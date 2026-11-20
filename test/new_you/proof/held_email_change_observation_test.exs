defmodule NewYou.Proof.HeldEmailChangeObservationTest do
  use ExUnit.Case, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias NewYou.{Communications, Identity, Repo}
  alias NewYou.Communications.DeliveryAttempt
  alias NewYou.Proof.{EmailChangeScenarios, P805}

  require Ash.Query

  @attempt_binding ~w(message_intent_id locale content_item_id content_version_id translation_version_id content_sha256 render_schema render_provenance render_digest)a

  test "the held email-change scenario passes with an independent delivery attempt" do
    with_foreign_attempt(fn attempt ->
      at_fixture_checkout(fn ->
        task = Task.async(fn -> Sandbox.unboxed_run(Repo, fn -> admit(attempt) end) end)
        %DeliveryAttempt{} = Task.await(task)
      end)

      assert held_email_change()
      assert_foreign_attempt_unchanged(attempt, 2)
    end)
  end

  test "the held email-change assertion detects a local attempt under the foreign parent" do
    with_foreign_attempt(fn attempt ->
      previous_keyring = Application.fetch_env(:new_you, :communications_keyring)
      reference = make_ref()

      at_fixture_checkout(fn ->
        created = admit(attempt)
        send(self(), {reference, created.id})
      end)

      assert_raise ExUnit.AssertionError, ~r/held email change created a delivery attempt/, fn ->
        held_email_change()
      end

      assert_received {^reference, inserted_id}
      refute inserted_id == attempt.id
      assert Enum.any?(assert_foreign_attempt_unchanged(attempt, 2), &(&1.id == inserted_id))
      restored? = Application.fetch_env(:new_you, :communications_keyring) == previous_keyring
      assert restored?, "fixture did not restore the Communications keyring"
      refute Process.get(:p810_provider)
    end)
  end

  test "an owned insert without a returned UUID fails the observation" do
    with_foreign_attempt(fn attempt ->
      at_fixture_checkout(fn ->
        assert %Ash.BulkResult{status: :success} =
                 Ash.bulk_create!([Map.take(attempt, @attempt_binding)], DeliveryAttempt, :admit,
                   authorize?: false,
                   return_records?: false
                 )
      end)

      assert_raise RuntimeError, "fixture DeliveryAttempt INSERT did not return its UUID", fn ->
        held_email_change()
      end

      assert_foreign_attempt_unchanged(attempt, 2)
    end)
  end

  defp at_fixture_checkout(callback) do
    Process.put({P805, :setup_checkpoint}, fn
      :sandbox_checked_out -> callback.()
      _ -> :ok
    end)
  end

  defp admit(attempt) do
    Ash.create!(DeliveryAttempt, Map.take(attempt, @attempt_binding),
      action: :admit,
      authorize?: false
    )
  end

  defp held_email_change do
    EmailChangeScenarios.scenario_development_only_email_change_intents_remain_held_and_never_reach_a_provider()
  end

  defp with_foreign_attempt(callback) do
    operation_id = Ecto.UUID.generate()
    email = "proof-#{operation_id}@example.test"

    try do
      attempt =
        P805.with_fixture(fn ->
          # Register B outside the fixture's cleanup identities. A separate
          # fixture claims these exact synthetic identities in the after block.
          request = %{P805.request() | operation_id: operation_id, email: email}
          assert {:ok, _} = Identity.register(request)
          [intent] = P805.intents(operation_id)

          Process.put(:p810_provider, fn _, _ -> :rejected_before_submission end)

          try do
            assert {:ok, :processed} = Communications.execute(intent.id)
            [attempt] = attempts(intent.id)
            assert attempt.provider_observation == :rejected_before_submission
            refute attempt.active
            attempt
          after
            Process.delete(:p810_provider)
          end
        end)

      assert_foreign_attempt_unchanged(attempt, 1)
      callback.(attempt)
    after
      P805.with_fixture(fn -> P805.request(%{operation_id: operation_id, email: email}) end)
    end
  end

  defp assert_foreign_attempt_unchanged(attempt, count) do
    assert P805.fixture_status() == :available

    Sandbox.unboxed_run(Repo, fn ->
      saved = attempts(attempt.message_intent_id)
      assert length(saved) == count
      assert Enum.find(saved, &(&1.id == attempt.id)) == attempt
      saved
    end)
  end

  defp attempts(intent_id) do
    DeliveryAttempt
    |> Ash.Query.filter(message_intent_id == ^intent_id)
    |> Ash.read!(authorize?: false)
  end
end
