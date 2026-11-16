defmodule NewYou.Repo.Migrations.Well18PrivacyPurposeEventCompleteness do
  @moduledoc "Enforce durable event provenance for every Privacy purpose authority transition."

  use Ecto.Migration

  def up do
    execute """
    CREATE FUNCTION privacy_purpose_authorities_require_event() RETURNS trigger LANGUAGE plpgsql AS $$
    DECLARE expected_transition text;
    BEGIN
      expected_transition := CASE NEW.state
        WHEN 'allowed' THEN 'granted'
        WHEN 'withdrawn' THEN 'withdrawn'
      END;

      IF NOT EXISTS (
        SELECT 1
        FROM privacy_purpose_events
        WHERE authority_id = NEW.id
          AND version = NEW.version
          AND transition = expected_transition
      ) THEN
        RAISE EXCEPTION 'privacy_purpose_authorities_missing_event' USING ERRCODE = '23514';
      END IF;

      RETURN NULL;
    END;
    $$;
    """

    execute """
    CREATE CONSTRAINT TRIGGER privacy_purpose_authorities_require_event
    AFTER INSERT OR UPDATE ON privacy_purpose_authorities
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION privacy_purpose_authorities_require_event();
    """
  end

  def down do
    execute "DROP TRIGGER IF EXISTS privacy_purpose_authorities_require_event ON privacy_purpose_authorities"
    execute "DROP FUNCTION IF EXISTS privacy_purpose_authorities_require_event()"
  end
end
