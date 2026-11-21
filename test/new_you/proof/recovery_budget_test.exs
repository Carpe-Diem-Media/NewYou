defmodule NewYou.Proof.RecoveryBudgetTest do
  use ExUnit.Case, async: true
  alias NewYou.Proof.RecoveryBudget

  test "phase durations partition the call and absent stages remain distinguishable" do
    line =
      ExUnit.CaptureIO.capture_io(fn ->
        assert :ok == RecoveryBudget.measure(fn -> RecoveryBudget.stage(:padding) end)
      end)
      |> String.trim()

    assert [timing] = RecoveryBudget.parse(line)
    assert timing.prepare + timing.padding == timing.public
    assert timing.account == -1
    assert RecoveryBudget.parse(line <> " private") == []

    assert RecoveryBudget.parse(String.replace_prefix(line, "P815_BUDGET ", "P815_BUDGET -3")) ==
             []

    assert Process.get(RecoveryBudget) == nil
  end

  test "exception clears the process-local measurement" do
    assert_raise RuntimeError, "fixture", fn ->
      RecoveryBudget.measure(fn -> raise "fixture" end)
    end

    assert Process.get(RecoveryBudget) == nil
  end
end
