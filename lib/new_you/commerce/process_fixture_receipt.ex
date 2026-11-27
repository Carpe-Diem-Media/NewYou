defmodule NewYou.Commerce.ProcessFixtureReceipt do
  @moduledoc false

  use Ash.Resource.Actions.Implementation

  if Mix.env() == :test do
    @impl true
    def run(input, _opts, _context) do
      with id when is_binary(id) <- input.arguments.primary_key["id"],
           :ok <- NewYou.Commerce.apply_hosted_payment_evidence(id) do
        :ok
      else
        _ -> {:error, "Fixture evidence remains unprocessed"}
      end
    end
  else
    @impl true
    def run(_, _, _), do: {:error, "Fixture execution requires TEST"}
  end
end
