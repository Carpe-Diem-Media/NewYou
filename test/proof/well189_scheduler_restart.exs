alias NewYou.Repo
alias Ecto.Adapters.SQL.Sandbox

[operation_id] = System.argv()
{:ok, operation_id} = Ecto.UUID.cast(operation_id)
:ok = Sandbox.checkout(Repo, sandbox: false)

try do
  Repo.checkout(fn ->
    # The generated scheduler scans all open rows. Restrict its connection-local
    # view to this fixture, while reading the real committed public row. This
    # prevents it from scheduling another user's shared TEST obligations.
    Repo.query!("""
    CREATE TEMP VIEW commerce_payment_consequences AS
    SELECT c.* FROM public.commerce_payment_consequences c
    JOIN public.commerce_plan_purchases p ON p.id = c.purchase_id
    WHERE p.operation_id = '#{operation_id}'::uuid
    """)

    :ok = NewYou.Commerce.Schedulers.DeliverPlanPayment.perform(%Oban.Job{args: %{}})
    IO.puts("P1_COMPLETED")
  end)
after
  Sandbox.checkin(Repo)
end
