defmodule NewYou.Repo.Migrations.Well14RoleScopes do
  @moduledoc "Preserve each existing assignment's authority while replacing direct capabilities with bounded Support scopes."

  use Ecto.Migration

  def up do
    drop_if_exists unique_index(
                     :identity_grants,
                     [:subject_account_id, :role, :capability, :target_account_id],
                     name: "identity_grants_one_active_assignment_index"
                   )

    drop_if_exists constraint(:identity_grants, :identity_grants_capability)

    rename table(:identity_grants), :capability, to: :scope
    flush()

    execute """
    UPDATE identity_grants SET scope = CASE scope
      WHEN 'place_security_hold' THEN 'security_hold_restriction'
      WHEN 'review_security_hold' THEN 'security_hold_review'
      WHEN 'release_security_hold' THEN 'security_hold_release'
    END
    """

    create unique_index(
             :identity_grants,
             [:subject_account_id, :role, :scope, :target_account_id],
             name: "identity_grants_one_active_assignment_index",
             where: "(state = 'active')"
           )

    create constraint(:identity_grants, :identity_grants_scope,
             check: """
               scope IN ('security_hold_restriction', 'security_hold_review', 'security_hold_release')
             """
           )
  end

  def down do
    # Grant history and selected security evidence cannot be discarded by a
    # schema rollback. Empty development databases can still roll back.
    execute """
    DO $$ BEGIN
      IF EXISTS (SELECT 1 FROM identity_grants) THEN
        RAISE EXCEPTION 'Cannot roll back Support scope authority while grant history exists';
      END IF;
    END $$;
    """

    drop_if_exists constraint(:identity_grants, :identity_grants_scope)

    drop_if_exists unique_index(
                     :identity_grants,
                     [:subject_account_id, :role, :scope, :target_account_id],
                     name: "identity_grants_one_active_assignment_index"
                   )

    rename table(:identity_grants), :scope, to: :capability

    create constraint(:identity_grants, :identity_grants_capability,
             check: """
               capability IN ('place_security_hold', 'review_security_hold', 'release_security_hold')
             """
           )

    create unique_index(
             :identity_grants,
             [:subject_account_id, :role, :capability, :target_account_id],
             name: "identity_grants_one_active_assignment_index",
             where: "(state = 'active')"
           )
  end
end
