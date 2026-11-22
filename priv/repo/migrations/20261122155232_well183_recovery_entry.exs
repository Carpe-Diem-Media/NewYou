defmodule NewYou.Repo.Migrations.Well183RecoveryEntry do
  @moduledoc "Record immutable Recovery entry context and admit its exact delivery schemas."

  use Ecto.Migration

  def up do
    drop_if_exists constraint(:message_intents, :message_intents_role_purpose_schema)

    create constraint(:message_intents, :message_intents_role_purpose_schema,
             check: """
               (role = 'account_verification' AND source_purpose = 'email_verification' AND render_schema = 'verification-v1') OR (role = 'magic_login' AND source_purpose = 'magic_login' AND render_schema = 'magic-login-v1') OR (role = 'password_reset' AND source_purpose = 'password_reset' AND render_schema IN ('password-reset-v1', 'password-reset-well136-v1')) OR (role = 'account_recovery' AND source_purpose = 'recovery' AND render_schema IN ('recovery-v1', 'recovery-well183-v1')) OR (role = 'recovery_security_notice' AND source_purpose = 'recovery_completed' AND render_schema IN ('recovery-notice-v1', 'recovery-notice-well183-v1')) OR (role = 'email_change_confirmation' AND source_purpose = 'email_change_confirmation' AND render_schema = 'email-change-confirmation-v1') OR (role = 'email_change_old_address_notice' AND source_purpose = 'email_change_old_address_notice' AND render_schema = 'email-change-old-address-notice-v1')
             """
           )

    alter table(:recovery_cases) do
      add :entry_context, :text, null: false, default: "p8_15"
    end

    create constraint(:recovery_cases, :recovery_cases_entry_context,
             check: """
               entry_context IN ('p8_15','well183')
             """
           )
  end

  def down do
    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM recovery_cases WHERE entry_context = 'well183')
         OR EXISTS (SELECT 1 FROM message_intents
                    WHERE render_schema IN ('recovery-well183-v1', 'recovery-notice-well183-v1')) THEN
        RAISE EXCEPTION 'well183_recovery_context_history_required' USING ERRCODE = '23514';
      END IF;
    END $$;
    """

    drop_if_exists constraint(:recovery_cases, :recovery_cases_entry_context)

    alter table(:recovery_cases) do
      remove :entry_context
    end

    drop_if_exists constraint(:message_intents, :message_intents_role_purpose_schema)

    create constraint(:message_intents, :message_intents_role_purpose_schema,
             check: """
               (role = 'account_verification' AND source_purpose = 'email_verification' AND render_schema = 'verification-v1') OR (role = 'magic_login' AND source_purpose = 'magic_login' AND render_schema = 'magic-login-v1') OR (role = 'password_reset' AND source_purpose = 'password_reset' AND render_schema IN ('password-reset-v1', 'password-reset-well136-v1')) OR (role = 'account_recovery' AND source_purpose = 'recovery' AND render_schema = 'recovery-v1') OR (role = 'recovery_security_notice' AND source_purpose = 'recovery_completed' AND render_schema = 'recovery-notice-v1') OR (role = 'email_change_confirmation' AND source_purpose = 'email_change_confirmation' AND render_schema = 'email-change-confirmation-v1') OR (role = 'email_change_old_address_notice' AND source_purpose = 'email_change_old_address_notice' AND render_schema = 'email-change-old-address-notice-v1')
             """
           )
  end
end
