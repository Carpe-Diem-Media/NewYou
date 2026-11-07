defmodule NewYou.Proof.P809MagicCatalog do
  @moduledoc "Bounded magic-login lifecycle cases within the partial Identity family."
  @family "session_login_revocation_restart"

  def manifests do
    cases = [
      %{
        case_id: "p809.magic_consume_race",
        invariant_id: "p809.magic_consume_race",
        race_id: "p809.magic_consume_race",
        assertion_ids:
          Enum.map(
            ~w(independent_connections real_contention one_winner one_session proof_consumed replay_denied),
            &("p809.magic_consume_race." <> &1)
          ),
        expected: "Concurrent explicit consumption commits one shared Identity Session"
      },
      %{
        case_id: "p809.magic_issue_consume_race",
        invariant_id: "p809.magic_issue_consume_race",
        race_id: "p809.magic_issue_consume_race",
        assertion_ids:
          Enum.map(
            ~w(independent_connections real_contention issue_commits consumer_denied old_proof_superseded one_current_proof no_session),
            &("p809.magic_issue_consume_race." <> &1)
          ),
        expected: "Replacement issuance serializes with consumption and supersedes the old proof"
      },
      %{
        case_id: "p809.magic_restart",
        invariant_id: "p809.magic_restart",
        race_id: nil,
        assertion_ids:
          Enum.map(
            ~w(delivery_survives_restart consume_survives_restart terminal_delivery_denied terminal_replay_denied one_session),
            &("p809.magic_restart." <> &1)
          ),
        expected:
          "Independent BEAM instances rematerialise current proof and reject terminal replay"
      }
    ]

    prior = NewYou.Proof.P809Catalog.manifests()[@family].cases

    manifest = %{
      coverage_id: @family,
      version: "p8-09.2",
      scope: :partial,
      cases: prior ++ Enum.map(cases, &base_case/1)
    }

    digest =
      :crypto.hash(:sha256, :erlang.term_to_binary(manifest, [:deterministic]))
      |> Base.encode16(case: :lower)

    %{@family => Map.put(manifest, :digest, digest)}
  end

  def registrations do
    for entry <- manifests()[@family].cases,
        String.starts_with?(entry.case_id, "p809.magic_") do
      entry
      |> Map.put(:manifest, entry)
      |> Map.put(:callback, fn -> NewYou.Proof.P809MagicLogin.run(entry.case_id) end)
    end
  end

  defp base_case(entry) do
    %{
      coverage_id: @family,
      case_id: entry.case_id,
      invariant_id: entry.invariant_id,
      source: "WELL-12; Identity Magic Login; TB-001 sections 4 and 8",
      boundary: "owning_ash_postgresql",
      cut_point: nil,
      race_id: entry.race_id,
      assertion_ids: entry.assertion_ids,
      timeout_ms: 60_000,
      timeout_override_reason: "real PostgreSQL contention and independent BEAM boot",
      expected: entry.expected
    }
  end
end
