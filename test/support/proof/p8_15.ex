defmodule NewYou.Proof.P815 do
  @moduledoc false

  import ExUnit.Assertions
  alias Ecto.Adapters.SQL.Sandbox
  alias NewYou.{Identity, Repo}
  alias NewYou.Identity.{Account, RecoveryCase, Token}

  alias NewYou.Proof.{
    CutPoints,
    P805,
    RecoveryBudget,
    RecoveryLease,
    RecoveryLoad,
    RecoveryScenarios,
    RecoverySeam,
    RegistrationSeam,
    Scenario
  }

  require Ash.Query

  def duplicate_request_race(verified? \\ true) do
    P805.with_fixture(fn ->
      {request, registration} =
        if verified? do
          account()
        else
          request = P805.request()
          {:ok, registration} = Identity.register(request)
          {request, registration}
        end

      before_account = Ash.get!(Account, registration.account_id, authorize?: false)
      first = operation()
      second = operation()

      race_recovery_requests(
        fn -> Identity.request_recovery(request.email, "af", first) end,
        fn -> Identity.request_recovery(request.email, "af", second) end
      )

      assert [recovery] = cases(registration.account_id)
      assert Ash.get!(Account, registration.account_id, authorize?: false) == before_account

      unless verified? do
        assert recovery.satisfied_assurance == 0
        assert recovery.state == :held_manual_review
      end

      :ok
    end)
  end

  def phase9_entry_race(first_context, second_context) do
    P805.with_fixture(fn ->
      Application.put_env(:new_you, :fp001_development_entry, true)
      Application.put_env(:new_you, :p8_15_browser_development_fixtures, false)
      {request, registration} = account()
      account_id = registration.account_id
      assert {:ok, session} = Identity.authenticate_password(request.email, request.password)
      before_account = Ash.get!(Account, account_id, authorize?: false)
      first = operation()
      second = operation()

      race_recovery_requests(
        fn -> Identity.request_recovery(request.email, "af", first, first_context) end,
        fn -> Identity.request_recovery(request.email, "af", second, second_context) end
      )

      assert [%{operation_id: ^first, entry_context: ^first_context, locale: "af"} = recovery] =
               cases(account_id)

      assert recovery.state == :proof_pending
      assert recovery.satisfied_assurance == 0
      assert {token, intent} = RecoveryScenarios.assert_recovery_proof(recovery)
      assert intent.locale == "af"
      assert NewYou.Communications.recovery_context(intent) == first_context
      assert P805.intents(second) == []

      assert :ok = Identity.request_recovery(request.email, "af", first, second_context)
      assert :ok = Identity.request_recovery(request.email, "af", first, first_context)
      assert [^recovery] = cases(account_id)
      assert {^token, ^intent} = RecoveryScenarios.assert_recovery_proof(recovery)

      {:ok, bearer} = delivery(recovery, request.email)
      acceptance = operation()
      other_context = if first_context == :well183, do: :p8_15, else: :well183

      assert {:error, :recovery_unavailable} =
               Identity.submit_recovery_proof(bearer, acceptance, "af", other_context)

      if first_context == :well183 do
        assert {:error, :recovery_unavailable} =
                 Identity.submit_recovery_proof(bearer, acceptance, "en", :well183)
      end

      assert [^recovery] = cases(account_id)
      assert {^token, ^intent} = RecoveryScenarios.assert_recovery_proof(recovery)

      assert {:ok, :accepted} =
               Identity.submit_recovery_proof(bearer, acceptance, "af", first_context)

      assert [
               %{id: id, state: :additional_assurance, proof_acceptance_id: ^acceptance} =
                 accepted
             ] =
               cases(account_id)

      assert id == recovery.id
      assert accepted.entry_context == first_context
      assert accepted.locale == "af"
      assert accepted.satisfied_assurance == 1
      assert accepted.version == recovery.version + 1

      assert {:ok, :accepted} =
               Identity.submit_recovery_proof(bearer, acceptance, "af", first_context)

      assert {:error, :recovery_unavailable} =
               Identity.submit_recovery_proof(bearer, acceptance, "af", other_context)

      assert [^accepted] = cases(account_id)
      assert {:ok, _} = Identity.authorize_session(session)
      assert Ash.get!(Account, account_id, authorize?: false) == before_account
      assert Ash.get!(Token, token.jti, authorize?: false).purpose == "recovery_consumed"
      assert P805.intents(first) == [intent]
      assert P805.intents(acceptance) == []
      refute RecoveryScenarios.hold_obligation(first)
      refute RecoveryScenarios.hold_obligation(second)
      :ok
    end)
  end

  def phase9_conflicting_retries do
    P805.with_fixture(fn ->
      Application.put_env(:new_you, :fp001_development_entry, true)
      request = P805.request()
      {:ok, registration} = Identity.register(request)
      account_id = registration.account_id
      original = operation()
      other = operation()
      :ok = Identity.request_recovery(request.email, "af", original, :well183)
      assert [%{state: :held_manual_review, proof_jti: nil} = waiting] = cases(account_id)
      assert {:ok, :verified} = Identity.verify_email(registration.verification_proof)
      account = Ash.get!(Account, account_id, authorize?: false)

      # The channel is now genuinely verified. An otherwise valid retry can
      # resume the case, so unchanged state discriminates the context/locale guard.
      for {operation, locale, context} <- [
            {original, "en", :well183},
            {other, "en", :well183},
            {original, "af", :p8_15},
            {other, "af", :p8_15}
          ] do
        assert :ok = Identity.request_recovery(request.email, locale, operation, context)
        assert [^waiting] = cases(account_id)
        assert P805.intents(operation) == []
      end

      race_recovery_requests(
        fn -> Identity.request_recovery(request.email, "af", original, :well183) end,
        fn -> Identity.request_recovery(request.email, "en", other, :well183) end
      )

      assert [%{state: :proof_pending, entry_context: :well183, locale: "af"} = resumed] =
               cases(account_id)

      assert resumed.id == waiting.id
      assert resumed.operation_id == original
      assert resumed.version == waiting.version + 1
      assert resumed.satisfied_assurance == 0

      assert {_token, %{render_schema: "recovery-well183-v1"}} =
               RecoveryScenarios.assert_recovery_proof(resumed)

      assert P805.intents(other) == []
      assert Ash.get!(Account, account_id, authorize?: false) == account
      refute RecoveryScenarios.hold_obligation(original)
      refute RecoveryScenarios.hold_obligation(other)
      :ok
    end)
  end

  defp race_recovery_requests(first_request, second_request) do
    parent = self()
    reference = make_ref()
    scenario = Scenario.start()

    try do
      {second, second_monitor} =
        Scenario.spawn(scenario, :second_request, fn ->
          :ok = Sandbox.checkout(Repo, sandbox: false)

          try do
            backend = P805.scalar("SELECT pg_backend_pid()")
            send(parent, {reference, :second_backend, backend})

            receive do
              {^reference, :begin} ->
                RecoverySeam.observe(fn
                  :transaction_returned -> send(parent, {reference, :second_committed})
                  _ -> :ok
                end)

                send(parent, {reference, :second_result, second_request.()})
            end
          after
            Sandbox.checkin(Repo)
          end
        end)

      second_backend = receive_backend(reference, :second_backend)

      {first, first_monitor} =
        Scenario.spawn(scenario, :first_request, fn ->
          :ok = Sandbox.checkout(Repo, sandbox: false)
          Process.put(RegistrationSeam, {:pause, parent, reference})

          try do
            send(parent, {reference, :first_result, first_request.()})
          after
            Sandbox.checkin(Repo)
          end
        end)

      first_backend = await_checkpoint(reference)
      send(second, {reference, :begin})
      assert_contention(second_backend, first_backend)
      send(first, {reference, :release})
      assert await_result(reference, :first_result) == :ok
      assert await_result(reference, :second_result) == :ok
      assert_received {^reference, :second_committed}
      await_normal(first_monitor)
      await_normal(second_monitor)
    after
      :ok = Scenario.stop(scenario)
    end
  end

  def assurance_race do
    P805.with_fixture(fn ->
      {request, registration} = account()
      before_account = Ash.get!(Account, registration.account_id, authorize?: false)

      Ash.update!(before_account, %{mfa_enrollment_state: :active},
        action: :update_privileged_mfa,
        authorize?: false
      )

      {:ok, session} = Identity.authenticate_password(request.email, request.password)
      request_id = operation()
      :ok = Identity.request_recovery(request.email, "af", request_id)
      [recovery] = cases(registration.account_id)
      {:ok, bearer} = delivery(recovery, request.email)
      acceptance_id = operation()
      parent = self()
      reference = make_ref()
      scenario = Scenario.start()

      try do
        {first, first_monitor} =
          Scenario.spawn(scenario, :first_acceptance, fn ->
            :ok = Sandbox.checkout(Repo, sandbox: false)
            Process.put(RegistrationSeam, {:pause, parent, reference})

            try do
              send(
                parent,
                {reference, :first_result, Identity.submit_recovery_proof(bearer, acceptance_id)}
              )
            after
              Sandbox.checkin(Repo)
            end
          end)

        first_backend = await_checkpoint(reference)

        {_second, second_monitor} =
          Scenario.spawn(scenario, :second_acceptance, fn ->
            :ok = Sandbox.checkout(Repo, sandbox: false)

            try do
              send(parent, {reference, :second_backend, P805.scalar("SELECT pg_backend_pid()")})

              send(
                parent,
                {reference, :second_result, Identity.submit_recovery_proof(bearer, acceptance_id)}
              )
            after
              Sandbox.checkin(Repo)
            end
          end)

        second_backend = receive_backend(reference, :second_backend)
        assert_contention(second_backend, first_backend)
        send(first, {reference, :release})
        assert await_result(reference, :first_result) == {:ok, :accepted}
        assert await_result(reference, :second_result) == {:ok, :accepted}
        await_normal(first_monitor)
        await_normal(second_monitor)
        current = Ash.get!(Account, registration.account_id, authorize?: false)
        assert current.security_posture == :held
        assert current.security_version == before_account.security_version + 1
        assert current.hold_version == before_account.hold_version + 1
        assert Identity.authorize_session(session) == {:error, :authentication_unavailable}

        assert P805.scalar(
                 "SELECT count(*) FROM evidence_obligations WHERE source_operation_id=$1 AND evidence_type='security_hold_placement'",
                 [Ecto.UUID.dump!(request_id)]
               ) == 1

        accepted = Ash.get!(RecoveryCase, recovery.id, authorize?: false)
        assert accepted.required_assurance == 2
        assert accepted.satisfied_assurance == 1
        assert Enum.count(accepted.history, &(&1["action"] == "accept_proof")) == 1
      after
        Scenario.stop(scenario)
      end
    end)
  end

  def unverified_restart_proof(opts \\ []) do
    P805.with_fixture(fn ->
      request = P805.request()
      {:ok, registration} = Identity.register(request)
      id = operation()
      before_account = Ash.get!(Account, registration.account_id, authorize?: false)
      recovery = request_unverified_case(registration.account_id, request.email, id, 3)
      secret = Base.encode64(Application.fetch_env!(:new_you, :identity_token_signing_secret))

      input = %{
        mode: "request",
        email: request.email,
        locale: "af",
        operation_id: id,
        case_id: recovery.id,
        expected_state: "held_manual_review",
        signing_secret: secret
      }

      assert restart_call(input) == :requested
      assert Ash.get!(Account, registration.account_id, authorize?: false) == before_account
      assert Ash.get!(RecoveryCase, recovery.id, authorize?: false).satisfied_assurance == 0
      assert {:ok, :verified} = Identity.verify_email(registration.verification_proof)
      verified_account = Ash.get!(Account, registration.account_id, authorize?: false)
      before_resume = Ash.get!(RecoveryCase, recovery.id, authorize?: false)
      interrupted? = Keyword.get(opts, :interrupt_resume?, false)

      if interrupted? do
        cut_result =
          restart_call(
            Map.merge(input, %{
              expected_state: "proof_pending",
              interrupt_request: true,
              skip_interrupt: Keyword.get(opts, :skip_interrupt?, false)
            })
          )

        record_failed_request_state(cut_result, verified_account, before_resume)
        assert_valid_skipped_cut(opts, before_resume)
        assert cut_result == :request_interrupted

        # A separate connection observes rollback after the registered OS group
        # is gone, before any retry can create the final proof or intent.
        rolled_back = Ash.get!(RecoveryCase, recovery.id, authorize?: false)
        assert rolled_back == before_resume
        assert rolled_back.state == :held_manual_review
        assert rolled_back.proof_jti == nil
        assert rolled_back.operation_id == id
        assert rolled_back.satisfied_assurance == 0
        assert Ash.get!(Account, registration.account_id, authorize?: false) == verified_account

        assert P805.scalar("SELECT count(*) FROM tokens WHERE recovery_case_id=$1", [
                 Ecto.UUID.dump!(recovery.id)
               ]) == 0

        assert P805.scalar(
                 "SELECT count(*) FROM message_intents WHERE source_operation_id=$1 AND role='account_recovery'",
                 [Ecto.UUID.dump!(id)]
               ) == 0
      end

      # Retry in a fresh VM with exactly the original operation and case IDs.
      rollback_once? = Keyword.get(opts, :rollback_resume_once?, false)

      resumed_request =
        restart_call(
          Map.merge(input, %{
            expected_state: "proof_pending",
            rollback_request_once: rollback_once?
          })
        )

      expected_request = if rollback_once?, do: :request_retried, else: :requested
      record_failed_request_state(resumed_request, verified_account, before_resume)
      assert resumed_request == expected_request

      resumed = Ash.get!(RecoveryCase, recovery.id, authorize?: false)
      assert resumed.operation_id == id
      assert resumed.state == :proof_pending
      assert resumed.required_assurance == 2
      assert resumed.satisfied_assurance == 0
      assert Enum.map(cases(registration.account_id), & &1.id) == [recovery.id]
      assert Ash.get!(Account, registration.account_id, authorize?: false) == verified_account

      assert P805.scalar("SELECT count(*) FROM tokens WHERE recovery_case_id=$1", [
               Ecto.UUID.dump!(recovery.id)
             ]) == 1

      assert P805.scalar(
               "SELECT count(*) FROM message_intents WHERE source_operation_id=$1 AND role='account_recovery'",
               [Ecto.UUID.dump!(id)]
             ) == 1

      {:ok, bearer} = delivery(resumed, request.email)
      assert Identity.cancel_recovery(bearer, operation()) == {:ok, :cancelled}

      assert Ash.get!(Account, registration.account_id, authorize?: false).security_posture ==
               :normal

      :ok
    end)
  end

  def interrupted_request(opts \\ []) do
    P805.with_fixture(fn ->
      fixture = resumable_fixture()
      scenario = Scenario.start()

      try do
        cut_request(scenario, fixture, opts)
        assert_resume_rolled_back(fixture)

        assert :ok =
                 RecoverySeam.isolated_fixture_request(
                   fixture.request.email,
                   fixture.recovery.operation_id
                 )

        resumed = assert_resumed_request(fixture)
        RecoveryScenarios.assert_recovery_proof(resumed)
        :ok
      after
        assert :ok = Scenario.stop(scenario)
      end
    end)
  end

  defp cut_request(scenario, fixture, opts) do
    parent = self()
    reference = make_ref()
    checkpoint = "transaction.before_commit"

    {worker, monitor} =
      Scenario.spawn(scenario, :resume_recovery, fn ->
        :ok = Sandbox.checkout(Repo, sandbox: false)

        # Sample before the request can check out its transaction lease. This
        # is a conservative bound on the earliest possible lease expiry.
        deadline =
          System.monotonic_time(:millisecond) + Identity.Recovery.request_transaction_timeout_ms()

        Process.put(
          RegistrationSeam,
          {:observe,
           fn ->
             assert Repo.in_transaction?(), "Recovery checkpoint ran outside the transaction"

             %{rows: [[backend, xid]]} =
               Repo.query!("SELECT pg_backend_pid(), pg_current_xact_id()::text")

             send(parent, {reference, :before_commit, self(), backend, xid, deadline})

             receive do
               {^reference, :cut} -> CutPoints.hit(scenario, checkpoint, :resume_recovery)
             after
               2_000 -> flunk("Recovery controller did not authorize the pre-commit cut")
             end
           end}
        )

        try do
          Identity.request_recovery(fixture.request.email, "af", fixture.recovery.operation_id)
        after
          Sandbox.checkin(Repo)
        end
      end)

    receive do
      {^reference, :before_commit, ^worker, backend, xid, deadline} ->
        if Keyword.get(opts, :expire_before_cut?, false) do
          await_aborted_transaction(xid, System.monotonic_time(:millisecond) + 2_000)
        end

        assert P805.scalar(
                 """
                 SELECT pg_backend_pid() <> $1
                   AND pg_xact_status($2::text::xid8) = 'in progress'
                   AND EXISTS (
                     SELECT 1 FROM pg_locks
                     WHERE pid = $1 AND locktype = 'transactionid'
                       AND transactionid = $2::text::xid8::xid
                       AND mode = 'ExclusiveLock' AND granted
                   )
                 """,
                 [backend, xid]
               ) == true,
               "the exact transaction was no longer in progress at the cut"

        assert :ok = CutPoints.arm(scenario, checkpoint, :resume_recovery, :terminate)
        send(worker, {reference, :cut})
        assert_receive {:DOWN, ^monitor, :process, ^worker, :proof_terminated}, 2_000
        await_aborted_transaction(xid, deadline)

        assert System.monotonic_time(:millisecond) < deadline,
               "the exact transaction was not observed aborted before possible lease expiry"

        assert :ok = CutPoints.verify_consumed(scenario)
        assert :ok = Scenario.request(scenario, {:await_owned_down, [worker], 5_000})

      {:DOWN, ^monitor, :process, ^worker, _reason} ->
        flunk("Recovery worker exited before acknowledging its pre-commit checkpoint")
    after
      5_000 -> flunk("Recovery worker did not acknowledge its pre-commit checkpoint")
    end
  end

  # This proves lease expiry separately from the registered checkpoint cut.
  # The retry is explicitly driven by this TEST controller, not a browser flow.
  def pre_checkpoint_timeout_proof(stage, opts \\ [])
      when stage in [:transaction_entered, :account_locked, :await_proof] do
    P805.with_fixture(fn ->
      fixture = resumable_fixture()
      scenario = Scenario.start()

      try do
        {worker, monitor, reference} = spawn_timeout_request(scenario, fixture, stage, opts)
        {backend, transaction, counts} = await_timeout_lease(reference, worker, monitor)
        assert backend != P805.scalar("SELECT pg_backend_pid()")
        assert counts == if(stage == :await_proof, do: {1, 1}, else: {0, 0})
        await_aborted_transaction(transaction, System.monotonic_time(:millisecond) + 2_000)
        assert_resume_rolled_back(fixture)
        send(worker, {reference, :aborted_transaction_observed})
        await_lease_expired(reference)
        {phases, database_failures} = await_timeout_result(reference)
        assert :lease_lost in database_failures
        refute :checkpoint in phases
        assert stage in phases
        assert :transaction_exception in phases or :transaction_error in phases
        await_normal(monitor)
        assert :ok = Scenario.request(scenario, {:await_owned_down, [worker], 5_000})
        assert_resume_rolled_back(fixture)
        assert_timeout_retry(fixture)
      after
        :ok = Scenario.stop(scenario)
      end
    end)
  end

  defp resumable_fixture do
    request = P805.request()
    {:ok, registration} = Identity.register(request)
    id = operation()
    recovery = request_unverified_case(registration.account_id, request.email, id, 3)
    assert {:ok, :verified} = Identity.verify_email(registration.verification_proof)

    %{
      request: request,
      recovery: recovery,
      account: Ash.get!(Account, registration.account_id, authorize?: false)
    }
  end

  defp spawn_timeout_request(scenario, fixture, stage, opts) do
    parent = self()
    reference = make_ref()

    {worker, monitor} =
      Scenario.spawn(scenario, :pre_checkpoint_timeout, fn ->
        timeout_request(parent, reference, fixture, stage, opts)
      end)

    {worker, monitor, reference}
  end

  defp timeout_request(parent, reference, fixture, stage, opts) do
    :ok = Sandbox.checkout(Repo, sandbox: false)
    install_timeout_observer(parent, reference, fixture, stage, opts)

    try do
      {:ok, database_failures} =
        NewYou.Proof.RecoverySeam.capture_database_failures(fn ->
          Identity.request_recovery(fixture.request.email, "af", fixture.recovery.operation_id)
        end)

      phases = Process.get({__MODULE__, :timeout_phases}, []) |> Enum.reverse()
      send(parent, {reference, :timeout_request_completed, {phases, database_failures}})
    after
      Process.delete({NewYou.Proof.RecoverySeam, :observer})
      Process.delete({__MODULE__, :timeout_phases})
      Sandbox.checkin(Repo)
    end
  end

  defp install_timeout_observer(parent, reference, fixture, stage, opts) do
    NewYou.Proof.RecoverySeam.observe(fn reached ->
      phases = Process.get({__MODULE__, :timeout_phases}, [])
      Process.put({__MODULE__, :timeout_phases}, [reached | phases])

      if reached == stage, do: observe_timeout_lease(parent, reference, fixture, opts)
    end)
  end

  defp observe_timeout_lease(parent, reference, fixture, opts) do
    %{rows: [[backend, transaction]]} =
      Repo.query!("SELECT pg_backend_pid(), pg_current_xact_id()::text")

    counts = timeout_effect_counts(fixture.recovery)
    send(parent, {reference, :timeout_lease, self(), backend, transaction, counts})

    if not Keyword.get(opts, :skip_timeout?, false),
      do: await_timeout_release(parent, reference)
  end

  defp await_timeout_release(parent, reference) do
    # The request lease expires while this callback is paused.
    # The controller releases it only after PostgreSQL reports this XID aborted.
    receive do
      {^reference, :aborted_transaction_observed} ->
        try do
          Repo.query!("SELECT 1")
          send(parent, {reference, :lease_still_usable})
        rescue
          error in DBConnection.ConnectionError ->
            send(parent, {reference, :lease_expired})
            reraise error, __STACKTRACE__
        end
    after
      5_000 -> raise "timeout proof controller did not release the observed lease"
    end
  end

  defp await_timeout_lease(reference, worker, monitor) do
    receive do
      {^reference, :timeout_lease, ^worker, backend, transaction, counts} ->
        {backend, transaction, counts}

      {^reference, :timeout_request_completed, _phases} ->
        flunk("pre-checkpoint timeout prerequisite was not reached")

      {:DOWN, ^monitor, :process, ^worker, _} ->
        flunk("pre-checkpoint timeout worker terminated before lease observation")
    after
      5_000 -> flunk("pre-checkpoint timeout lease was not observed")
    end
  end

  defp await_aborted_transaction(transaction, deadline) do
    case P805.scalar("SELECT pg_xact_status($1::text::xid8)", [transaction]) do
      "aborted" ->
        :ok

      "in progress" ->
        assert System.monotonic_time(:millisecond) < deadline,
               "the exact transaction was still in progress at the observation deadline"

        receive do
        after
          5 -> await_aborted_transaction(transaction, deadline)
        end

      "committed" ->
        flunk("pre-checkpoint timeout not proven: transaction committed")

      _ ->
        flunk("pre-checkpoint transaction outcome unavailable")
    end
  end

  defp await_lease_expired(reference) do
    receive do
      {^reference, :lease_expired} -> :ok
      {^reference, :lease_still_usable} -> flunk("transaction lease did not expire")
      {^reference, :timeout_request_completed, _} -> flunk("lease loss was not proven")
    after
      5_000 -> flunk("expired lease observation was not received")
    end
  end

  defp await_timeout_result(reference) do
    receive do
      {^reference, :timeout_request_completed, result} -> result
    after
      5_000 -> flunk("neutral request outcome was not received after timeout")
    end
  end

  defp timeout_effect_counts(recovery) do
    tokens =
      P805.scalar("SELECT count(*) FROM tokens WHERE recovery_case_id=$1", [
        Ecto.UUID.dump!(recovery.id)
      ])

    intents =
      P805.scalar(
        "SELECT count(*) FROM message_intents WHERE source_operation_id=$1 AND role='account_recovery'",
        [Ecto.UUID.dump!(recovery.operation_id)]
      )

    {tokens, intents}
  end

  defp assert_resume_rolled_back(fixture) do
    account_unchanged? =
      Ash.get!(Account, fixture.account.id, authorize?: false) == fixture.account

    case_unchanged? =
      Ash.get!(RecoveryCase, fixture.recovery.id, authorize?: false) == fixture.recovery

    assert account_unchanged?, "rolled-back request changed Account state"
    assert case_unchanged?, "rolled-back request changed RecoveryCase state"
    assert timeout_effect_counts(fixture.recovery) == {0, 0}
    assert P805.scalar("SELECT 1") == 1
  end

  defp assert_timeout_retry(fixture) do
    input = %{
      mode: "request",
      email: fixture.request.email,
      locale: "af",
      operation_id: fixture.recovery.operation_id,
      case_id: fixture.recovery.id,
      expected_state: "proof_pending",
      signing_secret:
        Base.encode64(Application.fetch_env!(:new_you, :identity_token_signing_secret))
    }

    retry_result = restart_call(input)
    record_failed_request_state(retry_result, fixture.account, fixture.recovery)
    assert retry_result == :requested
    assert_resumed_request(fixture)
    :ok
  end

  defp assert_resumed_request(fixture) do
    resumed = Ash.get!(RecoveryCase, fixture.recovery.id, authorize?: false)
    assert resumed.operation_id == fixture.recovery.operation_id
    assert resumed.state == :proof_pending
    assert resumed.version == fixture.recovery.version + 1
    assert resumed.required_assurance == 2
    assert resumed.satisfied_assurance == 0
    assert Enum.map(cases(fixture.account.id), & &1.id) == [fixture.recovery.id]

    account_unchanged? =
      Ash.get!(Account, fixture.account.id, authorize?: false) == fixture.account

    assert account_unchanged?
    assert timeout_effect_counts(resumed) == {1, 1}
    resumed
  end

  defp record_failed_request_state(
         {:restart_failed, %{cleanup: :confirmed}},
         expected_account,
         expected_case
       ) do
    account = Ash.get!(Account, expected_account.id, authorize?: false)
    recovery = Ash.get!(RecoveryCase, expected_case.id, authorize?: false)
    {tokens, intents} = timeout_effect_counts(expected_case)

    # This is a durable observation after confirmed child cleanup, never a
    # successful cut/retry receipt. No identifiers or request data are logged.
    IO.puts(
      :stderr,
      "P815_FAILED_REQUEST_STATE " <>
        inspect(%{
          account_unchanged?: account == expected_account,
          case_unchanged?: recovery == expected_case,
          token_count: tokens,
          intent_count: intents
        })
    )
  end

  defp record_failed_request_state(_result, _account, _recovery), do: :ok

  defp assert_valid_skipped_cut(opts, recovery) do
    if Keyword.get(opts, :skip_interrupt?, false) do
      assert Ash.get!(RecoveryCase, recovery.id, authorize?: false).state == :proof_pending,
             "missing-checkpoint control did not commit its valid request"

      assert timeout_effect_counts(recovery) == {1, 1}
    end
  end

  # A neutral public acknowledgement does not promise a committed fixture.
  # Establish the valid zero-assurance prerequisite through the same operation,
  # without retrying an interruption proof or changing its deadline.
  defp request_unverified_case(account_id, email, operation_id, attempts) do
    :ok = RecoverySeam.isolated_fixture_request(email, operation_id)

    case cases(account_id) do
      [recovery] ->
        assert recovery.operation_id == operation_id
        assert recovery.state == :held_manual_review
        assert recovery.proof_jti == nil
        recovery

      [] when attempts > 1 ->
        IO.puts(:stderr, "P815_FIXTURE_REQUEST_UNCOMMITTED")
        request_unverified_case(account_id, email, operation_id, attempts - 1)

      [] ->
        flunk("recovery fixture request did not commit after 3 bounded attempts")
    end
  end

  # P8-16 has no apply interface on this base. This fixture models an earlier
  # Account-owner email commit and proves only recovery's real lock/re-read guard.
  def prior_email_commit_race do
    P805.with_fixture(fn ->
      {_request, registration, recovery, bearer} = pending_recovery()
      replacement = "earlier-" <> Ecto.UUID.generate() <> "@example.test"
      P805.request(%{email: replacement})
      parent = self()
      reference = make_ref()
      scenario = Scenario.start()

      try do
        {writer, writer_monitor} =
          Scenario.spawn(scenario, :earlier_email_fixture, fn ->
            :ok = Sandbox.checkout(Repo, sandbox: false)

            try do
              {:ok, :ok} =
                Repo.transaction(fn ->
                  Repo.query!("UPDATE accounts SET email=$1 WHERE id=$2", [
                    replacement,
                    Ecto.UUID.dump!(registration.account_id)
                  ])

                  send(
                    parent,
                    {reference, :writer_backend, P805.scalar("SELECT pg_backend_pid()")}
                  )

                  receive do
                    {^reference, :release} -> :ok
                  after
                    10_000 -> raise "email fixture release deadline"
                  end
                end)
            after
              Sandbox.checkin(Repo)
            end
          end)

        writer_backend = receive_backend(reference, :writer_backend)

        {_consumer, consumer_monitor} =
          Scenario.spawn(scenario, :recovery_after_email, fn ->
            :ok = Sandbox.checkout(Repo, sandbox: false)

            try do
              send(parent, {reference, :consumer_backend, P805.scalar("SELECT pg_backend_pid()")})

              send(
                parent,
                {reference, :consumer_result, Identity.submit_recovery_proof(bearer, operation())}
              )
            after
              Sandbox.checkin(Repo)
            end
          end)

        consumer_backend = receive_backend(reference, :consumer_backend)
        assert_contention(consumer_backend, writer_backend)
        send(writer, {reference, :release})
        assert await_result(reference, :consumer_result) == {:ok, :failed}
        await_normal(writer_monitor)
        await_normal(consumer_monitor)
        assert Ash.get!(RecoveryCase, recovery.id, authorize?: false).state == :failed
        assert Ash.get!(Account, registration.account_id, authorize?: false).email == replacement
        assert account_version(registration.account_id) == 1

        assert Ash.get!(Token, recovery.proof_jti, authorize?: false).purpose ==
                 "recovery_revoked"
      after
        Scenario.stop(scenario)
      end
    end)
  end

  def completion_race do
    P805.with_fixture(fn ->
      {request, registration, recovery, bearer} = pending_recovery()
      assert Identity.submit_recovery_proof(bearer, operation()) == {:ok, :accepted}
      parent = self()
      reference = make_ref()
      first_operation = operation()
      second_operation = operation()
      scenario = Scenario.start()

      try do
        {first, first_monitor} =
          Scenario.spawn(scenario, :first_completion, fn ->
            :ok = Sandbox.checkout(Repo, sandbox: false)
            Process.put(RegistrationSeam, {:pause, parent, reference})

            try do
              result = Identity.complete_recovery(bearer, "recovered credential", first_operation)
              send(parent, {reference, :first_result, result})
            after
              Sandbox.checkin(Repo)
            end
          end)

        first_backend = await_checkpoint(reference)

        {_second, second_monitor} =
          Scenario.spawn(scenario, :second_completion, fn ->
            :ok = Sandbox.checkout(Repo, sandbox: false)

            try do
              backend = P805.scalar("SELECT pg_backend_pid()")
              send(parent, {reference, :second_backend, backend})

              result =
                Identity.complete_recovery(bearer, "competing credential", second_operation)

              send(parent, {reference, :second_result, result})
            after
              Sandbox.checkin(Repo)
            end
          end)

        second_backend = receive_backend(reference, :second_backend)
        assert_contention(second_backend, first_backend)
        send(first, {reference, :release})
        assert await_result(reference, :first_result) == {:ok, :completed}
        assert await_result(reference, :second_result) == {:error, :recovery_unavailable}
        await_normal(first_monitor)
        await_normal(second_monitor)
        assert Ash.get!(RecoveryCase, recovery.id, authorize?: false).state == :completed
        assert account_version(registration.account_id) == 2

        assert Identity.complete_recovery(bearer, "retry", first_operation) ==
                 {:ok, :already_completed}

        assert Identity.complete_recovery(bearer, "replay", second_operation) ==
                 {:error, :recovery_unavailable}

        assert request.email == recovery_account_email(registration.account_id)
      after
        :ok = Scenario.stop(scenario)
      end
    end)
  end

  def terminal_race(first_action) when first_action in [:complete, :cancel] do
    P805.with_fixture(fn ->
      {_request, registration, recovery, bearer} = pending_recovery()
      assert Identity.submit_recovery_proof(bearer, operation()) == {:ok, :accepted}
      before_account = Ash.get!(Account, registration.account_id, authorize?: false)
      parent = self()
      reference = make_ref()
      first_operation = operation()
      second_operation = operation()
      second_action = if first_action == :complete, do: :cancel, else: :complete
      scenario = Scenario.start()

      try do
        {first, first_monitor} =
          Scenario.spawn(scenario, :first_terminal_action, fn ->
            :ok = Sandbox.checkout(Repo, sandbox: false)
            Process.put(RegistrationSeam, {:pause, parent, reference})

            try do
              result = terminal_action(first_action, bearer, first_operation)
              send(parent, {reference, :first_result, result})
            after
              Sandbox.checkin(Repo)
            end
          end)

        first_backend = await_checkpoint(reference)

        {_second, second_monitor} =
          Scenario.spawn(scenario, :second_terminal_action, fn ->
            :ok = Sandbox.checkout(Repo, sandbox: false)

            try do
              send(parent, {reference, :second_backend, P805.scalar("SELECT pg_backend_pid()")})
              result = terminal_action(second_action, bearer, second_operation)
              send(parent, {reference, :second_result, result})
            after
              Sandbox.checkin(Repo)
            end
          end)

        second_backend = receive_backend(reference, :second_backend)
        assert_contention(second_backend, first_backend)
        send(first, {reference, :release})
        expected = if first_action == :complete, do: :completed, else: :cancelled
        assert await_result(reference, :first_result) == {:ok, expected}
        assert await_result(reference, :second_result) == {:error, :recovery_unavailable}
        await_normal(first_monitor)
        await_normal(second_monitor)
        assert Ash.get!(RecoveryCase, recovery.id, authorize?: false).state == expected
        after_account = Ash.get!(Account, registration.account_id, authorize?: false)
        increment = if first_action == :complete, do: 1, else: 0
        assert after_account.credential_version == before_account.credential_version + increment
        assert after_account.security_posture == :normal
        assert after_account.email == before_account.email

        assert P805.scalar(
                 "SELECT count(*) FROM message_intents WHERE role = 'recovery_security_notice' AND source_operation_id = $1",
                 [Ecto.UUID.dump!(first_operation)]
               ) == increment

        assert terminal_action(first_action, bearer, first_operation) ==
                 {:ok, if(first_action == :complete, do: :already_completed, else: :cancelled)}

        assert terminal_action(second_action, bearer, second_operation) ==
                 {:error, :recovery_unavailable}
      after
        :ok = Scenario.stop(scenario)
      end
    end)
  end

  defp terminal_action(:complete, bearer, id),
    do: Identity.complete_recovery(bearer, "terminal race replacement password", id)

  defp terminal_action(:cancel, bearer, id), do: Identity.cancel_recovery(bearer, id)

  def stale_login_race do
    P805.with_fixture(fn ->
      {request, _registration, recovery, bearer} = pending_recovery()
      {:ok, session} = Identity.authenticate_password(request.email, request.password)
      assert Identity.submit_recovery_proof(bearer, operation()) == {:ok, :accepted}
      parent = self()
      reference = make_ref()
      scenario = Scenario.start()

      try do
        {completion, completion_monitor} =
          Scenario.spawn(scenario, :completion, fn ->
            :ok = Sandbox.checkout(Repo, sandbox: false)
            Process.put(RegistrationSeam, {:pause, parent, reference})

            try do
              result = Identity.complete_recovery(bearer, "new recovery password", operation())
              send(parent, {reference, :completion_result, result})
            after
              Sandbox.checkin(Repo)
            end
          end)

        completion_backend = await_checkpoint(reference)

        {_login, login_monitor} =
          Scenario.spawn(scenario, :old_password_login, fn ->
            :ok = Sandbox.checkout(Repo, sandbox: false)

            try do
              backend = P805.scalar("SELECT pg_backend_pid()")
              send(parent, {reference, :login_backend, backend})
              result = Identity.authenticate_password(request.email, request.password)
              send(parent, {reference, :login_result, safe_login(result)})
            after
              Sandbox.checkin(Repo)
            end
          end)

        login_backend = receive_backend(reference, :login_backend)
        assert_contention(login_backend, completion_backend)
        send(completion, {reference, :release})
        assert await_result(reference, :completion_result) == {:ok, :completed}
        assert await_result(reference, :login_result) == :denied
        await_normal(completion_monitor)
        await_normal(login_monitor)
        assert Identity.authorize_session(session) == {:error, :authentication_unavailable}
        assert Ash.get!(RecoveryCase, recovery.id, authorize?: false).state == :completed
      after
        :ok = Scenario.stop(scenario)
      end

      :ok
    end)
  end

  def reset_vs_recovery_race(around \\ fn race -> race.() end) do
    P805.with_fixture(fn -> around.(&reset_vs_recovery_fixture/0) end)
  end

  defp reset_vs_recovery_fixture do
    {foreign_request, foreign_registration} = account()
    :ok = Identity.request_password_reset(foreign_request.email, "af", operation())

    foreign_proof =
      Token
      |> Ash.Query.filter(
        account_id == ^foreign_registration.account_id and purpose == "password_reset"
      )
      |> Ash.read_one!(authorize?: false)

    {request, registration, _recovery, recovery_bearer} =
      pending_recovery(&RecoverySeam.isolated_fixture_request/2)

    assert Identity.submit_recovery_proof(recovery_bearer, operation()) == {:ok, :accepted}
    reset_bearer = password_reset_delivery(request, registration.account_id)
    parent = self()
    reference = make_ref()
    scenario = Scenario.start()

    try do
      {completion, completion_monitor} =
        Scenario.spawn(scenario, :recovery_completion, fn ->
          :ok = Sandbox.checkout(Repo, sandbox: false)
          Process.put(RegistrationSeam, {:pause, parent, reference})

          try do
            result =
              Identity.complete_recovery(
                recovery_bearer,
                "recovery credential wins",
                operation()
              )

            send(parent, {reference, :completion_result, result})
          after
            Sandbox.checkin(Repo)
          end
        end)

      completion_backend = await_checkpoint(reference)

      {_reset, reset_monitor} =
        Scenario.spawn(scenario, :stale_password_reset, fn ->
          :ok = Sandbox.checkout(Repo, sandbox: false)

          try do
            backend = P805.scalar("SELECT pg_backend_pid()")
            send(parent, {reference, :reset_backend, backend})

            result =
              Identity.reset_password(reset_bearer, "stale reset credential", operation())

            send(parent, {reference, :reset_result, safe_reset(result)})
          after
            Sandbox.checkin(Repo)
          end
        end)

      reset_backend = receive_backend(reference, :reset_backend)
      assert_contention(reset_backend, completion_backend)
      send(completion, {reference, :release})
      assert await_result(reference, :completion_result) == {:ok, :completed}
      assert await_result(reference, :reset_result) == :denied
      await_normal(completion_monitor)
      await_normal(reset_monitor)
      assert account_version_by_email(request.email) == 2
      assert Ash.get!(Token, foreign_proof.jti, authorize?: false) == foreign_proof
    after
      :ok = Scenario.stop(scenario)
    end
  end

  def interrupted_acceptance do
    P805.with_fixture(fn ->
      {_request, _registration, recovery, bearer} = pending_recovery()
      scenario = Scenario.start()
      :ok = CutPoints.arm(scenario, "transaction.before_commit", :proof_acceptance, :terminate)

      try do
        {worker, monitor} =
          Scenario.spawn(scenario, :proof_acceptance, fn ->
            :ok = Sandbox.checkout(Repo, sandbox: false)

            Process.put(
              RegistrationSeam,
              {:observe,
               fn -> CutPoints.hit(scenario, "transaction.before_commit", :proof_acceptance) end}
            )

            try do
              Identity.submit_recovery_proof(bearer, operation())
            after
              Sandbox.checkin(Repo)
            end
          end)

        receive do
          {:DOWN, ^monitor, :process, ^worker, :proof_terminated} -> :ok
        after
          15_000 -> raise "P8-15 proof acceptance termination deadline"
        end

        assert CutPoints.verify_consumed(scenario) == :ok
        assert Ash.get!(Token, recovery.proof_jti, authorize?: false).purpose == "recovery"
        rolled_back = Ash.get!(RecoveryCase, recovery.id, authorize?: false)
        assert rolled_back.state == :proof_pending
        assert rolled_back.satisfied_assurance == 0
        assert Identity.submit_recovery_proof(bearer, operation()) == {:ok, :accepted}
      after
        :ok = Scenario.stop(scenario)
      end
    end)
  end

  def restart_proof(context \\ :p8_15) do
    P805.with_fixture(fn ->
      if context == :well183, do: Application.put_env(:new_you, :fp001_development_entry, true)

      {request, registration, recovery, bearer} =
        pending_recovery(&Identity.request_recovery(&1, "af", &2, context))

      operation_id = operation()
      password = "recovery survives a fresh BEAM"
      secret = Base.encode64(Application.fetch_env!(:new_you, :identity_token_signing_secret))

      assert restart_call(%{
               mode: "deliver",
               jti: recovery.proof_jti,
               destination: request.email,
               locale: "af",
               expected_digest: digest(bearer),
               signing_secret: secret,
               context: context
             }) == :delivery_matches

      assert restart_call(%{
               mode: "submit",
               proof: bearer,
               operation_id: operation(),
               signing_secret: secret,
               context: context
             }) == :accepted

      assert Ash.get!(RecoveryCase, recovery.id, authorize?: false).state == :additional_assurance

      assert restart_call(%{
               mode: "complete",
               proof: bearer,
               password: password,
               operation_id: operation_id,
               signing_secret: secret,
               context: context
             }) == :completed

      assert restart_call(%{
               mode: "replay",
               proof: bearer,
               password: if(context == :well183, do: password, else: "ignored"),
               operation_id: operation_id,
               signing_secret: secret,
               context: context
             }) == :already_completed

      assert Ash.get!(RecoveryCase, recovery.id, authorize?: false).state == :completed
      assert account_version(registration.account_id) == 2

      assert P805.scalar("SELECT count(*) FROM recovery_cases WHERE completion_id = $1", [
               Ecto.UUID.dump!(operation_id)
             ]) == 1

      :ok
    end)
  end

  defp pending_recovery(request_fixture \\ &Identity.request_recovery(&1, "af", &2)) do
    {request, registration} = account()
    request_id = operation()
    :ok = request_fixture.(request.email, request_id)
    [%RecoveryCase{operation_id: ^request_id} = recovery] = cases(registration.account_id)
    {:ok, bearer} = delivery(recovery, request.email)
    {request, registration, recovery, bearer}
  end

  defp account do
    request = P805.request()
    {:ok, registration} = Identity.register(request)
    {:ok, :verified} = Identity.verify_email(registration.verification_proof)
    {request, registration}
  end

  defp cases(account_id) do
    RecoveryCase
    |> Ash.Query.filter(account_id == ^account_id)
    |> Ash.read!(authorize?: false)
  end

  defp delivery(recovery, email) do
    {:ok, {:ok, bearer}} =
      Ash.transact([Account, Token], fn ->
        Identity.recovery_delivery(recovery.proof_jti, email, "af")
      end)

    {:ok, bearer}
  end

  defp password_reset_delivery(request, account_id) do
    request_id = operation()
    :ok = Identity.request_password_reset(request.email, "af", request_id)

    missing_operation? = is_nil(password_reset_proof(account_id, Ecto.UUID.generate()))
    assert missing_operation?
    assert %Token{} = proof = password_reset_proof(account_id, request_id)

    {:ok, {:ok, bearer}} =
      Ash.transact([Account, Token], fn ->
        Identity.password_reset_delivery(proof.jti, request.email, "af")
      end)

    bearer
  end

  defp password_reset_proof(account_id, request_id) do
    Token
    |> Ash.Query.filter(
      purpose == "password_reset" and reset_request_id == ^request_id and
        account_id == ^account_id
    )
    |> Ash.read_one!(authorize?: false)
  end

  defp operation do
    id = Ecto.UUID.generate()
    P805.track_operation(id)
    id
  end

  defp await_checkpoint(reference) do
    receive do
      {^reference, :before_commit, _worker, backend, _transaction} -> backend
    after
      15_000 -> raise "P8-15 transaction checkpoint deadline"
    end
  end

  defp receive_backend(reference, key) do
    receive do
      {^reference, ^key, backend} -> backend
    after
      15_000 -> raise "P8-15 contender connection deadline"
    end
  end

  defp assert_contention(contender, owner) do
    deadline = System.monotonic_time(:millisecond) + 15_000
    wait_contention(contender, owner, deadline)
  end

  defp wait_contention(contender, owner, deadline) do
    rows =
      Repo.query!(
        "SELECT a.virtualtransaction, b.virtualtransaction FROM pg_locks a JOIN pg_locks b ON b.pid = $1 AND b.locktype = 'virtualxid' WHERE a.pid = $2 AND a.locktype = 'virtualxid' AND $2 = ANY(pg_blocking_pids($1))",
        [contender, owner]
      ).rows

    case rows do
      [[contender_transaction, owner_transaction]] when contender != owner ->
        assert contender_transaction != owner_transaction

      _ ->
        if System.monotonic_time(:millisecond) < deadline do
          wait_contention(contender, owner, deadline)
        else
          raise "P8-15 PostgreSQL lock contention was not observed"
        end
    end
  end

  defp await_result(reference, name) do
    receive do
      {^reference, ^name, result} -> result
    after
      15_000 -> raise "P8-15 worker result deadline"
    end
  end

  defp await_normal(monitor) do
    receive do
      {:DOWN, ^monitor, :process, _worker, :normal} -> :ok
    after
      15_000 -> raise "P8-15 worker cleanup deadline"
    end
  end

  defp account_version(id), do: Ash.get!(Account, id, authorize?: false).credential_version

  defp account_version_by_email(email) do
    Account
    |> Ash.Query.filter(email == ^email)
    |> Ash.read_one!(authorize?: false)
    |> Map.fetch!(:credential_version)
  end

  defp recovery_account_email(id), do: Ash.get!(Account, id, authorize?: false).email
  defp safe_login({:ok, _}), do: :accepted
  defp safe_login(_), do: :denied
  defp safe_reset({:ok, :reset}), do: :reset
  defp safe_reset(_), do: :denied
  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :upper)

  def characterize_budget(scenario, replicate) do
    P805.with_fixture(fn ->
      fixtures = for _ <- 1..2, do: resumable_fixture()

      samples =
        fixtures
        |> Enum.with_index(1)
        |> Enum.map(fn {fixture, ordinal} -> budget_input(fixture, scenario, ordinal) end)

      diagnostic =
        run_restart(%{
          mode: "sample_budget",
          samples: samples,
          signing_secret:
            Base.encode64(Application.fetch_env!(:new_you, :identity_token_signing_secret))
        })

      assert diagnostic.status == :ok and diagnostic.cleanup == :confirmed
      assert diagnostic.marker == :requested
      assert length(diagnostic.budget_reports) == 2
      assert length(diagnostic.lease_reports) == 2

      Enum.zip([fixtures, diagnostic.budget_reports, diagnostic.lease_reports])
      |> Enum.with_index(1)
      |> Enum.each(fn {{fixture, timing, lease}, ordinal} ->
        {report_ordinal, timing} = Map.pop!(timing, :ordinal)
        assert report_ordinal == ordinal
        {transaction, timing} = Map.pop!(timing, :transaction)
        {success_count, timing} = Map.pop!(timing, :account_success_count)
        effect = budget_effect(fixture, scenario, transaction, lease)

        IO.puts(
          :stderr,
          "P815_BUDGET_SAMPLE " <>
            Jason.encode!(%{
              scenario: scenario,
              replicate: replicate,
              ordinal: ordinal,
              effect: effect,
              transaction: transaction,
              account_success_count: success_count,
              timing_us: timing,
              lease: lease
            })
        )

        assert scenario != :replay or effect == :replayed
        assert scenario != :contended or lease.closure == :checkout_deadline
      end)
    end)
  end

  defp budget_input(fixture, scenario, ordinal \\ 0) do
    case_id = fixture.recovery.id
    operation_id = fixture.recovery.operation_id
    RecoveryLease.verify_fixture!(case_id, operation_id)

    if scenario == :replay do
      :ok = Identity.request_recovery(fixture.request.email, "af", operation_id)
      assert_resumed_request(fixture)
    end

    email =
      case scenario do
        :unknown -> P805.request().email
        :malformed -> "malformed"
        _ -> fixture.request.email
      end

    %{
      ordinal: ordinal,
      email: email,
      case_id: case_id,
      operation_id: operation_id,
      locale: "af",
      budget: true,
      hold_lock: scenario == :contended,
      lease_probe: "observe"
    }
  end

  defp budget_effect(fixture, scenario, transaction, lease) do
    state = Ash.get!(RecoveryCase, fixture.recovery.id, authorize?: false).state

    case {scenario, state} do
      {:replay, :proof_pending} ->
        assert_resumed_request(fixture)
        NewYou.Proof.RecoveryBudget.replay_effect(transaction, lease)

      {:known, :proof_pending} ->
        assert_resumed_request(fixture)
        :issued

      # Neutral and contended requests must not commit, so their case keeps the
      # fixture state. Compare it with the fixture rather than a state name.
      {kind, _} when kind in [:unknown, :malformed, :contended] ->
        assert_resume_rolled_back(fixture)
        :unchanged

      {_, :held_manual_review} ->
        assert_resume_rolled_back(fixture)
        :unchanged
    end
  end

  @load_batch_size 8

  # Predeclared in docs/development/well-167-recovery-load-plan.md and amended by
  # Addendum A1. The child record is printed before any acceptance assertion, so
  # a failed criterion still leaves its observations on record.
  def characterize_load(scenario, concurrency, replicate) do
    P805.with_fixture(fn ->
      cold_fixture = resumable_fixture()
      cold = budget_input(cold_fixture, :known)
      load = load_scenario(scenario)

      diagnostic =
        run_restart(%{
          mode: "sample_load",
          cold: cold,
          hold: load.hold,
          batch: load.batch,
          concurrency: concurrency,
          after: load.after,
          signing_secret:
            Base.encode64(Application.fetch_env!(:new_you, :identity_token_signing_secret))
        })

      record = RecoveryLoad.record(scenario, concurrency, replicate, diagnostic)
      IO.puts(:stderr, "P815_LOAD_CHILD " <> Jason.encode!(record))
      assert_load_child(diagnostic, cold_fixture, load)
    end)
  end

  # Criteria 1 to 10 of the load plan and Addendum A1. Ordinals are 0 for the cold
  # request, 1 to 8 for the batch and 9 for the authorized follow-up.
  defp assert_load_child(diagnostic, cold_fixture, load) do
    assert diagnostic.status == :ok and diagnostic.cleanup == :confirmed
    assert diagnostic.marker == :requested

    batch = Enum.map(load.batch, & &1.ordinal)
    expected = Enum.to_list(0..(length(batch) + if(load.after, do: 1, else: 0)))
    tasks = Enum.filter(diagnostic.load_reports, &(&1.kind == :task))
    leases = diagnostic.lease_reports

    assert ordinals(diagnostic.budget_reports) == expected
    assert ordinals(leases) == expected
    assert ordinals(tasks) == batch
    assert Enum.all?(tasks, &(&1.status == :completed))

    Enum.each(leases, fn lease ->
      assert lease.closure == if(lease.ordinal in batch, do: load.closure, else: :none)
    end)

    assert Enum.all?(diagnostic.budget_reports, &(&1.public >= 500_000))
    assert_held(load, diagnostic.load_reports)
    assert_replays(load, diagnostic.budget_reports, leases)
    assert_follow_up(load, diagnostic.load_reports)

    Enum.each([cold_fixture | load.issued], &assert_resumed_request/1)
    Enum.each(load.unchanged, &assert_resume_rolled_back/1)
  end

  defp ordinals(reports), do: reports |> Enum.map(& &1.ordinal) |> Enum.sort()

  defp assert_held(%{hold: nil}, _reports), do: :ok

  defp assert_held(load, reports) do
    hold = Enum.find(reports, &(&1.kind == :hold))
    assert hold != nil

    reports
    |> Enum.filter(&(&1.kind == :task))
    |> Enum.each(fn task ->
      assert task.admitted_us >= 0 and task.admitted_us < hold.released_us
      assert_granted(load.grants, task.granted_us, hold.released_us)
    end)
  end

  defp assert_granted(:after_release, granted_us, released_us),
    do: assert(granted_us >= released_us)

  defp assert_granted(:never, granted_us, _released_us), do: assert(granted_us == -1)

  defp assert_replays(load, budgets, leases) do
    Enum.each(load.replays, fn ordinal ->
      budget = Enum.find(budgets, &(&1.ordinal == ordinal))
      lease = Enum.find(leases, &(&1.ordinal == ordinal))
      assert RecoveryBudget.replay_effect(budget.transaction, lease) == :replayed
    end)
  end

  defp assert_follow_up(%{after: nil}, _reports), do: :ok

  defp assert_follow_up(_load, reports) do
    state = Enum.find(reports, &(&1.kind == :state))
    assert %{settled: :settled, durable: :unchanged, tokens: 0, intents: 0} = state
  end

  # Batch and follow-up ordinals are assigned in input order. The contention
  # target keeps its case and operation so the child can verify it first.
  defp numbered(inputs) do
    inputs
    |> Enum.with_index(1)
    |> Enum.map(fn {input, ordinal} -> %{input | ordinal: ordinal} end)
  end

  defp hold(fixture, hold_ms) do
    %{
      case_id: fixture.recovery.id,
      operation_id: fixture.recovery.operation_id,
      account_id: fixture.recovery.account_id,
      hold_ms: hold_ms
    }
  end

  defp load_scenario(:independent) do
    fixtures = for _ <- 1..@load_batch_size, do: resumable_fixture()
    batch = numbered(Enum.map(fixtures, &budget_input(&1, :known)))

    %{
      hold: nil,
      after: nil,
      batch: batch,
      closure: :none,
      grants: nil,
      replays: [],
      issued: fixtures,
      unchanged: []
    }
  end

  defp load_scenario(:replay) do
    fixture = resumable_fixture()
    input = budget_input(fixture, :replay)
    batch = numbered(List.duplicate(input, @load_batch_size))

    %{
      hold: nil,
      after: nil,
      batch: batch,
      closure: :none,
      grants: nil,
      replays: Enum.map(batch, & &1.ordinal),
      issued: [fixture],
      unchanged: []
    }
  end

  defp load_scenario(:released) do
    fixture = resumable_fixture()
    input = budget_input(fixture, :known)

    %{
      hold: hold(fixture, 150),
      after: nil,
      batch: numbered(List.duplicate(input, @load_batch_size)),
      closure: :none,
      grants: :after_release,
      replays: [],
      issued: [fixture],
      unchanged: []
    }
  end

  defp load_scenario(:prolonged) do
    fixture = resumable_fixture()
    input = budget_input(fixture, :known)

    %{
      hold: hold(fixture, 1_000),
      after: %{input | ordinal: @load_batch_size + 1},
      batch: numbered(List.duplicate(input, @load_batch_size)),
      closure: :checkout_deadline,
      grants: :never,
      replays: [],
      issued: [fixture],
      unchanged: []
    }
  end

  defp load_scenario(:mixed) do
    known = for _ <- 1..2, do: resumable_fixture()
    replayed = for _ <- 1..2, do: resumable_fixture()
    [unknown_fixture, malformed_fixture] = for _ <- 1..2, do: resumable_fixture()

    batch =
      numbered(
        Enum.map(known, &budget_input(&1, :known)) ++
          Enum.map(replayed, &budget_input(&1, :replay)) ++
          List.duplicate(budget_input(unknown_fixture, :unknown), 2) ++
          List.duplicate(budget_input(malformed_fixture, :malformed), 2)
      )

    %{
      hold: nil,
      after: nil,
      batch: batch,
      closure: :none,
      grants: nil,
      # Ordinals 1 and 2 are known issuances, 3 and 4 replay, and 5 to 8 are
      # neutral requests that must roll back.
      replays: [3, 4],
      issued: known ++ replayed,
      unchanged: [unknown_fixture, malformed_fixture]
    }
  end

  def calibrate_recovery_lease(mode) when mode in [:observe, :baseline, :expiry, :checkin] do
    P805.with_fixture(fn ->
      fixture = resumable_fixture()
      recovery = fixture.recovery

      fields = %{
        mode: "request",
        lease_probe: Atom.to_string(mode),
        interrupt_request: true,
        skip_interrupt: true,
        expected_state: "proof_pending",
        email: fixture.request.email,
        case_id: recovery.id,
        operation_id: recovery.operation_id,
        locale: "af",
        signing_secret:
          Base.encode64(Application.fetch_env!(:new_you, :identity_token_signing_secret))
      }

      if mode == :baseline do
        assert_raise RuntimeError, "Recovery disposable job database verification failed", fn ->
          RecoveryLease.verify_fixture!(recovery.id, Ecto.UUID.generate())
        end
      end

      diagnostic = run_restart(fields)
      assert diagnostic.status == :ok and diagnostic.cleanup == :confirmed
      assert diagnostic.marker == :interruption_not_proven
      assert [report] = diagnostic.lease_reports
      IO.puts(:stderr, "P815_CALIBRATION #{mode} #{inspect(report)}")
      assert report.pre_callback_us >= 0 and report.callback_to_result_us >= 0

      expected = %{
        observe: :none,
        baseline: :unobserved,
        expiry: :checkout_deadline,
        checkin: :owner_checkin
      }

      assert report.closure == Map.fetch!(expected, mode)
      unchanged? = Ash.get!(Account, fixture.account.id, authorize?: false) == fixture.account
      assert unchanged?, "calibration changed the verified account"

      if mode in [:expiry, :checkin] do
        assert report.error == :lease_lost
        assert report.operation == :request_locked
        assert :checkpoint not in diagnostic.phases
        assert :transaction_error in diagnostic.phases
        assert_resume_rolled_back(fixture)
      else
        assert report.error == Map.fetch!(%{baseline: :unobserved, observe: :none}, mode)
        assert :transaction_returned in diagnostic.phases
        assert Ash.get!(RecoveryCase, recovery.id, authorize?: false).state == :proof_pending
        assert timeout_effect_counts(recovery) == {1, 1}
      end

      report
    end)
  end

  defp run_restart(fields) do
    if fields.mode == "request" and
         (RecoveryLease.hosted?() or Map.has_key?(fields, :lease_probe)) do
      RecoveryLease.verify_fixture!(fields.case_id, fields.operation_id)
    end

    NewYou.Proof.P815Port.run(
      System.find_executable("mix"),
      ["run", "test/proof/p8_15_restart.exs"],
      Jason.encode!(fields)
    )
  end

  defp restart_call(fields) do
    case run_restart(fields) do
      %{
        status: :interrupted,
        cleanup: :confirmed,
        started?: true,
        operation?: true,
        checkpoint?: true,
        phases: [
          :transaction_entered,
          :account_locked,
          :resume_verified_channel,
          :await_proof,
          :checkpoint
        ]
      } ->
        :request_interrupted

      %{status: :ok, cleanup: :confirmed, marker: marker, started?: true, operation?: true} =
          diagnostic ->
        if Map.get(fields, :interrupt_request, false),
          do: restart_failed(diagnostic),
          else: requested_marker(fields, marker, diagnostic)

      diagnostic ->
        restart_failed(diagnostic)
    end
  end

  defp requested_marker(%{rollback_request_once: true}, marker, diagnostic) do
    if diagnostic.rollback_checkpoint?, do: marker, else: restart_failed(diagnostic)
  end

  defp requested_marker(_fields, marker, _diagnostic), do: marker

  defp restart_failed(diagnostic) do
    # This map contains only P815Port's fixed markers/stages and bounded status
    # values. Retain it when the aggregate runner hides exception details.
    IO.puts(:stderr, "P815_RESTART_FAILED " <> inspect(diagnostic))
    {:restart_failed, diagnostic}
  end
end
