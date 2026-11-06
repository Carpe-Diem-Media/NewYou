defmodule NewYou.Communications.DeliveryEvidenceTest do
  use ExUnit.Case, async: false
  alias NewYou.{Communications, Identity, Repo}
  alias NewYou.Proof.P805

  setup do
    Application.put_env(
      :new_you,
      :communications_proof_evidence_key,
      :crypto.strong_rand_bytes(32)
    )

    on_exit(fn -> Application.delete_env(:new_you, :communications_proof_evidence_key) end)
  end

  test "accepted stays pending; duplicate and reordered observations never regress delivery" do
    P805.with_fixture(fn ->
      {:ok, registration} = Identity.register(P805.request())
      [intent] = Ash.read!(Communications.MessageIntent, authorize?: false)
      Process.put(:p810_provider, fn _, _ -> :accepted end)
      assert {:ok, :processed} = Communications.execute(intent.id)
      [attempt] = attempts()
      assert attempt.provider_observation == :accepted
      assert disposition(intent) == :reconciliation_required
      assert {:ok, :waiting} = Communications.execute(intent.id)
      evidence(attempt, :delivered, "delivered-event")
      evidence(attempt, :accepted, "early-event")
      evidence(attempt, :delivered, "delivered-event")
      evidence(attempt, :unknown, "delayed-timeout")
      assert hd(attempts()).provider_observation == :delivered
      assert disposition(intent) == :closed

      refute Ash.get!(Identity.Account, registration.account_id, authorize?: false).email_verified?
    end)
  after
    Process.delete(:p810_provider)
  end

  test "repeated conclusive reconciliation with different event references is idempotent" do
    P805.with_fixture(fn ->
      {:ok, _} = Identity.register(P805.request())
      [intent] = Ash.read!(Communications.MessageIntent, authorize?: false)
      Process.put(:p810_provider, fn _, _ -> :unknown end)
      assert {:ok, :processed} = Communications.execute(intent.id)
      [attempt] = attempts()
      evidence(attempt, :confirmed_no_operation, "first")
      evidence(attempt, :confirmed_no_operation, "second")
      refute hd(attempts()).conflict?
      assert disposition(intent) == :open
    end)
  after
    Process.delete(:p810_provider)
  end

  test "late contradictory old-attempt evidence stops newer work and remains visible" do
    P805.with_fixture(fn ->
      {:ok, _} = Identity.register(P805.request())
      [intent] = Ash.read!(Communications.MessageIntent, authorize?: false)
      Process.put(:p810_provider, fn _, _ -> :unknown end)
      assert {:ok, :processed} = Communications.execute(intent.id)
      [older] = attempts()
      evidence(older, :confirmed_no_operation, "absence")
      Process.put(:p810_provider, fn _, _ -> :accepted end)
      assert {:ok, :processed} = Communications.execute(intent.id)
      newer = Enum.find(attempts(), &(&1.id != older.id))
      evidence(older, :delivered, "late-contradiction")
      assert Ash.get!(Communications.DeliveryAttempt, older.id, authorize?: false).conflict?
      assert disposition(intent) == :reconciliation_required
      evidence(newer, :delivered, "newer-delivery")
      assert disposition(intent) == :reconciliation_required
      assert {:ok, :waiting} = Communications.execute(intent.id)
      assert length(attempts()) == 2

      Repo.query!("UPDATE tokens SET expires_at = now() - interval '1 second' WHERE jti = $1", [
        intent.source_reference
      ])

      assert {:ok, :source_invalid} = Communications.execute(intent.id)

      assert Ash.get!(Communications.ProtectedEnvelope, intent.id,
               authorize?: false,
               not_found_error?: false
             ) == nil
    end)
  after
    Process.delete(:p810_provider)
  end

  test "safe provider rejections and failures allow guarded new identities with immutable provenance" do
    P805.with_fixture(fn ->
      {:ok, _} = Identity.register(P805.request())
      [intent] = Ash.read!(Communications.MessageIntent, authorize?: false)

      for outcome <- [:rejected_before_submission, :bounced_or_failed, :delivered] do
        Process.put(:p810_provider, fn _, _ -> outcome end)
        assert {:ok, :processed} = Communications.execute(intent.id)
      end

      rows = attempts()
      assert length(rows) == 3
      assert Enum.uniq_by(rows, & &1.id) == rows

      assert Enum.all?(
               rows,
               &(&1.render_digest == intent.render_digest and &1.locale == intent.locale)
             )

      assert disposition(intent) == :closed
    end)
  after
    Process.delete(:p810_provider)
  end

  test "expired revoked and superseded sources never admit stale provider calls" do
    P805.with_fixture(fn ->
      for mode <- [:expired, :revoked, :superseded] do
        request = P805.request()
        {:ok, registration} = Identity.register(request)

        [intent] =
          Enum.filter(
            Ash.read!(Communications.MessageIntent, authorize?: false),
            &(&1.source_operation_id == request.operation_id)
          )

        case mode do
          :expired ->
            Repo.query!(
              "UPDATE tokens SET expires_at = now() - interval '1 second' WHERE jti = $1",
              [intent.source_reference]
            )

          :revoked ->
            account = Ash.get!(Identity.Account, registration.account_id, authorize?: false)

            :ok =
              AshAuthentication.TokenResource.Actions.revoke_jti(
                Identity.Token,
                intent.source_reference,
                AshAuthentication.user_to_subject(account),
                authorize?: false,
                context: %{ash_authentication: %{user: account}}
              )

          :superseded ->
            operation = Ash.UUID.generate()
            P805.track_operation(operation)

            assert {:ok, _} =
                     Identity.resend_verification(%{
                       operation_id: operation,
                       account_id: registration.account_id
                     })
        end

        Process.put(:p810_provider, fn _, _ -> flunk("invalid source submitted") end)
        assert {:ok, :source_invalid} = Communications.execute(intent.id)
        assert Enum.all?(attempts(), &(&1.message_intent_id != intent.id))

        assert Ash.get!(Communications.ProtectedEnvelope, intent.id,
                 authorize?: false,
                 not_found_error?: false
               ) == nil
      end
    end)
  after
    Process.delete(:p810_provider)
  end

  test "purpose, content, locale and render provenance mismatches fail closed before admission" do
    P805.with_fixture(fn ->
      {:ok, _} = Identity.register(P805.request())
      [intent] = Ash.read!(Communications.MessageIntent, authorize?: false)
      Process.put(:p810_provider, fn _, _ -> flunk("invalid binding submitted") end)

      for {column, value} <- [
            {"content_sha256", String.duplicate("0", 64)},
            {"render_digest", String.duplicate("0", 64)},
            {"translation_version_id", "withdrawn-or-unknown"},
            {"source_purpose", "password_reset"}
          ] do
        original = Map.fetch!(intent, String.to_existing_atom(column))

        Repo.query!("UPDATE message_intents SET #{column} = $1 WHERE id = $2", [
          value,
          Ecto.UUID.dump!(intent.id)
        ])

        assert {:ok, :held} = Communications.execute(intent.id)
        assert [] == attempts()

        Repo.query!("UPDATE message_intents SET #{column} = $1 WHERE id = $2", [
          original,
          Ecto.UUID.dump!(intent.id)
        ])
      end
    end)
  after
    Process.delete(:p810_provider)
  end

  test "ordinary callers cannot read capabilities or mutate attempts or invoke the worker action" do
    P805.with_fixture(fn ->
      {:ok, _} = Identity.register(P805.request())
      [intent] = Ash.read!(Communications.MessageIntent, authorize?: false)
      Process.put(:p810_provider, fn _, _ -> :accepted end)
      assert {:ok, :processed} = Communications.execute(intent.id)
      [attempt] = attempts()
      assert {:ok, []} = Ash.read(Communications.DeliveryAttempt, authorize?: true)
      assert {:ok, []} = Ash.read(Communications.ProtectedEnvelope, authorize?: true)

      assert {:error, _} =
               Ash.update(attempt, %{provider_observation: :delivered},
                 action: :record,
                 authorize?: true
               )

      assert {:error, _} =
               Communications.MessageIntent
               |> Ash.ActionInput.for_action(:execute_delivery, %{primary_key: %{id: intent.id}},
                 authorize?: true
               )
               |> Ash.run_action()
    end)
  after
    Process.delete(:p810_provider)
  end

  test "provider exceptions and accidental payload inspection do not expose secrets" do
    P805.with_fixture(fn ->
      {:ok, registration} = Identity.register(P805.request())
      [intent] = Ash.read!(Communications.MessageIntent, authorize?: false)

      Process.put(:p810_provider, fn _, payload ->
        Process.put(:p810_payload_inspection, inspect(payload))
        raise payload.body
      end)

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          assert {:ok, :processed} = Communications.execute(intent.id)
        end)

      refute String.contains?(
               Process.delete(:p810_payload_inspection),
               registration.verification_proof
             )

      refute String.contains?(log, registration.verification_proof)
      refute String.contains?(log, intent.destination)
      assert hd(attempts()).provider_observation == :unknown
      refute String.contains?(inspect(attempts()), registration.verification_proof)
    end)
  after
    Process.delete(:p810_provider)
  end

  test "PostgreSQL refuses a second unresolved admission even without executor serialization" do
    P805.with_fixture(fn ->
      {:ok, _} = Identity.register(P805.request())
      [intent] = Ash.read!(Communications.MessageIntent, authorize?: false)
      Process.put(:p810_provider, fn _, _ -> :accepted end)
      assert {:ok, :processed} = Communications.execute(intent.id)
      [attempt] = attempts()

      attributes =
        Map.take(attempt, [
          :message_intent_id,
          :locale,
          :content_item_id,
          :content_version_id,
          :translation_version_id,
          :content_sha256,
          :render_schema,
          :render_provenance,
          :render_digest
        ])

      assert {:error, _} =
               Ash.create(Communications.DeliveryAttempt, attributes,
                 action: :admit,
                 authorize?: false
               )

      assert [attempt] == attempts()
    end)
  after
    Process.delete(:p810_provider)
  end

  test "delivery telemetry and ordinary persistence exclude the protected bearer and body" do
    P805.with_fixture(fn ->
      {:ok, registration} = Identity.register(P805.request())
      [intent] = Ash.read!(Communications.MessageIntent, authorize?: false)
      handler = "p810-privacy-" <> Ash.UUID.generate()

      events =
        for action <- [:read, :create, :update, :destroy, :action],
            phase <- [:start, :stop, :exception],
            do: [:ash, :communications, action, phase]

      :ok = :telemetry.attach_many(handler, events, &__MODULE__.capture_event/4, self())

      try do
        Process.put(:p810_provider, fn _, payload ->
          Process.put(:p810_rendered, payload.body)
          :accepted
        end)

        assert {:ok, :processed} = Communications.execute(intent.id)
        observations = telemetry_events([])
        assert observations != []

        %{rows: rows} =
          Repo.query!(
            "SELECT row_to_json(i)::text FROM message_intents i WHERE id = $1 UNION ALL SELECT row_to_json(a)::text FROM delivery_attempts a WHERE message_intent_id = $1",
            [Ecto.UUID.dump!(intent.id)]
          )

        data = inspect({observations, rows, Repo.all(Oban.Job)})
        refute String.contains?(data, registration.verification_proof)
        refute String.contains?(data, Process.delete(:p810_rendered))
      after
        :telemetry.detach(handler)
      end
    end)
  after
    Process.delete(:p810_provider)
  end

  def capture_event(event, measurements, metadata, receiver),
    do: send(receiver, {:delivery_telemetry, inspect({event, measurements, metadata})})

  defp telemetry_events(acc) do
    receive do
      {:delivery_telemetry, event} -> telemetry_events([event | acc])
    after
      0 -> acc
    end
  end

  defp evidence(attempt, outcome, reference) do
    key = Application.fetch_env!(:new_you, :communications_proof_evidence_key)

    signature =
      :crypto.mac(
        :hmac,
        :sha256,
        key,
        attempt.id <> "|" <> to_string(outcome) <> "|" <> reference
      )

    assert {:ok, :recorded} = Communications.reconcile(attempt.id, outcome, reference, signature)
  end

  defp attempts, do: Ash.read!(Communications.DeliveryAttempt, authorize?: false)

  defp disposition(intent),
    do: Ash.get!(Communications.MessageIntent, intent.id, authorize?: false).dispatch_disposition
end
