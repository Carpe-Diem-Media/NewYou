defmodule NewYou.Content.PasswordResetBrowserCopyTest do
  use ExUnit.Case, async: false

  alias NewYou.Content.PasswordResetBrowserCopy

  test "all 23 approved bilingual keys have exact UTF-8 byte and digest bindings" do
    path = "docs/development/fixtures/well136-c02-v0.1.json"
    artifact = path |> File.read!() |> Jason.decode!()
    assert map_size(artifact["entries"]) == 23
    assert PasswordResetBrowserCopy.available?()

    for {key, entry} <- artifact["entries"], locale <- ["en", "af"] do
      text = PasswordResetBrowserCopy.text!(key, locale)
      assert text == entry[locale]["text"]
      assert NewYouWeb.PasswordResetCopy.text!(key, locale, :well136) == text
      assert byte_size(text) == entry[locale]["bytes"]
      assert Base.encode16(:crypto.hash(:sha256, text), case: :lower) == entry[locale]["sha256"]
    end

    assert_raise ArgumentError, fn ->
      PasswordResetBrowserCopy.text!("identity.login.submit", "zu")
    end

    assert_raise KeyError, fn -> PasswordResetBrowserCopy.text!("unknown.key", "en") end
  end

  test "copy withdrawal, changed bytes and production compilation deny consumption" do
    root = Path.join(System.tmp_dir!(), "well136-copy-#{Ecto.UUID.generate()}")
    fixtures = Path.join(root, "docs/development/fixtures")
    File.mkdir_p!(fixtures)

    for name <- ["well136-c02-v0.1.json", "well136-c02-owner-approval.json"],
        do: File.cp!(Path.join("docs/development/fixtures", name), Path.join(fixtures, name))

    module = Module.concat(__MODULE__, "Isolated#{System.unique_integer([:positive])}")

    source =
      File.read!("lib/new_you/content/password_reset_browser_copy.ex")
      |> String.replace(
        "defmodule NewYou.Content.PasswordResetBrowserCopy do",
        "defmodule #{inspect(module)} do"
      )

    source_path = Path.join(root, "lib/new_you/content/password_reset_browser_copy.ex")
    environment = Mix.env()

    try do
      Code.compile_string(source, source_path)
      assert module.available?()

      for name <- ["well136-c02-v0.1.json", "well136-c02-owner-approval.json"] do
        path = Path.join(fixtures, name)
        original = File.read!(path)

        for state <- ["withdrawn", "superseded"] do
          File.write!(path, Jason.encode!(Map.put(Jason.decode!(original), "status", state)))
          refute module.available?()

          assert_raise Module.concat(module, UnavailableError), fn ->
            module.text!("identity.login.forgot_password", "en")
          end
        end

        File.rm!(path)
        refute module.available?()
        File.write!(path, original)
        assert module.available?()
      end

      :code.purge(module)
      :code.delete(module)
      :code.purge(Module.concat(module, UnavailableError))
      :code.delete(Module.concat(module, UnavailableError))
      Mix.env(:prod)
      compiled = Code.compile_string(source, source_path)
      artifact = Path.join(fixtures, "well136-c02-v0.1.json") |> File.read!() |> Jason.decode!()

      forbidden =
        [artifact["version"], artifact["source_packet_sha256"] | artifact["approval_comments"]] ++
          Map.keys(artifact["entries"]) ++
          Enum.map(["well136-c02-v0.1.json", "well136-c02-owner-approval.json"], fn file ->
            Path.join(fixtures, file)
            |> File.read!()
            |> then(&:crypto.hash(:sha256, &1))
            |> Base.encode16(case: :lower)
          end) ++
          for {_key, entry} <- artifact["entries"],
              locale <- ["en", "af"],
              value <- ["text", "sha256"],
              do: entry[locale][value]

      for {_compiled_module, beam} <- compiled do
        # Decode actual literal/debug/documentation terms using the pinned OTP
        # reader. A raw byte search can miss compressed BEAM chunks.
        assert {:ok, {_, chunks}} =
                 :beam_lib.chunks(beam, [:literals, :debug_info, :attributes, :documentation], [
                   :allow_missing_chunks
                 ])

        payload = :erlang.term_to_binary(chunks)

        for text <- forbidden do
          refute :binary.match(payload, text) != :nomatch,
                 "production BEAM embeds approved C-02 content: #{text}"
        end
      end

      refute module.available?()
      assert is_nil(module.artifact_path())
      refute module.valid_artifact?(artifact)

      assert_raise Module.concat(module, UnavailableError), fn ->
        module.text!("identity.login.forgot_password", "en")
      end
    after
      Mix.env(environment)
      :code.purge(module)
      :code.delete(module)
      :code.purge(Module.concat(module, UnavailableError))
      :code.delete(Module.concat(module, UnavailableError))
      File.rm_rf!(root)
    end
  end
end
