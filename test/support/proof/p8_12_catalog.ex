defmodule NewYou.Proof.P812Catalog do
  @moduledoc "Bounded password-reset cases within the partial Identity session and revocation family."
  @family "session_login_revocation_restart"

  @cases [
    {"reset_race", nil, "p812.reset_race",
     ~w(independent_connections real_contention one_winner one_reset_consumption credential_version_once replay_denied no_session)},
    {"stale_login_race", nil, "p812.stale_login_race",
     ~w(independent_connections real_contention reset_committed login_denied no_session)},
    {"interrupted_reset", "transaction.before_commit", nil,
     ~w(cut_consumed atomic_rollback proof_current session_valid retry_commits no_session)},
    {"restart", nil, nil,
     ~w(delivery_survives_restart reset_survives_restart replay_survives_restart audit_once prior_session_revoked no_session)}
  ]

  def manifests do
    cases =
      Enum.map(@cases, fn {name, cut_point, race_id, assertions} ->
        case_id = "p812." <> name

        %{
          coverage_id: @family,
          case_id: case_id,
          invariant_id: case_id,
          source: "WELL-13; Identity JIT v0.3.0 F.3a; TB-001 sections 4 and 8",
          boundary: "owning_ash_postgresql",
          cut_point: cut_point,
          race_id: race_id,
          assertion_ids: Enum.map(assertions, &(case_id <> "." <> &1)),
          timeout_ms: if(name == "restart", do: 120_000, else: 60_000),
          timeout_override_reason:
            "real PostgreSQL contention; three independent BEAM boots have separate 30-second deadlines",
          expected:
            "Password reset commits one Account-wide security boundary and remains recoverable"
        }
      end)

    prior = NewYou.Proof.P809MagicCatalog.manifests()[@family].cases
    manifest = %{coverage_id: @family, version: "p8-12.1", scope: :partial, cases: prior ++ cases}

    digest =
      :crypto.hash(:sha256, :erlang.term_to_binary(manifest, [:deterministic]))
      |> Base.encode16(case: :lower)

    %{@family => Map.put(manifest, :digest, digest)}
  end

  def registrations do
    for entry <- manifests()[@family].cases, String.starts_with?(entry.case_id, "p812.") do
      entry
      |> Map.put(:manifest, entry)
      |> Map.put(:callback, fn -> NewYou.Proof.P812.run(entry.case_id) end)
    end
  end
end
