defmodule NewYou.Proof.RunnerTest do
  use ExUnit.Case, async: false

  alias NewYou.Proof.{Catalog, Result, Runner, Scenario, SelfTest}

  test "proof support scripts are not rediscovered as ExUnit test files" do
    config = Mix.Project.config()
    [load_test?] = Keyword.fetch!(config, :test_load_filters)
    [ignore_support] = Keyword.fetch!(config, :test_ignore_filters)

    for path <- Path.wildcard("test/proof/**/*.exs") do
      refute load_test?.(path), path
      assert Regex.match?(ignore_support, path), path
    end

    for path <- Path.wildcard("test/**/*_test.exs") -- ["test/proof/self_test.exs"] do
      assert load_test?.(path), path
      refute Regex.match?(ignore_support, path), path
    end
  end

  test "partial mappings cannot certify a family even when every case and other family passes" do
    for family <- Map.keys(Catalog.required().business_manifests) do
      manifests = full_fixture_manifests()
      manifests = put_in(manifests[family][:scope], :partial)
      result = evaluate_full_fixture(manifests, full_fixture_cases(manifests))
      entry = Enum.find(result.entries, &(&1.coverage_id == family))
      assert Enum.all?(entry.cases, &(&1.verdict == "PASS"))
      assert entry.verdict == "FAIL"
      assert "manifest.partial" in entry.reason_codes
      assert result.verdict == "FAIL"
      assert result.exit_code == 1
    end
  end

  test "a mapping without explicit completeness scope fails closed" do
    manifests = full_fixture_manifests()
    family = hd(Catalog.coverage_inventory())
    manifests = Map.update!(manifests, family, &Map.delete(&1, :scope))
    result = evaluate_full_fixture(manifests, full_fixture_cases(manifests))
    assert result.verdict == "FAIL"
  end

  test "CLI parsing accepts the approved modes and requires an output path" do
    for {mode, expected} <- [
          {"harness_self_test", :harness_self_test},
          {"tb001", :tb001},
          {"diagnostic", :diagnostic}
        ] do
      assert {:ok, %{mode: ^expected, output: "/tmp/proof.json", case_ids: []}} =
               Runner.parse_args(["--mode", mode, "--output", "/tmp/proof.json"])
    end

    assert {:error, :output_required} = Runner.parse_args(["--mode", "tb001"])

    assert {:error, :invalid_mode} =
             Runner.parse_args(["--mode", "phase9", "--output", "/tmp/proof.json"])
  end

  test "diagnostic selection is explicit and cannot name an unapproved case" do
    case_id = hd(Catalog.required().self_test.cases).case_id

    assert {:ok, %{mode: :diagnostic, case_ids: [^case_id]}} =
             Runner.parse_args([
               "--mode",
               "diagnostic",
               "--output",
               "/tmp/proof.json",
               "--case",
               case_id
             ])

    assert {:error, :unknown_case} =
             Runner.parse_args([
               "--mode",
               "diagnostic",
               "--output",
               "/tmp/proof.json",
               "--case",
               "phase9.business"
             ])
  end

  test "fixture selection is allowlisted for one diagnostic invariant only" do
    case_id = "cut.raise.transaction.before_commit"

    assert {:ok, %{fixture: :broken_invariant}} =
             Runner.parse_args([
               "--mode",
               "diagnostic",
               "--output",
               "/tmp/proof.json",
               "--case",
               case_id,
               "--fixture",
               "broken_invariant"
             ])

    assert {:error, :invalid_fixture} =
             Runner.parse_args([
               "--mode",
               "diagnostic",
               "--output",
               "/tmp/proof.json",
               "--case",
               case_id,
               "--fixture",
               "unapproved"
             ])

    assert {:error, :invalid_fixture} =
             Runner.parse_args([
               "--mode",
               "tb001",
               "--output",
               "/tmp/proof.json",
               "--fixture",
               "broken_invariant"
             ])
  end

  test "broken invariant probe records nested CLI exit and manifest identity" do
    output =
      Path.join(
        System.tmp_dir!(),
        "proof-broken-invariant-#{System.unique_integer([:positive])}.json"
      )

    on_exit(fn -> File.rm(output) end)

    case_id = "result.broken_invariant_exit"

    {stdout, exit_code} =
      System.cmd(
        "mix",
        [
          "run",
          "test/proof/run.exs",
          "--mode",
          "diagnostic",
          "--output",
          output,
          "--case",
          case_id
        ],
        stderr_to_stdout: true,
        env: [{"MIX_ENV", "test"}]
      )

    assert exit_code == 0, stdout
    assert {:ok, artifact} = output |> File.read!() |> Jason.decode()

    [entry] = artifact["results"]
    [case_result] = entry["cases"]

    assert artifact["mode"] == "diagnostic"
    assert artifact["overall_verdict"] == "PASS"
    assert case_result["case_id"] == case_id
    assert case_result["invariant_id"] == case_id
    assert case_result["cut_point"] == nil
    assert case_result["verdict"] == "PASS"
    assert %{"code" => "broken_invariant.exit_code", "value" => 1} in case_result["observations"]

    assert %{
             "code" => "broken_invariant.case",
             "value" => "cut.raise.transaction.before_commit"
           } in case_result["observations"]

    assert %{
             "code" => "broken_invariant.invariant",
             "value" => "cut.raise.transaction.before_commit"
           } in case_result["observations"]

    assert %{
             "code" => "broken_invariant.cut_point",
             "value" => "transaction.before_commit"
           } in case_result["observations"]

    assert %{"code" => "broken_invariant.reason_code", "value" => "assertion.failed"} in case_result[
             "observations"
           ]
  end

  test "allowlisted broken invariant fixture publishes its failing cut identity" do
    output =
      Path.join(
        System.tmp_dir!(),
        "proof-broken-fixture-#{System.unique_integer([:positive])}.json"
      )

    on_exit(fn -> File.rm(output) end)

    case_id = "cut.raise.transaction.before_commit"

    {stdout, exit_code} =
      System.cmd(
        "mix",
        [
          "run",
          "test/proof/run.exs",
          "--mode",
          "diagnostic",
          "--output",
          output,
          "--case",
          case_id,
          "--fixture",
          "broken_invariant"
        ],
        stderr_to_stdout: true,
        env: [{"MIX_ENV", "test"}]
      )

    assert exit_code != 0, stdout
    assert {:ok, artifact} = output |> File.read!() |> Jason.decode()

    [entry] = artifact["results"]
    [case_result] = entry["cases"]

    assert artifact["mode"] == "diagnostic"
    assert artifact["overall_verdict"] == "FAIL"
    assert artifact["exit_code"] != 0
    assert case_result["case_id"] == case_id
    assert case_result["invariant_id"] == case_id
    assert case_result["cut_point"] == "transaction.before_commit"
    assert case_result["verdict"] == "FAIL"
    assert "assertion.failed" in case_result["reason_codes"]
  end

  test "canonical CLI reports exception, exit, throw and timeout fixture failures" do
    for {fixture, status, reason} <- [
          {"callback_exception", "error", "probe.failed"},
          {"callback_exit", "error", "probe.failed"},
          {"callback_throw", "error", "probe.failed"},
          {"callback_timeout", "timeout", "timeout.expired"}
        ] do
      output =
        Path.join(
          System.tmp_dir!(),
          "proof-#{fixture}-#{System.unique_integer([:positive])}.json"
        )

      on_exit(fn -> File.rm(output) end)

      {stdout, exit_code} = run_fixture_cli("result.callback_failures", fixture, output)

      expected_exit_code = if fixture == "callback_timeout", do: 2, else: 1
      assert exit_code == expected_exit_code, stdout
      refute String.contains?(stdout, "synthetic-secret-canary")
      assert {:ok, artifact} = output |> File.read!() |> Jason.decode()
      [entry] = artifact["results"]
      [case_result] = entry["cases"]
      assert artifact["overall_verdict"] == "FAIL"
      assert artifact["exit_code"] == expected_exit_code
      assert case_result["case_id"] == "result.callback_failures"
      assert case_result["invariant_id"] == "result.callback_failures"
      assert case_result["status"] == status
      assert reason in case_result["reason_codes"]
    end
  end

  test "timed-out callbacks cannot leave nested scenario controllers alive or report cleanup PASS" do
    parent = self()
    reference = make_ref()
    case_id = "result.callback_failures"

    callback = fn ->
      nested = Scenario.start()
      :erlang.suspend_process(nested.controller)

      child =
        spawn_link(fn ->
          receive do
            :release -> :ok
          end
        end)

      send(parent, {reference, nested.controller, child})
      Process.sleep(10_100)
      :ok
    end

    {[case_result], cleanup} =
      SelfTest.run([case_id], callback_overrides: %{case_id => callback})

    assert_receive {^reference, nested_controller, child}
    assert case_result["status"] == "timeout", inspect({case_result, cleanup})
    assert case_result["verdict"] == "FAIL"
    assert "timeout.expired" in case_result["reason_codes"]
    assert case_result["duration_ms"] >= case_result["timeout_ms"]

    try do
      assert cleanup["verdict"] == "FAIL"
      assert cleanup["workers_stopped"] == false
      refute Process.alive?(nested_controller)
      refute Process.alive?(child)
    after
      if Process.alive?(nested_controller), do: Process.exit(nested_controller, :kill)
    end
  end

  test "canonical CLI reports cleanup and output failures with exit 2" do
    cleanup_output =
      Path.join(
        System.tmp_dir!(),
        "proof-cleanup-failure-#{System.unique_integer([:positive])}.json"
      )

    on_exit(fn -> File.rm(cleanup_output) end)

    {cleanup_stdout, cleanup_exit} =
      run_fixture_cli("provider.authentication_fixtures", "cleanup_failure", cleanup_output)

    assert cleanup_exit == 2, cleanup_stdout
    assert {:ok, artifact} = cleanup_output |> File.read!() |> Jason.decode()
    assert artifact["overall_verdict"] == "FAIL"
    assert artifact["exit_code"] == 2
    assert artifact["cleanup"]["verdict"] == "FAIL"

    existing_output =
      Path.join(
        System.tmp_dir!(),
        "proof-existing-output-#{System.unique_integer([:positive])}.json"
      )

    File.write!(existing_output, "synthetic-secret-canary")
    on_exit(fn -> File.rm(existing_output) end)

    {output_stdout, output_exit} =
      run_fixture_cli("provider.authentication_fixtures", nil, existing_output)

    assert output_exit == 2
    assert byte_size(output_stdout) < 1_024
    assert String.ends_with?(output_stdout, "proof output failure\n")
    refute String.contains?(output_stdout, "synthetic-secret-canary")
    assert File.read!(existing_output) == "synthetic-secret-canary"
  end

  test "canonical TB-001 rejects a caller-supplied complete business catalog" do
    manifests = executable_fixture_manifests()
    registrations = executable_fixture_registrations(manifests)

    result =
      Runner.run(:tb001,
        business_manifests: manifests,
        business_registrations: registrations
      )

    assert result["overall_verdict"] == "FAIL"
    assert result["exit_code"] == 2
    assert "runner.unsupported_option" in result["reason_codes"]
    assert length(result["results"]) == length(Catalog.coverage_inventory())
    assert_unexecuted_business_inventory(result["results"])

    assert Enum.all?(
             Enum.reject(
               result["results"],
               &Map.has_key?(Catalog.required().business_manifests, &1["coverage_id"])
             ),
             &("missing.manifest" in &1["reason_codes"])
           )

    assert :ok = Result.validate(result, mode: :tb001)
  end

  test "canonical TB-001 rejects a business manifest override by itself" do
    result = Runner.run(:tb001, business_manifests: executable_fixture_manifests())

    assert result["exit_code"] == 2
    assert "runner.unsupported_option" in result["reason_codes"]
    assert_unexecuted_business_inventory(result["results"])
  end

  test "canonical TB-001 rejects business registrations by themselves" do
    manifests = executable_fixture_manifests()
    registrations = executable_fixture_registrations(manifests)

    result = Runner.run(:tb001, business_registrations: registrations)

    assert result["exit_code"] == 2
    assert "runner.unsupported_option" in result["reason_codes"]
    assert_unexecuted_business_inventory(result["results"])
  end

  test "canonical TB-001 rejects diagnostic-only and unknown runtime options" do
    for opts <- [
          [fixture: :broken_invariant],
          [case_ids: ["cut.raise.transaction.before_commit"]],
          [unreviewed_option: true]
        ] do
      result = Runner.run(:tb001, opts)

      assert result["exit_code"] == 2
      assert "runner.unsupported_option" in result["reason_codes"]
    end
  end

  test "canonical TB-001 rejects an alternate Git root and keeps executing-checkout metadata" do
    alternate_root = clean_git_root()
    on_exit(fn -> File.rm_rf(alternate_root) end)

    actual_root = Path.dirname(Mix.Project.project_file())
    {actual_sha, 0} = System.cmd("git", ["-C", actual_root, "rev-parse", "HEAD"])
    {alternate_sha, 0} = System.cmd("git", ["-C", alternate_root, "rev-parse", "HEAD"])

    result = Runner.run(:tb001, root: alternate_root)

    assert result["git"]["head_before"] == String.trim(actual_sha)
    refute result["git"]["head_before"] == String.trim(alternate_sha)
    assert result["exit_code"] == 2
    assert "runner.unsupported_option" in result["reason_codes"]
  end

  test "blanket assertion helpers are absent from the callback API" do
    Code.ensure_loaded!(SelfTest)

    refute function_exported?(SelfTest, :assert_manifest_pass, 0)
    refute function_exported?(SelfTest, :assert_manifest_assertion, 1)
  end

  test "a callback-returned PASS cannot satisfy missing manifest assertions" do
    coverage_id = hd(Catalog.coverage_inventory())
    case_id = "returned.pass.case"
    manifests = %{coverage_id => fixture_manifest(coverage_id, [case_id])}

    for callback <- [
          fn -> :PASS end,
          fn -> %{"verdict" => "PASS", "assertions_executed" => 1} end
        ] do
      registrations =
        register_fixture_callbacks(manifests, fn _coverage_id, _case_id -> callback end)

      {results, _cleanup} = Runner.execute_full_catalog(manifests, registrations)

      case_result =
        results
        |> Enum.find(&(&1["coverage_id"] == coverage_id))
        |> Map.fetch!("cases")
        |> Enum.find(&(&1["case_id"] == case_id))

      assert case_result["verdict"] == "FAIL"
      assert "assertion.missing" in case_result["reason_codes"]
    end
  end

  test "full evaluator exposes every unavailable family alongside owned P8-05 cases" do
    {results, cleanup} = Runner.execute_full_catalog(Catalog.required().business_manifests, [])
    result = Runner.evaluate_full(Catalog.required().business_manifests, [], true, cleanup)
    assert Enum.map(results, & &1["coverage_id"]) == Catalog.coverage_inventory()
    assert Enum.all?(results, &(&1["verdict"] == "FAIL"))

    unavailable =
      Enum.reject(
        results,
        &Map.has_key?(Catalog.required().business_manifests, &1["coverage_id"])
      )

    assert length(unavailable) == 6

    assert Enum.all?(
             unavailable,
             &(&1["status"] == "missing" and "missing.manifest" in &1["reason_codes"])
           )

    registration = Enum.find(results, &(&1["coverage_id"] == "registration_pmr_reconciliation"))
    assert hd(registration["cases"])["reason_codes"] == ["missing.case"]
    assert result.verdict == "FAIL"
    assert result.exit_code == 1
  end

  test "synthetic full-catalog executor can pass a complete registered fixture" do
    manifests = executable_fixture_manifests()
    registrations = executable_fixture_registrations(manifests)

    {results, cleanup} = Runner.execute_full_catalog(manifests, registrations)

    assert Enum.map(results, & &1["coverage_id"]) == Catalog.coverage_inventory()
    assert Enum.all?(results, &(&1["status"] == "completed"))
    assert Enum.all?(results, &(&1["verdict"] == "PASS"))
    assert cleanup["verdict"] == "PASS"

    assert Enum.all?(results, fn entry ->
             [case_result] = entry["cases"]
             case_result["assertions_executed"] == 1 and case_result["verdict"] == "PASS"
           end)
  end

  test "missing registration surfaces as missing case rather than executed registration failure" do
    coverage_id = hd(Catalog.coverage_inventory())
    case_ids = ["unregistered.case", "later.case"]

    manifests = %{
      coverage_id => fixture_manifest(coverage_id, case_ids)
    }

    registrations =
      register_fixture_callbacks(manifests, fn _coverage_id, _case_id ->
        fn -> SelfTest.expect_manifest!("later.case.verified", true, true) end
      end)

    registrations = Enum.reject(registrations, &(&1.case_id == "unregistered.case"))

    {results, _cleanup} = Runner.execute_full_catalog(manifests, registrations)

    entry = Enum.find(results, &(&1["coverage_id"] == coverage_id))
    [missing_case, later_case] = entry["cases"]

    assert entry["verdict"] == "FAIL"
    assert missing_case["status"] == "missing"
    assert "missing.case" in missing_case["reason_codes"]
    refute "registration.missing" in missing_case["reason_codes"]
    assert later_case["status"] == "not_run"
  end

  test "synthetic executor requires explicit observed values for every assertion" do
    coverage_id = hd(Catalog.coverage_inventory())
    assertion_ids = ["dual.alpha.verified", "dual.beta.verified"]

    manifests = %{
      coverage_id => fixture_manifest(coverage_id, ["dual.case"], assertion_ids: assertion_ids)
    }

    registrations =
      register_fixture_callbacks(manifests, fn _coverage_id, _case_id ->
        fn ->
          SelfTest.expect_manifest!(hd(assertion_ids), :observed_alpha, :observed_alpha)
          SelfTest.expect_manifest!(List.last(assertion_ids), :observed_beta, :observed_beta)
          :PASS
        end
      end)

    {results, cleanup} = Runner.execute_full_catalog(manifests, registrations)
    entry = Enum.find(results, &(&1["coverage_id"] == coverage_id))
    case_result = Enum.find(entry["cases"], &(&1["case_id"] == "dual.case"))

    assert case_result["verdict"] == "PASS"
    assert case_result["assertion_ids"] == assertion_ids
    assert case_result["assertions_executed"] == 2
    assert cleanup["verdict"] == "PASS"

    mutations = [
      fn -> SelfTest.expect_manifest!(hd(assertion_ids), :alpha, :alpha) end,
      fn -> SelfTest.expect_manifest!(List.last(assertion_ids), :beta, :beta) end,
      fn ->
        SelfTest.expect_manifest!(hd(assertion_ids), :wrong, :alpha)
        SelfTest.expect_manifest!(List.last(assertion_ids), :beta, :beta)
      end,
      fn ->
        SelfTest.expect_manifest!(hd(assertion_ids), :alpha, :alpha)
        SelfTest.expect_manifest!(List.last(assertion_ids), :wrong, :beta)
      end,
      fn ->
        SelfTest.expect_manifest!(hd(assertion_ids), :alpha, :alpha)
        SelfTest.expect_manifest!(hd(assertion_ids), :alpha, :alpha)
      end,
      fn ->
        SelfTest.expect_manifest!(hd(assertion_ids), :alpha, :alpha)
        SelfTest.expect_manifest!(List.last(assertion_ids), :beta, :beta)
        SelfTest.expect_manifest!("dual.gamma", :gamma, :gamma)
      end,
      fn ->
        SelfTest.expect_manifest!(hd(assertion_ids), :alpha, :alpha)
        throw(:callback_threw_after_first_assertion)
      end,
      fn -> :PASS end,
      fn -> %{"verdict" => "PASS", "assertions_executed" => 2} end
    ]

    for callback <- mutations do
      mutation_registrations =
        register_fixture_callbacks(manifests, fn _coverage_id, _case_id -> callback end)

      {mutation_results, _} = Runner.execute_full_catalog(manifests, mutation_registrations)

      mutation_case =
        mutation_results
        |> Enum.find(&(&1["coverage_id"] == coverage_id))
        |> Map.fetch!("cases")
        |> Enum.find(&(&1["case_id"] == "dual.case"))

      assert mutation_case["verdict"] == "FAIL"
    end
  end

  test "compiled registration validation fails closed on duplicate and unknown entries" do
    coverage_id = hd(Catalog.coverage_inventory())
    manifests = %{coverage_id => fixture_manifest(coverage_id, ["only.case"])}
    [registration] = register_fixture_callbacks(manifests, fn _, _ -> fn -> :ok end end)

    duplicate = [registration, registration]

    assert {:error, errors} = Catalog.validate_compiled_registrations(manifests, duplicate)
    assert :duplicate_case in errors

    unknown_case = Map.put(registration, :case_id, "unapproved.case")

    assert {:error, [:unknown_case]} =
             Catalog.validate_compiled_registrations(manifests, [unknown_case])

    unknown_family = Map.put(registration, :coverage_id, "unapproved_family")

    assert {:error, [:unknown_case]} =
             Catalog.validate_compiled_registrations(manifests, [unknown_family])

    {results, cleanup} = Runner.execute_full_catalog(manifests, duplicate)
    assert cleanup["verdict"] == "FAIL"
    assert Enum.any?(results, &("registration.invalid" in &1["reason_codes"]))
  end

  test "synthetic full executor stops at the first failed predicate and marks later work not_run" do
    [first_family, second_family | _rest] = Catalog.coverage_inventory()

    manifests = %{
      first_family =>
        fixture_manifest(first_family, ["first.case", "later.case"], timeout_ms: 10_000),
      second_family => fixture_manifest(second_family, ["second.case"], timeout_ms: 10_000)
    }

    registrations =
      register_fixture_callbacks(manifests, fn _coverage_id, case_id ->
        case case_id do
          "first.case" ->
            fn ->
              SelfTest.expect_manifest!("first.case.verified", :observed, :expected)
            end

          _ ->
            fn -> SelfTest.expect_manifest!(case_id <> ".verified", true, true) end
        end
      end)

    {results, cleanup} = Runner.execute_full_catalog(manifests, registrations)

    first_entry = Enum.find(results, &(&1["coverage_id"] == first_family))
    second_entry = Enum.find(results, &(&1["coverage_id"] == second_family))

    assert first_entry["verdict"] == "FAIL"
    first_case = Enum.find(first_entry["cases"], &(&1["case_id"] == "first.case"))
    assert first_case["verdict"] == "FAIL"
    assert "assertion.failed" in first_case["reason_codes"]
    assert cleanup["verdict"] == "PASS"

    assert Enum.find(first_entry["cases"], &(&1["case_id"] == "later.case"))["status"] ==
             "not_run"

    assert second_entry["status"] == "not_run"
    assert second_entry["verdict"] == "FAIL"
  end

  test "test-only full evaluator accepts a complete fixture without catalog business manifests" do
    manifests = full_fixture_manifests()
    cases = full_fixture_cases(manifests)

    result = evaluate_full_fixture(manifests, cases)

    assert result.verdict == "PASS"
    assert result.exit_code == 0
    assert Enum.map(result.entries, & &1.coverage_id) == Catalog.coverage_inventory()
    assert Enum.all?(result.entries, &(&1.status == "completed"))
    assert Enum.all?(result.entries, &(&1.verdict == "PASS"))
  end

  test "test-only full evaluator rejects missing cases and assertions" do
    manifests = full_fixture_manifests()
    cases = full_fixture_cases(manifests)
    first = hd(Catalog.coverage_inventory())

    missing_case = Enum.reject(cases, &(&1["coverage_id"] == first))
    missing_case_result = evaluate_full_fixture(manifests, missing_case)
    assert missing_case_result.verdict == "FAIL"
    assert missing_case_result.exit_code == 1

    missing_assertion =
      Enum.map(cases, fn case_result ->
        if case_result["coverage_id"] == first,
          do: %{case_result | "assertion_ids" => [], "assertions_executed" => 0},
          else: case_result
      end)

    missing_assertion_result = evaluate_full_fixture(manifests, missing_assertion)
    assert missing_assertion_result.verdict == "FAIL"
    assert missing_assertion_result.exit_code == 1
  end

  test "test-only full evaluator rejects duplicate cases and wrong invariants" do
    manifests = full_fixture_manifests()
    cases = full_fixture_cases(manifests)
    first = hd(cases)

    duplicate_result = evaluate_full_fixture(manifests, cases ++ [first])
    assert duplicate_result.verdict == "FAIL"
    assert duplicate_result.exit_code == 1

    wrong_invariant = [%{first | "invariant_id" => "forged.invariant"} | tl(cases)]
    invariant_result = evaluate_full_fixture(manifests, wrong_invariant)
    assert invariant_result.verdict == "FAIL"
    assert invariant_result.exit_code == 1
  end

  test "test-only full evaluator rejects observations for unknown coverage" do
    manifests = full_fixture_manifests()
    cases = full_fixture_cases(manifests)
    unexpected = observed_case("unapproved_family", "unapproved.case", "PASS", [])

    result = evaluate_full_fixture(manifests, cases ++ [unexpected])

    assert result.verdict == "FAIL"
    assert result.exit_code == 1
    assert Enum.any?(result.entries, &("case.unexpected" in &1.reason_codes))
  end

  test "test-only full evaluator rejects failed cases and missing families" do
    manifests = full_fixture_manifests()
    cases = full_fixture_cases(manifests)
    first = hd(cases)

    failed_case = %{
      first
      | "verdict" => "FAIL",
        "reason_codes" => ["assertion.failed"]
    }

    failed_result = evaluate_full_fixture(manifests, [failed_case | tl(cases)])
    assert failed_result.verdict == "FAIL"
    assert failed_result.exit_code == 1

    [missing_family | remaining_manifests] = Map.to_list(manifests)
    incomplete_manifests = Map.new(remaining_manifests)
    incomplete_result = evaluate_full_fixture(incomplete_manifests, cases)

    missing_entry =
      Enum.find(incomplete_result.entries, &(&1.coverage_id == elem(missing_family, 0)))

    assert incomplete_result.verdict == "FAIL"
    assert incomplete_result.exit_code == 1
    assert missing_entry.status == "missing"
    assert "missing.manifest" in missing_entry.reason_codes
  end

  test "test-only full evaluator returns exit 2 for metadata or cleanup failure" do
    manifests = full_fixture_manifests()
    cases = full_fixture_cases(manifests)

    metadata_result = evaluate_full_fixture(manifests, cases, false, clean_cleanup())
    assert metadata_result.verdict == "FAIL"
    assert metadata_result.exit_code == 2

    cleanup_result = evaluate_full_fixture(manifests, cases, true, failed_cleanup())
    assert cleanup_result.verdict == "FAIL"
    assert cleanup_result.exit_code == 2
  end

  test "test-only full evaluator rejects every unconfirmed cleanup resource" do
    manifests = full_fixture_manifests()
    cases = full_fixture_cases(manifests)

    for field <- ["workers_stopped", "connections_released", "locks_released"] do
      cleanup = Map.put(clean_cleanup(), field, false)
      result = evaluate_full_fixture(manifests, cases, true, cleanup)

      assert result.verdict == "FAIL"
      assert result.exit_code == 2
      assert "cleanup.failed" in result.reason_codes
    end
  end

  test "full evaluator preserves first case failure and marks later work not_run" do
    [first_family, second_family | missing_families] = Catalog.coverage_inventory()

    manifests = %{
      first_family => fixture_manifest(first_family, ["first.case", "later.case"]),
      second_family => fixture_manifest(second_family, ["second.family.case"])
    }

    cases = [
      observed_case(first_family, "first.case", "FAIL", ["assertion.failed"]),
      observed_case(first_family, "later.case", "PASS", []),
      observed_case(second_family, "second.family.case", "PASS", [])
    ]

    result = evaluate_full_fixture(manifests, cases)
    [first_result, second_result | remaining] = result.entries

    assert result.verdict == "FAIL"
    assert result.exit_code == 1
    assert hd(first_result.cases).verdict == "FAIL"
    assert Enum.at(first_result.cases, 1).status == "not_run"
    assert second_result.status == "not_run"
    assert hd(second_result.cases).status == "not_run"

    assert Enum.map(remaining, & &1.coverage_id) == missing_families
    assert Enum.all?(remaining, &(&1.status == "missing"))
  end

  test "self-test runner retains the first failed case and marks later selected cases not_run" do
    first_case = "cut.raise.transaction.before_commit"
    later_case = "cut.raise.transaction.after_commit"

    {[first, later], cleanup} =
      SelfTest.run([first_case, later_case], callback_overrides: %{first_case => fn -> :ok end})

    assert first["case_id"] == first_case
    assert first["verdict"] == "FAIL"
    assert "assertion.missing" in first["reason_codes"]
    assert later["case_id"] == later_case
    assert later["status"] == "not_run"
    assert cleanup["verdict"] == "PASS"
  end

  test "self-test records a failed controller reply as a passing fail-closed probe" do
    {[result], cleanup} = NewYou.Proof.SelfTest.run(["scenario.lost_reply"])

    assert result["status"] == "completed"
    assert result["verdict"] == "PASS"
    assert cleanup["verdict"] == "PASS"
    assert cleanup["workers_stopped"]
    assert cleanup["connections_released"]
    assert cleanup["locks_released"]
  end

  test "self-test confirms an intentional nested controller death before reporting cleanup PASS" do
    {[result], cleanup} = SelfTest.run(["scenario.controller_death"])

    assert result["status"] == "completed"
    assert result["verdict"] == "PASS"
    assert cleanup["verdict"] == "PASS"
    assert cleanup["workers_stopped"]
    assert cleanup["connections_released"]
    assert cleanup["locks_released"]
  end

  test "self-test confirms rollback after a PostgreSQL worker is killed" do
    {[result], cleanup} = NewYou.Proof.SelfTest.run(["db.worker_crash_cleanup"])

    assert result["status"] == "completed"
    assert result["verdict"] == "PASS"
    assert cleanup["verdict"] == "PASS"
    assert cleanup["workers_stopped"]
    assert cleanup["connections_released"]
    assert cleanup["locks_released"]
  end

  test "self-test observes fresh PostgreSQL ownership after worker replacement" do
    {[result], cleanup} = NewYou.Proof.SelfTest.run(["restart.fresh_connection"])

    assert result["status"] == "completed"
    assert result["verdict"] == "PASS"
    assert cleanup["verdict"] == "PASS"
    assert cleanup["workers_stopped"]
    assert cleanup["connections_released"]
    assert cleanup["locks_released"]
  end

  test "self-test rejects callback exceptions without exposing their canary" do
    {[result], cleanup} = NewYou.Proof.SelfTest.run(["result.callback_failures"])

    assert result["status"] == "completed"
    assert result["verdict"] == "PASS"
    assert cleanup["verdict"] == "PASS"
  end

  test "self-test cannot pass a callback that records no required assertion" do
    case_id = "cut.raise.transaction.before_commit"

    {[result], cleanup} =
      NewYou.Proof.SelfTest.run([case_id], callback_overrides: %{case_id => fn -> :ok end})

    assert result["verdict"] == "FAIL"
    assert result["assertion_ids"] == []
    assert "assertion.missing" in result["reason_codes"]
    assert cleanup["verdict"] == "PASS"
  end

  @tag timeout: 240_000
  test "production exclusion evidence comes from an isolated production build" do
    {[result], cleanup} = NewYou.Proof.SelfTest.run(["production.exclusion"])

    assert %{"code" => "production.build_succeeded", "value" => true} in result["observations"]
    assert %{"code" => "production.modules_absent", "value" => true} in result["observations"]

    assert %{"code" => "production.runtime_ineffective", "value" => true} in result[
             "observations"
           ]

    assert result["verdict"] == "PASS"
    assert cleanup["verdict"] == "PASS"
  end

  test "wrong worker cut-point probe records its required assertion" do
    {[result], cleanup} = NewYou.Proof.SelfTest.run(["cut.wrong_worker"])

    assert result["verdict"] == "PASS"
    assert result["assertion_ids"] == ["cut.wrong_worker.verified"]
    assert result["assertions_executed"] == 1
    assert cleanup["verdict"] == "PASS"
  end

  test "cleanup aggregation confirms the runner controller stopped after a simple probe" do
    {[result], cleanup} = NewYou.Proof.SelfTest.run(["provider.authentication_fixtures"])

    assert result["verdict"] == "PASS"
    assert cleanup["workers_stopped"]
    assert cleanup["verdict"] == "PASS"
  end

  test "database cleanup requires explicit connection and lock release evidence" do
    assert SelfTest.database_cleanup_observations({:ok, %{cleanup: %{confirmed: true}}}) == %{
             connections_released: true,
             locks_released: false
           }

    assert SelfTest.database_cleanup_observations({
             :ok,
             %{cleanup: %{confirmed: true, locks_remaining: 0, active_transactions: 0}}
           }) == %{
             connections_released: true,
             locks_released: true
           }

    assert SelfTest.database_cleanup_observations({
             :error,
             %{cleanup: %{confirmed: true, locks_remaining: 1, active_transactions: 0}}
           }) == %{
             connections_released: true,
             locks_released: false
           }
  end

  defp evaluate_full_fixture(
         manifests,
         cases,
         metadata_complete? \\ true,
         cleanup \\ clean_cleanup()
       ) do
    Code.ensure_loaded!(Runner)

    assert function_exported?(Runner, :evaluate_full, 4),
           "test-only Runner.evaluate_full/4 evaluator seam is not available"

    result = Runner.evaluate_full(manifests, cases, metadata_complete?, cleanup)

    assert is_map(result)
    assert Map.has_key?(result, :entries)
    assert Map.has_key?(result, :verdict)
    assert Map.has_key?(result, :exit_code)
    assert Map.has_key?(result, :reason_codes)

    result
  end

  defp run_fixture_cli(case_id, fixture, output) do
    args =
      [
        "run",
        "test/proof/run.exs",
        "--mode",
        "diagnostic",
        "--output",
        output,
        "--case",
        case_id
      ] ++ if(fixture, do: ["--fixture", fixture], else: [])

    System.cmd("mix", args, stderr_to_stdout: true, env: [{"MIX_ENV", "test"}])
  end

  defp full_fixture_manifests do
    Map.new(Catalog.coverage_inventory(), fn coverage_id ->
      {coverage_id, fixture_manifest(coverage_id, ["#{coverage_id}.case"])}
    end)
  end

  defp assert_unexecuted_business_inventory(results) do
    assert Enum.map(results, & &1["coverage_id"]) == Catalog.coverage_inventory()

    for entry <- results do
      case Map.fetch(Catalog.required().business_manifests, entry["coverage_id"]) do
        {:ok, manifest} ->
          assert entry["status"] == "not_run"
          assert entry["manifest_sha256"] == manifest.digest
          assert entry["required_case_ids"] == Enum.map(manifest.cases, & &1.case_id)

          assert Enum.all?(
                   entry["cases"],
                   &(&1["status"] == "not_run" and &1["verdict"] == "FAIL")
                 )

        :error ->
          assert entry["status"] == "missing"
          assert entry["manifest_sha256"] == nil
          assert entry["cases"] == []
          assert entry["reason_codes"] == ["missing.manifest"]
      end
    end
  end

  defp executable_fixture_manifests, do: full_fixture_manifests()

  defp executable_fixture_registrations(manifests) do
    register_fixture_callbacks(manifests, fn _coverage_id, case_id ->
      fn -> SelfTest.expect_manifest!(case_id <> ".verified", true, true) end
    end)
  end

  defp register_fixture_callbacks(manifests, callback_builder) do
    Enum.flat_map(Catalog.coverage_inventory(), fn coverage_id ->
      case Map.get(manifests, coverage_id) do
        nil -> []
        family_manifest -> registration_entries(coverage_id, family_manifest, callback_builder)
      end
    end)
  end

  defp registration_entries(coverage_id, family_manifest, callback_builder) do
    Enum.map(family_manifest.cases, fn case_manifest ->
      %{
        coverage_id: coverage_id,
        case_id: case_manifest.case_id,
        invariant_id: case_manifest.invariant_id,
        callback: callback_builder.(coverage_id, case_manifest.case_id),
        manifest:
          Map.merge(case_manifest, %{
            coverage_id: coverage_id,
            version: family_manifest.version,
            boundary: case_manifest.boundary,
            timeout_ms: Map.get(case_manifest, :timeout_ms, 10_000),
            expected: case_manifest.expected
          })
      }
    end)
  end

  defp fixture_manifest(coverage_id, case_ids, opts \\ []) do
    timeout_ms = Keyword.get(opts, :timeout_ms, 10_000)
    shared_assertion_ids = Keyword.get(opts, :assertion_ids)

    cases =
      Enum.map(case_ids, fn case_id ->
        assertion_ids = shared_assertion_ids || [case_id <> ".verified"]

        %{
          case_id: case_id,
          invariant_id: case_id <> ".invariant",
          boundary: "test_boundary",
          cut_point: nil,
          race_id: nil,
          assertion_ids: assertion_ids,
          timeout_ms: timeout_ms,
          expected: "the internal fixture assertion passes"
        }
      end)

    digest = :crypto.hash(:sha256, :erlang.term_to_binary({coverage_id, cases}, [:deterministic]))

    %{
      coverage_id: coverage_id,
      version: "1.0.0",
      scope: :complete,
      digest: Base.encode16(digest, case: :lower),
      cases: cases
    }
  end

  defp full_fixture_cases(manifests) do
    Catalog.coverage_inventory()
    |> Enum.flat_map(fn coverage_id ->
      manifests
      |> Map.get(coverage_id, %{cases: []})
      |> Map.fetch!(:cases)
      |> Enum.map(fn manifest_case ->
        observed_case(
          coverage_id,
          manifest_case.case_id,
          "PASS",
          [],
          manifest_case.assertion_ids,
          manifest_case.invariant_id
        )
      end)
    end)
  end

  defp observed_case(
         coverage_id,
         case_id,
         verdict,
         reason_codes,
         assertion_ids \\ nil,
         invariant_id \\ nil
       ) do
    assertion_ids = assertion_ids || [case_id <> ".verified"]

    %{
      "coverage_id" => coverage_id,
      "case_id" => case_id,
      "invariant_id" => invariant_id || case_id <> ".invariant",
      "status" => "completed",
      "verdict" => verdict,
      "assertion_ids" => assertion_ids,
      "assertions_executed" => length(assertion_ids),
      "observations" => [%{"code" => "fixture.assertion", "value" => verdict == "PASS"}],
      "reason_codes" => reason_codes
    }
  end

  defp clean_cleanup do
    %{
      "verdict" => "PASS",
      "workers_stopped" => true,
      "connections_released" => true,
      "locks_released" => true,
      "reason_codes" => []
    }
  end

  defp failed_cleanup do
    %{
      "verdict" => "FAIL",
      "workers_stopped" => false,
      "connections_released" => true,
      "locks_released" => true,
      "reason_codes" => ["cleanup.unconfirmed"]
    }
  end

  defp clean_git_root do
    root = Path.join(System.tmp_dir!(), "proof-clean-root-#{System.unique_integer([:positive])}")
    File.mkdir_p!(root)
    File.cp!("mix.lock", Path.join(root, "mix.lock"))

    {_, 0} = System.cmd("git", ["-C", root, "init"], stderr_to_stdout: true)
    {_, 0} = System.cmd("git", ["-C", root, "add", "mix.lock"], stderr_to_stdout: true)

    {_, 0} =
      System.cmd(
        "git",
        [
          "-C",
          root,
          "-c",
          "user.name=Proof Test",
          "-c",
          "user.email=proof-test@example.invalid",
          "commit",
          "-m",
          "fixture baseline"
        ],
        stderr_to_stdout: true
      )

    root
  end
end
