defmodule NewYou.Repo.Migrations.Well218HostedDispatch do
  @moduledoc """
  Add a provider-disabled dispatch fence anchored to the immutable Purchase attempt.
  Existing purchases and payment evidence are left intact.
  """

  use Ecto.Migration

  def up do
    create table(:commerce_hosted_dispatches, primary_key: false) do
      add :reference, :text, null: false
      add :source_digest, :binary, null: false
      add :provider, :text, null: false
      add :integration, :text, null: false
      add :environment, :text, null: false
      add :channel, :text, null: false
      add :claim_id, :uuid
      add :fixture_code, :text

      add :attempt_id,
          references(:commerce_plan_purchases,
            column: :attempt_id,
            name: "commerce_hosted_dispatches_attempt_id_fkey",
            type: :uuid,
            on_delete: :restrict
          ), primary_key: true, null: false
    end

    create unique_index(
             :commerce_hosted_dispatches,
             [:provider, :integration, :environment, :reference],
             name: "commerce_hosted_dispatches_scoped_reference_index"
           )

    create constraint(:commerce_hosted_dispatches, :commerce_hosted_dispatches_fixture_scope,
             check: """
               provider = 'paystack' AND integration = 'local_fixture' AND
             environment = 'test' AND channel = 'card'

             """
           )

    create constraint(:commerce_hosted_dispatches, :commerce_hosted_dispatches_binding,
             check: """
               reference ~ '^[0-9a-f]{32}$' AND octet_length(source_digest) = 32
             """
           )

    create constraint(:commerce_hosted_dispatches, :commerce_hosted_dispatches_claim,
             check: """
               fixture_code IS NULL OR
               (claim_id IS NOT NULL AND fixture_code ~ '^[a-zA-Z0-9_-]{1,128}$')

             """
           )
  end

  def down do
    schema = String.replace(prefix() || "public", "\"", "\"\"")
    dispatches = ~s("#{schema}".commerce_hosted_dispatches)

    execute("LOCK TABLE #{dispatches} IN ACCESS EXCLUSIVE MODE")

    execute("""
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM #{dispatches}) THEN
        RAISE EXCEPTION 'Cannot remove the hosted dispatch fence with retained attempts';
      END IF;
    END;
    $$;
    """)

    drop table(:commerce_hosted_dispatches)
  end
end
