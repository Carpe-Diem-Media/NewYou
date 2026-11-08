defmodule NewYou.Proof.ReconciliationSeam do
  @moduledoc "Test-only source crash and race cutpoints. Absent from production builds."
  def checkpoint(point) do
    case Process.get(__MODULE__) do
      callback when is_function(callback, 1) -> callback.(point)
      _ -> :ok
    end
  end
end
