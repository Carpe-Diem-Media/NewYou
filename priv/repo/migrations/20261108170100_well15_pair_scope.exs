defmodule NewYou.Repo.Migrations.Well15PairScope do
  @moduledoc """
  Add pair-scoped E1 fields without rewriting immutable pre-hardening admissions.
  Generated with AshPostgres, then reviewed for legacy evidence preservation.
  """

  use Ecto.Migration

  def up do
    alter table(:evidence_records) do
      add :canonical_grant_id, :uuid
      add :canonical_grant_version, :bigint
    end

    drop_if_exists constraint(:evidence_records, :evidence_records_assertion_shape)

    # Older draft builds could admit E1 without canonical scope. Preserve those
    # immutable rows, but enforce the complete shape on every new INSERT/UPDATE.
    # Legacy admissions cannot pass the new exact apply/replay binding.
    create constraint(:evidence_records, :evidence_records_assertion_shape,
             validate: false,
             check: """
               (assertion_kind = 'materialisation' AND obligation_id IS NOT NULL AND attempt_id IS NULL AND action_class IS NULL AND actor_id IS NULL AND target_id IS NULL AND grant_id IS NULL AND grant_version IS NULL AND session_id IS NULL AND expected_version IS NULL AND reason_code IS NULL AND admitted_at IS NULL AND outcome IS NULL AND case_id IS NULL AND canonical_grant_id IS NULL AND canonical_grant_version IS NULL) OR (assertion_kind = 'admission' AND obligation_id IS NULL AND attempt_id IS NOT NULL AND action_class IS NOT NULL AND action_class IN ('security_hold_release', 'identity_reconciliation') AND ((action_class = 'security_hold_release' AND case_id IS NULL AND canonical_grant_id IS NULL AND canonical_grant_version IS NULL) OR (action_class = 'identity_reconciliation' AND case_id IS NOT NULL AND canonical_grant_id IS NOT NULL AND canonical_grant_version IS NOT NULL AND canonical_grant_version > 0)) AND actor_id IS NOT NULL AND target_id IS NOT NULL AND grant_id IS NOT NULL AND grant_version IS NOT NULL AND grant_version > 0 AND session_id IS NOT NULL AND expected_version IS NOT NULL AND expected_version >= 0 AND reason_code IS NOT NULL AND reason_code IN ('suspected_compromise', 'security_review', 'verified_recovery', 'mistaken_hold') AND admitted_at IS NOT NULL AND outcome IS NOT NULL AND outcome = 'admitted')
             """
           )
  end

  def down do
    execute "LOCK TABLE evidence_records IN ACCESS EXCLUSIVE MODE"

    execute """
    DO $$ BEGIN
      IF EXISTS (SELECT 1 FROM evidence_records WHERE canonical_grant_id IS NOT NULL) THEN
        RAISE EXCEPTION 'well15_pair_scope_evidence_required';
      END IF;
    END $$;
    """

    drop_if_exists constraint(:evidence_records, :evidence_records_assertion_shape)

    create constraint(:evidence_records, :evidence_records_assertion_shape,
             check: """
               (assertion_kind = 'materialisation' AND obligation_id IS NOT NULL AND attempt_id IS NULL AND action_class IS NULL AND actor_id IS NULL AND target_id IS NULL AND grant_id IS NULL AND grant_version IS NULL AND session_id IS NULL AND expected_version IS NULL AND reason_code IS NULL AND admitted_at IS NULL AND outcome IS NULL AND case_id IS NULL) OR (assertion_kind = 'admission' AND obligation_id IS NULL AND attempt_id IS NOT NULL AND action_class IS NOT NULL AND action_class IN ('security_hold_release', 'identity_reconciliation') AND ((action_class = 'security_hold_release' AND case_id IS NULL) OR (action_class = 'identity_reconciliation' AND case_id IS NOT NULL)) AND actor_id IS NOT NULL AND target_id IS NOT NULL AND grant_id IS NOT NULL AND grant_version IS NOT NULL AND grant_version > 0 AND session_id IS NOT NULL AND expected_version IS NOT NULL AND expected_version >= 0 AND reason_code IS NOT NULL AND reason_code IN ('suspected_compromise', 'security_review', 'verified_recovery', 'mistaken_hold') AND admitted_at IS NOT NULL AND outcome IS NOT NULL AND outcome = 'admitted')
             """
           )

    alter table(:evidence_records) do
      remove :canonical_grant_version
      remove :canonical_grant_id
    end
  end
end
