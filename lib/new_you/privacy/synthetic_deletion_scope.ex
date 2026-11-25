defmodule NewYou.Privacy.SyntheticDeletionScope do
  @moduledoc false

  use Ash.Resource,
    otp_app: :new_you,
    domain: NewYou.Privacy,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "privacy_synthetic_deletion_scopes"
    repo NewYou.Repo
  end

  actions do
    read :read do
      primary? true
      public? false
    end

    create :register do
      public? false
      accept [:subject_id]
    end

    update :suppress do
      public? false
      accept []
      change atomic_update(:suppressed?, true)
    end
  end

  policies do
    policy always() do
      forbid_if always()
    end
  end

  attributes do
    attribute :subject_id, :uuid, primary_key?: true, allow_nil?: false
    attribute :suppressed?, :boolean, allow_nil?: false, default: false, source: :suppressed
  end
end
