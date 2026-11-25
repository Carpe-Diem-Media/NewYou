defmodule NewYou.Proof.RecoveryLoadTest do
  use ExUnit.Case, async: true
  alias NewYou.Proof.{RecoveryBudget, RecoveryLoad}

  test "batch task observations keep admission and lock grant apart and clear after reading" do
    assert :ok == RecoveryLoad.observe_task(:transaction_entered)
    assert :ok == RecoveryLoad.observe_task(:account_locked)

    assert %{admitted: admitted, granted: granted} = RecoveryLoad.task_times()
    assert is_integer(admitted) and is_integer(granted)
    assert granted >= admitted
    assert RecoveryLoad.task_times() == %{admitted: nil, granted: nil}
  end

  test "other stages go to the budget observer and not to task times" do
    assert :ok == RecoveryLoad.observe_task(:transaction_returned)
    assert Process.get({RecoveryBudget, :outcome}) == :transaction_returned
    assert RecoveryLoad.task_times() == %{admitted: nil, granted: nil}

    Process.delete({RecoveryBudget, :outcome})
  end

  test "every batch input maps to one fixed status and no exit reason leaks" do
    inputs = for ordinal <- 1..5, do: %{"ordinal" => ordinal}

    results = [
      {:ok, {:completed, %{admitted: 10, granted: 20}}},
      {:ok, :raised},
      {:exit, :timeout},
      {:exit, {:boom, "secret"}}
    ]

    outcomes = RecoveryLoad.outcomes(inputs, results)

    assert outcomes == [
             %{ordinal: 1, status: :completed, admitted: 10, granted: 20},
             %{ordinal: 2, status: :raised, admitted: nil, granted: nil},
             %{ordinal: 3, status: :timeout, admitted: nil, granted: nil},
             %{ordinal: 4, status: :exit, admitted: nil, granted: nil},
             %{ordinal: 5, status: :incomplete, admitted: nil, granted: nil}
           ]

    refute inspect(outcomes) =~ "secret"
  end

  test "exited and killed tasks report the exit status" do
    inputs = [%{"ordinal" => 1}, %{"ordinal" => 2}]

    assert [%{status: :exit}, %{status: :exit}] =
             RecoveryLoad.outcomes(inputs, [{:ok, :exited}, {:exit, :killed}])
  end

  test "task lines round-trip relative to the origin" do
    outcomes = [
      %{ordinal: 1, status: :completed, admitted: 150, granted: 200},
      %{ordinal: 2, status: :timeout, admitted: 120, granted: nil}
    ]

    output = ExUnit.CaptureIO.capture_io(fn -> RecoveryLoad.print_tasks(outcomes, 100) end)

    assert parse_lines(output) == [
             %{kind: :task, ordinal: 1, status: :completed, admitted_us: 50, granted_us: 100},
             %{kind: :task, ordinal: 2, status: :timeout, admitted_us: 20, granted_us: -1}
           ]
  end

  test "hold release is printed relative to lock acquisition" do
    output = ExUnit.CaptureIO.capture_io(fn -> RecoveryLoad.print_hold(100, 250) end)

    assert parse_lines(output) == [%{kind: :hold, released_us: 150}]
  end

  test "state lines accept only fixed categories and bounded counts" do
    assert RecoveryLoad.parse("P815_STATE after_batch settled unchanged 0 0") == [
             %{kind: :state, settled: :settled, durable: :unchanged, tokens: 0, intents: 0}
           ]

    assert RecoveryLoad.parse("P815_STATE after_batch unsettled unknown -1 -1") == [
             %{kind: :state, settled: :unsettled, durable: :unknown, tokens: -1, intents: -1}
           ]

    assert RecoveryLoad.parse("P815_STATE after_batch settled exploded 0 0") == []
    assert RecoveryLoad.parse("P815_STATE after_batch settled unchanged 10000000 0") == []
  end

  test "task lines reject unknown statuses, bad ordinals and wrong field counts" do
    assert [%{kind: :task, ordinal: 1, status: :completed}] =
             RecoveryLoad.parse("P815_TASK 1 completed 10 20")

    assert RecoveryLoad.parse("P815_TASK 10 completed 10 20") == []
    assert RecoveryLoad.parse("P815_TASK 1 secret 10 20") == []
    assert RecoveryLoad.parse("P815_TASK 1 completed 10") == []
    assert RecoveryLoad.parse("P815_TASK 1 completed 10 20 30") == []
    assert RecoveryLoad.parse("P815_TASK 1 completed x 20") == []
    assert RecoveryLoad.parse("P815_TASK 1 completed 10 10000000") == []
  end

  test "hold lines reject out-of-range durations and unrelated text" do
    assert RecoveryLoad.parse("P815_HOLD 10000000") == []
    assert RecoveryLoad.parse("private data") == []
  end

  test "record joins each timed request with its budget, lease and task by ordinal" do
    diagnostic = %{
      status: :ok,
      marker: :requested,
      cleanup: :confirmed,
      budget_reports: [%{ordinal: 0, public: 500_000}, %{ordinal: 1, public: 501_000}],
      lease_reports: [%{ordinal: 1, closure: :none}, %{ordinal: 0, closure: :none}],
      load_reports: [
        %{kind: :hold, released_us: 150},
        %{kind: :task, ordinal: 1, status: :completed, admitted_us: 10, granted_us: 160}
      ]
    }

    record = RecoveryLoad.record(:released, 8, 1, diagnostic)

    assert record.status == :ok
    assert record.hold == %{kind: :hold, released_us: 150}
    assert record.state == nil

    assert [
             %{ordinal: 0, lease: %{ordinal: 0}, task: nil},
             %{ordinal: 1, lease: %{ordinal: 1}, task: %{status: :completed}}
           ] = record.requests
  end

  defp parse_lines(output) do
    output
    |> String.split("\n", trim: true)
    |> Enum.flat_map(&RecoveryLoad.parse/1)
  end
end
