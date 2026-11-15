defmodule NewYou.Proof.P819Catalog do
  @moduledoc """
  Reviewed TB-001 integration of the upstream proof cases.

  The fixed mapping below closes the partial upstream manifests. Shared scenario
  callbacks retain their original assertions. Their single ledger assertion is
  recorded only after every assertion in that named scenario returns normally.
  A raised assertion, timeout or incomplete cleanup cannot record completion.
  This module owns engineering evidence only, never business or certification authority.
  """
  alias NewYou.Proof.SelfTest

  # This inventory is reviewed separately from the executable @obligations.
  # Never derive or regenerate it when changing a callback declaration.
  @external_resource Path.expand("../../proof/tb001_required_cases.json", __DIR__)
  @required_inventory @external_resource |> File.read!() |> Jason.decode!()

  @upstream_cases %{
    "audit_e1" =>
      ~w(p813.admission_cut p813.capture_failure p813.source_failure p813.same_attempt_race p813.distinct_attempt_race p813.restart p813.crash_after_admission p813.crash_after_source),
    "audit_e2" =>
      ~w(p805.audit_schedule_rollback p805.commit_rollback p811.interrupted_materialisation p811.existing_assertion p811.concurrent_execution p811.restart_backlog),
    "browser_spine" => ~w(p805.browser_en p805.browser_af),
    "proof_capability_scanner_replay_supersession" =>
      ~w(p807.browser_en p807.browser_af p807.consume_race p807.interrupted_consume),
    "registration_pmr_reconciliation" =>
      ~w(p805.accepted p805.rejected p805.envelope_rollback p805.rollback_account p805.rollback_token p805.rollback_intent p805.rollback_nonce p805.rollback_obligation p805.rollback_operation p805.replay_neutrality p805.pmr_collision p805.retired_pmr p805.same_email_race p805.canonical_email_race p805.same_operation_race p805.pmr_collision_race p805.post_commit_recovery p805.resend p805.resend_binding),
    "session_login_revocation_restart" =>
      ~w(p809.reconnect p809.interrupted_issue p809.hold_race p809.beam_restart p809.browser_en p809.browser_af p809.magic_consume_race p809.magic_issue_consume_race p809.magic_restart p812.reset_race p812.stale_login_race p812.interrupted_reset p812.restart),
    "source_authority_bypass_negatives" =>
      ~w(p818.provider_observation p818.stale_browser_authority p818.audit_evidence_non_authority p818.executor_state_non_authority p818.signals_coordination_non_authority p818.analytics_projection p818.arc_029_enforcement)
  }

  @obligations [
    {"registration_pmr_reconciliation", "p819.reconciliation_apply",
     NewYou.Proof.ReconciliationScenarios,
     :scenario_scoped_detection_verified_review_and_apply_preserve_history_and_retire_the_losing_pmr,
     "scoped detection verified review and apply preserve history and retire the losing pmr", nil,
     nil},
    {"registration_pmr_reconciliation", "p819.reconciliation_authorization",
     NewYou.Proof.ReconciliationScenarios,
     :scenario_detection_and_demographic_similarity_cannot_substitute_for_current_verified_control,
     "detection and demographic similarity cannot substitute for current verified control", nil,
     nil},
    {"registration_pmr_reconciliation", "p819.reconciliation_pair_grants",
     NewYou.Proof.ReconciliationScenarios,
     :scenario_loser_only_and_survivor_only_grants_cannot_authorize_the_pair,
     "loser only and survivor only grants cannot authorize the pair", nil, nil},
    {"registration_pmr_reconciliation", "p819.reconciliation_current_grants",
     NewYou.Proof.ReconciliationScenarios,
     :scenario_apply_requires_both_current_target_grants_before_admitting_e1,
     "apply requires both current target grants before admitting e1", nil, nil},
    {"registration_pmr_reconciliation", "p819.reconciliation_history",
     NewYou.Proof.ReconciliationScenarios,
     :scenario_owner_policies_preserve_pending_message_and_audit_provenance_while_current_delivery_fails_closed,
     "owner policies preserve pending message and audit provenance while current delivery fails closed",
     nil, nil},
    {"registration_pmr_reconciliation", "p819.reconciliation_retirement",
     NewYou.Proof.ReconciliationScenarios,
     :scenario_retired_pmr_and_applied_provenance_cannot_be_revived_or_rewritten,
     "retired pmr and applied provenance cannot be revived or rewritten", nil, nil},
    {"registration_pmr_reconciliation", "p819.reconciliation_restart",
     NewYou.Proof.ReconciliationScenarios,
     :scenario_expired_approval_denies_retries_and_a_fresh_beam_reconstructs_re_review_recovery,
     "expired approval denies retries and a fresh beam reconstructs re review recovery", nil,
     nil},
    {"registration_pmr_reconciliation", "p819.reconciliation_pmr_race",
     NewYou.Proof.ReconciliationScenarios,
     :scenario_concurrent_registration_cannot_allocate_a_pmr_being_retired_by_reconciliation,
     "concurrent registration cannot allocate a pmr being retired by reconciliation", nil,
     "p819.reconciliation_pmr_race"},
    {"communications_durability_backlog_ambiguity", "p819.comm_admission",
     NewYou.Proof.DeliveryScenarios,
     :scenario_admission_commits_before_provider_i_o_and_delivery_never_verifies_identity,
     "admission commits before provider i o and delivery never verifies identity", nil, nil},
    {"communications_durability_backlog_ambiguity", "p819.comm_ambiguity",
     NewYou.Proof.DeliveryScenarios,
     :scenario_unknown_blocks_blind_retry_and_only_authenticated_no_operation_allows_a_new_attempt,
     "unknown blocks blind retry and only authenticated no operation allows a new attempt", nil,
     nil},
    {"communications_durability_backlog_ambiguity", "p819.comm_current_source",
     NewYou.Proof.DeliveryScenarios,
     :scenario_consumed_source_closes_send_authority_and_destroys_the_envelope,
     "consumed source closes send authority and destroys the envelope", nil, nil},
    {"communications_durability_backlog_ambiguity", "p819.comm_ambiguity_invalidation",
     NewYou.Proof.DeliveryScenarios,
     :scenario_source_invalidation_during_unresolved_delivery_clears_secrets_without_permitting_retry,
     "source invalidation during unresolved delivery clears secrets without permitting retry",
     nil, nil},
    {"communications_durability_backlog_ambiguity", "p819.comm_no_outer_transaction",
     NewYou.Proof.DeliveryScenarios, :scenario_outer_transactions_cannot_encompass_provider_i_o,
     "outer transactions cannot encompass provider i o", nil, nil},
    {"communications_durability_backlog_ambiguity", "p819.comm_pre_invoke_guard",
     NewYou.Proof.DeliveryScenarios,
     :scenario_consumption_between_admission_and_invocation_truthfully_closes_the_uninvoked_attempt,
     "consumption between admission and invocation truthfully closes the uninvoked attempt", nil,
     nil},
    {"communications_durability_backlog_ambiguity", "p819.comm_concurrent_execution",
     NewYou.Proof.DeliveryRecoveryScenarios,
     :scenario_competing_real_postgresql_executors_admit_only_one_provider_operation,
     "competing real postgresql executors admit only one provider operation", nil,
     "p819.comm_concurrent_execution"},
    {"communications_durability_backlog_ambiguity", "p819.comm_scheduler",
     NewYou.Proof.DeliveryRecoveryScenarios,
     :scenario_real_ashoban_scheduler_discovers_zero_job_intent_and_recreates_deleted_and_exhausted_jobs,
     "real ashoban scheduler discovers zero job intent and recreates deleted and exhausted jobs",
     nil, nil},
    {"communications_durability_backlog_ambiguity", "p819.comm_row_lock",
     NewYou.Proof.DeliveryRecoveryScenarios,
     :scenario_admission_contenders_wait_on_a_real_postgresql_row_lock,
     "admission contenders wait on a real postgresql row lock", nil, "p819.comm_row_lock"},
    {"communications_durability_backlog_ambiguity", "p819.comm_restart",
     NewYou.Proof.DeliveryRecoveryScenarios,
     :scenario_fresh_beam_discovers_missing_jobs_and_preserves_accepted_ambiguity_across_another_boot,
     "fresh beam discovers missing jobs and preserves accepted ambiguity across another boot",
     nil, nil},
    {"communications_durability_backlog_ambiguity", "p819.comm_crash_after_admission",
     NewYou.Proof.P819, :comm_crash_after_admission,
     "process death at after_admission recovers conservatively", "transaction.after_commit", nil},
    {"communications_durability_backlog_ambiguity", "p819.comm_crash_before_invoke",
     NewYou.Proof.P819, :comm_crash_before_invoke,
     "process death at before_invoke recovers conservatively", "provider.before_invoke", nil},
    {"communications_durability_backlog_ambiguity", "p819.comm_crash_after_invoke",
     NewYou.Proof.P819, :comm_crash_after_invoke,
     "process death at after_invoke recovers conservatively",
     "provider.after_invoke_before_persist", nil},
    {"communications_durability_backlog_ambiguity", "p819.comm_recheck_eligible",
     NewYou.Proof.P819, :comm_recheck_eligible, "pre invocation crash recovery rechecks eligible",
     "transaction.after_commit", nil},
    {"communications_durability_backlog_ambiguity", "p819.comm_recheck_content_ineligible",
     NewYou.Proof.P819, :comm_recheck_content_ineligible,
     "pre invocation crash recovery rechecks content_ineligible", "transaction.after_commit",
     nil},
    {"communications_durability_backlog_ambiguity", "p819.comm_recheck_capability_unavailable",
     NewYou.Proof.P819, :comm_recheck_capability_unavailable,
     "pre invocation crash recovery rechecks capability_unavailable", "transaction.after_commit",
     nil},
    {"communications_durability_backlog_ambiguity", "p819.comm_recheck_provider_unavailable",
     NewYou.Proof.P819, :comm_recheck_provider_unavailable,
     "pre invocation crash recovery rechecks provider_unavailable", "transaction.after_commit",
     nil},
    {"recovery_primary_email_change", "p819.recovery_lifecycle", NewYou.Proof.RecoveryScenarios,
     :scenario_explicit_proof_acceptance_and_completion_are_separate_durable_and_replay_safe,
     "explicit proof acceptance and completion are separate durable and replay safe", nil, nil},
    {"recovery_primary_email_change", "p819.recovery_rollback", NewYou.Proof.RecoveryScenarios,
     :scenario_proof_and_assurance_rollback_together_at_the_existing_source_transaction_cut,
     "proof and assurance rollback together at the existing source transaction cut",
     "transaction.before_commit", nil},
    {"recovery_primary_email_change", "p819.recovery_assurance", NewYou.Proof.RecoveryScenarios,
     :scenario_duplicates_reuse_one_case_and_never_lower_the_required_assurance,
     "duplicates reuse one case and never lower the required assurance", nil, nil},
    {"recovery_primary_email_change", "p819.recovery_terminal", NewYou.Proof.RecoveryScenarios,
     :scenario_cancelled_expired_and_stale_security_cases_remain_terminal,
     "cancelled expired and stale security cases remain terminal", nil, nil},
    {"recovery_primary_email_change", "p819.recovery_completion_rollback",
     NewYou.Proof.RecoveryScenarios,
     :scenario_completion_failure_rolls_back_credential_and_keeps_its_durable_e2_and_notice_absent,
     "completion failure rolls back credential and keeps its durable e2 and notice absent",
     "transaction.before_commit", nil},
    {"recovery_primary_email_change", "p819.recovery_purpose", NewYou.Proof.RecoveryScenarios,
     :scenario_foreign_purpose_and_unauthorized_ash_access_cannot_advance_a_case,
     "foreign purpose and unauthorized ash access cannot advance a case", nil, nil},
    {"recovery_primary_email_change", "p819.recovery_revocation", NewYou.Proof.RecoveryScenarios,
     :scenario_revoked_proof_and_reused_credentials_fail_without_creating_authority,
     "revoked proof and reused credentials fail without creating authority", nil, nil},
    {"recovery_primary_email_change", "p819.recovery_secrets", NewYou.Proof.RecoveryScenarios,
     :scenario_recovery_bearer_and_replacement_input_never_enter_cases_notices_audit_or_jobs,
     "recovery bearer and replacement input never enter cases notices audit or jobs", nil, nil},
    {"recovery_primary_email_change", "p819.recovery_duplicate_request_race", NewYou.Proof.P815,
     :duplicate_request_race, "recovery duplicate request race", nil,
     "p819.recovery_duplicate_request_race"},
    {"recovery_primary_email_change", "p819.recovery_assurance_race", NewYou.Proof.P815,
     :assurance_race, "recovery assurance race", nil, "p819.recovery_assurance_race"},
    {"recovery_primary_email_change", "p819.recovery_completion_race", NewYou.Proof.P815,
     :completion_race, "recovery completion race", nil, "p819.recovery_completion_race"},
    {"recovery_primary_email_change", "p819.recovery_stale_login_race", NewYou.Proof.P815,
     :stale_login_race, "recovery stale login race", nil, "p819.recovery_stale_login_race"},
    {"recovery_primary_email_change", "p819.recovery_reset_vs_recovery_race", NewYou.Proof.P815,
     :reset_vs_recovery_race, "recovery reset vs recovery race", nil,
     "p819.recovery_reset_vs_recovery_race"},
    {"recovery_primary_email_change", "p819.recovery_interrupted_acceptance", NewYou.Proof.P815,
     :interrupted_acceptance, "recovery interrupted acceptance", "transaction.before_commit",
     nil},
    {"recovery_primary_email_change", "p819.recovery_restart_proof", NewYou.Proof.P815,
     :restart_proof, "recovery restart proof", nil, nil},
    {"recovery_primary_email_change", "p819.recovery_unverified_restart_proof", NewYou.Proof.P815,
     :unverified_restart_proof, "recovery unverified restart proof", nil, nil},
    {"recovery_primary_email_change", "p819.email_request", NewYou.Proof.EmailChangeScenarios,
     :scenario_request_and_fresh_password_reauthentication_create_one_pending_proof_without_changing_canonical_email,
     "request and fresh password reauthentication create one pending proof without changing canonical email",
     nil, nil},
    {"recovery_primary_email_change", "p819.email_mfa", NewYou.Proof.EmailChangeScenarios,
     :scenario_active_mfa_requires_purpose_bound_totp_step_up_before_issuing_an_email_change_proof,
     "active mfa requires purpose bound totp step up before issuing an email change proof", nil,
     nil},
    {"recovery_primary_email_change", "p819.email_apply", NewYou.Proof.EmailChangeScenarios,
     :scenario_guarded_apply_changes_the_canonical_email_and_commits_security_consequences_once,
     "guarded apply changes the canonical email and commits security consequences once", nil,
     nil},
    {"recovery_primary_email_change", "p819.email_restart", NewYou.Proof.EmailChangeScenarios,
     :scenario_a_confirmed_change_resumes_and_applies_after_a_fresh_beam_restart,
     "a confirmed change resumes and applies after a fresh beam restart", nil, nil},
    {"recovery_primary_email_change", "p819.email_recovery_race",
     NewYou.Proof.EmailChangeScenarios,
     :scenario_primary_email_apply_and_recovery_completion_serialize_in_both_postgresql_commit_orders,
     "primary email apply and recovery completion serialize in both postgresql commit orders",
     nil, "p819.email_recovery_race"},
    {"recovery_primary_email_change", "p819.email_logout_race", NewYou.Proof.EmailChangeScenarios,
     :scenario_competing_session_logout_and_primary_email_apply_serialize_against_current_authority,
     "competing session logout and primary email apply serialize against current authority", nil,
     "p819.email_logout_race"},
    {"recovery_primary_email_change", "p819.email_cancel", NewYou.Proof.EmailChangeScenarios,
     :scenario_cancellation_revokes_the_proof_and_leaves_the_canonical_address_unchanged,
     "cancellation revokes the proof and leaves the canonical address unchanged", nil, nil},
    {"recovery_primary_email_change", "p819.email_supersession",
     NewYou.Proof.EmailChangeScenarios,
     :scenario_a_newer_accepted_operation_supersedes_the_old_proof_and_remains_the_only_current_operation,
     "a newer accepted operation supersedes the old proof and remains the only current operation",
     nil, nil},
    {"recovery_primary_email_change", "p819.email_expiry", NewYou.Proof.EmailChangeScenarios,
     :scenario_expiry_terminalizes_the_durable_operation_and_revokes_its_proof,
     "expiry terminalizes the durable operation and revokes its proof", nil, nil},
    {"recovery_primary_email_change", "p819.email_hold", NewYou.Proof.EmailChangeScenarios,
     :scenario_a_current_security_hold_terminalizes_the_change_without_applying_its_target,
     "a current security hold terminalizes the change without applying its target", nil, nil},
    {"recovery_primary_email_change", "p819.email_session", NewYou.Proof.EmailChangeScenarios,
     :scenario_confirmed_operation_cannot_apply_after_its_originating_session_is_revoked,
     "confirmed operation cannot apply after its originating session is revoked", nil, nil},
    {"recovery_primary_email_change", "p819.email_notices", NewYou.Proof.EmailChangeScenarios,
     :scenario_development_only_email_change_intents_remain_held_and_never_reach_a_provider,
     "development only email change intents remain held and never reach a provider", nil, nil},
    {"non_enumeration_current_privacy", "p819.privacy_missing", NewYou.Proof.EmailChangeScenarios,
     :scenario_proof_only_protected_mutation_denies_when_current_privacy_authority_is_missing,
     "proof only protected mutation denies when current privacy authority is missing", nil, nil},
    {"non_enumeration_current_privacy", "p819.privacy_withdraw_first",
     NewYou.Proof.EmailChangeScenarios,
     :scenario_committed_privacy_withdrawal_wins_before_identity_s_current_mutation_check,
     "committed privacy withdrawal wins before identity s current mutation check", nil,
     "p819.privacy_withdraw_first"},
    {"non_enumeration_current_privacy", "p819.privacy_apply_first",
     NewYou.Proof.EmailChangeScenarios,
     :scenario_identity_mutation_committed_first_serializes_before_privacy_withdrawal,
     "identity mutation committed first serializes before privacy withdrawal", nil,
     "p819.privacy_apply_first"},
    {"non_enumeration_current_privacy", "p819.privacy_restart", NewYou.Proof.EmailChangeScenarios,
     :scenario_withdrawn_privacy_authority_remains_denied_after_a_fresh_beam_restart,
     "withdrawn privacy authority remains denied after a fresh beam restart", nil, nil},
    {"non_enumeration_current_privacy", "p819.privacy_unavailable",
     NewYou.Proof.EmailChangeScenarios,
     :scenario_identity_fails_closed_when_its_current_privacy_read_is_unavailable,
     "identity fails closed when its current privacy read is unavailable", nil, nil},
    {"proof_capability_scanner_replay_supersession", "p819.recovery_scanner",
     NewYou.Proof.WebScenarios, :recovery_scanner, "recovery scanner", nil, nil},
    {"proof_capability_scanner_replay_supersession", "p819.reset_scanner",
     NewYou.Proof.WebScenarios, :reset_browser, "reset browser", nil, nil},
    {"proof_capability_scanner_replay_supersession", "p819.email_scanner",
     NewYou.Proof.EmailChangeScenarios,
     :scenario_passive_retrieval_is_inert_and_explicit_csrf_confirmation_does_not_apply_the_email,
     "passive retrieval is inert and explicit csrf confirmation does not apply the email", nil,
     nil},
    {"non_enumeration_current_privacy", "p819.login_neutral", NewYou.Proof.WebScenarios,
     :login_neutral, "login neutral", nil, nil},
    {"non_enumeration_current_privacy", "p819.recovery_neutral", NewYou.Proof.WebScenarios,
     :recovery_neutral, "recovery neutral", nil, nil},
    {"non_enumeration_current_privacy", "p819.support_minimum", NewYou.Proof.WebScenarios,
     :support_lookup, "support lookup", nil, nil},
    {"non_enumeration_current_privacy", "p819.recovery_window", NewYou.Proof.RecoveryScenarios,
     :scenario_a_locked_known_account_cannot_extend_the_neutral_public_request_window,
     "a locked known account cannot extend the neutral public request window", nil, nil},
    {"non_enumeration_current_privacy", "p819.registration_neutral", NewYou.Proof.P819,
     :registration_neutral,
     "registration response remains neutral for new and existing canonical email", nil, nil},
    {"browser_spine", "p819.browser_en", NewYou.Proof.P819, :browser_en,
     "continuous registration PMR verification password login and Session reconstruction en", nil,
     nil},
    {"browser_spine", "p819.browser_af", NewYou.Proof.P819, :browser_af,
     "continuous registration PMR verification password login and Session reconstruction af", nil,
     nil},
    {"proof_capability_scanner_replay_supersession", "p819.verification_passive",
     NewYou.Proof.VerificationScannerCases, :scanner,
     "GET HEAD preview scanner and prefetch leave verification passive until explicit CSRF confirmation",
     nil, nil},
    {"proof_capability_scanner_replay_supersession", "p819.reset_passive",
     NewYou.Proof.ResetScannerCases, :scanner,
     "GET HEAD preview scanner and prefetch leave reset passive until explicit CSRF confirmation",
     nil, nil},
    {"proof_capability_scanner_replay_supersession", "p819.magic_passive",
     NewYou.Proof.MagicScannerCases, :scanner,
     "GET HEAD preview scanner and prefetch leave magic login passive until explicit CSRF confirmation",
     nil, nil},
    {"proof_capability_scanner_replay_supersession", "p819.verification_lifecycle",
     NewYou.Proof.VerificationCases, :fail_closed,
     "wrong purpose expiry revocation supersession and replay fail closed for verification", nil,
     nil},
    {"proof_capability_scanner_replay_supersession", "p819.reset_lifecycle",
     NewYou.Proof.ResetCases, :fail_closed,
     "wrong purpose expiry revocation supersession and replay fail closed for reset", nil, nil},
    {"proof_capability_scanner_replay_supersession", "p819.magic_lifecycle",
     NewYou.Proof.MagicCases, :fail_closed,
     "expiry revocation supersession and replay fail closed for magic login", nil, nil}
  ]

  @doc false
  def manifests(upstream) do
    additions = Enum.group_by(cases(), & &1.coverage_id)

    Map.new(NewYou.Proof.Catalog.coverage_inventory(), fn family ->
      prior = get_in(upstream, [family, :cases]) || []
      expected_prior = Map.get(@upstream_cases, family, [])
      all_cases = prior ++ Map.get(additions, family, [])
      identities = Enum.map(all_cases, &[&1.case_id, &1.invariant_id])
      required = @required_inventory["families"][family]["cases"]

      scope =
        if Enum.sort(Enum.map(prior, & &1.case_id)) == Enum.sort(expected_prior) and
             Enum.sort(identities) == Enum.sort(required),
           do: :complete,
           else: :partial

      manifest = %{
        coverage_id: family,
        version: "tb001.p8-19.2",
        scope: scope,
        cases: all_cases
      }

      digest =
        :crypto.hash(:sha256, :erlang.term_to_binary(manifest, [:deterministic]))
        |> Base.encode16(case: :lower)

      {family, Map.put(manifest, :digest, digest)}
    end)
  end

  @doc false
  def registrations do
    for {family, id, module, function, _, _, _} <- @obligations do
      manifest = Enum.find(cases(), &(&1.case_id == id))

      %{
        coverage_id: family,
        case_id: id,
        invariant_id: id,
        manifest: manifest,
        callback: fn ->
          apply(module, function, [])
          SelfTest.expect_manifest!(id <> ".owner_assertions", true, true)
          SelfTest.observe_manifest!("owner.assertions_verified", true)
        end
      }
    end
  end

  defp boundary(NewYou.Proof.P819, function) when function in [:browser_en, :browser_af],
    do: "chromium_phoenix_identity_postgresql"

  defp boundary(NewYou.Proof.WebScenarios, :reset_browser),
    do: "chromium_phoenix_identity_postgresql"

  defp boundary(NewYou.Proof.WebScenarios, :support_lookup), do: "owning_ash_postgresql"

  defp boundary(NewYou.Proof.P819, :registration_neutral),
    do: "phoenix_conntest_identity_postgresql"

  defp boundary(
         NewYou.Proof.EmailChangeScenarios,
         :scenario_passive_retrieval_is_inert_and_explicit_csrf_confirmation_does_not_apply_the_email
       ),
       do: "phoenix_conntest_identity_postgresql"

  defp boundary(module, _)
       when module in [
              NewYou.Proof.WebScenarios,
              NewYou.Proof.VerificationScannerCases,
              NewYou.Proof.ResetScannerCases,
              NewYou.Proof.MagicScannerCases
            ],
       do: "phoenix_conntest_identity_postgresql"

  defp boundary(_, _), do: "owning_ash_postgresql"

  @doc false
  def cases do
    for {family, id, module, function, expected, cut, race} <- @obligations do
      %{
        coverage_id: family,
        case_id: id,
        invariant_id: id,
        source: "TB-001 section 8; #{inspect(module)}.#{function}/0",
        boundary: boundary(module, function),
        cut_point: cut,
        race_id: race,
        assertion_ids: [id <> ".owner_assertions"],
        timeout_ms: 120_000,
        timeout_override_reason:
          "existing owner assertions, PostgreSQL races and bounded fresh BEAM/browser probes",
        expected: expected
      }
    end
  end
end
