defmodule NewYou.Commerce.FixtureCorrectionSource do
  @moduledoc """
  Shared Commerce serialization and pinned read inputs for corrections to
  one accepted fixture purchase. The purchase lock also orders payment grants.
  """

  alias Ecto.Adapters.SQL.Sandbox
  alias NewYou.Commerce.{HostedDispatch, Purchase}
  alias NewYou.Repo

  require Ash.Query

  @doc false
  def lock_purchase(id) do
    Purchase
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.lock(:for_update)
    |> Ash.read_one(authorize?: false)
  end

  @doc false
  def transact(operation),
    do: Repo.without_query_telemetry(fn -> Ash.transact(Purchase, operation) end)

  @doc false
  def pinned_listener(%{attempt_id: attempt_id}) do
    case Ash.get(HostedDispatch, attempt_id, authorize?: false) do
      {:ok, %{fixture_certificate: certificate, fixture_port: port}}
      when is_binary(certificate) and byte_size(certificate) in 1..8_192 and port in 1..65_535 ->
        {:ok, %{port: port, certificate: certificate}}

      _ ->
        {:error, :listener_unavailable}
    end
  end

  @doc false
  def next_read(round, now) do
    round = min(round + 1, 6)
    delay = min(30 * Integer.pow(2, round - 1), 900)
    %{verify_round: round, verify_after: DateTime.add(now, delay)}
  end

  @doc false
  def retry_delay(response) do
    with [header] <- Req.Response.get_header(response, "retry-after"),
         true <- byte_size(header) <= 10,
         {seconds, ""} <- Integer.parse(header) do
      max(60, min(seconds, 900))
    else
      _ -> 60
    end
  end

  # Sandbox can acknowledge a savepoint while the enclosing transaction can
  # still roll back. An unboxed connection must see the exact winning claim.
  @doc false
  def independently_visible?(read) do
    observer = Task.async(fn -> independently_read(read) end)

    case Task.yield(observer, 2_000) do
      {:ok, result} ->
        result

      nil ->
        Task.shutdown(observer, :brutal_kill)
        false
    end
  end

  defp independently_read(read) do
    Sandbox.unboxed_run(Repo, fn -> Repo.without_query_telemetry(read) end)
  rescue
    _ -> false
  end
end
