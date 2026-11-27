defmodule NewYou.Commerce.FixtureRefundWork do
  @moduledoc false

  use Ash.Resource.Actions.Implementation

  @impl true
  def run(input, opts, _context) do
    case input.arguments.primary_key["id"] do
      id when is_binary(id) -> perform(opts[:operation], id)
      _ -> {:error, "Fixture work unavailable"}
    end
  end

  defp perform(:process_receipt, id), do: NewYou.Commerce.apply_fixture_refund_receipt(id)
  defp perform(:read_due, id), do: NewYou.Commerce.FixtureRefunds.read_due(id)
  defp perform(:deliver, id), do: NewYou.Commerce.deliver_fixture_refund(id)
end
