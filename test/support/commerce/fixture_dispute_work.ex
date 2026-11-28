defmodule NewYou.Commerce.FixtureDisputeWork do
  @moduledoc false
  use Ash.Resource.Actions.Implementation

  alias NewYou.Commerce.FixtureDisputes

  @impl true
  def run(input, opts, _context) do
    case input.arguments.primary_key["id"] do
      id when is_binary(id) -> perform(opts[:operation], id)
      _ -> {:error, "Fixture work unavailable"}
    end
  end

  defp perform(:process, id), do: FixtureDisputes.apply_receipt(id)
  defp perform(:deliver, id), do: FixtureDisputes.deliver(id)
  defp perform(:read_due, id), do: FixtureDisputes.read_due(id)
end
