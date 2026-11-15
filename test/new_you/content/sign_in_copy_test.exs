defmodule NewYou.Content.SignInCopyTest do
  use ExUnit.Case, async: true

  alias NewYou.Content.SignInCopy

  test "only the exact owner-approved bilingual development version is eligible" do
    assert SignInCopy.available?()
    assert SignInCopy.text!("identity.login.title", "en") == "Log in to your account"
    assert SignInCopy.text!("identity.login.title", "af") == "Meld aan by jou rekening"
    assert SignInCopy.text!("shared.navigation.logout", "af") == "Meld af"

    assert_raise KeyError, fn -> SignInCopy.text!("identity.login.unverified", "en") end
    assert_raise ArgumentError, fn -> SignInCopy.text!("identity.login.title", "nl") end
  end

  test "a changed locale, approval, scope, lifecycle or source digest cannot acquire eligibility" do
    bytes = File.read!(SignInCopy.artifact_path())
    approved = Jason.decode!(bytes)
    assert SignInCopy.valid_artifact?(approved)

    candidates = [
      put_in(approved, ["status"], "withdrawn"),
      put_in(approved, ["status"], "superseded"),
      put_in(approved, ["approval", "comment_id"], Ecto.UUID.generate()),
      put_in(approved, ["approval", "canonical_payload_sha256"], String.duplicate("0", 64)),
      put_in(approved, ["allowed_contexts"], ["production"]),
      put_in(approved, ["prohibited_contexts"], []),
      put_in(approved, ["entries", "identity.login.title", "af", "text"], "Teken in"),
      update_in(approved, ["entries", "identity.login.title"], &Map.delete(&1, "af")),
      Map.delete(approved, "version_id")
    ]

    for candidate <- candidates do
      refute SignInCopy.valid_artifact?(candidate)
    end
  end

  test "all locale strings retain the literal owner table bytes and individual digests" do
    approved = SignInCopy.artifact_path() |> File.read!() |> Jason.decode!()

    source =
      "docs/development/fixtures/well134-c01-owner-approval.json"
      |> File.read!()
      |> Jason.decode!()

    rows = source["comment_html"] |> LazyHTML.from_document() |> LazyHTML.query("tbody tr")
    assert Enum.count(rows) == 37

    keys =
      Enum.map(rows, fn row ->
        [_journey, key, en, af, _security] =
          row |> LazyHTML.query("td") |> Enum.map(&LazyHTML.text/1)

        for {locale, expected} <- [{"en", en}, {"af", af}] do
          entry = approved["entries"][key][locale]
          assert entry["text"] == expected
          assert entry["bytes"] == byte_size(expected)
          assert entry["sha256"] == Base.encode16(:crypto.hash(:sha256, expected), case: :lower)
          assert SignInCopy.text!(key, locale) == expected
        end

        key
      end)

    assert Enum.sort(Enum.uniq(keys)) == Enum.sort(Map.keys(approved["entries"]))
  end
end
