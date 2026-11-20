defmodule NewYou.Proof.FixtureObservation do
  @moduledoc """
  Ephemeral ownership of child writes made by TEST fixture processes.

  Successful INSERT identifiers are captured before parents can disappear. They
  select observations only; they never authorize cleanup or establish business
  state. Counts still query the database, so rolled-back writes are not effects.
  """
  use GenServer

  @event [:new_you, :repo, :query]
  @keys %{
    "tokens" => {:tokens, "jti"},
    "communications_envelope_nonces" => {:nonces, "nonce"},
    "oban_jobs" => {:jobs, "id"},
    "message_intents" => {:intents, "id"},
    "sessions" => {:sessions, "id"}
  }
  @insert ~r/INSERT\s+INTO\s+(?:"?\w+"?\.)?"?(?<table>tokens|communications_envelope_nonces|oban_jobs|message_intents|sessions)"?(?:\s+AS\s+"?\w+"?)?(?:\s*\((?<columns>[^)]+)\))?/i

  def with_scope(fun) do
    previous = context()
    ensure_started()
    scope = GenServer.call(__MODULE__, {:open, self()})

    try do
      fun.()
    after
      GenServer.call(__MODULE__, {:close, scope})
      bind(previous)
    end
  end

  def context do
    if :ets.whereis(__MODULE__) != :undefined do
      Enum.find_value([self() | Process.get(:"$callers", [])], &scope_for/1)
    end
  end

  defp scope_for(pid) do
    case :ets.lookup(__MODULE__, pid) do
      [{^pid, scope}] -> scope
      [] -> nil
    end
  end

  def with_context(nil, fun), do: fun.()

  def with_context(scope, fun) do
    previous = context()
    bind(scope)

    try do
      fun.()
    after
      bind(previous)
    end
  end

  def snapshot do
    ensure_started()
    scope = context() || GenServer.call(__MODULE__, {:open, self()})
    %{scope: scope, ids: owned_ids(scope)}
  end

  def ids(kind), do: snapshot().ids |> Map.fetch!(kind) |> MapSet.to_list()

  # Full rows are read only long enough to compute a digest. Creation IDs
  # include unexpected children and do not depend on their current associations.
  def fingerprint(kind) when kind in [:tokens, :sessions] do
    {table, column, type} =
      case kind do
        :tokens -> {"tokens", "jti", "text"}
        :sessions -> {"sessions", "id", "uuid"}
      end

    %{rows: rows} =
      NewYou.Repo.query!(
        "SELECT row_to_json(owned)::text FROM #{table} owned WHERE #{column} = ANY($1::#{type}[]) ORDER BY #{column}",
        [ids(kind)]
      )

    :crypto.hash(:sha256, :erlang.term_to_binary(rows))
  end

  def new_ids(%{scope: scope, ids: before}, kind) do
    owned_ids(scope)
    |> Map.fetch!(kind)
    |> MapSet.difference(Map.fetch!(before, kind))
    |> MapSet.to_list()
  end

  defp owned_ids(scope) do
    case GenServer.call(__MODULE__, {:ids, scope}) do
      {:error, table} ->
        raise "fixture INSERT into #{table} requires an attributable returned key"

      current ->
        current
    end
  end

  # Runs synchronously in Ecto's query caller. Do not retain full parameters,
  # SQL, JWTs or records, and never run another query inside this handler.
  def handle_query(_event, _measurements, metadata, _config) do
    with {:ok, %{num_rows: count} = result} when count > 0 <- metadata.result,
         %{"table" => table, "columns" => columns} <-
           Regex.named_captures(@insert, metadata.query),
         scope when not is_nil(scope) <- context() do
      {kind, key} = Map.fetch!(@keys, String.downcase(table))

      case inserted_ids(result, key, columns, metadata) do
        {:ok, ids} -> GenServer.call(__MODULE__, {:record, scope, kind, ids})
        :unknown -> GenServer.call(__MODULE__, {:invalid, scope, table})
      end
    else
      _ -> :ok
    end
  end

  defp inserted_ids(%{columns: columns, rows: rows, num_rows: count}, key, _inputs, _metadata)
       when is_list(columns) and is_list(rows) do
    case Enum.find_index(columns, &(&1 == key)) do
      nil ->
        :unknown

      index ->
        ids = Enum.map(rows, &Enum.at(&1, index))

        if length(ids) == count and Enum.all?(ids, &(not is_nil(&1))),
          do: {:ok, ids},
          else: :unknown
    end
  end

  # Raw nonce/JTI INSERTs can supply their key as a bound parameter. Generated
  # job IDs require RETURNING id; guessing them from a global sequence is unsafe.
  defp inserted_ids(%{num_rows: 1}, key, columns, metadata) when key in ["nonce", "jti"] do
    columns = columns |> String.split(",") |> Enum.map(&(String.trim(&1) |> String.trim("\"")))

    with index when is_integer(index) <- Enum.find_index(columns, &(&1 == key)),
         [_, values] <- Regex.run(~r/VALUES\s*\(([^)]+)\)/i, metadata.query),
         value when is_binary(value) <- values |> String.split(",") |> Enum.at(index),
         [_, position] <- Regex.run(~r/^\s*\$(\d+)\s*$/, value),
         id when is_binary(id) <- Enum.at(metadata.params, String.to_integer(position) - 1) do
      {:ok, [id]}
    else
      _ -> :unknown
    end
  end

  defp inserted_ids(_, _, _, _), do: :unknown

  defp ensure_started do
    case GenServer.start(__MODULE__, :ok, name: __MODULE__) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end
  end

  defp bind(nil) do
    if Process.whereis(__MODULE__), do: GenServer.call(__MODULE__, {:bind, self(), nil})
  end

  defp bind(scope), do: GenServer.call(__MODULE__, {:bind, self(), scope})

  @impl true
  def init(:ok) do
    :ets.new(__MODULE__, [:named_table, :protected, read_concurrency: true])
    :ok = :telemetry.attach(__MODULE__, @event, &__MODULE__.handle_query/4, nil)
    {:ok, %{scopes: %{}, monitors: %{}}}
  end

  @impl true
  def handle_call({:open, owner}, _from, state) do
    scope = make_ref()
    monitor = Process.monitor(owner)
    :ets.insert(__MODULE__, {owner, scope})

    entry = %{
      ids: Map.new(@keys, fn {_table, {kind, _key}} -> {kind, MapSet.new()} end),
      error: nil,
      monitor: monitor
    }

    {:reply, scope,
     %{
       state
       | scopes: Map.put(state.scopes, scope, entry),
         monitors: Map.put(state.monitors, monitor, scope)
     }}
  end

  def handle_call({:bind, pid, scope}, _from, state) do
    if Map.has_key?(state.scopes, scope),
      do: :ets.insert(__MODULE__, {pid, scope}),
      else: :ets.delete(__MODULE__, pid)

    {:reply, :ok, state}
  end

  def handle_call({:record, scope, _kind, _ids}, _from, state)
      when not is_map_key(state.scopes, scope),
      do: {:reply, {:error, :closed_scope}, state}

  def handle_call({:record, scope, kind, ids}, _from, state) do
    scopes =
      Map.update!(state.scopes, scope, fn entry ->
        update_in(
          entry,
          [:ids, kind],
          &Enum.reduce(ids, &1, fn id, set -> MapSet.put(set, id) end)
        )
      end)

    {:reply, :ok, %{state | scopes: scopes}}
  end

  def handle_call({:invalid, scope, _table}, _from, state)
      when not is_map_key(state.scopes, scope),
      do: {:reply, {:error, :closed_scope}, state}

  def handle_call({:invalid, scope, table}, _from, state) do
    {:reply, :ok, put_in(state, [:scopes, scope, :error], table)}
  end

  def handle_call({:ids, scope}, _from, state) do
    result =
      case Map.get(state.scopes, scope) do
        nil -> {:error, "closed observation scope"}
        %{error: nil, ids: ids} -> ids
        %{error: table} -> {:error, table}
      end

    {:reply, result, state}
  end

  def handle_call({:close, scope}, _from, state), do: {:reply, :ok, close(state, scope)}

  @impl true
  def handle_info({:DOWN, monitor, :process, _pid, _reason}, state) do
    {:noreply, close(state, Map.get(state.monitors, monitor))}
  end

  defp close(state, scope) do
    case Map.pop(state.scopes, scope) do
      {nil, _} ->
        state

      {entry, scopes} ->
        Process.demonitor(entry.monitor, [:flush])
        :ets.match_delete(__MODULE__, {:_, scope})
        %{state | scopes: scopes, monitors: Map.delete(state.monitors, entry.monitor)}
    end
  end
end
