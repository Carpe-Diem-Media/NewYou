defmodule NewYou.Communications.RecoveryDeliveryTest do
  use ExUnit.Case, async: false

  require Ash.Query
  alias NewYou.{Communications, Identity, Repo}
  alias NewYou.Communications.{DeliveryAttempt, MessageIntent}
  alias NewYou.Identity.{Account, RecoveryCase, Token}
  alias NewYou.Proof.{CutPoints, DeliverySeam, P805, Provider, Scenario}

  for locale <- ["en", "af"] do
    test "#{locale} recovery uses exact content and commits a distinct durable notice" do
      P805.with_fixture(fn ->
        {request, recovery, intent} = pending(unquote(locale))
        assert intent.content_item_id != nil
        assert intent.translation_version_id =~ String.upcase(unquote(locale)) <> "-V1"

        assert {:error, _} =
                 Ash.update(intent, %{platform_name: "replacement"},
                   action: :bind_recovery_content,
                   authorize?: false
                 )

        assert Ash.get!(MessageIntent, intent.id, authorize?: false) == intent
        deliver(intent)
        bearer = Process.delete({__MODULE__, :bearer})
        assert is_binary(bearer)
        assert Ash.get!(Token, intent.source_reference, authorize?: false).purpose == "recovery"
        assert Ash.get!(RecoveryCase, recovery.id, authorize?: false) == recovery
        assert {:ok, :accepted} = Identity.submit_recovery_proof(bearer, operation())
        completion = operation()

        assert {:ok, :completed} =
                 Identity.complete_recovery(bearer, "a new guarded recovery password", completion)

        assert {:ok, :already_completed} =
                 Identity.complete_recovery(bearer, "a new guarded recovery password", completion)

        notice = intent(completion, :recovery_security_notice)
        assert notice.id != intent.id
        assert notice.source_reference == intent.source_reference
        deliver(notice)

        assert Ash.get!(Account, recovery.account_id, authorize?: false).security_posture ==
                 :normal

        assert Ash.get!(RecoveryCase, recovery.id, authorize?: false).state == :completed
        assert length(attempts(notice)) == 1
        assert {:ok, :closed} = Communications.execute(notice.id)
        assert length(attempts(notice)) == 1
        assert request.email == notice.destination
      end)
    after
      Process.delete(:p810_provider)
      Process.delete({__MODULE__, :bearer})
    end
  end

  for outcome <- [:accepted, :unknown, :rejected_before_submission] do
    test "provider #{outcome} neither consumes proof nor establishes recovery success" do
      P805.with_fixture(fn ->
        {_request, recovery, intent} = pending("en")
        Process.put(:p810_provider, fn _, _ -> unquote(outcome) end)
        assert {:ok, :processed} = Communications.execute(intent.id)
        assert Ash.get!(RecoveryCase, recovery.id, authorize?: false) == recovery
        assert Ash.get!(Token, intent.source_reference, authorize?: false).purpose == "recovery"
        assert length(attempts(intent)) == 1

        if unquote(outcome) in [:accepted, :unknown] do
          Process.put(:p810_provider, fn _, _ -> flunk("ambiguous submission must not repeat") end)

          assert {:ok, :waiting} = Communications.execute(intent.id)
          assert length(attempts(intent)) == 1
        end
      end)
    after
      Process.delete(:p810_provider)
    end
  end

  test "content withdrawal between admission and invocation prevents submission" do
    P805.with_fixture(fn ->
      {_request, _recovery, intent} = pending("en")
      root = Path.join(System.tmp_dir!(), "queued-recovery-#{Ecto.UUID.generate()}")
      File.mkdir_p!(root)
      File.cp_r!(Path.expand("../../../docs", __DIR__), Path.join(root, "docs"))
      Process.put({NewYou.Content.RecoveryMessage, :evidence_root}, root)
      Process.put(:p810_provider, fn _, _ -> flunk("withdrawn content cannot reach provider") end)

      Process.put(DeliverySeam, fn
        :after_admission ->
          File.rm!(
            Path.join(
              root,
              "docs/delivery/content-evidence/content_media/recovery_messages/RECOVERY_MESSAGE_DEVELOPMENT_EVIDENCE_PACKET_v0.2.0.json"
            )
          )

        _ ->
          :ok
      end)

      try do
        assert {:ok, :held} = Communications.execute(intent.id)
        assert [attempt] = attempts(intent)
        assert attempt.admission == :closed_before_invocation
        assert attempt.invocation_started_at == nil
      after
        File.rm_rf!(root)
      end
    end)
  after
    Process.delete(:p810_provider)
    Process.delete(DeliverySeam)
    Process.delete({NewYou.Content.RecoveryMessage, :evidence_root})
  end

  test "restored content binds a held proof once without changing Identity authority" do
    P805.with_fixture(fn ->
      Process.put({NewYou.Content.RecoveryMessage, :evidence_root}, "/missing-recovery-content")
      {_request, recovery, intent} = pending("af")
      assert intent.content_item_id == nil
      Process.put(:p810_provider, fn _, _ -> flunk("unbound proof cannot send") end)
      assert {:ok, :held} = Communications.execute(intent.id)
      assert attempts(intent) == []
      Process.delete({NewYou.Content.RecoveryMessage, :evidence_root})
      Process.put(:p810_provider, fn _, _ -> :delivered end)
      assert {:ok, :processed} = Communications.execute(intent.id)
      bound = Ash.get!(MessageIntent, intent.id, authorize?: false)
      assert bound.content_item_id != nil
      assert bound.translation_version_id =~ "AF-V1"
      assert bound.source_reference == intent.source_reference
      assert bound.source_operation_id == intent.source_operation_id
      assert Ash.get!(RecoveryCase, recovery.id, authorize?: false) == recovery
      assert Ash.get!(Token, recovery.proof_jti, authorize?: false).purpose == "recovery"
      assert length(attempts(intent)) == 1
      assert {:ok, :closed} = Communications.execute(intent.id)

      assert {:error, _} =
               Ash.update(bound, %{platform_name: "replacement"},
                 action: :bind_recovery_content,
                 authorize?: false
               )

      assert Ash.get!(MessageIntent, intent.id, authorize?: false) == bound
    end)
  after
    Process.delete(:p810_provider)
    Process.delete({NewYou.Content.RecoveryMessage, :evidence_root})
  end

  test "late content cannot revive revoked proof or bypass private binding policies" do
    P805.with_fixture(fn ->
      Process.put({NewYou.Content.RecoveryMessage, :evidence_root}, "/missing-recovery-content")
      {_request, recovery, intent} = pending("en")

      assert {:error, %Ash.Error.Forbidden{}} =
               Ash.update(intent, %{platform_name: "unauthorized"},
                 action: :bind_recovery_content
               )

      proof = Ash.get!(Token, recovery.proof_jti, authorize?: false)
      Ash.update!(proof, %{}, action: :revoke_recovery, authorize?: false)
      Process.delete({NewYou.Content.RecoveryMessage, :evidence_root})
      Process.put(:p810_provider, fn _, _ -> flunk("revoked proof cannot send") end)
      assert {:ok, :source_invalid} = Communications.execute(intent.id)
      assert attempts(intent) == []
      assert Ash.get!(MessageIntent, intent.id, authorize?: false).dispatch_disposition == :closed
      assert Ash.get!(RecoveryCase, recovery.id, authorize?: false) == recovery
      assert {:ok, :closed} = Communications.execute(intent.id)
    end)
  after
    Process.delete(:p810_provider)
    Process.delete({NewYou.Content.RecoveryMessage, :evidence_root})
  end

  test "unavailable content preserves the committed security notice obligation" do
    P805.with_fixture(fn ->
      {_request, _recovery, proof_intent} = pending("en")

      {:ok, {:ok, bearer}} =
        Ash.transact([Account, Token, RecoveryCase], fn ->
          Identity.recovery_delivery(
            proof_intent.source_reference,
            proof_intent.destination,
            proof_intent.locale
          )
        end)

      assert {:ok, :accepted} = Identity.submit_recovery_proof(bearer, operation())
      Process.put({NewYou.Content.RecoveryMessage, :evidence_root}, "/missing-recovery-content")
      completion = operation()

      assert {:ok, :completed} =
               Identity.complete_recovery(bearer, "another guarded recovery password", completion)

      notice = intent(completion, :recovery_security_notice)
      assert notice.dispatch_disposition == :held
      assert notice.content_item_id == nil
      Process.put(:p810_provider, fn _, _ -> flunk("unbound notice cannot send") end)
      assert {:ok, :held} = Communications.execute(notice.id)
      assert attempts(notice) == []

      # Restoring current eligibility must recover the durable obligation,
      # without re-executing Identity completion or requiring a new source event.
      Process.delete({NewYou.Content.RecoveryMessage, :evidence_root})

      Process.put(:p810_provider, fn _, payload ->
        assert String.contains?(payload.body, "jc@carpediem.co.za")
        refute String.contains?(payload.body, "proof=")
        :delivered
      end)

      assert {:ok, :processed} = Communications.execute(notice.id)
      assert length(attempts(notice)) == 1
      assert Ash.get!(MessageIntent, notice.id, authorize?: false).content_item_id != nil
      assert {:ok, :closed} = Communications.execute(notice.id)
      assert length(attempts(notice)) == 1
    end)
  after
    Process.delete(:p810_provider)
    Process.delete({NewYou.Content.RecoveryMessage, :evidence_root})
  end

  for {point, cut} <- [
        after_admission: :"transaction.after_commit",
        before_invoke: :"provider.before_invoke",
        after_invoke: :"provider.after_invoke_before_persist"
      ] do
    test "recovery provider crash at #{point} reconstructs admission without changing Identity" do
      P805.with_fixture(fn ->
        {_request, recovery, intent} = pending("en")
        scenario = Scenario.start()
        :ok = Provider.configure(scenario, %{"recovery-delivery" => [{:submit, :accepted}]})
        :ok = CutPoints.arm(scenario, unquote(cut), :executor, :terminate)

        {pid, monitor} =
          Scenario.spawn(scenario, :executor, fn ->
            Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
              Process.put(:p810_provider, fn _, _ ->
                {:ok, event} = Provider.next(scenario, "recovery-delivery", :submit)
                event.outcome
              end)

              Process.put(DeliverySeam, fn point ->
                if point == unquote(point), do: CutPoints.hit(scenario, unquote(cut), :executor)
              end)

              Communications.execute(intent.id)
            end)
          end)

        try do
          assert_receive {:DOWN, ^monitor, :process, ^pid, :proof_terminated}, 10_000
          assert :ok = CutPoints.verify_consumed(scenario)
          Process.put(:p810_provider, fn _, _ -> :delivered end)
          assert {:ok, :waiting} = Communications.execute(intent.id)
          assert [attempt] = attempts(intent)

          if unquote(point) == :after_admission do
            assert attempt.admission == :closed_before_invocation
            assert attempt.invocation_started_at == nil
            assert {:ok, :processed} = Communications.execute(intent.id)
            assert length(attempts(intent)) == 2
          else
            assert attempt.provider_observation == :unknown
            assert attempt.active

            Process.put(:p810_provider, fn _, _ ->
              flunk("unknown invocation must reconcile before retry")
            end)

            assert {:ok, :waiting} = Communications.execute(intent.id)
            assert length(attempts(intent)) == 1
          end

          assert Ash.get!(RecoveryCase, recovery.id, authorize?: false) == recovery
          assert Ash.get!(Token, recovery.proof_jti, authorize?: false).purpose == "recovery"
        after
          Scenario.stop(scenario)
        end
      end)
    after
      Process.delete(:p810_provider)
    end
  end

  test "competing PostgreSQL executors bind restored content once and fence one invocation" do
    P805.with_fixture(fn ->
      Process.put({NewYou.Content.RecoveryMessage, :evidence_root}, "/missing-recovery-content")
      {_request, recovery, intent} = pending("en")
      assert intent.content_item_id == nil
      Process.delete({NewYou.Content.RecoveryMessage, :evidence_root})
      parent = self()
      reference = make_ref()

      task =
        Task.async(fn ->
          Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
            Process.put(:p810_provider, fn _, _ ->
              send(parent, {reference, :provider_entered, self()})

              receive do
                {^reference, :continue} -> :delivered
              after
                10_000 -> :unknown
              end
            end)

            Communications.execute(intent.id)
          end)
        end)

      assert_receive {^reference, :provider_entered, provider}, 10_000
      Process.put(:p810_provider, fn _, _ -> flunk("duplicate provider invocation") end)
      assert {:ok, :waiting} = Communications.execute(intent.id)
      send(provider, {reference, :continue})
      assert {:ok, :processed} = Task.await(task, 10_000)
      assert Ash.get!(MessageIntent, intent.id, authorize?: false).content_item_id != nil
      assert length(attempts(intent)) == 1
      assert Ash.get!(RecoveryCase, recovery.id, authorize?: false) == recovery
      assert {:ok, :closed} = Communications.execute(intent.id)
    end)
  after
    Process.delete(:p810_provider)
  end

  defp pending(locale) do
    request = P805.request(%{preferred_language: String.to_existing_atom(locale)})
    {:ok, registration} = Identity.register(request)
    {:ok, :verified} = Identity.verify_email(registration.verification_proof)
    operation = operation()
    :ok = Identity.request_recovery(request.email, locale, operation)
    intent = intent(operation, :account_recovery)

    recovery =
      RecoveryCase
      |> Ash.Query.filter(operation_id == ^operation)
      |> Ash.read_one!(authorize?: false)

    {request, recovery, intent}
  end

  defp deliver(intent) do
    assert {:ok, _} = NewYou.Content.RecoveryMessage.eligible(intent)

    assert intent.render_digest ==
             Communications.recovery_render_digest(
               intent.render_schema,
               intent.platform_name,
               intent.support_contact
             )

    Process.put(:p810_provider, fn _attempt, payload ->
      refute Repo.in_transaction?()
      assert payload.destination == intent.destination

      if intent.role == :account_recovery do
        [_, encoded] =
          Regex.run(~r{/recovery/confirm\?locale=(?:en|af)&proof=([^\s]+)}, payload.body)

        Process.put({__MODULE__, :bearer}, URI.decode_www_form(encoded))
      else
        assert String.contains?(payload.body, "jc@carpediem.co.za")
        refute String.contains?(payload.body, "proof=")
      end

      refute inspect(payload) =~ "proof="
      :delivered
    end)

    assert {:ok, :processed} = Communications.execute(intent.id)
  end

  defp intent(operation, role),
    do:
      MessageIntent
      |> Ash.Query.filter(source_operation_id == ^operation and role == ^role)
      |> Ash.read_one!(authorize?: false)

  defp attempts(intent),
    do:
      DeliveryAttempt
      |> Ash.Query.filter(message_intent_id == ^intent.id)
      |> Ash.read!(authorize?: false)

  defp operation do
    id = Ecto.UUID.generate()
    P805.track_operation(id)
    id
  end
end
