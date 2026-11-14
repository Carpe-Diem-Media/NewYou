defmodule NewYou.Proof.P818Catalog do
  @moduledoc "Complete P8-18 source-authority bypass-negative family for the shared P8-04 runner."

  @coverage_id "source_authority_bypass_negatives"
  @source "WELL-19; FP-001 P8-18; TB-001 Tracer Bullet family 9"

  @definitions [
    {"provider_observation", "communications_delivery_evidence",
     "identity.provider_evidence_cannot_transition_source",
     ~w(provider_acceptance_did_not_verify authenticated_callback_did_not_verify provider_reference_did_not_create_session recovery_delivery_did_not_complete recovery_delivery_did_not_apply_email email_change_intent_held_without_attempt primary_email_callback_did_not_confirm_or_apply provider_evidence_key_restored)},
    {"stale_browser_authority", "browser_cookie_and_session_projection",
     "identity.revocation_and_supersession_are_current_authority",
     ~w(browser_stale_page_denied_on_reconnect owner_revocation_persisted stale_session_denied_after_reconnect superseded_proof_denied)},
    {"audit_evidence_non_authority", "audit_evidence_and_obligations",
     "identity.audit_evidence_cannot_transition_source",
     ~w(evidence_materialized_once replay_reused_evidence identity_source_unchanged communications_and_privacy_source_unchanged fabricated_evidence_not_source_transition evidence_has_no_repair_action)},
    {"executor_state_non_authority", "oban_and_ashoban_jobs",
     "communications_and_audit_source_resources_required",
     ~w(missing_obligation_rejected missing_intent_rejected all_job_states_rejected_missing_sources source_truth_unchanged)},
    {"signals_coordination_non_authority", "signals_and_pubsub_coordination",
     "identity.signal_requires_owner_transition",
     ~w(signal_received signal_replay_received owner_interface_rejected_forged_signal source_verification_unchanged session_authority_absent)},
    {"analytics_projection", "privacy_to_analytics_derived_projection",
     "privacy.current_suppression_and_analytics_derived_only",
     ~w(current_privacy_read projection_contains_aggregate_only projection_writes_only_own_resource no_source_command_api privacy_authority_rows_cannot_be_deleted projection_failure_preserves_privacy_source withdrawal_suppressed reordered_rebuild_remains_suppressed)},
    {"arc_029_enforcement", "ordinary_application_write_boundary",
     "architecture.arc_029_owner_ash_write_boundary",
     ~w(real_application_clean repo_write_rejected raw_sql_write_rejected ecto_multi_write_rejected parallel_schema_rejected outer_ash_write_rejected parse_error_rejected narrow_exception_retained)}
  ]

  @doc "Return the fixed complete P8-18 family manifest."
  @spec manifests() :: %{String.t() => map()}
  def manifests do
    cases =
      for {name, boundary, invariant_id, assertions} <- @definitions do
        id = "p818." <> name

        %{
          coverage_id: @coverage_id,
          case_id: id,
          invariant_id: invariant_id,
          source: @source,
          boundary: boundary,
          cut_point: nil,
          race_id: nil,
          assertion_ids: Enum.map(assertions, &(id <> "." <> &1)),
          timeout_ms: 60_000,
          timeout_override_reason: "owner-interface proof uses real PostgreSQL fixtures",
          expected: "non-owning state cannot mutate, recreate or authorize source-owned truth"
        }
      end

    manifest = %{
      coverage_id: @coverage_id,
      version: "p8-18.1",
      scope: :complete,
      cases: cases
    }

    digest =
      :crypto.hash(:sha256, :erlang.term_to_binary(manifest, [:deterministic]))
      |> Base.encode16(case: :lower)

    %{@coverage_id => Map.put(manifest, :digest, digest)}
  end

  @doc "Return callback registrations for the fixed P8-18 family."
  @spec registrations() :: [map()]
  def registrations do
    for entry <- manifests()[@coverage_id].cases do
      entry
      |> Map.put(:manifest, entry)
      |> Map.put(:callback, fn -> NewYou.Proof.P818.run(entry.case_id) end)
    end
  end
end
