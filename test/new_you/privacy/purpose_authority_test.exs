defmodule NewYou.Privacy.PurposeAuthorityTest do
  use ExUnit.Case, async: false

  require Ash.Query

  alias NewYou.{Identity, Privacy, Repo}
  alias NewYou.Privacy.{PurposeAuthority, PurposeEvent}
  alias NewYou.Proof.{P805, P817PrivacySeam, Scenario}
  alias Ecto.Adapters.SQL.Sandbox

  test "proof-only purpose records positive authority, terminal withdrawal and immutable history" do
    P805.with_fixture(fn ->
      request = P805.request()
      operation_id = Ecto.UUID.generate()
      P805.track_operation(operation_id)
      {:ok, registration} = Identity.register(request)

      assert {:ok, :missing} =
               Privacy.current_p817_proof_purpose(registration.account_id, operation_id)

      assert {:error, :missing} =
               Privacy.withdraw_p817_proof_purpose(registration.account_id, operation_id)

      assert {:ok, :allowed} =
               Privacy.grant_p817_proof_purpose(registration.account_id, operation_id)

      assert {:ok, :already_allowed} =
               Privacy.grant_p817_proof_purpose(registration.account_id, operation_id)

      assert {:ok, :allowed} =
               Privacy.current_p817_proof_purpose(registration.account_id, operation_id)

      assert {:ok, :withdrawn} =
               Privacy.withdraw_p817_proof_purpose(registration.account_id, operation_id)

      assert {:ok, :already_withdrawn} =
               Privacy.withdraw_p817_proof_purpose(registration.account_id, operation_id)

      assert {:error, :withdrawn} =
               Privacy.grant_p817_proof_purpose(registration.account_id, operation_id)

      assert {:ok, :withdrawn} =
               Privacy.current_p817_proof_purpose(registration.account_id, operation_id)

      authority =
        PurposeAuthority
        |> Ash.Query.filter(
          subject_id == ^registration.account_id and source_operation_id == ^operation_id
        )
        |> Ash.read_one!(authorize?: false)

      events =
        PurposeEvent
        |> Ash.Query.filter(authority_id == ^authority.id)
        |> Ash.Query.sort(version: :asc)
        |> Ash.read!(authorize?: false)

      assert Enum.map(events, &{&1.transition, &1.version, &1.origin}) == [
               {:granted, 1, :p8_17_test_fixture},
               {:withdrawn, 2, :p8_17_test_fixture}
             ]

      assert {:error, _} =
               Ash.transact([PurposeAuthority], fn ->
                 Privacy.require_current_p817_proof_purpose_locked(
                   registration.account_id,
                   operation_id
                 )
               end)

      assert_raise Postgrex.Error, fn ->
        Repo.query!("UPDATE privacy_purpose_events SET version = 3 WHERE id = $1", [
          events |> hd() |> Map.fetch!(:id) |> Ecto.UUID.dump!()
        ])
      end

      assert_raise Postgrex.Error, fn ->
        Repo.query!("DELETE FROM privacy_purpose_events WHERE id = $1", [
          events |> hd() |> Map.fetch!(:id) |> Ecto.UUID.dump!()
        ])
      end

      assert_raise Postgrex.Error, fn ->
        Repo.query!(
          "UPDATE privacy_purpose_authorities SET state = 'allowed', version = 3 WHERE id = $1",
          [Ecto.UUID.dump!(authority.id)]
        )
      end

      assert_raise Postgrex.Error, fn ->
        Repo.query!("DELETE FROM privacy_purpose_authorities WHERE id = $1", [
          Ecto.UUID.dump!(authority.id)
        ])
      end

      fresh_process_result =
        Task.async(fn ->
          :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo, sandbox: false)

          try do
            Privacy.current_p817_proof_purpose(registration.account_id, operation_id)
          after
            Ecto.Adapters.SQL.Sandbox.checkin(Repo)
          end
        end)
        |> Task.await(10_000)

      assert fresh_process_result == {:ok, :withdrawn}
    end)
  end

  test "PostgreSQL rejects an authority transition without its matching event" do
    P805.with_fixture(fn ->
      request = P805.request()
      operation_id = Ecto.UUID.generate()
      P805.track_operation(operation_id)
      {:ok, registration} = Identity.register(request)

      assert_raise Postgrex.Error, fn ->
        Ash.transact([PurposeAuthority], fn ->
          Ash.create(
            PurposeAuthority,
            %{
              subject_id: registration.account_id,
              source_operation_id: operation_id,
              purpose: :p8_17_protected_mutation,
              state: :allowed,
              origin: :p8_17_test_fixture,
              version: 1
            },
            action: :grant_proof_only,
            authorize?: false
          )
        end)
      end

      assert {:ok, :missing} =
               Privacy.current_p817_proof_purpose(registration.account_id, operation_id)

      assert {:ok, :allowed} =
               Privacy.grant_p817_proof_purpose(registration.account_id, operation_id)

      authority =
        PurposeAuthority
        |> Ash.Query.filter(
          subject_id == ^registration.account_id and source_operation_id == ^operation_id
        )
        |> Ash.read_one!(authorize?: false)

      assert_raise Postgrex.Error, fn ->
        Ash.transact([PurposeAuthority], fn ->
          Ash.update(
            authority,
            %{version: authority.version + 1},
            action: :withdraw_proof_only,
            authorize?: false
          )
        end)
      end

      assert {:ok, :allowed} =
               Privacy.current_p817_proof_purpose(registration.account_id, operation_id)
    end)
  end

  test "PostgreSQL rejects an initial withdrawn authority even with matching history" do
    P805.with_fixture(fn ->
      subject_id = Ecto.UUID.generate()
      operation_id = Ecto.UUID.generate()
      authority_id = Ecto.UUID.generate()

      assert_raise Postgrex.Error, ~r/privacy_purpose_authorities_initial_state/, fn ->
        Repo.transaction(fn ->
          Repo.query!(
            """
            INSERT INTO privacy_purpose_authorities
              (id, subject_id, source_operation_id, purpose, state, origin, version)
            VALUES ($1, $2, $3, 'p8_17_protected_mutation', 'withdrawn',
                    'p8_17_test_fixture', 2)
            """,
            Enum.map([authority_id, subject_id, operation_id], &Ecto.UUID.dump!/1)
          )

          Repo.query!(
            """
            INSERT INTO privacy_purpose_events
              (authority_id, subject_id, source_operation_id, purpose, transition, origin, version)
            VALUES ($1, $2, $3, 'p8_17_protected_mutation', 'withdrawn',
                    'p8_17_test_fixture', 2)
            """,
            Enum.map([authority_id, subject_id, operation_id], &Ecto.UUID.dump!/1)
          )
        end)
      end
    end)
  end

  test "concurrent first grants resolve to one current authority and one event" do
    P805.with_fixture(fn ->
      request = P805.request()
      operation_id = Ecto.UUID.generate()
      P805.track_operation(operation_id)
      {:ok, registration} = Identity.register(request)

      scenario = Scenario.start()
      parent = self()
      reference = make_ref()

      try do
        workers =
          for label <- [:first_grant, :second_grant], into: %{} do
            {worker, monitor} =
              Scenario.spawn(scenario, label, fn ->
                :ok = Sandbox.checkout(Repo, sandbox: false)
                Process.put(P817PrivacySeam, {:pause, parent, reference, :grant_after_missing})

                try do
                  result = Privacy.grant_p817_proof_purpose(registration.account_id, operation_id)
                  send(parent, {reference, :grant_result, self(), result})
                after
                  :ok = Sandbox.checkin(Repo)
                end
              end)

            {label, {worker, monitor}}
          end

        first = await_grant_checkpoint(reference)
        second = await_grant_checkpoint(reference)

        assert first.worker != second.worker
        assert first.backend != second.backend
        assert first.transaction != second.transaction

        send(first.worker, {reference, :release})
        send(second.worker, {reference, :release})

        results = [
          await_grant_result(reference, first.worker),
          await_grant_result(reference, second.worker)
        ]

        assert Enum.count(results, &(&1 == {:ok, :allowed})) == 1
        assert Enum.count(results, &(&1 == {:ok, :already_allowed})) == 1

        Enum.each(workers, fn {_label, {_worker, monitor}} ->
          assert_receive {:DOWN, ^monitor, :process, _worker, :normal}, 15_000
        end)

        assert {:ok, :allowed} =
                 Privacy.current_p817_proof_purpose(registration.account_id, operation_id)

        authority =
          PurposeAuthority
          |> Ash.Query.filter(
            subject_id == ^registration.account_id and source_operation_id == ^operation_id
          )
          |> Ash.read_one!(authorize?: false)

        events =
          PurposeEvent
          |> Ash.Query.filter(authority_id == ^authority.id)
          |> Ash.read!(authorize?: false)

        assert length(events) == 1
        assert hd(events).transition == :granted
        assert hd(events).version == 1
      after
        Scenario.stop(scenario)
      end
    end)
  end

  defp await_grant_checkpoint(reference) do
    receive do
      {^reference, :p817_privacy_checkpoint, worker, backend, transaction, :grant_after_missing} ->
        %{worker: worker, backend: backend, transaction: transaction}
    after
      15_000 -> raise "concurrent Privacy grant checkpoint deadline"
    end
  end

  defp await_grant_result(reference, worker) do
    receive do
      {^reference, :grant_result, ^worker, result} -> result
    after
      15_000 -> raise "concurrent Privacy grant result deadline"
    end
  end
end
