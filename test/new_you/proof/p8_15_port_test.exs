defmodule NewYou.Proof.P815PortTest do
  use ExUnit.Case, async: true

  alias NewYou.Proof.P815Port

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

  test "reports a deadline without accepting a late marker" do
    path = Path.join(System.tmp_dir!(), "p815-pid-#{System.unique_integer([:positive])}")
    on_exit(fn -> File.rm(path) end)

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
    path = Path.join(System.tmp_dir!(), "p815-descendant-#{System.unique_integer([:positive])}")

    on_exit(fn ->
      case File.read(path) do
        {:ok, pid} -> System.cmd("kill", ["-KILL", String.trim(pid)], stderr_to_stdout: true)
        _ -> :ok
      end

      File.rm(path)
    end)

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

  defp assert_no_port_messages do
    {:messages, messages} = Process.info(self(), :messages)

    refute Enum.any?(messages, fn
             {port, _} when is_port(port) -> true
             _ -> false
           end)
  end
end
