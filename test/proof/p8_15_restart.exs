defmodule NewYou.Proof.P815RestartRequest do
  @moduledoc false
  alias Ecto.Adapters.SQL.Sandbox
  alias NewYou.{Identity, Repo}
  alias NewYou.Proof.{RecoveryLease, RecoverySeam}

  def run(input) do
    # The connection logger includes raw client stacks. The Port protocol emits fixed categories.
    Logger.configure(level: :emergency)

    RecoverySeam.observe(fn stage ->
      Process.put(:p815_phases, [stage | Process.get(:p815_phases, [])])
      if stage == :await_proof, do: RecoveryLease.stage(stage)
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

  defp requested_result(%{"rollback_request_once" => true}, attempt) when attempt > 1,
    do: :request_retried

  defp requested_result(_input, _attempt), do: :requested

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
    callback = fn ->
      Identity.request_recovery(input["email"], input["locale"], input["operation_id"])
    end

    if Map.has_key?(input, "lease_probe") or RecoveryLease.hosted?() do
      RecoveryLease.observe(input, callback)
    else
      callback.()
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

Ecto.Adapters.SQL.Sandbox.unboxed_run(NewYou.Repo, fn ->
  try do
    IO.puts("P815_OPERATION")

    result =
      case input["mode"] do
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
          case NewYou.Identity.submit_recovery_proof(input["proof"], input["operation_id"]) do
            {:ok, :accepted} -> :accepted
            _ -> :submission_denied
          end

        "complete" ->
          case NewYou.Identity.complete_recovery(
                 input["proof"],
                 input["password"],
                 input["operation_id"]
               ) do
            {:ok, :completed} -> :completed
            _ -> :completion_denied
          end

        "replay" ->
          case NewYou.Identity.complete_recovery(
                 input["proof"],
                 input["password"],
                 input["operation_id"]
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
