defmodule NewYou.Proof.P815RestartRequest do
  @moduledoc false
  alias Ecto.Adapters.SQL.Sandbox
  alias NewYou.{Identity, Repo}

  def run(input) do
    interrupt_once(input)

    Enum.reduce_while(1..3, :request_uncommitted, fn attempt, _ ->
      # A neutral request may time out and disconnect its lease. Reacquire before
      # observing durable state; acknowledgement alone never proves a commit.
      request(input)
      state = current_state(input)

      if Atom.to_string(state) == input["expected_state"] do
        {:halt, requested_result(input, attempt)}
      else
        {:cont, :request_uncommitted}
      end
    end)
  end

  defp request(input) do
    Sandbox.unboxed_run(Repo, fn ->
      :ok = Identity.request_recovery(input["email"], input["locale"], input["operation_id"])
    end)
  end

  defp current_state(input) do
    Sandbox.unboxed_run(Repo, fn ->
      Ash.get!(Identity.RecoveryCase, input["case_id"], authorize?: false).state
    end)
  end

  defp requested_result(%{"interrupt_request" => true}, attempt) when attempt > 1,
    do: :request_retried

  defp requested_result(_input, _attempt), do: :requested

  defp interrupt_once(%{"interrupt_request" => true}) do
    Process.put(
      NewYou.Proof.RegistrationSeam,
      {:observe,
       fn ->
         Process.delete(NewYou.Proof.RegistrationSeam)
         Process.sleep(400)
       end}
    )
  end

  defp interrupt_once(_), do: :ok
end

input = IO.gets("") |> Jason.decode!()
secret = Base.decode64!(input["signing_secret"])
Application.put_env(:new_you, :identity_token_signing_secret, secret)

Ecto.Adapters.SQL.Sandbox.unboxed_run(NewYou.Repo, fn ->
  try do
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
