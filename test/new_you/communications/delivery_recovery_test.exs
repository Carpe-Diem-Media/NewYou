defmodule NewYou.Communications.DeliveryRecoveryTest do
  use ExUnit.Case, async: false

  for {point, cut} <- [
        after_admission: :"transaction.after_commit",
        before_invoke: :"provider.before_invoke",
        after_invoke: :"provider.after_invoke_before_persist"
      ] do
    test "process death at #{point} recovers conservatively" do
      NewYou.Proof.DeliveryRecoveryScenarios.process_death(unquote(point), unquote(cut))
    end
  end

  for prerequisite <- [
        :eligible,
        :content_ineligible,
        :capability_unavailable,
        :provider_unavailable
      ] do
    test "pre-invocation crash recovery rechecks #{prerequisite}" do
      NewYou.Proof.DeliveryRecoveryScenarios.pre_invocation_recheck(unquote(prerequisite))
    end
  end

  test "competing real PostgreSQL executors admit only one provider operation" do
    NewYou.Proof.DeliveryRecoveryScenarios.scenario_competing_real_postgresql_executors_admit_only_one_provider_operation()
  end

  test "real AshOban scheduler discovers zero-job intent and recreates deleted and exhausted jobs" do
    NewYou.Proof.DeliveryRecoveryScenarios.scenario_real_ashoban_scheduler_discovers_zero_job_intent_and_recreates_deleted_and_exhausted_jobs()
  end

  test "admission contenders wait on a real PostgreSQL row lock" do
    NewYou.Proof.DeliveryRecoveryScenarios.scenario_admission_contenders_wait_on_a_real_postgresql_row_lock()
  end

  @tag timeout: 90_000
  test "fresh BEAM discovers missing jobs and preserves accepted ambiguity across another boot" do
    NewYou.Proof.DeliveryRecoveryScenarios.scenario_fresh_beam_discovers_missing_jobs_and_preserves_accepted_ambiguity_across_another_boot()
  end
end
