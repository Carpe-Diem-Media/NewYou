defmodule NewYou.Repo.Migrations.RecoveryGuards do
  @moduledoc "Preserve monotonic assurance and append-only recovery outcomes under PostgreSQL writes."
  use Ecto.Migration

  def up do
    execute """
    CREATE FUNCTION identity_recovery_guard() RETURNS trigger LANGUAGE plpgsql AS $$
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
              (OLD.state = 'held_manual_review' AND NEW.state IN ('held_manual_review','completed','failed','expired','cancelled'))) THEN
        RAISE EXCEPTION 'identity_recovery_monotonic_history' USING ERRCODE = '23514';
      END IF;
      RETURN NEW;
    END $$;
    """

    execute """
    CREATE TRIGGER identity_recovery_immutable BEFORE UPDATE OR DELETE ON recovery_cases
    FOR EACH ROW EXECUTE FUNCTION identity_recovery_guard();
    """

    execute """
    CREATE FUNCTION identity_recovery_account_guard() RETURNS trigger LANGUAGE plpgsql AS $$
    BEGIN
      IF NEW.recovery_assurance_floor < OLD.recovery_assurance_floor OR
         NEW.recovery_assurance_floor NOT IN (1,2) OR
         (OLD.security_posture = 'held' AND NEW.email IS DISTINCT FROM OLD.email) THEN
        RAISE EXCEPTION 'identity_recovery_account_guard' USING ERRCODE = '23514';
      END IF;
      RETURN NEW;
    END $$;
    """

    execute """
    CREATE TRIGGER accounts_recovery_guard BEFORE UPDATE ON accounts
    FOR EACH ROW EXECUTE FUNCTION identity_recovery_account_guard();
    """

    execute """
    CREATE FUNCTION audit_recovery_result_guard() RETURNS trigger LANGUAGE plpgsql AS $$
    BEGIN
      IF NEW.evidence_type = 'identity_recovery_completed' AND NEW.admission_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM evidence_records a WHERE a.id = NEW.admission_id
          AND a.assertion_kind = 'admission' AND a.action_class = 'identity_recovery'
          AND a.case_id = NEW.case_id AND a.attempt_id = NEW.source_operation_id
          AND a.actor_id = NEW.actor_id AND a.target_id = NEW.target_id
      ) THEN
        RAISE EXCEPTION 'audit_recovery_admission_mismatch' USING ERRCODE = '23514';
      END IF;
      RETURN NEW;
    END $$;
    """

    execute """
    CREATE TRIGGER audit_recovery_result_binding BEFORE INSERT ON evidence_obligations
    FOR EACH ROW EXECUTE FUNCTION audit_recovery_result_guard();
    """
  end

  def down do
    execute "DROP TRIGGER audit_recovery_result_binding ON evidence_obligations"
    execute "DROP FUNCTION audit_recovery_result_guard()"
    execute "DROP TRIGGER accounts_recovery_guard ON accounts"
    execute "DROP FUNCTION identity_recovery_account_guard()"
    execute "DROP TRIGGER identity_recovery_immutable ON recovery_cases"
    execute "DROP FUNCTION identity_recovery_guard()"
  end
end
