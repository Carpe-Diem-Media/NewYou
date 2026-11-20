defmodule NewYou.Identity.SessionManagementTest do
  use ExUnit.Case, async: false

  require Ash.Query

  alias NewYou.Audit
  alias NewYou.Audit.EvidenceObligation
  alias NewYou.Identity
  alias NewYou.Identity.{Account, Session, Token}
  alias NewYou.Repo
  alias Ecto.Adapters.SQL.Sandbox
  alias NewYou.Proof.P809
  alias NewYou.Proof.P805

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

  defp sign_in(request) do
    assert {:ok, credentials} = Identity.authenticate_password(request.email, request.password)
    credentials
  end

  defp session(credentials), do: Ash.get!(Session, credentials.session_id, authorize?: false)
end
