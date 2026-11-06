input = IO.gets("") |> Jason.decode!()
secret = Base.decode64!(input["signing_secret"])
Application.put_env(:new_you, :identity_token_signing_secret, secret)
:ok = Ecto.Adapters.SQL.Sandbox.checkout(NewYou.Repo, sandbox: false)

try do
  credentials = %{session_id: input["session_id"], token: input["token"]}
  result = NewYou.Identity.authorize_session(credentials)
  IO.puts(if match?({:ok, _}, result), do: "P809_RESTART_ALLOWED", else: "P809_RESTART_DENIED")
after
  Ecto.Adapters.SQL.Sandbox.checkin(NewYou.Repo)
end
