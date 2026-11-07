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
          NewYou.Identity.magic_login_delivery(
            input["jti"],
            input["destination"],
            input["locale"]
          )
        end)
        |> case do
          {:ok, {:ok, bearer}} ->
            digest = :crypto.hash(:sha256, bearer) |> Base.encode16(case: :upper)

            if digest == input["expected_digest"],
              do: :delivery_matches,
              else: :delivery_mismatch

          _ ->
            :delivery_denied
        end

      "consume" ->
        case NewYou.Identity.authenticate_magic_link(input["proof"]) do
          {:ok, %{session_id: session_id, token: token}}
          when is_binary(session_id) and is_binary(token) ->
            :consumed

          _ ->
            :denied
        end

      _ ->
        :denied
    end

  case result do
    :delivery_matches -> IO.puts("P809_MAGIC_DELIVERY_MATCH")
    :delivery_mismatch -> IO.puts("P809_MAGIC_DELIVERY_MISMATCH")
    :delivery_denied -> IO.puts("P809_MAGIC_DELIVERY_DENIED")
    :consumed -> IO.puts("P809_MAGIC_CONSUMED")
    :denied -> IO.puts("P809_MAGIC_DENIED")
  end
after
  :ok = Ecto.Adapters.SQL.Sandbox.checkin(NewYou.Repo)
end
