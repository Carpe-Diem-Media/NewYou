defmodule NewYou.Proof.SecurityHoldSeam do
  @moduledoc "TEST-only callbacks at the owning privileged-support durable boundaries."
  def checkpoint(point) do
    case Process.get(__MODULE__) do
      callback when is_function(callback, 1) -> callback.(point)
      nil -> :ok
    end

    :ok
  end
end
