defmodule NewYou.Proof.RecoverySeam do
  @moduledoc "Test-only recovery clock and fixed transaction diagnostics; RegistrationSeam supplies pre-commit cuts."

  @stages [
    :transaction_entered,
    :account_locked,
    :resume_verified_channel,
    :await_proof,
    :checkpoint,
    :transaction_returned,
    :transaction_error,
    :transaction_exception
  ]

  def now, do: Process.get({__MODULE__, :now}, DateTime.utc_now())

  def observe(callback) when is_function(callback, 1),
    do: Process.put({__MODULE__, :observer}, callback)

  # Stage names are the whole diagnostic. No request data or exception details
  # enter this callback, including on neutral public-request failures.
  def trace(stage) when stage in @stages do
    case Process.get({__MODULE__, :observer}) do
      callback when is_function(callback, 1) -> callback.(stage)
      _ -> :ok
    end

    :ok
  end
end
