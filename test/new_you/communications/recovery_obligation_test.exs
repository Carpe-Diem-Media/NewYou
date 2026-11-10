defmodule NewYou.Communications.RecoveryObligationTest do
  use NewYou.DataCase, async: false

  alias NewYou.{Communications, Identity}
  alias NewYou.Communications.MessageIntent
  alias NewYou.Proof.P805

  require Ash.Query

  test "recovery obligations are immutable, held and never sent without eligible content" do
    P805.with_fixture(fn ->
      request = P805.request(%{preferred_language: :en})
      {:ok, _registration} = Identity.register(request)
      operation_id = Ecto.UUID.generate()
      P805.track_operation(operation_id)
      reference = Joken.generate_jti()
      attrs = recovery_attrs(request.email, operation_id, reference)

      assert {:ok, intent} = Communications.establish_recovery(attrs)
      assert intent.role == :account_recovery
      assert intent.source_purpose == "recovery"
      assert intent.render_schema == "recovery-v1"
      assert intent.source_reference == reference
      assert intent.destination == request.email
      assert intent.content_item_id == nil
      assert intent.content_version_id == nil
      assert intent.translation_version_id == nil
      assert intent.content_sha256 == nil
      assert intent.platform_name == nil
      assert intent.render_digest == nil
      assert intent.dispatch_disposition == :held
      assert intent.terminal_reason == "content_ineligible"

      assert {:ok, replay} = Communications.establish_recovery(attrs)
      assert replay.id == intent.id

      assert {:error, :recovery_obligation_unavailable} =
               Communications.establish_recovery(
                 Map.put(attrs, :destination, "changed@example.test")
               )

      Process.put(:p810_provider, fn _, _ -> flunk("recovery must not reach a provider") end)
      assert {:ok, :held} = Communications.execute(intent.id)

      assert [persisted] =
               MessageIntent
               |> Ash.Query.filter(source_reference == ^reference)
               |> Ash.read!(authorize?: false)

      assert persisted.id == intent.id

      assert [] =
               Communications.DeliveryAttempt
               |> Ash.Query.filter(message_intent_id == ^intent.id)
               |> Ash.read!(authorize?: false)
    end)
  after
    Process.delete(:p810_provider)
  end

  test "recovery completion notices use their own role and remain held" do
    P805.with_fixture(fn ->
      request = P805.request(%{preferred_language: :en})
      {:ok, _registration} = Identity.register(request)
      operation_id = Ecto.UUID.generate()
      P805.track_operation(operation_id)
      reference = Joken.generate_jti()

      assert {:ok, intent} =
               Communications.establish_recovery_notice(
                 recovery_attrs(request.email, operation_id, reference)
               )

      assert intent.role == :recovery_security_notice
      assert intent.source_purpose == "recovery_completed"
      assert intent.render_schema == "recovery-notice-v1"
      assert intent.dispatch_disposition == :held
      assert intent.terminal_reason == "content_ineligible"
    end)
  end

  defp recovery_attrs(destination, operation_id, reference) do
    %{
      source_operation_id: operation_id,
      source_reference: reference,
      destination: destination,
      destination_provenance: "identity_recovery_issuance",
      destination_authorized_at: DateTime.utc_now(),
      locale: "en"
    }
  end
end
