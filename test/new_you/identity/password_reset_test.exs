defmodule NewYou.Identity.PasswordResetTest do
  use ExUnit.Case, async: false
  require Ash.Query

  alias NewYou.Identity
  alias NewYou.Identity.{Account, Session, Token}
  alias NewYou.Communications.MessageIntent
  alias NewYou.Proof.P805

  test "explicit reset replaces the credential, consumes once, revokes all Sessions and never logs in" do
    P805.with_fixture(fn ->
      {request, registration} = account()
      {:ok, password_session} = Identity.authenticate_password(request.email, request.password)
      :ok = Identity.request_magic_login(request.email, "af", operation())

      magic =
        Token
        |> Ash.Query.filter(account_id == ^registration.account_id and purpose == "magic_login")
        |> Ash.read_one!(authorize?: false)

      {:ok, magic_bearer} = materialize(:magic_login_delivery, magic, request.email)
      {:ok, magic_session} = Identity.authenticate_magic_link(magic_bearer)
      before = Ash.get!(Account, registration.account_id, authorize?: false)

      assert request_reset(request.email, "af", operation()) == :ok
      proof = current_proof(registration.account_id)
      {:ok, bearer} = materialize(:password_reset_delivery, proof, request.email)
      completion = operation()
      replacement = "a new independently selected password"
      assert reset(bearer, replacement, completion) == {:ok, :reset}
      after_account = Ash.get!(Account, before.id, authorize?: false)
      assert after_account.security_version == before.security_version + 1
      assert after_account.credential_version == before.credential_version + 1
      assert after_account.hashed_password != before.hashed_password

      assert {:error, :authentication_unavailable} =
               Identity.authenticate_password(request.email, request.password)

      assert {:error, :authentication_unavailable} = Identity.authorize_session(password_session)
      assert {:error, :authentication_unavailable} = Identity.authorize_session(magic_session)

      for credentials <- [password_session, magic_session] do
        session = Ash.get!(Session, credentials.session_id, authorize?: false)
        assert session.state == :revoked
        assert session.step_up_purpose == nil
        assert Ash.get!(Token, session.token_jti, authorize?: false).purpose == "revocation"
      end

      assert session_count(before.id) == 2
      assert reset(bearer, replacement, operation()) == {:error, :reset_unavailable}
      assert reset(bearer, replacement, completion) == {:ok, :already_reset}

      assert Ash.get!(Account, before.id, authorize?: false).credential_version ==
               after_account.credential_version

      assert {:ok, _} = Identity.authenticate_password(request.email, replacement)
    end)
  end

  test "request is neutral and durable delivery uses the approved content without credential authority" do
    P805.with_fixture(fn ->
      {request, registration} = account()

      for email <- [request.email, "unknown@example.test", "invalid", nil] do
        assert request_reset(email, "af", operation()) == :ok
      end

      proof = current_proof(registration.account_id)

      intent =
        MessageIntent
        |> Ash.Query.filter(source_reference == ^proof.jti)
        |> Ash.read_one!(authorize?: false)

      assert intent.role == :password_reset

      assert intent.translation_version_id ==
               "NEWYOU-CONTENTTRANSLATIONVERSION-PASSWORD-RESET-MESSAGE-EMAIL-AF-V2"

      account_before = Ash.get!(Account, registration.account_id, authorize?: false)

      Process.put(:p810_provider, fn _, payload ->
        assert String.contains?(payload.body, "Wysig jou")
        assert String.contains?(payload.body, "/password/reset/confirm?")
        :delivered
      end)

      try do
        assert {:ok, :processed} = NewYou.Communications.execute(intent.id)
      after
        Process.delete(:p810_provider)
      end

      assert Ash.get!(Token, proof.jti, authorize?: false).purpose == "password_reset"
      assert Ash.get!(Account, account_before.id, authorize?: false) == account_before
      assert session_count(account_before.id) == 0
    end)
  end

  test "reset tombstones credential-derived registration replay material" do
    P805.with_fixture(fn ->
      {request, registration} = account()
      :ok = request_reset(request.email, "af", operation())
      proof = current_proof(registration.account_id)
      {:ok, bearer} = materialize(:password_reset_delivery, proof, request.email)
      assert {:ok, :reset} = reset(bearer, "replacement", operation())

      bound =
        NewYou.Identity.RegistrationOperation
        |> Ash.Query.filter(operation_id == ^request.operation_id)
        |> Ash.read_one!(authorize?: false)

      assert bound.state == :tombstoned
      assert bound.password_verifier == nil
      assert bound.created_account_id == nil
    end)
  end

  defp request_reset(email, locale, operation),
    do: invoke(:request_password_reset, [email, locale, operation])

  defp reset(proof, password, operation),
    do: invoke(:reset_password, [proof, password, operation])

  defp invoke(function, args) do
    apply(Identity, function, args)
  rescue
    UndefinedFunctionError -> {:error, :not_implemented}
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

  defp current_proof(id),
    do:
      Token
      |> Ash.Query.filter(account_id == ^id and purpose == "password_reset")
      |> Ash.read_one!(authorize?: false)

  defp materialize(function, token, email) do
    case Ash.transact([Account, Token], fn ->
           apply(Identity, function, [token.jti, email, "af"])
         end) do
      {:ok, result} -> result
      _ -> {:error, :source_invalid}
    end
  end

  defp session_count(id),
    do: P805.scalar("SELECT count(*) FROM sessions WHERE account_id = $1", [Ecto.UUID.dump!(id)])
end
