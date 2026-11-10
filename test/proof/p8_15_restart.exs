input = IO.gets("") |> Jason.decode!()
secret = Base.decode64!(input["signing_secret"])
Application.put_env(:new_you, :identity_token_signing_secret, secret)
:ok = Ecto.Adapters.SQL.Sandbox.checkout(NewYou.Repo, sandbox: false)

try do
  result =
    case input["mode"] do
      "request" ->
        :ok =
          NewYou.Identity.request_recovery(input["email"], input["locale"], input["operation_id"])

        :requested

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
  _ ->
    IO.puts("P815_DENIED")
after
  :ok = Ecto.Adapters.SQL.Sandbox.checkin(NewYou.Repo)
end
