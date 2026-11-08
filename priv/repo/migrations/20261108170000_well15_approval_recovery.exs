defmodule NewYou.Repo.Migrations.Well15ApprovalRecovery do
  @moduledoc "Invalidate an approval through versioned re-review while preserving its evidence."
  use Ecto.Migration

  def up do
    execute """
    CREATE OR REPLACE FUNCTION identity_reconciliation_guard() RETURNS trigger LANGUAGE plpgsql AS $$
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
             (OLD.status = 'approved' AND NEW.status IN ('applied','review','rejected'))) THEN
        RAISE EXCEPTION 'identity_reconciliation_immutable_provenance' USING ERRCODE = '23514';
      END IF;
      IF OLD.status = 'approved' AND NEW.status IN ('review','rejected') AND
         (NEW.review IS NOT NULL OR
          NEW.history[cardinality(NEW.history)]->'superseded_review' IS DISTINCT FROM OLD.review) THEN
        RAISE EXCEPTION 'identity_reconciliation_approval_history_required' USING ERRCODE = '23514';
      END IF;
      RETURN NEW;
    END $$;
    """
  end

  def down do
    raise "well15_approval_recovery_requires_governed_disposition"
  end
end
