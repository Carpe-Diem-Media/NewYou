defmodule NewYou.Proof.P807 do
  @moduledoc """
  Bounded P8-07 cases using the existing scenario, concurrency and registration
  fixture machinery. No second runner or substitute business transition.
  """
  alias Ecto.Adapters.SQL.Sandbox
  alias NewYou.{Identity, Repo}
  alias NewYou.Proof.{Concurrent, CutPoints, P805, RegistrationSeam, Scenario}

  def run(id) do
    P805.with_fixture(fn ->
      {:ok, registration} = Identity.register(P805.request())
      before = P805.counts()
      execute(id, registration)
      check(id, "no_session_or_new_rows", P805.counts() == before)
      :ok
    end)
  end

  defp execute("p807.consume_race" = id, registration) do
    parent = self()
    reference = make_ref()
    scenario = Scenario.start()

    try do
      {_coordinator, monitor} =
        Scenario.spawn(scenario, :coordinator, fn ->
          nested = Scenario.start()

          result =
            Concurrent.run(
              nested,
              %{
                first: fn ->
                  Process.put(RegistrationSeam, {:pause, parent, reference})
                  Identity.verify_email(registration.verification_proof)
                end,
                second: fn ->
                  send(
                    parent,
                    {reference, :second, self(), P805.scalar("SELECT pg_backend_pid()")}
                  )

                  receive do
                    {^reference, :contend} ->
                      Identity.verify_email(registration.verification_proof)
                  after
                    15_000 -> raise "P8-07 contender deadline"
                  end
                end
              },
              timeout: 30_000
            )

          :ok = Scenario.stop(nested)
          send(parent, {reference, :results, result})
        end)

      {first, backend_a, _transaction_a} = await_checkpoint(reference)

      {second, backend_b} =
        receive do
          {^reference, :second, pid, backend} -> {pid, backend}
        after
          15_000 -> raise "P8-07 second connection deadline"
        end

      send(second, {reference, :contend})

      {transaction_a, transaction_b} =
        contention(backend_a, backend_b, System.monotonic_time(:millisecond) + 15_000)

      check(id, "independent_connections", backend_a != backend_b)
      check(id, "real_contention", is_binary(transaction_b) and transaction_a != transaction_b)
      send(first, {reference, :release})

      outcomes =
        receive do
          {^reference, :results, {:ok, result}} ->
            Enum.map(Map.values(result.outcomes), & &1.outcome)
        after
          30_000 -> raise "P8-07 result deadline"
        end

      receive do
        {:DOWN, ^monitor, :process, _, :normal} -> :ok
      after
        5_000 -> raise "P8-07 coordinator cleanup deadline"
      end

      check(
        id,
        "one_winner",
        Enum.count(outcomes, &(&1 == [:ok, :verified])) == 1 and
          Enum.count(outcomes, &(&1 == [:error, :verification_unavailable])) == 1
      )

      check(id, "committed_verified", account(registration).email_verified?)
      fresh_replay(id, registration, backend_a)
    after
      :ok = Scenario.stop(scenario)
    end
  end

  defp execute("p807.interrupted_consume" = id, registration) do
    parent = self()
    reference = make_ref()
    scenario = Scenario.start()

    try do
      :ok = CutPoints.arm(scenario, "transaction.before_commit", :verification, :terminate)

      {worker, monitor} =
        Scenario.spawn(scenario, :verification, fn ->
          :ok = Sandbox.checkout(Repo, sandbox: false)

          Process.put(
            RegistrationSeam,
            {:observe,
             fn ->
               backend = P805.scalar("SELECT pg_backend_pid()")
               send(parent, {reference, :cut, backend})
               CutPoints.hit(scenario, "transaction.before_commit", :verification)
             end}
          )

          try do
            Identity.verify_email(registration.verification_proof)
          after
            Sandbox.checkin(Repo)
          end
        end)

      old_backend =
        receive do
          {^reference, :cut, backend} -> backend
        after
          15_000 -> raise "P8-07 cut deadline"
        end

      receive do
        {:DOWN, ^monitor, :process, ^worker, :proof_terminated} -> :ok
      after
        15_000 -> raise "P8-07 termination deadline"
      end

      check(id, "cut_consumed", CutPoints.verify_consumed(scenario) == :ok)

      check(
        id,
        "atomic_rollback",
        not account(registration).email_verified? and
          match?(
            {:ok, _, _},
            AshAuthentication.Jwt.verify(registration.verification_proof, Identity.Account)
          )
      )

      fresh_consume(id, registration, old_backend)
    after
      :ok = Scenario.stop(scenario)
    end
  end

  defp execute(id, registration) when id in ["p807.browser_en", "p807.browser_af"] do
    locale = if id == "p807.browser_en", do: "en", else: "af"
    previous = Application.get_env(:new_you, :p8_07_browser_development_fixtures)
    Application.put_env(:new_you, :p8_07_browser_development_fixtures, "p8-07-temporary-v1")

    try do
      result = NewYou.Proof.P805Browser.run_verification(registration, locale)

      for name <- ~w(temporary_copy explicit_form verified_result safe_replay no_session) do
        check(id, name, result[name] == true)
      end

      check(id, "durable_verified", account(registration).email_verified?)
    after
      if previous,
        do: Application.put_env(:new_you, :p8_07_browser_development_fixtures, previous),
        else: Application.delete_env(:new_you, :p8_07_browser_development_fixtures)
    end
  end

  defp fresh_consume(id, registration, old_backend) do
    parent = self()
    reference = make_ref()
    scenario = Scenario.start()

    try do
      {_reader, monitor} =
        Scenario.spawn(scenario, :recovery, fn ->
          Sandbox.unboxed_run(Repo, fn ->
            backend = P805.scalar("SELECT pg_backend_pid()")
            result = Identity.verify_email(registration.verification_proof)
            replay = Identity.verify_email(registration.verification_proof)

            send(
              parent,
              {reference, :recovery, backend, result == {:ok, :verified},
               replay == {:error, :verification_unavailable}}
            )
          end)
        end)

      receive do
        {^reference, :recovery, backend, true, true} ->
          check(id, "fresh_recovery", backend != old_backend)
      after
        15_000 -> raise "P8-07 recovery deadline"
      end

      receive do
        {:DOWN, ^monitor, :process, _, :normal} -> :ok
      after
        5_000 -> raise "P8-07 recovery cleanup deadline"
      end
    after
      :ok = Scenario.stop(scenario)
    end
  end

  defp fresh_replay(id, registration, old_backend) do
    result =
      Task.async(fn ->
        Sandbox.unboxed_run(Repo, fn ->
          {P805.scalar("SELECT pg_backend_pid()"),
           Identity.verify_email(registration.verification_proof),
           account(registration).email_verified?}
        end)
      end)
      |> Task.await(15_000)

    {backend, replay, verified} = result

    check(
      id,
      "fresh_replay",
      backend != old_backend and verified and replay == {:error, :verification_unavailable}
    )
  end

  defp await_checkpoint(reference) do
    receive do
      {^reference, :before_commit, worker, backend, transaction} -> {worker, backend, transaction}
    after
      15_000 -> raise "P8-07 first transaction deadline"
    end
  end

  defp contention(first, second, deadline) do
    case Repo.query!(
           "SELECT a.virtualtransaction, b.virtualtransaction FROM pg_locks a JOIN pg_locks b ON b.pid = $1 AND b.locktype = 'virtualxid' WHERE a.pid = $2 AND a.locktype = 'virtualxid' AND $2 = ANY(pg_blocking_pids($1))",
           [second, first]
         ).rows do
      [[first_transaction, second_transaction]] ->
        {first_transaction, second_transaction}

      _ ->
        if System.monotonic_time(:millisecond) < deadline,
          do: contention(first, second, deadline),
          else: raise("P8-07 actual contention absent")
    end
  end

  defp account(registration),
    do: Ash.get!(Identity.Account, registration.account_id, authorize?: false)

  defp check(id, key, value), do: P805.check(id, key, value)
end
