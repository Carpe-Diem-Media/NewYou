defmodule NewYou.Proof.AuditSeam do
  @moduledoc """
  TEST-only observation inside the actual Audit transaction. Only the proof
  worker process dictionary can select a checkpoint. No runtime configuration,
  action input or production executable exposes it.
  """
  def checkpoint(point) do
    case Process.get(__MODULE__) do
      callback when is_function(callback, 1) ->
        callback.(point)
        :ok

      nil ->
        :ok
    end
  end
end
