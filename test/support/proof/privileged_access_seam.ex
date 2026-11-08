defmodule NewYou.Proof.PrivilegedAccessSeam do
  @moduledoc "TEST-only TOTP clock observation for deterministic period-boundary proof."
  def timestamp, do: Process.get(__MODULE__, System.os_time(:second))
end
