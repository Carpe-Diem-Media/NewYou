defmodule NewYou.Proof.P815RestartRequest do
  @moduledoc false
  alias Ecto.Adapters.SQL.Sandbox
  alias NewYou.{Identity, Repo}
  alias NewYou.Proof.{RecoveryBudget, RecoveryLease, RecoveryLoad, RecoverySeam}

  def run(input) do
    # The connection logger includes raw client stacks. The Port protocol emits fixed categories.
    Logger.configure(level: :emergency)

    RecoverySeam.observe(fn stage ->
      Process.put(:p815_phases, [stage | Process.get(:p815_phases, [])])
      if stage == :transaction_entered, do: RecoveryLease.calibrate_at_entry()
    end)

    interrupt_once(input)
    attempts = if input["interrupt_request"] == true, do: 1, else: 3

    Enum.reduce_while(1..attempts, :request_uncommitted, fn attempt, _ ->
      request(input)
      flush_phases()
      state = current_state(input)

      cond do
        input["interrupt_request"] == true ->
          {:halt, :interruption_not_proven}

        Atom.to_string(state) == input["expected_state"] ->
          {:halt, requested_result(input, attempt)}

        true ->
          IO.puts("P815_REQUEST_UNCOMMITTED")
          {:cont, :request_uncommitted}
      end
    end)
  end

  def sample([first, second]) do
    Logger.configure(level: :emergency)
    RecoverySeam.observe(&NewYou.Proof.RecoveryBudget.observe_outcome/1)
    Enum.each([first, second], &request/1)
    :requested
  end

  # Each request carries an ordinal: cold 0, batch 1 to 8 and the authorized
  # follow-up 9. Batch lines print as tasks finish, and the parent joins them by
  # ordinal. Batch tasks set their own observer because seam state lives in each
  # process dictionary.
  def load(input) do
    Logger.configure(level: :emergency)
    RecoverySeam.observe(&RecoveryBudget.observe_outcome/1)
    if input["cold"], do: request(input["cold"])
    if input["hold"], do: RecoveryLoad.verify_target!(input["hold"])
    before = if input["after"], do: RecoveryLoad.snapshot(input["hold"])
    run_batch(input)
    if input["after"], do: follow_up(input, before)
    :requested
  end

  # The follow-up runs only after the batch is proven rolled back. The state line
  # prints either way, so a failed proof stays observable.
  defp follow_up(input, before) do
    if RecoveryLoad.after_batch(input["hold"], before), do: request(input["after"])
  end

  defp requested_result(%{"rollback_request_once" => true}, attempt) when attempt > 1,
    do: :request_retried

  defp requested_result(_input, _attempt), do: :requested

  defp run_batch(%{"batch" => batch, "concurrency" => concurrency} = input) do
    # Batch tasks check out their own connections. Releasing this process's
    # sandbox connection keeps the nine-connection batch inside pool size 10.
    Ecto.Adapters.SQL.Sandbox.checkin(NewYou.Repo)

    case input["hold"] do
      nil -> unheld_batch(batch, concurrency)
      hold -> held_batch(batch, concurrency, hold)
    end
  end

  # Without a holder, times are relative to the batch start.
  defp unheld_batch(batch, concurrency) do
    origin = System.monotonic_time(:microsecond)
    RecoveryLoad.print_tasks(batch_tasks(batch, concurrency), origin)
  end

  # The batch starts while the holder owns the Account row. The lock is released
  # after hold_ms, and results are read after release. Times are relative to
  # lock acquisition.
  defp held_batch(batch, concurrency, %{"case_id" => case_id, "hold_ms" => hold_ms}) do
    {task, %{acquired: acquired, released: released}} =
      RecoveryBudget.with_account_lock(case_id, fn ->
        task = Task.async(fn -> batch_tasks(batch, concurrency) end)
        Process.sleep(hold_ms)
        task
      end)

    RecoveryLoad.print_hold(acquired, released)
    RecoveryLoad.print_tasks(Task.await(task, 10_000), acquired)
  end

  defp batch_tasks(batch, concurrency) do
    results =
      batch
      |> Task.async_stream(&batch_request/1,
        max_concurrency: concurrency,
        ordered: true,
        timeout: 10_000,
        on_timeout: :kill_task
      )
      |> Enum.to_list()

    RecoveryLoad.outcomes(batch, results)
  end

  # Each batch task reports one fixed status. Exception and exit reasons stay in
  # the child, so only the category leaves the process.
  defp batch_request(input) do
    RecoverySeam.observe(&RecoveryLoad.observe_task/1)

    try do
      request(input)
      {:completed, RecoveryLoad.task_times()}
    rescue
      _ -> :raised
    catch
      :exit, _ -> :exited
    end
  end

  defp request(input) do
    {:ok, failures} =
      RecoverySeam.capture_database_failures(fn ->
        Sandbox.unboxed_run(Repo, fn -> request_on_checkout(input) end)
      end)

    Enum.each(failures, fn category ->
      IO.puts("P815_DB_" <> (category |> Atom.to_string() |> String.upcase()))
    end)
  end

  defp request_on_checkout(input) do
    callback = fn -> measured_request(input) end

    if input["budget"] == true or Map.has_key?(input, "lease_probe") or RecoveryLease.hosted?() do
      RecoveryLease.observe(input, callback)
    else
      callback.()
    end
  end

  defp measured_request(input) do
    call = fn ->
      Identity.request_recovery(input["email"], input["locale"], input["operation_id"])
    end

    case input do
      %{"budget" => true, "hold_lock" => true} ->
        {result, _times} =
          RecoveryBudget.with_account_lock(input["case_id"], fn ->
            RecoveryBudget.measure(input["ordinal"], call)
          end)

        result

      %{"budget" => true} ->
        RecoveryBudget.measure(input["ordinal"], call)

      _ ->
        call.()
    end
  end

  defp current_state(input) do
    Sandbox.unboxed_run(Repo, fn ->
      Ash.get!(Identity.RecoveryCase, input["case_id"], authorize?: false).state
    end)
  end

  defp flush_phases do
    for stage <- Enum.reverse(Process.delete(:p815_phases) || []) do
      IO.puts("P815_PHASE_" <> (stage |> Atom.to_string() |> String.upcase()))
    end
  end

  defp interrupt_once(%{"interrupt_request" => true, "skip_interrupt" => false}) do
    Process.put(
      NewYou.Proof.RegistrationSeam,
      {:observe,
       fn ->
         Process.delete(NewYou.Proof.RegistrationSeam)
         flush_phases()
         IO.puts("P815_CHECKPOINT")
         IO.puts("P815_INTERRUPT_READY")

         # The parent cuts this registered child only after receiving both
         # complete markers. Its existing deadline bounds a missing handshake.
         receive do
           :release_checkpoint -> :ok
         end
       end}
    )
  end

  defp interrupt_once(%{"rollback_request_once" => true}) do
    Process.put(
      NewYou.Proof.RegistrationSeam,
      {:observe,
       fn ->
         Process.delete(NewYou.Proof.RegistrationSeam)
         IO.puts("P815_ROLLBACK_CHECKPOINT")
         raise "TEST-only recovery resume transaction rollback"
       end}
    )
  end

  defp interrupt_once(_), do: :ok
end

IO.puts("P815_STARTED")
input = IO.gets("") |> Jason.decode!()
secret = Base.decode64!(input["signing_secret"])
Application.put_env(:new_you, :identity_token_signing_secret, secret)

context =
  if input["context"] == "well183" do
    Application.put_env(:new_you, :fp001_development_entry, true)
    :well183
  else
    :p8_15
  end

Ecto.Adapters.SQL.Sandbox.unboxed_run(NewYou.Repo, fn ->
  try do
    IO.puts("P815_OPERATION")

    result =
      case input["mode"] do
        "sample_budget" ->
          NewYou.Proof.P815RestartRequest.sample(input["samples"])

        "sample_load" ->
          NewYou.Proof.P815RestartRequest.load(input)

        "request" ->
          NewYou.Proof.P815RestartRequest.run(input)

        "deliver" ->
          NewYou.Identity.Account
          |> Ash.transact(fn ->
            NewYou.Identity.recovery_delivery(input["jti"], input["destination"], input["locale"])
          end)
          |> case do
            {:ok, {:ok, bearer}} ->
              if :crypto.hash(:sha256, bearer) |> Base.encode16(case: :upper) ==
                   input["expected_digest"],
                 do: :delivery_matches,
                 else: :delivery_mismatch

            _ ->
              :delivery_denied
          end

        "submit" ->
          case NewYou.Identity.submit_recovery_proof(
                 input["proof"],
                 input["operation_id"],
                 "af",
                 context
               ) do
            {:ok, :accepted} -> :accepted
            _ -> :submission_denied
          end

        "complete" ->
          case NewYou.Identity.complete_recovery(
                 input["proof"],
                 input["password"],
                 input["operation_id"],
                 "af",
                 context
               ) do
            {:ok, :completed} -> :completed
            _ -> :completion_denied
          end

        "replay" ->
          case NewYou.Identity.complete_recovery(
                 input["proof"],
                 input["password"],
                 input["operation_id"],
                 "af",
                 context
               ) do
            {:ok, :already_completed} -> :already_completed
            _ -> :replay_denied
          end

        _ ->
          :denied
      end

    IO.puts("P815_" <> (Atom.to_string(result) |> String.upcase()))
  rescue
    error ->
      # Never print exception details containing the stdin bearer or Account.
      IO.puts(:stderr, "P815_FAILURE_CLASS_" <> inspect(error.__struct__))
      IO.puts("P815_DENIED")
  end
end)
