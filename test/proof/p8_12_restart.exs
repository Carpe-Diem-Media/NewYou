input = IO.gets("") |> Jason.decode!()
secret = Base.decode64!(input["signing_secret"])
Application.put_env(:new_you, :identity_token_signing_secret, secret)
:ok = Ecto.Adapters.SQL.Sandbox.checkout(NewYou.Repo, sandbox: false)

try do
  result =
    case input["mode"] do
      "deliver" ->
        NewYou.Identity.Account
        |> Ash.transact(fn ->
          NewYou.Identity.password_reset_delivery(
            input["jti"],
            input["destination"],
            input["locale"]
          )
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

      "consume" ->
        NewYou.Identity.reset_password(input["proof"], input["password"], input["operation_id"])
        |> case do
          {:ok, :reset} -> :reset
          {:ok, :already_reset} -> :already_reset
          _ -> :reset_denied
        end

      "replay" ->
        NewYou.Identity.reset_password(input["proof"], input["password"], input["operation_id"])
        |> case do
          {:ok, :already_reset} -> :already_reset
          _ -> :replay_denied
        end

      _ ->
        :denied
    end

  IO.puts("P812_" <> (result |> Atom.to_string() |> String.upcase()))
after
  :ok = Ecto.Adapters.SQL.Sandbox.checkin(NewYou.Repo)
end
