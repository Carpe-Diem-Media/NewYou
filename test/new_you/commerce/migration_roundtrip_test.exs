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

  test "P1 migrations apply, roll back and reapply in a transaction-owned schema" do
    Enum.each(@migrations, fn {_, path, _} -> Code.require_file(path) end)
    :ok = Sandbox.checkout(Repo, sandbox: false)
    schema = "well189_" <> String.replace(Ecto.UUID.generate(), "-", "")

    try do
      assert {:error, :probe_complete} =
               Repo.transaction(fn ->
                 Repo.query!("CREATE SCHEMA #{schema}")
                 Enum.each(@migrations, &run_migration(&1, :up, schema))
                 assert table_count(schema) == 4
                 assert foreign_key_targets(schema) == {3, 3}
                 @migrations |> Enum.reverse() |> Enum.each(&run_migration(&1, :down, schema))
                 assert table_count(schema) == 0
                 Enum.each(@migrations, &run_migration(&1, :up, schema))
                 assert table_count(schema) == 4
                 assert foreign_key_targets(schema) == {3, 3}
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
        "SELECT count(*) FROM information_schema.tables WHERE table_schema = $1 AND table_name = ANY($2::text[])",
        [
          schema,
          ~w(commerce_plan_purchases commerce_verified_payments commerce_payment_consequences entitlements_plan_rights)
        ]
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
