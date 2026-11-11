defmodule NewYou.Proof.P805Test do
  use ExUnit.Case, async: false

  alias NewYou.Proof.{Catalog, FullCatalog}

  test "canonical-equivalent email contention is a registered proof case" do
    registrations = Catalog.compiled_business_registrations()
    race = Enum.find(registrations, &(&1.case_id == "p805.canonical_email_race"))
    assert "p805.canonical_email_race.public_response" in race.assertion_ids
  end

  test "same-operation contention is a registered proof case" do
    registrations = Catalog.compiled_business_registrations()
    race = Enum.find(registrations, &(&1.case_id == "p805.same_operation_race"))
    assert "p805.same_operation_race.same_account_result" in race.assertion_ids
  end

  test "post-commit process loss and recovery is a registered proof case" do
    registrations = Catalog.compiled_business_registrations()
    assert Enum.any?(registrations, &(&1.case_id == "p805.post_commit_recovery"))
  end

  test "concurrent PMR collision is a registered proof case" do
    registrations = Catalog.compiled_business_registrations()
    assert Enum.any?(registrations, &(&1.case_id == "p805.pmr_collision_race"))
  end

  test "registration write boundaries have registered rollback cases" do
    ids = Enum.map(Catalog.compiled_business_registrations(), & &1.case_id)

    assert Enum.all?(
             ~w(account token intent nonce obligation operation),
             &(("p805.rollback_" <> &1) in ids)
           )
  end

  test "retired PMR non-reuse is a registered proof case" do
    registrations = Catalog.compiled_business_registrations()
    proof = Enum.find(registrations, &(&1.case_id == "p805.retired_pmr"))
    assert "p805.retired_pmr.account_removed" in proof.assertion_ids
  end

  @case_ids ~w(p805.accepted p805.rejected p805.envelope_rollback p805.rollback_account p805.rollback_token p805.rollback_intent p805.rollback_nonce p805.rollback_obligation p805.rollback_operation p805.audit_schedule_rollback p805.commit_rollback p805.replay_neutrality p805.pmr_collision p805.retired_pmr p805.same_email_race p805.canonical_email_race p805.same_operation_race p805.pmr_collision_race p805.post_commit_recovery p805.resend p805.resend_binding p805.browser_en p805.browser_af)

  test "bounded P8-05, P8-07, P8-08, P8-09, P8-11, P8-12 and P8-13 cases do not manufacture complete coverage" do
    manifests = Catalog.required().business_manifests
    assert Enum.all?(Map.values(manifests), &(&1.scope == :partial))
    registrations = Catalog.compiled_business_registrations()
    cases = Enum.flat_map(Map.values(manifests), & &1.cases)

    expected =
      @case_ids ++
        ~w(p807.consume_race p807.interrupted_consume p807.browser_en p807.browser_af p809.reconnect p809.interrupted_issue p809.hold_race p809.beam_restart p809.browser_en p809.browser_af p809.magic_consume_race p809.magic_issue_consume_race p809.magic_restart p811.interrupted_materialisation p811.existing_assertion p811.concurrent_execution p811.restart_backlog p813.admission_cut p813.capture_failure p813.source_failure p813.same_attempt_race p813.distinct_attempt_race p813.restart p813.crash_after_admission p813.crash_after_source p812.reset_race p812.stale_login_race p812.interrupted_reset p812.restart)

    assert Enum.sort(Enum.map(cases, & &1.case_id)) == Enum.sort(expected)
    assert Enum.sort(Enum.map(registrations, & &1.case_id)) == Enum.sort(expected)
    assert :ok = Catalog.validate_compiled_registrations(manifests, registrations)
    missing = Catalog.validate_registrations(registrations, :tb001).missing_families
    assert missing == Catalog.coverage_inventory()
    assert "session_login_revocation_restart" in missing
    assert "audit_e1" in missing
    assert "recovery_primary_email_change" in missing
    assert Catalog.coverage_inventory() |> length() == 10
  end

  # The aggregate includes independent BEAM boots across all owned families.
  # Each case retains its own proof deadline; this bounds the complete run.
  @tag timeout: 600_000
  test "runner executes every owned obligation and retains incomplete overall TB-001" do
    manifests = Catalog.required().business_manifests
    assert map_size(manifests) > 0

    assert {:ok, observations, cleanup} =
             FullCatalog.execute(manifests, Catalog.compiled_business_registrations())

    failures =
      observations
      |> Enum.reject(&(&1["verdict"] == "PASS"))
      |> Enum.map(fn observation ->
        failed_codes =
          observation["observations"]
          |> Enum.filter(&(&1["value"] == false))
          |> Enum.map(& &1["code"])

        observation
        |> Map.take([
          "case_id",
          "verdict",
          "status",
          "reason_codes",
          "duration_ms",
          "assertion_ids"
        ])
        |> Map.put("failed_observations", failed_codes)
      end)

    assert failures == [], "bounded proof failures: #{inspect(failures, limit: :infinity)}"

    assert length(observations) == length(@case_ids) + 29
    assert cleanup["verdict"] == "PASS"

    for observation <- observations do
      manifest =
        manifests[observation["coverage_id"]].cases
        |> Enum.find(&(&1.case_id == observation["case_id"]))

      assert observation["assertion_ids"] == manifest.assertion_ids
      assert observation["assertions_executed"] == length(manifest.assertion_ids)
      assert Enum.all?(observation["observations"], &is_boolean(&1["value"]))
    end

    result = NewYou.Proof.Runner.evaluate_full(manifests, observations, true, cleanup)

    for entry <- result.entries, Map.has_key?(manifests, entry.coverage_id) do
      assert Enum.all?(entry.cases, &(&1.verdict == "PASS"))
      assert entry.verdict == "FAIL"
      assert "manifest.partial" in entry.reason_codes
    end

    assert result.exit_code == 1
    assert result.verdict == "FAIL"
    assert "coverage.incomplete" in result.reason_codes
  end

  test "fixture cleanup recovers committed browser provenance when operation IDs were not returned" do
    alias NewYou.Proof.P805
    alias Ecto.Adapters.SQL.Sandbox
    parent = self()

    assert_raise RuntimeError, "synthetic browser result lost", fn ->
      P805.with_fixture(fn ->
        input = P805.request()
        browser_operation_id = Ecto.UUID.generate()

        {:ok, registration} =
          NewYou.Identity.register(%{input | operation_id: browser_operation_id})

        pmr = P805.account!(registration.account_id).pmr
        send(parent, {:committed_fixture, input.email, browser_operation_id, pmr})
        raise "synthetic browser result lost"
      end)
    end

    assert_receive {:committed_fixture, email, operation_id, pmr}

    Sandbox.unboxed_run(NewYou.Repo, fn ->
      assert fixture_rows(operation_id, email) == [0, 0, 0, 0, 0, 0, 0, 0]

      assert P805.scalar("SELECT count(*) FROM identity_pmr_reservations WHERE pmr = $1", [pmr]) ==
               1
    end)
  end

  test "fixture guardian cleans committed records when the fixture owner is killed" do
    alias NewYou.Proof.P805
    alias Ecto.Adapters.SQL.Sandbox
    previous_mfa = Application.fetch_env(:new_you, :identity_mfa_keyring)

    parent = self()

    scenario = NewYou.Proof.Scenario.start()

    {owner, monitor} =
      NewYou.Proof.Scenario.spawn(scenario, :fixture_owner, fn ->
        P805.with_fixture(fn ->
          Application.put_env(:new_you, :identity_mfa_keyring, :synthetic_owner_death)
          input = P805.request()
          {:ok, registration} = NewYou.Identity.register(input)
          account = P805.account!(registration.account_id)
          send(parent, {:fixture_committed, input.email, input.operation_id, account.pmr})
          receive do: (:never -> :ok)
        end)
      end)

    {email, operation_id, pmr} =
      receive do
        {:fixture_committed, email, operation_id, pmr} -> {email, operation_id, pmr}
      after
        15_000 -> flunk("fixture owner did not commit registration")
      end

    Process.exit(owner, :kill)
    assert_receive {:DOWN, ^monitor, :process, ^owner, :killed}, 5_000
    # Scenario teardown must await fixture cleanup before another case can run.
    assert {:error, [:worker_failed]} = NewYou.Proof.Scenario.stop(scenario)
    restored? = Application.fetch_env(:new_you, :identity_mfa_keyring) == previous_mfa
    assert restored?, "fixture environment was not restored after owner death"

    Sandbox.unboxed_run(NewYou.Repo, fn ->
      assert fixture_rows(operation_id, email) == [0, 0, 0, 0, 0, 0, 0, 0]

      assert P805.scalar("SELECT count(*) FROM identity_pmr_reservations WHERE pmr = $1", [pmr]) ==
               1
    end)
  end

  test "fixture cleanup removes only tracked rows and preserves historical foreign evidence" do
    alias Ecto.Adapters.SQL.Sandbox
    alias NewYou.Proof.P805

    historical_before =
      Sandbox.unboxed_run(NewYou.Repo, fn -> historical_foreign_evidence_signature() end)

    {owned, untracked, untracked_pmr} =
      P805.with_fixture(fn ->
        owned = P805.request()
        {:ok, _} = NewYou.Identity.register(owned)

        untracked = %{
          owned
          | operation_id: Ecto.UUID.generate(),
            email: "untracked-#{Ecto.UUID.generate()}@example.test"
        }

        {:ok, registration} = NewYou.Identity.register(untracked)
        {owned, untracked, P805.account!(registration.account_id).pmr}
      end)

    Sandbox.unboxed_run(NewYou.Repo, fn ->
      assert fixture_rows(owned.operation_id, owned.email) == [0, 0, 0, 0, 0, 0, 0, 0]
      assert fixture_rows(untracked.operation_id, untracked.email) == [1, 1, 1, 1, 1, 1, 1, 1]

      assert P805.scalar("SELECT count(*) FROM identity_pmr_reservations WHERE pmr = $1", [
               untracked_pmr
             ]) == 1

      assert historical_foreign_evidence_signature() == historical_before
    end)

    P805.with_fixture(fn ->
      _ = P805.request(%{operation_id: untracked.operation_id, email: untracked.email})
    end)

    Sandbox.unboxed_run(NewYou.Repo, fn ->
      assert fixture_rows(untracked.operation_id, untracked.email) == [0, 0, 0, 0, 0, 0, 0, 0]

      assert P805.scalar("SELECT count(*) FROM identity_pmr_reservations WHERE pmr = $1", [
               untracked_pmr
             ]) == 1

      assert historical_foreign_evidence_signature() == historical_before
    end)
  end

  defp fixture_rows(operation_id, email) do
    operation = Ecto.UUID.dump!(operation_id)

    [
      NewYou.Proof.P805.scalar("SELECT count(*) FROM accounts WHERE email = $1", [email]),
      NewYou.Proof.P805.scalar(
        "SELECT count(*) FROM registration_operations WHERE operation_id = $1",
        [operation]
      ),
      NewYou.Proof.P805.scalar(
        "SELECT count(*) FROM tokens WHERE account_id IN (SELECT id FROM accounts WHERE email = $1)",
        [email]
      ),
      NewYou.Proof.P805.scalar(
        "SELECT count(*) FROM message_intents WHERE source_operation_id = $1",
        [operation]
      ),
      NewYou.Proof.P805.scalar(
        "SELECT count(*) FROM communications_protected_envelopes e JOIN message_intents i ON i.id = e.message_intent_id WHERE i.source_operation_id = $1",
        [operation]
      ),
      NewYou.Proof.P805.scalar(
        "SELECT count(*) FROM communications_envelope_nonces n WHERE n.nonce IN (SELECT e.nonce FROM communications_protected_envelopes e JOIN message_intents i ON i.id = e.message_intent_id WHERE i.source_operation_id = $1)",
        [operation]
      ),
      NewYou.Proof.P805.scalar(
        "SELECT count(*) FROM evidence_obligations WHERE source_operation_id = $1",
        [operation]
      ),
      NewYou.Proof.P805.scalar(
        "SELECT count(*) FROM oban_jobs WHERE args->'primary_key'->>'id' IN (SELECT id::text FROM evidence_obligations WHERE source_operation_id = $1) OR args->'primary_key'->>'id' IN (SELECT id::text FROM message_intents WHERE source_operation_id = $1)",
        [operation]
      )
    ]
  end

  defp historical_foreign_evidence_signature do
    %{rows: rows} =
      NewYou.Repo.query!(
        "SELECT id::text, source_operation_id::text, evidence_type, created_at::text FROM evidence_obligations WHERE evidence_type = 'identity_recovery_completed' ORDER BY id"
      )

    :crypto.hash(:sha256, :erlang.term_to_binary(rows))
  end

  test "missing owned callback remains a missing case and cannot become a passing family" do
    registrations =
      Catalog.compiled_business_registrations() |> Enum.reject(&(&1.case_id == "p805.accepted"))

    {results, _cleanup} =
      NewYou.Proof.Runner.execute_full_catalog(
        Catalog.required().business_manifests,
        registrations
      )

    family = Enum.find(results, &(&1["coverage_id"] == "registration_pmr_reconciliation"))
    assert family["verdict"] == "FAIL"
    assert hd(family["cases"])["reason_codes"] == ["missing.case"]
  end
end
