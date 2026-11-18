defmodule NewYou.Proof.DevelopmentEntryRecoveryTest do
  use ExUnit.Case, async: false
  alias NewYou.Proof.{P805, Scenario}

  for initial <- [:absent, false, nil], completion <- [:normal, :killed] do
    @initial initial
    @completion completion
    test "ordinary development entry restores #{inspect(initial)} after #{completion} owner" do
      previous = Application.fetch_env(:new_you, :fp001_development_entry)
      on_exit(fn -> restore(previous) end)
      expected = initial_state(@initial)
      restore(expected)
      parent = self()
      scenario = Scenario.start()
      completion = @completion

      {owner, monitor} =
        Scenario.spawn(scenario, :ordinary_entry_owner, fn ->
          P805.with_fixture(fn ->
            Application.put_env(:new_you, :fp001_development_entry, true)
            send(parent, {:entry_enabled, self()})
            receive do: (:finish -> :ok)
          end)
        end)

      try do
        assert_receive {:entry_enabled, ^owner}, 5_000
        assert Application.fetch_env(:new_you, :fp001_development_entry) == {:ok, true}
        finish_owner(owner, completion)
        assert_receive {:DOWN, ^monitor, :process, ^owner, _}, 5_000
        # Our monitor cannot settle the controller's independent death ledger.
        assert :ok = Scenario.request(scenario, {:await_owned_down, [owner], 5_000})
        result = Scenario.stop(scenario)

        assert result == expected_result(completion)

        assert Application.fetch_env(:new_you, :fp001_development_entry) == expected
      after
        if Process.alive?(owner), do: Process.exit(owner, :kill)
        if Process.alive?(scenario.controller), do: Scenario.stop(scenario)
      end
    end
  end

  defp initial_state(:absent), do: :error
  defp initial_state(value), do: {:ok, value}
  defp finish_owner(owner, :killed), do: Process.exit(owner, :kill)
  defp finish_owner(owner, :normal), do: send(owner, :finish)
  defp expected_result(:killed), do: {:error, [:worker_failed]}
  defp expected_result(:normal), do: :ok

  defp restore({:ok, value}), do: Application.put_env(:new_you, :fp001_development_entry, value)
  defp restore(:error), do: Application.delete_env(:new_you, :fp001_development_entry)
end
