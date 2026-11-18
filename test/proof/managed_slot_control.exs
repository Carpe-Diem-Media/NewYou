defmodule NewYou.ManagedSlotControl do
  @moduledoc """
  Private probe control protocol. The controller supplies an existing mode-0700
  directory through `control_directory`. Each phase creates one exclusive JSON
  file, at most 4096 payload bytes. The controller must read a complete newline-
  terminated record, since creation can precede completion. It does not wait on stdout,
  then sends a JSON line with `ack` and the complete `identity` on stdin.
  Ready acknowledgements also supply `peer_database`. Missing acknowledgement,
  cancellation, malformed input and timeout fail closed. Files are evidence;
  this module never removes them or releases a lease.
  """
  @limit 4096
  @keys ~w(lease generation job worktree database role)

  def child_result(0, receipt), do: {:ok, receipt}
  def child_result(_, _), do: {:error, :child_failed}

  def valid_identity?(receipt) do
    identity = identity(receipt)
    generation = identity["generation"]
    database = identity["database"]

    Enum.all?(~w(lease generation job), fn key ->
      is_binary(identity[key]) and Regex.match?(~r/\A[0-9a-f]{32}\z/, identity[key])
    end) and is_binary(identity["worktree"]) and Path.type(identity["worktree"]) == :absolute and
      is_binary(database) and Regex.match?(~r/\Adc_new_you_s\d{2}_g[0-9a-f]{32}\z/, database) and
      String.ends_with?(database, "_g" <> generation) and identity["role"] == database <> "_r"
  end

  def identity(receipt), do: Map.take(receipt, @keys)

  def acknowledge(value, phase, receipt) do
    keys = if phase == "ready", do: ~w(ack identity peer_database), else: ~w(ack identity)

    cond do
      value == %{"cancel" => true} -> {:error, :cancelled}
      not is_map(value) -> {:error, :malformed}
      Enum.sort(Map.keys(value)) != Enum.sort(keys) -> {:error, :malformed}
      value["ack"] != phase -> {:error, :wrong_phase}
      not valid_identity?(receipt) -> {:error, :identity_mismatch}
      value["identity"] != identity(receipt) -> {:error, :identity_mismatch}
      true -> :ok
    end
  end

  def publish(directory, phase, payload) when phase in ~w(ready done empty child) do
    helper = Path.join(__DIR__, "managed_slot_coordinator.py")

    case System.cmd("python3", [helper, "publish", directory, phase, payload],
           stderr_to_stdout: true
         ) do
      {_, 0} -> :ok
      _ -> {:error, :control_write_failed}
    end
  rescue
    _ -> {:error, :control_write_failed}
  end

  def read_line(device \\ :stdio), do: bounded_line(device, @limit)
  def bounded_line(device, limit), do: read_bytes(device, "", limit)
  defp read_bytes(_device, buffer, limit) when byte_size(buffer) > limit, do: {:error, :too_large}

  defp read_bytes(device, buffer, limit) do
    case IO.binread(device, 1) do
      "\n" -> {:ok, buffer}
      :eof -> {:error, :eof}
      byte when is_binary(byte) -> read_bytes(device, buffer <> byte, limit)
      _ -> {:error, :read_failed}
    end
  end

  def await(reader, timeout) do
    task = Task.async(reader)

    case Task.yield(task, timeout) || Task.shutdown(task, :brutal_kill) do
      {:ok, result} -> result
      _ -> {:error, :timeout}
    end
  end
end
