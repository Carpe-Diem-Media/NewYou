defmodule NewYou.Identity.SelfMemberReferenceTest do
  use ExUnit.Case, async: false

  alias NewYou.{Identity, Repo}
  alias NewYou.Proof.P805

  test "concurrent reads and reauthentication return only the existing reference" do
    P805.with_fixture(fn ->
      {request, account, credentials} = member()
      {_request, foreign, foreign_credentials} = member()
      pmr = account.pmr

      Application.put_env(:new_you, :identity_pmr_generator, fn ->
        flunk("self-display attempted PMR allocation")
      end)

      workers =
        for _ <- 1..2 do
          P805.independent_fixture_task(fn -> Identity.self_member_reference(credentials) end)
        end

      assert Enum.map(workers, &Task.await/1) == [{:ok, pmr}, {:ok, pmr}]
      assert :ok = Identity.logout(credentials)
      assert {:error, :authentication_unavailable} = Identity.self_member_reference(credentials)
      assert {:ok, fresh} = Identity.authenticate_password(request.email, request.password)
      assert {:ok, ^pmr} = Identity.self_member_reference(fresh)

      assert {:error, :authentication_unavailable} =
               Identity.self_member_reference(%{
                 fresh
                 | session_id: foreign_credentials.session_id
               })

      assert Identity.self_member_reference(foreign_credentials) == {:ok, foreign.pmr}

      assert pmr_truth(account.id) == [[pmr, "active", nil]]
      assert pmr_truth(foreign.id) == [[foreign.pmr, "active", nil]]
    end)
  end

  test "existing credentials fail closed as current Account, Session or Token authority changes" do
    P805.with_fixture(fn ->
      {_request, account, credentials} = member()
      {_request, survivor, _credentials} = member()
      id = Ecto.UUID.dump!(account.id)
      session_id = Ecto.UUID.dump!(credentials.session_id)
      pmr = account.pmr

      assert {:error, :authentication_unavailable} = Identity.self_member_reference(%{})
      assert {:ok, ^pmr} = Identity.self_member_reference(credentials)

      deny_during(credentials, "UPDATE accounts SET security_posture = 'held' WHERE id = $1", [id])

      deny_during(credentials, ~s(UPDATE accounts SET "email_verified?" = false WHERE id = $1), [
        id
      ])

      deny_during(
        credentials,
        "UPDATE sessions SET idle_expires_at = now() - interval '1 second' WHERE id = $1",
        [session_id]
      )

      deny_during(
        credentials,
        "UPDATE sessions SET expires_at = now() - interval '1 second' WHERE id = $1",
        [session_id]
      )

      invalid_pmr =
        String.slice(pmr, 0, 20) <> if(String.ends_with?(pmr, "0"), do: "1", else: "0")

      refute Identity.PMR.valid?(invalid_pmr)
      deny_during(credentials, "UPDATE accounts SET pmr = $2 WHERE id = $1", [id, invalid_pmr])

      deny_during(credentials, "UPDATE sessions SET state = 'revoked' WHERE id = $1", [session_id])

      deny_during(
        credentials,
        "UPDATE tokens SET purpose = 'revocation' WHERE jti = (SELECT token_jti FROM sessions WHERE id = $1)",
        [session_id]
      )

      deny_during(
        credentials,
        """
        UPDATE accounts SET pmr_status = 'retired', canonical_account_id = $2,
          account_status = 'closed_terminal', credential_status = 'revoked' WHERE id = $1
        """,
        [id, Ecto.UUID.dump!(survivor.id)]
      )

      assert {:ok, ^pmr} = Identity.self_member_reference(credentials)
    end)
  end

  defp deny_during(credentials, sql, args) do
    assert {:error, :restored_fixture} =
             Repo.transact(fn ->
               assert %{num_rows: 1} = Repo.query!(sql, args)

               assert {:error, :authentication_unavailable} =
                        Identity.self_member_reference(credentials)

               {:error, :restored_fixture}
             end)
  end

  defp member do
    request = P805.request()
    assert {:ok, registration} = Identity.register(request)
    assert {:ok, :verified} = Identity.verify_email(registration.verification_proof)
    assert {:ok, credentials} = Identity.authenticate_password(request.email, request.password)
    account = Ash.get!(Identity.Account, registration.account_id, authorize?: false)
    {request, account, credentials}
  end

  defp pmr_truth(id) do
    Repo.query!("SELECT pmr, pmr_status, canonical_account_id FROM accounts WHERE id = $1", [
      Ecto.UUID.dump!(id)
    ]).rows
  end
end
