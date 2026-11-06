defmodule NewYou.Proof.DeliverySeam do
  @moduledoc "TEST-only checkpoints around the real Communications transaction and provider boundary."
  def checkpoint(point) do
    case Process.get(__MODULE__) do
      callback when is_function(callback, 1) -> callback.(point)
      nil -> :ok
    end
  end
end
