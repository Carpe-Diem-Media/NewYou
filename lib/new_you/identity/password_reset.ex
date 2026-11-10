defmodule NewYou.Identity.PasswordReset do
  @moduledoc """
  Identity-owned password-reset proof and credential-security lifecycle. Account locks serialize issue,
  supersession and explicit consumption. The Token's fixed claims describe one
  proof; only an in-memory signature is reconstructed for a current delivery.
  Signing never calls a token creation/upsert API. Communications retains no bearer.
  """
  @enabled Mix.env() in [:dev, :test] and
             Application.compile_env(:new_you, :verification_development_fixtures, false)

  if @enabled do
    require Ash.Query
    alias AshAuthentication.{Jwt, Jwt.Config}
    alias NewYou.Identity.{Account, Email, Session, Token, DeviceAssurance, RegistrationOperation}
    alias NewYou.Audit.EvidenceObligation
    alias NewYou.Communications.{MessageIntent, DeliveryAttempt}

    @request_work_timeout_ms 250
    @request_response_floor_ms 500

    @doc """
    Runs one bounded issuance attempt and always returns a neutral response after
    the common minimum window. A timeout cancels the worker; an interrupted
    transaction rolls back. If commit wins cancellation, the retained operation ID
    makes an unchanged retry harmless. Request success never authenticates.
    """
    @spec request(term(), term(), term()) :: :ok
    def request(email, locale, operation_id) do
      started = System.monotonic_time(:millisecond)
      deadline = started + @request_work_timeout_ms
      response_at = started + @request_response_floor_ms

      try do
        callback = request_callback(fn -> request_transaction(email, locale, operation_id) end)

        task =
          Task.Supervisor.async_nolink(
            NewYou.Identity.PasswordReset.RequestSupervisor,
            fn -> bounded_request(callback, deadline) end
          )

        Task.yield(task, remaining(deadline)) || Task.shutdown(task, :brutal_kill)
      rescue
        _ -> :ok
      catch
        _, _ -> :ok
      after
        # Pad every outcome after work finishes or cancellation, outside all locks.
        # Host/scheduler pauses are outside this deliberate timing treatment.
        Process.sleep(remaining(response_at))
      end

      :ok
    end

    defp bounded_request(callback, deadline) do
      if remaining(deadline) > 0 do
        # An unlinked one-shot timer survives caller death. The worker cannot keep
        # issuing after its deadline merely because the request process vanished.
        {:ok, timer} = :timer.kill_after(remaining(deadline))

        try do
          callback.()
        rescue
          _ -> :ok
        catch
          _, _ -> :ok
        after
          :timer.cancel(timer)
        end
      end

      :ok
    end

    defp remaining(deadline), do: max(deadline - System.monotonic_time(:millisecond), 0)

    defp request_transaction(email, locale, operation_id) do
      Ash.transact(
        [Account, Token, MessageIntent, DeliveryAttempt],
        fn ->
          with true <- locale in ["en", "af"],
               {:ok, operation_id} <- Ecto.UUID.cast(operation_id),
               {:ok, email} <- Email.canonicalize(email),
               {:ok, %Account{} = account} <- find_account(email) do
            issue_locked(account.id, email, locale, operation_id)
          else
            _ -> :ok
          end
        end,
        timeout: @request_work_timeout_ms
      )
    end

    if Mix.env() == :test do
      defp request_callback(callback),
        do: NewYou.Proof.RegistrationSeam.inherit(callback)
    else
      defp request_callback(callback), do: callback
    end

    defp issue_locked(id, email, locale, operation_id) do
      with {:ok, account} <- lock_account(id),
           true <- eligible?(account) and account.email == email,
           {:ok, prior} <- by_request(operation_id) do
        case prior do
          nil -> issue_new(account, locale, operation_id)
          %Token{} -> :ok
        end
      else
        _ -> {:error, :reset_unavailable}
      end
    end

    defp issue_new(account, locale, operation_id) do
      with {:ok, previous} <- current_proofs(account.id),
           :ok <- supersede(previous),
           {:ok, bearer, claims} <-
             Joken.generate_and_sign(
               Config.default_claims(Account, token_lifetime: {15, :minutes}),
               %{
                 "sub" => AshAuthentication.user_to_subject(account),
                 "purpose" => "password_reset",
                 "locale" => locale
               },
               Config.token_signer(Account)
             ),
           {:ok, proof} <-
             Ash.create(
               Token,
               %{
                 token: bearer,
                 reset_request_id: operation_id,
                 reset_claims: claims,
                 reset_account_binding: account_binding(account),
                 reset_locale: locale
               },
               action: :issue_password_reset,
               authorize?: false,
               context: %{ash_authentication: %{user: account}}
             ),
           {:ok, _intent} <-
             NewYou.Communications.establish_password_reset(%{
               source_operation_id: operation_id,
               source_reference: proof.jti,
               role: :password_reset,
               source_purpose: "password_reset",
               render_schema: "password-reset-v1",
               destination: account.email,
               destination_provenance: "identity_password_reset_issuance",
               destination_authorized_at: proof.created_at,
               locale: locale
             }) do
        checkpoint()
        :ok
      else
        _ -> {:error, :reset_unavailable}
      end
    end

    @spec delivery(String.t(), String.t(), String.t()) ::
            {:ok, binary()} | {:error, :source_invalid | :capability_unavailable}
    def delivery(reference, destination, locale) do
      with true <- NewYou.Repo.in_transaction?(),
           {:ok, %Token{} = locator} <- token(reference),
           {:ok, account} <- lock_account(locator.account_id),
           {:ok, proof} <- token(reference, true),
           true <- valid_current?(proof, account),
           true <- account.email == destination and proof.reset_locale == locale,
           {:ok, bearer, claims} <-
             Joken.encode_and_sign(proof.reset_claims, Config.token_signer(Account)),
           true <- claims == proof.reset_claims,
           {:ok, ^claims, Account} <- Jwt.verify(bearer, Account) do
        {:ok, bearer}
      else
        {:error, _} -> {:error, :capability_unavailable}
        _ -> {:error, :source_invalid}
      end
    rescue
      _ -> {:error, :capability_unavailable}
    end

    @doc """
    Explicit reset under the Account lock. One fresh confirmation operation can
    commit; its retry reports the prior outcome without reapplying its password.
    A fresh reset rejects the current password before proof consumption or any
    security consequence. The configured hash provider verifies that comparison.
    A different operation using the consumed proof is a replay and fails closed.
    No Session is issued. Every failed write rolls back all consequences.
    """
    @spec reset(binary(), binary(), String.t()) ::
            {:ok, :reset | :already_reset} | {:error, :reset_unavailable}
    def reset(bearer, password, operation_id) do
      with true <- is_binary(password) and byte_size(password) in 1..1024,
           {:ok, operation_id} <- Ecto.UUID.cast(operation_id),
           {:ok, %{"purpose" => "password_reset", "jti" => jti}} <-
             Joken.verify(bearer, Config.token_signer(Account)),
           {:ok, %Token{} = locator} <- token(jti),
           {:ok, result} <-
             Ash.transact(
               [
                 Account,
                 Token,
                 Session,
                 DeviceAssurance,
                 RegistrationOperation,
                 EvidenceObligation
               ],
               fn ->
                 consume_locked(locator.account_id, jti, bearer, password, operation_id)
               end
             ) do
        case result do
          {:ok, outcome} when outcome in [:reset, :already_reset] -> {:ok, outcome}
          outcome when outcome in [:reset, :already_reset] -> {:ok, outcome}
          _ -> {:error, :reset_unavailable}
        end
      else
        _ -> {:error, :reset_unavailable}
      end
    rescue
      _ -> {:error, :reset_unavailable}
    end

    defp consume_locked(account_id, jti, bearer, password, operation_id) do
      with {:ok, account} <- lock_account(account_id),
           {:ok, proof} <- token(jti, true),
           {:ok, claims} <- Joken.verify(bearer, Config.token_signer(Account)),
           true <- claims == proof.reset_claims do
        reset_or_receipt(proof, account, claims, bearer, password, operation_id)
      else
        _ -> {:error, :reset_unavailable}
      end
    end

    defp reset_or_receipt(
           %Token{purpose: "password_reset_consumed", reset_consumption_id: operation_id},
           _account,
           _claims,
           _bearer,
           _password,
           operation_id
         ),
         do: {:ok, :already_reset}

    defp reset_or_receipt(proof, account, claims, bearer, password, operation_id) do
      # Signature-only verification can recover a committed receipt. Every new
      # mutation still requires all time/resource claim validations.
      case Jwt.verify(bearer, Account) do
        {:ok, ^claims, Account} -> replace_current(proof, account, password, operation_id)
        _ -> {:error, :reset_unavailable}
      end
    end

    defp replace_current(proof, account, password, operation_id) do
      with true <- valid_current?(proof, account),
           {:ok, strategy} <- AshAuthentication.Info.strategy(Account, :password),
           false <-
             strategy.hash_provider.valid?(
               password,
               Map.fetch!(account, strategy.hashed_password_field)
             ),
           {:ok, _} <-
             Ash.update(proof, %{reset_consumption_id: operation_id},
               action: :consume_password_reset,
               authorize?: false
             ),
           {:ok, _} <-
             Ash.update(account, %{password: password},
               action: :replace_password,
               authorize?: false
             ),
           :ok <- revoke_sessions(account.id),
           :ok <- revoke_devices(account.id),
           :ok <- NewYou.Identity.invalidate_registration_operations(account.id),
           {:ok, _} <-
             NewYou.Audit.establish_identity_security_obligation(%{
               source_operation_id: operation_id,
               source_occurred_at: DateTime.utc_now(),
               evidence_type: :identity_password_reset,
               actor_id: account.id,
               target_id: account.id,
               outcome: :succeeded
             }) do
        checkpoint()
        {:ok, :reset}
      else
        _ -> {:error, :reset_unavailable}
      end
    end

    defp revoke_sessions(id) do
      sessions =
        Session
        |> Ash.Query.filter(account_id == ^id and state == :active)
        |> Ash.Query.sort(:id)
        |> Ash.Query.lock(:for_update)
        |> Ash.read!(authorize?: false)

      Enum.each(sessions, fn session ->
        # Invalidate only linked authentication authority, never other purposes.
        case token(session.token_jti, true) do
          {:ok, %Token{purpose: "user"} = linked} ->
            Ash.update!(linked, %{}, action: :revoke_authentication, authorize?: false)

          _ ->
            :ok
        end

        Ash.update!(session, %{}, action: :revoke, authorize?: false)
      end)

      :ok
    end

    defp revoke_devices(id) do
      DeviceAssurance
      |> Ash.Query.filter(account_id == ^id and state == :trusted)
      |> Ash.Query.sort(:id)
      |> Ash.Query.lock(:for_update)
      |> Ash.read!(authorize?: false)
      |> Enum.each(&Ash.update!(&1, %{}, action: :revoke, authorize?: false))

      :ok
    end

    defp valid_current?(%Token{} = proof, %Account{} = account) do
      eligible?(account) and proof.account_id == account.id and proof.purpose == "password_reset" and
        proof.subject == AshAuthentication.user_to_subject(account) and
        DateTime.compare(DateTime.utc_now(), proof.expires_at) == :lt and
        proof.reset_account_binding == account_binding(account) and
        claims_match?(proof)
    end

    defp valid_current?(_, _), do: false

    defp claims_match?(proof) do
      is_map(proof.reset_claims) and proof.reset_claims["jti"] == proof.jti and
        proof.reset_claims["sub"] == proof.subject and
        proof.reset_claims["purpose"] == "password_reset" and
        proof.reset_claims["locale"] == proof.reset_locale and
        proof.reset_claims["exp"] == DateTime.to_unix(proof.expires_at)
    end

    defp eligible?(account),
      do:
        account.email_verified? and account.credential_status == :active and
          account.account_status == :open and account.security_posture == :normal

    # Bind retained claims to the original signing key as well as Account state.
    # Key replacement must never re-sign an old proof into a new capability.
    defp account_binding(account) do
      {:ok, {secret_module, secret_opts}} =
        AshAuthentication.Info.authentication_tokens_signing_secret(Account)

      {:ok, secret} =
        AshAuthentication.Secret.secret_for(
          secret_module,
          [:authentication, :tokens, :signing_secret],
          Account,
          secret_opts,
          %{}
        )

      :crypto.mac(
        :hmac,
        :sha256,
        secret,
        :erlang.term_to_binary(
          {"password-reset-account:v1",
           AshAuthentication.Info.authentication_tokens_signing_algorithm!(Account), account.id,
           account.email, account.hashed_password, account.credential_version,
           account.security_version, account.email_verified?, account.credential_status,
           account.account_status, account.security_posture},
          [:deterministic]
        )
      )
    end

    defp find_account(email),
      do: Account |> Ash.Query.filter(email == ^email) |> Ash.read_one(authorize?: false)

    defp lock_account(id),
      do:
        Account
        |> Ash.Query.filter(id == ^id)
        |> Ash.Query.lock(:for_update)
        |> Ash.read_one(authorize?: false)

    defp token(jti, lock? \\ false) do
      query = Ash.Query.filter(Token, jti == ^jti)
      query = if lock?, do: Ash.Query.lock(query, :for_update), else: query
      Ash.read_one(query, authorize?: false)
    end

    defp by_request(operation_id),
      do:
        Token
        |> Ash.Query.filter(reset_request_id == ^operation_id)
        |> Ash.read_one(authorize?: false)

    defp current_proofs(account_id),
      do:
        Token
        |> Ash.Query.filter(account_id == ^account_id and purpose == "password_reset")
        |> Ash.read(authorize?: false)

    defp supersede(proofs) do
      Enum.reduce_while(proofs, :ok, fn proof, _ ->
        case Ash.update(proof, %{}, action: :supersede_password_reset, authorize?: false) do
          {:ok, _} -> {:cont, :ok}
          _ -> {:halt, {:error, :reset_unavailable}}
        end
      end)
    end

    if Mix.env() == :test do
      defp checkpoint, do: NewYou.Proof.RegistrationSeam.checkpoint()
    else
      defp checkpoint, do: :ok
    end
  else
    @spec request(term(), term(), term()) :: :ok
    def request(_email, _locale, _operation_id), do: :ok

    @spec delivery(String.t(), String.t(), String.t()) :: {:error, :source_invalid}
    def delivery(_reference, _destination, _locale), do: {:error, :source_invalid}

    @spec reset(binary(), binary(), String.t()) :: {:error, :reset_unavailable}
    def reset(_bearer, _password, _operation_id), do: {:error, :reset_unavailable}
  end
end
