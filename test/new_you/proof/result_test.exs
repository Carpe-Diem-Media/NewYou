defmodule NewYou.Proof.ResultTest do
  use ExUnit.Case, async: true

  alias NewYou.Proof.{Catalog, Result, Scenario}

  test "evidence is bound to the current routed TB-001 authority and rejects its predecessor" do
    router = File.read!("docs/delivery/CURRENT_DELIVERY_ROUTER.json") |> Jason.decode!()

    authority =
      Enum.find(router["delivery_contracts"], &(&1["document_id"] == "FP001_TRACER_BULLET"))

    assert authority["canonical_filename"] == "FP-001_TRACER_BULLET_CONTRACT_WORKING_v0.1.3.md"

    assert Base.encode16(:crypto.hash(:sha256, File.read!(authority["repository_path"])),
             case: :lower
           ) == authority["sha256"]

    result = self_test_result(Catalog.required().self_test.digest)
    assert result["contract"] == "TB-001/v0.1.3"
    assert :ok = Result.validate(result, mode: :harness_self_test)

    assert {:error, errors} =
             Result.validate(Map.put(result, "contract", "TB-001/v0.1.2"),
               mode: :harness_self_test
             )

    assert :invalid_constant in errors
  end

  test "semantic validation independently rejects partial-family PASS and missing scope reason" do
    manifest = Catalog.required().business_manifests["browser_spine"]

    entry = %{
      "coverage_id" => "browser_spine",
      "manifest_sha256" => manifest.digest,
      "required_case_ids" => Enum.map(manifest.cases, & &1.case_id),
      "status" => "completed",
      "verdict" => "PASS",
      "reason_codes" => [],
      "cases" =>
        Enum.map(manifest.cases, fn case_data ->
          case_data
          |> Map.drop([:coverage_id, :digest])
          |> Map.merge(%{
            status: "completed",
            verdict: "PASS",
            observations: [],
            assertions_executed: length(case_data.assertion_ids),
            duration_ms: 0,
            timeout_override_reason: Map.get(case_data, :timeout_override_reason),
            reason_codes: []
          })
          |> Jason.encode!()
          |> Jason.decode!()
        end)
    }

    result = unavailable_full_result()

    results =
      Enum.map(result["results"], fn current ->
        if current["coverage_id"] == "browser_spine", do: entry, else: current
      end)

    assert {:error, errors} = Result.validate(Map.put(result, "results", results), mode: :tb001)
    assert :partial_manifest_pass in errors
    assert :missing_partial_manifest_reason in errors
  end

  test "expect records the actual assertion and returns the observation" do
    scenario = Scenario.start()
    :ok = Scenario.require_assertions(scenario, "case.one", ["case.one.verified"])

    assert :observed =
             Result.expect!(scenario, "case.one", "case.one.verified", :observed, :observed)

    assert %{"case.one" => %{assertion_ids: ["case.one.verified"], failed_ids: [], count: 1}} =
             Scenario.assertion_snapshot(scenario)

    assert :ok = Scenario.stop(scenario)
  end

  test "mismatch and duplicate or unknown assertion ids fail closed" do
    scenario = Scenario.start()
    :ok = Scenario.require_assertions(scenario, "case.one", ["case.one.verified"])

    assert_raise RuntimeError, "proof assertion failed", fn ->
      Result.expect!(scenario, "case.one", "case.one.verified", :wrong, :expected)
    end

    assert_raise RuntimeError, "proof assertion failed", fn ->
      Result.expect!(scenario, "case.one", "case.one.verified", :expected, :expected)
    end

    assert_raise RuntimeError, "proof assertion failed", fn ->
      Result.expect!(scenario, "case.one", "case.one.unknown", true, true)
    end

    assert {:error, _} = Scenario.stop(scenario)
  end

  test "result verdict and exit code are derived from cleanup and actual assertions" do
    result =
      Result.verdict(
        mode: :harness_self_test,
        metadata_complete: true,
        checks: [:pass],
        cleanup: :pass
      )

    assert result == %{overall_verdict: "PASS", exit_code: 0}

    assert Result.verdict(
             mode: :harness_self_test,
             metadata_complete: false,
             checks: [:pass],
             cleanup: :pass
           ) ==
             %{overall_verdict: "FAIL", exit_code: 2}

    assert Result.verdict(mode: :tb001, metadata_complete: true, checks: [:fail], cleanup: :pass) ==
             %{overall_verdict: "FAIL", exit_code: 1}
  end

  test "complete tb001 evidence can pass the pure verdict boundary" do
    assert Result.verdict(
             mode: :tb001,
             metadata_complete: true,
             checks: [:pass],
             cleanup: :pass
           ) == %{overall_verdict: "PASS", exit_code: 0}
  end

  test "schema and cross-field validation reject caller counts and inconsistent pass" do
    malformed = %{"overall_verdict" => "PASS", "exit_code" => 0, "assertions_executed" => 100}
    assert {:error, _} = Result.validate(malformed, mode: :harness_self_test)
  end

  test "empty diagnostic results cannot claim PASS" do
    sha = String.duplicate("a", 40)
    lock_sha = String.duplicate("b", 64)
    result = self_test_result(Catalog.required().self_test.digest)

    result = %{
      result
      | "mode" => "diagnostic",
        "metadata_complete" => true,
        "git" => %{
          "head_before" => sha,
          "head_after" => sha,
          "clean_before" => true,
          "clean_after" => true,
          "lock_sha256_before" => lock_sha,
          "lock_sha256_after" => lock_sha
        },
        "runtime" => %{
          "elixir" => System.version(),
          "otp" => List.to_string(:erlang.system_info(:otp_release)),
          "erts" => List.to_string(:erlang.system_info(:version)),
          "postgresql" => "18.6",
          "mix_env" => "test"
        },
        "dependencies" => test_dependency_metadata(),
        "results" => [],
        "overall_verdict" => "PASS",
        "exit_code" => 0,
        "reason_codes" => []
    }

    assert {:error, reasons} = Result.validate(result, mode: :diagnostic)
    assert :invalid_overall_pass in reasons
  end

  test "a timeout case requires the infrastructure failure exit code" do
    result = self_test_result(Catalog.required().self_test.digest)
    [entry] = result["results"]
    [first_case | remaining_cases] = entry["cases"]

    timed_out_case = %{
      first_case
      | "status" => "timeout",
        "verdict" => "FAIL",
        "reason_codes" => ["timeout.expired"]
    }

    timed_out_entry = %{
      entry
      | "verdict" => "FAIL",
        "reason_codes" => ["self_test.incomplete"],
        "cases" => [timed_out_case | remaining_cases]
    }

    sha = String.duplicate("a", 40)
    lock_sha = String.duplicate("b", 64)

    result = %{
      result
      | "mode" => "diagnostic",
        "metadata_complete" => true,
        "git" => %{
          "head_before" => sha,
          "head_after" => sha,
          "clean_before" => true,
          "clean_after" => true,
          "lock_sha256_before" => lock_sha,
          "lock_sha256_after" => lock_sha
        },
        "runtime" => %{
          "elixir" => System.version(),
          "otp" => List.to_string(:erlang.system_info(:otp_release)),
          "erts" => List.to_string(:erlang.system_info(:version)),
          "postgresql" => "18.6",
          "mix_env" => "test"
        },
        "dependencies" => test_dependency_metadata(),
        "results" => [timed_out_entry],
        "overall_verdict" => "FAIL",
        "exit_code" => 1,
        "reason_codes" => ["coverage.incomplete"]
    }

    assert {:error, reasons} = Result.validate(result, mode: :diagnostic)
    assert :timeout_failure_mismatch in reasons
  end

  test "companion schema keeps the approved inventory and fixed wire keys" do
    schema =
      File.read!("docs/superpowers/specs/p8-04-proof-result-v1.schema.json")
      |> Jason.decode!()

    assert schema["properties"]["contract"]["const"] == "TB-001/v0.1.3"

    assert schema["$schema"] == "https://json-schema.org/draft/2020-12/schema"
    assert schema["$id"] == "urn:new-you:p8-04:proof-result:1.0.0"

    assert schema["required"] ==
             ~w(schema_version run_id mode contract metadata_complete git runtime dependencies coverage_inventory results cleanup overall_verdict exit_code reason_codes)

    assert schema["properties"]["coverage_inventory"]["const"] == Catalog.coverage_inventory()

    assert schema["properties"]["mode"]["enum"] ==
             ["harness_self_test", "tb001", "diagnostic"]

    assert schema["$defs"]["case"]["properties"]["cut_point"]["enum"] == [
             nil,
             "transaction.before_commit",
             "transaction.after_commit",
             "scheduling.before_enqueue",
             "scheduling.after_enqueue",
             "provider.before_invoke",
             "provider.after_invoke_before_persist",
             "evidence.before_materialize",
             "evidence.after_materialize_before_commit"
           ]

    assert schema["additionalProperties"] == false
    assert schema["properties"]["results"]["items"]["additionalProperties"] == false
    assert schema["$defs"]["case"]["additionalProperties"] == false
  end

  test "source capture uses the current checkout and lockfile" do
    source = Result.capture_source()
    assert source.head == System.cmd("git", ["rev-parse", "HEAD"]) |> elem(0) |> String.trim()
    assert is_boolean(source.clean)

    assert source.lock_sha256 ==
             :crypto.hash(:sha256, File.read!("mix.lock")) |> Base.encode16(case: :lower)
  end

  test "PostgreSQL metadata comes from the TEST connection and checks its role" do
    assert {:ok, version} = Result.capture_postgresql()
    assert is_binary(version)
    assert String.match?(version, ~r/^\d+(\.\d+)+/)
  end

  test "atomic publication refuses an existing target and preserves its bytes" do
    directory = Path.join(System.tmp_dir!(), "proof-result-#{System.unique_integer([:positive])}")
    File.mkdir!(directory)
    target = Path.join(directory, "result.json")
    File.write!(target, "canary-existing-artifact")

    assert {:error, :output_failure} = Result.write_atomic(target, %{safe: "result"})
    assert File.read!(target) == "canary-existing-artifact"

    File.rm!(target)
    assert :ok = Result.write_atomic(target, %{safe: "result"})
    assert File.read!(target) == "{\"safe\":\"result\"}"
    assert Bitwise.band(File.stat!(target).mode, 0o777) == 0o600

    File.rm_rf!(directory)
  end

  test "metadata and source changes cannot claim a complete result" do
    assert {:error, reasons} =
             Result.validate(%{"mode" => "tb001", "metadata_complete" => true}, mode: :tb001)

    assert :incomplete_metadata_claim in reasons or :schema_properties in reasons

    assert Result.verdict(
             mode: :diagnostic,
             metadata_complete: false,
             checks: [:pass],
             cleanup: :pass
           ) ==
             %{overall_verdict: "FAIL", exit_code: 2}
  end

  test "full results preserve the fixed coverage inventory order" do
    result = unavailable_full_result()
    reversed = %{result | "results" => Enum.reverse(result["results"])}

    assert {:error, reasons} = Result.validate(reversed, mode: :tb001)
    assert :incomplete_tb001_results in reasons
  end

  test "self-test results cannot claim a different manifest digest" do
    digest = Catalog.required().self_test.digest
    wrong_digest = String.duplicate(if(String.first(digest) == "0", do: "1", else: "0"), 64)

    assert {:error, reasons} =
             Result.validate(self_test_result(wrong_digest), mode: :harness_self_test)

    assert :invalid_self_test_manifest in reasons
  end

  test "self-test result accepts bounded natural-language expectations from its manifest" do
    digest = Catalog.required().self_test.digest

    assert :ok = Result.validate(self_test_result(digest), mode: :harness_self_test)
  end

  test "self-test result rejects a missing required case" do
    result = self_test_result(Catalog.required().self_test.digest)
    [entry] = result["results"]
    result = %{result | "results" => [%{entry | "cases" => Enum.drop(entry["cases"], -1)}]}

    assert {:error, reasons} = Result.validate(result, mode: :harness_self_test)
    assert :incomplete_self_test_manifest in reasons
  end

  test "self-test result rejects a missing required assertion" do
    result = self_test_result(Catalog.required().self_test.digest)
    [entry] = result["results"]
    [first | rest] = entry["cases"]
    missing_assertion = %{first | "assertion_ids" => [], "assertions_executed" => 0}

    result = %{result | "results" => [%{entry | "cases" => [missing_assertion | rest]}]}

    assert {:error, reasons} = Result.validate(result, mode: :harness_self_test)
    assert :invalid_case_pass in reasons
  end

  test "self-test result rejects duplicate cases" do
    result = self_test_result(Catalog.required().self_test.digest)
    [entry] = result["results"]
    [first | rest] = entry["cases"]
    result = %{result | "results" => [%{entry | "cases" => [first | [first | rest]]}]}

    assert {:error, reasons} = Result.validate(result, mode: :harness_self_test)
    assert :incomplete_self_test_manifest in reasons
  end

  test "self-test result rejects an assertion with the wrong invariant" do
    result = self_test_result(Catalog.required().self_test.digest)
    [entry] = result["results"]
    [first | rest] = entry["cases"]
    wrong_invariant = %{first | "invariant_id" => "forged.invariant"}

    result = %{result | "results" => [%{entry | "cases" => [wrong_invariant | rest]}]}

    assert {:error, _reasons} = Result.validate(result, mode: :harness_self_test)
  end

  test "self-test result rejects a passing family with a failed case" do
    result = self_test_result(Catalog.required().self_test.digest)
    [entry] = result["results"]
    [first | rest] = entry["cases"]

    failed_case = %{
      first
      | "verdict" => "FAIL",
        "reason_codes" => ["assertion.failed"]
    }

    result = %{result | "results" => [%{entry | "cases" => [failed_case | rest]}]}

    assert {:error, _reasons} = Result.validate(result, mode: :harness_self_test)
  end

  test "full verdict uses exit 2 for incomplete metadata or cleanup" do
    assert Result.verdict(
             mode: :tb001,
             metadata_complete: false,
             checks: [:pass],
             cleanup: :pass
           ) == %{overall_verdict: "FAIL", exit_code: 2}

    assert Result.verdict(
             mode: :tb001,
             metadata_complete: true,
             checks: [:pass],
             cleanup: :fail
           ) == %{overall_verdict: "FAIL", exit_code: 2}
  end

  test "complete metadata must include every dependency from the current lockfile" do
    result = unavailable_full_result()

    result = %{
      result
      | "metadata_complete" => true,
        "git" => %{
          "head_before" => String.duplicate("a", 40),
          "head_after" => String.duplicate("a", 40),
          "clean_before" => true,
          "clean_after" => true,
          "lock_sha256_before" => String.duplicate("b", 64),
          "lock_sha256_after" => String.duplicate("b", 64)
        },
        "runtime" => %{
          "elixir" => "1.18.0",
          "otp" => "27",
          "erts" => "15.2",
          "postgresql" => "17.2",
          "mix_env" => "test"
        },
        "dependencies" => [
          %{
            "name" => "proof_not_in_lock",
            "source" => "hex",
            "locked_version" => "1.0.0",
            "loaded_version" => nil,
            "revision" => nil,
            "runtime_required" => false
          }
        ],
        "exit_code" => 1
    }

    assert {:error, reasons} = Result.validate(result, mode: :tb001)
    assert :dependency_lock_mismatch in reasons
  end

  test "dependency capture preserves runtime-required role when app is absent" do
    expression =
      ~S|:ok = Application.stop(:jason); :ok = Application.unload(:jason); {:ok, dependencies} = NewYou.Proof.Result.capture_dependencies(); dependency = Enum.find(dependencies, &(&1.name == "jason")); IO.puts("P8_04_DEPENDENCY_CAPTURE=" <> Jason.encode!(%{"runtime_required" => dependency.runtime_required, "loaded_version" => dependency.loaded_version}))|

    {stdout, exit_code} =
      System.cmd("mix", ["run", "-e", expression],
        stderr_to_stdout: true,
        env: [{"MIX_ENV", "test"}]
      )

    assert exit_code == 0, stdout

    payload =
      stdout
      |> String.split("\n")
      |> Enum.find(&String.starts_with?(&1, "P8_04_DEPENDENCY_CAPTURE="))

    assert is_binary(payload), stdout

    assert {:ok, dependency} =
             payload |> String.replace_prefix("P8_04_DEPENDENCY_CAPTURE=", "") |> Jason.decode()

    assert dependency["runtime_required"] == true
    assert dependency["loaded_version"] == nil
  end

  test "dependency classification separates expected runtime roles from loaded apps" do
    lock_entries = [
      {:jason, hex_lock_entry("1.4.5")},
      {:source_tool, hex_lock_entry("0.1.0")}
    ]

    assert {:ok, entries} =
             Result.classify_dependencies(
               lock_entries,
               %{"jason" => true, "source_tool" => false},
               %{"jason" => "1.4.5"}
             )

    assert Enum.map(entries, & &1.name) == ["jason", "source_tool"]
    assert length(entries) == length(lock_entries)

    assert %{runtime_required: true, loaded_version: "1.4.5", locked_version: "1.4.5"} =
             Enum.find(entries, &(&1.name == "jason"))

    assert %{runtime_required: false, loaded_version: nil} =
             Enum.find(entries, &(&1.name == "source_tool"))
  end

  test "dependency classification keeps an unloaded runtime app required" do
    assert {:ok, [dependency]} =
             Result.classify_dependencies(
               [{:jason, hex_lock_entry("1.4.5")}],
               %{"jason" => true},
               %{}
             )

    assert dependency.runtime_required
    assert dependency.loaded_version == nil
  end

  test "dependency classification rejects duplicate names and missing runtime roles" do
    entry = hex_lock_entry("1.4.5")

    assert {:error, :duplicate_dependency} =
             Result.classify_dependencies(
               [{:jason, entry}, {:jason, entry}],
               %{"jason" => true},
               %{"jason" => "1.4.5"}
             )

    assert {:error, :runtime_role_unavailable} =
             Result.classify_dependencies(
               [{:jason, entry}],
               %{},
               %{"jason" => "1.4.5"}
             )
  end

  test "dependency classification rejects git entries without revisions and path sources" do
    assert {:error, :unreproducible_lock_entry} =
             Result.classify_dependencies(
               [{:git_dep, {:git, "https://example.invalid/dep.git", nil, []}}],
               %{"git_dep" => true},
               %{}
             )

    assert {:error, :unreproducible_lock_entry} =
             Result.classify_dependencies(
               [{:local_dep, {:path, "../local_dep", []}}],
               %{"local_dep" => false},
               %{}
             )
  end

  test "database preflight rejects DEV and production identities" do
    test_config = NewYou.LocalConfig.repo(:test)

    test_server = %{
      database: "new_you_test",
      username: "new_you_test",
      role_createdb?: false
    }

    assert Result.test_connection_valid?(:test, test_config, test_server)

    dev = [hostname: "127.0.0.1", port: 55432, database: "new_you_dev", username: "new_you_dev"]
    dev_server = %{database: "new_you_dev", username: "new_you_dev", role_createdb?: false}

    refute Result.test_connection_valid?(:test, dev, dev_server)
    refute Result.test_connection_valid?(:prod, test_config, test_server)

    refute Result.test_connection_valid?(:test, test_config, %{test_server | role_createdb?: true})

    refute Result.test_connection_valid?(
             :test,
             Keyword.put(test_config, :url, "redacted"),
             test_server
           )
  end

  defp unavailable_full_result do
    inventory = Catalog.coverage_inventory()

    results =
      Enum.map(inventory, fn coverage_id ->
        %{
          "coverage_id" => coverage_id,
          "manifest_sha256" => nil,
          "required_case_ids" => [],
          "status" => "missing",
          "verdict" => "FAIL",
          "reason_codes" => ["missing.manifest"],
          "cases" => []
        }
      end)

    %{
      "schema_version" => "1.0.0",
      "run_id" => "run-test",
      "mode" => "tb001",
      "contract" => "TB-001/v0.1.3",
      "metadata_complete" => false,
      "git" => %{
        "head_before" => nil,
        "head_after" => nil,
        "clean_before" => nil,
        "clean_after" => nil,
        "lock_sha256_before" => nil,
        "lock_sha256_after" => nil
      },
      "runtime" => %{
        "elixir" => nil,
        "otp" => nil,
        "erts" => nil,
        "postgresql" => nil,
        "mix_env" => nil
      },
      "dependencies" => test_dependency_metadata(),
      "coverage_inventory" => inventory,
      "results" => results,
      "cleanup" => %{
        "verdict" => "FAIL",
        "workers_stopped" => false,
        "connections_released" => false,
        "locks_released" => false,
        "reason_codes" => ["not.run"]
      },
      "overall_verdict" => "FAIL",
      "exit_code" => 2,
      "reason_codes" => ["metadata.unavailable"]
    }
  end

  defp self_test_result(digest) do
    manifests = Catalog.required().self_test.cases

    cases =
      Enum.map(manifests, fn manifest ->
        %{
          "case_id" => manifest.case_id,
          "invariant_id" => manifest.invariant_id,
          "boundary" => manifest.boundary,
          "cut_point" => manifest.cut_point,
          "race_id" => nil,
          "status" => "completed",
          "verdict" => "PASS",
          "expected" => manifest.expected,
          "observations" => [%{"code" => "fixture.result", "value" => true}],
          "assertion_ids" => manifest.assertion_ids,
          "assertions_executed" => length(manifest.assertion_ids),
          "duration_ms" => 0,
          "timeout_ms" => manifest.timeout_ms,
          "timeout_override_reason" => manifest.timeout_override_reason,
          "reason_codes" => []
        }
      end)

    %{
      "schema_version" => "1.0.0",
      "run_id" => "run-test",
      "mode" => "harness_self_test",
      "contract" => "TB-001/v0.1.3",
      "metadata_complete" => false,
      "git" => %{
        "head_before" => nil,
        "head_after" => nil,
        "clean_before" => nil,
        "clean_after" => nil,
        "lock_sha256_before" => nil,
        "lock_sha256_after" => nil
      },
      "runtime" => %{
        "elixir" => nil,
        "otp" => nil,
        "erts" => nil,
        "postgresql" => nil,
        "mix_env" => nil
      },
      "dependencies" => test_dependency_metadata(),
      "coverage_inventory" => Catalog.coverage_inventory(),
      "results" => [
        %{
          "coverage_id" => "harness",
          "manifest_sha256" => digest,
          "required_case_ids" => Enum.map(cases, & &1["case_id"]),
          "status" => "completed",
          "verdict" => "PASS",
          "reason_codes" => [],
          "cases" => cases
        }
      ],
      "cleanup" => %{
        "verdict" => "PASS",
        "workers_stopped" => true,
        "connections_released" => true,
        "locks_released" => true,
        "reason_codes" => []
      },
      "overall_verdict" => "FAIL",
      "exit_code" => 2,
      "reason_codes" => ["metadata.unavailable"]
    }
  end

  defp test_dependency_metadata do
    case Result.capture_dependencies() do
      {:ok, dependencies} -> dependencies
      {:error, _reason} -> []
    end
  end

  defp hex_lock_entry(version),
    do: {:hex, "synthetic", version, <<0::256>>, [:mix], [], "hexpm", nil}
end
