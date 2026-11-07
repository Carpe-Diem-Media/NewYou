defmodule NewYou.Proof.P813Catalog do
  @moduledoc "Bounded P8-13 E1 and privileged-support proof. It does not certify the full TB-001 inventory."
  @definitions [
    {"admission_cut", "transaction.after_commit", nil,
     ~w(committed_before_effect cut_consumed hold_retained retry_current)},
    {"capture_failure", "evidence.before_materialize", nil,
     ~w(cut_consumed no_admission no_release)},
    {"source_failure", "transaction.before_commit", nil,
     ~w(cut_consumed admission_retained source_rolled_back linked_failure recovery_no_source_replay)},
    {"same_attempt_race", nil, "p813.same_attempt",
     ~w(independent_connections independent_transactions contention both_replay one_admission one_transition)},
    {"distinct_attempt_race", nil, "p813.distinct_attempt",
     ~w(independent_connections independent_transactions contention one_winner distinct_admissions one_transition)},
    {"restart", nil, nil,
     ~w(first_boot reconstructed current_revocation second_boot outcome_recovered source_unchanged)},
    {"crash_after_admission", "transaction.after_commit", nil,
     ~w(admission_committed cut_consumed hold_retained same_attempt_retry one_admission)},
    {"crash_after_source", "transaction.after_commit", nil,
     ~w(source_committed cut_consumed outcome_durable restarted_materialisation no_source_replay)}
  ]

  def manifests do
    cases =
      for {name, cut, race, assertions} <- @definitions do
        id = "p813." <> name

        %{
          coverage_id: "audit_e1",
          case_id: id,
          invariant_id: id,
          source: "WELL-14; Identity JIT E/F/K; Audit JIT 5-8; TB-001 E1",
          boundary: "owning_ash_postgresql",
          cut_point: cut,
          race_id: race,
          assertion_ids: Enum.map(assertions, &(id <> "." <> &1)),
          timeout_ms: 60_000,
          timeout_override_reason:
            "real PostgreSQL contention and independent BEAM reconstruction",
          expected: "committed E1 admission precedes a freshly authorised Identity effect"
        }
      end

    manifest = %{coverage_id: "audit_e1", version: "p8-13.1", scope: :partial, cases: cases}

    digest =
      :crypto.hash(:sha256, :erlang.term_to_binary(manifest, [:deterministic]))
      |> Base.encode16(case: :lower)

    %{"audit_e1" => Map.put(manifest, :digest, digest)}
  end

  def registrations do
    for entry <- manifests()["audit_e1"].cases do
      entry
      |> Map.put(:manifest, entry)
      |> Map.put(:callback, fn -> NewYou.Proof.P813.run(entry.case_id) end)
    end
  end
end
