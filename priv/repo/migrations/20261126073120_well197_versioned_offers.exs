defmodule NewYou.Repo.Migrations.Well197VersionedOffers do
  @moduledoc """
  Add versioned offer admission without modifying any accepted legacy rows.
  """

  use Ecto.Migration

  def up do
    alter table(:commerce_plan_purchases) do
      add :quote_id, :uuid
    end

    create unique_index(:commerce_plan_purchases, [:quote_id],
             name: "commerce_plan_purchases_quote_index"
           )

    drop_if_exists constraint(:commerce_plan_purchases, :commerce_plan_purchases_same_account)

    drop_if_exists constraint(:commerce_plan_purchases, :commerce_plan_purchases_price)

    create index(:commerce_plan_purchases, [:recipient_id])

    create index(:commerce_plan_purchases, [:payer_id])

    create table(:entitlements_assessment_credit_evidence, primary_key: false) do
      add :recipient_id, :uuid, null: false, primary_key: true
      add :evidence_id, :uuid, null: false
      add :ordinary_state, :text, null: false
      add :credit_id, :uuid
      add :premium_state, :text, null: false
    end

    create constraint(:entitlements_assessment_credit_evidence, :assessment_credit_evidence_shape,
             check: """
               ((ordinary_state IN ('none', 'unavailable') AND credit_id IS NULL) OR
               (ordinary_state IN ('available_unused', 'held_unconsumed', 'consumed', 'closed') AND credit_id IS NOT NULL))
             AND premium_state IN ('none', 'available_unused', 'expired')

             """
           )

    create table(:temperament_assessment_delivery_evidence, primary_key: false) do
      add :recipient_id, :uuid, null: false, primary_key: true
      add :evidence_id, :uuid, null: false
      add :status, :text, null: false
      add :successful_at, :"timestamptz(6)"
    end

    create constraint(
             :temperament_assessment_delivery_evidence,
             :assessment_delivery_evidence_shape,
             check: """
               (status = 'successful' AND successful_at IS NOT NULL) OR
             (status IN ('none', 'unavailable') AND successful_at IS NULL)

             """
           )

    create table(:commerce_purchase_quotes, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v7()"), primary_key: true
    end

    alter table(:commerce_plan_purchases) do
      modify :quote_id,
             references(:commerce_purchase_quotes,
               column: :id,
               name: "commerce_plan_purchases_quote_id_fkey",
               type: :uuid,
               prefix: prefix() || "public",
               on_delete: :restrict
             )
    end

    create constraint(:commerce_plan_purchases, :commerce_plan_purchases_terms,
             check: """
               amount_minor > 0 AND currency = 'ZAR' AND
             (quote_id IS NOT NULL OR
               (price_version = 'synthetic-plan-v1' AND payer_id = recipient_id))

             """
           )

    alter table(:commerce_purchase_quotes) do
      add :operation_id, :uuid, null: false
      add :payer_id, :uuid, null: false
      add :recipient_id, :uuid, null: false
      add :language, :text, null: false
      add :disclosure_id, :uuid, null: false
      add :disclosure_fingerprint, :binary, null: false
      add :state, :text, null: false, default: "offered"
      add :decision, :text

      add :offered_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :offer_id, :uuid, null: false
    end

    create unique_index(:commerce_purchase_quotes, [:operation_id],
             name: "commerce_purchase_quotes_operation_index"
           )

    create table(:commerce_offer_versions, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
    end

    alter table(:commerce_purchase_quotes) do
      modify :offer_id,
             references(:commerce_offer_versions,
               column: :id,
               name: "commerce_purchase_quotes_offer_id_fkey",
               type: :uuid,
               prefix: prefix() || "public",
               on_delete: :restrict
             )
    end

    create constraint(:commerce_purchase_quotes, :commerce_purchase_quotes_state,
             check: """
               (state IN ('offered', 'accepted') AND decision IS NULL) OR
             (state = 'stale' AND decision IS NOT NULL AND decision = 'offer_changed') OR
             (state = 'rejected' AND decision IS NOT NULL AND decision IN ('unused_credit', 'annual_interval', 'competing_purchase')) OR
             (state = 'reconciling' AND decision IS NOT NULL AND decision IN ('credit_evidence_unavailable', 'delivery_evidence_unavailable'))

             """
           )

    create constraint(:commerce_purchase_quotes, :commerce_purchase_quotes_disclosure,
             check: """
               language IN ('en', 'af') AND octet_length(disclosure_fingerprint) = 32
             """
           )

    alter table(:commerce_offer_versions) do
      add :product, :text, null: false
      add :price_version, :text, null: false
      add :currency, :text, null: false
      add :amount_minor, :bigint, null: false
      add :assessment_list_minor, :bigint, null: false
      add :assessment_discount_minor, :bigint, null: false
      add :plan_list_minor, :bigint, null: false
      add :plan_discount_minor, :bigint, null: false
      add :allocation_version, :text
      add :promotion_version, :text
      add :state, :text, null: false, default: "draft"
      add :approval_id, :uuid
      add :allocation_approval_id, :uuid
      add :disclosure_en_id, :uuid
      add :disclosure_af_id, :uuid
      add :withdrawal_id, :uuid
      add :approved_at, :"timestamptz(6)"
      add :expires_at, :"timestamptz(6)"

      add :created_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create unique_index(:commerce_offer_versions, [:price_version],
             name: "commerce_offer_versions_price_version_index"
           )

    create constraint(:commerce_offer_versions, :commerce_offer_versions_amounts,
             check: """
               currency = 'ZAR' AND amount_minor > 0 AND
             plan_list_minor >= 0 AND assessment_list_minor >= 0 AND
             plan_discount_minor >= 0 AND assessment_discount_minor >= 0 AND
             (plan_list_minor = 0 AND plan_discount_minor = 0 OR plan_list_minor > plan_discount_minor) AND
             (assessment_list_minor = 0 AND assessment_discount_minor = 0 OR
               assessment_list_minor > assessment_discount_minor) AND
             (plan_list_minor::numeric - plan_discount_minor) +
               (assessment_list_minor::numeric - assessment_discount_minor) = amount_minor AND
             ((product = 'plan' AND assessment_list_minor = 0 AND allocation_version IS NULL) OR
              (product = 'assessment' AND plan_list_minor = 0 AND allocation_version IS NULL) OR
              (product = 'bundle' AND plan_list_minor > 0 AND assessment_list_minor > 0 AND
               (plan_discount_minor > 0 OR assessment_discount_minor > 0) AND allocation_version IS NOT NULL))

             """
           )

    create constraint(:commerce_offer_versions, :commerce_offer_versions_lifecycle,
             check: """
               (state = 'draft' AND approval_id IS NULL AND approved_at IS NULL AND
               disclosure_en_id IS NULL AND disclosure_af_id IS NULL AND allocation_approval_id IS NULL
               AND withdrawal_id IS NULL) OR
             (state IN ('approved', 'superseded', 'withdrawn') AND approval_id IS NOT NULL
               AND approved_at IS NOT NULL AND disclosure_en_id IS NOT NULL AND disclosure_af_id IS NOT NULL
               AND disclosure_en_id <> disclosure_af_id
               AND (expires_at IS NULL OR expires_at > approved_at)
               AND ((product = 'bundle' AND allocation_approval_id IS NOT NULL
                 AND allocation_approval_id <> approval_id) OR
                 (product <> 'bundle' AND allocation_approval_id IS NULL))
               AND ((state = 'withdrawn') = (withdrawal_id IS NOT NULL)))

             """
           )

    create index(:commerce_offer_versions, [:product],
             name: "commerce_offer_versions_one_approved",
             unique: true,
             where: "state = 'approved'"
           )

    create table(:commerce_assessment_admissions, primary_key: false) do
      add :purchase_id,
          references(:commerce_plan_purchases,
            column: :id,
            name: "commerce_assessment_admissions_purchase_id_fkey",
            type: :uuid,
            prefix: prefix() || "public",
            on_delete: :restrict
          ), primary_key: true, null: false

      add :recipient_id, :uuid, null: false
      add :state, :text, null: false, default: "pending"
      add :resolved_at, :"timestamptz(6)"
      add :resolution_id, :uuid

      add :admitted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create constraint(:commerce_assessment_admissions, :commerce_assessment_admissions_lifecycle,
             check: """
               (state IN ('pending', 'paid') AND resolved_at IS NULL AND resolution_id IS NULL) OR
             (state IN ('nonpayable', 'reconciled') AND resolved_at IS NOT NULL AND resolution_id IS NOT NULL)

             """
           )

    create index(:commerce_assessment_admissions, [:recipient_id],
             name: "commerce_assessment_admissions_active_recipient",
             unique: true,
             where: "state IN ('pending', 'paid')"
           )

    protect_history()
  end

  def down do
    execute("LOCK TABLE #{relation(:commerce_plan_purchases)} IN ACCESS EXCLUSIVE MODE")

    execute """
    DO $$ BEGIN
      IF EXISTS (SELECT 1 FROM #{relation(:commerce_plan_purchases)} WHERE quote_id IS NOT NULL) THEN
        RAISE EXCEPTION 'cannot remove accepted offer evidence';
      END IF;
    END $$
    """

    remove_history_guards()

    drop_if_exists index(:commerce_assessment_admissions, [:recipient_id],
                     name: "commerce_assessment_admissions_active_recipient"
                   )

    drop_if_exists constraint(
                     :commerce_assessment_admissions,
                     :commerce_assessment_admissions_lifecycle
                   )

    drop constraint(
           :commerce_assessment_admissions,
           "commerce_assessment_admissions_purchase_id_fkey"
         )

    drop table(:commerce_assessment_admissions)

    drop_if_exists index(:commerce_offer_versions, [:product],
                     name: "commerce_offer_versions_one_approved"
                   )

    drop_if_exists constraint(:commerce_offer_versions, :commerce_offer_versions_lifecycle)

    drop_if_exists constraint(:commerce_offer_versions, :commerce_offer_versions_amounts)

    drop_if_exists unique_index(:commerce_offer_versions, [:price_version],
                     name: "commerce_offer_versions_price_version_index"
                   )

    alter table(:commerce_offer_versions) do
      remove :created_at
      remove :expires_at
      remove :approved_at
      remove :withdrawal_id
      remove :disclosure_af_id
      remove :disclosure_en_id
      remove :allocation_approval_id
      remove :approval_id
      remove :state
      remove :promotion_version
      remove :allocation_version
      remove :plan_discount_minor
      remove :plan_list_minor
      remove :assessment_discount_minor
      remove :assessment_list_minor
      remove :amount_minor
      remove :currency
      remove :price_version
      remove :product
    end

    drop_if_exists constraint(:commerce_purchase_quotes, :commerce_purchase_quotes_disclosure)

    drop_if_exists constraint(:commerce_purchase_quotes, :commerce_purchase_quotes_state)

    drop constraint(:commerce_purchase_quotes, "commerce_purchase_quotes_offer_id_fkey")

    alter table(:commerce_purchase_quotes) do
      modify :offer_id, :uuid
    end

    drop table(:commerce_offer_versions)

    drop_if_exists unique_index(:commerce_purchase_quotes, [:operation_id],
                     name: "commerce_purchase_quotes_operation_index"
                   )

    alter table(:commerce_purchase_quotes) do
      remove :offer_id
      remove :offered_at
      remove :decision
      remove :state
      remove :disclosure_fingerprint
      remove :disclosure_id
      remove :language
      remove :recipient_id
      remove :payer_id
      remove :operation_id
    end

    drop_if_exists constraint(:commerce_plan_purchases, :commerce_plan_purchases_terms)

    drop constraint(:commerce_plan_purchases, "commerce_plan_purchases_quote_id_fkey")

    alter table(:commerce_plan_purchases) do
      modify :quote_id, :uuid
    end

    drop table(:commerce_purchase_quotes)

    drop_if_exists constraint(
                     :temperament_assessment_delivery_evidence,
                     :assessment_delivery_evidence_shape
                   )

    drop table(:temperament_assessment_delivery_evidence)

    drop_if_exists constraint(
                     :entitlements_assessment_credit_evidence,
                     :assessment_credit_evidence_shape
                   )

    drop table(:entitlements_assessment_credit_evidence)

    drop_if_exists index(:commerce_plan_purchases, [:payer_id])

    drop_if_exists index(:commerce_plan_purchases, [:recipient_id])

    create constraint(:commerce_plan_purchases, :commerce_plan_purchases_price,
             check: """
               price_version = 'synthetic-plan-v1' AND amount_minor = 39900 AND currency = 'ZAR'
             """
           )

    create constraint(:commerce_plan_purchases, :commerce_plan_purchases_same_account,
             check: """
               payer_id = recipient_id
             """
           )

    drop_if_exists unique_index(:commerce_plan_purchases, [:quote_id],
                     name: "commerce_plan_purchases_quote_index"
                   )

    alter table(:commerce_plan_purchases) do
      remove :quote_id
    end
  end

  defp protect_history do
    offers = relation(:commerce_offer_versions)
    quotes = relation(:commerce_purchase_quotes)
    purchases = relation(:commerce_plan_purchases)
    admissions = relation(:commerce_assessment_admissions)
    guard_update = relation(:well197_guard_update)
    check_acceptance = relation(:well197_check_acceptance)

    execute """
    CREATE FUNCTION #{guard_update}() RETURNS trigger
    LANGUAGE plpgsql SET search_path = pg_catalog AS $$
    BEGIN
      CASE TG_TABLE_NAME
        WHEN 'commerce_offer_versions' THEN
          IF OLD.state = 'draft' AND NEW.state = 'approved' AND
             to_jsonb(NEW) - ARRAY['state', 'approved_at', 'approval_id', 'allocation_approval_id',
                                    'disclosure_en_id', 'disclosure_af_id'] =
             to_jsonb(OLD) - ARRAY['state', 'approved_at', 'approval_id', 'allocation_approval_id',
                                    'disclosure_en_id', 'disclosure_af_id'] THEN
            RETURN NEW;
          END IF;

          IF OLD.state = 'approved' AND NEW.state IN ('superseded', 'withdrawn') AND
             to_jsonb(NEW) - ARRAY['state', 'withdrawal_id'] =
             to_jsonb(OLD) - ARRAY['state', 'withdrawal_id'] THEN
            RETURN NEW;
          END IF;
        WHEN 'commerce_purchase_quotes' THEN
          IF OLD.state IN ('offered', 'reconciling') AND
             NEW.state IN ('accepted', 'rejected', 'reconciling', 'stale') AND
             to_jsonb(NEW) - ARRAY['state', 'decision'] = to_jsonb(OLD) - ARRAY['state', 'decision'] THEN
            RETURN NEW;
          END IF;
        WHEN 'commerce_assessment_admissions' THEN
          IF ((OLD.state = 'pending' AND NEW.state IN ('paid', 'nonpayable')) OR
              (OLD.state = 'paid' AND NEW.state = 'reconciled')) AND
             to_jsonb(NEW) - ARRAY['state', 'resolved_at', 'resolution_id'] =
             to_jsonb(OLD) - ARRAY['state', 'resolved_at', 'resolution_id'] THEN
            RETURN NEW;
          END IF;
        ELSE
          NULL;
      END CASE;

      RAISE EXCEPTION 'immutable offer acceptance evidence or invalid lifecycle transition'
        USING ERRCODE = '23514', CONSTRAINT = 'well197_history_update';
    END $$;
    """

    for table <- [offers, quotes, purchases, admissions] do
      execute """
      CREATE TRIGGER well197_guard_update BEFORE UPDATE ON #{table}
      FOR EACH ROW EXECUTE FUNCTION #{guard_update}();
      """
    end

    execute """
    CREATE FUNCTION #{check_acceptance}() RETURNS trigger
    LANGUAGE plpgsql SET search_path = pg_catalog AS $$
    DECLARE
      quote_key uuid;
    BEGIN
      IF TG_TABLE_NAME = 'commerce_plan_purchases' THEN
        quote_key := NEW.quote_id;
      ELSE
        SELECT id INTO quote_key FROM #{quotes} WHERE id = NEW.id AND state = 'accepted';
      END IF;

      IF quote_key IS NULL THEN
        RETURN NULL;
      END IF;

      IF NOT EXISTS (
        SELECT 1 FROM #{quotes} q
        JOIN #{offers} o ON o.id = q.offer_id
        JOIN #{purchases} p ON p.quote_id = q.id
        LEFT JOIN #{admissions} a ON a.purchase_id = p.id
        WHERE q.id = quote_key AND q.state = 'accepted' AND
          q.operation_id = p.operation_id AND q.payer_id = p.payer_id AND q.recipient_id = p.recipient_id AND
          p.price_version = o.price_version AND p.currency = o.currency AND p.amount_minor = o.amount_minor AND
          q.disclosure_id = CASE q.language WHEN 'en' THEN o.disclosure_en_id ELSE o.disclosure_af_id END AND
          (p.accepted_at AT TIME ZONE 'UTC') >= o.approved_at AND
          (o.expires_at IS NULL OR (p.accepted_at AT TIME ZONE 'UTC') < o.expires_at) AND
          ((o.product = 'plan' AND a.purchase_id IS NULL) OR
           (o.product IN ('assessment', 'bundle') AND a.recipient_id = p.recipient_id))
      ) THEN
        RAISE EXCEPTION 'incomplete versioned acceptance'
          USING ERRCODE = '23514', CONSTRAINT = 'well197_complete_acceptance';
      END IF;

      RETURN NULL;
    END $$;
    """

    execute """
    CREATE CONSTRAINT TRIGGER well197_complete_acceptance
    AFTER INSERT ON #{purchases} DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION #{check_acceptance}();
    """

    execute """
    CREATE CONSTRAINT TRIGGER well197_complete_acceptance
    AFTER INSERT OR UPDATE ON #{quotes} DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION #{check_acceptance}();
    """
  end

  defp remove_history_guards do
    for table <- [
          :commerce_offer_versions,
          :commerce_purchase_quotes,
          :commerce_plan_purchases,
          :commerce_assessment_admissions
        ] do
      execute("DROP TRIGGER well197_guard_update ON #{relation(table)}")
    end

    for table <- [:commerce_plan_purchases, :commerce_purchase_quotes] do
      execute("DROP TRIGGER well197_complete_acceptance ON #{relation(table)}")
    end

    execute("DROP FUNCTION #{relation(:well197_guard_update)}()")
    execute("DROP FUNCTION #{relation(:well197_check_acceptance)}()")
  end

  defp relation(name) do
    schema = String.replace(prefix() || "public", "\"", "\"\"")
    ~s("#{schema}"."#{name}")
  end
end
