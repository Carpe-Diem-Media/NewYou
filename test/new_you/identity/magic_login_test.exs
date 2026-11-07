defmodule NewYou.Identity.MagicLoginTest do
  use ExUnit.Case, async: false
  require Ash.Query

  alias NewYou.Identity
  alias NewYou.Identity.{Account, Session, Token}
  alias NewYou.Proof.P805

  test "new issuance supersedes the current proof and identical request retries reuse it" do
    P805.with_fixture(fn ->
      {request, registration} = account()
      operation = operation()
      assert :ok = Identity.request_magic_login(request.email, "af", operation)
      [first] = proofs(registration.account_id)
      assert :ok = Identity.request_magic_login(request.email, "af", operation)
      assert length(proofs(registration.account_id)) == 1

      assert :ok = Identity.request_magic_login(request.email, "af", operation())
      assert Enum.count(proofs(registration.account_id), &(&1.purpose == "magic_login")) == 1
      assert Ash.get!(Token, first.jti, authorize?: false).purpose == "magic_login_superseded"
    end)
  end

  test "transient rematerialisation preserves the exact proof and consumption creates one shared Session" do
    P805.with_fixture(fn ->
      {request, registration} = account()
      assert :ok = Identity.request_magic_login(request.email, "af", operation())
      [token] = proofs(registration.account_id)
      before = token_snapshot()
      {:ok, bearer} = materialize(token, request.email, "af")
      {:ok, again} = materialize(token, request.email, "af")
      same_bearer? = bearer == again
      unchanged_tokens? = before == token_snapshot()
      assert same_bearer?
      assert unchanged_tokens?
      assert :error == AshAuthentication.Jwt.verify(bearer <> "x", Account)
      assert {:ok, credentials} = Identity.authenticate_magic_link(bearer)
      session = Ash.get!(Session, credentials.session_id, authorize?: false)
      assert session.authentication_method == :magic_login
      assert session.authentication_proof_jti == token.jti
      assert {:ok, %{account_id: id}} = Identity.authorize_session(credentials)
      assert id == registration.account_id
      assert {:error, :authentication_unavailable} = Identity.authenticate_magic_link(bearer)
      assert {:error, :source_invalid} = materialize(token, request.email, "af")

      assert P805.scalar("SELECT count(*) FROM sessions WHERE account_id = $1", [
               Ecto.UUID.dump!(id)
             ]) == 1
    end)
  end

  test "public request always returns neutral acceptance and never registers an Account" do
    P805.with_fixture(fn ->
      before = P805.scalar("SELECT count(*) FROM accounts")

      for {email, locale, operation} <- [
            {"unknown@example.test", "en", operation()},
            {"invalid", "af", operation()},
            {"unknown@example.test", "xx", operation()},
            {nil, nil, nil}
          ] do
        assert :ok = Identity.request_magic_login(email, locale, operation)
      end

      assert before == P805.scalar("SELECT count(*) FROM accounts")
    end)
  end

  test "database rejects incomplete magic metadata even when the nullable locale makes SQL unknown" do
    P805.with_fixture(fn ->
      {request, registration} = account()
      assert :ok = Identity.request_magic_login(request.email, "af", operation())
      [proof] = proofs(registration.account_id)

      assert_raise Postgrex.Error, fn ->
        NewYou.Repo.query!("UPDATE tokens SET magic_locale = NULL WHERE jti = $1", [proof.jti])
      end
    end)
  end

  test "a replacement signing key cannot rematerialise an existing proof under a new signature" do
    P805.with_fixture(fn ->
      {request, registration} = account()
      :ok = Identity.request_magic_login(request.email, "af", operation())
      [proof] = proofs(registration.account_id)
      original_key = Application.fetch_env!(:new_you, :identity_token_signing_secret)
      {:ok, bearer} = materialize(proof, request.email, "af")

      try do
        Application.put_env(
          :new_you,
          :identity_token_signing_secret,
          :crypto.strong_rand_bytes(32)
        )

        denied? = match?({:error, _}, materialize(proof, request.email, "af"))

        assert denied?,
               "signing-key replacement rematerialised a different bearer for an old proof"
      after
        Application.put_env(:new_you, :identity_token_signing_secret, original_key)
      end

      {:ok, restored} = materialize(proof, request.email, "af")
      same_bearer? = bearer == restored
      assert same_bearer?
    end)
  end

  test "temporary signing-key loss holds the delivery obligation and recovers without new proof" do
    P805.with_fixture(fn ->
      {request, registration} = account()
      :ok = Identity.request_magic_login(request.email, "af", operation())
      [proof] = proofs(registration.account_id)

      intent =
        NewYou.Communications.MessageIntent
        |> Ash.Query.filter(source_reference == ^proof.jti)
        |> Ash.read_one!(authorize?: false)

      original_key = Application.fetch_env!(:new_you, :identity_token_signing_secret)

      try do
        Application.delete_env(:new_you, :identity_token_signing_secret)
        assert {:ok, :held} = NewYou.Communications.execute(intent.id)
        assert Ash.get!(Token, proof.jti, authorize?: false).purpose == "magic_login"
      after
        Application.put_env(:new_you, :identity_token_signing_secret, original_key)
      end

      Process.put(:p810_provider, fn _, _ -> :delivered end)

      try do
        assert {:ok, :processed} = NewYou.Communications.execute(intent.id)
      after
        Process.delete(:p810_provider)
      end

      assert length(proofs(registration.account_id)) == 1
    end)
  end

  defp operation do
    id = Ecto.UUID.generate()
    P805.track_operation(id)
    id
  end

  defp account do
    request = P805.request()
    {:ok, registration} = Identity.register(request)
    {:ok, :verified} = Identity.verify_email(registration.verification_proof)
    {request, registration}
  end

  defp proofs(account_id) do
    Token
    |> Ash.Query.filter(account_id == ^account_id and not is_nil(magic_request_id))
    |> Ash.read!(authorize?: false)
  end

  defp materialize(token, destination, locale) do
    case Ash.transact([Account, Token], fn ->
           Identity.magic_login_delivery(token.jti, destination, locale)
         end) do
      {:ok, result} -> result
      _ -> {:error, :source_invalid}
    end
  end

  defp token_snapshot do
    NewYou.Repo.query!("SELECT row_to_json(t)::text FROM tokens t ORDER BY jti").rows
  end
end
