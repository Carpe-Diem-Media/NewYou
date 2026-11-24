alias NewYou.{Commerce, Entitlements, Repo}
alias Ecto.Adapters.SQL.Sandbox

[stage, purchase_id] = System.argv()
:ok = Sandbox.checkout(Repo, sandbox: false)

try do
  {:ok, [id]} = Commerce.open_plan_payment_consequences(purchase_id)

  {:ok, right} =
    case stage do
      "grant" ->
        Entitlements.grant_paid_plan(id)

      "recover" ->
        :ok =
          Oban.Testing.perform_job(
            NewYou.Commerce.Workers.DeliverPlanPayment,
            %{"primary_key" => %{"id" => id}},
            repo: Repo
          )

        {:ok, []} = Commerce.open_plan_payment_consequences(purchase_id)
        Entitlements.grant_paid_plan(id)
    end

  :held_unconsumed = right.state
  IO.puts("P1_RIGHT=#{right.id}")
after
  Sandbox.checkin(Repo)
end
