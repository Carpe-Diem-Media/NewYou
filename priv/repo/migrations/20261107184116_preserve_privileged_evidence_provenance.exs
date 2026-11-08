defmodule NewYou.Repo.Migrations.PreservePrivilegedEvidenceProvenance do
  @moduledoc "Extend the existing append-only Audit guard to selected security provenance and E1 result links."
  use Ecto.Migration

  def up do
    execute "LOCK TABLE evidence_obligations, evidence_records IN ACCESS EXCLUSIVE MODE"

    execute """
    CREATE OR REPLACE FUNCTION audit_e2_guard_obligation() RETURNS trigger LANGUAGE plpgsql AS $$
    BEGIN
      IF TG_OP = 'INSERT' THEN
        IF NEW.state <> 'open' THEN
          RAISE EXCEPTION 'audit_e2_must_start_open' USING ERRCODE = '23514';
        END IF;
        IF NEW.evidence_type = 'security_hold_release_result' AND NOT EXISTS (
          SELECT 1 FROM evidence_records a
          WHERE a.id = NEW.admission_id AND a.assertion_kind = 'admission'
            AND a.attempt_id = NEW.source_operation_id
            AND a.actor_id = NEW.actor_id AND a.target_id = NEW.target_id
            AND a.grant_id = NEW.grant_id AND a.session_id = NEW.session_id
            AND a.reason_code = NEW.reason_code
        ) THEN
          RAISE EXCEPTION 'audit_e1_result_binding_mismatch' USING ERRCODE = '23514';
        END IF;
      ELSE
        IF OLD.state = 'fulfilled' OR
          (to_jsonb(NEW) - ARRAY['state','fulfilled_at','updated_at']) IS DISTINCT FROM
          (to_jsonb(OLD) - ARRAY['state','fulfilled_at','updated_at']) THEN
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
  end

  def down do
    # The guard remains valid against the preceding schema and is stronger for
    # its original registration fields. No history or source data is rewritten.
    execute """
    CREATE OR REPLACE FUNCTION audit_e2_guard_obligation() RETURNS trigger LANGUAGE plpgsql AS $$
    BEGIN
      IF TG_OP = 'INSERT' THEN
        IF NEW.state <> 'open' THEN
          RAISE EXCEPTION 'audit_e2_must_start_open' USING ERRCODE = '23514';
        END IF;
      ELSIF OLD.state = 'fulfilled' OR
        (to_jsonb(NEW) - ARRAY['state','fulfilled_at','updated_at']) IS DISTINCT FROM
        (to_jsonb(OLD) - ARRAY['state','fulfilled_at','updated_at']) THEN
        RAISE EXCEPTION 'audit_e2_immutable_provenance' USING ERRCODE = '23514';
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
  end
end
