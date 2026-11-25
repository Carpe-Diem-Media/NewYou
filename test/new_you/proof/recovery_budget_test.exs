defmodule NewYou.Proof.RecoveryBudgetTest do
  use ExUnit.Case, async: true
  alias NewYou.Proof.RecoveryBudget

  test "phase durations partition the call and absent stages remain distinguishable" do
    line =
      ExUnit.CaptureIO.capture_io(fn ->
        assert :ok == RecoveryBudget.measure(0, fn -> RecoveryBudget.stage(:padding) end)
      end)
      |> String.trim()

    assert [timing] = RecoveryBudget.parse(line)
    assert timing.ordinal == 0
    assert timing.prepare + timing.padding == timing.public
    assert timing.account == -1
    assert RecoveryBudget.parse(line <> " private") == []

    # The ordinal must be a single digit from 0 to 9, so both values below are rejected.
    assert RecoveryBudget.parse(String.replace(line, " 0 ", " -3 ", global: false)) == []
    assert RecoveryBudget.parse(String.replace(line, " 0 ", " 10 ", global: false)) == []

    assert Process.get(RecoveryBudget) == nil
  end

  test "only successful query events from the owner inside the Account stage accumulate" do
    measurements = %{
      query_time: System.convert_time_unit(125, :microsecond, :native),
      total_time: System.convert_time_unit(200, :microsecond, :native)
    }

    event = fn data, owner ->
      NewYou.Proof.RecoverySeam.record_database_failure(
        [],
        data,
        %{result: {:ok, :private}},
        {owner, make_ref()}
      )
    end

    line =
      ExUnit.CaptureIO.capture_io(fn ->
        RecoveryBudget.measure(0, fn ->
          event.(measurements, self())
          RecoveryBudget.stage(:account)
          event.(measurements, :unrelated)
          event.(measurements, self())
          event.(Map.delete(measurements, :query_time), self())
          RecoveryBudget.stage(:case_lookup)
          event.(measurements, self())
        end)
      end)

    assert [report] = RecoveryBudget.parse(String.trim(line))
    assert report.account_success_count == 2
    assert report.account_adapter_total == 400
    assert report.account_query == -1
  end

  test "two calls in one child retain their own terminal outcomes and ordinals" do
    lines =
      ExUnit.CaptureIO.capture_io(fn ->
        RecoveryBudget.measure(1, fn -> RecoveryBudget.observe_outcome(:transaction_returned) end)
        RecoveryBudget.measure(2, fn -> RecoveryBudget.observe_outcome(:transaction_error) end)
        RecoveryBudget.measure(3, fn -> :ok end)
      end)

    reports =
      for line <- String.split(lines, "\n"),
          report <- RecoveryBudget.parse(line),
          do: {report.ordinal, report.transaction}

    assert reports == [
             {1, :transaction_returned},
             {2, :transaction_error},
             {3, :unobserved}
           ]
  end

  test "previously issued durable effects only count as replay with a successful measured transaction" do
    healthy = %{closure: :none, error: :none}
    assert RecoveryBudget.replay_effect(:transaction_returned, healthy) == :replayed
    assert RecoveryBudget.replay_effect(:transaction_error, healthy) == :failed_replay
    assert RecoveryBudget.replay_effect(:unobserved, healthy) == :unconfirmed_replay

    assert RecoveryBudget.replay_effect(:transaction_returned, %{
             closure: :checkout_deadline,
             error: :lease_lost
           }) == :unconfirmed_replay
  end

  test "exception clears the process-local measurement" do
    assert_raise RuntimeError, "fixture", fn ->
      RecoveryBudget.measure(0, fn -> raise "fixture" end)
    end

    assert Process.get(RecoveryBudget) == nil
  end
end
