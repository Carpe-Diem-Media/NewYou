defmodule NewYou.Commerce.MigrationRoundtripTest do
  use ExUnit.Case, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias NewYou.Repo

  @migrations [
    {20_261_124_054_400, "priv/repo/migrations/20261124054400_well189_plan_purchase.exs",
     NewYou.Repo.Migrations.Well189PlanPurchase},
    {20_261_124_054_552, "priv/repo/migrations/20261124054552_well189_payment.exs",
     NewYou.Repo.Migrations.Well189Payment},
    {20_261_124_054_748, "priv/repo/migrations/20261124054748_well189_plan_right.exs",
     NewYou.Repo.Migrations.Well189PlanRight}
  ]

  @correction_migrations [
    {20_261_125_135_231, "priv/repo/migrations/20261125135231_well192_synthetic_collection.exs",
     NewYou.Repo.Migrations.Well192SyntheticCollection},
    {20_261_125_135_359, "priv/repo/migrations/20261125135359_well192_synthetic_excess.exs",
     NewYou.Repo.Migrations.Well192SyntheticExcess},
    {20_261_125_135_554,
     "priv/repo/migrations/20261125135554_well192_accepted_correction_fixture.exs",
     NewYou.Repo.Migrations.Well192AcceptedCorrectionFixture},
    {20_261_125_135_844, "priv/repo/migrations/20261125135844_well192_correction_convergence.exs",
     NewYou.Repo.Migrations.Well192CorrectionConvergence},
    {20_261_125_140_557, "priv/repo/migrations/20261125140557_well192_correction_receipt.exs",
     NewYou.Repo.Migrations.Well192CorrectionReceipt},
    {20_261_125_153_016,
     "priv/repo/migrations/20261125153016_well192_collection_receipt_binding.exs",
     NewYou.Repo.Migrations.Well192CollectionReceiptBinding}
  ]

  test "P1 migrations apply, roll back and reapply in a transaction-owned schema" do
    roundtrip(@migrations, 4, fn schema -> assert foreign_key_targets(schema) == {3, 3} end)
  end

  test "E2a migrations roundtrip with isolated foreign keys and correction constraints" do
    roundtrip(@migrations ++ @correction_migrations, 11, fn schema ->
      assert foreign_key_targets(schema) == {6, 6}

      assert [["commerce_synthetic_collection_receipts_pkey", "p"]] ==
               Repo.query!(
                 """
                 SELECT conname::text, contype::text FROM pg_constraint c JOIN pg_namespace n
                   ON c.connamespace = n.oid
                 WHERE n.nspname = $1 AND conname = 'commerce_synthetic_collection_receipts_pkey'
                 """,
                 [schema]
               ).rows

      assert [
               ["commerce_synthetic_collection_receipts_fingerprint_length"],
               ["commerce_synthetic_correction_shape"],
               ["commerce_synthetic_excess_claims_amount"],
               ["commerce_synthetic_order_allocation"]
             ] ==
               Repo.query!(
                 """
                 SELECT conname::text FROM pg_constraint c JOIN pg_namespace n
                   ON c.connamespace = n.oid
                 WHERE n.nspname = $1 AND c.contype = 'c' AND conname = ANY($2::text[])
                 ORDER BY conname
                 """,
                 [
                   schema,
                   ~w(commerce_synthetic_collection_receipts_fingerprint_length commerce_synthetic_correction_shape commerce_synthetic_excess_claims_amount commerce_synthetic_order_allocation)
                 ]
               ).rows

      assert [[_, "UNIQUE"], [_, "UNIQUE"], [_, "INDEX"]] =
               Repo.query!(
                 """
                 SELECT indexname::text, split_part(indexdef, ' ', 2) FROM pg_indexes
                 WHERE schemaname = $1 AND indexname = ANY($2::text[]) AND indexdef LIKE '% WHERE %'
                 ORDER BY indexname
                 """,
                 [
                   schema,
                   ~w(commerce_synthetic_corrections_component_key commerce_synthetic_corrections_excess_key commerce_synthetic_corrections_open)
                 ]
               ).rows
    end)
  end

  defp roundtrip(migrations, table_count, assert_constraints) do
    Enum.each(migrations, fn {_, path, module} ->
      unless Code.ensure_loaded?(module), do: Code.require_file(path)
    end)

    :ok = Sandbox.checkout(Repo, sandbox: false)
    schema = "well189_" <> String.replace(Ecto.UUID.generate(), "-", "")

    try do
      assert {:error, :probe_complete} =
               Repo.transaction(fn ->
                 Repo.query!("CREATE SCHEMA #{schema}")
                 Enum.each(migrations, &run_migration(&1, :up, schema))
                 assert table_count(schema) == table_count
                 assert_constraints.(schema)
                 migrations |> Enum.reverse() |> Enum.each(&run_migration(&1, :down, schema))
                 assert table_count(schema) == 0
                 Enum.each(migrations, &run_migration(&1, :up, schema))
                 assert table_count(schema) == table_count
                 assert_constraints.(schema)
                 Repo.rollback(:probe_complete)
               end)

      assert [[0]] =
               Repo.query!("SELECT count(*) FROM pg_namespace WHERE nspname = $1", [schema]).rows
    after
      Sandbox.checkin(Repo)
    end
  end

  defp run_migration({version, _, module}, operation, schema) do
    Ecto.Migration.Runner.run(
      Repo,
      Repo.config(),
      version,
      module,
      :forward,
      operation,
      operation,
      prefix: schema,
      log: false
    )
  end

  defp table_count(schema) do
    [[count]] =
      Repo.query!(
        "SELECT count(*) FROM information_schema.tables WHERE table_schema = $1",
        [schema]
      ).rows

    count
  end

  defp foreign_key_targets(schema) do
    [[total, local]] =
      Repo.query!(
        """
          SELECT count(*), count(*) FILTER (WHERE target_ns.nspname = $1)
          FROM pg_constraint c
          JOIN pg_class source ON source.oid = c.conrelid
          JOIN pg_namespace source_ns ON source_ns.oid = source.relnamespace
          JOIN pg_class target ON target.oid = c.confrelid
          JOIN pg_namespace target_ns ON target_ns.oid = target.relnamespace
          WHERE c.contype = 'f' AND source_ns.nspname = $1
        """,
        [schema]
      ).rows

    {total, local}
  end
end
