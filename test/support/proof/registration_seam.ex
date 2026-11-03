defmodule NewYou.Proof.RegistrationSeam do
  @moduledoc """
  TEST-only checkpoint at the end of AcceptRegistration, before Ash commits.
  Only the proof worker's process dictionary can bind it. Requests, runtime
  configuration and action input cannot select or supply a checkpoint.
  It observes or interrupts the existing transaction; it never wraps it.
  """

  def checkpoint do
    case Process.get(__MODULE__) do
      nil ->
        :ok

      {:pause, parent, reference} ->
        %{rows: [[backend, transaction]]} =
          NewYou.Repo.query!("SELECT pg_backend_pid(), txid_current()::text")

        send(parent, {reference, :before_commit, self(), backend, transaction})

        receive do
          {^reference, :release} -> :ok
        after
          15_000 -> raise "proof checkpoint deadline"
        end

      {:observe, callback} when is_function(callback, 0) ->
        callback.()
    end
  end
end
