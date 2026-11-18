defmodule NewYou.Proof.P815PortTest do
  use ExUnit.Case, async: true

  alias NewYou.Proof.P815Port

  test "interrupts an owned child only after its complete transaction checkpoint signal" do
    path = temp_path("checkpoint-interrupt")
    on_exit(fn -> clean_pid_file(path) end)

    result =
      P815Port.run(
        System.find_executable("sh"),
        [
          "-c",
          "echo $$ > \"$1\"; printf 'P815_STARTED\\nP815_OPERATION\\nP815_CHECKPOINT\\nP815_INTERRUPT_READY\\n'; exec sleep 5",
          "sh",
          path
        ],
        "",
        2_000
      )

    assert %{status: :interrupted, cleanup: :confirmed, checkpoint?: true} = result
    pid = path |> File.read!() |> String.trim()
    assert {_, 1} = System.cmd("kill", ["-0", pid], stderr_to_stdout: true)
    assert_no_port_messages()
    File.rm!(path)
  end

  test "an incomplete interruption signal cannot count as an observed checkpoint cut" do
    result =
      P815Port.run(
        System.find_executable("sh"),
        [
          "-c",
          "printf 'P815_STARTED\\nP815_OPERATION\\nP815_CHECKPOINT\\nP815_INTERRUPT_READY'; exec sleep 5"
        ],
        "",
        200
      )

    assert %{status: :timeout, cleanup: :confirmed} = result
  end

  test "returns only fixed recovery phases when a transaction misses its checkpoint" do
    result =
      P815Port.run(
        System.find_executable("sh"),
        [
          "-c",
          "printf 'P815_STARTED\\nP815_OPERATION\\nP815_PHASE_TRANSACTION_ENTERED\\nP815_PHASE_ACCOUNT_LOCKED\\nP815_PHASE_TRANSACTION_ERROR\\nP815_PHASE_private-canary\\nP815_INTERRUPTION_NOT_PROVEN\\n'"
        ],
        "",
        1_000
      )

    assert %{status: :ok, marker: :interruption_not_proven, checkpoint?: false} = result
    assert result.phases == [:transaction_entered, :account_locked, :transaction_error]
    refute inspect(result) =~ "private-canary"
  end

  test "reports a nonzero exit without retaining arbitrary output" do
    result =
      P815Port.run(System.find_executable("sh"), ["-c", "printf secret; exit 17"], "", 1_000)

    assert %{status: {:exit, 17}, marker: nil, elapsed_ms: elapsed} = result
    assert elapsed >= 0
    refute inspect(result) =~ "secret"
  end

  test "passes stdin only after the process group is verified and never returns it" do
    result =
      P815Port.run(
        System.find_executable("sh"),
        ["-c", "IFS= read -r value; printf '%s\\nP815_REQUESTED\\n' \"$value\""],
        "private-input-canary",
        1_000
      )

    assert %{status: :ok, marker: :requested, cleanup: :confirmed} = result
    refute inspect(result) =~ "private-input-canary"
    assert_no_port_messages()
  end

  test "distinguishes an unrecognized successful exit from output overflow" do
    sh = System.find_executable("sh")
    assert %{status: :missing_marker} = P815Port.run(sh, ["-c", "printf unexpected"], "", 1_000)

    assert %{status: :output_overflow} =
             P815Port.run(sh, ["-c", "head -c 8192 /dev/zero"], "", 1_000)
  end

  test "retains recognized progress before the output limit is exceeded" do
    python = System.find_executable("python3")
    script = "import os; os.write(1, b'P815_STARTED\\n' + b'x' * 8192)"

    assert %{status: :output_overflow, started?: true} =
             P815Port.run(python, ["-c", script], "", 1_000)
  end

  test "output overflow terminates the child" do
    path = temp_path("overflow")
    on_exit(fn -> clean_pid_file(path) end)

    result =
      P815Port.run(
        System.find_executable("sh"),
        ["-c", "echo $$ > \"$1\"; head -c 8192 /dev/zero; exec sleep 5", "sh", path],
        "",
        1_000
      )

    assert %{status: :output_overflow, cleanup: :confirmed} = result
    pid = path |> File.read!() |> String.trim()
    assert {_, 1} = System.cmd("kill", ["-0", pid], stderr_to_stdout: true)
    File.rm!(path)
  end

  test "reports a deadline without accepting a late marker" do
    path = temp_path("pid")
    on_exit(fn -> clean_pid_file(path) end)

    result =
      P815Port.run(
        System.find_executable("sh"),
        ["-c", "echo $$ > \"$1\"; exec sleep 5", "sh", path],
        "",
        200
      )

    assert %{status: :timeout, marker: nil, cleanup: :confirmed} = result
    pid = path |> File.read!() |> String.trim()
    assert {_, 1} = System.cmd("kill", ["-0", pid], stderr_to_stdout: true)
    assert_no_port_messages()
    File.rm!(path)
  end

  test "does not launch a child after its deadline has already expired" do
    assert %{status: :timeout, cleanup: :not_started, started?: false} =
             P815Port.run(
               System.find_executable("sh"),
               ["-c", "printf 'P815_REQUESTED\\n'"],
               "",
               0
             )
  end

  test "recognizes only allowed progress and failure classes" do
    result =
      P815Port.run(
        System.find_executable("sh"),
        [
          "-c",
          "printf 'P815_STARTED\\nP815_OPERATION\\nP815_FAILURE_CLASS_DBConnection.ConnectionError\\n' >&2; exit 9"
        ],
        "",
        1_000
      )

    assert %{status: {:exit, 9}, started?: true, operation?: true, failure_class: :connection} =
             result

    unknown =
      P815Port.run(
        System.find_executable("sh"),
        ["-c", "printf 'P815_FAILURE_CLASS_PRIVATE-CANARY\\n' >&2; exit 9"],
        "",
        1_000
      )

    assert %{failure_class: :other} = unknown
    refute inspect(unknown) =~ "PRIVATE-CANARY"
  end

  test "reports an executable startup failure without retaining shell output" do
    result = P815Port.run("/definitely-missing-p815-executable", [], "", 1_000)

    assert %{status: {:exit, 127}, started?: false, operation?: false, cleanup: :confirmed} =
             result

    refute inspect(result) =~ "definitely-missing"
    assert %{status: :startup_failure, cleanup: :not_started} = P815Port.run(nil, [], "", 1_000)
  end

  test "requires a clean exit for a recognized success marker" do
    sh = System.find_executable("sh")
    command = "printf 'P815_STARTED\\nP815_OPERATION\\nP815_REQUEST_RETRIED\\n'; exit %s"

    assert %{status: :ok, marker: :request_retried, exit_status: 0} =
             P815Port.run(sh, ["-c", String.replace(command, "%s", "0")], "", 1_000)

    assert %{status: {:exit, 7}, marker: :request_retried, exit_status: 7} =
             P815Port.run(sh, ["-c", String.replace(command, "%s", "7")], "", 1_000)
  end

  test "abnormal child exit cannot leave a background descendant running" do
    path = temp_path("descendant")
    on_exit(fn -> clean_pid_file(path) end)

    result =
      P815Port.run(
        System.find_executable("sh"),
        ["-c", "sleep 5 >/dev/null 2>&1 & echo $! > \"$1\"; exit 7", "sh", path],
        "",
        1_000
      )

    assert %{status: {:exit, 7}, exit_status: 7, cleanup: :confirmed} = result
    pid = path |> File.read!() |> String.trim()
    assert {_, 1} = System.cmd("kill", ["-0", pid], stderr_to_stdout: true)
    File.rm!(path)
  end

  test "terminates the child when the caller is killed" do
    path = temp_path("cancel")
    on_exit(fn -> clean_pid_file(path) end)

    {owner, monitor} =
      spawn_monitor(fn ->
        P815Port.run(
          System.find_executable("sh"),
          ["-c", "echo $$ > \"$1\"; exec sleep 5", "sh", path],
          "",
          5_000
        )
      end)

    assert wait_until(fn -> File.exists?(path) end, System.monotonic_time(:millisecond) + 2_000)
    pid = path |> File.read!() |> String.trim()
    Process.exit(owner, :kill)
    assert_receive {:DOWN, ^monitor, :process, ^owner, :killed}, 1_000

    assert wait_until(
             fn -> elem(System.cmd("kill", ["-0", pid], stderr_to_stdout: true), 1) != 0 end,
             System.monotonic_time(:millisecond) + 1_500
           )

    File.rm!(path)
  end

  defp wait_until(predicate, deadline) do
    cond do
      predicate.() ->
        true

      System.monotonic_time(:millisecond) >= deadline ->
        false

      true ->
        receive do
        after
          10 -> wait_until(predicate, deadline)
        end
    end
  end

  defp assert_no_port_messages do
    {:messages, messages} = Process.info(self(), :messages)

    refute Enum.any?(messages, fn
             {port, _} when is_port(port) -> true
             _ -> false
           end)
  end

  defp temp_path(label) do
    suffix = :crypto.strong_rand_bytes(12) |> Base.url_encode64(padding: false)
    Path.join(System.tmp_dir!(), "p815-#{label}-#{suffix}")
  end

  defp clean_pid_file(path) do
    case File.read(path) do
      {:ok, pid} -> System.cmd("kill", ["-KILL", String.trim(pid)], stderr_to_stdout: true)
      _ -> :ok
    end

    File.rm(path)
  end
end
