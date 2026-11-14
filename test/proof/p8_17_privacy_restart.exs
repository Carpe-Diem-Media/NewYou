# Synthetic P8-17 restart probe. Credentials arrive only through the anonymous
# pipe and the proof-purpose switch exists only in this fresh test VM.
input = IO.gets("") |> Jason.decode!()

Application.put_env(
  :new_you,
  :identity_token_signing_secret,
  Base.decode64!(input["signing_secret"])
)

Application.put_env(:new_you, :p8_17_test_proof_purpose?, true)

Application.put_env(:new_you, :p8_16_primary_email_change_policy, %{
  delay_seconds: 0,
  requires_review?: false
})

:ok = Ecto.Adapters.SQL.Sandbox.checkout(NewYou.Repo, sandbox: false)

result =
  try do
    NewYou.Identity.apply_primary_email_change(input["operation_id"])
  after
    :ok = Ecto.Adapters.SQL.Sandbox.checkin(NewYou.Repo)
  end

case result do
  {:error, :primary_email_change_unavailable} ->
    IO.puts("P817_RESTART_DENIED")

  _ ->
    raise "P8-17 restarted retry did not fail closed"
end
