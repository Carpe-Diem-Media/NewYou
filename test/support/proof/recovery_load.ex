defmodule NewYou.Proof.RecoveryLoad do
  @moduledoc false
  # WELL-167 load observations. Lines carry an ordinal, a fixed category or an
  # integer duration in microseconds on the system monotonic clock. They never
  # carry identifiers, tokens, PIDs, exception reasons or request data.

  alias Ecto.Adapters.SQL.Sandbox
  alias NewYou.Identity.{Account, RecoveryCase}
  alias NewYou.Proof.{RecoveryBudget, RecoveryLease}
  alias NewYou.Repo

  @statuses ~w(completed raised timeout exit incomplete)a
  @settled ~w(settled unsettled)a
  @durable ~w(unchanged changed unknown)a
  @maximum 9_999_999

  # Batch tasks record admission and lock grant. Other stages go to the budget
  # observer, which keeps only the terminal transaction outcome.
  def observe_task(stage) when stage in [:transaction_entered, :account_locked] do
    Process.put({__MODULE__, stage}, System.monotonic_time(:microsecond))
    :ok
  end

  def observe_task(stage), do: RecoveryBudget.observe_outcome(stage)

  def task_times do
    %{
      admitted: Process.delete({__MODULE__, :transaction_entered}),
      granted: Process.delete({__MODULE__, :account_locked})
    }
  end

  # An ordered stream yields one element per batch input. A shorter stream leaves
  # the remaining requests incomplete rather than dropping them silently.
  def outcomes(inputs, results) do
    missing = List.duplicate(:missing, max(length(inputs) - length(results), 0))

    Enum.zip_with(inputs, results ++ missing, fn input, result ->
      {status, admitted, granted} = status(result)
      %{ordinal: input["ordinal"], status: status, admitted: admitted, granted: granted}
    end)
  end

  defp status({:ok, {:completed, %{admitted: admitted, granted: granted}}}),
    do: {:completed, admitted, granted}

  defp status({:ok, :raised}), do: {:raised, nil, nil}
  defp status({:ok, :exited}), do: {:exit, nil, nil}
  defp status({:exit, :timeout}), do: {:timeout, nil, nil}
  defp status({:exit, _reason}), do: {:exit, nil, nil}
  defp status(:missing), do: {:incomplete, nil, nil}

  # Times are relative to the origin: lock acquisition for held batches, otherwise
  # the batch start. -1 marks an event that did not occur.
  def print_tasks(outcomes, origin) do
    Enum.each(outcomes, fn outcome ->
      admitted = relative(outcome.admitted, origin)
      granted = relative(outcome.granted, origin)
      IO.puts("P815_TASK #{outcome.ordinal} #{outcome.status} #{admitted} #{granted}")
    end)
  end

  def print_hold(acquired, released), do: IO.puts("P815_HOLD #{relative(released, acquired)}")

  defp relative(nil, _origin), do: -1
  defp relative(time, origin), do: min(time - origin, @maximum)

  # Verifies the contention case and operation before the child takes the Account
  # lock. The parent created both, and the disposable database check is unchanged.
  def verify_target!(%{"case_id" => case_id, "operation_id" => operation_id}) do
    Sandbox.unboxed_run(Repo, fn -> RecoveryLease.verify_fixture!(case_id, operation_id) end)
  end

  # Durable effects of the contention case, read on a fresh checkout. Token counts
  # are scoped to the case and message intents to its operation.
  def snapshot(%{
        "account_id" => account_id,
        "case_id" => case_id,
        "operation_id" => operation_id
      }) do
    Sandbox.unboxed_run(Repo, fn ->
      %{
        account: Ash.get!(Account, account_id, authorize?: false),
        recovery_case: Ash.get!(RecoveryCase, case_id, authorize?: false),
        tokens: count("SELECT count(*) FROM tokens WHERE recovery_case_id=$1", case_id),
        intents:
          count(
            "SELECT count(*) FROM message_intents WHERE source_operation_id=$1 AND role='account_recovery'",
            operation_id
          )
      }
    end)
  end

  defp count(sql, id) do
    %{rows: [[total]]} = Repo.query!(sql, [Ecto.UUID.dump!(id)], log: false)
    total
  end

  # Acquiring the Account row lock within lock_timeout proves that no batch
  # transaction still holds it. The durable comparison prints either way.
  def after_batch(hold, before) do
    settled = settle(hold)
    {durable, tokens, intents} = compare(hold, before)
    IO.puts("P815_STATE after_batch #{settled} #{durable} #{tokens} #{intents}")
    settled == :settled and durable == :unchanged and tokens == 0 and intents == 0
  end

  defp settle(%{"case_id" => case_id}) do
    Sandbox.unboxed_run(Repo, fn ->
      Repo.transaction(fn ->
        Repo.query!("SET LOCAL lock_timeout = '3s'", [], log: false)

        Repo.query!(
          "SELECT a.id FROM accounts a JOIN recovery_cases c ON c.account_id = a.id WHERE c.id = $1 FOR UPDATE OF a",
          [Ecto.UUID.dump!(case_id)],
          log: false
        )
      end)
    end)

    :settled
  rescue
    _ -> :unsettled
  end

  defp compare(hold, before) do
    later = snapshot(hold)
    same? = {later.account, later.recovery_case} == {before.account, before.recovery_case}
    {if(same?, do: :unchanged, else: :changed), later.tokens, later.intents}
  rescue
    _ -> {:unknown, -1, -1}
  end

  # One record per child, printed before any acceptance assertion. Each timed
  # request joins its budget report with its lease and task reports by ordinal.
  def record(scenario, concurrency, replicate, diagnostic) do
    tasks = Enum.filter(diagnostic.load_reports, &(&1.kind == :task))

    %{
      scenario: scenario,
      concurrency: concurrency,
      replicate: replicate,
      status: status_name(diagnostic.status),
      marker: diagnostic.marker,
      cleanup: diagnostic.cleanup,
      hold: Enum.find(diagnostic.load_reports, &(&1.kind == :hold)),
      state: Enum.find(diagnostic.load_reports, &(&1.kind == :state)),
      requests:
        Enum.map(diagnostic.budget_reports, fn budget ->
          %{
            ordinal: budget.ordinal,
            budget: budget,
            lease: Enum.find(diagnostic.lease_reports, &(&1.ordinal == budget.ordinal)),
            task: Enum.find(tasks, &(&1.ordinal == budget.ordinal))
          }
        end)
    }
  end

  defp status_name(status) when is_atom(status), do: status
  defp status_name(_status), do: :exit

  def parse("P815_TASK " <> payload) do
    with [ordinal, status_text, admitted, granted] <- String.split(payload, " "),
         true <- ordinal?(ordinal),
         status when not is_nil(status) <- allowed(status_text, @statuses),
         [admitted_us, granted_us] <- durations([admitted, granted]) do
      [
        %{
          kind: :task,
          ordinal: String.to_integer(ordinal),
          status: status,
          admitted_us: admitted_us,
          granted_us: granted_us
        }
      ]
    else
      _ -> []
    end
  end

  def parse("P815_HOLD " <> payload) do
    case durations([payload]) do
      [released_us] -> [%{kind: :hold, released_us: released_us}]
      _ -> []
    end
  end

  def parse("P815_STATE after_batch " <> payload) do
    with [settled_text, durable_text, tokens, intents] <- String.split(payload, " "),
         settled when not is_nil(settled) <- allowed(settled_text, @settled),
         durable when not is_nil(durable) <- allowed(durable_text, @durable),
         [tokens_count, intents_count] <- durations([tokens, intents]) do
      [
        %{
          kind: :state,
          settled: settled,
          durable: durable,
          tokens: tokens_count,
          intents: intents_count
        }
      ]
    else
      _ -> []
    end
  end

  def parse(_), do: []

  # Non-negative durations up to the cap, plus -1 for an unknown measurement.
  defp durations(values) do
    for value <- values,
        {number, ""} <- [Integer.parse(value)],
        number == -1 or number in 0..@maximum,
        do: number
  end

  defp ordinal?(value), do: Regex.match?(~r/\A[0-9]\z/, value)
  defp allowed(value, atoms), do: Enum.find(atoms, &(Atom.to_string(&1) == value))
end
