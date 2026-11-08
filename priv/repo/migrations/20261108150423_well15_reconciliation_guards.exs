defmodule NewYou.Repo.Migrations.Well15ReconciliationGuards do
  @moduledoc "Preserve original case provenance and permanent retired-PMR state under ordinary database writes."
  use Ecto.Migration

  def up do
    execute """
    ALTER TABLE accounts ADD CONSTRAINT accounts_canonical_account_id_fkey
    FOREIGN KEY (canonical_account_id) REFERENCES accounts(id);
    """

    execute """
    CREATE FUNCTION identity_reconciliation_guard() RETURNS trigger LANGUAGE plpgsql AS $$
    BEGIN
      IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'identity_reconciliation_history_required' USING ERRCODE = '23514';
      END IF;
      IF OLD.status IN ('applied','rejected') OR
        (to_jsonb(NEW) - ARRAY['status','version','review','history','updated_at','applied_operation_id','applied_at','apply_binding']) IS DISTINCT FROM
        (to_jsonb(OLD) - ARRAY['status','version','review','history','updated_at','applied_operation_id','applied_at','apply_binding']) OR
        NEW.version <> OLD.version + 1 OR
        cardinality(NEW.history) <> cardinality(OLD.history) + 1 OR
        NEW.history[1:cardinality(OLD.history)] IS DISTINCT FROM OLD.history OR
        NOT ((OLD.status = 'detected' AND NEW.status IN ('candidate','rejected')) OR
             (OLD.status = 'candidate' AND NEW.status IN ('review','rejected')) OR
             (OLD.status = 'review' AND NEW.status IN ('approved','rejected','conflict')) OR
             (OLD.status = 'conflict' AND NEW.status IN ('review','rejected')) OR
             (OLD.status = 'approved' AND NEW.status = 'applied')) THEN
        RAISE EXCEPTION 'identity_reconciliation_immutable_provenance' USING ERRCODE = '23514';
      END IF;
      RETURN NEW;
    END $$;
    """

    execute """
    CREATE TRIGGER identity_reconciliation_immutable BEFORE UPDATE OR DELETE ON reconciliation_cases
    FOR EACH ROW EXECUTE FUNCTION identity_reconciliation_guard();
    """

    execute """
    CREATE FUNCTION identity_retired_pmr_guard() RETURNS trigger LANGUAGE plpgsql AS $$
    BEGIN
      IF OLD.pmr_status = 'retired' AND
         (NEW.pmr_status <> 'retired' OR NEW.pmr IS DISTINCT FROM OLD.pmr OR
          NEW.canonical_account_id IS DISTINCT FROM OLD.canonical_account_id OR NEW.account_status <> 'closed_terminal') THEN
        RAISE EXCEPTION 'identity_retired_pmr_is_permanent' USING ERRCODE = '23514';
      END IF;
      RETURN NEW;
    END $$;
    """

    execute """
    CREATE TRIGGER accounts_retired_pmr_permanent BEFORE UPDATE ON accounts
    FOR EACH ROW EXECUTE FUNCTION identity_retired_pmr_guard();
    """

    execute """
    CREATE FUNCTION audit_reconciliation_result_guard() RETURNS trigger LANGUAGE plpgsql AS $$
    BEGIN
      IF NEW.evidence_type = 'identity_reconciliation_result' AND NOT EXISTS (
        SELECT 1 FROM evidence_records a WHERE a.id = NEW.admission_id AND a.assertion_kind = 'admission'
          AND a.action_class = 'identity_reconciliation' AND a.case_id = NEW.case_id
          AND a.attempt_id = NEW.source_operation_id AND a.actor_id = NEW.actor_id AND a.target_id = NEW.target_id
          AND a.grant_id = NEW.grant_id AND a.session_id = NEW.session_id AND a.reason_code = NEW.reason_code
      ) THEN
        RAISE EXCEPTION 'audit_reconciliation_admission_mismatch' USING ERRCODE = '23514';
      END IF;
      RETURN NEW;
    END $$;
    """

    execute """
    CREATE TRIGGER audit_reconciliation_result_binding BEFORE INSERT ON evidence_obligations
    FOR EACH ROW EXECUTE FUNCTION audit_reconciliation_result_guard();
    """
  end

  def down do
    execute "LOCK TABLE reconciliation_cases, accounts, evidence_records IN ACCESS EXCLUSIVE MODE"

    execute """
    DO $$ BEGIN
      IF EXISTS (SELECT 1 FROM reconciliation_cases) OR EXISTS (SELECT 1 FROM accounts WHERE pmr_status = 'retired') OR EXISTS (SELECT 1 FROM evidence_records WHERE case_id IS NOT NULL) THEN
        RAISE EXCEPTION 'well15_rollback_requires_governed_disposition';
      END IF;
    END $$;
    """

    execute "DROP TRIGGER audit_reconciliation_result_binding ON evidence_obligations"
    execute "DROP FUNCTION audit_reconciliation_result_guard()"
    execute "DROP TRIGGER accounts_retired_pmr_permanent ON accounts"
    execute "DROP FUNCTION identity_retired_pmr_guard()"
    execute "DROP TRIGGER identity_reconciliation_immutable ON reconciliation_cases"
    execute "DROP FUNCTION identity_reconciliation_guard()"
    execute "ALTER TABLE accounts DROP CONSTRAINT accounts_canonical_account_id_fkey"
  end
end
