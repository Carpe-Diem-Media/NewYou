defmodule NewYou.Identity.PrimaryEmailChange do
  @moduledoc """
  Account-owned primary-email-change request and proof-issuance boundary.

  Account is locked before related Token rows, which are locked by JTI before the
  current Session. The signed bearer is transient; only fixed claims and JTIs are
  retained by Identity.
  """

  @enabled Mix.env() in [:dev, :test] and
             Application.compile_env(:new_you, :verification_development_fixtures, false)

  if @enabled do
    require Ash.Query

    alias AshAuthentication.{Argon2Provider, Jwt, Jwt.Config}
    alias NewYou.Identity.{Account, DeviceAssurance, Email, RecoveryCase, Session, Token}
    alias NewYou.Audit.EvidenceObligation
    alias NewYou.Communications.{DeliveryAttempt, MessageIntent}

    @operation_lifetime_seconds 24 * 60 * 60
    @proof_lifetime {24, :hours}
    @step_up_seconds 5 * 60

    @doc "Accept a new target address for the current authenticated Account."
    def request(credentials, target, locale, operation_id) do
      with {:ok, locator} <- session_locator(credentials),
           {:ok, target} <- Email.canonicalize(target),
           true <- locale in ["en", "af"],
           {:ok, operation_id} <- Ecto.UUID.cast(operation_id),
           result <-
             Ash.transact(
               [Account, Token, Session, EvidenceObligation],
               fn -> request_locked(locator, credentials, target, locale, operation_id) end
             ) do
        unwrap(result, :requested)
      else
        _ -> unavailable()
      end
    rescue
      _ -> unavailable()
    catch
      _, _ -> unavailable()
    end

    @doc "Require fresh password and current Session assurance before issuing or refreshing proof authority."
    def reauthenticate(credentials, password, operation_id) do
      with {:ok, locator} <- session_locator(credentials),
           {:ok, operation_id} <- Ecto.UUID.cast(operation_id),
           true <- is_binary(password) and byte_size(password) in 1..1024,
           result <-
             Ash.transact(
               [Account, Token, Session, MessageIntent, DeliveryAttempt, EvidenceObligation],
               fn -> reauthenticate_locked(locator, credentials, password, operation_id) end
             ) do
        unwrap_reauthenticate(result)
      else
        _ -> unavailable()
      end
    rescue
      _ -> unavailable()
    catch
      _, _ -> unavailable()
    end

    @doc "Consume a current new-address proof only after explicit participant confirmation."
    def confirm(bearer) when is_binary(bearer) and byte_size(bearer) in 1..8192 do
      with {:ok, claims} <- confirmation_claims(bearer),
           {:ok, operation_id} <- Ecto.UUID.cast(claims["operation_id"]),
           {:ok, proof} <- token(claims["jti"]),
           {:ok, result} <-
             Ash.transact(
               [Account, Token, EvidenceObligation],
               fn -> confirm_locked(proof.account_id, bearer, claims, operation_id) end
             ) do
        unwrap(result, :confirmed)
      else
        _ -> unavailable()
      end
    rescue
      _ -> unavailable()
    catch
      _, _ -> unavailable()
    end

    def confirm(_), do: unavailable()

    @doc "Apply the Account-owned address change after current proof, version, delay and risk guards pass."
    def apply(operation_id) do
      with {:ok, operation_id} <- Ecto.UUID.cast(operation_id),
           result <-
             Ash.transact(
               [
                 Account,
                 RecoveryCase,
                 Token,
                 Session,
                 DeviceAssurance,
                 MessageIntent,
                 DeliveryAttempt,
                 EvidenceObligation,
                 NewYou.Privacy.PurposeAuthority
               ],
               fn -> apply_locked(operation_id) end
             ) do
        unwrap_apply(result)
      else
        _ -> unavailable()
      end
    rescue
      _ -> unavailable()
    catch
      _, _ -> unavailable()
    end

    @doc "Cancel the current operation under the Account lock and revoke its outstanding proof."
    def cancel(credentials, operation_id) do
      with {:ok, locator} <- session_locator(credentials),
           {:ok, operation_id} <- Ecto.UUID.cast(operation_id),
           result <-
             Ash.transact([Account, Token, Session, EvidenceObligation], fn ->
               cancel_locked(locator, credentials, operation_id)
             end) do
        unwrap_cancel(result)
      else
        _ -> unavailable()
      end
    rescue
      _ -> unavailable()
    catch
      _, _ -> unavailable()
    end

    @doc "Expire one operation after its persisted deadline; retries return the terminal receipt."
    def expire(operation_id) do
      with {:ok, operation_id} <- Ecto.UUID.cast(operation_id),
           result <-
             Ash.transact([Account, Token, EvidenceObligation], fn ->
               expire_locked(operation_id)
             end) do
        unwrap_expire(result)
      else
        _ -> unavailable()
      end
    rescue
      _ -> unavailable()
    catch
      _, _ -> unavailable()
    end

    @doc "Expire a bounded batch of persisted due operations, safe to retry after restart."
    def expire_due(limit) when is_integer(limit) and limit in 1..500 do
      now = now_usec()

      operations =
        Account
        |> Ash.Query.filter(
          primary_email_change_state in [
            :requested,
            :reauthenticated,
            :new_address_pending,
            :confirmed,
            :delayed,
            :reviewed
          ] and primary_email_change_expires_at <= ^now
        )
        |> Ash.Query.sort(primary_email_change_expires_at: :asc)
        |> Ash.Query.limit(limit)
        |> Ash.read!(authorize?: false)
        |> Enum.map(& &1.primary_email_change_operation_id)

      results = Enum.map(operations, &expire/1)

      if Enum.all?(results, &match?({:ok, state} when state in [:expired, :already_expired], &1)) do
        {:ok, length(operations)}
      else
        unavailable()
      end
    rescue
      _ -> unavailable()
    end

    def expire_due(_), do: unavailable()

    @doc "Record a participant risk review after fresh password and current Session step-up."
    def review(credentials, password, operation_id) do
      with {:ok, locator} <- session_locator(credentials),
           {:ok, operation_id} <- Ecto.UUID.cast(operation_id),
           true <- is_binary(password) and byte_size(password) in 1..1024,
           result <-
             Ash.transact([Account, Token, Session, EvidenceObligation], fn ->
               review_locked(locator, credentials, password, operation_id)
             end) do
        unwrap_review(result)
      else
        _ -> unavailable()
      end
    rescue
      _ -> unavailable()
    catch
      _, _ -> unavailable()
    end

    @doc false
    # Communications-only transient re-signing seam. The caller must already be
    # inside its owner transaction and the capability must still be current.
    def delivery(reference, destination, locale) do
      with true <- NewYou.Repo.in_transaction?(),
           {:ok, %Token{} = locator} <- token(reference),
           {:ok, account} <- lock_account(locator.account_id),
           {:ok, proof} <- token(reference, true),
           true <- current_confirmation?(proof, account),
           true <- account.primary_email_change_target == destination,
           true <- account.primary_email_change_locale == locale,
           {:ok, bearer, claims} <-
             Joken.encode_and_sign(proof.email_change_claims, Config.token_signer(Account)),
           true <- claims == proof.email_change_claims,
           {:ok, ^claims, Account} <- Jwt.verify(bearer, Account) do
        {:ok, bearer}
      else
        {:error, _} -> {:error, :capability_unavailable}
        _ -> {:error, :source_invalid}
      end
    rescue
      _ -> {:error, :capability_unavailable}
    end

    defp request_locked(locator, credentials, target, locale, operation_id) do
      with {:ok, account} <- lock_account(locator.account_id),
           {:ok, session, token, claims} <- lock_current_session(locator, credentials, account),
           true <- eligible_account?(account),
           false <- secure_equal?(account.email, target),
           true <- available_target?(target, account.id) do
        checkpoint()
        request_or_supersede(account, session, token, claims, target, locale, operation_id)
      else
        _ -> unavailable()
      end
    end

    defp request_or_supersede(account, _session, _token, _claims, target, locale, operation_id)
         when account.primary_email_change_operation_id == operation_id do
      if account.primary_email_change_target == target and
           account.primary_email_change_locale == locale do
        {:ok, :requested}
      else
        unavailable()
      end
    end

    defp request_or_supersede(account, _session, _token, _claims, target, locale, operation_id) do
      now = now_usec()

      with :ok <- supersede_current_operation(account, now),
           {:ok, refreshed} <- lock_account(account.id),
           {:ok, requested} <-
             Ash.update(
               refreshed,
               %{
                 primary_email_change_operation_id: operation_id,
                 primary_email_change_target: target,
                 primary_email_change_locale: locale,
                 primary_email_change_requested_at: now,
                 primary_email_change_expires_at:
                   DateTime.add(now, @operation_lifetime_seconds, :second),
                 primary_email_change_security_version: refreshed.security_version,
                 primary_email_change_credential_version: refreshed.credential_version,
                 primary_email_change_reauth_session_id: nil,
                 primary_email_change_reauthenticated_at: nil,
                 primary_email_change_token_jti: nil,
                 primary_email_change_token_expires_at: nil,
                 primary_email_change_confirmed_at: nil,
                 primary_email_change_confirmation_id: nil,
                 primary_email_change_apply_after: nil,
                 primary_email_change_requires_review?: false,
                 primary_email_change_reviewed_at: nil,
                 primary_email_change_applied_at: nil,
                 primary_email_change_terminated_at: nil
               },
               action: :request_primary_email_change,
               authorize?: false
             ),
           {:ok, _} <-
             audit(requested, operation_id, :identity_primary_email_change_requested, now) do
        {:ok, :requested}
      else
        _ -> unavailable()
      end
    end

    defp supersede_current_operation(%Account{primary_email_change_state: state} = account, now)
         when state in [
                :requested,
                :reauthenticated,
                :new_address_pending,
                :confirmed,
                :delayed,
                :reviewed
              ] do
      with :ok <- supersede_proofs(account.id),
           {:ok, superseded} <-
             Ash.update(account, %{primary_email_change_terminated_at: now},
               action: :supersede_primary_email_change,
               authorize?: false
             ),
           {:ok, _} <-
             audit(
               superseded,
               account.primary_email_change_operation_id,
               :identity_primary_email_change_superseded,
               now
             ) do
        :ok
      else
        _ -> {:error, :email_change_unavailable}
      end
    end

    defp supersede_current_operation(_account, _now), do: :ok

    defp reauthenticate_locked(locator, credentials, password, operation_id) do
      with {:ok, account} <- lock_account(locator.account_id),
           {:ok, session, proof} <- lock_reauthentication_session(locator, credentials, account),
           true <- eligible_account?(account),
           true <- account.primary_email_change_operation_id == operation_id,
           :lt <- DateTime.compare(now_usec(), account.primary_email_change_expires_at),
           true <- account.primary_email_change_security_version == account.security_version,
           true <- account.primary_email_change_credential_version == account.credential_version,
           true <- Argon2Provider.valid?(password, account.hashed_password),
           true <- available_target?(account.primary_email_change_target, account.id),
           result <- reauthenticate_state(account, session, password, operation_id, proof) do
        result
      else
        _ -> unavailable()
      end
    end

    defp reauthenticate_state(
           %Account{primary_email_change_state: :requested} = account,
           session,
           _password,
           operation_id,
           _proof
         ) do
      if mfa_assurance?(session, account) do
        issue_new_confirmation(account, session, operation_id)
      else
        unavailable()
      end
    end

    defp reauthenticate_state(
           %Account{primary_email_change_state: :new_address_pending} = account,
           session,
           _password,
           operation_id,
           proof
         ) do
      retry_pending_confirmation(account, session, operation_id, proof)
    end

    defp reauthenticate_state(
           %Account{primary_email_change_state: state} = account,
           session,
           password,
           operation_id,
           proof
         )
         when state in [:delayed, :reviewed] do
      refresh_assurance(account, session, password, operation_id, proof)
    end

    defp reauthenticate_state(_account, _session, _password, _operation_id, _proof),
      do: unavailable()

    defp issue_new_confirmation(account, session, operation_id) do
      with true <- mfa_assurance?(session, account),
           now <- now_usec(),
           {:ok, step_up_session} <- set_step_up(session, account, now),
           {:ok, reauthenticated} <-
             Ash.update(
               account,
               %{
                 primary_email_change_reauthenticated_at: now,
                 primary_email_change_reauth_session_id: step_up_session.id,
                 primary_email_change_security_version: account.security_version,
                 primary_email_change_credential_version: account.credential_version
               },
               action: :reauthenticate_primary_email_change,
               authorize?: false
             ),
           {:ok, _result} <- issue_confirmation(reauthenticated, step_up_session, operation_id) do
        checkpoint()
        {:ok, :proof_pending}
      else
        _ -> unavailable()
      end
    end

    defp retry_pending_confirmation(account, session, operation_id, proof) do
      with true <- account.primary_email_change_reauth_session_id == session.id,
           true <- match?(%Token{}, proof),
           true <- current_confirmation?(proof, account),
           {:ok, intent} <-
             MessageIntent
             |> Ash.Query.filter(
               source_operation_id == ^operation_id and role == :email_change_confirmation
             )
             |> Ash.Query.lock(:for_update)
             |> Ash.read_one(authorize?: false),
           true <- intent.source_reference == proof.jti,
           true <- intent.destination == account.primary_email_change_target,
           true <- intent.locale == account.primary_email_change_locale,
           true <- intent.dispatch_disposition == :held do
        {:ok, :proof_pending}
      else
        _ -> unavailable()
      end
    end

    defp refresh_assurance(account, session, password, operation_id, proof) do
      now = now_usec()

      with true <-
             is_binary(password) and Argon2Provider.valid?(password, account.hashed_password),
           true <- mfa_assurance?(session, account),
           true <- current_consumed_confirmation?(proof, account, operation_id, now),
           {:ok, refreshed_session} <- refresh_session_assurance(session, account, now),
           {:ok, _refreshed} <-
             Ash.update(
               account,
               %{
                 primary_email_change_reauthenticated_at: now,
                 primary_email_change_reauth_session_id: refreshed_session.id,
                 primary_email_change_security_version: account.security_version,
                 primary_email_change_credential_version: account.credential_version
               },
               action: :refresh_primary_email_change_assurance,
               authorize?: false
             ) do
        {:ok, :assurance_refreshed}
      else
        _ -> unavailable()
      end
    end

    defp refresh_session_assurance(session, %{mfa_enrollment_state: :disabled} = account, now) do
      # Fresh password verification establishes purpose-bound step-up when no MFA factor exists.
      set_step_up(session, account, now)
    end

    defp refresh_session_assurance(session, %{mfa_enrollment_state: :active}, _now),
      do: {:ok, session}

    defp refresh_session_assurance(_session, _account, _now),
      do: {:error, :primary_email_change_unavailable}

    # Load every operation Token in JTI order before locking the Session. Rebinding
    # assurance after confirmation follows the same Account -> Token -> Session
    # order as final apply and cannot rely on a stale caller-loaded Session.
    defp lock_reauthentication_session(locator, credentials, account) do
      case account.primary_email_change_token_jti do
        proof_jti when is_binary(proof_jti) ->
          lock_current_session_and_confirmation(locator, credentials, account, proof_jti)

        _ ->
          with {:ok, session, _token, _claims} <-
                 lock_current_session(locator, credentials, account) do
            {:ok, session, nil}
          end
      end
    end

    defp lock_current_session_and_confirmation(locator, credentials, account, proof_jti) do
      token_jtis = Enum.sort(Enum.uniq([locator.jti, proof_jti]))

      tokens =
        Token
        |> Ash.Query.filter(account_id == ^account.id and jti in ^token_jtis)
        |> Ash.Query.sort(:jti)
        |> Ash.Query.lock(:for_update)
        |> Ash.read!(authorize?: false)

      auth_token = Enum.find(tokens, &(&1.jti == locator.jti))
      proof = Enum.find(tokens, &(&1.jti == proof_jti))

      with %Token{} = auth_token <- auth_token,
           %Token{} = proof <- proof,
           {:ok, [session]} <- lock_session(locator.session_id, account.id, locator.jti),
           {:ok, %{"sub" => subject, "jti" => jti}, Account} <-
             Jwt.verify(credentials.token, Account),
           true <- subject == locator.subject and jti == locator.jti,
           true <- subject == AshAuthentication.user_to_subject(account),
           true <-
             auth_token.subject == subject and auth_token.purpose == "user" and
               before?(auth_token.expires_at),
           true <-
             session.state == :active and before?(session.expires_at) and
               before?(session.idle_expires_at) do
        {:ok, session, proof}
      else
        _ -> {:error, :authentication_unavailable}
      end
    end

    defp issue_confirmation(account, session, operation_id) do
      with {:ok, bearer, claims} <-
             Joken.generate_and_sign(
               Config.default_claims(Account, token_lifetime: @proof_lifetime),
               %{
                 "sub" => AshAuthentication.user_to_subject(account),
                 "purpose" => "email_change_confirmation",
                 "locale" => account.primary_email_change_locale,
                 "operation_id" => operation_id
               },
               Config.token_signer(Account)
             ),
           {:ok, proof} <-
             Ash.create(
               Token,
               %{
                 token: bearer,
                 email_change_operation_id: operation_id,
                 email_change_claims: claims,
                 email_change_account_binding: account_binding(account, operation_id),
                 email_change_locale: account.primary_email_change_locale
               },
               action: :issue_email_change_confirmation,
               authorize?: false,
               context: %{ash_authentication: %{user: account}}
             ),
           {:ok, pending} <-
             Ash.update(
               account,
               %{
                 primary_email_change_token_jti: proof.jti,
                 primary_email_change_token_expires_at: proof.expires_at
               },
               action: :issue_primary_email_change_confirmation,
               authorize?: false
             ),
           {:ok, _intent} <-
             NewYou.Communications.establish_primary_email_change_confirmation(%{
               source_operation_id: operation_id,
               source_reference: proof.jti,
               role: :email_change_confirmation,
               source_purpose: "email_change_confirmation",
               render_schema: "email-change-confirmation-v1",
               destination: account.primary_email_change_target,
               destination_provenance: "identity_primary_email_change_issuance",
               destination_authorized_at: proof.created_at,
               locale: account.primary_email_change_locale
             }) do
        {:ok, %{account: pending, session: session, proof: proof}}
      else
        _ -> {:error, :email_change_unavailable}
      end
    end

    defp set_step_up(session, account, now) do
      Ash.update(
        session,
        %{
          step_up_purpose: :change_primary_email,
          step_up_at: now,
          step_up_expires_at: DateTime.add(now, @step_up_seconds, :second),
          step_up_mfa_version: account.mfa_version,
          step_up_security_version: account.security_version
        },
        action: :set_step_up,
        authorize?: false
      )
    end

    defp mfa_assurance?(
           %{step_up_purpose: :change_primary_email} = session,
           %{mfa_enrollment_state: :active} = account
         ) do
      now = now_usec()

      not is_nil(session.step_up_at) and not is_nil(session.step_up_expires_at) and
        DateTime.compare(now, session.step_up_at) != :lt and
        DateTime.compare(now, session.step_up_expires_at) == :lt and
        session.step_up_mfa_version == account.mfa_version and
        session.step_up_security_version == account.security_version
    end

    defp mfa_assurance?(_session, %{mfa_enrollment_state: :active}), do: false

    defp mfa_assurance?(_session, %{mfa_enrollment_state: :pending}), do: false

    defp mfa_assurance?(_session, _account), do: true

    defp supersede_proofs(account_id) do
      Token
      |> Ash.Query.filter(account_id == ^account_id and purpose == "email_change_confirmation")
      |> Ash.Query.sort(:jti)
      |> Ash.Query.lock(:for_update)
      |> Ash.read!(authorize?: false)
      |> Enum.reduce_while(:ok, fn proof, :ok ->
        case Ash.update(proof, %{},
               action: :supersede_email_change_confirmation,
               authorize?: false
             ) do
          {:ok, _} -> {:cont, :ok}
          _ -> {:halt, {:error, :email_change_unavailable}}
        end
      end)
    end

    defp available_target?(email, account_id) do
      Account
      |> Ash.Query.filter(email == ^email and id != ^account_id)
      |> Ash.read_one(authorize?: false)
      |> case do
        {:ok, nil} -> true
        _ -> false
      end
    end

    defp lock_current_session(locator, credentials, account) do
      with {:ok, [token]} <- lock_user_token(locator.jti, account.id),
           {:ok, [session]} <- lock_session(locator.session_id, account.id, locator.jti),
           {:ok, %{"sub" => subject, "jti" => jti}, Account} <-
             Jwt.verify(credentials.token, Account),
           true <- subject == locator.subject and jti == locator.jti,
           true <- subject == AshAuthentication.user_to_subject(account),
           true <-
             token.subject == subject and token.purpose == "user" and before?(token.expires_at),
           true <-
             session.state == :active and before?(session.expires_at) and
               before?(session.idle_expires_at) do
        {:ok, session, token, %{"sub" => subject, "jti" => jti}}
      else
        _ -> {:error, :authentication_unavailable}
      end
    end

    defp session_locator(%{session_id: session_id, token: bearer})
         when is_binary(session_id) and is_binary(bearer) and byte_size(bearer) in 1..8192 do
      with {:ok, %{"sub" => subject, "jti" => jti}, Account} <- Jwt.verify(bearer, Account),
           {:ok, session_id} <- Ecto.UUID.cast(session_id),
           {:ok, session} when not is_nil(session) <-
             Ash.get(Session, session_id, authorize?: false),
           true <- session.token_jti == jti do
        {:ok,
         %{account_id: session.account_id, session_id: session_id, subject: subject, jti: jti}}
      else
        _ -> {:error, :authentication_unavailable}
      end
    end

    defp session_locator(_), do: {:error, :authentication_unavailable}

    defp lock_account(id),
      do:
        Account
        |> Ash.Query.filter(id == ^id)
        |> Ash.Query.lock(:for_update)
        |> Ash.read_one(authorize?: false)

    defp lock_session(id, account_id, jti),
      do:
        Session
        |> Ash.Query.filter(id == ^id and account_id == ^account_id and token_jti == ^jti)
        |> Ash.Query.lock(:for_update)
        |> Ash.read(authorize?: false)

    defp lock_user_token(jti, account_id),
      do:
        Token
        |> Ash.Query.filter(jti == ^jti and account_id == ^account_id and purpose == "user")
        |> Ash.Query.lock(:for_update)
        |> Ash.read(authorize?: false)

    defp eligible_account?(account),
      do:
        account.email_verified? and account.credential_status == :active and
          account.account_status == :open and account.security_posture == :normal

    defp account_binding(account, operation_id) do
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
          {"primary-email-change:v1", account.id, account.email,
           account.primary_email_change_target, operation_id, account.credential_version,
           account.security_version, account.email_verified?, account.credential_status,
           account.account_status, account.security_posture},
          [:deterministic]
        )
      )
    end

    defp confirm_locked(account_id, bearer, claims, operation_id) do
      with {:ok, account} <- lock_account(account_id),
           {:ok, proof} <- token(claims["jti"], true),
           {:ok, current_claims} <- confirmation_claims(bearer),
           true <- current_claims == claims,
           true <-
             claims["operation_id"] == Ecto.UUID.cast!(account.primary_email_change_operation_id),
           true <- account.primary_email_change_operation_id == operation_id,
           true <- current_confirmation?(proof, account),
           true <- available_target?(account.primary_email_change_target, account.id),
           now <- now_usec(),
           confirmation_id <- Ecto.UUID.generate(),
           {:ok, _consumed} <-
             Ash.update(proof, %{}, action: :consume_email_change_confirmation, authorize?: false),
           {:ok, confirmed} <-
             Ash.update(
               account,
               %{
                 primary_email_change_confirmed_at: now,
                 primary_email_change_confirmation_id: confirmation_id
               },
               action: :confirm_primary_email_change,
               authorize?: false
             ),
           {:ok, ready} <- schedule_application(confirmed, now),
           {:ok, _} <-
             audit(ready, operation_id, :identity_primary_email_change_confirmed, now) do
        checkpoint()
        {:ok, :confirmed}
      else
        _ -> unavailable()
      end
    end

    defp schedule_application(account, now) do
      case Application.get_env(:new_you, :p8_16_primary_email_change_policy) do
        %{delay_seconds: seconds, requires_review?: requires_review?}
        when is_integer(seconds) and seconds >= 0 and is_boolean(requires_review?) ->
          Ash.update(
            account,
            %{
              primary_email_change_apply_after: DateTime.add(now, seconds, :second),
              primary_email_change_requires_review?: requires_review?
            },
            action: :delay_primary_email_change,
            authorize?: false
          )

        _ ->
          {:ok, account}
      end
    end

    defp apply_locked(operation_id) do
      case lock_account_by_operation(operation_id) do
        {:ok, account} -> apply_current_state(account, operation_id)
        _ -> unavailable()
      end
    end

    defp apply_current_state(%{primary_email_change_state: :applied}, _operation_id),
      do: {:ok, :already_applied}

    defp apply_current_state(%{primary_email_change_state: :held}, _operation_id),
      do: {:ok, :already_held}

    defp apply_current_state(%{primary_email_change_state: :rejected}, _operation_id),
      do: {:ok, :already_rejected}

    defp apply_current_state(%{primary_email_change_state: state} = account, operation_id)
         when state in [
                :requested,
                :reauthenticated,
                :new_address_pending,
                :confirmed,
                :delayed,
                :reviewed
              ] do
      if account.security_posture == :held do
        hold_current(account, operation_id)
      else
        apply_current(account, operation_id)
      end
    end

    defp apply_current_state(_account, _operation_id), do: unavailable()

    defp hold_current(account, operation_id) do
      now = now_usec()

      with :ok <- revoke_current_proof(account),
           {:ok, held} <-
             Ash.update(
               account,
               %{primary_email_change_terminated_at: now},
               action: :hold_primary_email_change,
               authorize?: false
             ),
           {:ok, _} <- audit(held, operation_id, :identity_primary_email_change_held, now) do
        checkpoint()
        {:ok, :held}
      else
        _ -> unavailable()
      end
    end

    defp cancel_locked(locator, credentials, operation_id) do
      case lock_account(locator.account_id) do
        {:ok, account} -> cancel_with_current_session(locator, credentials, operation_id, account)
        _ -> unavailable()
      end
    end

    defp cancel_with_current_session(locator, credentials, operation_id, account) do
      case lock_current_session(locator, credentials, account) do
        {:ok, _session, _token, _claims} -> cancel_current(account, operation_id)
        _ -> unavailable()
      end
    end

    defp cancel_current(account, operation_id) do
      if account.primary_email_change_operation_id == operation_id do
        cancel_state(account, operation_id)
      else
        unavailable()
      end
    end

    defp cancel_state(%{primary_email_change_state: :cancelled}, _operation_id),
      do: {:ok, :already_cancelled}

    defp cancel_state(%{primary_email_change_state: state} = account, operation_id)
         when state in [
                :requested,
                :reauthenticated,
                :new_address_pending,
                :confirmed,
                :delayed,
                :reviewed
              ],
         do: cancel_active(account, operation_id)

    defp cancel_state(_account, _operation_id), do: unavailable()

    defp cancel_active(account, operation_id) do
      now = now_usec()

      with :ok <- revoke_current_proof(account),
           {:ok, cancelled} <-
             Ash.update(
               account,
               %{primary_email_change_terminated_at: now},
               action: :cancel_primary_email_change,
               authorize?: false
             ),
           {:ok, _} <-
             audit(cancelled, operation_id, :identity_primary_email_change_cancelled, now) do
        checkpoint()
        {:ok, :cancelled}
      else
        _ -> unavailable()
      end
    end

    defp review_locked(locator, credentials, password, operation_id) do
      with {:ok, account} <- lock_account(locator.account_id),
           {:ok, session, _token, _claims} <- lock_current_session(locator, credentials, account),
           true <- account.primary_email_change_operation_id == operation_id do
        case account.primary_email_change_state do
          :reviewed when account.primary_email_change_requires_review? ->
            {:ok, :already_reviewed}

          :delayed when account.primary_email_change_requires_review? ->
            review_current_operation(account, session, password, operation_id)

          _ ->
            unavailable()
        end
      else
        _ -> unavailable()
      end
    end

    defp review_current_operation(account, session, password, operation_id) do
      now = now_usec()

      with true <- account.primary_email_change_reauth_session_id == session.id,
           true <- eligible_account?(account),
           true <- account.primary_email_change_security_version == account.security_version,
           true <- account.primary_email_change_credential_version == account.credential_version,
           true <- Argon2Provider.valid?(password, account.hashed_password),
           true <- review_step_up?(session, account),
           true <- apply_due?(account, now),
           {:ok, proof} <- token(account.primary_email_change_token_jti, true),
           true <- current_consumed_confirmation?(proof, account, operation_id, now),
           true <- available_target?(account.primary_email_change_target, account.id),
           {:ok, _reviewed_session} <- set_step_up(session, account, now),
           {:ok, reviewed} <-
             Ash.update(
               account,
               %{primary_email_change_reviewed_at: now},
               action: :review_primary_email_change,
               authorize?: false
             ),
           {:ok, _} <- audit(reviewed, operation_id, :identity_primary_email_change_reviewed, now) do
        checkpoint()
        {:ok, :reviewed}
      else
        _ -> unavailable()
      end
    end

    defp expire_locked(operation_id) do
      case lock_account_by_operation(operation_id) do
        {:ok, account} -> expire_current_state(account, operation_id)
        _ -> unavailable()
      end
    end

    defp expire_current_state(%{primary_email_change_state: :expired}, _operation_id),
      do: {:ok, :already_expired}

    defp expire_current_state(%{primary_email_change_state: state} = account, operation_id)
         when state in [
                :requested,
                :reauthenticated,
                :new_address_pending,
                :confirmed,
                :delayed,
                :reviewed
              ] do
      if before?(account.primary_email_change_expires_at) do
        {:ok, :not_expired}
      else
        expire_current(account, operation_id)
      end
    end

    defp expire_current_state(_account, _operation_id), do: unavailable()

    defp expire_current(account, operation_id) do
      now = now_usec()

      with :ok <- revoke_current_proof(account),
           {:ok, expired} <-
             Ash.update(
               account,
               %{primary_email_change_terminated_at: now},
               action: :expire_primary_email_change,
               authorize?: false
             ),
           {:ok, _} <- audit(expired, operation_id, :identity_primary_email_change_expired, now) do
        checkpoint()
        {:ok, :expired}
      else
        _ -> unavailable()
      end
    end

    defp revoke_current_proof(%{primary_email_change_token_jti: nil}), do: :ok

    defp revoke_current_proof(account) do
      with {:ok, proof} <- token(account.primary_email_change_token_jti, true),
           true <- proof.account_id == account.id,
           true <- proof.email_change_operation_id == account.primary_email_change_operation_id,
           {:ok, _} <-
             Ash.update(proof, %{},
               action: :revoke_email_change_confirmation,
               authorize?: false
             ) do
        :ok
      else
        _ -> {:error, :email_change_unavailable}
      end
    end

    defp apply_current(account, operation_id) do
      now = now_usec()

      with true <- account.primary_email_change_operation_id == operation_id,
           true <- account.primary_email_change_state in [:delayed, :reviewed],
           true <- application_reviewed?(account),
           {:ok, {session, auth_token, proof}} <- lock_apply_authority(account),
           true <- current_apply_authority?(session, auth_token, account),
           true <- current_consumed_confirmation?(proof, account, operation_id, now),
           :ok <- current_privacy_proof_purpose(account, operation_id) do
        if available_target?(account.primary_email_change_target, account.id) do
          commit_apply(account, proof, operation_id, now)
        else
          reject_current(account, operation_id, now)
        end
      else
        _ -> unavailable()
      end
    end

    defp lock_apply_authority(account) do
      with {:ok, %Session{id: session_id, token_jti: session_jti}} <-
             session_reference(account),
           proof_jti when is_binary(proof_jti) <- account.primary_email_change_token_jti,
           {:ok, active_session_jtis} <- active_session_jtis(account.id),
           jtis <- Enum.sort(Enum.uniq([session_jti, proof_jti | active_session_jtis])),
           {:ok, tokens} <- lock_tokens(account.id, jtis),
           tokens_by_jti <- Map.new(tokens, &{&1.jti, &1}),
           %Token{} = auth_token <- Map.get(tokens_by_jti, session_jti),
           %Token{} = proof <- Map.get(tokens_by_jti, proof_jti),
           {:ok, sessions} <- lock_apply_sessions(account.id, session_id),
           %Session{} = session <- Enum.find(sessions, &(&1.id == session_id)),
           true <- session.token_jti == session_jti do
        {:ok, {session, auth_token, proof}}
      else
        _ -> {:error, :email_change_unavailable}
      end
    end

    # This unlocked read supplies only the Session's immutable token JTI. Apply
    # locks that Token with the proof Token, then reloads and locks the Session
    # before evaluating any Session or step-up authority.
    defp session_reference(account) do
      Session
      |> Ash.Query.filter(
        id == ^account.primary_email_change_reauth_session_id and account_id == ^account.id
      )
      |> Ash.read_one(authorize?: false)
    end

    # These JTIs are lock locators only. The final authority check uses Session
    # rows reloaded under lock after all related Token rows are locked.
    defp active_session_jtis(account_id) do
      Session
      |> Ash.Query.filter(account_id == ^account_id and state == :active)
      |> Ash.Query.sort(:id)
      |> Ash.read(authorize?: false)
      |> case do
        {:ok, sessions} -> {:ok, Enum.map(sessions, & &1.token_jti)}
        _ -> {:error, :email_change_unavailable}
      end
    end

    defp lock_apply_sessions(account_id, operation_session_id) do
      Session
      |> Ash.Query.filter(
        account_id == ^account_id and
          (state == :active or id == ^operation_session_id)
      )
      |> Ash.Query.sort(:id)
      |> Ash.Query.lock(:for_update)
      |> Ash.read(authorize?: false)
    end

    defp lock_tokens(account_id, jtis) do
      Token
      |> Ash.Query.filter(account_id == ^account_id and jti in ^jtis)
      |> Ash.Query.sort(:jti)
      |> Ash.Query.lock(:for_update)
      |> Ash.read(authorize?: false)
    end

    defp current_apply_authority?(session, auth_token, account) do
      session_is_operation_bound?(session, auth_token, account) and
        session_is_current?(session) and auth_token_is_current?(auth_token, account) and
        current_email_change_assurance?(session, account)
    end

    defp session_is_operation_bound?(session, auth_token, account) do
      session.id == account.primary_email_change_reauth_session_id and
        session.account_id == account.id and session.token_jti == auth_token.jti
    end

    defp session_is_current?(session) do
      session.state == :active and before?(session.expires_at) and
        before?(session.idle_expires_at)
    end

    defp auth_token_is_current?(auth_token, account) do
      auth_token.account_id == account.id and
        auth_token.subject == AshAuthentication.user_to_subject(account) and
        auth_token.purpose == "user" and before?(auth_token.expires_at)
    end

    defp current_email_change_assurance?(session, %{mfa_enrollment_state: :active} = account),
      do: current_email_change_step_up?(session, account)

    defp current_email_change_assurance?(session, %{mfa_enrollment_state: :disabled} = account),
      do: current_email_change_step_up?(session, account)

    defp current_email_change_assurance?(_session, _account), do: false

    defp commit_apply(account, proof, operation_id, now) do
      with {:ok, applied} <-
             Ash.update(
               account,
               %{
                 email: account.primary_email_change_target,
                 email_verified?: true,
                 primary_email_change_applied_at: now,
                 primary_email_change_terminated_at: now
               },
               action: :apply_primary_email_change,
               authorize?: false
             ),
           :ok <- NewYou.Identity.Recovery.invalidate_sessions_and_devices(account.id),
           {:ok, _notice} <-
             NewYou.Communications.establish_primary_email_change_notice(%{
               source_operation_id: operation_id,
               source_reference: proof.jti,
               role: :email_change_old_address_notice,
               destination: account.email,
               destination_provenance: "identity_primary_email_change_old_address",
               destination_authorized_at: now,
               locale: account.primary_email_change_locale
             }),
           {:ok, _} <-
             audit(applied, operation_id, :identity_primary_email_change_applied, now) do
        checkpoint()
        {:ok, :applied}
      else
        _ -> unavailable()
      end
    end

    defp reject_current(account, operation_id, now) do
      with :ok <- revoke_current_proof(account),
           {:ok, rejected} <-
             Ash.update(
               account,
               %{primary_email_change_terminated_at: now},
               action: :reject_primary_email_change,
               authorize?: false
             ),
           {:ok, _} <-
             audit(rejected, operation_id, :identity_primary_email_change_rejected, now) do
        checkpoint()
        {:ok, :rejected}
      else
        _ -> unavailable()
      end
    end

    defp current_consumed_confirmation?(proof, account, operation_id, now) do
      proof_matches_operation?(
        proof,
        account,
        operation_id,
        "email_change_confirmation_consumed"
      ) and
        email_change_claims_match?(proof, account, operation_id) and
        consumed_confirmation_current?(proof, account, now) and
        proof_binding_matches?(proof, account, operation_id)
    end

    defp application_reviewed?(%{primary_email_change_requires_review?: false} = account),
      do:
        account.primary_email_change_state == :delayed and
          not is_nil(account.primary_email_change_apply_after)

    defp application_reviewed?(%{primary_email_change_requires_review?: true} = account),
      do:
        account.primary_email_change_state == :reviewed and
          not is_nil(account.primary_email_change_reviewed_at) and
          not is_nil(account.primary_email_change_apply_after)

    defp application_reviewed?(_), do: false

    defp apply_due?(account, now) do
      not is_nil(account.primary_email_change_apply_after) and
        DateTime.compare(now, account.primary_email_change_apply_after) != :lt
    end

    defp review_step_up?(_session, %{mfa_enrollment_state: :disabled}), do: true
    defp review_step_up?(_session, %{mfa_enrollment_state: :pending}), do: false

    defp review_step_up?(session, %{mfa_enrollment_state: :active} = account) do
      current_email_change_step_up?(session, account) and mfa_assurance?(session, account)
    end

    defp current_email_change_step_up?(session, account) do
      now = now_usec()

      session.step_up_purpose == :change_primary_email and not is_nil(session.step_up_at) and
        not is_nil(session.step_up_expires_at) and
        DateTime.compare(now, session.step_up_at) != :lt and
        DateTime.compare(now, session.step_up_expires_at) == :lt and
        session.step_up_mfa_version == account.mfa_version and
        session.step_up_security_version == account.security_version
    end

    defp lock_account_by_operation(operation_id),
      do:
        Account
        |> Ash.Query.filter(primary_email_change_operation_id == ^operation_id)
        |> Ash.Query.lock(:for_update)
        |> Ash.read_one(authorize?: false)

    defp confirmation_claims(bearer) do
      case Jwt.verify(bearer, Account) do
        {:ok,
         %{
           "purpose" => "email_change_confirmation",
           "sub" => _subject,
           "jti" => jti,
           "operation_id" => operation_id,
           "locale" => locale
         } = claims, Account}
        when is_binary(jti) and locale in ["en", "af"] ->
          with {:ok, _} <- Ecto.UUID.cast(operation_id), do: {:ok, claims}

        _ ->
          {:error, :proof_unavailable}
      end
    end

    defp current_confirmation?(%Token{} = proof, %Account{} = account) do
      operation_id = account.primary_email_change_operation_id

      proof_matches_operation?(proof, account, operation_id, "email_change_confirmation") and
        email_change_claims_match?(proof, account, operation_id) and
        confirmation_authority_current?(proof, account) and
        proof_binding_matches?(proof, account, operation_id)
    end

    defp current_confirmation?(_, _), do: false

    defp proof_matches_operation?(proof, account, operation_id, purpose) do
      proof.account_id == account.id and proof.purpose == purpose and
        proof.email_change_operation_id == operation_id and
        proof.jti == account.primary_email_change_token_jti and
        proof.email_change_locale == account.primary_email_change_locale
    end

    defp email_change_claims_match?(proof, account, operation_id) do
      claims = proof.email_change_claims

      claims["purpose"] == "email_change_confirmation" and
        claims["operation_id"] == operation_id and claims["jti"] == proof.jti and
        claims["sub"] == AshAuthentication.user_to_subject(account) and
        claims["locale"] == account.primary_email_change_locale and
        claims["exp"] == DateTime.to_unix(proof.expires_at)
    end

    defp consumed_confirmation_current?(proof, account, now) do
      account.primary_email_change_confirmation_id != nil and
        account_change_versions_match?(account) and apply_due?(account, now) and
        before?(account.primary_email_change_expires_at) and before?(proof.expires_at) and
        eligible_account?(account)
    end

    defp confirmation_authority_current?(proof, account) do
      account.primary_email_change_state == :new_address_pending and
        account_change_versions_match?(account) and eligible_account?(account) and
        before?(proof.expires_at)
    end

    defp account_change_versions_match?(account) do
      account.primary_email_change_security_version == account.security_version and
        account.primary_email_change_credential_version == account.credential_version
    end

    defp proof_binding_matches?(proof, account, operation_id) do
      secure_equal?(
        proof.email_change_account_binding,
        account_binding(account, operation_id)
      )
    end

    defp secure_equal?(left, right)
         when is_binary(left) and is_binary(right) and byte_size(left) == byte_size(right),
         do: Plug.Crypto.secure_compare(left, right)

    defp secure_equal?(_, _), do: false

    defp token(jti, lock? \\ false) do
      query = Ash.Query.filter(Token, jti == ^jti)
      query = if lock?, do: Ash.Query.lock(query, :for_update), else: query
      Ash.read_one(query, authorize?: false)
    end

    defp audit(account, operation_id, event, occurred_at) do
      NewYou.Audit.establish_identity_security_obligation(%{
        source_operation_id: operation_id,
        source_occurred_at: occurred_at,
        evidence_type: event,
        actor_id: account.id,
        target_id: account.id,
        outcome: :succeeded
      })
    end

    defp before?(date), do: DateTime.compare(now_usec(), date) == :lt
    defp now_usec, do: DateTime.utc_now() |> DateTime.truncate(:microsecond)

    defp unwrap({:ok, {:ok, result}}, result), do: {:ok, result}
    defp unwrap({:ok, result}, result), do: {:ok, result}
    defp unwrap(_, _), do: unavailable()

    defp unwrap_reauthenticate({:ok, {:ok, result}})
         when result in [:proof_pending, :assurance_refreshed],
         do: {:ok, result}

    defp unwrap_reauthenticate({:ok, result})
         when result in [:proof_pending, :assurance_refreshed],
         do: {:ok, result}

    defp unwrap_reauthenticate(_), do: unavailable()

    defp unwrap_apply({:ok, {:ok, result}}), do: {:ok, result}

    defp unwrap_apply({:ok, result})
         when result in [
                :applied,
                :already_applied,
                :held,
                :already_held,
                :rejected,
                :already_rejected
              ],
         do: {:ok, result}

    defp unwrap_apply(_), do: unavailable()

    defp unwrap_cancel({:ok, {:ok, result}}) when result in [:cancelled, :already_cancelled],
      do: {:ok, result}

    defp unwrap_cancel({:ok, result}) when result in [:cancelled, :already_cancelled],
      do: {:ok, result}

    defp unwrap_cancel(_), do: unavailable()

    defp unwrap_expire({:ok, {:ok, result}})
         when result in [:expired, :already_expired, :not_expired],
         do: {:ok, result}

    defp unwrap_expire({:ok, result}) when result in [:expired, :already_expired, :not_expired],
      do: {:ok, result}

    defp unwrap_expire(_), do: unavailable()

    defp unwrap_review({:ok, {:ok, result}}) when result in [:reviewed, :already_reviewed],
      do: {:ok, result}

    defp unwrap_review({:ok, result}) when result in [:reviewed, :already_reviewed],
      do: {:ok, result}

    defp unwrap_review(_), do: unavailable()

    defp unavailable, do: {:error, :primary_email_change_unavailable}

    if Mix.env() == :test do
      defp checkpoint, do: NewYou.Proof.RegistrationSeam.checkpoint()
    else
      defp checkpoint, do: :ok
    end
  else
    def request(_, _, _, _), do: {:error, :primary_email_change_unavailable}
    def reauthenticate(_, _, _), do: {:error, :primary_email_change_unavailable}
    def confirm(_), do: {:error, :primary_email_change_unavailable}
    def apply(_), do: {:error, :primary_email_change_unavailable}
    def cancel(_, _), do: {:error, :primary_email_change_unavailable}
    def expire(_), do: {:error, :primary_email_change_unavailable}
    def expire_due(_), do: {:error, :primary_email_change_unavailable}
    def review(_, _, _), do: {:error, :primary_email_change_unavailable}
    def delivery(_, _, _), do: {:error, :source_invalid}
  end

  if Mix.env() in [:dev, :test] do
    defp current_privacy_proof_purpose(account, operation_id) do
      if Application.get_env(:new_you, :p8_17_test_proof_purpose?) == true do
        with :ok <- privacy_checkpoint(:before_current_read),
             :ok <-
               NewYou.Privacy.require_current_p817_proof_purpose_locked(
                 account.id,
                 operation_id
               ),
             :ok <- privacy_checkpoint(:after_current_read) do
          :ok
        else
          _ -> {:error, :privacy_authority_denied}
        end
      else
        :ok
      end
    rescue
      _ -> {:error, :privacy_authority_unavailable}
    catch
      _, _ -> {:error, :privacy_authority_unavailable}
    end

    if Mix.env() == :test do
      defp privacy_checkpoint(point), do: NewYou.Proof.P817PrivacySeam.checkpoint(point)
    else
      defp privacy_checkpoint(_point), do: :ok
    end
  else
    defp current_privacy_proof_purpose(_account, _operation_id), do: :ok
  end
end
