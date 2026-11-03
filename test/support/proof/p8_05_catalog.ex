defmodule NewYou.Proof.P805Catalog do
  @moduledoc """
  WELL-53 mappings for P8-05 only. Family names are the fixed TB-001 inventory;
  these cases do not certify later reconciliation, materialisation or delivery.
  """

  @registration "registration_pmr_reconciliation"
  @audit "audit_e2"
  @browser "browser_spine"
  @definitions [
    {@registration, "accepted",
     ~w(account_fields credential_same_transition raw_password_absent complete_consequences audit_minimum_reference zero_communications_jobs no_execution protected_capability_private)},
    {@registration, "rejected",
     ~w(credential required_fields age terms privacy no_partial_consequences)},
    {@registration, "envelope_rollback", ~w(cut_reached unavailable no_partial_consequences)},
    {@audit, "audit_schedule_rollback", ~w(cut_reached unavailable no_partial_consequences)},
    {@audit, "commit_rollback",
     ~w(cut_reached complete_before_cut unavailable no_partial_consequences)},
    {@registration, "replay_neutrality",
     ~w(same_operation changed_input duplicate_neutral no_duplicate_consequences)},
    {@registration, "pmr_collision",
     ~w(unique collision_retried bounded_exhaustion no_partial_consequences)},
    {@registration, "same_email_race",
     ~w(independent_connections independent_transactions contention one_account neutral_results no_duplicate_consequences fresh_owner_read)},
    {@registration, "resend",
     ~w(separate_binding superseded one_new_intent protected_envelope zero_communications_jobs no_resend_audit discoverable idempotent)},
    {@registration, "resend_binding",
     ~w(unknown_neutral immutable_binding terminal_replay ineligible_neutral)},
    {@browser, "browser_en",
     ~w(approved_copy required_form legal_artifacts submitted_acceptances pending_copy explicit_resend locale_no_fallback no_session)},
    {@browser, "browser_af",
     ~w(approved_copy required_form legal_artifacts submitted_acceptances pending_copy explicit_resend locale_no_fallback no_session)}
  ]

  def manifests do
    @definitions
    |> Enum.map(fn {family, name, assertions} ->
      case_id = "p805." <> name

      %{
        coverage_id: family,
        case_id: case_id,
        invariant_id: "p805." <> name,
        source: "WELL-53; P8-05 registration JIT; TB-001 section 8",
        boundary:
          if(family == @browser, do: "phoenix_identity_postgresql", else: "owning_ash_postgresql"),
        cut_point: cut(name),
        race_id: if(name == "same_email_race", do: "p805.same_email", else: nil),
        assertion_ids: Enum.map(assertions, &(case_id <> "." <> &1)),
        timeout_ms: 60_000,
        timeout_override_reason:
          "bounded real password hashing and PostgreSQL owner transactions",
        expected:
          "P8-05 #{name} satisfies its named obligations through the real owner path; later TB-001 slices are outside this mapping"
      }
    end)
    |> Enum.group_by(& &1.coverage_id)
    |> Map.new(fn {family, cases} ->
      manifest = %{coverage_id: family, version: "p8-05.2", scope: :partial, cases: cases}
      {family, Map.put(manifest, :digest, digest(manifest))}
    end)
  end

  def registrations do
    for {_family, manifest} <- manifests(), entry <- manifest.cases do
      Map.put(entry, :manifest, entry)
      |> Map.put(:callback, fn -> NewYou.Proof.P805.run(entry.case_id) end)
    end
  end

  defp cut("commit_rollback"), do: "transaction.before_commit"
  defp cut("audit_schedule_rollback"), do: "scheduling.before_enqueue"
  defp cut(_), do: nil

  defp digest(term),
    do:
      :crypto.hash(:sha256, :erlang.term_to_binary(term, [:deterministic]))
      |> Base.encode16(case: :lower)
end
