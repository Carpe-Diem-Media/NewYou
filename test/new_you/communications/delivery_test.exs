defmodule NewYou.Communications.DeliveryTest do
  use ExUnit.Case, async: false
  alias NewYou.{Communications, Identity}
  alias NewYou.Proof.P805

  test "admission commits before provider I/O and delivery never verifies Identity" do
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

  test "unknown blocks blind retry and only authenticated no-operation allows a new attempt" do
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

  test "consumed source closes send authority and destroys the envelope" do
    P805.with_fixture(fn ->
      {:ok, registration} = Identity.register(P805.request())
      [intent] = Ash.read!(Communications.MessageIntent, authorize?: false)
      assert {:ok, :verified} = Identity.verify_email(registration.verification_proof)
      Process.put(:p810_provider, fn _, _ -> flunk("stale source invoked provider") end)
      assert {:ok, :source_invalid} = Communications.execute(intent.id)
      assert [] == Ash.read!(Communications.DeliveryAttempt, authorize?: false)
      assert [] == Ash.read!(Communications.ProtectedEnvelope, authorize?: false)
    end)
  after
    Process.delete(:p810_provider)
  end

  test "source invalidation during unresolved delivery clears secrets without permitting retry" do
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

  test "outer transactions cannot encompass provider I/O" do
    P805.with_fixture(fn ->
      {:ok, _} = Identity.register(P805.request())
      [intent] = Ash.read!(Communications.MessageIntent, authorize?: false)

      result =
        Ash.transact([Communications.MessageIntent], fn ->
          Communications.execute(intent.id)
        end)

      assert match?({:error, _}, result)
      assert [] == Ash.read!(Communications.DeliveryAttempt, authorize?: false)
    end)
  end

  test "consumption between admission and invocation truthfully closes the uninvoked attempt" do
    P805.with_fixture(fn ->
      {:ok, registration} = Identity.register(P805.request())
      [intent] = Ash.read!(Communications.MessageIntent, authorize?: false)
      Process.put(:p810_provider, fn _, _ -> flunk("consumed proof submitted") end)

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
    end)
  after
    Process.delete(:p810_provider)
    Process.delete(NewYou.Proof.DeliverySeam)
  end
end
