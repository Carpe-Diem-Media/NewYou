defmodule NewYou.Proof.P817PrivacySeam do
  @moduledoc "TEST-only cut-points around Identity's current Privacy re-read."

  def checkpoint(point) do
    case Process.get(__MODULE__) do
      {:pause, parent, reference, ^point} ->
        %{rows: [[backend, transaction]]} =
          NewYou.Repo.query!("SELECT pg_backend_pid(), txid_current()::text")

        send(parent, {reference, :p817_privacy_checkpoint, self(), backend, transaction, point})

        receive do
          {^reference, :release} -> :ok
        after
          15_000 -> raise "P8-17 Privacy checkpoint deadline"
        end

      {:fail, ^point} ->
        {:error, :privacy_authority_unavailable}

      _ ->
        :ok
    end
  end
end
