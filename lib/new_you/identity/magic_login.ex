defmodule NewYou.Identity.MagicLogin do
  @moduledoc """
  Identity's optional magic-login proof lifecycle. Account locks serialize issue,
  supersession and explicit consumption. The Token's fixed claims describe one
  proof; only an in-memory signature is reconstructed for a current delivery.
  Signing never calls a token creation/upsert API. Communications retains no bearer.
  """
  @enabled Mix.env() in [:dev, :test] and
             Application.compile_env(:new_you, :verification_development_fixtures, false)

  if @enabled do
    require Ash.Query
    alias AshAuthentication.{Jwt, Jwt.Config}
    alias NewYou.Identity.{Account, Email, PasswordSession, Session, Token}
    alias NewYou.Communications.{MessageIntent, DeliveryAttempt}

    @spec request(term(), term(), term()) :: :ok
    def request(email, locale, operation_id) do
      with true <- locale in ["en", "af"],
           {:ok, operation_id} <- Ecto.UUID.cast(operation_id),
           {:ok, email} <- Email.canonicalize(email),
           {:ok, %Account{} = account} <- find_account(email) do
        Ash.transact([Account, Token, MessageIntent, DeliveryAttempt], fn ->
          issue_locked(account.id, email, locale, operation_id)
        end)
      else
        _ -> :ok
      end

      :ok
    rescue
      _ -> :ok
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
        _ -> {:error, :authentication_unavailable}
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
                 "purpose" => "magic_login",
                 "locale" => locale
               },
               Config.token_signer(Account)
             ),
           {:ok, proof} <-
             Ash.create(
               Token,
               %{
                 token: bearer,
                 magic_request_id: operation_id,
                 magic_claims: claims,
                 magic_account_binding: account_binding(account),
                 magic_locale: locale
               },
               action: :issue_magic_login,
               authorize?: false,
               context: %{ash_authentication: %{user: account}}
             ),
           {:ok, _intent} <-
             NewYou.Communications.establish_magic_login(%{
               source_operation_id: operation_id,
               source_reference: proof.jti,
               role: :magic_login,
               source_purpose: "magic_login",
               render_schema: "magic-login-v1",
               destination: account.email,
               destination_provenance: "identity_magic_login_issuance",
               destination_authorized_at: proof.created_at,
               locale: locale
             }) do
        checkpoint()
        :ok
      else
        _ -> {:error, :authentication_unavailable}
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
           true <- account.email == destination and proof.magic_locale == locale,
           {:ok, bearer, claims} <-
             Joken.encode_and_sign(proof.magic_claims, Config.token_signer(Account)),
           true <- claims == proof.magic_claims,
           {:ok, ^claims, Account} <- Jwt.verify(bearer, Account) do
        {:ok, bearer}
      else
        {:error, _} -> {:error, :capability_unavailable}
        _ -> {:error, :source_invalid}
      end
    rescue
      _ -> {:error, :capability_unavailable}
    end

    @spec authenticate(binary()) :: {:ok, map()} | {:error, :authentication_unavailable}
    def authenticate(bearer) do
      with {:ok, %{"purpose" => "magic_login", "jti" => jti}, Account} <-
             Jwt.verify(bearer, Account),
           {:ok, %Token{} = locator} <- token(jti),
           {:ok, result} <-
             Ash.transact([Account, Token, Session], fn ->
               consume_locked(locator.account_id, jti, bearer)
             end) do
        case result do
          {:ok, credentials} -> {:ok, credentials}
          credentials when is_map(credentials) -> {:ok, credentials}
          _ -> {:error, :authentication_unavailable}
        end
      else
        _ -> {:error, :authentication_unavailable}
      end
    rescue
      _ -> {:error, :authentication_unavailable}
    end

    defp consume_locked(account_id, jti, bearer) do
      with {:ok, account} <- lock_account(account_id),
           {:ok, proof} <- token(jti, true),
           true <- valid_current?(proof, account),
           {:ok, claims, Account} <- Jwt.verify(bearer, Account),
           true <- claims == proof.magic_claims,
           {:ok, _} <- Ash.update(proof, %{}, action: :consume_magic_login, authorize?: false),
           {:ok, credentials} <-
             PasswordSession.issue_current(account, %{
               authentication_method: :magic_login,
               authentication_proof_jti: proof.jti
             }) do
        checkpoint()
        {:ok, credentials}
      else
        _ -> {:error, :authentication_unavailable}
      end
    end

    defp valid_current?(%Token{} = proof, %Account{} = account) do
      eligible?(account) and proof.account_id == account.id and proof.purpose == "magic_login" and
        proof.subject == AshAuthentication.user_to_subject(account) and
        DateTime.compare(DateTime.utc_now(), proof.expires_at) == :lt and
        proof.magic_account_binding == account_binding(account) and
        claims_match?(proof)
    end

    defp valid_current?(_, _), do: false

    defp claims_match?(proof) do
      is_map(proof.magic_claims) and proof.magic_claims["jti"] == proof.jti and
        proof.magic_claims["sub"] == proof.subject and
        proof.magic_claims["purpose"] == "magic_login" and
        proof.magic_claims["locale"] == proof.magic_locale and
        proof.magic_claims["exp"] == DateTime.to_unix(proof.expires_at)
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
          {"magic-login-account:v1",
           AshAuthentication.Info.authentication_tokens_signing_algorithm!(Account), account.id,
           account.email, account.hashed_password, account.email_verified?,
           account.credential_status, account.account_status, account.security_posture},
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
        |> Ash.Query.filter(magic_request_id == ^operation_id)
        |> Ash.read_one(authorize?: false)

    defp current_proofs(account_id),
      do:
        Token
        |> Ash.Query.filter(account_id == ^account_id and purpose == "magic_login")
        |> Ash.read(authorize?: false)

    defp supersede(proofs) do
      Enum.reduce_while(proofs, :ok, fn proof, _ ->
        case Ash.update(proof, %{}, action: :supersede_magic_login, authorize?: false) do
          {:ok, _} -> {:cont, :ok}
          _ -> {:halt, {:error, :authentication_unavailable}}
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

    @spec authenticate(binary()) :: {:error, :authentication_unavailable}
    def authenticate(_bearer), do: {:error, :authentication_unavailable}
  end
end
