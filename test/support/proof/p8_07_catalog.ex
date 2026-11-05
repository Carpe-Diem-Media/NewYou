defmodule NewYou.Proof.P807Catalog do
  @moduledoc "Bounded verification proof mappings; the TB-001 family remains partial."
  @family "proof_capability_scanner_replay_supersession"
  @definitions [
    {"browser_en",
     ~w(temporary_copy explicit_form verified_result safe_replay no_session durable_verified no_session_or_new_rows)},
    {"browser_af",
     ~w(temporary_copy explicit_form verified_result safe_replay no_session durable_verified no_session_or_new_rows)},
    {"consume_race",
     ~w(independent_connections real_contention one_winner committed_verified fresh_replay no_session_or_new_rows)},
    {"interrupted_consume",
     ~w(cut_consumed atomic_rollback fresh_recovery no_session_or_new_rows)}
  ]

  def manifests do
    cases =
      for {name, assertions} <- @definitions do
        id = "p807." <> name

        %{
          coverage_id: @family,
          case_id: id,
          invariant_id: id,
          source: "WELL-8; Identity JIT email verification; TB-001 section 8",
          boundary:
            if(String.starts_with?(name, "browser_"),
              do: "phoenix_identity_postgresql",
              else: "owning_ash_postgresql"
            ),
          cut_point: if(name == "interrupted_consume", do: "transaction.before_commit"),
          race_id: if(name == "consume_race", do: id),
          assertion_ids: Enum.map(assertions, &(id <> "." <> &1)),
          timeout_ms: 60_000,
          timeout_override_reason: "bounded real PostgreSQL contention and process-loss recovery",
          expected:
            "Atomic verification and Token consumption, no Session; later proof purposes remain unproved"
        }
      end

    manifest = %{coverage_id: @family, version: "p8-07.1", scope: :partial, cases: cases}

    digest =
      :crypto.hash(:sha256, :erlang.term_to_binary(manifest, [:deterministic]))
      |> Base.encode16(case: :lower)

    %{@family => Map.put(manifest, :digest, digest)}
  end

  def registrations do
    for {_family, manifest} <- manifests(), entry <- manifest.cases do
      entry
      |> Map.put(:manifest, entry)
      |> Map.put(:callback, fn -> NewYou.Proof.P807.run(entry.case_id) end)
    end
  end
end
