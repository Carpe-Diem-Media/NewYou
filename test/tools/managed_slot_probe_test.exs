unless Process.whereis(ExUnit.Server), do: ExUnit.start()

Process.put(:managed_slot_probe_test_load, true)
Code.require_file("../proof/managed_slot_probe.exs", __DIR__)

defmodule NewYou.ManagedSlotProbeTest do
  use ExUnit.Case, async: true

  test "control receipt is available while the stdout secret tail is withheld" do
    directory = Path.join(System.tmp_dir!(), "slot-control-#{System.unique_integer([:positive])}")
    File.mkdir!(directory)
    File.chmod!(directory, 0o700)
    on_exit(fn -> File.rm_rf!(directory) end)
    payload = ~s({"own_count":1})
    old_output = "MANAGED_SLOT_READY=" <> payload <> "\n" <> String.duplicate(".", 256) <> "\n"
    assert byte_size(old_output) < 512
    assert binary_part(old_output, 0, max(byte_size(old_output) - 512, 0)) == ""
    assert :ok = NewYou.ManagedSlotControl.publish(directory, "ready", payload)
    assert File.read!(Path.join(directory, "ready.json")) == payload <> "\n"

    assert {:error, :control_write_failed} =
             NewYou.ManagedSlotControl.publish(directory, "ready", payload)

    assert {:error, :control_write_failed} =
             NewYou.ManagedSlotControl.publish(directory, "done", String.duplicate("x", 4097))
  end

  test "acknowledgements bind phase and every identity field" do
    generation = String.duplicate("b", 32)
    database = "dc_new_you_s01_g" <> generation

    identity = %{
      "lease" => String.duplicate("a", 32),
      "generation" => generation,
      "job" => String.duplicate("c", 32),
      "worktree" => "/private/worktree",
      "database" => database,
      "role" => database <> "_r"
    }

    assert NewYou.ManagedSlotControl.valid_identity?(identity)

    refute NewYou.ManagedSlotControl.valid_identity?(
             Map.put(identity, "generation", String.duplicate("d", 32))
           )

    refute NewYou.ManagedSlotControl.valid_identity?(Map.put(identity, "role", "other"))
    ack = %{"ack" => "done", "identity" => identity}
    assert :ok = NewYou.ManagedSlotControl.acknowledge(ack, "done", identity)

    ready =
      %{ack | "ack" => "ready"}
      |> Map.put("peer_database", "dc_new_you_s02_g" <> String.duplicate("d", 32))

    assert :ok = NewYou.ManagedSlotControl.acknowledge(ready, "ready", identity)

    assert {:error, :malformed} =
             NewYou.ManagedSlotControl.acknowledge(Map.put(ack, "extra", true), "done", identity)

    for key <- Map.keys(identity) do
      wrong = put_in(ack, ["identity", key], "other")

      assert {:error, :identity_mismatch} =
               NewYou.ManagedSlotControl.acknowledge(wrong, "done", identity)
    end

    assert {:error, :wrong_phase} = NewYou.ManagedSlotControl.acknowledge(ack, "child", identity)

    assert {:error, :malformed} =
             NewYou.ManagedSlotControl.acknowledge("finish", "done", identity)

    assert {:error, :cancelled} =
             NewYou.ManagedSlotControl.acknowledge(%{"cancel" => true}, "done", identity)

    assert {:error, :identity_mismatch} =
             NewYou.ManagedSlotControl.acknowledge(
               %{"ack" => "done", "identity" => %{}},
               "done",
               %{}
             )
  end

  test "bounded input and wait reject EOF, oversized data and timeout" do
    {:ok, device} = StringIO.open("")
    assert {:error, :eof} = NewYou.ManagedSlotControl.read_line(device)
    {:ok, device} = StringIO.open(String.duplicate("x", 4097))
    assert {:error, :too_large} = NewYou.ManagedSlotControl.read_line(device)
    {:ok, device} = StringIO.open("ack\n")
    assert {:ok, "ack"} = NewYou.ManagedSlotControl.read_line(device)

    assert {:error, :timeout} =
             NewYou.ManagedSlotControl.await(
               fn ->
                 receive do
                   :never -> :ok
                 end
               end,
               0
             )

    assert {:error, :eof} = NewYou.ManagedSlotControl.await(fn -> {:error, :eof} end, 1000)
  end

  test "child failure cannot become a successful receipt" do
    assert {:ok, %{}} = NewYou.ManagedSlotControl.child_result(0, %{})

    for status <- [1, 2, 137],
        do: assert({:error, :child_failed} = NewYou.ManagedSlotControl.child_result(status, %{}))
  end

  @tag standalone: true
  test "standalone tests do not start the application or database dependencies" do
    for application <- [:new_you, :ecto_sql, :postgrex, :ash],
        not Code.ensure_loaded?(NewYou.Application) do
      refute List.keymember?(Application.started_applications(), application, 0)
    end
  end

  test "a successful wait cannot finish before its reader acknowledges" do
    parent = self()

    waiter =
      Task.async(fn ->
        NewYou.ManagedSlotControl.await(
          fn ->
            send(parent, {:waiting, self()})

            receive do
              :ack -> :ok
            end
          end,
          1000
        )
      end)

    assert_receive {:waiting, reader}
    assert Task.yield(waiter, 0) == nil
    send(reader, :ack)
    assert Task.await(waiter) == :ok
  end

  test "a fresh script invocation rejects DEV before reading input or starting a Repo" do
    expression = "Mix.start(); Code.require_file(\"test/proof/managed_slot_probe.exs\")"

    {executable, arguments} =
      case System.find_executable("mise") do
        nil -> {System.find_executable("elixir"), ["-e", expression]}
        mise -> {mise, ["exec", "--", "elixir", "-e", expression]}
      end

    {output, status} =
      System.cmd(executable, arguments,
        env: [{"MIX_ENV", "dev"}, {"ERL_FLAGS", "+S 2:2"}],
        stderr_to_stdout: true
      )

    assert status == 2
    assert output =~ "MANAGED_SLOT_ERROR=test_environment_required"
  end

  test "psql boundary uses supported options and keeps credentials out of arguments" do
    directory = Path.join(System.tmp_dir!(), "slot-psql-#{System.unique_integer([:positive])}")
    File.mkdir!(directory)
    on_exit(fn -> File.rm_rf!(directory) end)
    executable = Path.join(directory, "psql")

    File.write!(executable, """
    #!/bin/sh
    test "$PGCONNECT_TIMEOUT" = 5 || exit 10
    test -n "$PGPASSWORD" || exit 11
    for argument do
      test "$argument" != "$PGPASSWORD" || exit 12
      case "$argument" in --connect-timeout*) exit 13 ;; esac
    done
    printf '1\\n'
    """)

    File.chmod!(executable, 0o700)

    assert {"1\n", 0} =
             NewYou.ManagedSlotProbe.psql_probe(executable, ["--command=SELECT 1"], "synthetic")
  end

  test "rejects non-test execution before database configuration is read" do
    assert {:error, :test_environment_required} =
             NewYou.ManagedSlotProbe.validate_environment(:dev)
  end

  test "rejects a partial managed lease before verifier or repo access" do
    markers = %{"DEVCORE_SLOT_PROJECT" => "new_you"}

    assert {:error, :managed_markers_required} =
             NewYou.ManagedSlotProbe.validate_markers(markers)
  end

  test "accepts the complete managed marker set only with opaque identifiers" do
    markers = %{
      "DEVCORE_SLOT_PROJECT" => "new_you",
      "DEVCORE_SLOT_LEASE" => String.duplicate("a", 32),
      "DEVCORE_SLOT_GENERATION" => String.duplicate("b", 32),
      "DEVCORE_SLOT_JOB" => String.duplicate("c", 32),
      "DEVCORE_SLOT_WORKTREE" => "/worktrees/new-you"
    }

    assert :ok = NewYou.ManagedSlotProbe.validate_markers(markers)

    assert {:error, :managed_markers_required} =
             NewYou.ManagedSlotProbe.validate_markers(Map.put(markers, "DEVCORE_SLOT_JOB", "job"))
  end

  test "accepts only synthetic slot-proof addresses" do
    valid = "slot-proof-0123456789abcdef0123456789abcdef@example.test"
    peer = "slot-proof-fedcba9876543210fedcba9876543210@example.test"

    assert {:ok, %{own_email: ^valid, peer_email: ^peer, mode: :empty}} =
             NewYou.ManagedSlotProbe.validate_input(%{
               "own_email" => valid,
               "peer_email" => peer,
               "mode" => "empty",
               "control_directory" => "/private/control"
             })

    assert {:error, :invalid_probe_input} =
             NewYou.ManagedSlotProbe.validate_input(%{
               "own_email" => "person@example.test",
               "peer_email" => peer,
               "mode" => "empty",
               "control_directory" => "/private/control"
             })
  end

  test "barrier requires a different allocated slot database" do
    own = "dc_new_you_s01_g" <> String.duplicate("a", 32)
    peer = "dc_new_you_s02_g" <> String.duplicate("b", 32)

    assert {:ok, ^peer} =
             NewYou.ManagedSlotProbe.validate_continue(
               %{"continue" => true, "peer_database" => peer},
               own
             )

    assert {:error, :invalid_barrier_input} =
             NewYou.ManagedSlotProbe.validate_continue(
               %{"continue" => true, "peer_database" => own},
               own
             )

    assert {:error, :invalid_barrier_input} =
             NewYou.ManagedSlotProbe.validate_continue(
               %{"continue" => true, "peer_database" => "new_you_test"},
               own
             )
  end
end
