defmodule NewYou.Proof.DeliveryScenarios do
  @moduledoc false
  import ExUnit.Assertions
  alias NewYou.{Communications, Identity}
  alias NewYou.Proof.P805

  def scenario_admission_commits_before_provider_i_o_and_delivery_never_verifies_identity() do
    P805.with_fixture(fn ->
      {:ok, registration} = Identity.register(P805.request())
      [intent] = Ash.read!(Communications.MessageIntent, authorize?: false)

      Process.put(:p810_provider, fn attempt, payload ->
        refute NewYou.Repo.in_transaction?()

        assert attempt.id ==
                 Ash.get!(Communications.DeliveryAttempt, attempt.id, authorize?: false).id

        assert payload.destination == intent.destination
        assert String.contains?(payload.body, "/verification/confirm")
        :delivered
      end)

      assert {:ok, :processed} = Communications.execute(intent.id)

      assert Ash.get!(Communications.MessageIntent, intent.id, authorize?: false).dispatch_disposition ==
               :closed

      refute Ash.get!(Identity.Account, registration.account_id, authorize?: false).email_verified?

      assert Ash.read!(Communications.ProtectedEnvelope, authorize?: false) == []
    end)
  after
    Process.delete(:p810_provider)
  end

  def scenario_unknown_blocks_blind_retry_and_only_authenticated_no_operation_allows_a_new_attempt() do
    P805.with_fixture(fn ->
      {:ok, _} = Identity.register(P805.request())
      [intent] = Ash.read!(Communications.MessageIntent, authorize?: false)
      Process.put(:p810_provider, fn _, _ -> :unknown end)
      assert {:ok, :processed} = Communications.execute(intent.id)
      [attempt] = Ash.read!(Communications.DeliveryAttempt, authorize?: false)
      assert {:ok, :waiting} = Communications.execute(intent.id)

      assert {:error, :unauthenticated} =
               Communications.reconcile(
                 attempt.id,
                 :confirmed_no_operation,
                 "proof-1",
                 <<0::256>>
               )

      Application.put_env(:new_you, :communications_proof_evidence_key, String.duplicate("k", 32))

      signature =
        :crypto.mac(
          :hmac,
          :sha256,
          String.duplicate("k", 32),
          attempt.id <> "|confirmed_no_operation|proof-1"
        )

      assert {:ok, :recorded} =
               Communications.reconcile(attempt.id, :confirmed_no_operation, "proof-1", signature)

      Process.put(:p810_provider, fn _, _ -> :delivered end)
      assert {:ok, :processed} = Communications.execute(intent.id)
      attempts = Ash.read!(Communications.DeliveryAttempt, authorize?: false)
      assert length(attempts) == 2
      assert Enum.all?(attempts, &(&1.content_sha256 == intent.content_sha256))
    end)
  after
    Process.delete(:p810_provider)
    Application.delete_env(:new_you, :communications_proof_evidence_key)
  end

  def scenario_consumed_source_closes_send_authority_and_destroys_the_envelope() do
    P805.with_fixture(fn ->
      {:ok, registration} = Identity.register(P805.request())
      [intent] = Ash.read!(Communications.MessageIntent, authorize?: false)
      assert {:ok, :verified} = Identity.verify_email(registration.verification_proof)
      Process.put(:p810_provider, &stale_source_provider/2)
      assert {:ok, :source_invalid} = Communications.execute(intent.id)
      assert [] == Ash.read!(Communications.DeliveryAttempt, authorize?: false)
      assert [] == Ash.read!(Communications.ProtectedEnvelope, authorize?: false)
    end)
  after
    Process.delete(:p810_provider)
  end

  def scenario_source_invalidation_during_unresolved_delivery_clears_secrets_without_permitting_retry() do
    P805.with_fixture(fn ->
      {:ok, registration} = Identity.register(P805.request())
      [intent] = Ash.read!(Communications.MessageIntent, authorize?: false)
      Process.put(:p810_provider, fn _, _ -> :accepted end)
      assert {:ok, :processed} = Communications.execute(intent.id)
      assert {:ok, :verified} = Identity.verify_email(registration.verification_proof)
      assert {:ok, :source_invalid} = Communications.execute(intent.id)
      assert [] == Ash.read!(Communications.ProtectedEnvelope, authorize?: false)
      [attempt] = Ash.read!(Communications.DeliveryAttempt, authorize?: false)
      assert attempt.active
      assert attempt.provider_observation == :accepted
      assert {:ok, :closed} = Communications.execute(intent.id)
    end)
  after
    Process.delete(:p810_provider)
  end

  def scenario_outer_transactions_cannot_encompass_provider_i_o() do
    P805.with_fixture(fn ->
      {:ok, _} = Identity.register(P805.request())
      [intent] = Ash.read!(Communications.MessageIntent, authorize?: false)

      result =
        Ash.transact([Communications.MessageIntent], fn -> Communications.execute(intent.id) end)

      assert match?({:error, _}, result)
      assert [] == Ash.read!(Communications.DeliveryAttempt, authorize?: false)
    end)
  end

  def scenario_consumption_between_admission_and_invocation_truthfully_closes_the_uninvoked_attempt() do
    P805.with_fixture(fn ->
      scenario_consumption_between_admission_and_invocation_truthfully_closes_the_uninvoked_attempt_fixture()
    end)
  after
    Process.delete(:p810_provider)
    Process.delete(NewYou.Proof.DeliverySeam)
  end

  defp scenario_consumption_between_admission_and_invocation_truthfully_closes_the_uninvoked_attempt_fixture() do
    {:ok, registration} = Identity.register(P805.request())
    [intent] = Ash.read!(Communications.MessageIntent, authorize?: false)
    Process.put(:p810_provider, &consumed_proof_provider/2)

    Process.put(NewYou.Proof.DeliverySeam, fn point ->
      if point == :after_admission do
        assert {:ok, :verified} = Identity.verify_email(registration.verification_proof)
      end
    end)

    assert {:ok, :source_invalid} = Communications.execute(intent.id)
    [attempt] = Ash.read!(Communications.DeliveryAttempt, authorize?: false)
    assert attempt.admission == :closed_before_invocation
    assert attempt.invocation_started_at == nil
    refute attempt.active
  end

  @spec stale_source_provider(term(), term()) :: no_return()
  defp stale_source_provider(_, _), do: flunk("stale source invoked provider")

  @spec consumed_proof_provider(term(), term()) :: no_return()
  defp consumed_proof_provider(_, _), do: flunk("consumed proof submitted")
end
