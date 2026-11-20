defmodule NewYou.Identity.PasswordSessionTest do
  use ExUnit.Case, async: false

  alias NewYou.Identity
  alias NewYou.Proof.{FixtureObservation, P805}

  test "proof runner reconstructs Session authority on a fresh connection" do
    assert Code.ensure_loaded?(NewYou.Proof.P809Catalog)

    registration =
      Enum.find(NewYou.Proof.P809Catalog.registrations(), &(&1.case_id == "p809.reconnect"))

    {result, cleanup} =
      NewYou.Proof.SelfTest.execute_registered_case(
        Map.put(registration.manifest, :version, "p8-08.1"),
        registration.callback
      )

    assert result["verdict"] == "PASS", inspect(result)
    assert Enum.all?(cleanup, fn {_key, value} -> value == true end), inspect(cleanup)
  end

  test "proof runner verifies interrupted session issuance rolls back and recovers" do
    registration =
      Enum.find(
        NewYou.Proof.P809Catalog.registrations(),
        &(&1.case_id == "p809.interrupted_issue")
      )

    {result, cleanup} =
      NewYou.Proof.SelfTest.execute_registered_case(
        Map.put(registration.manifest, :version, "p8-08.1"),
        registration.callback
      )

    assert result["verdict"] == "PASS", inspect(result)
    assert Enum.all?(cleanup, fn {_key, value} -> value == true end), inspect(cleanup)
  end

  test "proof runner executes both browser locales" do
    for id <- ~w(p809.browser_en p809.browser_af) do
      registration = Enum.find(NewYou.Proof.P809Catalog.registrations(), &(&1.case_id == id))

      {result, cleanup} =
        NewYou.Proof.SelfTest.execute_registered_case(
          Map.put(registration.manifest, :version, "p8-08.1"),
          registration.callback
        )

      assert result["verdict"] == "PASS", inspect(result)
      assert Enum.all?(cleanup, fn {_key, value} -> value == true end), inspect(cleanup)
    end
  end

  test "proof runner arbitrates login against a concurrent security hold" do
    registration =
      Enum.find(NewYou.Proof.P809Catalog.registrations(), &(&1.case_id == "p809.hold_race"))

    {result, cleanup} =
      NewYou.Proof.SelfTest.execute_registered_case(
        Map.put(registration.manifest, :version, "p8-08.1"),
        registration.callback
      )

    assert result["verdict"] == "PASS", inspect(result)
    assert Enum.all?(cleanup, fn {_key, value} -> value == true end), inspect(cleanup)
  end

  test "proof runner reconstructs Session authority across BEAM restarts" do
    registration =
      Enum.find(NewYou.Proof.P809Catalog.registrations(), &(&1.case_id == "p809.beam_restart"))

    {result, cleanup} =
      NewYou.Proof.SelfTest.execute_registered_case(
        Map.put(registration.manifest, :version, "p8-08.1"),
        registration.callback
      )

    assert result["verdict"] == "PASS", inspect(result)
    assert Enum.all?(cleanup, fn {_key, value} -> value == true end), inspect(cleanup)
  end

  test "password authentication requires verification and creates a usable session" do
    P805.with_fixture(fn ->
      request = P805.request()
      assert {:ok, registration} = Identity.register(request)

      assert {:error, :authentication_unavailable} =
               Identity.authenticate_password(request.email, request.password)

      assert {:ok, :verified} = Identity.verify_email(registration.verification_proof)

      assert %{rows: [[0]]} =
               NewYou.Repo.query!("SELECT count(*) FROM sessions WHERE account_id = $1", [
                 Ecto.UUID.dump!(registration.account_id)
               ])

      assert {:ok, credentials} =
               Identity.authenticate_password(request.email, request.password)

      assert {:ok, %{account_id: id} = actor} = Identity.authorize_session(credentials)
      assert id == registration.account_id
      assert Map.keys(actor) == [:account_id]
    end)
  end

  test "expired-token cleanup retains linked Session history and denies old credentials" do
    P805.with_fixture(fn ->
      request = P805.request()
      {:ok, registration} = Identity.register(request)
      {:ok, :verified} = Identity.verify_email(registration.verification_proof)

      credentials =
        for state <- [:active, :expired, :revoked, :logged_out] do
          {:ok, credentials} = Identity.authenticate_password(request.email, request.password)
          session_id = Ecto.UUID.dump!(credentials.session_id)

          NewYou.Repo.query!(
            "UPDATE sessions SET state = $2 WHERE id = $1",
            [session_id, Atom.to_string(state)]
          )

          session = Ash.get!(Identity.Session, credentials.session_id, authorize?: false)

          NewYou.Repo.query!(
            "UPDATE tokens SET expires_at = now() - interval '1 hour' WHERE jti = $1",
            [session.token_jti]
          )

          {credentials, session}
        end

      before_sessions = session_signature()
      before_tokens = token_signature()

      # The maintenance action is global. Roll back its whole effect after
      # proving fixture token deletion and retained Session history.
      with_rolled_back_maintenance(fn ->
        assert :ok =
                 AshAuthentication.TokenResource.Actions.expunge_expired(Identity.Token)

        assert :ok =
                 AshAuthentication.TokenResource.Actions.expunge_expired(Identity.Token)

        for {credentials, original} <- credentials do
          retained =
            Ash.get!(Identity.Session, credentials.session_id, authorize?: false)

          assert retained.state == original.state
          assert retained.token_jti == original.token_jti
          assert retained.created_at == original.created_at

          assert is_nil(
                   Ash.get!(Identity.Token, original.token_jti,
                     authorize?: false,
                     not_found_error?: false
                   )
                 )

          assert {:error, :authentication_unavailable} =
                   Identity.authorize_session(credentials)
        end

        assert {:ok, fresh} =
                 Identity.authenticate_password(request.email, request.password)

        assert {:ok, %{account_id: id}} = Identity.authorize_session(fresh)
        assert id == registration.account_id
      end)

      assert session_signature() == before_sessions
      assert token_signature() == before_tokens
    end)
  end

  test "password login rejects an email changed while waiting for the Account lock" do
    P805.with_fixture(fn ->
      request = P805.request()
      changed_email = P805.request().email
      {:ok, registration} = Identity.register(request)
      {:ok, :verified} = Identity.verify_email(registration.verification_proof)
      account_id = Ecto.UUID.dump!(registration.account_id)
      parent = self()
      reference = make_ref()
      scenario = NewYou.Proof.Scenario.start()

      before_tokens =
        P805.scalar("SELECT count(*) FROM tokens WHERE account_id = $1", [account_id])

      before_sessions =
        P805.scalar("SELECT count(*) FROM sessions WHERE account_id = $1", [account_id])

      try do
        {:ok, monitor} =
          NewYou.Repo.transaction(fn ->
            NewYou.Repo.query!("SELECT id FROM accounts WHERE id = $1 FOR UPDATE", [account_id])
            holder_backend = P805.scalar("SELECT pg_backend_pid()")

            {_worker, monitor} =
              NewYou.Proof.Scenario.spawn(scenario, :stale_email_login, fn ->
                :ok = Ecto.Adapters.SQL.Sandbox.checkout(NewYou.Repo, sandbox: false)

                try do
                  send(parent, {reference, :backend, P805.scalar("SELECT pg_backend_pid()")})

                  # Send only the decision, never a bearer, back to the test process.
                  result = Identity.authenticate_password(request.email, request.password)

                  send(
                    parent,
                    {reference, :denied, result == {:error, :authentication_unavailable}}
                  )
                after
                  Ecto.Adapters.SQL.Sandbox.checkin(NewYou.Repo)
                end
              end)

            assert_receive {^reference, :backend, login_backend}, 5_000

            assert await_account_lock(
                     holder_backend,
                     login_backend,
                     System.monotonic_time(:millisecond) + 10_000
                   )

            NewYou.Repo.query!("UPDATE accounts SET email = $2 WHERE id = $1", [
              account_id,
              changed_email
            ])

            monitor
          end)

        assert_receive {^reference, :denied, true}, 5_000
        assert_receive {:DOWN, ^monitor, :process, _, :normal}, 5_000

        assert P805.scalar("SELECT count(*) FROM tokens WHERE account_id = $1", [account_id]) ==
                 before_tokens

        assert P805.scalar("SELECT count(*) FROM sessions WHERE account_id = $1", [account_id]) ==
                 before_sessions

        assert {:error, :authentication_unavailable} =
                 Identity.authenticate_password(request.email, request.password)

        assert {:ok, fresh} =
                 Identity.authenticate_password(
                   String.replace(changed_email, "@example.test", "@EXAMPLE.TEST"),
                   request.password
                 )

        assert {:ok, %{account_id: id}} = Identity.authorize_session(fresh)
        assert id == registration.account_id
      after
        assert :ok = NewYou.Proof.Scenario.stop(scenario)
      end
    end)
  end

  test "session and token revocation independently deny protected access" do
    P805.with_fixture(fn ->
      request = P805.request()
      {:ok, registration} = Identity.register(request)
      {:ok, :verified} = Identity.verify_email(registration.verification_proof)
      {:ok, first} = Identity.authenticate_password(request.email, request.password)
      {:ok, second} = Identity.authenticate_password(request.email, request.password)
      {:ok, claims} = AshAuthentication.Jwt.peek(second.token)

      assert {:error, :authentication_unavailable} =
               Identity.authorize_session(%{first | token: second.token})

      assert %{rows: [[false]]} =
               NewYou.Repo.query!(
                 "SELECT row_to_json(s)::text LIKE '%' || $2 || '%' FROM sessions s WHERE id = $1",
                 [Ecto.UUID.dump!(first.session_id), first.token]
               )

      NewYou.Repo.query!("UPDATE sessions SET state = 'revoked' WHERE id = $1", [
        Ecto.UUID.dump!(first.session_id)
      ])

      NewYou.Repo.query!("UPDATE tokens SET purpose = 'revocation' WHERE jti = $1", [
        claims["jti"]
      ])

      assert {:error, :authentication_unavailable} = Identity.authorize_session(first)
      assert {:error, :authentication_unavailable} = Identity.authorize_session(second)
    end)
  end

  test "current account security and session expiry deny stale credentials" do
    P805.with_fixture(fn ->
      request = P805.request()
      {:ok, registration} = Identity.register(request)
      {:ok, :verified} = Identity.verify_email(registration.verification_proof)
      {:ok, credentials} = Identity.authenticate_password(request.email, request.password)
      account_id = Ecto.UUID.dump!(registration.account_id)

      NewYou.Repo.query!("UPDATE accounts SET security_posture = 'held' WHERE id = $1", [
        account_id
      ])

      assert {:error, :authentication_unavailable} = Identity.authorize_session(credentials)

      NewYou.Repo.query!("UPDATE accounts SET security_posture = 'normal' WHERE id = $1", [
        account_id
      ])

      NewYou.Repo.query!(
        "UPDATE sessions SET expires_at = now() - interval '1 second' WHERE id = $1",
        [Ecto.UUID.dump!(credentials.session_id)]
      )

      assert {:error, :authentication_unavailable} = Identity.authorize_session(credentials)
    end)
  end

  test "logout is idempotent and its session remains denied" do
    P805.with_fixture(fn ->
      request = P805.request()
      {:ok, registration} = Identity.register(request)
      {:ok, :verified} = Identity.verify_email(registration.verification_proof)
      {:ok, credentials} = Identity.authenticate_password(request.email, request.password)

      assert :ok = Identity.logout(credentials)
      assert :ok = Identity.logout(credentials)
      assert {:error, :authentication_unavailable} = Identity.authorize_session(credentials)
    end)
  end

  test "self-service revocation is idempotent without revoking the linked token" do
    P805.with_fixture(fn ->
      request = P805.request()
      {:ok, registration} = Identity.register(request)
      {:ok, :verified} = Identity.verify_email(registration.verification_proof)
      {:ok, credentials} = Identity.authenticate_password(request.email, request.password)
      assert :ok = Identity.revoke_session(credentials)
      ended_at = Ash.get!(Identity.Session, credentials.session_id, authorize?: false).ended_at
      assert :ok = Identity.revoke_session(credentials)
      session = Ash.get!(Identity.Session, credentials.session_id, authorize?: false)
      assert %DateTime{} = session.created_at
      assert %DateTime{} = session.ended_at
      assert session.ended_at == ended_at
      refute inspect(session) =~ session.token_jti
      assert {:error, :authentication_unavailable} = Identity.authorize_session(credentials)
      assert {:ok, _, _} = AshAuthentication.Jwt.verify(credentials.token, Identity.Account)
    end)
  end

  test "session write failure rolls back token issuance" do
    P805.with_fixture(fn ->
      request = P805.request()
      {:ok, registration} = Identity.register(request)
      {:ok, :verified} = Identity.verify_email(registration.verification_proof)
      account_id = Ecto.UUID.dump!(registration.account_id)

      before =
        NewYou.Repo.query!("SELECT count(*) FROM tokens WHERE account_id = $1", [account_id]).rows

      NewYou.Repo.query!("""
      CREATE FUNCTION p809_reject_session() RETURNS trigger LANGUAGE plpgsql AS $$
      BEGIN RAISE EXCEPTION 'p809 session failure' USING ERRCODE = '23514'; END; $$
      """)

      NewYou.Repo.query!(
        "CREATE TRIGGER p809_reject BEFORE INSERT ON sessions FOR EACH ROW EXECUTE FUNCTION p809_reject_session()"
      )

      try do
        assert {:error, :authentication_unavailable} =
                 Identity.authenticate_password(request.email, request.password)

        assert before ==
                 NewYou.Repo.query!("SELECT count(*) FROM tokens WHERE account_id = $1", [
                   account_id
                 ]).rows
      after
        NewYou.Repo.query!("DROP TRIGGER p809_reject ON sessions")
        NewYou.Repo.query!("DROP FUNCTION p809_reject_session()")
      end
    end)
  end

  test "a terminal logout cannot be rewritten as revocation" do
    P805.with_fixture(fn ->
      request = P805.request()
      {:ok, registration} = Identity.register(request)
      {:ok, :verified} = Identity.verify_email(registration.verification_proof)
      {:ok, credentials} = Identity.authenticate_password(request.email, request.password)
      assert :ok = Identity.logout(credentials)
      session = Ash.get!(Identity.Session, credentials.session_id, authorize?: false)
      assert {:error, _} = Ash.update(session, %{}, action: :revoke, authorize?: false)
    end)
  end

  test "login rechecks current credential, closure and security status" do
    P805.with_fixture(fn ->
      request = P805.request()
      {:ok, registration} = Identity.register(request)
      {:ok, :verified} = Identity.verify_email(registration.verification_proof)
      id = Ecto.UUID.dump!(registration.account_id)

      for {column, denied, normal} <- [
            {"credential_status", "revoked", "active"},
            {"account_status", "closed_recoverable", "open"},
            {"account_status", "closed_terminal", "open"},
            {"security_posture", "held", "normal"}
          ] do
        NewYou.Repo.query!("UPDATE accounts SET #{column} = $1 WHERE id = $2", [denied, id])

        assert {:error, :authentication_unavailable} =
                 Identity.authenticate_password(request.email, request.password)

        NewYou.Repo.query!("UPDATE accounts SET #{column} = $1 WHERE id = $2", [normal, id])
      end

      assert {:error, :authentication_unavailable} =
               Identity.authenticate_password(request.email, "wrong password")

      assert {:error, :authentication_unavailable} =
               Identity.authenticate_password("unknown@example.test", request.password)
    end)
  end

  test "an idle deadline denies access independently of absolute expiry" do
    P805.with_fixture(fn ->
      request = P805.request()
      {:ok, registration} = Identity.register(request)
      {:ok, :verified} = Identity.verify_email(registration.verification_proof)
      {:ok, credentials} = Identity.authenticate_password(request.email, request.password)

      NewYou.Repo.query!(
        "UPDATE sessions SET idle_expires_at = now() - interval '1 second' WHERE id = $1",
        [Ecto.UUID.dump!(credentials.session_id)]
      )

      assert {:error, :authentication_unavailable} = Identity.authorize_session(credentials)

      assert Ash.get!(Identity.Session, credentials.session_id, authorize?: false).state ==
               :expired
    end)
  end

  test "expiry reconciliation is idempotent for an absolute deadline" do
    P805.with_fixture(fn ->
      request = P805.request()
      {:ok, registration} = Identity.register(request)
      {:ok, :verified} = Identity.verify_email(registration.verification_proof)
      {:ok, credentials} = Identity.authenticate_password(request.email, request.password)

      NewYou.Repo.query!(
        "UPDATE sessions SET expires_at = now() - interval '1 second' WHERE id = $1",
        [Ecto.UUID.dump!(credentials.session_id)]
      )

      foreign_request = P805.request()
      {:ok, foreign_registration} = Identity.register(foreign_request)
      {:ok, :verified} = Identity.verify_email(foreign_registration.verification_proof)

      {:ok, foreign_credentials} =
        Identity.authenticate_password(foreign_request.email, foreign_request.password)

      NewYou.Repo.query!(
        "UPDATE sessions SET expires_at = now() - interval '1 second' WHERE id = $1",
        [Ecto.UUID.dump!(foreign_credentials.session_id)]
      )

      before = session_signature()

      # Reconciliation is intentionally global and bounded to 100 rows per call.
      # Exercise its actual batches, then roll back all changes to retained rows.
      with_rolled_back_maintenance(fn ->
        due =
          P805.scalar(
            "SELECT count(*) FROM sessions WHERE state = 'active' AND (expires_at <= now() OR idle_expires_at <= now())"
          )

        assert due >= 2

        for batch <- 0..div(due - 1, 100) do
          expected = min(due - batch * 100, 100)
          assert {:ok, ^expected} = Identity.expire_due_sessions()
        end

        assert {:ok, 0} = Identity.expire_due_sessions()

        assert Ash.get!(Identity.Session, credentials.session_id, authorize?: false).state ==
                 :expired

        assert Ash.get!(Identity.Session, foreign_credentials.session_id, authorize?: false).state ==
                 :expired

        assert P805.scalar(
                 "SELECT count(*) FROM sessions WHERE account_id = $1 AND state = 'expired'",
                 [Ecto.UUID.dump!(registration.account_id)]
               ) == 1
      end)

      assert session_signature() == before

      assert Ash.get!(Identity.Session, credentials.session_id, authorize?: false).state ==
               :active

      assert Ash.get!(Identity.Session, foreign_credentials.session_id, authorize?: false).state ==
               :active
    end)
  end

  for maintenance <- [:tokens, :sessions] do
    test "#{maintenance} maintenance excludes foreign inserts and rolls back foreign effects" do
      P805.with_fixture(fn ->
        {_request, registration, credentials} = authenticated_fixture()
        before = %{tokens: token_signature(), sessions: session_signature()}
        parent = self()
        reference = make_ref()

        foreign =
          P805.independent_fixture_task(fn -> foreign_maintenance_fixture(parent, reference) end)

        try do
          assert_receive {^reference, :ready, other}, 5_000
          assert %{tokens: token_signature(), sessions: session_signature()} == before

          with_rolled_back_maintenance(fn ->
            case unquote(maintenance) do
              :tokens ->
                assert :ok =
                         AshAuthentication.TokenResource.Actions.expunge_expired(Identity.Token)

                removed? =
                  is_nil(
                    Ash.get!(Identity.Token, other.token_jti,
                      authorize?: false,
                      not_found_error?: false
                    )
                  )

                assert removed?

                assert Ash.get!(Identity.Session, other.session_id, authorize?: false).state ==
                         :active

              :sessions ->
                due =
                  P805.scalar(
                    "SELECT count(*) FROM sessions WHERE state = 'active' AND (expires_at <= now() OR idle_expires_at <= now())"
                  )

                assert due >= 1

                for batch <- 0..div(due - 1, 100) do
                  expected = min(due - batch * 100, 100)
                  assert {:ok, ^expected} = Identity.expire_due_sessions()
                end

                assert Ash.get!(Identity.Session, other.session_id, authorize?: false).state ==
                         :expired
            end
          end)

          assert %{tokens: token_signature(), sessions: session_signature()} == before

          # This owned Session has neither the expected Account association nor
          # a parent Token. Capture must observe its creation, not infer ownership
          # from those links. The deliberate orphan exists only in this rollback.
          assert {:error, :orphan_probe} =
                   NewYou.Repo.transaction(fn ->
                     own_session =
                       Ash.get!(Identity.Session, credentials.session_id, authorize?: false)

                     NewYou.Repo.query!("UPDATE tokens SET account_id = $1 WHERE jti = $2", [
                       Ecto.UUID.dump!(other.account_id),
                       own_session.token_jti
                     ])

                     refute token_signature() == before.tokens
                     now = DateTime.utc_now() |> DateTime.truncate(:second)

                     Ash.create!(
                       Identity.Session,
                       %{
                         account_id: other.account_id,
                         token_jti: Ecto.UUID.generate(),
                         expires_at: DateTime.add(now, 300),
                         idle_expires_at: DateTime.add(now, 300),
                         last_seen_at: now
                       },
                       action: :issue,
                       authorize?: false
                     )

                     refute session_signature() == before.sessions
                     NewYou.Repo.rollback(:orphan_probe)
                   end)

          assert session_signature() == before.sessions

          assert Ash.get!(Identity.Account, registration.account_id, authorize?: false).account_status ==
                   :open

          send(foreign.pid, {reference, :verify})
          assert_receive {^reference, :preserved, true}, 5_000
        after
          send(foreign.pid, {reference, :release})
          assert :ok = Task.await(foreign, 10_000)
        end
      end)
    end
  end

  defp authenticated_fixture do
    request = P805.request()
    {:ok, registration} = Identity.register(request)
    {:ok, :verified} = Identity.verify_email(registration.verification_proof)
    {:ok, credentials} = Identity.authenticate_password(request.email, request.password)
    {request, registration, credentials}
  end

  defp foreign_maintenance_fixture(parent, reference) do
    {_request, registration, credentials} = authenticated_fixture()
    assert {:ok, _} = Identity.authorize_session(credentials)
    session = Ash.get!(Identity.Session, credentials.session_id, authorize?: false)

    NewYou.Repo.query!(
      "UPDATE tokens SET expires_at = now() - interval '1 hour' WHERE jti = $1",
      [session.token_jti]
    )

    NewYou.Repo.query!(
      "UPDATE sessions SET expires_at = now() - interval '1 hour' WHERE id = $1",
      [Ecto.UUID.dump!(session.id)]
    )

    before = %{tokens: token_signature(), sessions: session_signature()}

    send(
      parent,
      {reference, :ready,
       %{
         account_id: registration.account_id,
         session_id: session.id,
         token_jti: session.token_jti
       }}
    )

    receive do
      {^reference, :verify} ->
        preserved? = %{tokens: token_signature(), sessions: session_signature()} == before
        send(parent, {reference, :preserved, preserved?})
        receive do: ({^reference, :release} -> :ok)

      {^reference, :release} ->
        :ok
    after
      10_000 -> raise "foreign maintenance fixture release deadline"
    end
  end

  # Use Ecto's sandbox transaction rather than nesting an outer Repo transaction.
  # Ash denials roll back their own savepoint without aborting the whole proof.
  defp with_rolled_back_maintenance(callback) do
    sandbox = Ecto.Adapters.SQL.Sandbox
    :ok = sandbox.checkin(NewYou.Repo)
    :ok = sandbox.checkout(NewYou.Repo)

    try do
      callback.()
    after
      :ok = sandbox.checkin(NewYou.Repo)
      :ok = sandbox.checkout(NewYou.Repo, sandbox: false)
    end
  end

  defp token_signature, do: FixtureObservation.fingerprint(:tokens)

  defp session_signature, do: FixtureObservation.fingerprint(:sessions)

  defp await_account_lock(holder, login, deadline) do
    case NewYou.Repo.query!("SELECT $1 = ANY(pg_blocking_pids($2))", [holder, login]).rows do
      [[true]] ->
        true

      _ ->
        System.monotonic_time(:millisecond) < deadline and
          await_account_lock(holder, login, deadline)
    end
  end
end
