alias NewYou.Commerce.{HostedCheckout, PaystackCheckout}

{:ok, {HostedCheckout, [imports: imports]}} =
  :beam_lib.chunks(:code.which(HostedCheckout), [:imports])

false =
  Enum.any?(imports, fn {module, _, _} ->
    module in [Req.Request, PaystackCheckout, Ash, :telemetry]
  end)

true = Code.ensure_loaded?(PaystackCheckout)
false = function_exported?(PaystackCheckout, :build, 3)

scope = %{provider: :paystack, integration: :local_fixture, environment: :test, channel: :card}
credentials = %{session_id: "fixture-only", token: "fixture-only"}

# Configuration cannot turn a non-TEST build into a wire caller.
Application.put_env(:new_you, :paystack, enabled: true, integration: :local_fixture)

{:error, :provider_disabled} = HostedCheckout.prepare(credentials, %{}, scope)
{:error, :provider_disabled} = HostedCheckout.initialize(credentials, %{}, scope, 1)
{:error, :provider_disabled} = HostedCheckout.recover(credentials, %{}, scope)

IO.puts("E1a-F non-TEST dispatch exclusion passed")

false = Code.ensure_loaded?(NewYouWeb.FixtureWebhook)
false = Code.ensure_loaded?(NewYou.Commerce.Workers.VerifyFixtureReference)
false = Code.ensure_loaded?(NewYou.Commerce.Workers.ProcessFixtureReceipt)
false = function_exported?(PaystackCheckout, :build_verify, 2)

{:error, :provider_disabled} = NewYou.Commerce.HostedPaymentEvidence.verify_due("fixture-only")
{:error, :unavailable} = NewYou.Commerce.apply_hosted_payment_evidence("fixture-only")

IO.puts("E1b-F non-TEST fixture ingress, Verify and settlement exclusion passed")
