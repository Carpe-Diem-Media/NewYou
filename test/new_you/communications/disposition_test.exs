defmodule NewYou.Communications.DispositionTest do
  use ExUnit.Case, async: false
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

    for resource <- [Communications.DeliveryAttempt, Identity.Account] do
      refute AshStateMachine in Spark.extensions(resource)
    end
  end

  test "explicit actions govern open hold reconciliation and terminal closure" do
    P805.with_fixture(fn ->
      {:ok, _} = Identity.register(P805.request())
      [intent] = Ash.read!(MessageIntent, authorize?: false)
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
      {:ok, _} = Identity.register(P805.request())
      [stale] = Ash.read!(MessageIntent, authorize?: false)
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
      {:ok, _} = Identity.register(P805.request())
      [intent] = Ash.read!(MessageIntent, authorize?: false)
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

  defp transition(intent, action), do: Ash.update!(intent, %{}, action: action, authorize?: false)
end
