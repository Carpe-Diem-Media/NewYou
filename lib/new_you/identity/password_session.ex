defmodule NewYou.Identity.PasswordSession do
  @moduledoc false
  require Ash.Query

  alias AshAuthentication.{Argon2Provider, Jwt}
  alias NewYou.Identity.{Account, Email, Session, Token}
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

  def authorize(%{session_id: id, token: bearer}) when is_binary(id) and is_binary(bearer) do
    with {:ok, %{"sub" => subject, "jti" => jti}, Account} <- Jwt.verify(bearer, Account),
         {:ok, session} when not is_nil(session) <- Ash.get(Session, id, authorize?: false),
         {:ok, result} <-
           Ash.transact([Account, Token, Session], fn ->
             authorize_locked(id, session.account_id, bearer, subject, jti)
           end) do
      case result do
        {:ok, %Account{id: id}} -> {:ok, %{account_id: id}}
        %Account{id: id} -> {:ok, %{account_id: id}}
        _ -> {:error, :authentication_unavailable}
      end
    else
      _ -> {:error, :authentication_unavailable}
    end
  rescue
    _ -> {:error, :authentication_unavailable}
  end

  def authorize(_), do: {:error, :authentication_unavailable}

  defp authorize_locked(id, account_id, bearer, subject, jti) do
    with {:ok, [account]} <-
           Account
           |> Ash.Query.filter(id == ^account_id)
           |> Ash.Query.lock(:for_update)
           |> Ash.read(authorize?: false),
         true <- eligible?(account),
         ^subject <- AshAuthentication.user_to_subject(account),
         {:ok, [token]} <-
           Token
           |> Ash.Query.filter(jti == ^jti and account_id == ^account_id and purpose == "user")
           |> Ash.Query.lock(:for_update)
           |> Ash.read(authorize?: false),
         {:ok, [session]} <-
           Session
           |> Ash.Query.filter(id == ^id and account_id == ^account_id and token_jti == ^jti)
           |> Ash.Query.lock(:for_update)
           |> Ash.read(authorize?: false),
         {:ok, %{"sub" => ^subject, "jti" => ^jti}, Account} <- Jwt.verify(bearer, Account),
         true <- session.state == :active,
         :lt <- DateTime.compare(DateTime.utc_now(), token.expires_at) do
      validate_and_touch(session, account)
    else
      _ -> {:error, :authentication_unavailable}
    end
  end

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
