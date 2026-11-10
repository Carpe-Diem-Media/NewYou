defmodule NewYou.Identity.PasswordResetRequestTest do
  use ExUnit.Case, async: false
  require Ash.Query
  alias NewYou.Identity
  alias NewYou.Identity.Token
  alias NewYou.Proof.{P805, RegistrationSeam, Scenario}
  alias Ecto.Adapters.SQL.Sandbox

  test "eligible unknown and restricted requests return one neutral padded response" do
    P805.with_fixture(fn ->
      request = P805.request()
      {:ok, result} = Identity.register(request)
      {:ok, :verified} = Identity.verify_email(result.verification_proof)

      samples =
        for email <- [request.email, "unknown@example.test", nil, "invalid"] do
          started = System.monotonic_time(:millisecond)
          assert Identity.request_password_reset(email, "af", operation()) == :ok
          System.monotonic_time(:millisecond) - started
        end

      assert Enum.min(samples) >= 490
      assert Enum.max(samples) - Enum.min(samples) < 200

      NewYou.Repo.query!("UPDATE accounts SET security_posture='held' WHERE id=$1", [
        Ecto.UUID.dump!(result.account_id)
      ])

      started = System.monotonic_time(:millisecond)
      assert Identity.request_password_reset(request.email, "af", operation()) == :ok
      assert System.monotonic_time(:millisecond) - started >= 490

      assert length(
               Token
               |> Ash.Query.filter(
                 account_id == ^result.account_id and purpose == "password_reset"
               )
               |> Ash.read!(authorize?: false)
             ) == 1
    end)
  end

  test "request cancellation rolls back proof and delivery together and the same request can retry" do
    P805.with_fixture(fn ->
      request = P805.request()
      {:ok, result} = Identity.register(request)
      {:ok, :verified} = Identity.verify_email(result.verification_proof)
      operation = operation()
      parent = self()
      reference = make_ref()
      scenario = Scenario.start()

      try do
        {requester, monitor} =
          Scenario.spawn(scenario, :reset_request, fn ->
            :ok = Sandbox.checkout(NewYou.Repo, sandbox: false)
            Process.put(RegistrationSeam, {:pause, parent, reference})

            try do
              send(
                parent,
                {reference, :result,
                 Identity.request_password_reset(request.email, "af", operation)}
              )
            after
              Sandbox.checkin(NewYou.Repo)
            end
          end)

        assert_receive {^reference, :before_commit, worker, _, _}, 1500
        worker_monitor = Process.monitor(worker)
        assert_receive {^reference, :result, :ok}, 1500
        assert_receive {:DOWN, ^worker_monitor, :process, ^worker, :killed}, 1500
        assert_receive {:DOWN, ^monitor, :process, ^requester, :normal}, 1500
        assert proof_count(operation) == 0
        assert intent_count(operation) == 0
        assert Identity.request_password_reset(request.email, "af", operation) == :ok
        assert proof_count(operation) == 1
        assert intent_count(operation) == 1
      after
        Scenario.stop(scenario)
      end
    end)
  end

  defp operation do
    id = Ecto.UUID.generate()
    P805.track_operation(id)
    id
  end

  defp proof_count(id),
    do:
      P805.scalar("SELECT count(*) FROM tokens WHERE reset_request_id=$1", [Ecto.UUID.dump!(id)])

  defp intent_count(id),
    do:
      P805.scalar("SELECT count(*) FROM message_intents WHERE source_operation_id=$1", [
        Ecto.UUID.dump!(id)
      ])
end
