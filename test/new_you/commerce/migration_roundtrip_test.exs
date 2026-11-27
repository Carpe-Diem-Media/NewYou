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

  @offer_migrations [
    {20_261_126_073_120, "priv/repo/migrations/20261126073120_well197_versioned_offers.exs",
     NewYou.Repo.Migrations.Well197VersionedOffers},
    {20_261_126_073_624,
     "priv/repo/migrations/20261126073624_well197_payment_consequence_scope.exs",
     NewYou.Repo.Migrations.Well197PaymentConsequenceScope}
  ]

  @dispatch_migration {
    20_261_126_204_523,
    "priv/repo/migrations/20261126204523_well218_hosted_dispatch.exs",
    NewYou.Repo.Migrations.Well218HostedDispatch
  }

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

  test "versioned migrations roundtrip legacy P1 and E2a history and refuse to strip accepted S1 evidence" do
    base = @migrations ++ @correction_migrations
    load_migrations(base ++ @offer_migrations)
    :ok = Sandbox.checkout(Repo, sandbox: false)
    schema = "well197_" <> String.replace(Ecto.UUID.generate(), "-", "")

    try do
      assert {:error, :probe_complete} =
               Repo.transaction(fn ->
                 Repo.query!("CREATE SCHEMA #{schema}")
                 Enum.each(base, &run_migration(&1, :up, schema))
                 seed_legacy(schema)
                 legacy = legacy_rows(schema, false)

                 Enum.each(@offer_migrations, &run_migration(&1, :up, schema))
                 assert table_count(schema) == 16
                 assert legacy_rows(schema, true) == legacy

                 assert [[nil, "plan"]] ==
                          Repo.query!("""
                          SELECT p.quote_id, c.delivery_kind FROM #{schema}.commerce_plan_purchases p
                            JOIN #{schema}.commerce_payment_consequences c ON p.id = c.purchase_id
                          """).rows

                 assert_accepted_shape_and_rollback_guard(schema)

                 @offer_migrations
                 |> Enum.reverse()
                 |> Enum.each(&run_migration(&1, :down, schema))

                 assert table_count(schema) == 11
                 assert legacy_rows(schema, false) == legacy

                 Enum.each(@offer_migrations, &run_migration(&1, :up, schema))
                 assert table_count(schema) == 16
                 assert legacy_rows(schema, true) == legacy
                 Repo.rollback(:probe_complete)
               end)
    after
      Sandbox.checkin(Repo)
    end
  end

  test "hosted dispatch migration preserves adjacent-version rows and will not erase a claim" do
    base = @migrations ++ @correction_migrations ++ @offer_migrations
    load_migrations(base ++ [@dispatch_migration])
    :ok = Sandbox.checkout(Repo, sandbox: false)
    schema = "well218_" <> String.replace(Ecto.UUID.generate(), "-", "")

    try do
      assert {:error, :probe_complete} =
               Repo.transaction(fn ->
                 Repo.query!("CREATE SCHEMA #{schema}")
                 Enum.each(base, &run_migration(&1, :up, schema))
                 seed_legacy(schema)
                 old_rows = legacy_rows(schema, true)
                 table = "#{schema}.commerce_hosted_dispatches"

                 run_migration(@dispatch_migration, :up, schema)
                 assert table_count(schema) == 17
                 assert [[0]] = Repo.query!("SELECT count(*) FROM #{table}").rows
                 assert legacy_rows(schema, true) == old_rows

                 run_migration(@dispatch_migration, :down, schema)
                 assert table_count(schema) == 16
                 assert legacy_rows(schema, true) == old_rows

                 run_migration(@dispatch_migration, :up, schema)
                 assert table_count(schema) == 17
                 {foreign_keys, local} = foreign_key_targets(schema)
                 assert foreign_keys == local

                 # This isolated DDL probe populates just the physical relation.
                 # Domain tests exercise admission through the owning Ash actions.
                 Repo.query!("""
                 INSERT INTO #{table}
                   (attempt_id, reference, source_digest, provider, integration, environment, channel, claim_id)
                 SELECT attempt_id, repeat('a', 32), decode(repeat('11', 32), 'hex'),
                   'paystack', 'local_fixture', 'test', 'card', gen_random_uuid()
                 FROM #{schema}.commerce_plan_purchases
                 """)

                 assert_dispatch_constraints(table)

                 Repo.query!("SAVEPOINT refuse_dispatch_rollback")

                 assert_raise Postgrex.Error, ~r/Cannot remove the hosted dispatch fence/, fn ->
                   run_migration(@dispatch_migration, :down, schema)
                 end

                 Repo.query!("ROLLBACK TO SAVEPOINT refuse_dispatch_rollback")

                 assert [[1]] =
                          Repo.query!("SELECT count(*) FROM #{table} WHERE claim_id IS NOT NULL").rows

                 assert legacy_rows(schema, true) == old_rows
                 Repo.rollback(:probe_complete)
               end)
    after
      Sandbox.checkin(Repo)
    end
  end

  test "payment evidence migration preserves legacy rows and refuses to erase fixture provenance" do
    evidence_migration =
      {20_261_127_054_309,
       "priv/repo/migrations/20261127054309_well219_hosted_payment_evidence.exs",
       NewYou.Repo.Migrations.Well219HostedPaymentEvidence}

    listener_migration =
      {20_261_127_065_856,
       "priv/repo/migrations/20261127065856_well219_bind_fixture_listener.exs",
       NewYou.Repo.Migrations.Well219BindFixtureListener}

    base = @migrations ++ @correction_migrations ++ @offer_migrations ++ [@dispatch_migration]
    load_migrations(base ++ [evidence_migration, listener_migration])
    :ok = Sandbox.checkout(Repo, sandbox: false)
    schema = "well219_" <> String.replace(Ecto.UUID.generate(), "-", "")

    try do
      assert {:error, :probe_complete} =
               Repo.transaction(fn ->
                 Repo.query!("CREATE SCHEMA #{schema}")
                 Enum.each(base, &run_migration(&1, :up, schema))
                 seed_legacy(schema)
                 old_rows = legacy_rows(schema, true)

                 run_migration(evidence_migration, :up, schema)
                 assert table_count(schema) == 18
                 {foreign_keys, local} = foreign_key_targets(schema)
                 assert foreign_keys == local

                 assert [[nil]] =
                          Repo.query!(
                            "SELECT fixture_receipt_id FROM #{schema}.commerce_verified_payments"
                          ).rows

                 run_migration(evidence_migration, :down, schema)
                 assert legacy_rows(schema, true) == old_rows
                 run_migration(evidence_migration, :up, schema)

                 assert_listener_migration(listener_migration, schema)

                 receipt_sql = """
                 INSERT INTO #{schema}.commerce_hosted_payment_receipts (source, digest, outcome)
                 VALUES ('webhook', decode(repeat('ab', 32), 'hex'), 'succeeded')
                 """

                 Repo.query!(receipt_sql)
                 Repo.query!("SAVEPOINT unique_receipt")

                 assert {:error, %Postgrex.Error{postgres: %{code: :unique_violation}}} =
                          Repo.query(receipt_sql)

                 Repo.query!("ROLLBACK TO SAVEPOINT unique_receipt")
                 Repo.query!("SAVEPOINT refuse_provenance_rollback")

                 assert_raise Postgrex.Error,
                              ~r/Cannot discard retained fixture payment evidence/,
                              fn ->
                                run_migration(evidence_migration, :down, schema)
                              end

                 Repo.query!("ROLLBACK TO SAVEPOINT refuse_provenance_rollback")

                 assert [[1]] =
                          Repo.query!(
                            "SELECT count(*) FROM #{schema}.commerce_hosted_payment_receipts"
                          ).rows

                 Repo.rollback(:probe_complete)
               end)
    after
      Sandbox.checkin(Repo)
    end
  end

  defp assert_listener_migration(migration, schema) do
    table = "#{schema}.commerce_hosted_dispatches"
    run_migration(migration, :up, schema)
    run_migration(migration, :down, schema)

    Repo.query!("""
    INSERT INTO #{table}
      (attempt_id, reference, source_digest, provider, integration, environment, channel,
       claim_id, fixture_port, verify_after)
    SELECT attempt_id, repeat('b', 32), decode(repeat('22', 32), 'hex'),
      'paystack', 'local_fixture', 'test', 'card', gen_random_uuid(), 12_345, now()
    FROM #{schema}.commerce_plan_purchases
    """)

    run_migration(migration, :up, schema)

    assert [[12_345, nil]] =
             Repo.query!("SELECT fixture_port, fixture_certificate FROM #{table}").rows

    Repo.query!("SAVEPOINT retain_listener_trust")

    assert_raise Postgrex.Error, ~r/Cannot remove fixture listener trust/, fn ->
      run_migration(migration, :down, schema)
    end

    Repo.query!("ROLLBACK TO SAVEPOINT retain_listener_trust")
  end

  defp assert_dispatch_constraints(table) do
    for {sql, name} <- [
          {"UPDATE #{table} SET attempt_id = gen_random_uuid()",
           "commerce_hosted_dispatches_attempt_id_fkey"},
          {"UPDATE #{table} SET environment = 'live'",
           "commerce_hosted_dispatches_fixture_scope"},
          {"UPDATE #{table} SET reference = 'wrong/path'", "commerce_hosted_dispatches_binding"},
          {"UPDATE #{table} SET claim_id = NULL, fixture_code = 'fixture'",
           "commerce_hosted_dispatches_claim"}
        ] do
      Repo.query!("SAVEPOINT dispatch_constraint")

      assert {:error, %Postgrex.Error{postgres: %{constraint: ^name}}} = Repo.query(sql)

      Repo.query!("ROLLBACK TO SAVEPOINT dispatch_constraint")
    end

    assert [[true]] =
             Repo.query!(
               """
               SELECT indisunique FROM pg_index
               WHERE indexrelid = to_regclass($1)
               """,
               [String.replace_suffix(table, "dispatches", "dispatches_scoped_reference_index")]
             ).rows
  end

  defp seed_legacy(schema) do
    Repo.query!("""
    WITH parties AS (
      SELECT gen_random_uuid() AS account_id
    ), purchase AS (
      INSERT INTO #{schema}.commerce_plan_purchases
        (operation_id, payer_id, recipient_id, price_version, amount_minor, currency)
      SELECT gen_random_uuid(), account_id, account_id, 'synthetic-plan-v1', 39900, 'ZAR' FROM parties
      RETURNING id, recipient_id
    ), payment AS (
      INSERT INTO #{schema}.commerce_verified_payments (purchase_id)
      SELECT id FROM purchase RETURNING id, purchase_id
    ), consequence AS (
      INSERT INTO #{schema}.commerce_payment_consequences (purchase_id, payment_id, fulfilled_at)
      SELECT purchase_id, id, now() FROM payment RETURNING purchase_id, payment_id
    ), plan_right AS (
      INSERT INTO #{schema}.entitlements_plan_rights (purchase_id, payment_id, recipient_id, component)
      SELECT p.id, c.payment_id, p.recipient_id, 'plan'
      FROM purchase p JOIN consequence c ON c.purchase_id = p.id RETURNING purchase_id
    )
    INSERT INTO #{schema}.commerce_synthetic_corrections
      (source_id, receipt_id, kind, component, amount_minor, acknowledged_at)
    SELECT purchase_id, gen_random_uuid(), 'component_end', 'plan', 39900, now() FROM plan_right
    """)
  end

  defp legacy_rows(schema, versioned?) do
    Enum.map(
      ~w(commerce_plan_purchases commerce_verified_payments commerce_payment_consequences entitlements_plan_rights commerce_synthetic_corrections),
      fn table ->
        projection =
          case {table, versioned?} do
            {"commerce_plan_purchases", true} -> "to_jsonb(t) - 'quote_id'"
            {"commerce_payment_consequences", true} -> "to_jsonb(t) - 'delivery_kind'"
            _ -> "to_jsonb(t)"
          end

        Repo.query!("SELECT #{projection} FROM #{schema}.#{table} t ORDER BY t.id").rows
      end
    )
  end

  defp assert_accepted_shape_and_rollback_guard(schema) do
    Repo.query!("SAVEPOINT s1_schema_probe")

    Repo.query!("""
    WITH offer AS (
      INSERT INTO #{schema}.commerce_offer_versions
        (id, product, price_version, currency, amount_minor, assessment_list_minor,
         assessment_discount_minor, plan_list_minor, plan_discount_minor, state,
         approval_id, approved_at, disclosure_en_id, disclosure_af_id)
      VALUES (gen_random_uuid(), 'plan', 'roundtrip-offer-197', 'ZAR', 41700, 0, 0, 41700, 0,
        'approved', gen_random_uuid(), now() - '1 second'::interval, gen_random_uuid(), gen_random_uuid())
      RETURNING id, disclosure_en_id
    )
    INSERT INTO #{schema}.commerce_purchase_quotes
      (operation_id, payer_id, recipient_id, offer_id, language, disclosure_id,
       disclosure_fingerprint, state)
    SELECT gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), id, 'en', disclosure_en_id,
      decode(repeat('00', 32), 'hex'), 'accepted' FROM offer
    """)

    Repo.query!("SAVEPOINT incomplete_acceptance")

    assert {:error, %Postgrex.Error{postgres: %{constraint: "well197_complete_acceptance"}}} =
             Repo.query("SET CONSTRAINTS ALL IMMEDIATE")

    Repo.query!("ROLLBACK TO SAVEPOINT incomplete_acceptance")

    Repo.query!("""
    INSERT INTO #{schema}.commerce_plan_purchases
      (operation_id, payer_id, recipient_id, quote_id, price_version, amount_minor, currency)
    SELECT operation_id, payer_id, recipient_id, q.id, o.price_version, o.amount_minor, o.currency
    FROM #{schema}.commerce_purchase_quotes q JOIN #{schema}.commerce_offer_versions o ON q.offer_id = o.id
    """)

    Repo.query!("SET CONSTRAINTS ALL IMMEDIATE")

    for table <- ~w(commerce_plan_purchases commerce_purchase_quotes commerce_offer_versions) do
      Repo.query!("SAVEPOINT immutable_financial_history")

      assert {:error, %Postgrex.Error{postgres: %{constraint: "well197_history_update"}}} =
               Repo.query("UPDATE #{schema}.#{table} SET id = id")

      Repo.query!("ROLLBACK TO SAVEPOINT immutable_financial_history")
    end

    for migration <- @offer_migrations do
      Repo.query!("SAVEPOINT refused_reverse")

      assert_raise Postgrex.Error, ~r/accepted offer evidence/, fn ->
        run_migration(migration, :down, schema)
      end

      Repo.query!("ROLLBACK TO SAVEPOINT refused_reverse")
    end

    assert [[41_700]] ==
             Repo.query!(
               "SELECT amount_minor FROM #{schema}.commerce_plan_purchases WHERE quote_id IS NOT NULL"
             ).rows

    Repo.query!("ROLLBACK TO SAVEPOINT s1_schema_probe")
  end

  defp roundtrip(migrations, table_count, assert_constraints) do
    load_migrations(migrations)
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

  defp load_migrations(migrations) do
    Enum.each(migrations, fn {_, path, module} ->
      unless Code.ensure_loaded?(module), do: Code.require_file(path)
    end)
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
