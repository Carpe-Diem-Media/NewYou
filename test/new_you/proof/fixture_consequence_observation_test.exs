defmodule NewYou.Proof.FixtureConsequenceObservationTest do
  use ExUnit.Case, async: false
  alias NewYou.Identity
  alias NewYou.Repo
  alias NewYou.Proof.{FixtureObservation, P805}
  require Ash.Query

  test "independent fixture writes do not change the selected owner's observations" do
    P805.with_fixture(fn ->
      own = P805.request()
      assert {:ok, registration} = Identity.register(own)
      before = P805.counts([own.operation_id], [own.email])
      parent = self()
      reference = make_ref()

      foreign =
        P805.independent_fixture_task(fn ->
          assert {:ok, _} = Identity.register(P805.request())
          send(parent, {reference, :foreign_committed})

          receive do
            {^reference, :release} -> :ok
          after
            10_000 -> raise "diagnostic release timeout"
          end
        end)

      try do
        assert_receive {^reference, :foreign_committed}, 5_000
        during = P805.counts([own.operation_id], [own.email])

        own_tokens =
          Identity.Token
          |> Ash.Query.filter(account_id == ^registration.account_id)
          |> Ash.read!(domain: Identity, authorize?: false)

        assert length(own_tokens) == 1
        assert during == before
      after
        send(foreign.pid, {reference, :release})
        assert :ok = Task.await(foreign, 15_000)
      end

      assert P805.counts([own.operation_id], [own.email]) == before
    end)
  end

  test "owned tokens and orphan children remain observable without the expected associations" do
    with_foreign_fixture(fn foreign ->
      P805.with_fixture(fn ->
        request = P805.request()
        assert {:ok, registration} = Identity.register(request)
        {:ok, claims} = AshAuthentication.Jwt.peek(registration.verification_proof)
        before = P805.counts()
        assert before == [1, 1, 1, 0, 1, 1, 1, 1, 1, 1]

        assert {:error, :orphan_probe} =
                 Repo.transaction(fn ->
                   # Mutate only this fixture's freshly created Token. The unrelated
                   # Account is merely the wrong association, not a cleanup target.
                   Repo.query!("UPDATE tokens SET account_id = $1 WHERE jti = $2", [
                     Ecto.UUID.dump!(foreign.account_id),
                     claims["jti"]
                   ])

                   Repo.query!("DELETE FROM registration_operations WHERE operation_id = $1", [
                     Ecto.UUID.dump!(request.operation_id)
                   ])

                   Repo.query!(
                     "DELETE FROM communications_protected_envelopes WHERE message_intent_id IN (SELECT id FROM message_intents WHERE source_operation_id = $1)",
                     [Ecto.UUID.dump!(request.operation_id)]
                   )

                   Repo.query!("INSERT INTO communications_envelope_nonces (nonce) VALUES ($1)", [
                     :crypto.strong_rand_bytes(12)
                   ])

                   Repo.query!(
                     "INSERT INTO oban_jobs (queue, worker, args) VALUES ('audit', 'NewYou.Audit.Workers.RegistrationEvidence', $1) RETURNING id",
                     [%{"primary_key" => %{"id" => Ecto.UUID.generate()}}]
                   )

                   observed = P805.counts()
                   assert Enum.at(observed, 1) == 1
                   assert Enum.at(observed, 2) == 0
                   assert Enum.at(observed, 5) == 0
                   assert Enum.at(observed, 6) == 2
                   assert Enum.at(observed, 8) == 2
                   Repo.rollback(:orphan_probe)
                 end)

        assert P805.counts() == before
      end)
    end)
  end

  test "foreign retained rows survive successful and raised owner teardown" do
    with_foreign_fixture(fn _foreign ->
      for outcome <- [:success, :raise] do
        run = fn ->
          P805.with_fixture(fn ->
            assert {:ok, _} = Identity.register(P805.request())
            if outcome == :raise, do: raise("owned fixture interrupted")
            :ok
          end)
        end

        if outcome == :raise,
          do: assert_raise(RuntimeError, "owned fixture interrupted", run),
          else: assert(:ok == run.())
      end
    end)
  end

  test "foreign retained rows survive abrupt owner cancellation and guardian teardown" do
    with_foreign_fixture(fn _foreign ->
      scenario = NewYou.Proof.Scenario.start()
      parent = self()
      reference = make_ref()

      {worker, monitor} =
        NewYou.Proof.Scenario.spawn(scenario, :cancelled_owner, fn ->
          P805.with_fixture(fn ->
            assert {:ok, _} = Identity.register(P805.request())
            send(parent, {reference, :owner_committed})
            receive do: (:never -> :ok)
          end)
        end)

      try do
        assert_receive {^reference, :owner_committed}, 5_000
        Process.exit(worker, :kill)
        assert_receive {:DOWN, ^monitor, :process, ^worker, :killed}, 5_000
      after
        if Process.alive?(worker), do: Process.exit(worker, :kill)
        assert {:error, [:worker_failed]} = NewYou.Proof.Scenario.stop(scenario)
      end
    end)
  end

  test "explicit recovery ownership detects unlinked writes and excludes rolled back rows" do
    P805.with_fixture(fn ->
      context = FixtureObservation.context()
      parent = self()
      reference = make_ref()

      {worker, monitor} =
        spawn_monitor(fn ->
          FixtureObservation.with_context(context, fn ->
            Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
              before = P805.counts([], [])

              assert {:error, :recovered_probe} =
                       Repo.transaction(fn ->
                         Repo.query!(
                           "INSERT INTO communications_envelope_nonces (nonce) VALUES ($1)",
                           [:crypto.strong_rand_bytes(12)]
                         )

                         assert Enum.at(P805.counts([], []), 6) == Enum.at(before, 6) + 1
                         Repo.rollback(:recovered_probe)
                       end)

              assert P805.counts([], []) == before
            end)
          end)

          send(parent, {reference, :proved})
        end)

      assert_receive {^reference, :proved}, 5_000
      assert_receive {:DOWN, ^monitor, :process, ^worker, :normal}, 5_000
      assert P805.counts() == List.duplicate(0, 10)
    end)
  end

  test "an owned generated key that cannot be captured fails observation visibly" do
    P805.with_fixture(fn ->
      assert {:error, :uncaptured_probe} =
               Repo.transaction(fn ->
                 Repo.query!(
                   "INSERT INTO oban_jobs (queue, worker, args) VALUES ('audit', 'NewYou.Audit.Workers.RegistrationEvidence', $1)",
                   [%{"primary_key" => %{"id" => Ecto.UUID.generate()}}]
                 )

                 assert_raise RuntimeError,
                              ~r/fixture INSERT into oban_jobs requires an attributable returned key/,
                              fn -> P805.counts() end

                 Repo.rollback(:uncaptured_probe)
               end)
    end)
  end

  # Only one fixture holds the environment lease at a time. The retained
  # registration has explicit synthetic identities claimed during its own cleanup.
  defp with_foreign_fixture(fun) do
    operation = Ecto.UUID.generate()
    email = "proof-#{operation}@example.test"

    try do
      {foreign, before} =
        P805.with_fixture(fn ->
          request = %{P805.request() | operation_id: operation, email: email}
          assert {:ok, registration} = Identity.register(request)
          {registration, signature(operation, registration.account_id)}
        end)

      try do
        fun.(foreign)
      after
        Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
          assert signature(operation, foreign.account_id) == before
        end)
      end
    after
      P805.with_fixture(fn -> P805.request(%{operation_id: operation, email: email}) end)
    end
  end

  defp signature(operation, account) do
    operation = Ecto.UUID.dump!(operation)
    account = Ecto.UUID.dump!(account)

    queries = [
      {"SELECT row_to_json(t)::text FROM accounts t WHERE id = $1", [account]},
      {"SELECT row_to_json(t)::text FROM tokens t WHERE account_id = $1 ORDER BY jti", [account]},
      {"SELECT row_to_json(t)::text FROM registration_operations t WHERE operation_id = $1",
       [operation]},
      {"SELECT row_to_json(t)::text FROM message_intents t WHERE source_operation_id = $1 ORDER BY id",
       [operation]},
      {"SELECT row_to_json(t)::text FROM communications_protected_envelopes t WHERE message_intent_id IN (SELECT id FROM message_intents WHERE source_operation_id = $1)",
       [operation]},
      {"SELECT row_to_json(t)::text FROM communications_envelope_nonces t WHERE nonce IN (SELECT nonce FROM communications_protected_envelopes WHERE message_intent_id IN (SELECT id FROM message_intents WHERE source_operation_id = $1))",
       [operation]},
      {"SELECT row_to_json(t)::text FROM evidence_obligations t WHERE source_operation_id = $1 ORDER BY id",
       [operation]},
      {"SELECT row_to_json(t)::text FROM oban_jobs t WHERE args->'primary_key'->>'id' IN (SELECT id::text FROM evidence_obligations WHERE source_operation_id = $1) ORDER BY id",
       [operation]}
    ]

    # Keep foreign record contents out of ExUnit assertion output.
    queries
    |> Enum.map(fn {sql, args} -> Repo.query!(sql, args).rows end)
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
  end
end
