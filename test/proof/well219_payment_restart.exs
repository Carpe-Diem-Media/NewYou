alias Ecto.Adapters.SQL.Sandbox
alias NewYou.{Commerce, Entitlements, Repo}
alias NewYou.Commerce.HostedDispatch

input = IO.gets("") |> Jason.decode!()
:ok = Sandbox.checkout(Repo, sandbox: false)

try do
  %{failure: 0, discard: 0, queues_not_drained: []} =
    AshOban.Test.schedule_and_run_triggers({HostedDispatch, :verify_fixture_reference})

  {:ok, [consequence]} = Commerce.open_plan_payment_consequences(input["purchase_id"])

  case input["phase"] do
    "verify_then_grant" ->
      # This is the committed state of a delivery worker lost between the
      # owning Entitlements transaction and the Commerce acknowledgement.
      {:ok, %{state: :held_unconsumed}} = Entitlements.grant_paid_plan(consequence)

    "acknowledge" ->
      {:ok, %{state: :held_unconsumed}} = Commerce.deliver_plan_payment_consequence(consequence)
      {:ok, []} = Commerce.open_plan_payment_consequences(input["purchase_id"])
  end

  IO.puts("E1BF_COMPLETED")
after
  Sandbox.checkin(Repo)
end
