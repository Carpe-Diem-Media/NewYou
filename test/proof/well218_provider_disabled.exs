alias NewYou.Commerce.{HostedCheckout, PaystackCheckout, PaystackTestIntegration}

scope = %{provider: :paystack, integration: :voelgoedwinkel, environment: :test, channel: :card}
fixture_scope = %{scope | integration: :local_fixture}
attempt = "1179dc31-72bc-4f01-a2cd-78f59ccd45ac"

fixture = %{
  attempt_id: attempt,
  listener: %{port: 1, certificate: <<0>>},
  restricted_key: "rk_test_fixture_canary",
  email: "fixture@example.test",
  capability_key: :binary.copy(<<251>>, 32)
}

Application.put_env(:new_you, :paystack_test_checkout, fixture)

System.put_env(%{
  "NEW_YOU_PAYSTACK_TEST_APPROVED_ATTEMPT_ID" => attempt,
  "NEW_YOU_PAYSTACK_TEST_RESTRICTED_KEY" => "rk_test_runtime_canary",
  "NEW_YOU_PAYSTACK_TEST_EMAIL" => "runtime@example.test",
  "NEW_YOU_PAYSTACK_TEST_CAPABILITY_KEY" => Base.encode64(:binary.copy(<<81>>, 32))
})

true = Code.ensure_loaded?(PaystackCheckout)
true = Code.ensure_loaded?(PaystackTestIntegration)
false = function_exported?(PaystackCheckout, :build, 3)
false = function_exported?(PaystackCheckout, :build_verify, 2)
{:error, :provider_disabled} = HostedCheckout.initialize(%{}, %{}, fixture_scope, 1)
nil = Process.whereis(NewYou.Repo)

case Mix.env() do
  :dev ->
    System.delete_env("NEW_YOU_PAYSTACK_TEST_ENABLED")
    {:error, :checkout_unavailable} = PaystackTestIntegration.settings(attempt)
    System.put_env("NEW_YOU_PAYSTACK_TEST_ENABLED", "true")
    {:ok, %{listener: :paystack}} = PaystackTestIntegration.settings(attempt)

    false = Code.ensure_loaded?(NewYouWeb.FixtureWebhook)
    false = Code.ensure_loaded?(NewYou.Commerce.Workers.VerifyFixtureReference)
    nil = Ash.Resource.Info.action(NewYou.Commerce.HostedDispatch, :verify_fixture_reference)
    [] = AshOban.Info.oban_triggers_and_scheduled_actions(NewYou.Commerce.HostedDispatch)

    {:ok, {HostedCheckout, [imports: imports]}} =
      :beam_lib.chunks(:code.which(HostedCheckout), [:imports])

    false = Enum.any?(imports, fn {module, _, _} -> module == Ecto.Adapters.SQL.Sandbox end)
    true = function_exported?(PaystackCheckout, :build_provider, 3)
    {:error, :checkout_unavailable} = HostedCheckout.prepare(%{}, %{}, scope)

    approval_key = "NEW_YOU_PAYSTACK_DEV_PLAN_APPROVAL"
    System.delete_env(approval_key)
    {:error, :purchase_unavailable} = NewYou.LocalConfig.paystack_development_plan()

    approval = %{
      "payer_id" => attempt,
      "operation_id" => Ecto.UUID.generate(),
      "offer_id" => Ecto.UUID.generate(),
      "approval_id" => Ecto.UUID.generate(),
      "disclosure_en_id" => Ecto.UUID.generate(),
      "disclosure_af_id" => Ecto.UUID.generate()
    }

    System.put_env(approval_key, Jason.encode!(approval))
    {:ok, ^approval} = NewYou.LocalConfig.paystack_development_plan()
    {:error, :purchase_unavailable} = NewYou.Commerce.PaystackDevelopmentSource.authorize(%{})

  :prod ->
    System.put_env("NEW_YOU_PAYSTACK_TEST_ENABLED", "true")
    false = function_exported?(PaystackTestIntegration, :settings, 1)
    false = function_exported?(PaystackCheckout, :build_provider, 3)
    {:error, :provider_disabled} = HostedCheckout.prepare(%{}, %{}, scope)
    {:error, :provider_disabled} = HostedCheckout.initialize(%{}, %{}, scope)
    {:error, :provider_disabled} = HostedCheckout.recover(%{}, %{}, scope)
end

IO.puts("WELL-190 checkout build boundary passed for #{Mix.env()}")

# The E1b-F fixture remains unavailable in both non-TEST builds.
false = Code.ensure_loaded?(NewYouWeb.FixtureWebhook)
false = Code.ensure_loaded?(NewYou.Identity.SyntheticPurchaseParties)
false = Code.ensure_loaded?(NewYou.Proof.PlanPaymentObservation)
false = Code.ensure_loaded?(NewYou.Commerce.Workers.VerifyFixtureReference)
false = Code.ensure_loaded?(NewYou.Commerce.Workers.ProcessFixtureReceipt)
{:error, :provider_disabled} = NewYou.Commerce.HostedPaymentEvidence.verify_due("fixture-only")
{:error, :unavailable} = NewYou.Commerce.apply_hosted_payment_evidence("fixture-only")

IO.puts("WELL-219 fixture ingress, Verify and settlement exclusion passed for #{Mix.env()}")
