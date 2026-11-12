defmodule NewYou.Proof.RecoverySeam do
  @moduledoc "Test-only recovery clock; existing P8-04 Scenario and RegistrationSeam supply transaction cuts and contention proof."
  def now, do: Process.get({__MODULE__, :now}, DateTime.utc_now())
end
