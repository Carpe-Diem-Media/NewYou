defmodule NewYou.Proof.P811Catalog do
  @moduledoc "Bounded Audit E2 proof. Does not certify E1 or the full TB-001 inventory."
  @family "audit_e2"
  @definitions [
    {"interrupted_materialisation", "evidence.after_materialize_before_commit", nil,
     ~w(cut_consumed record_rolled_back obligation_open source_unchanged fresh_retry)},
    {"existing_assertion", nil, nil,
     ~w(open_with_record same_assertion fulfilled terminal_replay source_unchanged truthful_timing minimum_envelope)},
    {"concurrent_execution", nil, "p811.concurrent_execution",
     ~w(independent_connections independent_transactions contention both_succeed single_assertion source_unchanged)},
    {"restart_backlog", nil, nil,
     ~w(first_boot jobs_recreated duplicate_schedule_safe second_boot recovered source_unchanged original_correlation)}
  ]

  def manifests do
    cases =
      for {name, cut, race, assertions} <- @definitions do
        id = "p811." <> name

        %{
          coverage_id: @family,
          case_id: id,
          invariant_id: id,
          source: "WELL-11; Audit JIT sections 6-8, 13; TB-001 sections 6-8",
          boundary: "owning_ash_postgresql",
          cut_point: cut,
          race_id: race,
          assertion_ids: Enum.map(assertions, &(id <> "." <> &1)),
          timeout_ms: 60_000,
          timeout_override_reason: "real PostgreSQL contention and independent BEAM boots",
          expected: "Audit converges on one assertion without replaying source truth"
        }
      end

    prior = NewYou.Proof.P805Catalog.manifests()[@family].cases
    manifest = %{coverage_id: @family, version: "p8-11.1", scope: :partial, cases: prior ++ cases}

    digest =
      :crypto.hash(:sha256, :erlang.term_to_binary(manifest, [:deterministic]))
      |> Base.encode16(case: :lower)

    %{@family => Map.put(manifest, :digest, digest)}
  end

  def registrations do
    for entry <- manifests()[@family].cases, String.starts_with?(entry.case_id, "p811.") do
      entry
      |> Map.put(:manifest, entry)
      |> Map.put(:callback, fn -> NewYou.Proof.P811.run(entry.case_id) end)
    end
  end
end
