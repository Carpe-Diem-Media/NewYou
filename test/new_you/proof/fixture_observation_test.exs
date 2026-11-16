defmodule NewYou.Proof.FixtureObservationTest do
  use ExUnit.Case, async: false

  alias NewYou.{Communications, Identity, Repo}
  alias NewYou.Proof.P805
  require Ash.Query

  test "observations exclude other operations and retain every same-fixture attempt" do
    P805.with_fixture(fn ->
      own = P805.request()
      foreign = P805.request()
      {:ok, own_registration} = Identity.register(own)
      {:ok, foreign_registration} = Identity.register(foreign)
      context = {[own.operation_id], [own.email]}

      [intent] = P805.read(Communications.MessageIntent, Communications, context)
      assert intent.source_operation_id == own.operation_id
      [account] = P805.read(Identity.Account, Identity, context)
      assert account.id == own_registration.account_id
      refute account.id == foreign_registration.account_id
      [token] = P805.read(Identity.Token, Identity, context)
      assert token.account_id == own_registration.account_id
      [operation] = P805.read(Identity.RegistrationOperation, Identity, context)
      assert operation.operation_id == own.operation_id
      [envelope] = P805.read(Communications.ProtectedEnvelope, Communications, context)
      assert envelope.message_intent_id == intent.id

      Process.put(:p810_provider, fn _, _ -> :rejected_before_submission end)
      assert {:ok, :processed} = Communications.execute(intent.id)
      assert length(P805.read(Communications.DeliveryAttempt, Communications, context)) == 1
      assert {:ok, :processed} = Communications.execute(intent.id)
      attempts = P805.read(Communications.DeliveryAttempt, Communications, context)
      assert length(attempts) == 2
      assert Enum.all?(attempts, &(&1.message_intent_id == intent.id))

      [foreign_intent] = P805.intents(foreign.operation_id)
      assert {:ok, :processed} = Communications.execute(foreign_intent.id)
      assert length(P805.read(Communications.DeliveryAttempt, Communications, context)) == 2
      assert length(P805.read(Communications.MessageIntent, Communications)) == 2
    end)
  after
    Process.delete(:p810_provider)
  end

  test "an unsupported foreign enum is excluded before hydration and restored by rollback" do
    P805.with_fixture(fn ->
      own = P805.request()
      foreign = P805.request()
      {:ok, _} = Identity.register(own)
      {:ok, _} = Identity.register(foreign)
      [foreign_intent] = P805.intents(foreign.operation_id)
      context = {[own.operation_id], [own.email]}
      marker = make_ref()

      constraint_query =
        "SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conrelid = 'public.message_intents'::regclass AND conname = 'message_intents_disposition'"

      %{rows: [[constraint_before]]} = Repo.query!(constraint_query)

      assert {:error, decoder_error} =
               Repo.transaction(fn ->
                 Repo.query!("SET LOCAL lock_timeout = '2s'")

                 Repo.query!(
                   "ALTER TABLE message_intents DROP CONSTRAINT message_intents_disposition"
                 )

                 Repo.query!(
                   "UPDATE message_intents SET dispatch_disposition = $1 WHERE id = $2",
                   [
                     "well114_unsupported_foreign",
                     Ecto.UUID.dump!(foreign_intent.id)
                   ]
                 )

                 [intent] = P805.read(Communications.MessageIntent, Communications, context)
                 assert intent.source_operation_id == own.operation_id
                 send(self(), {:scoped_before_decode, marker})

                 Communications.MessageIntent
                 |> Ash.Query.filter(id == ^foreign_intent.id)
                 |> Ash.read!(authorize?: false)

                 flunk("unsupported synthetic foreign enum unexpectedly decoded")
               end)

      assert_receive {:scoped_before_decode, ^marker}
      assert %Ash.Query{errors: errors} = decoder_error

      assert Enum.any?(errors, fn error ->
               message = Exception.message(error)
               message =~ "well114_unsupported_foreign" and message =~ "cannot load"
             end)

      assert %{rows: [[^constraint_before]]} = Repo.query!(constraint_query)

      assert Ash.get!(Communications.MessageIntent, foreign_intent.id, authorize?: false).dispatch_disposition ==
               :open
    end)
  end
end
