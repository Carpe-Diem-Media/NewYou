defmodule NewYou.Repo.Migrations.Well15PreserveCaseHistory do
  @moduledoc "TRUNCATE must preserve the same case provenance as row updates and deletes."
  use Ecto.Migration

  def up do
    execute """
    CREATE FUNCTION identity_reconciliation_reject_truncate() RETURNS trigger LANGUAGE plpgsql AS $$
    BEGIN
      RAISE EXCEPTION 'identity_reconciliation_history_required' USING ERRCODE = '23514';
    END $$;
    """

    execute """
    CREATE TRIGGER identity_reconciliation_no_truncate BEFORE TRUNCATE ON reconciliation_cases
    FOR EACH STATEMENT EXECUTE FUNCTION identity_reconciliation_reject_truncate();
    """
  end

  def down do
    execute "LOCK TABLE reconciliation_cases IN ACCESS EXCLUSIVE MODE"

    execute """
    DO $$ BEGIN
      IF EXISTS (SELECT 1 FROM reconciliation_cases) THEN
        RAISE EXCEPTION 'well15_rollback_requires_governed_disposition';
      END IF;
    END $$;
    """

    execute "DROP TRIGGER identity_reconciliation_no_truncate ON reconciliation_cases"
    execute "DROP FUNCTION identity_reconciliation_reject_truncate()"
  end
end
