defmodule NewYou.Proof.ReconciliationSeam do
  @moduledoc "Test-only source crash and race cutpoints. Absent from production builds."
  def control_time, do: Process.get({__MODULE__, :control_time}, DateTime.utc_now())

  def checkpoint(point) do
    case Process.get(__MODULE__) do
      callback when is_function(callback, 1) -> callback.(point)
      _ -> :ok
    end
  end
end
