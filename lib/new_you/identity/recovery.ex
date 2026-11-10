defmodule NewYou.Identity.Recovery do
  @moduledoc """
  Internal implementation of the Identity graduated-recovery actions.
  Account locks precede case and proof locks. Fixed non-bearer JWT claims permit
  transient delivery without a second token store. Every fresh mutation rechecks
  the Account binding. Committed receipts permit no new security effects.
  """
  import Kernel, except: [binding: 1]
  require Ash.Query
  alias AshAuthentication.{Jwt, Jwt.Config}
  alias NewYou.Identity.{Account, Token, RecoveryCase, Session, DeviceAssurance, IdentityGrant}
  alias NewYou.{Audit, Communications, Identity}

  @enabled Mix.env() in [:dev, :test] and
             Application.compile_env(:new_you, :verification_development_fixtures, false)
  @terminal [:completed, :failed, :expired, :cancelled]
  @resources [
    Account,
    RecoveryCase,
    Token,
    Session,
    DeviceAssurance,
    IdentityGrant,
    NewYou.Identity.RegistrationOperation,
    Audit.EvidenceObligation,
    Communications.MessageIntent
  ]

  defmacrop checkpoint do
    if Mix.env() == :test do
      quote do: NewYou.Proof.RegistrationSeam.checkpoint()
    else
      quote do: :ok
    end
  end

  if @enabled do
    @spec request(term(), term(), term()) :: :ok
    def request(email, locale, operation_id) do
      started = System.monotonic_time(:millisecond)

      try do
        with {:ok, email} <- NewYou.Identity.Email.canonicalize(email),
             true <- locale in ["en", "af"],
             {:ok, operation_id} <- Ecto.UUID.cast(operation_id) do
          transaction(fn -> request_locked(email, locale, operation_id) end, timeout: 250)
        end
      rescue
        _ -> :ok
      after
        Process.sleep(max(500 - (System.monotonic_time(:millisecond) - started), 0))
      end

      :ok
    end
  else
    @spec request(term(), term(), term()) :: :ok
    def request(_email, _locale, _operation_id), do: :ok
  end

  defp request_locked(email, locale, operation_id) do
    with {:ok, %Account{} = account} <-
           Account
           |> Ash.Query.filter(email == ^email)
           |> Ash.Query.lock(:for_update)
           |> Ash.read_one(authorize?: false),
         true <- account.account_status == :open and account.credential_status == :active,
         {:ok, prior} <-
           RecoveryCase
           |> Ash.Query.filter(operation_id == ^operation_id)
           |> Ash.read_one(authorize?: false) do
      reuse_or_start(prior, account, locale, operation_id)
    else
      _ -> unavailable()
    end
  end

  defp reuse_or_start(%RecoveryCase{account_id: id}, %{id: id}, _locale, _operation_id),
    do: {:ok, :pending}

  defp reuse_or_start(%RecoveryCase{}, _account, _locale, _operation_id), do: unavailable()

  defp reuse_or_start(nil, account, locale, operation_id) do
    current =
      RecoveryCase
      |> Ash.Query.filter(account_id == ^account.id and state not in ^@terminal)
      |> Ash.read_one!(authorize?: false)

    start_or_resume(current, account, locale, operation_id)
  end

  defp start_or_resume(nil, account, locale, operation_id),
    do: start_case(account, locale, operation_id)

  defp start_or_resume(current, account, locale, operation_id) do
    if DateTime.compare(now(), current.expires_at) == :lt do
      {:ok, :pending}
    else
      with {:ok, _} <- transition(current, :expire, %{terminated_at: now()}),
           :ok <- revoke_case_proof(current) do
        start_case(account, locale, operation_id)
      end
    end
  end

  defp revoke_case_proof(%{proof_jti: nil}), do: :ok

  defp revoke_case_proof(recovery) do
    case token(recovery.proof_jti, true) do
      {:ok, %Token{purpose: purpose} = proof} when purpose in ["recovery", "recovery_consumed"] ->
        case Ash.update(proof, %{}, action: :revoke_recovery, authorize?: false) do
          {:ok, _} -> :ok
          _ -> unavailable()
        end

      {:ok, %Token{}} ->
        :ok

      _ ->
        unavailable()
    end
  end

  defp start_case(account, locale, operation_id) do
    required = required_assurance(account)

    with {:ok, account} <-
           Ash.update(account, %{recovery_assurance_floor: required},
             action: :set_recovery_floor,
             authorize?: false
           ),
         {:ok, recovery} <-
           Ash.create(
             RecoveryCase,
             %{
               operation_id: operation_id,
               account_id: account.id,
               required_assurance: required,
               account_binding: binding(account),
               locale: locale,
               expires_at: DateTime.add(now(), 3600, :second),
               history: [%{"state" => "requested", "version" => 0}]
             },
             action: :request,
             authorize?: false
           ) do
      if account.email_verified? do
        issue_proof(account, recovery)
      else
        hold_case(account, recovery)
      end
    end
  end

  defp required_assurance(account) do
    now = now()

    privileged =
      IdentityGrant
      |> Ash.Query.filter(
        subject_account_id == ^account.id and state == :active and starts_at <= ^now and
          expires_at > ^now
      )
      |> Ash.exists?(authorize?: false)

    required =
      if privileged or account.mfa_enrollment_state == :active or
           account.security_posture == :held or not account.email_verified?, do: 2, else: 1

    max(required, account.recovery_assurance_floor)
  end

  defp issue_proof(account, recovery) do
    with {:ok, bearer, claims} <-
           Joken.generate_and_sign(
             Config.default_claims(Account, token_lifetime: {15, :minutes}),
             %{
               "sub" => AshAuthentication.user_to_subject(account),
               "purpose" => "recovery",
               "case_id" => recovery.id
             },
             Config.token_signer(Account)
           ),
         {:ok, proof} <-
           Ash.create(
             Token,
             %{token: bearer, recovery_case_id: recovery.id, recovery_claims: claims},
             action: :issue_recovery,
             authorize?: false,
             context: %{ash_authentication: %{user: account}}
           ),
         {:ok, _} <-
           Communications.establish_recovery(%{
             source_operation_id: recovery.operation_id,
             source_reference: proof.jti,
             destination: account.email,
             destination_provenance: "identity_recovery_issuance",
             destination_authorized_at: proof.created_at,
             locale: recovery.locale
           }),
         {:ok, _} <- transition(recovery, :await_proof, %{proof_jti: proof.jti}) do
      checkpoint()
      {:ok, :pending}
    else
      _ -> unavailable()
    end
  end

  @spec delivery(term(), term(), term()) :: {:ok, binary()} | {:error, atom()}
  def delivery(reference, destination, locale) do
    with true <- :erlang.andalso(@enabled, NewYou.Repo.in_transaction?()),
         {:ok, %Token{} = locator} <- token(reference),
         {:ok, account} <- lock_account(locator.account_id),
         {:ok, recovery} <- lock_case(locator.recovery_case_id),
         {:ok, proof} <- token(reference, true),
         true <- current?(recovery, account) and recovery.state == :proof_pending,
         true <- proof.purpose == "recovery" and DateTime.compare(now(), proof.expires_at) == :lt,
         true <-
           account.email_verified? and account.email == destination and recovery.locale == locale,
         {:ok, bearer, claims} <-
           Joken.encode_and_sign(proof.recovery_claims, Config.token_signer(Account)),
         true <- claims == proof.recovery_claims,
         {:ok, ^claims, Account} <- Jwt.verify(bearer, Account) do
      {:ok, bearer}
    else
      _ -> {:error, :source_invalid}
    end
  rescue
    _ -> {:error, :capability_unavailable}
  end

  @spec run(atom(), map()) :: {:ok, atom() | map()} | {:error, :recovery_unavailable}
  def run(operation, request) do
    with true <- :erlang.andalso(@enabled, is_map(request)),
         false <- Ash.DataLayer.in_transaction?(Account) do
      case operation do
        :approve_manual_recovery -> NewYou.Identity.ManualRecovery.approve(request)
        :complete_manual_recovery -> NewYou.Identity.ManualRecovery.complete(request)
        _ -> claimant_action(operation, request)
      end
    else
      _ -> unavailable()
    end
  rescue
    _ -> unavailable()
  end

  defp claimant_action(operation, request) do
    with true <- operation in [:submit_recovery_proof, :complete_recovery, :cancel_recovery],
         {:ok, operation_id} <- Ecto.UUID.cast(request[:operation_id]),
         true <- is_binary(request[:proof]) and byte_size(request.proof) in 1..8192,
         {:ok, %{"purpose" => "recovery", "jti" => jti} = claims} <-
           Joken.verify(request.proof, Config.token_signer(Account)),
         {:ok, %Token{} = locator} <- token(jti) do
      transaction(fn -> lock_claimant(operation, request, operation_id, locator, claims) end)
    else
      _ -> unavailable()
    end
  end

  defp lock_claimant(operation, request, operation_id, locator, claims) do
    with {:ok, account} <- lock_account(locator.account_id),
         {:ok, recovery} <- lock_case(locator.recovery_case_id),
         {:ok, proof} <- token(locator.jti, true),
         true <- proof.recovery_claims == claims and recovery.proof_jti == proof.jti do
      claimant_locked(operation, request, operation_id, recovery, account, proof)
    else
      _ -> unavailable()
    end
  end

  defp claimant_locked(
         :complete_recovery,
         _request,
         id,
         %{state: :completed, completion_id: id},
         _account,
         _proof
       ),
       do: {:ok, :already_completed}

  defp claimant_locked(
         :submit_recovery_proof,
         _request,
         id,
         %{proof_acceptance_id: id, state: state},
         _account,
         %{purpose: "recovery_consumed"}
       )
       when state not in @terminal, do: {:ok, :accepted}

  defp claimant_locked(:cancel_recovery, _request, _id, %{state: :cancelled}, _account, _proof),
    do: {:ok, :cancelled}

  defp claimant_locked(operation, request, id, recovery, account, proof) do
    cond do
      recovery.state in @terminal ->
        unavailable()

      DateTime.compare(now(), recovery.expires_at) != :lt ->
        terminate(recovery, proof, :expire, :expired)

      not current?(recovery, account) ->
        terminate(recovery, proof, :fail, :failed)

      true ->
        fresh_claimant_action(operation, request, id, recovery, account, proof)
    end
  end

  defp fresh_claimant_action(:submit_recovery_proof, request, id, recovery, account, proof) do
    with :proof_pending <- recovery.state,
         "recovery" <- proof.purpose,
         {:ok, claims, Account} <- Jwt.verify(request.proof, Account),
         true <- claims == proof.recovery_claims and account.email_verified?,
         {:ok, _} <- Ash.update(proof, %{}, action: :consume_recovery, authorize?: false),
         {:ok, recovery} <-
           transition(recovery, :accept_proof, %{satisfied_assurance: 1, proof_acceptance_id: id}) do
      accept_assurance(account, recovery)
    else
      _ -> unavailable()
    end
  end

  defp fresh_claimant_action(:complete_recovery, request, id, recovery, account, proof) do
    with :additional_assurance <- recovery.state,
         1 <- recovery.required_assurance,
         "recovery_consumed" <- proof.purpose,
         true <- required_assurance(account) == 1 and account.security_posture == :normal do
      finish(recovery, account, proof, request[:password], id, nil)
    else
      _ -> unavailable()
    end
  end

  defp fresh_claimant_action(:cancel_recovery, _request, _id, recovery, _account, proof),
    do: terminate(recovery, proof, :cancel, :cancelled)

  defp accept_assurance(account, recovery) do
    with {:ok, _} <- graduate_assurance(account, recovery) do
      checkpoint()
      {:ok, :accepted}
    end
  end

  defp graduate_assurance(account, %{required_assurance: 2} = recovery),
    do: hold_case(account, recovery)

  defp graduate_assurance(_account, recovery), do: {:ok, recovery}

  defp hold_case(account, recovery) do
    with {:ok, account} <- ensure_hold(account, recovery),
         :ok <- invalidate_sessions_and_devices(account.id) do
      transition(recovery, :require_review, %{
        required_assurance: 2,
        account_binding: binding(account)
      })
    end
  end

  defp ensure_hold(%{security_posture: :held} = account, _recovery), do: {:ok, account}

  defp ensure_hold(account, recovery) do
    with {:ok, held} <- Ash.update(account, %{}, action: :hold_for_recovery, authorize?: false),
         {:ok, _} <-
           Audit.establish_identity_security_obligation(%{
             source_operation_id: recovery.operation_id,
             source_occurred_at: now(),
             evidence_type: :security_hold_placement,
             actor_id: nil,
             target_id: account.id,
             case_id: recovery.id,
             reason_code: :verified_recovery,
             outcome: :succeeded
           }) do
      {:ok, held}
    else
      _ -> unavailable()
    end
  end

  @doc false
  def finish(recovery, account, proof, password, operation_id, authority) do
    with true <- is_binary(password) and byte_size(password) in 1..1024,
         {:ok, strategy} <- AshAuthentication.Info.strategy(Account, :password),
         false <- strategy.hash_provider.valid?(password, account.hashed_password),
         {:ok, _} <-
           Ash.update(account, %{password: password},
             action: :replace_password,
             authorize?: false
           ),
         :ok <- invalidate_sessions_and_devices(account.id),
         :ok <- Identity.invalidate_registration_operations(account.id),
         {:ok, _} <-
           Communications.establish_recovery_notice(%{
             source_operation_id: operation_id,
             source_reference: proof.jti,
             destination: account.email,
             destination_provenance: "identity_recovery_completion",
             destination_authorized_at: now(),
             locale: recovery.locale
           }),
         {:ok, _} <-
           Audit.establish_identity_security_obligation(%{
             source_operation_id: operation_id,
             source_occurred_at: now(),
             evidence_type: :identity_recovery_completed,
             actor_id: if(authority, do: authority.actor.id, else: account.id),
             target_id: account.id,
             case_id: recovery.id,
             outcome: :succeeded,
             admission_id: if(authority, do: authority.admission_id, else: nil),
             grant_id: if(authority, do: authority.grant.id, else: nil),
             session_id: if(authority, do: authority.session.id, else: nil),
             reason_code: if(authority, do: :verified_recovery, else: nil)
           }),
         {:ok, _} <-
           transition(recovery, :finish, %{
             completion_id: operation_id,
             completed_at: now(),
             terminated_at: now(),
             satisfied_assurance: recovery.required_assurance
           }) do
      checkpoint()
      {:ok, :completed}
    else
      _ -> unavailable()
    end
  end

  @doc false
  def invalidate_sessions_and_devices(id) do
    Session
    |> Ash.Query.filter(account_id == ^id and state == :active)
    |> Ash.Query.sort(:id)
    |> Ash.Query.lock(:for_update)
    |> Ash.read!(authorize?: false)
    |> Enum.each(fn session ->
      case token(session.token_jti, true) do
        {:ok, %{purpose: "user"} = linked} ->
          Ash.update!(linked, %{}, action: :revoke_authentication, authorize?: false)

        _ ->
          :ok
      end

      Ash.update!(session, %{}, action: :revoke, authorize?: false)
    end)

    DeviceAssurance
    |> Ash.Query.filter(account_id == ^id and state == :trusted)
    |> Ash.Query.sort(:id)
    |> Ash.Query.lock(:for_update)
    |> Ash.read!(authorize?: false)
    |> Enum.each(&Ash.update!(&1, %{}, action: :revoke, authorize?: false))

    :ok
  end

  defp terminate(recovery, proof, action, outcome) do
    with {:ok, _} <- transition(recovery, action, %{terminated_at: now()}),
         {:ok, _} <- Ash.update(proof, %{}, action: :revoke_recovery, authorize?: false),
         do: {:ok, outcome}
  end

  @doc false
  def transition(recovery, action, attrs) do
    event = %{"action" => Atom.to_string(action), "version" => recovery.version + 1}

    Ash.update(recovery, Map.put(attrs, :history, recovery.history ++ [event]),
      action: action,
      authorize?: false
    )
  end

  @doc false
  def current?(recovery, account),
    do:
      recovery.account_id == account.id and account.account_status == :open and
        account.credential_status == :active and
        recovery.account_binding == binding(account) and
        recovery.required_assurance >= required_assurance(account)

  @doc false
  def binding(account) do
    {:ok, {module, opts}} = AshAuthentication.Info.authentication_tokens_signing_secret(Account)

    {:ok, secret} =
      AshAuthentication.Secret.secret_for(
        module,
        [:authentication, :tokens, :signing_secret],
        Account,
        opts,
        %{}
      )

    :crypto.mac(
      :hmac,
      :sha256,
      secret,
      :erlang.term_to_binary(
        {"recovery-account:v1",
         AshAuthentication.Info.authentication_tokens_signing_algorithm!(Account), account.id,
         account.email, account.hashed_password, account.credential_version,
         account.security_version, account.hold_version, account.email_verified?,
         account.credential_status, account.account_status, account.security_posture,
         account.mfa_version, account.recovery_assurance_floor},
        [:deterministic]
      )
    )
  end

  @doc false
  def lock_account(id),
    do:
      Account
      |> Ash.Query.filter(id == ^id)
      |> Ash.Query.lock(:for_update)
      |> Ash.read_one(authorize?: false)

  @doc false
  def lock_case(id),
    do:
      RecoveryCase
      |> Ash.Query.filter(id == ^id)
      |> Ash.Query.lock(:for_update)
      |> Ash.read_one(authorize?: false)

  @doc false
  def token(jti, lock? \\ false) do
    query = Ash.Query.filter(Token, jti == ^jti)
    query = if lock?, do: Ash.Query.lock(query, :for_update), else: query
    Ash.read_one(query, authorize?: false)
  end

  @doc false
  def transaction(callback, opts \\ []) do
    case Ash.transact(@resources, callback, opts) do
      {:ok, {:ok, result}} -> {:ok, result}
      {:ok, result} -> {:ok, result}
      _ -> unavailable()
    end
  end

  if Mix.env() == :test do
    defp now, do: NewYou.Proof.RecoverySeam.now()
  else
    defp now, do: DateTime.utc_now()
  end

  defp unavailable, do: {:error, :recovery_unavailable}
end
