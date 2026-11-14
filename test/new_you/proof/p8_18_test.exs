defmodule NewYou.Proof.P818Test do
  use ExUnit.Case, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias NewYou.Privacy
  alias NewYou.Proof.{Catalog, FullCatalog, P805}

  require Ash.Query

  @coverage_id "source_authority_bypass_negatives"
  @case_ids ~w(
    p818.provider_observation
    p818.stale_browser_authority
    p818.audit_evidence_non_authority
    p818.executor_state_non_authority
    p818.signals_coordination_non_authority
    p818.analytics_projection
    p818.arc_029_enforcement
  )

  test "P8-18 registers the complete source-authority negative family" do
    manifests = Catalog.required().business_manifests
    family = manifests[@coverage_id]
    registrations = Catalog.compiled_business_registrations()

    assert family.scope == :complete
    assert Enum.sort(Enum.map(family.cases, & &1.case_id)) == Enum.sort(@case_ids)

    assert Enum.all?(
             family.cases,
             &(is_binary(&1.invariant_id) and &1.invariant_id != &1.case_id)
           )

    assert Enum.sort(
             registrations
             |> Enum.filter(&(&1.coverage_id == @coverage_id))
             |> Enum.map(& &1.case_id)
           ) == Enum.sort(@case_ids)

    assert :ok = Catalog.validate_compiled_registrations(manifests, registrations)
    refute @coverage_id in Catalog.validate_registrations(registrations, :tb001).missing_families
  end

  test "the minimum Analytics projection reads current Privacy authority and stores no identifiers" do
    assert Code.ensure_loaded?(NewYou.Analytics)
    assert Code.ensure_loaded?(NewYou.Analytics.P817PrivacyProjection)
    assert function_exported?(NewYou.Analytics, :rebuild_p817_privacy_projection, 0)

    assert documented_and_typed?(
             NewYou.Analytics,
             :rebuild_p817_privacy_projection,
             0
           )

    assert documented_and_typed?(NewYou.Privacy, :current_p817_proof_purpose_count, 0)
    assert documented_and_typed?(NewYou.Privacy, :current_p817_proof_purpose_snapshot, 0)

    refute function_exported?(NewYou.Analytics, :verify_identity, 1)
    refute function_exported?(NewYou.Analytics, :complete_recovery, 2)
    refute function_exported?(NewYou.Analytics, :apply_primary_email_change, 1)

    P805.with_fixture(fn ->
      subject_id = Ecto.UUID.generate()
      operation_id = Ecto.UUID.generate()
      P805.track_operation(operation_id)
      assert {:ok, baseline} = Privacy.current_p817_proof_purpose_snapshot()

      assert {:ok, :allowed} = Privacy.grant_p817_proof_purpose(subject_id, operation_id)
      assert :ok = NewYou.Analytics.rebuild_p817_privacy_projection()

      projection = only_projection()
      assert projection.current_allowed_count == baseline.current_allowed_count + 1

      refute Enum.any?(
               projection_fields(),
               &(&1 in [:subject_id, :source_operation_id, :account_id])
             )

      assert {:ok, :withdrawn} = Privacy.withdraw_p817_proof_purpose(subject_id, operation_id)
      assert :ok = NewYou.Analytics.rebuild_p817_privacy_projection()
      assert only_projection().current_allowed_count == baseline.current_allowed_count

      assert {:error, :withdrawn} = Privacy.grant_p817_proof_purpose(subject_id, operation_id)
      assert :ok = NewYou.Analytics.rebuild_p817_privacy_projection()
      assert only_projection().current_allowed_count == baseline.current_allowed_count
    end)
  end

  test "proof fixture cleanup deletes only its own Analytics projection key" do
    P805.with_fixture(fn ->
      fixture_key = P805.analytics_projection_key()
      other_key = "p817_test_" <> Ecto.UUID.generate()
      scope_key = {NewYou.Analytics, :p817_test_projection_key}

      try do
        Process.put(scope_key, fixture_key)
        assert :ok = NewYou.Analytics.rebuild_p817_privacy_projection()

        Process.put(scope_key, other_key)
        assert :ok = NewYou.Analytics.rebuild_p817_privacy_projection()
        assert projection_keys([fixture_key, other_key]) == Enum.sort([fixture_key, other_key])

        assert :ok = P805.cleanup_test_analytics_projection(fixture_key)
        assert projection_keys([fixture_key, other_key]) == [other_key]
      after
        Process.put(scope_key, fixture_key)
        :ok = P805.cleanup_test_analytics_projection(other_key)
      end
    end)
  end

  test "the database rejects a negative Analytics privacy revision" do
    P805.with_fixture(fn ->
      assert :ok = NewYou.Analytics.rebuild_p817_privacy_projection()
      projection_key = P805.analytics_projection_key()

      assert_raise Postgrex.Error, fn ->
        NewYou.Repo.query!(
          "UPDATE p817_privacy_projections SET privacy_revision = -1 WHERE projection_key = $1",
          [projection_key]
        )
      end

      assert only_projection().privacy_revision >= 0
    end)
  end

  test "fixture setup failure restores environment and Analytics fixture key" do
    projection_scope_key = {NewYou.Analytics, :p817_test_projection_key}
    setup_hook_key = {P805, :setup_checkpoint}
    fixture_key = "p817_test_" <> Ecto.UUID.generate()
    prior_fixture_key = Process.get(projection_scope_key, :missing)
    prior_environment = Application.fetch_env(:new_you, :p8_05_browser_development_fixtures)

    try do
      Process.put(projection_scope_key, fixture_key)

      Process.put(setup_hook_key, fn
        :sandbox_checked_out -> raise "injected P8-05 setup failure"
        _stage -> :ok
      end)

      assert_raise RuntimeError, "injected P8-05 setup failure", fn ->
        P805.with_fixture(fn -> flunk("fixture callback should not run after setup failure") end)
      end

      assert Application.fetch_env(:new_you, :p8_05_browser_development_fixtures) ==
               prior_environment

      assert Process.get(projection_scope_key) == fixture_key
      refute Process.get({P805, :guardian})
      refute Process.get({P805, :fixture_checked_out})
      refute Process.get(setup_hook_key)
    after
      case prior_fixture_key do
        :missing -> Process.delete(projection_scope_key)
        previous -> Process.put(projection_scope_key, previous)
      end

      Process.delete(setup_hook_key)
    end
  end

  test "a stale overlapping Analytics rebuild cannot replace a newer Privacy snapshot" do
    P805.with_fixture(fn ->
      subject_id = Ecto.UUID.generate()
      operation_id = Ecto.UUID.generate()
      P805.track_operation(operation_id)
      assert {:ok, baseline} = Privacy.current_p817_proof_purpose_snapshot()

      assert {:ok, :allowed} = Privacy.grant_p817_proof_purpose(subject_id, operation_id)
      assert :ok = NewYou.Analytics.rebuild_p817_privacy_projection()

      parent = self()
      pause_key = {NewYou.Analytics, :after_privacy_snapshot}
      projection_key = P805.analytics_projection_key()
      projection_scope_key = {NewYou.Analytics, :p817_test_projection_key}
      task_registry_key = {__MODULE__, :p818_rebuild_tasks}

      first =
        Task.async(fn ->
          :ok = Sandbox.checkout(NewYou.Repo, sandbox: false)
          Process.put(projection_scope_key, projection_key)

          Process.put(pause_key, fn snapshot ->
            send(parent, {:first_privacy_snapshot, snapshot})

            receive do
              :continue_first_rebuild -> :ok
            after
              5_000 -> raise "timed out waiting to resume the first projection rebuild"
            end
          end)

          try do
            NewYou.Analytics.rebuild_p817_privacy_projection()
          after
            Process.delete(pause_key)
            Process.delete(projection_scope_key)
            :ok = Sandbox.checkin(NewYou.Repo)
          end
        end)

      Process.put(task_registry_key, [first])

      try do
        assert_receive {:first_privacy_snapshot, first_snapshot}, 5_000
        assert first_snapshot.current_allowed_count == baseline.current_allowed_count + 1
        assert first_snapshot.revision > baseline.revision
        assert {:ok, :withdrawn} = Privacy.withdraw_p817_proof_purpose(subject_id, operation_id)

        second =
          Task.async(fn ->
            :ok = Sandbox.checkout(NewYou.Repo, sandbox: false)
            Process.put(projection_scope_key, projection_key)

            Process.put(pause_key, fn snapshot ->
              send(parent, {:second_privacy_snapshot, snapshot})
              :ok
            end)

            send(parent, :second_rebuild_started)

            try do
              NewYou.Analytics.rebuild_p817_privacy_projection()
            after
              Process.delete(pause_key)
              Process.delete(projection_scope_key)
              :ok = Sandbox.checkin(NewYou.Repo)
            end
          end)

        Process.put(task_registry_key, [first, second])
        assert_receive :second_rebuild_started, 5_000

        assert_receive {:second_privacy_snapshot, second_snapshot}, 5_000
        assert second_snapshot.current_allowed_count == baseline.current_allowed_count
        assert second_snapshot.revision > first_snapshot.revision
        assert :ok = Task.await(second, 5_000)

        send(first.pid, :continue_first_rebuild)
        assert :ok = Task.await(first, 5_000)
        assert only_projection().current_allowed_count == baseline.current_allowed_count
      after
        tasks = Process.get(task_registry_key, [])
        Process.delete(task_registry_key)
        stop_rebuild_tasks(tasks, first.pid)
      end
    end)
  end

  test "the complete P8-18 callbacks pass through the shared P8-04 runner" do
    manifests = Catalog.required().business_manifests
    previous_provider = Process.get(:p810_provider, :missing)
    provider = fn _, _ -> :accepted end

    registrations =
      Catalog.compiled_business_registrations()
      |> Enum.filter(&(&1.coverage_id == @coverage_id))

    try do
      Process.put(:p810_provider, provider)

      assert {:ok, observations, cleanup} =
               FullCatalog.execute(%{@coverage_id => manifests[@coverage_id]}, registrations)

      failures = Enum.reject(observations, &(&1["verdict"] == "PASS"))
      assert failures == [], "P8-18 family failures: #{inspect(failures, limit: :infinity)}"
      assert Enum.sort(Enum.map(observations, & &1["case_id"])) == Enum.sort(@case_ids)
      assert Enum.all?(observations, &(&1["status"] == "completed"))

      for observation <- observations do
        manifest =
          Enum.find(manifests[@coverage_id].cases, &(&1.case_id == observation["case_id"]))

        assert observation["invariant_id"] == manifest.invariant_id
        assert observation["assertion_ids"] == manifest.assertion_ids
        assert observation["assertions_executed"] == length(manifest.assertion_ids)
      end

      assert cleanup["verdict"] == "PASS"
      assert Process.get(:p810_provider) == provider
    after
      case previous_provider do
        :missing -> Process.delete(:p810_provider)
        previous -> Process.put(:p810_provider, previous)
      end
    end
  end

  defp only_projection do
    resource = NewYou.Analytics.P817PrivacyProjection
    projection_key = P805.analytics_projection_key()

    assert [projection] =
             resource
             |> Ash.Query.filter(projection_key == ^projection_key)
             |> Ash.read!(authorize?: false)

    projection
  end

  defp projection_keys(keys) do
    NewYou.Analytics.P817PrivacyProjection
    |> Ash.Query.filter(projection_key in ^keys)
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.projection_key)
    |> Enum.sort()
  end

  defp projection_fields do
    NewYou.Analytics.P817PrivacyProjection
    |> Ash.Resource.Info.attributes()
    |> Enum.map(& &1.name)
  end

  defp stop_rebuild_tasks(tasks, first_pid) do
    Enum.each(tasks, fn task ->
      if task.pid == first_pid, do: send(task.pid, :continue_first_rebuild)

      if Process.alive?(task.pid) do
        try do
          Task.await(task, 10_000)
        rescue
          _error -> :ok
        catch
          :exit, {:timeout, _details} ->
            raise "P8-18 Analytics rebuild worker did not settle after release"

          :exit, _reason ->
            :ok
        end
      else
        _ = Task.yield(task, 0)
      end
    end)
  end

  defp documented_and_typed?(module, function, arity) do
    {:ok, specs} = Code.Typespec.fetch_specs(module)

    has_spec? =
      Enum.any?(specs, fn {{name, spec_arity}, _} ->
        name == function and spec_arity == arity
      end)

    {:docs_v1, _, _, _, moduledoc, _, docs} = Code.fetch_docs(module)
    module_doc? = is_map(moduledoc) and is_binary(Map.get(moduledoc, "en"))

    function_doc? =
      Enum.any?(docs, fn
        {{:function, ^function, ^arity}, _, _, doc, _} ->
          is_map(doc) and is_binary(Map.get(doc, "en"))

        _ ->
          false
      end)

    has_spec? and module_doc? and function_doc?
  end
end
