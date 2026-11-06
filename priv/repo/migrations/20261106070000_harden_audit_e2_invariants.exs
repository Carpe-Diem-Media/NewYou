defmodule NewYou.Repo.Migrations.HardenAuditE2Invariants do
  @moduledoc """
  Preserve Audit assertions and their provenance independently of executor state.
  No rows are rewritten. Existing invalid fulfilled rows fail migration validation.
  These triggers are ordinary-write guards, not protection against a database owner
  deliberately disabling them. Lawful disposition requires a separately governed path.
  """
  use Ecto.Migration

  def up do
    # Close the validation/install race with ordinary writers. The migration
    # changes guards only and releases these locks with its transaction.
    execute "LOCK TABLE evidence_obligations, evidence_records IN ACCESS EXCLUSIVE MODE"

    execute """
    DO $$ BEGIN
      IF EXISTS (
        SELECT 1 FROM evidence_obligations o
        WHERE o.state = 'fulfilled'
          AND NOT EXISTS (SELECT 1 FROM evidence_records r WHERE r.obligation_id = o.id)
      ) THEN
        RAISE EXCEPTION 'audit_e2_existing_integrity_mismatch' USING ERRCODE = '23514';
      END IF;
    END $$;
    """

    execute """
    CREATE FUNCTION audit_e2_immutable() RETURNS trigger LANGUAGE plpgsql AS $$
    BEGIN
      RAISE EXCEPTION 'audit_e2_immutable' USING ERRCODE = '23514';
    END;
    $$;
    """

    execute """
    CREATE TRIGGER evidence_records_immutable
    BEFORE UPDATE OR DELETE ON evidence_records
    FOR EACH ROW EXECUTE FUNCTION audit_e2_immutable();
    """

    execute """
    CREATE TRIGGER evidence_records_no_truncate
    BEFORE TRUNCATE ON evidence_records
    FOR EACH STATEMENT EXECUTE FUNCTION audit_e2_immutable();
    """

    execute """
    CREATE TRIGGER evidence_obligations_no_delete
    BEFORE DELETE ON evidence_obligations
    FOR EACH ROW EXECUTE FUNCTION audit_e2_immutable();
    """

    execute """
    CREATE TRIGGER evidence_obligations_no_truncate
    BEFORE TRUNCATE ON evidence_obligations
    FOR EACH STATEMENT EXECUTE FUNCTION audit_e2_immutable();
    """

    execute """
    CREATE FUNCTION audit_e2_guard_obligation() RETURNS trigger LANGUAGE plpgsql AS $$
    BEGIN
      IF TG_OP = 'INSERT' THEN
        IF NEW.state <> 'open' THEN
          RAISE EXCEPTION 'audit_e2_must_start_open' USING ERRCODE = '23514';
        END IF;
      ELSE
        IF OLD.state = 'fulfilled'
          OR NEW.id IS DISTINCT FROM OLD.id
          OR NEW.evidence_type IS DISTINCT FROM OLD.evidence_type
          OR NEW.source_operation_id IS DISTINCT FROM OLD.source_operation_id
          OR NEW.source_occurred_at IS DISTINCT FROM OLD.source_occurred_at
          OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
          RAISE EXCEPTION 'audit_e2_immutable_provenance' USING ERRCODE = '23514';
        END IF;
      END IF;

      IF NEW.state = 'fulfilled' AND NOT EXISTS (
        SELECT 1 FROM evidence_records WHERE obligation_id = NEW.id
      ) THEN
        RAISE EXCEPTION 'audit_e2_fulfilment_requires_record' USING ERRCODE = '23514';
      END IF;
      RETURN NEW;
    END;
    $$;
    """

    execute """
    CREATE TRIGGER evidence_obligations_lifecycle
    BEFORE INSERT OR UPDATE ON evidence_obligations
    FOR EACH ROW EXECUTE FUNCTION audit_e2_guard_obligation();
    """
  end

  def down do
    execute "DROP TRIGGER evidence_obligations_lifecycle ON evidence_obligations"
    execute "DROP FUNCTION audit_e2_guard_obligation()"
    execute "DROP TRIGGER evidence_obligations_no_truncate ON evidence_obligations"
    execute "DROP TRIGGER evidence_obligations_no_delete ON evidence_obligations"
    execute "DROP TRIGGER evidence_records_no_truncate ON evidence_records"
    execute "DROP TRIGGER evidence_records_immutable ON evidence_records"
    execute "DROP FUNCTION audit_e2_immutable()"
  end
end
