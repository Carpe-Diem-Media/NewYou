defmodule NewYou.Proof.P805Fixture do
  @moduledoc """
  VM-local ownership of P805's shared TEST environment and synthetic scope.

  Admission, the environment snapshot, cleanup, restoration and release share
  one atomic boundary. An interrupted owner or guardian leaves the record in
  place. Only verified settlement and successful scoped cleanup release it.
  This is TEST coordination, not durable application or Domain authority.
  """

  @key {__MODULE__, :ownership}

  def acquire(environment, projection_key, cleanup_hook) do
    # Reject before waiting on a cleanup lock, without reading global settings.
    if current(), do: raise("P8-05 fixture already active or quarantined")

    locked(fn ->
      if current(), do: raise("P8-05 fixture already active or quarantined")

      fixture = %{
        reference: make_ref(),
        owner: self(),
        guardian: nil,
        phase: :owned,
        quarantine_reason: nil,
        previous: Map.new(environment, &{&1, Application.fetch_env(:new_you, &1)}),
        projection_key: projection_key,
        cleanup_hook: cleanup_hook,
        operations: [],
        emails: [],
        webhook_receipt_digests: [],
        foreign_operations: [],
        foreign_emails: [],
        foreign_projections: [],
        workers: [],
        ports: %{},
        external_launch: nil
      }

      store(fixture)
      fixture.reference
    end)
  end

  def attach(reference, guardian), do: update(reference, &%{&1 | guardian: guardian})

  def track(reference, :operation, operation),
    do: update(reference, &%{&1 | operations: Enum.uniq([operation | &1.operations])})

  def track(reference, :email, email),
    do: update(reference, &%{&1 | emails: Enum.uniq([email | &1.emails])})

  def track(reference, :webhook_receipt_digest, <<_::256>> = digest),
    do: update(reference, &%{&1 | webhook_receipt_digests: [digest | &1.webhook_receipt_digests]})

  def track(reference, :foreign_operation, operation),
    do:
      update(
        reference,
        &%{&1 | foreign_operations: Enum.uniq([operation | &1.foreign_operations])}
      )

  def track(reference, :foreign_email, email),
    do: update(reference, &%{&1 | foreign_emails: Enum.uniq([email | &1.foreign_emails])})

  def track(reference, :foreign_projection, key),
    do: update(reference, &%{&1 | foreign_projections: [key | &1.foreign_projections]})

  # Registered workers must launch externals through P805.open_restart_port/3.
  # A BEAM DOWN alone never settles a recorded external process group.
  def worker(reference, worker),
    do: update(reference, &%{&1 | workers: Enum.uniq([worker | &1.workers])})

  # The guardian launches sequentially. An unresolved attempt must never be
  # replaced, even if its worker has exited or its Port has already closed.
  def begin_external(reference) do
    locked(fn ->
      case current() do
        %{reference: ^reference, phase: :owned, external_launch: nil} = fixture ->
          launch = make_ref()
          store(%{fixture | external_launch: %{reference: launch, port: nil}})
          {:ok, launch}

        _ ->
          {:error, :launch_unavailable}
      end
    end)
  end

  def opened(reference, launch, port) when is_port(port) do
    update_launch(reference, launch, fn fixture ->
      case fixture.external_launch do
        %{port: nil} = reservation ->
          %{fixture | external_launch: %{reservation | port: port}}

        _ ->
          {:error, :invalid_launch_transition}
      end
    end)
  end

  def port(reference, launch, port, pid) when is_integer(pid) and pid > 1 do
    update_launch(reference, launch, fn fixture ->
      if fixture.external_launch.port == port and not Map.has_key?(fixture.ports, port),
        do: %{fixture | ports: Map.put(fixture.ports, port, pid)},
        else: {:error, :invalid_launch_transition}
    end)
  end

  def settle_external(reference, launch, outcome) when outcome in [:not_started, :started] do
    update_launch(reference, launch, fn fixture ->
      port = fixture.external_launch.port

      if (outcome == :not_started and is_nil(port)) or
           (outcome == :started and is_port(port) and Map.has_key?(fixture.ports, port)),
         do: %{fixture | external_launch: nil},
         else: {:error, :invalid_launch_transition}
    end)
  end

  def settling(reference), do: update(reference, &%{&1 | phase: :settling})
  def quarantine(reference), do: update(reference, &%{&1 | phase: :quarantined})

  def active?(reference), do: match?(%{reference: ^reference}, current())

  def owned?(reference), do: match?(%{reference: ^reference, phase: :owned}, current())

  @doc "Returns the exact synthetic recovery target, excluding environment secrets and hooks."
  def info do
    case current() do
      nil -> :available
      fixture -> Map.drop(fixture, [:previous, :cleanup_hook])
    end
  end

  @doc """
  Rechecks workers and recorded OS process groups before scoped cleanup.
  Never kills a process or accepts a caller assertion of external termination.
  Failed cleanup retains the same target for another explicit reconciliation.
  """
  def reconcile(reference, cleanup) do
    locked(fn ->
      case current() do
        %{reference: ^reference} = fixture ->
          reconcile_current(fixture, cleanup)

        _ ->
          {:error, :not_quarantined}
      end
    end)
  end

  defp reconcile_current(fixture, cleanup) do
    if fixture.phase == :quarantined or not Process.alive?(fixture.owner) do
      do_finish(fixture, cleanup)
    else
      {:error, :not_quarantined}
    end
  end

  def finish(reference, cleanup) when is_reference(reference) do
    locked(fn ->
      case current() do
        %{reference: ^reference} = fixture -> do_finish(fixture, cleanup)
        _ -> {:error, :stale_fixture}
      end
    end)
  end

  defp do_finish(fixture, cleanup) do
    if safe?(fixture) do
      try do
        :ok = cleanup.(fixture)
        restore_environment(fixture.previous)
        # Erase last, while still holding the same admission mutex.
        :persistent_term.erase(@key)
        :ok
      rescue
        _ -> retain(fixture, :cleanup_failed)
      catch
        _, _ -> retain(fixture, :cleanup_failed)
      end
    else
      retain(fixture, :processes_unconfirmed)
    end
  end

  defp safe?(fixture) do
    launch_settled?(fixture) and
      Enum.all?(fixture.workers, &(not Process.alive?(&1))) and
      Enum.all?(fixture.ports, fn {port, pid} ->
        is_nil(Port.info(port)) and NewYou.Proof.P815Port.external_stopped?(pid)
      end)
  end

  defp launch_settled?(%{external_launch: nil}), do: true

  defp launch_settled?(fixture) do
    # An interrupted transfer can reconcile only through its recorded OS target.
    # A reservation without that identity stays quarantined, even after Port exit.
    Map.has_key?(fixture.ports, fixture.external_launch.port)
  end

  defp retain(fixture, reason) do
    store(%{fixture | phase: :quarantined, quarantine_reason: reason})
    {:error, reason}
  end

  defp restore_environment(previous) do
    Enum.each(previous, fn
      {key, {:ok, value}} -> Application.put_env(:new_you, key, value)
      {key, :error} -> Application.delete_env(:new_you, key)
    end)
  end

  defp update(reference, callback) do
    locked(fn ->
      case current() do
        %{reference: ^reference} = fixture ->
          store(callback.(fixture))
          :ok

        _ ->
          {:error, :stale_fixture}
      end
    end)
  end

  defp update_launch(reference, launch, callback) do
    locked(fn ->
      case current() do
        %{reference: ^reference, external_launch: %{reference: ^launch}} = fixture ->
          store_launch_update(callback.(fixture))

        _ ->
          {:error, :stale_launch}
      end
    end)
  end

  defp store_launch_update({:error, _} = error), do: error
  defp store_launch_update(updated), do: store(updated)

  defp current, do: :persistent_term.get(@key, nil)
  defp store(fixture), do: :persistent_term.put(@key, fixture)
  defp locked(callback), do: :global.trans({__MODULE__, self()}, callback, [node()])
end
