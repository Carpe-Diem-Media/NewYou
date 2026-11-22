defmodule NewYouWeb.Well183BrowserTest do
  use ExUnit.Case, async: false

  for locale <- ["en", "af"] do
    @locale locale
    @tag timeout: 120_000
    test "bounded #{@locale} browser Recovery with fresh sign-in" do
      NewYou.Proof.Well183Browser.run(@locale)
    end
  end
end
