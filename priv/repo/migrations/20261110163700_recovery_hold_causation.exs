defmodule NewYou.Repo.Migrations.RecoveryHoldCausation do
  @moduledoc "Bind automatic restriction evidence to its Identity-owned recovery cause without attributing a human actor."
  use Ecto.Migration

  def up do
    execute """
    CREATE FUNCTION audit_recovery_hold_cause_guard() RETURNS trigger LANGUAGE plpgsql AS $$
    BEGIN
      IF NEW.evidence_type = 'security_hold_placement' AND NEW.actor_id IS NULL AND NOT EXISTS (
        SELECT 1 FROM recovery_cases c JOIN accounts a ON a.id = c.account_id
        WHERE c.id = NEW.case_id AND c.operation_id = NEW.source_operation_id
          AND c.account_id = NEW.target_id AND a.security_posture = 'held'
      ) THEN
        RAISE EXCEPTION 'audit_recovery_hold_cause_mismatch' USING ERRCODE = '23514';
      END IF;
      RETURN NEW;
    END $$;
    """

    execute """
    CREATE TRIGGER audit_recovery_hold_cause BEFORE INSERT ON evidence_obligations
    FOR EACH ROW EXECUTE FUNCTION audit_recovery_hold_cause_guard();
    """
  end

  def down do
    execute "DROP TRIGGER audit_recovery_hold_cause ON evidence_obligations"
    execute "DROP FUNCTION audit_recovery_hold_cause_guard()"
  end
end
