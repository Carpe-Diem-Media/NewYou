defmodule NewYou.Commerce.DeliverPlanPayment do
  @moduledoc false
  use Ash.Resource.Actions.Implementation

  @impl true
  def run(input, _opts, _context) do
    case input.arguments.primary_key do
      %{"id" => id} -> deliver(id)
      %{id: id} -> deliver(id)
      _ -> {:error, "Payment consequence identifier required"}
    end
  end

  defp deliver(id) do
    case NewYou.Commerce.deliver_plan_payment_consequence(id) do
      {:ok, _right} -> :ok
      {:error, _reason} -> {:error, "Payment consequence remains open"}
    end
  end
end
