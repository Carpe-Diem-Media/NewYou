defmodule NewYou.Communications.Actions.ExecuteDelivery do
  @moduledoc false
  use Ash.Resource.Actions.Implementation
  @impl true
  def run(input, _, _) do
    case input.arguments.primary_key do
      %{"id" => id} -> NewYou.Communications.execute(id)
      %{id: id} -> NewYou.Communications.execute(id)
      _ -> {:error, :delivery_unavailable}
    end
  end
end
