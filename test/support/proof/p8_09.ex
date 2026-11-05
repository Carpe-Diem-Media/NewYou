defmodule NewYou.Proof.P809 do
  @moduledoc false
  alias Ecto.Adapters.SQL.Sandbox
  alias NewYou.{Identity, Repo}
  alias NewYou.Proof.{P805, Scenario, CutPoints, RegistrationSeam}

  def run(id) do
    P805.with_fixture(fn ->
      request = P805.request()
      {:ok, registration} = Identity.register(request)
      {:ok, :verified} = Identity.verify_email(registration.verification_proof)
      {:ok, credentials} = Identity.authenticate_password(request.email, request.password)
      execute(id, request, credentials)
      :ok
    end)
  end

  defp execute("p809.reconnect" = id, _request, credentials) do
    parent_backend = P805.scalar("SELECT pg_backend_pid()")
    {backend, result} = fresh(credentials)
    P805.check(id, "fresh_connection", backend != parent_backend and match?({:ok, _}, result))

    Repo.query!("UPDATE sessions SET state = 'revoked' WHERE id = $1", [
      Ecto.UUID.dump!(credentials.session_id)
    ])

    {_backend, denied} = fresh(credentials)

    P805.check(
      id,
      "active_denied_after_revoke",
      denied == {:error, :authentication_unavailable}
    )
  end

  defp execute("p809.beam_restart" = id, request, credentials) do
    P805.check(id, "first_boot", restart_process(credentials) == :allowed)
    P805.check(id, "second_boot", restart_process(credentials) == :allowed)
    {:ok, token_case} = Identity.authenticate_password(request.email, request.password)
    {:ok, hold_case} = Identity.authenticate_password(request.email, request.password)

    Repo.query!("UPDATE sessions SET state = 'revoked' WHERE id = $1", [
      Ecto.UUID.dump!(credentials.session_id)
    ])

    P805.check(id, "revoked_after_restart", restart_process(credentials) == :denied)
    {:ok, claims} = AshAuthentication.Jwt.peek(token_case.token)
    Repo.query!("UPDATE tokens SET purpose = 'revocation' WHERE jti = $1", [claims["jti"]])
    P805.check(id, "token_revoked_after_restart", restart_process(token_case) == :denied)
    Repo.query!("UPDATE accounts SET security_posture = 'held' WHERE email = $1", [request.email])
    P805.check(id, "held_after_restart", restart_process(hold_case) == :denied)
  end

  defp execute(id, request, _credentials) when id in ["p809.browser_en", "p809.browser_af"] do
    locale = if id == "p809.browser_en", do: "en", else: "af"
    previous = Application.get_env(:new_you, :p8_08_browser_development_fixtures)
    Application.put_env(:new_you, :p8_08_browser_development_fixtures, true)

    try do
      checks = NewYou.Proof.P805Browser.run_login(request, locale)

      for key <- ~w(login_form protected_access reloaded_access),
          do: P805.check(id, key, checks[key])
    after
      if previous == nil,
        do: Application.delete_env(:new_you, :p8_08_browser_development_fixtures),
        else: Application.put_env(:new_you, :p8_08_browser_development_fixtures, previous)
    end
  end

  defp execute("p809.hold_race" = id, request, credentials) do
    parent = self()
    reference = make_ref()
    scenario = Scenario.start()

    %{rows: [[account_id]]} =
      Repo.query!("SELECT account_id FROM sessions WHERE id = $1", [
        Ecto.UUID.dump!(credentials.session_id)
      ])

    try do
      {_worker, login_monitor} =
        Scenario.spawn(scenario, :login, fn ->
          :ok = Sandbox.checkout(Repo, sandbox: false)
          Process.put(RegistrationSeam, {:pause, parent, reference})

          try do
            send(
              parent,
              {reference, :login_result,
               Identity.authenticate_password(request.email, request.password)}
            )
          after
            Sandbox.checkin(Repo)
          end
        end)

      {login_worker, login_backend} =
        receive do
          {^reference, :before_commit, worker, backend, _} -> {worker, backend}
        after
          15_000 -> raise "login checkpoint deadline"
        end

      {_holder, holder_monitor} =
        Scenario.spawn(scenario, :holder, fn ->
          :ok = Sandbox.checkout(Repo, sandbox: false)

          try do
            send(parent, {reference, :holder_backend, P805.scalar("SELECT pg_backend_pid()")})

            Repo.query!("UPDATE accounts SET security_posture = 'held' WHERE id = $1", [
              account_id
            ])

            send(parent, {reference, :held})
          after
            Sandbox.checkin(Repo)
          end
        end)

      holder_backend =
        receive do
          {^reference, :holder_backend, backend} -> backend
        after
          15_000 -> raise "hold worker deadline"
        end

      P805.check(
        id,
        "real_contention",
        blocked?(login_backend, holder_backend, System.monotonic_time(:millisecond) + 15_000)
      )

      send(login_worker, {reference, :release})

      login =
        receive do
          {^reference, :login_result, result} -> result
        after
          15_000 -> raise "login result deadline"
        end

      receive do
        {^reference, :held} -> :ok
      after
        15_000 -> raise "hold result deadline"
      end

      for monitor <- [login_monitor, holder_monitor] do
        receive do
          {:DOWN, ^monitor, :process, _, :normal} -> :ok
        after
          15_000 -> raise "race cleanup deadline"
        end
      end

      P805.check(id, "login_commits", match?({:ok, _}, login))
      {:ok, issued} = login

      P805.check(
        id,
        "hold_denies",
        Identity.authorize_session(issued) == {:error, :authentication_unavailable}
      )
    after
      :ok = Scenario.stop(scenario)
    end
  end

  defp execute("p809.interrupted_issue" = id, request, _credentials) do
    parent = self()
    reference = make_ref()
    scenario = Scenario.start()
    tokens_before = P805.scalar("SELECT count(*) FROM tokens")
    sessions_before = P805.scalar("SELECT count(*) FROM sessions")

    try do
      :ok = CutPoints.arm(scenario, "transaction.before_commit", :login, :terminate)

      {worker, monitor} =
        Scenario.spawn(scenario, :login, fn ->
          :ok = Sandbox.checkout(Repo, sandbox: false)

          Process.put(
            RegistrationSeam,
            {:observe,
             fn ->
               send(parent, {reference, :cut, P805.scalar("SELECT pg_backend_pid()")})
               CutPoints.hit(scenario, "transaction.before_commit", :login)
             end}
          )

          try do
            Identity.authenticate_password(request.email, request.password)
          after
            Sandbox.checkin(Repo)
          end
        end)

      old_backend =
        receive do
          {^reference, :cut, backend} -> backend
        after
          15_000 -> raise "P8-08 cut deadline"
        end

      receive do
        {:DOWN, ^monitor, :process, ^worker, :proof_terminated} -> :ok
      after
        15_000 -> raise "P8-08 termination deadline"
      end

      P805.check(id, "cut_consumed", CutPoints.verify_consumed(scenario) == :ok)

      P805.check(
        id,
        "atomic_rollback",
        tokens_before == P805.scalar("SELECT count(*) FROM tokens") and
          sessions_before == P805.scalar("SELECT count(*) FROM sessions")
      )

      {backend, result} =
        Task.async(fn ->
          Sandbox.unboxed_run(Repo, fn ->
            {P805.scalar("SELECT pg_backend_pid()"),
             Identity.authenticate_password(request.email, request.password)}
          end)
        end)
        |> Task.await(15_000)

      P805.check(id, "fresh_recovery", backend != old_backend and match?({:ok, _}, result))
    after
      :ok = Scenario.stop(scenario)
    end
  end

  defp blocked?(first, second, deadline) do
    case Repo.query!("SELECT $1 = ANY(pg_blocking_pids($2))", [first, second]).rows do
      [[true]] ->
        true

      _ ->
        if System.monotonic_time(:millisecond) < deadline,
          do: blocked?(first, second, deadline),
          else: false
    end
  end

  defp restart_process(credentials) do
    payload =
      Jason.encode!(%{
        session_id: credentials.session_id,
        token: credentials.token,
        signing_secret:
          Base.encode64(Application.fetch_env!(:new_you, :identity_token_signing_secret))
      })

    executable = System.find_executable("mix") || raise "mix unavailable"

    port =
      Port.open({:spawn_executable, executable}, [
        :binary,
        :exit_status,
        args: ["run", "test/proof/p8_09_restart.exs"],
        env: [{~c"MIX_ENV", ~c"test"}, {~c"ERL_FLAGS", ~c"+S 2:2"}]
      ])

    true = Port.command(port, payload <> "\n")
    restart_output(port, "", System.monotonic_time(:millisecond) + 30_000)
  end

  defp restart_output(port, output, deadline) do
    remaining = max(deadline - System.monotonic_time(:millisecond), 0)

    receive do
      {^port, {:data, bytes}} when byte_size(output) + byte_size(bytes) < 16_384 ->
        restart_output(port, output <> bytes, deadline)

      {^port, {:exit_status, 0}} ->
        cond do
          String.contains?(output, "P809_RESTART_ALLOWED") -> :allowed
          String.contains?(output, "P809_RESTART_DENIED") -> :denied
          true -> :error
        end

      {^port, {:exit_status, _}} ->
        :error
    after
      remaining ->
        Port.close(port)
        :error
    end
  end

  defp fresh(credentials) do
    Task.async(fn ->
      :ok = Sandbox.checkout(Repo, sandbox: false)

      try do
        {P805.scalar("SELECT pg_backend_pid()"), Identity.authorize_session(credentials)}
      after
        Sandbox.checkin(Repo)
      end
    end)
    |> Task.await(15_000)
  end
end
