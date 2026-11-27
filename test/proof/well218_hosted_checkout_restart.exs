alias Ecto.Adapters.SQL.Sandbox
alias NewYou.Commerce.{HostedCheckout, OfferAdmission}
alias NewYou.Repo

input = IO.gets("") |> Jason.decode!()
:ok = Sandbox.checkout(Repo, sandbox: false)

try do
  Application.put_env(
    :new_you,
    :identity_token_signing_secret,
    Base.decode64!(input["signing_key"])
  )

  scope = %{provider: :paystack, integration: :local_fixture, environment: :test, channel: :card}

  credentials = %{
    session_id: input["credentials"]["session_id"],
    token: input["credentials"]["token"]
  }

  {:ok, accepted} = OfferAdmission.snapshot(credentials, input["purchase_id"])
  {:ok, recovered} = HostedCheckout.recover(credentials, accepted, scope)

  true =
    recovered.attempt_id == input["attempt_id"] and
      recovered.reference == input["reference"] and
      Atom.to_string(recovered.status) == input["status"] and
      recovered.authorization_url == input["url"]

  if recovered.status != :prepared do
    {:ok, ^recovered} = HostedCheckout.initialize(credentials, accepted, scope, input["port"])
  end

  IO.puts("E1AF_COMPLETED")
after
  Sandbox.checkin(Repo)
end
