defmodule NewYouWeb.Well136BrowserTest do
  use ExUnit.Case, async: false

  for locale <- ["en", "af"] do
    @locale locale
    @tag timeout: 120_000
    test "ordinary #{@locale} browser journey uses real delivery and fresh sign-in" do
      NewYou.Proof.Well136Browser.run(@locale)
    end
  end

  @tag timeout: 120_000
  test "browser failure reports its source checkpoint when ordinary entry is unavailable" do
    Process.put({NewYou.Proof.Well136Browser, :setup_checkpoint}, fn
      :server_started, _ -> Application.put_env(:new_you, :fp001_development_entry, false)
      _, _ -> :ok
    end)

    try do
      error = assert_raise RuntimeError, fn -> NewYou.Proof.Well136Browser.run("en") end
      assert error.message =~ "browser.evaluation; checkpoint: reset.public_entry"
    after
      Process.delete({NewYou.Proof.Well136Browser, :setup_checkpoint})
    end
  end
end
