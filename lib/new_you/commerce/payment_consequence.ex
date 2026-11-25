defmodule NewYou.Commerce.PaymentConsequence do
  @moduledoc false

  use Ash.Resource,
    otp_app: :new_you,
    domain: NewYou.Commerce,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshOban],
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "commerce_payment_consequences"
    repo NewYou.Repo

    custom_indexes do
      index [:id], where: "fulfilled_at IS NULL", name: "commerce_payment_consequences_open"
    end
  end

  oban do
    triggers do
      trigger :deliver_plan_payment do
        action :deliver
        where expr(is_nil(fulfilled_at))
        scheduler_cron "* * * * *"
        queue :commerce
        worker_module_name NewYou.Commerce.Workers.DeliverPlanPayment
        scheduler_module_name NewYou.Commerce.Schedulers.DeliverPlanPayment
      end
    end
  end

  actions do
    action :deliver do
      public? false
      argument :primary_key, :map, allow_nil?: false, sensitive?: true
      run NewYou.Commerce.DeliverPlanPayment
    end

    update :acknowledge do
      public? false
      accept [:fulfilled_at]
    end

    read :read do
      primary? true
      public? false

      pagination do
        keyset? true
        required? false
      end
    end

    create :establish do
      public? false
      accept [:purchase_id, :payment_id]
    end
  end

  policies do
    policy action([:read, :deliver]) do
      authorize_if AshOban.Checks.AshObanInteraction
    end
  end

  attributes do
    uuid_v7_primary_key :id
    create_timestamp :established_at
    attribute :fulfilled_at, AshPostgres.TimestamptzUsec
  end

  relationships do
    belongs_to :purchase, NewYou.Commerce.Purchase do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :payment, NewYou.Commerce.VerifiedPayment do
      allow_nil? false
      attribute_writable? true
    end
  end

  identities do
    identity :purchase, [:purchase_id]
    identity :payment, [:payment_id]
  end
end
