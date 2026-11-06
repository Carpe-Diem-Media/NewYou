defmodule NewYou.Proof.BrowserProtocolTest do
  use ExUnit.Case, async: true

  test "browser protocol races retain navigation and cleanup proof" do
    executable = System.find_executable("node") || flunk("proof browser requires Node")

    {output, status} =
      System.cmd(executable, ["--test", "test/proof/browser_protocol_test.mjs"],
        stderr_to_stdout: true
      )

    assert status == 0, output
  end
end
