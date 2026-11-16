defmodule NewYou.Repo.Migrations.Well18PrivacyInitialStateGuard do
  @moduledoc "Reject Privacy purpose authority rows that begin in a withdrawn state."

  use Ecto.Migration

  def up do
    execute """
    CREATE FUNCTION privacy_purpose_authorities_initial_state_guard() RETURNS trigger LANGUAGE plpgsql AS $$
    BEGIN
      IF NEW.state <> 'allowed' OR NEW.version <> 1 THEN
        RAISE EXCEPTION 'privacy_purpose_authorities_initial_state' USING ERRCODE = '23514';
      END IF;

      RETURN NEW;
    END;
    $$;
    """

    execute """
    CREATE TRIGGER privacy_purpose_authorities_initial_state
    BEFORE INSERT ON privacy_purpose_authorities
    FOR EACH ROW EXECUTE FUNCTION privacy_purpose_authorities_initial_state_guard();
    """
  end

  def down do
    execute "DROP TRIGGER IF EXISTS privacy_purpose_authorities_initial_state ON privacy_purpose_authorities"
    execute "DROP FUNCTION IF EXISTS privacy_purpose_authorities_initial_state_guard()"
  end
end
