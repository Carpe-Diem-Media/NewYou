defmodule NewYou.Identity.EmailVerificationTest do
  use ExUnit.Case, async: false

  alias NewYou.Identity
  alias NewYou.Proof.P805

  test "real Chromium confirms and safely replays the temporary EN/AF flow" do
    run_case("p807.browser_en")
    run_case("p807.browser_af")
  end

  test "real competing transactions have one winner and fresh-connection replay rejects" do
    assert Code.ensure_loaded?(NewYou.Proof.P807)
    assert function_exported?(NewYou.Proof.P807, :run, 1)
    run_case("p807.consume_race")
  end

  test "pre-commit worker loss rolls back and replacement reconstructs from the database" do
    assert Code.ensure_loaded?(NewYou.Proof.P807)
    assert function_exported?(NewYou.Proof.P807, :run, 1)
    run_case("p807.interrupted_consume")
  end

  test "current closure and security hold prevent verification without consuming proof" do
    P805.with_fixture(fn ->
      {:ok, registration} = Identity.register(P805.request())
      id = Ecto.UUID.dump!(registration.account_id)

      for {column, value, original} <- [
            {"account_status", "closed_recoverable", "open"},
            {"account_status", "closed_terminal", "open"},
            {"security_posture", "held", "normal"}
          ] do
        NewYou.Repo.query!("UPDATE accounts SET #{column} = $1 WHERE id = $2", [value, id])

        assert {:error, :verification_unavailable} =
                 Identity.verify_email(registration.verification_proof)

        refute account(registration).email_verified?

        assert {:ok, _, _} =
                 AshAuthentication.Jwt.verify(registration.verification_proof, Identity.Account)

        NewYou.Repo.query!("UPDATE accounts SET #{column} = $1 WHERE id = $2", [original, id])
      end

      assert {:ok, :verified} = Identity.verify_email(registration.verification_proof)
    end)
  end

  test "explicit confirmation commits verification once without issuing a login token" do
    P805.with_fixture(fn ->
      {:ok, registration} = Identity.register(P805.request())
      before = P805.counts()
      [original] = Ash.read!(Identity.Token, authorize?: false)
      assert {:ok, :verified} = Identity.verify_email(registration.verification_proof)
      [consumed] = Ash.read!(Identity.Token, authorize?: false)
      assert consumed.expires_at == original.expires_at
      assert account(registration).email_verified?

      assert {:error, :verification_unavailable} =
               Identity.verify_email(registration.verification_proof)

      assert before == P805.counts()

      assert Enum.all?(
               Ash.read!(Identity.Token, authorize?: false),
               &(&1.purpose == "revocation")
             )
    end)
  end

  test "invalid, wrong-purpose, revoked, expired and superseded proofs fail closed" do
    P805.with_fixture(fn ->
      {:ok, registration} = Identity.register(P805.request())
      user = account(registration)

      {:ok, wrong, _} =
        AshAuthentication.Jwt.token_for_user(user, %{"purpose" => "password_reset"},
          purpose: :password_reset,
          authorize?: false
        )

      {:ok, expired, _} =
        AshAuthentication.Jwt.token_for_user(user, %{"purpose" => "email_verification"},
          purpose: :email_verification,
          token_lifetime: {-1, :seconds},
          authorize?: false
        )

      for proof <- [nil, "invalid", wrong, expired] do
        assert {:error, :verification_unavailable} = Identity.verify_email(proof)
        refute account(registration).email_verified?
      end

      assert :ok =
               AshAuthentication.TokenResource.Actions.revoke_jti(
                 Identity.Token,
                 token_jti(registration.verification_proof),
                 AshAuthentication.user_to_subject(user),
                 authorize?: false,
                 context: %{ash_authentication: %{user: user}}
               )

      assert {:error, :verification_unavailable} =
               Identity.verify_email(registration.verification_proof)

      assert {:ok, :verification_pending} =
               Identity.resend_verification(%{
                 operation_id: Ecto.UUID.generate(),
                 account_id: user.id
               })

      refute account(registration).email_verified?

      assert {:error, :verification_unavailable} =
               Identity.verify_email(registration.verification_proof)
    end)
  end

  test "current credential eligibility is re-read and account-write failure restores proof" do
    P805.with_fixture(fn ->
      {:ok, registration} = Identity.register(P805.request())
      id = Ecto.UUID.dump!(registration.account_id)
      NewYou.Repo.query!("UPDATE accounts SET credential_status = 'revoked' WHERE id = $1", [id])

      assert {:error, :verification_unavailable} =
               Identity.verify_email(registration.verification_proof)

      NewYou.Repo.query!("UPDATE accounts SET credential_status = 'active' WHERE id = $1", [id])

      NewYou.Repo.query!("""
      CREATE FUNCTION p807_reject_verification() RETURNS trigger LANGUAGE plpgsql AS $$
      BEGIN RAISE EXCEPTION 'p807 owner failure' USING ERRCODE = '23514'; END; $$
      """)

      NewYou.Repo.query!(
        "CREATE TRIGGER p807_reject BEFORE UPDATE ON accounts FOR EACH ROW EXECUTE FUNCTION p807_reject_verification()"
      )

      try do
        assert {:error, :verification_unavailable} =
                 Identity.verify_email(registration.verification_proof)

        refute account(registration).email_verified?

        assert {:ok, _, _} =
                 AshAuthentication.Jwt.verify(registration.verification_proof, Identity.Account)
      after
        NewYou.Repo.query!("DROP TRIGGER p807_reject ON accounts")
        NewYou.Repo.query!("DROP FUNCTION p807_reject_verification()")
      end

      assert {:ok, :verified} = Identity.verify_email(registration.verification_proof)
    end)
  end

  test "stored presence, purpose and expiry remain authoritative even for a signed bearer" do
    P805.with_fixture(fn ->
      {:ok, registration} = Identity.register(P805.request())
      jti = token_jti(registration.verification_proof)
      NewYou.Repo.query!("UPDATE tokens SET purpose = 'password_reset' WHERE jti = $1", [jti])

      assert {:error, :verification_unavailable} =
               Identity.verify_email(registration.verification_proof)

      NewYou.Repo.query!(
        "UPDATE tokens SET purpose = 'email_verification', expires_at = now() - interval '1 hour' WHERE jti = $1",
        [jti]
      )

      assert {:error, :verification_unavailable} =
               Identity.verify_email(registration.verification_proof)

      NewYou.Repo.query!("DELETE FROM tokens WHERE jti = $1", [jti])

      assert {:error, :verification_unavailable} =
               Identity.verify_email(registration.verification_proof)

      refute account(registration).email_verified?
    end)
  end

  test "resend supersedes an unconsumed proof and only the replacement can verify" do
    P805.with_fixture(fn ->
      {:ok, registration} = Identity.register(P805.request())

      assert {:ok, :verification_pending} =
               Identity.resend_verification(%{
                 operation_id: Ecto.UUID.generate(),
                 account_id: registration.account_id
               })

      assert {:error, :verification_unavailable} =
               Identity.verify_email(registration.verification_proof)

      [token] =
        Ash.read!(Identity.Token, authorize?: false)
        |> Enum.filter(&(&1.purpose == "email_verification"))

      %{rows: [[intent, nonce, ciphertext, tag, version]]} =
        NewYou.Repo.query!(
          "SELECT message_intent_id::text, nonce, ciphertext, tag, key_version FROM communications_protected_envelopes WHERE source_reference = $1",
          [token.jti]
        )

      keyring = Application.fetch_env!(:new_you, :communications_keyring)

      {:ok, replacement} =
        NewYou.Communications.EnvelopeCrypto.decrypt_versioned(
          keyring.keys,
          version,
          {intent, token.jti, "email_verification"},
          %{nonce: nonce, ciphertext: ciphertext, tag: tag}
        )

      assert {:ok, :verified} = Identity.verify_email(replacement)
      assert {:error, :verification_unavailable} = Identity.verify_email(replacement)

      assert {:error, :verification_unavailable} =
               Identity.verify_email(registration.verification_proof)
    end)
  end

  test "a provider actor cannot call private confirmation or directly mark verification" do
    P805.with_fixture(fn ->
      {:ok, registration} = Identity.register(P805.request())

      refute Ash.can?(
               {Identity.Account, :confirm_email, %{proof: registration.verification_proof}},
               %{provider: true}
             )

      assert {:error, _} =
               Ash.update(account(registration), %{},
                 action: :mark_email_verified,
                 actor: %{provider: true}
               )

      refute account(registration).email_verified?
    end)
  end

  defp account(registration),
    do: Ash.get!(Identity.Account, registration.account_id, authorize?: false)

  defp run_case(id) do
    registration = Enum.find(NewYou.Proof.P807Catalog.registrations(), &(&1.case_id == id))
    manifest = Map.put(registration.manifest, :version, "p8-07.1")

    {result, cleanup} =
      NewYou.Proof.SelfTest.execute_registered_case(manifest, registration.callback)

    assert result["verdict"] == "PASS", inspect(result)
    assert Enum.all?(cleanup, fn {_key, value} -> value == true end), inspect(cleanup)
  end

  defp token_jti(proof) do
    {:ok, claims} = AshAuthentication.Jwt.peek(proof)
    claims["jti"]
  end
end
