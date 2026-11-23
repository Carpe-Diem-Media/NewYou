defmodule NewYou.Repo do
  use AshPostgres.Repo,
    otp_app: :new_you

  @doc """
  Disables SQL telemetry and logging for synchronous queries that use Repo defaults.

  Use when query metadata would carry restricted values. The previous setting
  is restored on return or failure. This does not propagate to spawned processes.
  """
  @spec without_query_telemetry((-> result)) :: result when result: var
  def without_query_telemetry(callback) do
    key = {__MODULE__, :without_query_telemetry}
    previous = Process.put(key, true)

    try do
      callback.()
    after
      if is_nil(previous), do: Process.delete(key), else: Process.put(key, previous)
    end
  end

  @impl true
  def default_options(operation) do
    if Process.get({__MODULE__, :without_query_telemetry}) do
      [telemetry_event: nil, log: false]
    else
      super(operation)
    end
  end

  @impl true
  def installed_extensions do
    # Add extensions here, and the migration generator will install them.
    ["ash-functions"]
  end

  # Don't open unnecessary transactions
  # will default to `false` in 4.0
  @impl true
  def prefer_transaction? do
    false
  end

  @impl true
  def min_pg_version do
    %Version{major: 16, minor: 0, patch: 0}
  end
end
