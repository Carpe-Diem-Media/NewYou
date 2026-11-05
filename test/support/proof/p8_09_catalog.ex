defmodule NewYou.Proof.P809Catalog do
  @moduledoc "Bounded Session reconstruction proof; the TB-001 family remains partial."
  @family "session_login_revocation_restart"

  def manifests do
    id = "p809.reconnect"

    entry = %{
      coverage_id: @family,
      case_id: id,
      invariant_id: id,
      source: "WELL-9; Identity JIT Session; TB-001 section 8",
      boundary: "owning_ash_postgresql",
      cut_point: nil,
      race_id: nil,
      assertion_ids:
        Enum.map(~w(fresh_connection active_denied_after_revoke), &(id <> "." <> &1)),
      timeout_ms: 60_000,
      timeout_override_reason: "independent PostgreSQL connections",
      expected: "Fresh connection reconstructs current Session authority and rejects revocation"
    }

    interrupted = %{
      entry
      | case_id: "p809.interrupted_issue",
        invariant_id: "p809.interrupted_issue",
        cut_point: "transaction.before_commit",
        assertion_ids:
          Enum.map(
            ~w(cut_consumed atomic_rollback fresh_recovery),
            &("p809.interrupted_issue." <> &1)
          ),
        expected: "Interrupted issuance rolls back and a fresh worker recovers"
    }

    browsers =
      for locale <- ~w(en af) do
        id = "p809.browser_" <> locale

        %{
          entry
          | case_id: id,
            invariant_id: id,
            boundary: "phoenix_identity_postgresql",
            assertion_ids:
              Enum.map(~w(login_form protected_access reloaded_access), &(id <> "." <> &1)),
            expected: "Chromium authenticates and revalidates on a fresh request"
        }
      end

    race = %{
      entry
      | case_id: "p809.hold_race",
        invariant_id: "p809.hold_race",
        race_id: "p809.hold_race",
        assertion_ids:
          Enum.map(~w(real_contention login_commits hold_denies), &("p809.hold_race." <> &1)),
        expected: "Concurrent hold serializes with login and denies current access"
    }

    restart = %{
      entry
      | case_id: "p809.beam_restart",
        invariant_id: "p809.beam_restart",
        assertion_ids:
          Enum.map(
            ~w(first_boot second_boot revoked_after_restart token_revoked_after_restart held_after_restart),
            &("p809.beam_restart." <> &1)
          ),
        expected: "Independent BEAM instances reconstruct and revalidate Session authority"
    }

    manifest = %{
      coverage_id: @family,
      version: "p8-08.1",
      scope: :partial,
      cases: [entry, interrupted, race, restart] ++ browsers
    }

    digest =
      :crypto.hash(:sha256, :erlang.term_to_binary(manifest, [:deterministic]))
      |> Base.encode16(case: :lower)

    %{@family => Map.put(manifest, :digest, digest)}
  end

  def registrations do
    for {_family, manifest} <- manifests(), entry <- manifest.cases do
      entry
      |> Map.put(:manifest, entry)
      |> Map.put(:callback, fn -> NewYou.Proof.P809.run(entry.case_id) end)
    end
  end
end
