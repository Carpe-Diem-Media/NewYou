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
