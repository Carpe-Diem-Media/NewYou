defmodule NewYou.Repo.Migrations.PreserveLegacyAdmissions do
  @moduledoc "Preserve WELL-15 immutable legacy admission compatibility while enforcing the complete shape on all new writes."
  use Ecto.Migration

  def up do
    execute """
    DO $$ DECLARE shape text;
    BEGIN
      SELECT pg_get_expr(conbin, conrelid) INTO STRICT shape FROM pg_constraint
      WHERE conname = 'evidence_records_assertion_shape'
        AND conrelid = 'evidence_records'::regclass;
      ALTER TABLE evidence_records DROP CONSTRAINT evidence_records_assertion_shape;
      EXECUTE 'ALTER TABLE evidence_records ADD CONSTRAINT evidence_records_assertion_shape CHECK (' || shape || ') NOT VALID';
    END $$;
    """
  end

  # The same complete predicate stays enforced for new rows in both directions.
  # Validation of historical immutable evidence needs a separate governed decision.
  def down, do: :ok
end
