defmodule NewYouWeb.Well136BrowserTest do
  use ExUnit.Case, async: false

  @tag timeout: 120_000
  test "ordinary EN and AF browser journeys use real delivery and fresh sign-in" do
    for locale <- ["en", "af"] do
      NewYou.Proof.Well136Browser.run(locale)
    end
  end
end
