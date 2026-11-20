defmodule NewYou.Architecture.AnalyticsProjectionRollbackTest do
  use NewYou.DataCase, async: false

  alias NewYou.Repo

  @migration_version 20_261_114_173_506
  @migration_path "priv/repo/migrations/20261114173506_p8_18_test_projection_scope.exs"
  @migration NewYou.Repo.Migrations.P818TestProjectionScope

  test "rolling back the test projection scope removes only valid test rows" do
    Code.require_file(@migration_path)

    assert %{rows: [[public_table_oid]]} =
             Repo.query!("SELECT 'public.p817_privacy_projections'::regclass::oid::bigint")

    Repo.query!("""
    CREATE TEMPORARY TABLE p817_privacy_projections (
      projection_key text NOT NULL,
      current_allowed_count bigint NOT NULL,
      CONSTRAINT p817_privacy_projections_single_key
        CHECK (projection_key = 'p817_current_privacy_aggregate')
    ) ON COMMIT DROP
    """)

    assert %{rows: [[prefix]]} =
             Repo.query!("SELECT nspname FROM pg_namespace WHERE oid = pg_my_temp_schema()")

    assert String.starts_with?(prefix, "pg_temp_")

    migration_opts = [prefix: prefix, log: false]

    assert :ok =
             Ecto.Migration.Runner.run(
               Repo,
               Repo.config(),
               @migration_version,
               @migration,
               :forward,
               :up,
               :up,
               migration_opts
             )

    Repo.query!("""
    INSERT INTO "#{prefix}".p817_privacy_projections (projection_key, current_allowed_count)
    VALUES
      ('p817_current_privacy_aggregate', 12),
      ('p817_test_123e4567-e89b-12d3-a456-426614174000', 4)
    """)

    assert :ok =
             Ecto.Migration.Runner.run(
               Repo,
               Repo.config(),
               @migration_version,
               @migration,
               :forward,
               :down,
               :down,
               migration_opts
             )

    assert %{rows: [["p817_current_privacy_aggregate", 12]]} =
             Repo.query!("""
             SELECT projection_key, current_allowed_count
             FROM "#{prefix}".p817_privacy_projections
             """)

    assert %{rows: [["p817_privacy_projections_single_key"]]} =
             Repo.query!("""
             SELECT conname
             FROM pg_constraint
             WHERE conrelid = '"#{prefix}".p817_privacy_projections'::regclass
               AND conname = 'p817_privacy_projections_single_key'
             """)

    assert %{rows: [["t", temporary_table_oid]]} =
             Repo.query!("""
             SELECT relpersistence::text, oid::bigint
             FROM pg_class
             WHERE oid = '"#{prefix}".p817_privacy_projections'::regclass
               AND relnamespace = pg_my_temp_schema()
             """)

    refute temporary_table_oid == public_table_oid

    assert %{rows: [[^public_table_oid]]} =
             Repo.query!("SELECT 'public.p817_privacy_projections'::regclass::oid::bigint")

    assert_raise Postgrex.Error, fn ->
      Repo.query!("""
      INSERT INTO "#{prefix}".p817_privacy_projections (projection_key, current_allowed_count)
      VALUES ('p817_test_123e4567-e89b-12d3-a456-426614174000', 4)
      """)
    end
  end
end
