defmodule NewYou.Identity.PrivilegedAccess do
  @moduledoc false

  require Ash.Query

  alias AshAuthentication.{Argon2Provider, Jwt}
  alias NewYou.Audit
  alias NewYou.Identity.{Account, IdentityGrant, Session, Token}

  @purposes [
    :place_security_hold,
    :review_security_hold,
    :release_security_hold,
    :review_reconciliation,
    :apply_reconciliation,
    :change_primary_email,
    :approve_manual_recovery,
    :complete_manual_recovery
  ]
  @step_up_seconds 5 * 60
  @max_failed_codes 5
  @cooldown_seconds 15 * 60

  defmacrop totp_timestamp do
    if Mix.env() == :test do
      quote do: NewYou.Proof.PrivilegedAccessSeam.timestamp()
    else
      quote do: System.os_time(:second)
    end
  end

  def enroll_mfa(credentials, password) do
    case transact_session(credentials, fn account, _token, _session ->
           enroll_locked(account, password)
         end) do
      {:ok, {:ok, secret}} -> {:ok, %{secret: secret}}
      _ -> unavailable()
    end
  end

  def confirm_mfa(credentials, password, code) do
    with true <- valid_code_shape?(code),
         {:ok, result} <-
           transact_session(credentials, fn account, _token, session ->
             confirm_locked(account, session, password, code)
           end) do
      if result == :ok, do: {:ok, :ok}, else: unavailable()
    else
      _ -> unavailable()
    end
  end

  def step_up(credentials, password, code, purpose) do
    with true <- purpose in @purposes,
         true <- valid_code_shape?(code),
         {:ok, result} <-
           transact_session(credentials, fn account, _token, session ->
             step_up_locked(account, session, password, code, purpose)
           end) do
      if result == :ok, do: {:ok, :ok}, else: unavailable()
    else
      _ -> unavailable()
    end
  end

  @doc false
  def authorize_locked(credentials, grant_id, target_id, capability)
      when capability in @purposes do
    authorize_locked(credentials, grant_id, target_id, capability, [])
  end

  def authorize_locked(_, _, _, _), do: unavailable()

  @doc false
  def authorize_locked(credentials, grant_id, target_id, capability, additional_account_ids)
      when capability in @purposes and is_list(additional_account_ids) do
    with true <- Ash.DataLayer.in_transaction?(Account),
         {:ok, claims} <- verified_claims(credentials),
         {:ok, actor_id} <- account_id_from_subject(claims["sub"]),
         {:ok, accounts} <- lock_accounts([actor_id, target_id | additional_account_ids]),
         actor <- Map.fetch!(accounts, actor_id),
         target <- Map.fetch!(accounts, target_id),
         {:ok, %{session: session, token: token}} <-
           lock_session_after_account(credentials, actor, claims["sub"], claims["jti"]),
         {:ok, grant} <- lock_grant(grant_id),
         true <- actor.mfa_enrollment_state == :active,
         true <- valid_step_up?(session, actor, capability),
         true <- valid_grant?(grant, actor, target, capability),
         {:ok, %{"sub" => subject, "jti" => jti}, Account} <-
           Jwt.verify(credentials.token, Account),
         true <- subject == AshAuthentication.user_to_subject(actor),
         true <- jti == token.jti do
      {:ok, %{actor: actor, target: target, session: session, grant: grant, accounts: accounts}}
    else
      _ -> unavailable()
    end
  end

  def authorize_locked(_, _, _, _, _), do: unavailable()

  @doc false
  def authorize_recorded_locked(review, target_id, capability, actor)
      when is_map(review) and capability in @purposes do
    with true <- Ash.DataLayer.in_transaction?(Account),
         true <- is_map(actor) and actor.id == review["reviewer_id"],
         true <- eligible?(actor),
         {:ok, [session]} <- lock_recorded_session(review["session_id"], actor.id),
         {:ok, [token]} <- lock_user_token(session.token_jti, actor.id),
         true <- token.purpose == "user" and before?(token.expires_at),
         true <- before?(session.expires_at) and before?(session.idle_expires_at),
         true <- not_revoked?(token.jti),
         {:ok, grant} <- lock_grant(review["grant_id"]),
         true <- grant.version == review["grant_version"],
         true <- actor.mfa_version == review["mfa_version"],
         true <- actor.security_version == review["security_version"],
         true <- valid_step_up?(session, actor, capability),
         {:ok, target} <-
           Account |> Ash.Query.filter(id == ^target_id) |> Ash.read_one(authorize?: false),
         true <- valid_grant?(grant, actor, target, capability) do
      {:ok,
       %{
         actor: actor,
         target: target,
         session: session,
         token: token,
         grant: grant,
         review: review
       }}
    else
      _ -> unavailable()
    end
  end

  def authorize_recorded_locked(_, _, _, _), do: unavailable()

  defp transact_session(credentials, callback) do
    case transaction([Account, Token, Session], fn ->
           run_session_callback(credentials, callback)
         end) do
      {:ok, result} -> {:ok, result}
      _ -> unavailable()
    end
  end

  defp run_session_callback(credentials, callback) do
    case lock_current_session(credentials) do
      {:ok, %{actor: account, token: token, session: session}} ->
        callback.(account, token, session)

      _ ->
        {:error, :unavailable}
    end
  end

  defp enroll_locked(account, password) do
    with :ok <- not_locked?(account),
         :ok <- reauthenticate_or_record_failure(account, password) do
      case account.mfa_enrollment_state do
        :disabled -> begin_enrollment(account)
        :pending -> resume_enrollment(account)
        _ -> {:error, :unavailable}
      end
    else
      {:denied, _} = denied -> denied
      _ -> {:error, :unavailable}
    end
  end

  defp begin_enrollment(account) do
    secret = NimbleTOTP.secret()

    case update_account(account, %{
           pending_totp_secret: secret,
           mfa_enrollment_state: :pending,
           mfa_failed_attempts: 0,
           mfa_locked_until: nil,
           mfa_version: account.mfa_version + 1,
           security_version: account.security_version + 1
         }) do
      {:ok, _} -> {:ok, secret}
      _ -> {:error, :unavailable}
    end
  end

  defp resume_enrollment(account) do
    # Reauthentication may recover an interrupted setup response while pending.
    # The Account lock keeps retries on one factor; activation closes this path.
    case load_account(account.id, [:pending_totp_secret]) do
      {:ok, [%{pending_totp_secret: secret}]} when is_binary(secret) -> {:ok, secret}
      _ -> {:error, :unavailable}
    end
  end

  defp confirm_locked(account, session, password, code) do
    with :ok <- not_locked?(account),
         :ok <- reauthenticate_or_record_failure(account, password),
         true <- account.mfa_enrollment_state == :pending,
         {:ok, [current]} <- load_account(account.id, [:pending_totp_secret]),
         true <- is_binary(current.pending_totp_secret) do
      period = current_period()

      confirm_pending_factor(account, current, session, code, period)
    else
      {:denied, _} = denied ->
        denied

      _ ->
        {:error, :unavailable}
    end
  end

  defp confirm_pending_factor(account, current, session, code, period) do
    if valid_totp?(current.pending_totp_secret, code, period) do
      confirm_factor(current, session, period)
    else
      failure_outcome(account, :invalid_code)
    end
  end

  defp confirm_factor(current, session, period) do
    with {:ok, _updated} <-
           update_account(current, %{
             totp_secret: current.pending_totp_secret,
             pending_totp_secret: nil,
             mfa_enrollment_state: :active,
             mfa_confirmed_at: now_usec(),
             mfa_last_accepted_period: period,
             mfa_failed_attempts: 0,
             mfa_locked_until: nil,
             mfa_version: current.mfa_version + 1,
             security_version: current.security_version + 1
           }),
         {:ok, :ok} <- audit_mfa_confirmation(current, session) do
      :ok
    else
      _ -> {:error, :unavailable}
    end
  end

  defp step_up_locked(account, session, password, code, purpose) do
    with :ok <- not_locked?(account),
         :ok <- reauthenticate_or_record_failure(account, password),
         true <- account.mfa_enrollment_state == :active,
         {:ok, [current]} <- load_account(account.id, [:totp_secret]),
         true <- is_binary(current.totp_secret),
         period <- current_period(),
         true <-
           is_nil(current.mfa_last_accepted_period) or period > current.mfa_last_accepted_period,
         true <- valid_totp?(current.totp_secret, code, period) do
      now = now_usec()

      with {:ok, _updated} <-
             update_account(current, %{
               mfa_last_accepted_period: period,
               mfa_failed_attempts: 0,
               mfa_locked_until: nil
             }),
           {:ok, _session} <-
             Ash.update(
               session,
               %{
                 step_up_purpose: purpose,
                 step_up_at: now,
                 step_up_expires_at: DateTime.add(now, @step_up_seconds, :second),
                 step_up_mfa_version: current.mfa_version,
                 step_up_security_version: current.security_version
               },
               action: :set_step_up,
               authorize?: false
             ) do
        :ok
      else
        _ -> {:error, :unavailable}
      end
    else
      false ->
        failure_outcome(account, :invalid_code)

      {:denied, _} = denied ->
        denied

      {:error, _} ->
        {:denied, :unavailable}

      _ ->
        {:error, :unavailable}
    end
  end

  defp reauthenticate(account, password)
       when is_binary(password) and byte_size(password) in 1..1024 do
    if Argon2Provider.valid?(password, account.hashed_password),
      do: :ok,
      else: {:error, :password}
  end

  defp reauthenticate(_, _), do: {:error, :password}

  defp reauthenticate_or_record_failure(account, password) do
    case reauthenticate(account, password) do
      :ok ->
        :ok

      _ ->
        failure_outcome(account, :password)
    end
  end

  defp record_failure(account) do
    attempts = account.mfa_failed_attempts + 1

    locked_until =
      if attempts >= @max_failed_codes,
        do: DateTime.add(now_usec(), @cooldown_seconds, :second),
        else: account.mfa_locked_until

    update_account(account, %{mfa_failed_attempts: attempts, mfa_locked_until: locked_until})
  end

  defp failure_outcome(account, reason) do
    case record_failure(account) do
      {:ok, _account} -> {:denied, reason}
      _ -> {:error, :unavailable}
    end
  end

  defp not_locked?(%{mfa_locked_until: nil}), do: :ok

  defp not_locked?(%{mfa_locked_until: lock}) do
    if DateTime.compare(now_usec(), lock) == :lt, do: {:denied, :locked}, else: :ok
  end

  defp audit_mfa_confirmation(account, session) do
    Audit.establish_identity_security_obligation(%{
      source_operation_id: Ecto.UUID.generate(),
      source_occurred_at: now_usec(),
      evidence_type: :identity_mfa_confirmed,
      actor_id: account.id,
      target_id: account.id,
      session_id: session.id,
      outcome: :succeeded
    })
    |> case do
      {:ok, _obligation} -> {:ok, :ok}
      _ -> {:error, :unavailable}
    end
  end

  defp lock_current_session(%{session_id: id, token: bearer})
       when is_binary(id) and is_binary(bearer) do
    with {:ok, %{"sub" => subject, "jti" => jti}, Account} <- Jwt.verify(bearer, Account),
         {:ok, account} <- lock_account_by_subject(subject),
         {:ok, result} <-
           lock_session_after_account(%{session_id: id, token: bearer}, account, subject, jti) do
      {:ok, Map.put(result, :actor, account)}
    else
      _ -> unavailable()
    end
  end

  defp lock_current_session(_), do: unavailable()

  defp lock_account_by_subject(subject) do
    case account_id_from_subject(subject) do
      {:ok, account_id} -> lock_account(account_id)
      _ -> unavailable()
    end
  end

  defp lock_accounts(ids) do
    ids
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.reduce_while({:ok, %{}}, fn id, {:ok, locked} ->
      case lock_account(id) do
        {:ok, account} -> {:cont, {:ok, Map.put(locked, id, account)}}
        _ -> {:halt, unavailable()}
      end
    end)
  end

  defp lock_session_after_account(%{session_id: id, token: bearer}, account, subject, jti) do
    with true <- eligible?(account),
         ^subject <- AshAuthentication.user_to_subject(account),
         {:ok, [token]} <- lock_user_token(jti, account.id),
         true <- not_revoked?(jti),
         {:ok, [session]} <- lock_session(id, jti, account.id),
         {:ok, %{"sub" => ^subject, "jti" => ^jti}, Account} <- Jwt.verify(bearer, Account),
         true <- session.state == :active,
         true <-
           before?(token.expires_at) and before?(session.expires_at) and
             before?(session.idle_expires_at) do
      {:ok, %{token: token, session: session}}
    else
      _ -> unavailable()
    end
  end

  defp verified_claims(%{token: bearer}) when is_binary(bearer) do
    case Jwt.verify(bearer, Account) do
      {:ok, %{"sub" => subject, "jti" => jti} = claims, Account}
      when is_binary(subject) and is_binary(jti) ->
        {:ok, claims}

      _ ->
        unavailable()
    end
  end

  defp verified_claims(_), do: unavailable()

  defp account_id_from_subject("account?id=" <> account_id), do: Ecto.UUID.cast(account_id)
  defp account_id_from_subject(_), do: {:error, :subject}

  defp lock_account(id) do
    Account
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.lock(:for_update)
    |> Ash.read(domain: NewYou.Identity, authorize?: false)
    |> case do
      {:ok, [account]} -> {:ok, account}
      _ -> unavailable()
    end
  end

  defp lock_user_token(jti, account_id) do
    Token
    |> Ash.Query.filter(jti == ^jti and account_id == ^account_id and purpose == "user")
    |> Ash.Query.lock(:for_update)
    |> Ash.read(domain: NewYou.Identity, authorize?: false)
  end

  defp not_revoked?(jti) do
    Token
    |> Ash.Query.filter(purpose == "revocation" and jti == ^jti)
    |> Ash.exists?(domain: NewYou.Identity, authorize?: false)
    |> then(&(&1 == false))
  end

  defp lock_session(id, jti, account_id) do
    Session
    |> Ash.Query.filter(id == ^id and token_jti == ^jti and account_id == ^account_id)
    |> Ash.Query.lock(:for_update)
    |> Ash.read(domain: NewYou.Identity, authorize?: false)
  end

  defp lock_recorded_session(id, account_id) do
    Session
    |> Ash.Query.filter(id == ^id and account_id == ^account_id)
    |> Ash.Query.lock(:for_update)
    |> Ash.read(domain: NewYou.Identity, authorize?: false)
  end

  defp lock_grant(id) do
    IdentityGrant
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.lock(:for_update)
    |> Ash.read(domain: NewYou.Identity, authorize?: false)
    |> case do
      {:ok, [grant]} -> {:ok, grant}
      _ -> unavailable()
    end
  end

  defp valid_grant?(grant, actor, target, capability) do
    now = now_usec()

    grant.state == :active and IdentityGrant.permits?(grant, capability) and
      grant.subject_account_id == actor.id and grant.target_account_id == target.id and
      is_nil(grant.revoked_at) and grant.approver_account_id != actor.id and
      DateTime.compare(now, grant.starts_at) != :lt and
      DateTime.compare(now, grant.expires_at) == :lt
  end

  defp valid_step_up?(session, account, purpose) do
    now = now_usec()

    session.step_up_purpose == purpose and not is_nil(session.step_up_at) and
      not is_nil(session.step_up_expires_at) and
      DateTime.compare(now, session.step_up_at) != :lt and
      DateTime.compare(now, session.step_up_expires_at) == :lt and
      session.step_up_mfa_version == account.mfa_version and
      session.step_up_security_version == account.security_version and
      account.mfa_enrollment_state == :active
  end

  defp load_account(id, fields) do
    Account
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.load(fields)
    |> Ash.Query.lock(:for_update)
    |> Ash.read(domain: NewYou.Identity, authorize?: false)
  end

  defp update_account(account, attributes) do
    Ash.update(account, attributes, action: :update_privileged_mfa, authorize?: false)
  end

  defp eligible?(account) do
    account.email_verified? and account.credential_status == :active and
      account.account_status == :open and account.security_posture == :normal
  end

  defp valid_code_shape?(code),
    do: is_binary(code) and Regex.match?(~r/\A[0-9]{6}\z/, code)

  defp valid_totp?(secret, code, period),
    do: NimbleTOTP.valid?(secret, code, time: period * 30)

  defp current_period, do: div(totp_timestamp(), 30)
  defp now_usec, do: DateTime.utc_now() |> DateTime.truncate(:microsecond)
  defp before?(datetime), do: DateTime.compare(now_usec(), datetime) == :lt

  defp transaction(resources, callback) do
    Ash.transact(resources, callback)
  end

  defp unavailable, do: {:error, :privileged_access_unavailable}
end
