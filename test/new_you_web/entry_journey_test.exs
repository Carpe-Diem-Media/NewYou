defmodule NewYouWeb.EntryJourneyTest do
  use ExUnit.Case, async: false

  alias NewYou.Proof.EntryJourney

  test "English ordinary entry registers and verifies without creating a session" do
    EntryJourney.run("en")
  end

  test "Afrikaans ordinary entry registers and verifies without creating a session" do
    EntryJourney.run("af")
  end
end
