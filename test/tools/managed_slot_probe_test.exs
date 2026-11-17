unless Process.whereis(ExUnit.Server), do: ExUnit.start()

Process.put(:managed_slot_probe_test_load, true)
Code.require_file("../proof/managed_slot_probe.exs", __DIR__)

defmodule NewYou.ManagedSlotProbeTest do
  use ExUnit.Case, async: true

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
               "mode" => "empty"
             })

    assert {:error, :invalid_probe_input} =
             NewYou.ManagedSlotProbe.validate_input(%{
               "own_email" => "person@example.test",
               "peer_email" => peer,
               "mode" => "empty"
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
