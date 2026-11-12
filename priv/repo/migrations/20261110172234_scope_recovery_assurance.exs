defmodule NewYou.Repo.Migrations.ScopeRecoveryAssurance do
  @moduledoc """
  Generated Account attribute removal plus explicit recovery guard corrections.
  Required assurance remains on each immutable-history RecoveryCase. This changes
  no Account security posture, credential, Session, Device or historical case.
  """

  use Ecto.Migration

  def up do
    execute """
    CREATE OR REPLACE FUNCTION identity_recovery_guard() RETURNS trigger LANGUAGE plpgsql AS $$
    BEGIN
      IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'identity_recovery_history_required' USING ERRCODE = '23514';
      END IF;
      IF OLD.state IN ('completed','failed','expired','cancelled') OR
         NEW.required_assurance < OLD.required_assurance OR
         NEW.satisfied_assurance < OLD.satisfied_assurance OR
         NEW.version <> OLD.version + 1 OR
         cardinality(NEW.history) <> cardinality(OLD.history) + 1 OR
         NEW.history[1:cardinality(OLD.history)] IS DISTINCT FROM OLD.history OR
         (to_jsonb(NEW) - ARRAY['state','version','proof_jti','required_assurance','satisfied_assurance','account_binding','proof_acceptance_id','review','completed_at','completion_id','terminated_at','history','updated_at']) IS DISTINCT FROM
         (to_jsonb(OLD) - ARRAY['state','version','proof_jti','required_assurance','satisfied_assurance','account_binding','proof_acceptance_id','review','completed_at','completion_id','terminated_at','history','updated_at']) OR
         NOT ((OLD.state = 'requested' AND NEW.state IN ('proof_pending','held_manual_review','failed','expired','cancelled')) OR
              (OLD.state = 'proof_pending' AND NEW.state IN ('additional_assurance','held_manual_review','failed','expired','cancelled')) OR
              (OLD.state = 'additional_assurance' AND NEW.state IN ('held_manual_review','completed','failed','expired','cancelled')) OR
              (OLD.state = 'held_manual_review' AND NEW.state = 'proof_pending' AND OLD.satisfied_assurance = 0 AND OLD.proof_jti IS NULL AND OLD.review IS NULL) OR
              (OLD.state = 'held_manual_review' AND NEW.state IN ('held_manual_review','completed','failed','expired','cancelled'))) THEN
        RAISE EXCEPTION 'identity_recovery_monotonic_history' USING ERRCODE = '23514';
      END IF;
      RETURN NEW;
    END $$;
    """

    execute """
    CREATE OR REPLACE FUNCTION identity_recovery_account_guard() RETURNS trigger LANGUAGE plpgsql AS $$
    BEGIN
      IF OLD.security_posture = 'held' AND NEW.email IS DISTINCT FROM OLD.email THEN
        RAISE EXCEPTION 'identity_recovery_account_guard' USING ERRCODE = '23514';
      END IF;
      RETURN NEW;
    END $$;
    """

    execute """
    CREATE OR REPLACE FUNCTION audit_recovery_hold_cause_guard() RETURNS trigger LANGUAGE plpgsql AS $$
    BEGIN
      IF NEW.evidence_type = 'security_hold_placement' AND NEW.actor_id IS NULL AND NOT EXISTS (
        SELECT 1 FROM recovery_cases c JOIN accounts a ON a.id = c.account_id
          JOIN tokens t ON t.jti = c.proof_jti AND t.recovery_case_id = c.id AND t.account_id = c.account_id
        WHERE c.id = NEW.case_id AND c.operation_id = NEW.source_operation_id
          AND c.account_id = NEW.target_id AND a.security_posture = 'held'
          AND c.satisfied_assurance >= 1 AND c.proof_acceptance_id IS NOT NULL
          AND t.purpose = 'recovery_consumed'
      ) THEN
        RAISE EXCEPTION 'audit_recovery_hold_cause_mismatch' USING ERRCODE = '23514';
      END IF;
      RETURN NEW;
    END $$;
    """

    alter table(:accounts) do
      remove :recovery_assurance_floor
    end
  end

  def down do
    raise Ecto.MigrationError,
      message:
        "recovery assurance correction requires a forward migration; do not restore the unsupported permanent Account floor"
  end
end
