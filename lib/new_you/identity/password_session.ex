defmodule NewYou.Identity.PasswordSession do
  @moduledoc false
  require Ash.Query

  alias AshAuthentication.{Argon2Provider, Jwt}

  alias NewYou.Identity.{
    Account,
    Email,
    IdentityGrant,
    PMR,
    PrivilegedAccess,
    Session,
    SessionRevocation,
    Token
  }

  @session_page_size 20
  @revocation_rollback "Audit rejected Session revocation evidence"
  @global_rollback "Global Session revocation rolled back before commit"
  @global_proof_expired "Global Session revocation proof expired before use"
  @idle_seconds 30 * 60

  def authenticate(email, password) when is_binary(password) and byte_size(password) <= 1024 do
    with {:ok, email} <- Email.canonicalize(email),
         {:ok, account} <- find_account(email),
         true <- Argon2Provider.valid?(password, account.hashed_password) do
      issue(account, email)
    else
      _ -> {:error, :authentication_unavailable}
    end
  rescue
    _ -> {:error, :authentication_unavailable}
  end

  def authenticate(_, _), do: {:error, :authentication_unavailable}

  defp find_account(email) do
    case Account |> Ash.Query.filter(email == ^email) |> Ash.read(authorize?: false) do
      {:ok, [account]} ->
        {:ok, account}

      _ ->
        Argon2Provider.simulate()
        {:error, :authentication_unavailable}
    end
  end

  defp issue(account, email) do
    case Ash.transact([Account, Token, Session], fn -> issue_locked(account, email) end) do
      {:ok, {:ok, credentials}} -> {:ok, credentials}
      {:ok, credentials} when is_map(credentials) -> {:ok, credentials}
      _ -> {:error, :authentication_unavailable}
    end
  end

  defp issue_locked(account, email) do
    with {:ok, [current]} <-
           Account
           |> Ash.Query.filter(id == ^account.id)
           |> Ash.Query.lock(:for_update)
           |> Ash.read(authorize?: false),
         true <- current.email == email,
         true <- eligible?(current),
         true <- current.hashed_password == account.hashed_password,
         {:ok, credentials} <- issue_current(current) do
      checkpoint()
      {:ok, credentials}
    else
      _ -> {:error, :authentication_unavailable}
    end
  end

  @doc false
  # Internal Identity seam. Caller holds the current eligible Account lock in the
  # same Token/Session transaction. Shared issuance preserves password semantics.
  def issue_current(current, provenance \\ %{}) do
    with {:ok, bearer, claims} <-
           Jwt.token_for_user(current, %{}, purpose: :user, authorize?: false),
         {:ok, expires_at} <- DateTime.from_unix(claims["exp"]),
         now <- DateTime.utc_now() |> DateTime.truncate(:second),
         {:ok, session} <-
           Ash.create(
             Session,
             Map.merge(
               %{
                 account_id: current.id,
                 token_jti: claims["jti"],
                 expires_at: expires_at,
                 idle_expires_at: DateTime.add(now, @idle_seconds),
                 last_seen_at: now
               },
               provenance
             ),
             action: :issue,
             authorize?: false
           ) do
      {:ok, %{session_id: session.id, token: bearer}}
    else
      _ -> {:error, :authentication_unavailable}
    end
  end

  def authorize(credentials) do
    case with_current_session(credentials, fn session, account, _token, _linked ->
           validate_and_touch(session, account)
         end) do
      {:ok, %Account{id: id}} -> {:ok, %{account_id: id}}
      _ -> {:error, :authentication_unavailable}
    end
  end

  def self_member_reference(credentials) do
    case with_current_session(credentials, &member_reference_locked/4) do
      {:ok, {:member_reference, pmr}} -> {:ok, pmr}
      _ -> {:error, :authentication_unavailable}
    end
  end

  defp member_reference_locked(session, account, _token, _linked) do
    with %Account{canonical_account_id: nil, pmr_status: :active, pmr: pmr} <- account,
         true <- PMR.valid?(pmr),
         {:ok, %Account{}} <- validate_and_touch(session, account) do
      {:member_reference, pmr}
    else
      _ -> :denied
    end
  end

  def list_active(credentials, cursor) do
    with {:ok, cursor} <- optional_cursor(cursor),
         {:ok, {:listed, page}} <-
           with_current_session(credentials, fn session, account, token, _linked ->
             active_page(session, account, token, cursor)
           end) do
      {:ok, page}
    else
      _ -> {:error, :authentication_unavailable}
    end
  end

  def revoke_other(credentials, target_id) do
    case Ecto.UUID.cast(target_id) do
      {:ok, id} ->
        credentials
        |> with_current_session(fn session, account, token, _linked ->
          revoke_other_locked(session, account, token, id)
        end)
        |> revocation_result()

      :error ->
        {:error, :session_unavailable}
    end
  end

  def global_revocation_form(credentials) do
    case with_current_session(credentials, &global_form_locked/4) do
      {:ok, {:form, form}} -> {:ok, form}
      _ -> {:error, :session_unavailable}
    end
  end

  defp global_form_locked(session, account, _token, _linked) do
    with true <- usable_deadlines?(session),
         {:ok, mfa_required?} <- ordinary_revocation_factor(account) do
      {:form, %{session_id: session.id, mfa_required?: mfa_required?}}
    else
      _ -> :denied
    end
  end

  def revoke_all(credentials, password, code) do
    credentials
    |> with_current_session(&revoke_all_locked(&1, &2, &3, &4, password, code), :all)
    |> revocation_result()
  end

  defp revoke_all_locked(session, account, token, linked, password, code) do
    with true <- usable_deadlines?(session),
         {:ok, _mfa_required?} <- ordinary_revocation_factor(account),
         :ok <- PrivilegedAccess.step_up_for_revocation(account, session, password, code) do
      finish_global_revocation(session, account, token, linked)
    else
      {:denied, _reason} -> :denied
      false -> :denied
      {:error, :ineligible} -> :denied
      {:error, _} -> {:error, @global_rollback}
    end
  rescue
    _ -> {:error, @global_rollback}
  end

  defp ordinary_revocation_factor(account) do
    with true <- account.mfa_enrollment_state in [:disabled, :active],
         {:ok, false} <-
           IdentityGrant
           |> Ash.Query.filter(
             subject_account_id == ^account.id and state == :active and expires_at > now()
           )
           |> Ash.exists(authorize?: false) do
      {:ok, account.mfa_enrollment_state == :active}
    else
      false -> {:error, :ineligible}
      {:ok, true} -> {:error, :ineligible}
      {:error, _} = error -> error
    end
  end

  defp finish_global_revocation(session, account, token, linked) do
    with {:ok, %Session{} = verified} <- Ash.get(Session, session.id, authorize?: false),
         true <- usable_deadlines?(verified) and future?(token.expires_at),
         true <- PrivilegedAccess.current_revocation_step_up?(verified, account),
         :ok <- SessionRevocation.revoke_sessions(account.id, linked),
         :ok <- SessionRevocation.revoke_devices(account.id),
         {:ok, _} <-
           NewYou.Audit.establish_identity_security_obligation(%{
             source_operation_id: session.id,
             source_occurred_at: DateTime.utc_now(),
             evidence_type: :identity_session_revoked,
             actor_id: account.id,
             target_id: account.id,
             outcome: :succeeded
           }) do
      checkpoint()
      :revoked
    else
      false -> {:error, @global_proof_expired}
      {:error, _} -> {:error, @global_rollback}
    end
  end

  defp revocation_result({:ok, result}) when result in [:revoked, :already_ended, :stale],
    do: {:ok, result}

  defp revocation_result({:error, reason}) when reason in [:audit_rejected, :global_rollback],
    do: {:error, :session_revocation_failed}

  defp revocation_result({:error, :transaction_unconfirmed}),
    do: {:error, :session_result_uncertain}

  defp revocation_result(_result), do: {:error, :session_unavailable}

  defp optional_cursor(nil), do: {:ok, nil}
  defp optional_cursor(cursor), do: Ecto.UUID.cast(cursor)

  defp with_current_session(credentials, operation, scope \\ :presenting)

  defp with_current_session(%{session_id: id, token: bearer}, operation, scope)
       when is_binary(id) and is_binary(bearer) do
    with {:ok, %{"sub" => subject, "jti" => jti, "purpose" => "user"}, Account} <-
           Jwt.verify(bearer, Account),
         {:ok, session} when not is_nil(session) <- Ash.get(Session, id, authorize?: false) do
      Ash.transact([Account, Token, Session], fn ->
        authorize_locked(id, session.account_id, bearer, subject, jti, operation, scope)
      end)
      |> current_session_result()
    else
      _ -> {:error, :authentication_unavailable}
    end
  rescue
    _ -> {:error, :transaction_unconfirmed}
  end

  defp with_current_session(_, _, _), do: {:error, :authentication_unavailable}

  if Mix.env() == :test do
    # Ash has committed by this point. Exercise loss of its acknowledgement
    # before the owning interface can confirm any outcome to the controller.
    defp current_session_result({:ok, :revoked} = result) do
      if Process.get({__MODULE__, :lose_revocation_acknowledgement}) do
        raise "transaction acknowledgement lost in TEST"
      end

      result
    end
  end

  defp current_session_result({:ok, {:ok, result}}), do: {:ok, result}
  defp current_session_result({:ok, result}), do: {:ok, result}

  defp current_session_result(
         {:error, %Ash.Error.Unknown.UnknownError{error: @revocation_rollback}}
       ),
       do: {:error, :audit_rejected}

  defp current_session_result({:error, %Ash.Error.Unknown.UnknownError{error: @global_rollback}}),
    do: {:error, :global_rollback}

  defp current_session_result(
         {:error, %Ash.Error.Unknown.UnknownError{error: @global_proof_expired}}
       ),
       do: {:error, :session_unavailable}

  defp current_session_result({:error, _}), do: {:error, :transaction_unconfirmed}

  defp authorize_locked(id, account_id, bearer, subject, jti, operation, scope) do
    with {:ok, [account]} <-
           Account
           |> Ash.Query.filter(id == ^account_id)
           |> Ash.Query.lock(:for_update)
           |> Ash.read(authorize?: false),
         true <- eligible?(account),
         ^subject <- AshAuthentication.user_to_subject(account),
         {:ok, token, linked} <- lock_authority_tokens(scope, jti, account_id, subject),
         {:ok, [session]} <-
           Session
           |> Ash.Query.filter(id == ^id and account_id == ^account_id and token_jti == ^jti)
           |> Ash.Query.lock(:for_update)
           |> Ash.read(authorize?: false),
         {:ok, %{"sub" => ^subject, "jti" => ^jti}, Account} <- Jwt.verify(bearer, Account),
         true <- session.state == :active,
         true <- future?(token.expires_at) do
      operation.(session, account, token, linked)
    else
      _ -> :denied
    end
  end

  defp lock_authority_tokens(:all, jti, account_id, subject) do
    linked = SessionRevocation.lock_linked_tokens(account_id)

    case Map.get(linked, jti) do
      %Token{subject: ^subject} = token -> {:ok, token, linked}
      _ -> :denied
    end
  end

  defp lock_authority_tokens(:presenting, jti, account_id, subject) do
    case locked_user_token(jti, account_id, subject) do
      {:ok, %Token{} = token} -> {:ok, token, nil}
      _ -> :denied
    end
  end

  defp locked_user_token(jti, account_id, subject) do
    Token
    |> Ash.Query.filter(
      jti == ^jti and account_id == ^account_id and subject == ^subject and purpose == "user"
    )
    |> Ash.Query.lock(:for_update)
    |> Ash.read_one(authorize?: false)
  end

  defp active_page(current, account, token, cursor) do
    if usable_deadlines?(current) and future?(token.expires_at),
      do: read_active_page(current, account, cursor),
      else: :denied
  end

  defp read_active_page(current, account, cursor) do
    query =
      account
      |> usable_sessions()
      |> Ash.Query.sort(id: :desc)
      |> Ash.Query.select([:id, :created_at, :last_seen_at])
      |> Ash.Query.limit(@session_page_size + 1)

    query = if cursor, do: Ash.Query.filter(query, id < ^cursor), else: query

    with {:ok, rows} <- Ash.read(query, authorize?: false) do
      {page, remaining} = Enum.split(rows, @session_page_size)

      sessions =
        Enum.map(page, fn session ->
          session
          |> Map.take([:id, :created_at, :last_seen_at])
          |> Map.put(:current?, session.id == current.id)
        end)

      {:listed,
       %{sessions: sessions, next_cursor: if(remaining == [], do: nil, else: List.last(page).id)}}
    end
  end

  defp usable_sessions(account) do
    account_id = account.id
    subject = AshAuthentication.user_to_subject(account)

    Ash.Query.filter(
      Session,
      account_id == ^account_id and state == :active and expires_at > now() and
        idle_expires_at > now() and
        exists(
          token,
          account_id == ^account_id and subject == ^subject and purpose == "user" and
            expires_at > now()
        )
    )
  end

  defp revoke_other_locked(%{id: id}, _account, _token, id), do: :denied

  defp revoke_other_locked(current, account, actor_token, id) do
    with true <- usable_deadlines?(current),
         {:ok, target} when not is_nil(target) <-
           Session
           |> Ash.Query.filter(id == ^id and account_id == ^account.id)
           |> Ash.Query.lock(:for_update)
           |> Ash.read_one(authorize?: false) do
      cond do
        not (usable_deadlines?(current) and future?(actor_token.expires_at)) -> :denied
        target.state == :active -> revoke_usable(current, account, actor_token, target)
        true -> :already_ended
      end
    else
      false -> :denied
      {:ok, nil} -> :denied
      {:error, _} = error -> error
    end
  end

  # Remote termination of a currently usable session is the material security
  # transition. Replays and stale targets stop before establishing E2.
  defp revoke_usable(current, account, actor_token, target) do
    subject = AshAuthentication.user_to_subject(account)

    with {:ok, token} when not is_nil(token) <-
           locked_user_token(target.token_jti, account.id, subject),
         true <-
           future?(token.expires_at) and usable_deadlines?(target) and
             future?(actor_token.expires_at) and usable_deadlines?(current),
         {:ok, ended} <- Ash.update(target, %{}, action: :revoke, authorize?: false),
         {:ok, _} <-
           NewYou.Audit.establish_identity_security_obligation(%{
             source_operation_id: ended.id,
             source_occurred_at: ended.ended_at,
             evidence_type: :identity_session_revoked,
             actor_id: account.id,
             target_id: account.id,
             outcome: :succeeded
           }) do
      :revoked
    else
      {:error, :evidence_outcome_unavailable} -> {:error, @revocation_rollback}
      {:ok, nil} -> stale_or_denied(current, actor_token)
      false -> stale_or_denied(current, actor_token)
      {:error, _} = error -> error
    end
  end

  defp stale_or_denied(current, token) do
    if usable_deadlines?(current) and future?(token.expires_at), do: :stale, else: :denied
  end

  defp usable_deadlines?(session),
    do: future?(session.expires_at) and future?(session.idle_expires_at)

  defp future?(deadline), do: DateTime.compare(deadline, DateTime.utc_now()) == :gt

  defp validate_and_touch(session, account) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    if DateTime.compare(now, session.expires_at) != :lt or
         DateTime.compare(now, session.idle_expires_at) != :lt do
      case Ash.update(session, %{}, action: :expire, authorize?: false) do
        {:ok, _} -> :expired
        _ -> {:error, :authentication_unavailable}
      end
    else
      case Ash.update(
             session,
             %{last_seen_at: now, idle_expires_at: DateTime.add(now, @idle_seconds)},
             action: :touch,
             authorize?: false
           ) do
        {:ok, _} -> {:ok, account}
        _ -> {:error, :authentication_unavailable}
      end
    end
  end

  def logout(credentials), do: terminate_session(credentials, :logout)
  def revoke(credentials), do: terminate_session(credentials, :revoke)

  defp terminate_session(%{session_id: id, token: bearer}, action)
       when is_binary(id) and is_binary(bearer) do
    with {:ok, %{"sub" => subject, "jti" => jti}, Account} <- Jwt.verify(bearer, Account),
         {:ok, result} <-
           Ash.transact([Account, Session], fn -> terminate_locked(id, jti, subject, action) end),
         result when result in [:ok, {:ok, :ok}] <- result do
      :ok
    else
      _ -> {:error, :authentication_unavailable}
    end
  rescue
    _ -> {:error, :authentication_unavailable}
  end

  defp terminate_session(_, _), do: {:error, :authentication_unavailable}

  defp terminate_locked(id, jti, subject, action) do
    with {:ok, [session]} <-
           Session
           |> Ash.Query.filter(id == ^id and token_jti == ^jti)
           |> Ash.Query.lock(:for_update)
           |> Ash.read(authorize?: false),
         {:ok, account} when not is_nil(account) <-
           Ash.get(Account, session.account_id, authorize?: false),
         ^subject <- AshAuthentication.user_to_subject(account) do
      case session.state do
        :logged_out when action == :logout ->
          :ok

        :revoked when action == :revoke ->
          :ok

        :active ->
          terminate_active(session, action)

        _ ->
          {:error, :authentication_unavailable}
      end
    else
      _ -> {:error, :authentication_unavailable}
    end
  end

  defp terminate_active(session, action) do
    case Ash.update(session, %{}, action: action, authorize?: false) do
      {:ok, _} -> :ok
      _ -> {:error, :authentication_unavailable}
    end
  end

  def expire_due do
    query =
      Session
      |> Ash.Query.filter(state == :active and (expires_at <= now() or idle_expires_at <= now()))
      |> Ash.Query.limit(100)

    case Ash.read(query, authorize?: false) do
      {:ok, sessions} -> Enum.reduce_while(sessions, {:ok, 0}, &expire_one/2)
      _ -> {:error, :authentication_unavailable}
    end
  rescue
    _ -> {:error, :authentication_unavailable}
  end

  defp expire_one(session, {:ok, count}) do
    case Ash.update(session, %{}, action: :expire, authorize?: false) do
      {:ok, _} -> {:cont, {:ok, count + 1}}
      _ -> already_terminal(session, count)
    end
  end

  defp already_terminal(session, count) do
    case Ash.get(Session, session.id, authorize?: false) do
      {:ok, %{state: state}} when state in [:expired, :revoked, :logged_out] ->
        {:cont, {:ok, count}}

      _ ->
        {:halt, {:error, :authentication_unavailable}}
    end
  end

  defp eligible?(account),
    do:
      account.email_verified? and account.credential_status == :active and
        account.account_status == :open and account.security_posture == :normal

  if Mix.env() == :test do
    defp checkpoint, do: NewYou.Proof.RegistrationSeam.checkpoint()
  else
    defp checkpoint, do: :ok
  end
end
