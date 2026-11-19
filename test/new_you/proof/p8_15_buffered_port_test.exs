# Compile the actual collector with a test-only entry point. This controls Port
# packet boundaries without exposing private production functions or starting Mix.
source_path = Path.expand("../../support/proof/p8_15_port.ex", __DIR__)

{:defmodule, meta, [_name, [do: {:__block__, block_meta, definitions}]]} =
  source_path |> File.read!() |> Code.string_to_quoted!()

entry =
  quote do
    def collect_owned_port(port, started, deadline) do
      run_port(port, System.find_executable("ps"), "", deadline - started, started)
    end
  end

Code.compile_quoted(
  {:defmodule, meta,
   [NewYou.Proof.P815BufferedCollector, [do: {:__block__, block_meta, definitions ++ [entry]}]]},
  source_path
)

defmodule NewYou.Proof.P815BufferedPortTest do
  use ExUnit.Case, async: true

  @signals "P815_STARTED\nP815_OPERATION\nP815_CHECKPOINT\nP815_INTERRUPT_READY\n"

  test "coalesced READY and checkpoint interrupt without another data event" do
    assert %{status: :interrupted, cleanup: :confirmed, checkpoint?: true} =
             collect(["P815_READY\n" <> @signals])
  end

  test "split READY and checkpoint packets interrupt" do
    assert %{status: :interrupted, cleanup: :confirmed, checkpoint?: true} =
             collect(["P815_READY\n", @signals])
  end

  test "an incomplete final line cannot authorize interruption" do
    assert %{status: :timeout, cleanup: :confirmed} =
             collect(["P815_READY\n" <> String.trim_trailing(@signals, "\n")])
  end

  test "a missing checkpoint cannot authorize interruption" do
    assert %{status: :timeout, cleanup: :confirmed, checkpoint?: false} =
             collect(["P815_READY\n" <> String.replace(@signals, "P815_CHECKPOINT\n", "")])
  end

  test "an expired deadline takes priority over buffered checkpoint signals" do
    assert %{status: :timeout, cleanup: :unconfirmed} =
             collect(["P815_READY\n" <> @signals], -1)
  end

  test "overflow takes priority over complete checkpoint signals" do
    assert %{status: :output_overflow, cleanup: :confirmed} =
             collect(["P815_READY\n" <> @signals <> String.duplicate("x", 8_192)])
  end

  defp collect(packets, timeout \\ 200) do
    # This test process owns the real, isolated Port. Its child emits no data,
    # so only the explicitly queued packets can advance the collector.
    port =
      Port.open({:spawn_executable, System.find_executable("sh")}, [
        :binary,
        :exit_status,
        :stderr_to_stdout,
        args: ["-c", "IFS= read -r go; IFS= read -r payload"]
      ])

    {:os_pid, pid} = Port.info(port, :os_pid)
    {pgid, 0} = System.cmd("ps", ["-o", "pgid=", "-p", Integer.to_string(pid)])
    assert String.trim(pgid) == Integer.to_string(pid)

    try do
      send(self(), {port, {:data, "P815_GROUP=#{pid}\n"}})
      Enum.each(packets, &send(self(), {port, {:data, &1}}))
      started = System.monotonic_time(:millisecond)

      result =
        NewYou.Proof.P815BufferedCollector.collect_owned_port(port, started, started + timeout)

      assert result.cleanup == if(timeout < 0, do: :unconfirmed, else: :confirmed)
      assert NewYou.Proof.P815BufferedCollector.external_stopped?(pid)
      refute_receive {^port, _}, 0
      result
    after
      if Port.info(port), do: Port.close(port)
    end
  end
end
