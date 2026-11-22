defmodule NewYou.Content.SessionManagementCopyTest do
  use ExUnit.Case, async: true

  alias NewYou.Content.SessionManagementCopy

  @router "docs/delivery/CURRENT_DELIVERY_ROUTER.json"
  @id "FP001_SESSION_AND_TRUSTED_DEVICE_BROWSER_COPY_APPROVED"

  test "loads exact eligible Session keys in both locales and excludes global and trusted-device copy" do
    entries = router()["delivery_contracts"]
    entry = Enum.find(entries, &(&1["document_id"] == @id))
    items = File.read!(entry["repository_path"]) |> Jason.decode!() |> Map.fetch!("copy_items")

    for locale <- ~w(en af) do
      assert {:ok, text} = SessionManagementCopy.load(locale)
      assert map_size(text) == 22

      for {key, value} <- text do
        assert String.starts_with?(key, "identity.sessions.")
        refute String.starts_with?(key, "identity.sessions.all.")
        item = Enum.find(items, &(&1["key"] == key))
        assert value == item[locale]["text"]
      end
    end

    assert {:error, :content_ineligible} = SessionManagementCopy.load("de")
  end

  test "fails closed for withdrawn, superseded or conflicting routing and tampered packet bytes" do
    current = router()

    for status <- ["WITHDRAWN", "SUPERSEDED"] do
      updated = update_entries(current, &Map.put(&1, "status", status))

      assert {:error, :content_ineligible} =
               SessionManagementCopy.load_for_proof("af", reader(updated))
    end

    entry = Enum.find(current["delivery_contracts"], &(&1["document_id"] == @id))
    conflicting = Map.update!(current, "delivery_contracts", &[entry | &1])

    assert {:error, :content_ineligible} =
             SessionManagementCopy.load_for_proof("en", reader(conflicting))

    assert {:error, :content_ineligible} =
             SessionManagementCopy.load_for_proof("en", fn
               @router -> File.read(@router)
               path -> {:ok, File.read!(path) <> "\n"}
             end)
  end

  defp router, do: File.read!(@router) |> Jason.decode!()

  defp update_entries(router, update) do
    Map.update!(router, "delivery_contracts", fn entries ->
      Enum.map(entries, fn
        %{"document_id" => @id} = entry -> update.(entry)
        entry -> entry
      end)
    end)
  end

  defp reader(router) do
    fn
      @router -> {:ok, Jason.encode!(router)}
      path -> File.read(path)
    end
  end
end
