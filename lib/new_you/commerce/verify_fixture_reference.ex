defmodule NewYou.Commerce.VerifyFixtureReference do
  @moduledoc false

  use Ash.Resource.Actions.Implementation

  if Mix.env() == :test do
    @impl true
    def run(input, _opts, _context) do
      with id when is_binary(id) <- input.arguments.primary_key["attempt_id"],
           :ok <- NewYou.Commerce.HostedPaymentEvidence.verify_due(id) do
        :ok
      else
        _ -> {:error, "Fixture reference remains open"}
      end
    end
  else
    @impl true
    def run(_, _, _), do: {:error, "Fixture execution requires TEST"}
  end
end
