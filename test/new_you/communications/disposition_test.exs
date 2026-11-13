defmodule NewYou.Communications.DispositionTest do
  use ExUnit.Case, async: false
  require Ash.Query
  alias NewYou.Communications.MessageIntent
  alias NewYou.{Communications, Identity}
  alias NewYou.Proof.P805

  test "dispatch disposition is the single locked AshStateMachine dimension" do
    assert AshStateMachine in Spark.extensions(MessageIntent)

    assert AshStateMachine.Info.state_machine_state_attribute!(MessageIntent) ==
             :dispatch_disposition

    assert AshStateMachine.Info.state_machine_initial_states!(MessageIntent) == [:open]

    assert Enum.sort(AshStateMachine.Info.state_machine_all_states(MessageIntent)) ==
             Enum.sort([:open, :held, :reconciliation_required, :closed])

    assert Ash.Resource.Info.action(MessageIntent, :disposition) == nil

    for resource <- [Communications.DeliveryAttempt] do
      refute AshStateMachine in Spark.extensions(resource)
    end

    assert AshStateMachine in Spark.extensions(Identity.Account)

    assert AshStateMachine.Info.state_machine_state_attribute!(Identity.Account) ==
             :primary_email_change_state
  end

  test "explicit actions govern open hold reconciliation and terminal closure" do
    P805.with_fixture(fn ->
      request = P805.request()
      {:ok, _} = Identity.register(request)
      [intent] = intents(request.operation_id)
      assert intent.dispatch_disposition == :open
      held = transition(intent, :hold)
      assert held.dispatch_disposition == :held
      reconciling = transition(held, :require_reconciliation)
      assert reconciling.dispatch_disposition == :reconciliation_required
      resumed = transition(reconciling, :resume)
      assert resumed.dispatch_disposition == :open
      closed = transition(resumed, :close)
      assert closed.dispatch_disposition == :closed

      for action <- [:hold, :resume, :require_reconciliation] do
        assert {:error, _} = Ash.update(closed, %{}, action: action, authorize?: false)
      end

      assert Ash.get!(MessageIntent, intent.id, authorize?: false).dispatch_disposition == :closed
    end)
  end

  test "atomic transition guards reject a stale open record after stored closure" do
    P805.with_fixture(fn ->
      request = P805.request()
      {:ok, _} = Identity.register(request)
      [stale] = intents(request.operation_id)
      closed = transition(stale, :close)

      for action <- [:hold, :resume, :require_reconciliation] do
        assert {:error, _} = Ash.update(stale, %{}, action: action, authorize?: false)
      end

      assert Ash.get!(MessageIntent, stale.id, authorize?: false).dispatch_disposition ==
               closed.dispatch_disposition
    end)
  end

  test "ordinary callers cannot transition and absent conflict evidence cannot reopen closure" do
    P805.with_fixture(fn ->
      request = P805.request()
      {:ok, _} = Identity.register(request)
      [intent] = intents(request.operation_id)
      assert {:error, _} = Ash.update(intent, %{}, action: :hold, authorize?: true)
      closed = transition(intent, :close)

      assert {:error, _} =
               Ash.update(closed, %{attempt_id: Ash.UUID.generate()},
                 action: :flag_evidence_conflict,
                 authorize?: false
               )

      assert Ash.get!(MessageIntent, intent.id, authorize?: false).dispatch_disposition == :closed
    end)
  end

  test "operation scoping ignores unrelated intents and exact cardinality catches extras" do
    P805.with_fixture(fn ->
      first_request = P805.request()
      second_request = P805.request()
      {:ok, _} = Identity.register(first_request)
      {:ok, _} = Identity.register(second_request)

      assert length(intents(first_request.operation_id)) == 1
      assert length(intents(second_request.operation_id)) == 1

      duplicate_reference =
        Ecto.UUID.generate() |> String.replace("-", "") |> String.slice(0, 24)

      NewYou.Repo.query!(
        """
        INSERT INTO message_intents (
          id, source_owner, source_operation_id, source_reference, role, source_purpose,
          destination, destination_provenance, destination_authorized_at, locale,
          content_item_id, content_version_id, translation_version_id, content_sha256,
          platform_name, render_schema, render_digest
        )
        SELECT gen_random_uuid(), source_owner, source_operation_id, $1, role, source_purpose,
               destination, destination_provenance, destination_authorized_at, locale,
               content_item_id, content_version_id, translation_version_id, content_sha256,
               platform_name, render_schema, render_digest
        FROM message_intents
        WHERE source_operation_id = $2
        """,
        [duplicate_reference, Ecto.UUID.dump!(first_request.operation_id)]
      )

      assert length(intents(first_request.operation_id)) == 2

      assert_raise MatchError, fn ->
        [intent] = intents(first_request.operation_id)
        intent
      end
    end)
  end

  defp intents(operation_id) do
    MessageIntent
    |> Ash.Query.filter(source_operation_id == ^operation_id)
    |> Ash.read!(domain: Communications, authorize?: false)
  end

  defp transition(intent, action), do: Ash.update!(intent, %{}, action: action, authorize?: false)
end
