defmodule NewYou.Content.RegistrationTest do
  use ExUnit.Case, async: false

  alias NewYou.Content.Registration

  @manifest_path "docs/delivery/content-evidence/content_media/LEGAL_BASELINE_CONTENT_MANIFEST_v0.1.0.json"
  @terms_path "docs/delivery/content-evidence/content_media/legal_baselines/NEWYOU-TERMS-EN-DEV-BASELINE-2026-10-27-001.html"
  @privacy_path "docs/delivery/content-evidence/content_media/legal_baselines/NEWYOU-PRIVACY-EN-DEV-BASELINE-2026-10-27-001.html"
  @expected_versions %{
    terms_version_id: "NEWYOU-TERMS-EN-DEV-2026-10-27-001",
    privacy_version_id: "NEWYOU-PRIVACY-EN-DEV-2026-10-27-001"
  }

  test "returns the configured current legal version pair and exact documents" do
    assert Registration.legal_versions() == {:ok, @expected_versions}
    assert Registration.legal_document(:terms) == {:ok, File.read!(@terms_path)}
    assert Registration.legal_document(:privacy) == {:ok, File.read!(@privacy_path)}
  end

  test "rejects a mismatched configured legal version pair" do
    previous = Application.fetch_env!(:new_you, :identity_registration_legal_versions)

    Application.put_env(:new_you, :identity_registration_legal_versions, %{
      terms_version_id: "wrong",
      privacy_version_id: @expected_versions.privacy_version_id
    })

    try do
      assert Registration.legal_versions() == {:error, :content_ineligible}
      assert Registration.legal_document(:terms) == {:error, :content_ineligible}
    after
      Application.put_env(:new_you, :identity_registration_legal_versions, previous)
    end
  end

  test "rejects unsupported document names" do
    assert Registration.legal_document(:other) == {:error, :content_ineligible}
  end

  test "rejects withdrawn, superseded, and ineligible manifest entries" do
    manifest = @manifest_path |> File.read!() |> Jason.decode!()
    terms_entry = Enum.find(manifest["versions"], &(&1["document_type"] == "terms"))
    body = File.read!(@terms_path)

    for changed <- [
          put_in(terms_entry, ["withdrawal", "status"], "WITHDRAWN"),
          put_in(terms_entry, ["supersession", "superseded_by"], "successor"),
          put_in(terms_entry, ["allowed_contexts"], ["production"]),
          Map.delete(terms_entry, "supersession"),
          Map.put(terms_entry, "effective_for_participants", true)
        ] do
      refute Registration.legal_baseline_valid?(:terms, changed, body)
    end
  end

  test "rejects changed artifact bytes" do
    manifest = @manifest_path |> File.read!() |> Jason.decode!()
    terms_entry = Enum.find(manifest["versions"], &(&1["document_type"] == "terms"))

    refute Registration.legal_baseline_valid?(:terms, terms_entry, File.read!(@terms_path) <> " ")
  end

  test "accepts the pinned context policy for both documents regardless of list order" do
    for {document, entry, body} <- legal_baselines() do
      assert Registration.legal_baseline_valid?(document, entry, body)

      reordered =
        entry
        |> Map.update!("allowed_contexts", &Enum.reverse/1)
        |> Map.update!("prohibited_contexts", &Enum.reverse/1)

      assert Registration.legal_baseline_valid?(document, reordered, body)
    end
  end

  test "rejects unexpected additional allowed contexts" do
    for {document, entry, body} <- legal_baselines(),
        context <- entry["prohibited_contexts"] ++ ["unapproved_development_context"] do
      changed = Map.update!(entry, "allowed_contexts", &(&1 ++ [context]))

      refute Registration.legal_baseline_valid?(document, changed, body),
             "#{document} admitted additional allowed context #{context}"
    end
  end

  test "rejects removal of each approved development context" do
    for {document, entry, body} <- legal_baselines(), context <- entry["allowed_contexts"] do
      changed = Map.update!(entry, "allowed_contexts", &List.delete(&1, context))

      refute Registration.legal_baseline_valid?(document, changed, body),
             "#{document} admitted policy without development context #{context}"
    end
  end

  test "rejects removal of each mandatory prohibited context" do
    for {document, entry, body} <- legal_baselines(), context <- entry["prohibited_contexts"] do
      changed = Map.update!(entry, "prohibited_contexts", &List.delete(&1, context))

      refute Registration.legal_baseline_valid?(document, changed, body),
             "#{document} admitted policy without prohibited context #{context}"
    end
  end

  test "rejects a development context that is also prohibited" do
    for {document, entry, body} <- legal_baselines(), context <- entry["allowed_contexts"] do
      changed = Map.update!(entry, "prohibited_contexts", &(&1 ++ [context]))

      refute Registration.legal_baseline_valid?(document, changed, body),
             "#{document} admitted contradictory context #{context}"
    end
  end

  test "rejects unexpected prohibited contexts" do
    for {document, entry, body} <- legal_baselines() do
      changed = Map.update!(entry, "prohibited_contexts", &(&1 ++ ["unknown_context"]))

      refute Registration.legal_baseline_valid?(document, changed, body)
    end
  end

  test "rejects missing, malformed and duplicate context-policy metadata" do
    for {document, entry, body} <- legal_baselines(),
        field <- ["allowed_contexts", "prohibited_contexts"] do
      refute Registration.legal_baseline_valid?(document, Map.delete(entry, field), body)

      for value <- [nil, "local_development", %{}, [], true, 1, [nil], [["local_development"]]] do
        refute Registration.legal_baseline_valid?(document, Map.put(entry, field, value), body),
               "#{document} admitted malformed #{field}: #{inspect(value)}"
      end

      for extra <- [nil, 1, %{}, ["local_development"], hd(entry[field])] do
        changed = Map.update!(entry, field, &(&1 ++ [extra]))

        refute Registration.legal_baseline_valid?(document, changed, body),
               "#{document} admitted invalid #{field} entry: #{inspect(extra)}"
      end
    end
  end

  defp legal_baselines do
    manifest = @manifest_path |> File.read!() |> Jason.decode!()

    for {document, path} <- [terms: @terms_path, privacy: @privacy_path] do
      entry = Enum.find(manifest["versions"], &(&1["document_type"] == Atom.to_string(document)))
      {document, entry, File.read!(path)}
    end
  end
end
