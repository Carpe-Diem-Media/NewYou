alias NewYou.Commerce

false = Code.ensure_loaded?(NewYou.Proof.PlanPaymentObservation)
{:ok, {Commerce, [imports: imports]}} = :beam_lib.chunks(:code.which(Commerce), [:imports])

false =
  Enum.any?(imports, fn {module, _, _} ->
    module in [NewYou.Proof.PlanPaymentObservation, NewYou.Identity]
  end)

{:error, :payment_unavailable} =
  Commerce.apply_payment_observation(%{
    purchase_id: "11111111-1111-4111-8111-111111111111",
    attempt_id: "22222222-2222-4222-8222-222222222222",
    amount_minor: 39_900,
    currency: "ZAR",
    environment: :test,
    integration: :synthetic,
    status: :succeeded
  })

IO.puts("P1 production fixture exclusion passed")
