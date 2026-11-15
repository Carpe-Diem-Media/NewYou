defmodule NewYou.Proof.TB001IntegrationTest do
  use ExUnit.Case, async: false

  alias NewYou.Proof.Catalog

  @tag timeout: 120_000
  test "standalone canonical acceptance rejects removed and substituted obligations" do
    for mutation <- ["drop", "substitute", "authority"] do
      output = Path.join(System.tmp_dir!(), "tb001-inventory-#{Ecto.UUID.generate()}.json")
      on_exit(fn -> File.rm(output) end)

      {stdout, status} =
        System.cmd(
          System.find_executable("mix"),
          ["run", "test/proof/tb001_inventory_broken.exs", mutation, output],
          env: [{"MIX_ENV", "test"}, {"ERL_FLAGS", "+S 2:2"}],
          stderr_to_stdout: true
        )

      assert status in [1, 2], stdout
      artifact = output |> File.read!() |> Jason.decode!()
      assert artifact["mode"] == "tb001"
      assert artifact["overall_verdict"] == "FAIL"

      family =
        Enum.find(artifact["results"], &(&1["coverage_id"] == "registration_pmr_reconciliation"))

      assert family["verdict"] == "FAIL"
      assert "manifest.partial" in family["reason_codes"]
      assert "registration.invalid" in family["reason_codes"]
      assert Enum.all?(family["cases"], &(&1["assertions_executed"] == 0))
      # A fresh unmodified validator also rejects the mutated declaration's
      # digest and required IDs, independently of its nonzero command outcome.
      assert {:error, errors} = NewYou.Proof.Result.validate(artifact, mode: :tb001)
      assert :invalid_business_manifest_digest in errors
      if mutation != "authority", do: assert(:invalid_business_required_cases in errors)
    end
  end

  @tag :inventory_identity
  test "deleting or substituting a declared P8-19 obligation leaves its family partial" do
    source = File.read!("test/support/proof/p8_19_catalog.ex")
    previous = Code.compiler_options(ignore_module_conflict: true)

    try do
      for mutation <- [:drop, :substitute, :authority] do
        ast = Code.string_to_quoted!(source)

        damaged =
          Macro.prewalk(ast, fn
            {:@, meta, [{:required_inventory, attribute_meta, [value]}]}
            when mutation == :authority ->
              damaged =
                quote do: Map.put(unquote(value), "source_sha256", String.duplicate("0", 64))

              {:@, meta, [{:required_inventory, attribute_meta, [damaged]}]}

            {:@, meta, [{:obligations, attribute_meta, [[first | rest]]}]}
            when mutation != :authority ->
              obligations =
                case mutation do
                  :drop ->
                    rest

                  :substitute ->
                    [
                      Macro.prewalk(first, fn
                        "p819.reconciliation_apply" -> "p819.unreviewed_substitution"
                        value -> value
                      end)
                      | rest
                    ]
                end

              {:@, meta, [{:obligations, attribute_meta, [obligations]}]}

            node ->
              node
          end)

        Code.compile_quoted(damaged, Path.expand("test/support/proof/p8_19_catalog.ex"))
        manifest = Catalog.required().business_manifests["registration_pmr_reconciliation"]
        assert manifest.scope == :partial, "#{mutation} must fail independent inventory"
      end
    after
      Code.compile_string(source, Path.expand("test/support/proof/p8_19_catalog.ex"))
      Code.compiler_options(previous)
    end
  end

  test "loss of reviewed upstream coverage leaves the affected family partial" do
    upstream =
      NewYou.Proof.P805Catalog.manifests()
      |> Map.merge(NewYou.Proof.P807Catalog.manifests())
      |> Map.merge(NewYou.Proof.P809Catalog.manifests())
      |> Map.merge(NewYou.Proof.P809MagicCatalog.manifests())
      |> Map.merge(NewYou.Proof.P812Catalog.manifests())
      |> Map.merge(NewYou.Proof.P811Catalog.manifests())
      |> Map.merge(NewYou.Proof.P813Catalog.manifests())
      |> Map.merge(NewYou.Proof.P818Catalog.manifests())

    for {family, manifest} <- upstream do
      damaged = Map.put(upstream, family, %{manifest | cases: tl(manifest.cases)})
      assert NewYou.Proof.P819Catalog.manifests(damaged)[family].scope == :partial
    end
  end

  @tag timeout: 120_000
  test "an isolated broken full-proof callback exits nonzero with family and cut identity" do
    output = Path.join(System.tmp_dir!(), "tb001-broken-#{Ecto.UUID.generate()}.json")
    on_exit(fn -> File.rm(output) end)

    # Inherit the parent's selected runtime and TEST environment, as restart
    # probes do. Hosted setup-beam runners do not require a workstation CLI.
    executable = System.find_executable("mix") || raise "mix unavailable"

    {stdout, status} =
      System.cmd(executable, ["run", "test/proof/tb001_broken.exs", output],
        env: [{"MIX_ENV", "test"}, {"ERL_FLAGS", "+S 2:2"}],
        stderr_to_stdout: true
      )

    assert status in [1, 2], stdout
    artifact = output |> File.read!() |> Jason.decode!()
    assert artifact["mode"] == "tb001"
    assert artifact["overall_verdict"] == "FAIL"
    assert artifact["exit_code"] == status

    family =
      Enum.find(artifact["results"], &(&1["coverage_id"] == "registration_pmr_reconciliation"))

    broken = Enum.find(family["cases"], &(&1["case_id"] == "p805.post_commit_recovery"))
    assert broken["verdict"] == "FAIL"
    assert broken["invariant_id"] == "p805.post_commit_recovery"
    assert broken["cut_point"] == "transaction.after_commit"
    assert "assertion.failed" in broken["reason_codes"]
    assert artifact["cleanup"]["verdict"] == "PASS"
    assert :ok = NewYou.Proof.Result.validate(artifact, mode: :tb001)
    if status == 2, do: assert("source.dirty" in artifact["reason_codes"])
  end

  test "the reviewed TB-001 catalog compiles every required family and callback" do
    manifests = Catalog.required().business_manifests
    registrations = Catalog.compiled_business_registrations()
    inventory = File.read!("test/proof/tb001_required_cases.json") |> Jason.decode!()

    assert inventory["contract"] == "TB-001/v0.1.3"

    assert inventory["source_sha256"] ==
             Base.encode16(:crypto.hash(:sha256, File.read!(inventory["source"])), case: :lower)

    assert Enum.sort(Map.keys(inventory["families"])) == Enum.sort(Catalog.coverage_inventory())

    for {family, manifest} <- manifests do
      assert Enum.sort(Enum.map(manifest.cases, &[&1.case_id, &1.invariant_id])) ==
               Enum.sort(inventory["families"][family]["cases"])
    end

    assert Enum.sort(Map.keys(manifests)) == Enum.sort(Catalog.coverage_inventory())
    assert Enum.all?(manifests, fn {_, manifest} -> manifest.scope == :complete end)
    assert :ok = Catalog.validate_compiled_registrations(manifests, registrations)

    assert %{errors: [], missing_cases: [], missing_families: []} =
             Catalog.validate_registrations(registrations, :tb001)

    expected =
      for {family, manifest} <- manifests,
          entry <- manifest.cases,
          do: {family, entry.case_id, entry.invariant_id}

    assert Enum.sort(expected) ==
             Enum.sort(Enum.map(registrations, &{&1.coverage_id, &1.case_id, &1.invariant_id}))

    assert Enum.all?(registrations, &is_function(&1.callback, 0))
  end

  test "removing any compiled required callback is a registration failure" do
    registrations = Catalog.compiled_business_registrations()

    for registration <- registrations do
      result = Catalog.validate_registrations(List.delete(registrations, registration), :tb001)
      assert registration.case_id in result.missing_cases
      assert :missing_case in result.errors
    end
  end
end
