defmodule NewYou.Proof.DeliveryAttemptObservation do
  @moduledoc false

  alias NewYou.Communications.DeliveryAttempt
  alias NewYou.Repo
  require Ash.Query

  @insert ~r/\A\s*INSERT\s+INTO\s+(?:"?\w+"?\.)?"?delivery_attempts"?(?=[\s(])/i

  # The held-email scenario and its Ash writes run synchronously in the fixture
  # process. Returned UUIDs select durable observations before teardown. They
  # never authorize cleanup, and the observer retains no other query data.
  def capture(callback) do
    event = (Repo.config()[:telemetry_prefix] || [:new_you, :repo]) ++ [:query]
    ensure_handler(event)
    previous = Process.put(__MODULE__, [])

    try do
      callback.(fn -> persisted_ids(Process.get(__MODULE__)) end)
    after
      if is_nil(previous), do: Process.delete(__MODULE__), else: Process.put(__MODULE__, previous)
    end
  end

  # One inert TEST handler avoids retaining a handler per fixture if a proof
  # worker is killed. Ecto invokes it in the process that issued the query.
  defp ensure_handler(event) do
    case :telemetry.attach(__MODULE__, event, &__MODULE__.handle_query/4, nil) do
      :ok -> :ok
      {:error, :already_exists} -> :ok
    end
  end

  def handle_query(_event, _measurements, metadata, _config) do
    with previous when not is_nil(previous) <- Process.get(__MODULE__),
         {:ok, %{num_rows: count} = result} when count > 0 <- metadata.result,
         true <- Regex.match?(@insert, metadata.query) do
      Process.put(__MODULE__, returned_ids(result, previous))
    end
  end

  defp returned_ids(%{columns: columns, rows: rows, num_rows: count}, previous)
       when is_list(columns) and is_list(rows) and length(rows) == count and is_list(previous) do
    with index when is_integer(index) <- Enum.find_index(columns, &(&1 == "id")),
         ids = Enum.map(rows, &Ecto.UUID.cast(Enum.at(&1, index))),
         true <- Enum.all?(ids, &match?({:ok, _}, &1)) do
      Enum.map(ids, fn {:ok, id} -> id end) ++ previous
    else
      _ -> :unattributed
    end
  end

  defp returned_ids(_result, _previous), do: :unattributed

  defp persisted_ids(:unattributed),
    do: raise("fixture DeliveryAttempt INSERT did not return its UUID")

  defp persisted_ids([]), do: []

  defp persisted_ids(ids) do
    DeliveryAttempt
    |> Ash.Query.filter(id in ^ids)
    |> Ash.Query.select([:id])
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.id)
  end
end
