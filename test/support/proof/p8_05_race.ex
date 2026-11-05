defmodule NewYou.Proof.P805Race do
  @moduledoc false
  alias NewYou.{Identity, Repo}
  alias NewYou.Proof.{Concurrent, P805, P805PublicResponse, RegistrationSeam, Scenario}

  def run(id) do
    {input, duplicate} = setup_inputs(id)
    before = P805.counts()
    parent = self()
    reference = make_ref()
    scenario = Scenario.start()

    try do
      {coordinator, monitor} =
        Scenario.spawn(scenario, :coordinator, fn ->
          nested = Scenario.start()

          result =
            Concurrent.run(
              nested,
              %{
                first: fn -> worker(parent, reference, :first, input, id) end,
                second: fn -> worker(parent, reference, :second, duplicate, id) end
              },
              timeout: 30_000
            )

          :ok = Scenario.stop(nested)
          send(parent, {reference, :outcomes, result})
        end)

      {first, backend_a, transaction_a} = await_first(reference)
      {second, backend_b} = await_second(reference)
      P805.check(id, "independent_connections", backend_a != backend_b)
      send(second, {reference, :contend})

      transaction_b =
        await_contention(backend_a, backend_b, System.monotonic_time(:millisecond) + 15_000)

      P805.check(
        id,
        "independent_transactions",
        transaction_a != transaction_b
      )

      P805.check(id, "contention", is_binary(transaction_b))
      send(first, {reference, :release})

      outcomes =
        receive do
          {^reference, :outcomes, {:ok, results}} -> results
        after
          30_000 -> raise "proof race completion deadline"
        end

      receive do
        {:DOWN, ^monitor, :process, ^coordinator, :normal} -> :ok
      after
        5_000 -> raise "proof race coordinator cleanup deadline"
      end

      assert_outcomes(id, input, duplicate, before, outcomes, reference)
    after
      :ok = Scenario.stop(scenario)
    end
  end

  defp setup_inputs(id) do
    input = P805.request()
    configure_pmr(id)
    {input, duplicate_input(id, input)}
  end

  defp configure_pmr("p805.pmr_collision_race") do
    {:ok, collision} = Identity.PMR.generate()

    Application.put_env(:new_you, :identity_pmr_generator, fn ->
      calls = Process.get({__MODULE__, :pmr_candidates}, 0)
      Process.put({__MODULE__, :pmr_candidates}, calls + 1)
      if calls == 0, do: {:ok, collision}, else: Identity.PMR.generate()
    end)
  end

  defp configure_pmr(_), do: :ok
  defp duplicate_input("p805.same_operation_race", input), do: input
  defp duplicate_input("p805.pmr_collision_race", _input), do: P805.request()

  defp duplicate_input("p805.canonical_email_race", input) do
    [local, domain] = String.split(input.email, "@")
    P805.request(%{email: " \t" <> local <> "@" <> String.upcase(domain) <> "\t "})
  end

  defp duplicate_input(_, input), do: P805.request(%{email: input.email})

  defp assert_outcomes(id, input, duplicate, before, outcomes, reference) do
    same_operation = id == "p805.same_operation_race"
    pmr_race = id == "p805.pmr_collision_race"
    results = Enum.map(Map.values(outcomes.outcomes), &Enum.take(&1.outcome, 2))

    P805.check(
      id,
      "one_account",
      Enum.count(results, &(&1 == [:verification_pending, :created])),
      if(same_operation or pmr_race, do: 2, else: 1)
    )

    P805.check(
      id,
      "neutral_results",
      Enum.all?(
        results,
        &(&1 in [[:verification_pending, :created], [:verification_pending, :neutral]])
      )
    )

    expected_counts =
      if pmr_race,
        do: [2, 2, 2, 0, 2, 2, 2, 2, 2, 2],
        else: [1, 1, if(same_operation, do: 1, else: 2), 0, 1, 1, 1, 1, 1, 1]

    P805.check(
      id,
      "no_duplicate_consequences",
      P805.delta(before, P805.counts()),
      expected_counts
    )

    assert_owner(id, input, duplicate, pmr_race)
    assert_special(id, input, outcomes, reference)
  end

  defp assert_owner(id, input, duplicate, pmr_race) do
    operations =
      P805.read(Identity.RegistrationOperation, Identity)
      |> Enum.filter(
        &(&1.operation_id in [input.operation_id, duplicate.operation_id] and
            is_binary(&1.created_account_id))
      )

    accounts = Enum.map(operations, &P805.account!(&1.created_account_id))

    P805.check(
      id,
      "fresh_owner_read",
      length(accounts) == if(pmr_race, do: 2, else: 1) and
        Enum.all?(accounts, &(Identity.PMR.valid?(&1.pmr) and &1.credential_status == :active)) and
        length(Enum.uniq(Enum.map(accounts, & &1.pmr))) == length(accounts) and
        [input.operation_id, duplicate.operation_id]
        |> Enum.uniq()
        |> Enum.flat_map(&P805.intents/1)
        |> length() == if(pmr_race, do: 2, else: 1)
    )
  end

  defp assert_special(id, input, outcomes, reference) do
    pmr_race = id == "p805.pmr_collision_race"
    same_operation = id == "p805.same_operation_race"

    if pmr_race do
      P805.check(
        id,
        "collision_retried",
        Enum.any?(
          Map.values(outcomes.outcomes),
          &(&1.outcome == [:verification_pending, :created, true])
        )
      )
    end

    if id == "p805.canonical_email_race" do
      projections =
        for _ <- 1..2 do
          receive do
            {^reference, :public_response, projection} -> projection
          after
            5_000 -> raise "public response deadline"
          end
        end

      P805.check(id, "public_response", match?([{:ok, first}, {:ok, first}], projections))
    end

    if same_operation do
      returned_ids =
        for _ <- 1..2 do
          receive do
            {^reference, :returned_account, account_id} -> account_id
          after
            5_000 -> raise "registration result deadline"
          end
        end

      [operation] =
        P805.read(Identity.RegistrationOperation, Identity)
        |> Enum.filter(&(&1.operation_id == input.operation_id))

      P805.check(
        id,
        "same_account_result",
        Enum.all?(returned_ids, &(&1 == operation.created_account_id))
      )

      before_changed = P805.counts()
      changed = Identity.register(%{input | surname: "Changed"})
      P805.check(id, "changed_input_rejected", match?({:error, _}, changed))
      P805.check(id, "changed_input_no_writes", P805.counts(), before_changed)
    end
  end

  defp worker(parent, reference, label, input, id) do
    if label == :first do
      Process.put(RegistrationSeam, {:pause, parent, reference})
    else
      backend = P805.scalar("SELECT pg_backend_pid()")
      send(parent, {reference, :second_ready, self(), backend})

      receive do
        {^reference, :contend} -> :ok
      after
        20_000 -> raise "proof race start deadline"
      end
    end

    if id == "p805.canonical_email_race" do
      browser_registration(input, parent, reference)
    else
      register(input, parent, reference, id)
    end
  after
    Process.delete(RegistrationSeam)
  end

  defp register(input, parent, reference, id) do
    case Identity.register(input) do
      {:ok, result} ->
        if id == "p805.same_operation_race",
          do: send(parent, {reference, :returned_account, result.account_id})

        outcome = if is_binary(result.account_id), do: :created, else: :neutral

        if Process.get({__MODULE__, :pmr_candidates}) do
          {result.status, outcome, Process.get({__MODULE__, :pmr_candidates}) > 1}
        else
          {result.status, outcome}
        end

      {:error, _} ->
        :rejected
    end
  end

  defp browser_registration(input, parent, reference) do
    params = %{
      "registration" => %{
        "operation_id" => input.operation_id,
        "first_name" => input.first_name,
        "surname" => input.surname,
        "email" => input.email,
        "password" => input.password,
        "preferred_language" => Atom.to_string(input.preferred_language),
        "confirmed_age_18" => "true",
        "terms_accepted" => "true",
        "privacy_accepted" => "true"
      }
    }

    response =
      Phoenix.ConnTest.dispatch(
        Phoenix.ConnTest.build_conn(),
        NewYouWeb.Endpoint,
        :post,
        "/register",
        params
      )

    operation =
      P805.read(Identity.RegistrationOperation, Identity)
      |> Enum.find(&(&1.operation_id == input.operation_id))

    projection =
      P805PublicResponse.project(
        response.status,
        response.resp_body,
        input.email,
        Atom.to_string(input.preferred_language)
      )

    send(parent, {reference, :public_response, projection})

    category =
      case projection do
        {:ok, %{category: category}} -> category
        _ -> :unexpected
      end

    {category, if(is_binary(operation.created_account_id), do: :created, else: :neutral)}
  end

  defp await_first(reference) do
    receive do
      {^reference, :before_commit, worker, backend, transaction} -> {worker, backend, transaction}
    after
      20_000 -> raise "proof first transaction deadline"
    end
  end

  defp await_second(reference) do
    receive do
      {^reference, :second_ready, worker, backend} -> {worker, backend}
    after
      5_000 -> raise "proof second connection deadline"
    end
  end

  defp await_contention(first, second, deadline) do
    # Query actual PostgreSQL lock state. There is no sleep, substitute lock,
    # or enclosing harness transaction around either owning registration action.
    %{rows: rows} =
      Repo.query!(
        "SELECT backend_xid::text FROM pg_stat_activity WHERE pid = $1 AND $2 = ANY(pg_blocking_pids(pid))",
        [second, first]
      )

    case rows do
      [[transaction]] when is_binary(transaction) ->
        transaction

      _ ->
        if System.monotonic_time(:millisecond) < deadline,
          do: await_contention(first, second, deadline),
          else: raise("proof actual contention not observed")
    end
  end
end
