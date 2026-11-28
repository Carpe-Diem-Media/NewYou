defmodule NewYou.Privacy.FixtureDisputePurposeTelemetryTest do
  use ExUnit.Case, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias NewYou.Privacy.FixtureDisputePurpose
  alias NewYou.Privacy.{FixtureDisputePurposeAuthority, FixtureDisputePurposeEvent}
  alias NewYou.Proof.P805
  alias NewYou.Repo
  require Ash.Query

  @query_event [:new_you, :repo, :query]

  test "purpose authority SQL omits subject, dispute and operation UUIDs from telemetry" do
    P805.with_fixture(fn ->
      subject_id = uuid()
      dispute_id = uuid()
      grant_operation = track_uuid()
      missing_operation = track_uuid()
      failed_operation = track_uuid()
      withdraw_failure_operation = track_uuid()
      race_operation = track_uuid()

      ids = [
        subject_id,
        dispute_id,
        grant_operation,
        missing_operation,
        failed_operation,
        withdraw_failure_operation,
        race_operation
      ]

      assert_clean(ids, fn ->
        assert {:ok, :allowed} =
                 FixtureDisputePurpose.grant(subject_id, grant_operation, dispute_id)
      end)

      assert_clean(ids, fn ->
        assert {:ok, proof} =
                 FixtureDisputePurpose.issue_proof(subject_id, grant_operation, dispute_id)

        assert proof.fields.subject_id == subject_id
      end)

      assert_clean(ids, fn ->
        assert {:ok, :withdrawn} =
                 FixtureDisputePurpose.withdraw(subject_id, grant_operation, dispute_id)
      end)

      assert_clean(ids, fn ->
        assert {:error, :withdrawn} =
                 FixtureDisputePurpose.grant(subject_id, grant_operation, dispute_id)
      end)

      assert_clean(ids, fn ->
        assert {:error, :privacy_authority_unavailable} =
                 FixtureDisputePurpose.withdraw(subject_id, missing_operation, dispute_id)
      end)

      P805.with_rejected_insert("privacy_fixture_dispute_purpose_events", fn reached? ->
        assert_clean(ids, fn ->
          assert {:error, :privacy_authority_unavailable} =
                   FixtureDisputePurpose.grant(subject_id, failed_operation, dispute_id)

          assert nil == authority(subject_id, failed_operation, dispute_id)
        end)

        assert reached?.()
      end)

      assert_clean(ids, fn ->
        assert {:ok, :allowed} =
                 FixtureDisputePurpose.grant(subject_id, withdraw_failure_operation, dispute_id)
      end)

      P805.with_rejected_insert("privacy_fixture_dispute_purpose_events", fn reached? ->
        assert_clean(ids, fn ->
          assert {:error, :privacy_authority_unavailable} =
                   FixtureDisputePurpose.withdraw(
                     subject_id,
                     withdraw_failure_operation,
                     dispute_id
                   )

          assert %{state: :allowed, version: 1} =
                   authority(subject_id, withdraw_failure_operation, dispute_id)

          assert [%{transition: :granted, version: 1}] =
                   events(subject_id, withdraw_failure_operation, dispute_id)
        end)

        assert reached?.()
      end)

      assert_clean(ids, fn ->
        assert {:error, :privacy_authority_denied} =
                 FixtureDisputePurpose.issue_proof(subject_id, missing_operation, dispute_id)
      end)

      assert_clean(ids, fn ->
        results = concurrent_grants(subject_id, race_operation, dispute_id)
        assert Enum.sort(results) == Enum.sort([{:ok, :allowed}, {:ok, :already_allowed}])

        assert %{state: :allowed, version: 1} =
                 authority(subject_id, race_operation, dispute_id)

        assert [%{transition: :granted, version: 1}] =
                 events(subject_id, race_operation, dispute_id)
      end)

      assert_clean(ids, fn ->
        assert {:ok, :already_allowed} =
                 FixtureDisputePurpose.grant(subject_id, race_operation, dispute_id)
      end)
    end)
  end

  defp assert_clean(ids, operation) do
    handler_id = {__MODULE__, make_ref()}
    observer = self()

    needles = Enum.flat_map(ids, fn id -> [id, Ecto.UUID.dump!(id)] end)

    assert :ok =
             :telemetry.attach(
               handler_id,
               @query_event,
               fn event, measurements, metadata, _ ->
                 encoded = :erlang.term_to_binary(metadata, [:deterministic])

                 if Enum.any?(needles, &binary_match?(encoded, &1)) do
                   send(observer, {:fixture_dispute_sql, event, measurements, metadata})
                 end
               end,
               nil
             )

    try do
      count = length(ids)

      assert {:ok, _} = Repo.query(probe_query(count, "text"), ids)
      assert_receive {:fixture_dispute_sql, @query_event, _, string_metadata}
      string_telemetry = :erlang.term_to_binary(string_metadata, [:deterministic])
      assert Enum.all?(ids, &binary_match?(string_telemetry, &1))

      assert {:ok, _} =
               Repo.query(probe_query(count, "uuid"), Enum.map(ids, &Ecto.UUID.dump!/1))

      assert_receive {:fixture_dispute_sql, @query_event, _, binary_metadata}
      binary_telemetry = :erlang.term_to_binary(binary_metadata, [:deterministic])

      assert Enum.all?(ids, fn id ->
               binary_match?(binary_telemetry, Ecto.UUID.dump!(id))
             end)

      flush_telemetry()
      operation.()
      refute_receive {:fixture_dispute_sql, @query_event, _, _}, 0
    after
      :telemetry.detach(handler_id)
    end
  end

  defp probe_query(count, type) do
    parameters = Enum.map_join(1..count, ", ", &"$#{&1}::#{type}")
    "SELECT #{parameters}"
  end

  defp concurrent_grants(subject_id, operation_id, dispute_id) do
    parent = self()

    table_lock = Task.async(fn -> hold_grant_table_lock(parent) end)

    assert_receive {:grant_table_lock, lock_owner, lock_backend}

    contenders =
      for _ <- 1..2 do
        Task.async(fn ->
          run_grant_contender(parent, subject_id, operation_id, dispute_id)
        end)
      end

    backends =
      for _ <- 1..2,
          do:
            (
              assert_receive {:grant_contender, backend}
              backend
            )

    assert length(Enum.uniq(backends)) == 2

    Enum.each(backends, fn backend ->
      assert_waiting_on_grant_insert(backend, lock_backend, 100)
    end)

    send(lock_owner, :release_grant_inserts)
    assert {:ok, _} = Task.await(table_lock)
    Task.await_many(contenders)
  end

  defp hold_grant_table_lock(parent) do
    Sandbox.unboxed_run(Repo, fn ->
      Repo.transaction(fn ->
        Repo.query!("LOCK TABLE privacy_fixture_dispute_purposes IN SHARE MODE")
        [[backend]] = Repo.query!("SELECT pg_backend_pid()").rows
        send(parent, {:grant_table_lock, self(), backend})

        receive do
          :release_grant_inserts -> :released
        end
      end)
    end)
  end

  defp run_grant_contender(parent, subject_id, operation_id, dispute_id) do
    Sandbox.unboxed_run(Repo, fn ->
      [[backend]] = Repo.query!("SELECT pg_backend_pid()").rows
      send(parent, {:grant_contender, backend})
      FixtureDisputePurpose.grant(subject_id, operation_id, dispute_id)
    end)
  end

  defp assert_waiting_on_grant_insert(_backend, _blocker, 0),
    do: flunk("grant contender did not block on the held table lock")

  defp assert_waiting_on_grant_insert(backend, blocker, attempts) do
    case Repo.query!(
           """
           SELECT wait_event_type, query, $2::integer = ANY(pg_blocking_pids($1::integer))
           FROM pg_stat_activity
           WHERE pid = $1::integer
           """,
           [backend, blocker]
         ).rows do
      [["Lock", query, true]] ->
        assert query =~ ~s(INSERT INTO "privacy_fixture_dispute_purposes")

      _ ->
        Process.sleep(20)
        assert_waiting_on_grant_insert(backend, blocker, attempts - 1)
    end
  end

  defp binary_match?(metadata, value) do
    match?({_, _}, :binary.match(metadata, value))
  end

  defp flush_telemetry do
    receive do
      {:fixture_dispute_sql, _, _, _} -> flush_telemetry()
    after
      0 -> :ok
    end
  end

  defp track_uuid do
    id = uuid()
    P805.track_operation(id)
    id
  end

  defp authority(subject_id, operation_id, dispute_id) do
    Repo.without_query_telemetry(fn ->
      FixtureDisputePurposeAuthority
      |> Ash.Query.filter(
        subject_id == ^subject_id and source_operation_id == ^operation_id and
          dispute_id == ^dispute_id
      )
      |> Ash.read_one!(authorize?: false)
    end)
  end

  defp events(subject_id, operation_id, dispute_id) do
    Repo.without_query_telemetry(fn ->
      FixtureDisputePurposeEvent
      |> Ash.Query.filter(
        subject_id == ^subject_id and source_operation_id == ^operation_id and
          dispute_id == ^dispute_id
      )
      |> Ash.read!(authorize?: false)
    end)
  end

  defp uuid, do: Ecto.UUID.generate()
end
