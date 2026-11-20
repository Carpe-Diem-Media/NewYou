defmodule NewYou.Proof.P805Test do
  use ExUnit.Case, async: false

  alias NewYou.Proof.{Catalog, FullCatalog, P805Fixture}

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

  test "upstream bounded mappings remain available inside the complete integration" do
    upstream = NewYou.Proof.P805Catalog.manifests()
    assert Enum.all?(upstream, fn {_, manifest} -> manifest.scope == :partial end)
    manifests = Catalog.required().business_manifests
    registrations = Catalog.compiled_business_registrations()
    assert Enum.all?(manifests, fn {_, manifest} -> manifest.scope == :complete end)
    assert Enum.all?(@case_ids, fn id -> Enum.any?(registrations, &(&1.case_id == id)) end)
    assert :ok = Catalog.validate_compiled_registrations(manifests, registrations)
    assert Catalog.validate_registrations(registrations, :tb001).missing_families == []
  end

  # The aggregate includes independent BEAM boots across all owned families.
  # Each case retains its own proof deadline; this bounds the complete run.
  @tag timeout: 600_000
  test "runner executes every reviewed obligation and evaluates complete TB-001" do
    manifests = Catalog.required().business_manifests
    assert map_size(manifests) > 0

    assert {:ok, observations, cleanup} =
             FullCatalog.execute(manifests, Catalog.compiled_business_registrations())

    assert_no_catalog_failures(observations, manifests)

    assert length(observations) == 133
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

      if manifests[entry.coverage_id].scope == :complete do
        assert entry.verdict == "PASS"
        assert entry.reason_codes == []
      else
        assert entry.verdict == "FAIL"
        assert "manifest.partial" in entry.reason_codes
      end
    end

    assert result.exit_code == 0
    assert result.verdict == "PASS"
    assert result.reason_codes == []
  end

  test "aggregate diagnostics report a late owner callback abort without claiming assertion execution" do
    case_id = "p819.email_notices"
    registration = Enum.find(Catalog.compiled_business_registrations(), &(&1.case_id == case_id))
    coverage_id = registration.coverage_id
    family = Catalog.required().business_manifests[coverage_id]
    manifests = %{coverage_id => %{family | cases: [registration.manifest]}}

    # Force the real owner callback to abort at admission, before opening a
    # checkout or recording its completion assertion.
    fixture = P805Fixture.acquire([], "aggregate-diagnostics", nil)

    failure =
      try do
        assert {:ok, [failure], %{"verdict" => "PASS"}} =
                 FullCatalog.execute(manifests, [registration])

        failure
      after
        assert :ok = P805Fixture.finish(fixture, fn _ -> :ok end)
      end

    assert %{
             "case_id" => ^case_id,
             "verdict" => "FAIL",
             "status" => "error",
             "reason_codes" => ["probe.failed"],
             "assertion_ids" => [],
             "assertions_executed" => 0
           } = failure

    earlier =
      for index <- 1..132, do: %{"case_id" => "passing-case-#{index}", "verdict" => "PASS"}

    error =
      assert_raise ExUnit.AssertionError, fn ->
        assert_no_catalog_failures(earlier ++ [failure], manifests)
      end

    assert error.message =~ ~s("case_id" => "p819.email_notices")
    assert error.message =~ ~s("status" => "error")
    assert error.message =~ ~s("reason_codes" => ["probe.failed"])
    assert error.message =~ ~s("unrecorded_assertions" => ["p819.email_notices.owner_assertions"])
    assert error.message =~ ~s("failed_observations" => [])
    refute error.message =~ "passing-case-"
    refute error.message =~ "fixture already active or quarantined"
    refute error.message =~ "..."
  end

  defp assert_no_catalog_failures(observations, manifests) do
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
        |> attribute_owner_abort(manifests[observation["coverage_id"]])
      end)

    assert failures == [], "bounded proof failures: #{inspect(failures, limit: :infinity)}"
  end

  defp attribute_owner_abort(
         %{"case_id" => case_id, "assertion_ids" => [], "reason_codes" => reasons} = failure,
         %{cases: cases}
       ) do
    completion_id = case_id <> ".owner_assertions"

    # The wrapper records this assertion only after the owner callback returns.
    # Keep missing completion evidence separate from a false observation.
    if "probe.failed" in reasons and
         Enum.any?(cases, &(&1.case_id == case_id and &1.assertion_ids == [completion_id])) do
      Map.put(failure, "unrecorded_assertions", [completion_id])
    else
      failure
    end
  end

  defp attribute_owner_abort(failure, _manifest), do: failure

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
        snapshot = capture_fixture(browser_operation_id, input.email)
        assert fixture_rows(snapshot) == List.duplicate(1, 8)
        send(parent, {:committed_fixture, snapshot, pmr})
        raise "synthetic browser result lost"
      end)
    end

    assert_receive {:committed_fixture, snapshot, pmr}

    Sandbox.unboxed_run(NewYou.Repo, fn ->
      assert fixture_rows(snapshot) == List.duplicate(0, 8)

      assert P805.scalar("SELECT count(*) FROM identity_pmr_reservations WHERE pmr = $1", [pmr]) ==
               1
    end)
  end

  test "fixture guardian cleans committed records when the fixture owner is killed" do
    alias NewYou.Proof.P805
    alias Ecto.Adapters.SQL.Sandbox
    previous_mfa = Application.fetch_env(:new_you, :identity_mfa_keyring)

    browser_keys =
      ~w(p8_07_browser_development_fixtures p8_08_browser_development_fixtures p8_09_browser_development_fixtures p8_12_browser_development_fixtures p8_15_browser_development_fixtures)a

    previous_browser = Map.new(browser_keys, &{&1, Application.fetch_env(:new_you, &1)})

    parent = self()

    scenario = NewYou.Proof.Scenario.start()

    {owner, monitor} =
      NewYou.Proof.Scenario.spawn(scenario, :fixture_owner, fn ->
        P805.with_fixture(fn ->
          Application.put_env(:new_you, :identity_mfa_keyring, :synthetic_owner_death)
          input = P805.request()
          {:ok, registration} = NewYou.Identity.register(input)
          account = P805.account!(registration.account_id)
          snapshot = capture_fixture(input.operation_id, input.email)
          assert fixture_rows(snapshot) == List.duplicate(1, 8)
          send(parent, {:fixture_committed, snapshot, account.pmr})
          receive do: (:never -> :ok)
        end)
      end)

    {snapshot, pmr} =
      receive do
        {:fixture_committed, snapshot, pmr} -> {snapshot, pmr}
      after
        15_000 -> flunk("fixture owner did not commit registration")
      end

    Process.exit(owner, :kill)
    assert_receive {:DOWN, ^monitor, :process, ^owner, :killed}, 5_000
    # Scenario teardown must await fixture cleanup before another case can run.
    assert {:error, [:worker_failed]} = NewYou.Proof.Scenario.stop(scenario)
    restored? = Application.fetch_env(:new_you, :identity_mfa_keyring) == previous_mfa
    assert restored?, "fixture environment was not restored after owner death"
    assert Map.new(browser_keys, &{&1, Application.fetch_env(:new_you, &1)}) == previous_browser

    Sandbox.unboxed_run(NewYou.Repo, fn ->
      assert fixture_rows(snapshot) == List.duplicate(0, 8)

      assert P805.scalar("SELECT count(*) FROM identity_pmr_reservations WHERE pmr = $1", [pmr]) ==
               1
    end)
  end

  for path <- [:success, :assertion_failure] do
    @path path
    test "fixture preservation cleans its committed rows on the #{@path} path" do
      alias Ecto.Adapters.SQL.Sandbox
      alias NewYou.Proof.P805
      parent = self()
      path = @path

      historical_before =
        Sandbox.unboxed_run(NewYou.Repo, &historical_foreign_evidence_signature/0)

      exercise = fn ->
        with_preserved_registration(fn owned, untracked, pmr ->
          send(parent, {:preserved_fixture, owned, untracked, pmr})

          Sandbox.unboxed_run(NewYou.Repo, fn ->
            assert fixture_rows(owned) == List.duplicate(0, 8)
            assert fixture_rows(untracked) == List.duplicate(1, 8)
            assert historical_foreign_evidence_signature() == historical_before
          end)

          preservation_assertion(path)
        end)
      end

      exercise_preservation(path, exercise)

      assert_receive {:preserved_fixture, owned, untracked, pmr}

      Sandbox.unboxed_run(NewYou.Repo, fn ->
        assert fixture_rows(owned) == List.duplicate(0, 8)
        assert fixture_rows(untracked) == List.duplicate(0, 8)

        assert P805.scalar("SELECT count(*) FROM identity_pmr_reservations WHERE pmr = $1", [pmr]) ==
                 1

        assert historical_foreign_evidence_signature() == historical_before
      end)
    end
  end

  test "cleanup observation finds orphan nonces and jobs after their parents disappear" do
    alias Ecto.Adapters.SQL.Sandbox
    alias NewYou.Proof.P805

    snapshot =
      P805.with_fixture(fn ->
        request = P805.request()
        {:ok, _} = NewYou.Identity.register(request)
        snapshot = capture_fixture(request.operation_id, request.email)
        assert fixture_rows(snapshot) == List.duplicate(1, 8)
        snapshot
      end)

    Sandbox.unboxed_run(NewYou.Repo, fn ->
      assert fixture_rows(snapshot) == List.duplicate(0, 8)

      # Only synthetic children are inserted, and the transaction always rolls
      # back. Their parents are already absent, so joins cannot find these leaks.
      assert {:error, :synthetic_leak_probe} =
               NewYou.Repo.transaction(fn ->
                 NewYou.Repo.query!(
                   "INSERT INTO communications_envelope_nonces (nonce) VALUES ($1)",
                   [hd(snapshot.nonces)]
                 )

                 NewYou.Repo.query!(
                   "INSERT INTO oban_jobs (queue, worker, args) VALUES ('audit', 'NewYou.Audit.Workers.RegistrationEvidence', $1) RETURNING id",
                   [%{"primary_key" => %{"id" => Ecto.UUID.load!(hd(snapshot.obligation_ids))}}]
                 )

                 counts = fixture_rows(snapshot)
                 assert Enum.at(counts, 5) == 1
                 assert Enum.at(counts, 7) == 1
                 refute counts == List.duplicate(0, 8)
                 NewYou.Repo.rollback(:synthetic_leak_probe)
               end)

      assert fixture_rows(snapshot) == List.duplicate(0, 8)
    end)
  end

  test "partial consequence counts find children after fixture parents disappear" do
    alias NewYou.Proof.P805

    P805.with_fixture(fn ->
      request = P805.request()

      assert {:error, :partial_consequence_probe} =
               NewYou.Repo.transaction(fn ->
                 {:ok, _} = NewYou.Identity.register(request)

                 NewYou.Repo.query!(
                   "DELETE FROM registration_operations WHERE operation_id = $1",
                   [Ecto.UUID.dump!(request.operation_id)]
                 )

                 NewYou.Repo.query!(
                   "INSERT INTO communications_envelope_nonces (nonce) VALUES ($1)",
                   [:crypto.strong_rand_bytes(12)]
                 )

                 NewYou.Repo.query!(
                   "INSERT INTO oban_jobs (queue, worker, args) VALUES ('audit', 'NewYou.Audit.Workers.RegistrationEvidence', $1) RETURNING id",
                   [%{"primary_key" => %{"id" => Ecto.UUID.generate()}}]
                 )

                 counts = P805.counts()
                 assert Enum.at(counts, 0) == 1
                 assert Enum.at(counts, 1) == 1
                 assert Enum.at(counts, 6) == 2
                 assert Enum.at(counts, 8) == 2
                 NewYou.Repo.rollback(:partial_consequence_probe)
               end)

      assert Enum.all?(Enum.drop(P805.counts(), -1), &(&1 == 0))
    end)
  end

  test "a fresh recovery process observes parentless replay consequences" do
    alias NewYou.Proof.P805

    P805.with_fixture(fn ->
      task =
        Task.async(fn ->
          :ok = Ecto.Adapters.SQL.Sandbox.checkout(NewYou.Repo, sandbox: false)

          try do
            assert {:error, :replay_probe} =
                     NewYou.Repo.transaction(fn ->
                       before = P805.counts([], [])

                       NewYou.Repo.query!(
                         "INSERT INTO communications_envelope_nonces (nonce) VALUES ($1)",
                         [:crypto.strong_rand_bytes(12)]
                       )

                       assert Enum.at(P805.counts([], []), 6) == Enum.at(before, 6) + 1
                       NewYou.Repo.rollback(:replay_probe)
                     end)
          after
            Ecto.Adapters.SQL.Sandbox.checkin(NewYou.Repo)
          end
        end)

      Task.await(task, 15_000)
    end)
  end

  defp preservation_assertion(:success), do: :ok

  defp preservation_assertion(:assertion_failure),
    do: flunk("synthetic preservation assertion failure")

  defp exercise_preservation(:success, exercise), do: exercise.()

  defp exercise_preservation(:assertion_failure, exercise) do
    assert_raise ExUnit.AssertionError, ~r/synthetic preservation assertion failure/, exercise
  end

  defp with_preserved_registration(callback) do
    alias NewYou.Proof.P805
    operation_id = Ecto.UUID.generate()
    email = "untracked-#{Ecto.UUID.generate()}@example.test"

    # Choose cleanup identities before any committed write can happen.
    # The second fixture runs even when creation or an intermediate assertion fails.
    try do
      {owned, untracked, pmr} =
        P805.with_fixture(fn ->
          request = P805.request()
          {:ok, _} = NewYou.Identity.register(request)
          owned = capture_fixture(request.operation_id, request.email)
          untracked_request = %{request | operation_id: operation_id, email: email}
          {:ok, registration} = NewYou.Identity.register(untracked_request)
          untracked = capture_fixture(operation_id, email)
          assert fixture_rows(owned) == List.duplicate(1, 8)
          assert fixture_rows(untracked) == List.duplicate(1, 8)
          {owned, untracked, P805.account!(registration.account_id).pmr}
        end)

      callback.(owned, untracked, pmr)
    after
      P805.with_fixture(fn -> P805.request(%{operation_id: operation_id, email: email}) end)
    end
  end

  defp capture_fixture(operation_id, email) do
    operation = Ecto.UUID.dump!(operation_id)
    account_ids = fixture_ids("SELECT id FROM accounts WHERE email = $1", [email])

    intent_ids =
      fixture_ids("SELECT id FROM message_intents WHERE source_operation_id = $1", [operation])

    obligation_ids =
      fixture_ids("SELECT id FROM evidence_obligations WHERE source_operation_id = $1", [
        operation
      ])

    primary_keys = Enum.map(intent_ids ++ obligation_ids, &Ecto.UUID.load!/1)

    %{
      operation: operation,
      account_ids: account_ids,
      token_ids:
        fixture_ids("SELECT jti FROM tokens WHERE account_id = ANY($1::uuid[])", [account_ids]),
      intent_ids: intent_ids,
      envelope_ids:
        fixture_ids(
          "SELECT message_intent_id FROM communications_protected_envelopes WHERE message_intent_id = ANY($1::uuid[])",
          [intent_ids]
        ),
      nonces:
        fixture_ids(
          "SELECT nonce FROM communications_protected_envelopes WHERE message_intent_id = ANY($1::uuid[])",
          [intent_ids]
        ),
      obligation_ids: obligation_ids,
      primary_keys: primary_keys,
      job_ids:
        fixture_ids(
          "SELECT id FROM oban_jobs WHERE args->'primary_key'->>'id' = ANY($1::text[])",
          [primary_keys]
        )
    }
  end

  defp fixture_ids(query, parameters) do
    %{rows: rows} = NewYou.Repo.query!(query, parameters)
    Enum.map(rows, &hd/1)
  end

  defp fixture_rows(snapshot) do
    # All child selectors use identities captured while parents still existed.
    # Stable ownership selectors also catch additional same-fixture children.
    queries = [
      {"SELECT count(*) FROM accounts WHERE id = ANY($1::uuid[])", [snapshot.account_ids]},
      {"SELECT count(*) FROM registration_operations WHERE operation_id = $1",
       [snapshot.operation]},
      {"SELECT count(*) FROM tokens WHERE jti = ANY($1::text[]) OR account_id = ANY($2::uuid[])",
       [snapshot.token_ids, snapshot.account_ids]},
      {"SELECT count(*) FROM message_intents WHERE id = ANY($1::uuid[]) OR source_operation_id = $2",
       [snapshot.intent_ids, snapshot.operation]},
      {"SELECT count(*) FROM communications_protected_envelopes WHERE message_intent_id = ANY($1::uuid[]) OR nonce = ANY($2::bytea[])",
       [snapshot.envelope_ids, snapshot.nonces]},
      {"SELECT count(*) FROM communications_envelope_nonces WHERE nonce = ANY($1::bytea[])",
       [snapshot.nonces]},
      {"SELECT count(*) FROM evidence_obligations WHERE id = ANY($1::uuid[]) OR source_operation_id = $2",
       [snapshot.obligation_ids, snapshot.operation]},
      {"SELECT count(*) FROM oban_jobs WHERE id = ANY($1::bigint[]) OR args->'primary_key'->>'id' = ANY($2::text[])",
       [snapshot.job_ids, snapshot.primary_keys]}
    ]

    Enum.map(queries, fn {query, parameters} -> NewYou.Proof.P805.scalar(query, parameters) end)
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
