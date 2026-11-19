defmodule NewYou.Proof.BrowserProtocolTest do
  use ExUnit.Case, async: true

  test "browser protocol races retain navigation and cleanup proof" do
    executable = System.find_executable("node") || flunk("proof browser requires Node")

    {output, status} =
      System.cmd(
        executable,
        [
          "--test",
          "test/proof/browser_protocol_test.mjs",
          "test/proof/reset_request_checkpoints_test.mjs"
        ], stderr_to_stdout: true)

    assert status == 0, output
  end

  test "browser failures identify an allowed checkpoint without returning private diagnostics" do
    message =
      browser_failure(%{
        "failure" => "browser.evaluation",
        "checkpoint" => "reset.public_entry",
        "checks" => %{"private-value" => "sensitive fixture value"},
        "raw_error" => "sensitive browser error"
      })

    assert message =~ "browser.evaluation; checkpoint: reset.public_entry"
    refute message =~ "sensitive"
    refute message =~ "private-value"
  end

  for checkpoint <- ~w(reset.request_layout reset.request_labels reset.request_stylesheet) do
    test "request evaluation failure retains #{checkpoint} without private diagnostics" do
      message =
        browser_failure(%{
          "failure" => "browser.evaluation",
          "checkpoint" => unquote(checkpoint),
          "raw_error" => "synthetic-private-canary"
        })

      assert message ==
               "proof browser failed with bounded diagnostic: browser.evaluation; checkpoint: " <>
                 unquote(checkpoint)

      refute message =~ "synthetic-private-canary"
    end
  end

  test "unapproved checkpoint text never enters browser failure messages" do
    message =
      browser_failure(%{
        "failure" => "browser.evaluation",
        "checkpoint" => "sensitive unapproved checkpoint"
      })

    assert message == "proof browser failed with bounded diagnostic: browser.evaluation"
  end

  defp browser_failure(result) do
    root = Path.join(System.tmp_dir!(), "well136-protocol-#{Ecto.UUID.generate()}")
    File.mkdir!(root)

    try do
      script = Path.join(root, "failure.mjs")
      File.write!(script, "process.stdout.write(" <> Jason.encode!(Jason.encode!(result)) <> ");")

      error =
        assert_raise RuntimeError, fn ->
          NewYou.Proof.P805Browser.run_port(System.find_executable("node"), script, "{}")
        end

      error.message
    after
      File.rm_rf!(root)
    end
  end
end
