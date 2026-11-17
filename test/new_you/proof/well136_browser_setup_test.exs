defmodule NewYou.Proof.Well136BrowserSetupTest do
  use ExUnit.Case, async: false
  alias NewYou.Proof.Well136Browser

  test "failed evidence copy removes only its owned temporary directory" do
    Process.put({Well136Browser, :setup_checkpoint}, fn
      :evidence_directory_created, path ->
        Process.put(:well136_owned_directory, path)
        File.write!(Path.join(path, "docs"), "synthetic copy obstruction")
    end)

    try do
      assert_raise File.CopyError, fn -> Well136Browser.run("en") end
      path = Process.get(:well136_owned_directory)
      assert is_binary(path)
      refute File.exists?(path)
    after
      Process.delete({Well136Browser, :setup_checkpoint})
      if path = Process.delete(:well136_owned_directory), do: File.rm_rf!(path)
    end
  end

  test "failure after server startup stops that server and removes its evidence directory" do
    Process.put({Well136Browser, :setup_checkpoint}, fn
      :evidence_directory_created, path ->
        Process.put(:well136_owned_directory, path)

      :server_started, server ->
        Process.put(:well136_owned_server, server)
        raise "synthetic listener setup failure"
    end)

    try do
      assert_raise RuntimeError, "synthetic listener setup failure", fn ->
        Well136Browser.run("af")
      end

      server = Process.get(:well136_owned_server)
      assert is_pid(server)
      refute Process.alive?(server)
      refute File.exists?(Process.get(:well136_owned_directory))
    after
      Process.delete({Well136Browser, :setup_checkpoint})

      if server = Process.delete(:well136_owned_server) do
        if Process.alive?(server), do: Supervisor.stop(server)
      end

      if path = Process.delete(:well136_owned_directory), do: File.rm_rf!(path)
    end
  end
end
