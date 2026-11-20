defmodule NewYou.LocalSessionTest do
  use ExUnit.Case, async: false

  test "automatic local admission preserves worktree and process ownership" do
    {output, status} =
      System.cmd("python3", ["-m", "unittest", "tests.test_local_session", "-v"],
        cd: File.cwd!(),
        stderr_to_stdout: true
      )

    assert status == 0, output
  end
end
