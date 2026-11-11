defmodule NewYou.Communications.RecoveryDeliveryPreparationTest do
  use ExUnit.Case, async: false

  require Ash.Query
  alias NewYou.{Communications, Identity}
  alias NewYou.Identity.{Account, DeliveryEligibility, RecoveryCase, Token}
  alias NewYou.Proof.P805

  test "source admission is read-only, transaction-bound and exact to the issued intent" do
    P805.with_fixture(fn ->
      {request, recovery, intent} = pending()
      before = snapshot(recovery)

      assert guard(:recovery, intent) == :ok
      assert snapshot(recovery) == before

      assert DeliveryEligibility.recovery(
               intent.source_reference,
               intent.destination,
               intent.locale,
               intent.source_operation_id
             ) == {:error, :source_invalid}

      for attrs <- [
            %{source_operation_id: operation()},
            %{destination: "other@example.test"},
            %{locale: "af"},
            %{source_reference: Joken.generate_jti()}
          ] do
        assert guard(:recovery, Map.merge(intent, attrs)) == {:error, :source_invalid}
      end

      assert guard(:recovery_notice, intent) == {:error, :source_invalid}
      assert request.email == intent.destination
      assert snapshot(recovery) == before
      assert_held(intent)
    end)
  end

  test "accepted, cancelled and expired proof cannot authorize delivery" do
    P805.with_fixture(fn ->
      {_request, recovery, intent} = pending()
      bearer = bearer(intent)
      assert {:ok, :accepted} = Identity.submit_recovery_proof(bearer, operation())
      assert guard(:recovery, intent) == {:error, :source_invalid}
      assert guard(:recovery_notice, intent) == {:error, :source_invalid}
      assert {:ok, :cancelled} = Identity.cancel_recovery(bearer, operation())
      assert guard(:recovery, intent) == {:error, :source_invalid}
      assert snapshot(recovery).case.state == :cancelled

      {_request, _recovery, pending_intent} = pending()
      Process.put({NewYou.Proof.RecoverySeam, :now}, DateTime.add(DateTime.utc_now(), 3601))
      assert guard(:recovery, pending_intent) == {:error, :source_invalid}
      assert {:error, :source_invalid} = delivery(pending_intent)
    end)
  after
    Process.delete({NewYou.Proof.RecoverySeam, :now})
  end

  test "only the committed completion receipt authorizes its notice beyond link expiry" do
    P805.with_fixture(fn ->
      {request, recovery, intent} = pending()
      bearer = bearer(intent)
      assert {:ok, :accepted} = Identity.submit_recovery_proof(bearer, operation())
      completion = operation()

      assert {:ok, :completed} =
               Identity.complete_recovery(
                 bearer,
                 "a separate replacement recovery credential",
                 completion
               )

      notice =
        Communications.MessageIntent
        |> Ash.Query.filter(
          source_operation_id == ^completion and role == :recovery_security_notice
        )
        |> Ash.read_one!(authorize?: false)

      before = snapshot(recovery)
      assert guard(:recovery_notice, notice) == :ok

      assert DeliveryEligibility.recovery_notice(
               notice.source_reference,
               notice.locale,
               notice.source_operation_id
             ) == {:error, :source_invalid}

      assert guard(:recovery_notice, Map.put(notice, :source_operation_id, operation())) ==
               {:error, :source_invalid}

      assert guard(:recovery_notice, Map.put(notice, :locale, "af")) ==
               {:error, :source_invalid}

      assert guard(:recovery, intent) == {:error, :source_invalid}

      Process.put({NewYou.Proof.RecoverySeam, :now}, DateTime.add(DateTime.utc_now(), 7200))
      assert guard(:recovery_notice, notice) == :ok
      assert snapshot(recovery) == before
      assert_held(notice)
      assert snapshot(recovery) == before

      # Revoking authentication material cannot erase a committed security notice.
      Ash.update!(before.token, %{}, action: :revoke_recovery, authorize?: false)
      assert guard(:recovery_notice, notice) == :ok
      assert guard(:recovery, intent) == {:error, :source_invalid}

      replace_with_reset(request, recovery.account_id)

      assert snapshot(recovery).account.credential_version ==
               before.account.credential_version + 1

      assert guard(:recovery_notice, notice) == :ok

      assert Ash.get!(Communications.MessageIntent, notice.id, authorize?: false).destination ==
               notice.destination
    end)
  after
    Process.delete({NewYou.Proof.RecoverySeam, :now})
  end

  test "a later Account credential change invalidates the original delivery source" do
    P805.with_fixture(fn ->
      {request, recovery, intent} = pending()
      replace_with_reset(request, recovery.account_id)

      before = snapshot(recovery)
      assert guard(:recovery, intent) == {:error, :source_invalid}
      assert snapshot(recovery) == before
    end)
  end

  defp replace_with_reset(request, account_id) do
    :ok = Identity.request_password_reset(request.email, "en", operation())

    reset =
      Token
      |> Ash.Query.filter(account_id == ^account_id and purpose == "password_reset")
      |> Ash.read_one!(authorize?: false)

    {:ok, {:ok, proof}} =
      Ash.transact([Account, Token], fn ->
        Identity.password_reset_delivery(reset.jti, request.email, "en")
      end)

    assert {:ok, :reset} =
             Identity.reset_password(proof, "a different reset credential", operation())
  end

  defp guard(function, intent) do
    {:ok, {:ok, result}} =
      Ash.transact([Account, RecoveryCase, Token], fn ->
        args =
          if function == :recovery_notice,
            do: [intent.source_reference, intent.locale, intent.source_operation_id],
            else: [
              intent.source_reference,
              intent.destination,
              intent.locale,
              intent.source_operation_id
            ]

        {:ok, apply(DeliveryEligibility, function, args)}
      end)

    result
  end

  defp delivery(intent) do
    {:ok, {:ok, result}} =
      Ash.transact([Account, RecoveryCase, Token], fn ->
        {:ok,
         Identity.recovery_delivery(intent.source_reference, intent.destination, intent.locale)}
      end)

    result
  end

  defp bearer(intent) do
    {:ok, proof} = delivery(intent)
    proof
  end

  defp snapshot(recovery),
    do: %{
      case: Ash.get!(RecoveryCase, recovery.id, authorize?: false),
      account: Ash.get!(Account, recovery.account_id, authorize?: false),
      token: Ash.get!(Token, recovery.proof_jti, authorize?: false)
    }

  defp assert_held(intent) do
    Process.put(:p810_provider, fn _, _ ->
      flunk("source eligibility cannot grant provider admission")
    end)

    assert {:ok, :held} = Communications.execute(intent.id)

    assert [] ==
             Communications.DeliveryAttempt
             |> Ash.Query.filter(message_intent_id == ^intent.id)
             |> Ash.read!(authorize?: false)
  after
    Process.delete(:p810_provider)
  end

  defp pending do
    request = P805.request(%{preferred_language: :en})
    {:ok, registered} = Identity.register(request)
    {:ok, :verified} = Identity.verify_email(registered.verification_proof)
    operation = operation()
    :ok = Identity.request_recovery(request.email, "en", operation)

    recovery =
      RecoveryCase
      |> Ash.Query.filter(account_id == ^registered.account_id)
      |> Ash.read_one!(authorize?: false)

    intent =
      Communications.MessageIntent
      |> Ash.Query.filter(source_operation_id == ^operation)
      |> Ash.read_one!(authorize?: false)

    {request, recovery, intent}
  end

  defp operation do
    id = Ecto.UUID.generate()
    P805.track_operation(id)
    id
  end
end
