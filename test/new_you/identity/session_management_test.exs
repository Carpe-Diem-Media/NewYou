defmodule NewYou.Identity.SessionManagementTest do
  use ExUnit.Case, async: false

  require Ash.Query

  alias NewYou.Audit
  alias NewYou.Audit.EvidenceObligation
  alias NewYou.Identity
  alias NewYou.Identity.{Account, DeviceAssurance, PasswordSession, Session, Token}
  alias NewYou.Repo
  alias Ecto.Adapters.SQL.Sandbox
  alias NewYou.Proof.{P805, P809, PrivilegedAccessSeam, RecoveryScenarios, RegistrationSeam}

  test "global revocation requires fresh proof and a replay cannot affect a fresh Session" do
    P805.with_fixture(fn ->
      request = verified_account()
      initiator = sign_in(request)
      target = sign_in(request)
      foreign = verified_account() |> sign_in()
      terminal = sign_in(request)
      account_id = session(initiator).account_id
      device = RecoveryScenarios.trusted_device(account_id)
      foreign_device = RecoveryScenarios.trusted_device(session(foreign).account_id)
      {magic, independent_proof} = sign_in_magic(request, account_id)
      assert :ok = Identity.logout(terminal)

      assert {:error, :session_unavailable} =
               Identity.revoke_all_sessions(initiator, "incorrect password", nil)

      assert session(initiator).state == :active
      assert session(target).state == :active

      assert {:ok, :revoked} = Identity.revoke_all_sessions(initiator, request.password, nil)

      for credentials <- [initiator, target, magic] do
        assert %{state: :revoked, step_up_purpose: nil, token_jti: jti} = session(credentials)
        assert Ash.get!(Token, jti, authorize?: false).purpose == "revocation"
        assert {:error, :authentication_unavailable} = Identity.authorize_session(credentials)
      end

      assert Ash.get!(DeviceAssurance, device, authorize?: false).state == :revoked
      assert Ash.get!(DeviceAssurance, foreign_device, authorize?: false).state == :trusted
      assert Ash.get!(Token, independent_proof, authorize?: false).purpose == "magic_login"
      assert session(terminal).state == :logged_out
      assert {:ok, _} = Identity.authorize_session(foreign)
      fresh = sign_in(request)

      assert {:error, :session_unavailable} =
               Identity.revoke_all_sessions(initiator, request.password, nil)

      assert {:ok, _} = Identity.authorize_session(fresh)

      assert [%{outcome: :succeeded}] =
               EvidenceObligation
               |> Ash.Query.filter(source_operation_id == ^initiator.session_id)
               |> Ash.read!(authorize?: false)
    end)
  end

  test "an enrolled factor requires a fresh current code and preserves strict replay protection" do
    previous = Application.fetch_env(:new_you, :identity_mfa_keyring)

    Application.put_env(:new_you, :identity_mfa_keyring, %{
      active_version: "test-v1",
      keys: %{"test-v1" => :crypto.strong_rand_bytes(32)}
    })

    try do
      P805.with_fixture(fn ->
        request = verified_account()
        initiator = sign_in(request)
        target = sign_in(request)
        timestamp = 1_800_000_000
        Process.put(PrivilegedAccessSeam, timestamp)

        assert {:ok, %{secret: secret}} =
                 Identity.enroll_privileged_mfa(initiator, request.password)

        assert {:error, :session_unavailable} =
                 Identity.revoke_all_sessions(initiator, request.password, nil)

        confirmation = NimbleTOTP.verification_code(secret, time: timestamp)

        assert {:ok, :ok} =
                 Identity.confirm_privileged_mfa(initiator, request.password, confirmation)

        assert {:ok, %{mfa_required?: true}} = Identity.global_session_revocation_form(initiator)

        assert {:error, :session_unavailable} =
                 Identity.revoke_all_sessions(initiator, request.password, confirmation)

        assert session(target).state == :active
        fresh_timestamp = timestamp + 30
        Process.put(PrivilegedAccessSeam, fresh_timestamp)
        code = NimbleTOTP.verification_code(secret, time: fresh_timestamp)
        assert {:ok, :revoked} = Identity.revoke_all_sessions(initiator, request.password, code)
        assert session(target).state == :revoked
      end)
    after
      Process.delete(PrivilegedAccessSeam)

      case previous do
        {:ok, value} -> Application.put_env(:new_you, :identity_mfa_keyring, value)
        :error -> Application.delete_env(:new_you, :identity_mfa_keyring)
      end
    end
  end

  test "global Audit rejection rolls back Sessions, tokens, assurance and devices" do
    P805.with_fixture(fn ->
      request = verified_account()
      initiator = sign_in(request)
      target = sign_in(request)
      account_id = session(initiator).account_id
      device = RecoveryScenarios.trusted_device(account_id)

      assert {:ok, _} =
               Ash.transact(Account, fn ->
                 Audit.establish_identity_security_obligation(%{
                   source_operation_id: initiator.session_id,
                   source_occurred_at: ~U[2025-01-01 00:00:00Z],
                   evidence_type: :identity_session_revoked,
                   actor_id: account_id,
                   target_id: account_id,
                   outcome: :failed
                 })
               end)

      assert {:error, :session_revocation_failed} =
               Identity.revoke_all_sessions(initiator, request.password, nil)

      for credentials <- [initiator, target] do
        assert %{state: :active, step_up_purpose: nil, token_jti: jti} = session(credentials)
        assert Ash.get!(Token, jti, authorize?: false).purpose == "user"
        assert {:ok, _} = Identity.authorize_session(credentials)
      end

      assert Ash.get!(DeviceAssurance, device, authorize?: false).state == :trusted
    end)
  end

  @tag timeout: 120_000
  test "an unacknowledged global commit survives restart and a stale retry cannot end fresh authority" do
    P805.with_fixture(fn ->
      request = verified_account()
      initiator = sign_in(request)
      target = sign_in(request)
      assert :allowed = P809.restart_process(target)

      Process.put({PasswordSession, :lose_revocation_acknowledgement}, true)

      try do
        assert {:error, :session_result_uncertain} =
                 Identity.revoke_all_sessions(initiator, request.password, nil)
      after
        Process.delete({PasswordSession, :lose_revocation_acknowledgement})
      end

      assert :denied = P809.restart_process(initiator)
      assert :denied = P809.restart_process(target)
      fresh = sign_in(request)

      assert {:error, :session_unavailable} =
               Identity.revoke_all_sessions(initiator, request.password, nil)

      assert {:ok, %{sessions: [%{id: id, current?: true}]}} =
               Identity.list_active_sessions(fresh)

      assert id == fresh.session_id
    end)
  end

  test "independent PostgreSQL connections order password issuance around global revocation" do
    P805.with_fixture(fn ->
      request = verified_account()
      initiator = sign_in(request)

      issue = fn -> Identity.authenticate_password(request.email, request.password) end
      revoke = fn -> Identity.revoke_all_sessions(initiator, request.password, nil) end

      assert {{:ok, before_boundary}, {:ok, :revoked}} = ordered_operations(issue, revoke)
      assert session(before_boundary).state == :revoked

      second_initiator = sign_in(request)

      revoke_again = fn ->
        Identity.revoke_all_sessions(second_initiator, request.password, nil)
      end

      assert {{:ok, :revoked}, {:ok, after_boundary}} = ordered_operations(revoke_again, issue)
      assert session(second_initiator).state == :revoked
      assert {:ok, _} = Identity.authorize_session(after_boundary)
    end)
  end

  test "a current Session lists only its own usable Sessions with minimal metadata" do
    P805.with_fixture(fn ->
      request = verified_account()
      initiator = sign_in(request)
      target = sign_in(request)
      ended = sign_in(request)
      foreign = verified_account() |> sign_in()
      assert :ok = Identity.logout(ended)
      original = session(target)

      assert {:ok, %{sessions: sessions, next_cursor: nil}} =
               Identity.list_active_sessions(initiator)

      assert MapSet.new(Enum.map(sessions, & &1.id)) ==
               MapSet.new([initiator.session_id, target.session_id])

      assert Enum.find(sessions, & &1.current?).id == initiator.session_id

      assert Enum.all?(
               sessions,
               &(Enum.sort(Map.keys(&1)) == [:created_at, :current?, :id, :last_seen_at])
             )

      assert session(target).last_seen_at == original.last_seen_at
      refute Enum.any?(sessions, &(&1.id == foreign.session_id))
      assert {:error, :authentication_unavailable} = Identity.list_active_sessions(ended)
    end)
  end

  test "the bounded page cursor continues within the authenticated Account" do
    P805.with_fixture(fn ->
      request = verified_account()
      initiator = sign_in(request)
      sessions = for _ <- 1..20, do: sign_in(request)
      foreign = verified_account() |> sign_in()

      assert {:ok, %{sessions: first, next_cursor: cursor}} =
               Identity.list_active_sessions(initiator)

      assert length(first) == 20
      assert cursor == List.last(first).id

      assert {:ok, %{sessions: [%{id: remaining}], next_cursor: nil}} =
               Identity.list_active_sessions(initiator, cursor)

      assert Enum.sort([remaining | Enum.map(first, & &1.id)]) ==
               Enum.sort(Enum.map([initiator | sessions], & &1.session_id))

      assert {:ok, %{sessions: foreign_page}} =
               Identity.list_active_sessions(initiator, foreign.session_id)

      refute Enum.any?(foreign_page, &(&1.id == foreign.session_id))
    end)
  end

  test "only one other owned Session is revoked and replay preserves its terminal result" do
    P805.with_fixture(fn ->
      request = verified_account()
      initiator = sign_in(request)
      target = sign_in(request)
      untouched = sign_in(request)
      foreign = verified_account() |> sign_in()
      unknown = Ecto.UUID.generate()

      for rejected_id <- [initiator.session_id, foreign.session_id, unknown] do
        assert {:error, :session_unavailable} =
                 Identity.revoke_other_session(initiator, rejected_id)
      end

      assert {:ok, :revoked} = Identity.revoke_other_session(initiator, target.session_id)

      assert %{state: :revoked, ended_at: %DateTime{}, step_up_purpose: nil} =
               ended = session(target)

      assert {:ok, :already_ended} = Identity.revoke_other_session(initiator, target.session_id)
      assert session(target).ended_at == ended.ended_at

      assert [obligation] =
               EvidenceObligation
               |> Ash.Query.filter(
                 source_operation_id == ^target.session_id and
                   evidence_type == :identity_session_revoked
               )
               |> Ash.read!(authorize?: false)

      assert obligation.actor_id == ended.account_id
      assert obligation.target_id == ended.account_id
      assert obligation.outcome == :succeeded

      assert {:ok, materialized} =
               Audit.materialize_registration_evidence(%{primary_key: %{id: obligation.id}},
                 authorize?: false
               )

      assert {:ok, ^materialized} =
               Audit.materialize_registration_evidence(%{primary_key: %{id: obligation.id}},
                 authorize?: false
               )

      assert {:ok, _, _} = AshAuthentication.Jwt.verify(target.token, Identity.Account)
      assert {:error, :authentication_unavailable} = Identity.authorize_session(target)

      for still_valid <- [initiator, untouched, foreign] do
        assert {:ok, _} = Identity.authorize_session(still_valid)
      end
    end)
  end

  test "active rows with an expired deadline or revoked token neither appear nor accept revocation" do
    P805.with_fixture(fn ->
      request = verified_account()
      initiator = sign_in(request)
      stale_session = sign_in(request)
      stale_token = sign_in(request)
      usable = sign_in(request)

      Repo.query!(
        "UPDATE sessions SET idle_expires_at = now() - interval '1 second' WHERE id = $1",
        [
          Ecto.UUID.dump!(stale_session.session_id)
        ]
      )

      stale_token_row = session(stale_token)
      token = Ash.get!(Token, stale_token_row.token_jti, authorize?: false)
      assert {:ok, _} = Ash.update(token, %{}, action: :revoke_authentication, authorize?: false)

      assert {:ok, %{sessions: sessions}} = Identity.list_active_sessions(initiator)

      assert Enum.sort(Enum.map(sessions, & &1.id)) ==
               Enum.sort([initiator.session_id, usable.session_id])

      for stale <- [stale_session, stale_token] do
        assert {:ok, :stale} = Identity.revoke_other_session(initiator, stale.session_id)
        assert %{state: :active, ended_at: nil} = session(stale)
        assert {:error, :authentication_unavailable} = Identity.list_active_sessions(stale)
      end

      Repo.query!("UPDATE accounts SET security_posture = 'held' WHERE id = $1", [
        Ecto.UUID.dump!(session(initiator).account_id)
      ])

      assert {:error, :authentication_unavailable} = Identity.list_active_sessions(initiator)

      assert {:error, :session_unavailable} =
               Identity.revoke_other_session(initiator, usable.session_id)

      assert %{state: :active, ended_at: nil} = session(usable)
    end)
  end

  test "conflicting Audit evidence rolls back revocation and the list reconciles the result" do
    P805.with_fixture(fn ->
      request = verified_account()
      initiator = sign_in(request)
      target = sign_in(request)
      account_id = session(target).account_id

      assert {:ok, _} =
               Ash.transact(Account, fn ->
                 Audit.establish_identity_security_obligation(%{
                   source_operation_id: target.session_id,
                   source_occurred_at: ~U[2025-01-01 00:00:00Z],
                   evidence_type: :identity_session_revoked,
                   actor_id: account_id,
                   target_id: account_id,
                   outcome: :failed
                 })
               end)

      assert {:error, :session_revocation_failed} =
               Identity.revoke_other_session(initiator, target.session_id)

      assert %{state: :active, ended_at: nil} = session(target)
      assert {:ok, _} = Identity.authorize_session(target)
      assert {:ok, %{sessions: visible}} = Identity.list_active_sessions(initiator)
      assert Enum.any?(visible, &(&1.id == target.session_id))
    end)
  end

  @tag timeout: 120_000
  test "independent connections arbitrate a race and fresh BEAMs observe the committed owner state" do
    P805.with_fixture(fn ->
      request = verified_account()
      initiator = sign_in(request)
      target = sign_in(request)
      assert :allowed = P809.restart_process(target)
      parent = self()

      contenders =
        for _ <- 1..2 do
          Task.async(fn ->
            :ok = Sandbox.checkout(Repo, sandbox: false)

            try do
              send(parent, {:ready, self()})

              receive do
                :revoke -> Identity.revoke_other_session(initiator, target.session_id)
              after
                5_000 -> :timeout
              end
            after
              Sandbox.checkin(Repo)
            end
          end)
        end

      for task <- contenders do
        pid = task.pid
        assert_receive {:ready, ^pid}, 5_000
      end

      Enum.each(contenders, &send(&1.pid, :revoke))

      assert Enum.sort(Task.await_many(contenders, 10_000)) ==
               [{:ok, :already_ended}, {:ok, :revoked}]

      assert :denied = P809.restart_process(target)
      assert :allowed = P809.restart_process(initiator)
    end)
  end

  defp verified_account do
    request = P805.request(%{email: "sessions-#{Ecto.UUID.generate()}@example.test"})
    assert {:ok, result} = Identity.register(request)
    assert {:ok, :verified} = Identity.verify_email(result.verification_proof)
    request
  end

  defp ordered_operations(first, second) do
    parent = self()
    reference = make_ref()

    holder =
      separate_connection(fn ->
        Process.put(RegistrationSeam, {:pause, parent, reference})
        first.()
      end)

    assert_receive {^reference, :before_commit, worker, blocker, _transaction}, 5_000

    contender =
      separate_connection(fn ->
        %{rows: [[backend]]} = Repo.query!("SELECT pg_backend_pid()")
        send(parent, {reference, :contender, backend})
        second.()
      end)

    assert_receive {^reference, :contender, backend}, 5_000
    assert await_blocker(blocker, backend, System.monotonic_time(:millisecond) + 5_000)
    send(worker, {reference, :release})
    assert [first_result, second_result] = Task.await_many([holder, contender], 10_000)
    {first_result, second_result}
  end

  defp separate_connection(callback) do
    Task.async(fn ->
      :ok = Sandbox.checkout(Repo, sandbox: false)

      try do
        callback.()
      after
        Sandbox.checkin(Repo)
      end
    end)
  end

  defp await_blocker(blocker, backend, deadline) do
    case Repo.query!("SELECT $1 = ANY(pg_blocking_pids($2))", [blocker, backend]).rows do
      [[true]] ->
        true

      _ ->
        System.monotonic_time(:millisecond) < deadline and
          await_blocker(blocker, backend, deadline)
    end
  end

  defp sign_in_magic(request, account_id) do
    operation = RecoveryScenarios.operation()
    assert :ok = Identity.request_magic_login(request.email, "en", operation)

    token =
      Token
      |> Ash.Query.filter(magic_request_id == ^operation)
      |> Ash.read_one!(authorize?: false)

    assert {:ok, {:ok, bearer}} =
             Ash.transact([Account, Token], fn ->
               Identity.magic_login_delivery(token.jti, request.email, "en")
             end)

    assert {:ok, credentials} = Identity.authenticate_magic_link(bearer)
    assert session(credentials).authentication_method == :magic_login

    next_operation = RecoveryScenarios.operation()
    assert :ok = Identity.request_magic_login(request.email, "en", next_operation)

    independent_proof =
      Token
      |> Ash.Query.filter(account_id == ^account_id and magic_request_id == ^next_operation)
      |> Ash.read_one!(authorize?: false)

    {credentials, independent_proof.jti}
  end

  defp sign_in(request) do
    assert {:ok, credentials} = Identity.authenticate_password(request.email, request.password)
    credentials
  end

  defp session(credentials), do: Ash.get!(Session, credentials.session_id, authorize?: false)
end
