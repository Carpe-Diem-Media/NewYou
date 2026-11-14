defmodule NewYou.Proof.P818 do
  @moduledoc "P8-18 owner-boundary negatives using the shared P8-04 manifest assertions."

  alias Ecto.Adapters.SQL.Sandbox
  alias NewYou.{Audit, Communications, Identity, Privacy, Repo}
  alias NewYou.Audit.{EvidenceObligation, EvidenceRecord}
  alias NewYou.Communications.{DeliveryAttempt, MessageIntent}
  alias NewYou.Identity.{Account, RecoveryCase, Session}
  alias NewYou.Proof.P805

  require Ash.Query

  @doc "Execute one fixed P8-18 source-authority negative proof case."
  @spec run(String.t()) :: :ok
  def run("p818.provider_observation" = id),
    do: P805.with_fixture(fn -> provider_observation(id) end)

  def run("p818.stale_browser_authority" = id),
    do: P805.with_fixture(fn -> stale_browser_authority(id) end)

  def run("p818.audit_evidence_non_authority" = id),
    do: P805.with_fixture(fn -> audit_evidence_non_authority(id) end)

  def run("p818.executor_state_non_authority" = id),
    do: P805.with_fixture(fn -> executor_state_non_authority(id) end)

  def run("p818.signals_coordination_non_authority" = id),
    do: P805.with_fixture(fn -> signals_coordination_non_authority(id) end)

  def run("p818.analytics_projection" = id),
    do: P805.with_fixture(fn -> analytics_projection(id) end)

  def run("p818.arc_029_enforcement" = id), do: arc_029_enforcement(id)

  def run(_), do: raise(ArgumentError, "unknown P8-18 proof case")

  defp provider_observation(id) do
    request = P805.request()
    {:ok, registration} = Identity.register(request)

    verification_intent =
      MessageIntent
      |> Ash.Query.filter(
        source_operation_id == ^request.operation_id and role == :account_verification
      )
      |> Ash.read_one!(authorize?: false)

    previous_evidence_key = Process.get(:communications_proof_evidence_key, :missing)
    previous_provider = Process.get(:p810_provider, :missing)
    Process.put(:communications_proof_evidence_key, String.duplicate("k", 32))

    Process.put(:p810_provider, fn _, _ -> :accepted end)

    try do
      {:ok, :processed} = Communications.execute(verification_intent.id)

      [verification_attempt] =
        DeliveryAttempt
        |> Ash.Query.filter(message_intent_id == ^verification_intent.id)
        |> Ash.read!(authorize?: false)

      after_acceptance = Ash.get!(Account, registration.account_id, authorize?: false)
      P805.check(id, "provider_acceptance_did_not_verify", not after_acceptance.email_verified?)

      :ok = reconcile_delivered(verification_attempt, "p818-verification-delivered")
      account = Ash.get!(Account, registration.account_id, authorize?: false)
      P805.check(id, "authenticated_callback_did_not_verify", not account.email_verified?)

      P805.check(
        id,
        "provider_reference_did_not_create_session",
        Identity.authenticate_password(request.email, request.password) ==
          {:error, :authentication_unavailable} and session_count(registration.account_id) == 0
      )

      {:ok, :verified} = Identity.verify_email(registration.verification_proof)

      recovery_operation = Ecto.UUID.generate()
      P805.track_operation(recovery_operation)
      :ok = Identity.request_recovery(request.email, "af", recovery_operation)

      recovery_intent =
        MessageIntent
        |> Ash.Query.filter(
          source_operation_id == ^recovery_operation and role == :account_recovery
        )
        |> Ash.read_one!(authorize?: false)

      {:ok, :processed} = Communications.execute(recovery_intent.id)

      [recovery_attempt] =
        DeliveryAttempt
        |> Ash.Query.filter(message_intent_id == ^recovery_intent.id)
        |> Ash.read!(authorize?: false)

      :ok = reconcile_delivered(recovery_attempt, "p818-recovery-delivered")

      recovery =
        RecoveryCase
        |> Ash.Query.filter(account_id == ^registration.account_id)
        |> Ash.read_one!(authorize?: false)

      P805.check(id, "recovery_delivery_did_not_complete", recovery.state != :completed)

      P805.check(
        id,
        "recovery_delivery_did_not_apply_email",
        Identity.complete_recovery(
          recovery_attempt.id,
          "provider-observation-is-not-a-recovery-proof",
          recovery_operation
        ) == {:error, :recovery_unavailable} and
          match?({:ok, _}, Identity.authenticate_password(request.email, request.password))
      )

      prove_primary_email_callback_is_non_authoritative(id, recovery_attempt)
    after
      restore_process_value(:p810_provider, previous_provider)
      restore_process_value(:communications_proof_evidence_key, previous_evidence_key)
    end

    P805.check(
      id,
      "provider_evidence_key_restored",
      Process.get(:communications_proof_evidence_key, :missing) == previous_evidence_key
    )
  end

  defp prove_primary_email_callback_is_non_authoritative(id, recovery_attempt) do
    email_request = P805.request()
    {:ok, email_registration} = Identity.register(email_request)
    {:ok, :verified} = Identity.verify_email(email_registration.verification_proof)
    target = P805.request()
    email_change_operation = Ecto.UUID.generate()
    P805.track_operation(email_change_operation)

    {:ok, credentials} =
      Identity.authenticate_password(email_request.email, email_request.password)

    {:ok, :requested} =
      Identity.request_primary_email_change(
        credentials,
        target.email,
        "af",
        email_change_operation
      )

    {:ok, :proof_pending} =
      Identity.reauthenticate_primary_email_change(
        credentials,
        email_request.password,
        email_change_operation
      )

    email_change_intent =
      MessageIntent
      |> Ash.Query.filter(
        source_operation_id == ^email_change_operation and role == :email_change_confirmation
      )
      |> Ash.read_one!(authorize?: false)

    email_change_delivery = Communications.execute(email_change_intent.id)

    email_change_attempts =
      DeliveryAttempt
      |> Ash.Query.filter(message_intent_id == ^email_change_intent.id)
      |> Ash.read!(authorize?: false)

    held_email_change_intent =
      Ash.get!(MessageIntent, email_change_intent.id, authorize?: false)

    P805.check(
      id,
      "email_change_intent_held_without_attempt",
      email_change_delivery == {:ok, :held} and
        held_email_change_intent.dispatch_disposition == :held and email_change_attempts == []
    )

    unrelated_provider_reference = "p818-recovery-delivery-is-not-email-change-proof"
    :ok = reconcile_delivered(recovery_attempt, unrelated_provider_reference)
    callback_confirmation = Identity.confirm_primary_email_change(unrelated_provider_reference)
    callback_application = Identity.apply_primary_email_change(email_change_operation)

    unrelated_provider_intent =
      Ash.get!(MessageIntent, recovery_attempt.message_intent_id, authorize?: false)

    current_email_change_account =
      Ash.get!(Account, email_registration.account_id, authorize?: false)

    P805.check(
      id,
      "primary_email_callback_did_not_confirm_or_apply",
      callback_confirmation == {:error, :primary_email_change_unavailable} and
        callback_application == {:error, :primary_email_change_unavailable} and
        unrelated_provider_intent.role == :account_recovery and
        unrelated_provider_intent.source_operation_id != email_change_operation and
        current_email_change_account.email == email_request.email and
        current_email_change_account.primary_email_change_state == :new_address_pending
    )
  end

  defp stale_browser_authority(id) do
    request = P805.request()
    {:ok, registration} = Identity.register(request)
    {:ok, :verified} = Identity.verify_email(registration.verification_proof)
    {:ok, credentials} = Identity.authenticate_password(request.email, request.password)
    {:ok, %{account_id: account_id}} = Identity.authorize_session(credentials)

    browser_checks = NewYou.Proof.P805Browser.run_stale_session(request, "af")

    P805.check(
      id,
      "browser_stale_page_denied_on_reconnect",
      browser_checks["protected_page_loaded"] and browser_checks["logout_completed"] and
        browser_checks["reconnect_denied"] and browser_checks["stale_page_retained"]
    )

    :ok = Identity.revoke_session(credentials)

    original_backend = P805.scalar("SELECT pg_backend_pid()")

    {fresh_backend, fresh_authorization} =
      Task.async(fn ->
        Sandbox.unboxed_run(Repo, fn ->
          {P805.scalar("SELECT pg_backend_pid()"), Identity.authorize_session(credentials)}
        end)
      end)
      |> Task.await(10_000)

    P805.check(id, "owner_revocation_persisted", account_id == registration.account_id)

    P805.check(
      id,
      "stale_session_denied_after_reconnect",
      fresh_backend != original_backend and
        fresh_authorization == {:error, :authentication_unavailable}
    )

    magic_first_operation = Ecto.UUID.generate()
    magic_second_operation = Ecto.UUID.generate()
    P805.track_operation(magic_first_operation)
    P805.track_operation(magic_second_operation)
    :ok = Identity.request_magic_login(request.email, "af", magic_first_operation)

    [old_proof] =
      NewYou.Identity.Token
      |> Ash.Query.filter(account_id == ^registration.account_id and purpose == "magic_login")
      |> Ash.read!(authorize?: false)

    {:ok, {:ok, stale_magic_proof}} =
      Ash.transact([Account, NewYou.Identity.Token], fn ->
        Identity.magic_login_delivery(old_proof.jti, request.email, "af")
      end)

    :ok = Identity.request_magic_login(request.email, "af", magic_second_operation)

    P805.check(
      id,
      "superseded_proof_denied",
      Identity.authenticate_magic_link(stale_magic_proof) == {:error, :authentication_unavailable} and
        active_session_count(registration.account_id) == 0
    )
  end

  defp audit_evidence_non_authority(id) do
    request = P805.request()
    {:ok, registration} = Identity.register(request)

    [obligation] =
      EvidenceObligation
      |> Ash.Query.filter(source_operation_id == ^request.operation_id)
      |> Ash.read!(authorize?: false)

    privacy_operation = Ecto.UUID.generate()
    privacy_subject = Ecto.UUID.generate()
    P805.track_operation(privacy_operation)
    {:ok, :allowed} = Privacy.grant_p817_proof_purpose(privacy_subject, privacy_operation)

    intent_ids = Enum.map(P805.intents(request.operation_id), & &1.id)

    communications_before =
      DeliveryAttempt
      |> Ash.Query.filter(message_intent_id in ^intent_ids)
      |> Ash.read!(authorize?: false)
      |> Enum.map(&{&1.id, &1.provider_observation, &1.reconciliation, &1.active})

    {:ok, privacy_count_before} = Privacy.current_p817_proof_purpose_count()
    identity_before = identity_state(registration.account_id)

    assert_materialized = fn ->
      {:ok, _result} =
        Audit.materialize_registration_evidence(
          %{primary_key: %{id: obligation.id}},
          authorize?: false
        )

      {:ok, %EvidenceRecord{} = record} =
        Audit.get_evidence_record_by_obligation(obligation.id, authorize?: false)

      record
    end

    first = assert_materialized.()
    second = assert_materialized.()

    P805.check(id, "evidence_materialized_once", first.id == second.id)

    P805.check(
      id,
      "replay_reused_evidence",
      is_nil(Ash.Resource.Info.action(EvidenceRecord, :update))
    )

    P805.check(
      id,
      "identity_source_unchanged",
      identity_state(registration.account_id) == identity_before and
        is_nil(Ash.Resource.Info.action(EvidenceRecord, :destroy))
    )

    communications_after =
      DeliveryAttempt
      |> Ash.Query.filter(message_intent_id in ^intent_ids)
      |> Ash.read!(authorize?: false)
      |> Enum.map(&{&1.id, &1.provider_observation, &1.reconciliation, &1.active})

    {:ok, privacy_count_after} = Privacy.current_p817_proof_purpose_count()

    P805.check(
      id,
      "communications_and_privacy_source_unchanged",
      communications_after == communications_before and
        privacy_count_after == privacy_count_before
    )

    fabricated_operation = Ecto.UUID.generate()
    P805.track_operation(fabricated_operation)

    {:ok, fabricated_obligation} =
      Ash.create(
        EvidenceObligation,
        %{
          source_operation_id: fabricated_operation,
          source_occurred_at: DateTime.utc_now(),
          evidence_type: :identity_password_reset,
          actor_id: registration.account_id,
          target_id: registration.account_id,
          reason_code: :security_review,
          outcome: :succeeded
        },
        action: :establish_identity_security,
        domain: Audit,
        authorize?: false
      )

    {:ok, _fabricated_evidence} =
      Audit.materialize_registration_evidence(
        %{primary_key: %{id: fabricated_obligation.id}},
        authorize?: false
      )

    {:ok, fabricated_record} =
      Audit.get_evidence_record_by_obligation(fabricated_obligation.id, authorize?: false)

    {:ok, privacy_count_after_fabrication} = Privacy.current_p817_proof_purpose_count()

    P805.check(
      id,
      "fabricated_evidence_not_source_transition",
      match?(%EvidenceRecord{}, fabricated_record) and
        identity_state(registration.account_id) == identity_before and
        communications_after ==
          DeliveryAttempt
          |> Ash.Query.filter(message_intent_id in ^intent_ids)
          |> Ash.read!(authorize?: false)
          |> Enum.map(&{&1.id, &1.provider_observation, &1.reconciliation, &1.active}) and
        privacy_count_after_fabrication == privacy_count_before
    )

    P805.check(
      id,
      "evidence_has_no_repair_action",
      Enum.map(Ash.Resource.Info.actions(EvidenceRecord), & &1.name) --
        [
          :read,
          :materialize,
          :admit_reconciliation,
          :admit_recovery,
          :admit_security_hold_release
        ] == [] and
        is_nil(Ash.Resource.Info.action(EvidenceRecord, :update)) and
        is_nil(Ash.Resource.Info.action(EvidenceObligation, :destroy))
    )
  end

  defp executor_state_non_authority(id) do
    request = P805.request()
    {:ok, registration} = Identity.register(request)
    source_before = identity_state(registration.account_id)
    queue = String.replace_prefix(P805.analytics_projection_key(), "p817_test_", "p818_")
    verify_missing_executor_sources(id, queue)

    [obligation] =
      EvidenceObligation
      |> Ash.Query.filter(source_operation_id == ^request.operation_id)
      |> Ash.read!(authorize?: false)

    verify_audit_job_lifecycle(id, obligation, queue)
    stale_unchanged? = verify_stale_message_completion(id, queue)

    P805.check(
      id,
      "source_truth_unchanged",
      identity_state(registration.account_id) == source_before and
        stale_unchanged?
    )
  end

  defp verify_missing_executor_sources(id, queue) do
    unknown_id = Ecto.UUID.generate()

    obligation_worker =
      AshOban.Info.oban_trigger(EvidenceObligation, :registration_evidence).worker

    message_worker = AshOban.Info.oban_trigger(MessageIntent, :delivery).worker
    missing_obligation = enqueue_missing_source(obligation_worker, unknown_id, queue)
    missing_intent = enqueue_missing_source(message_worker, unknown_id, queue)

    %{failure: 2, success: 0} = Oban.drain_queue(queue: queue)

    P805.check(
      id,
      "missing_obligation_rejected",
      expected_job_failure?(missing_obligation, :evidence_materialisation_unavailable)
    )

    P805.check(
      id,
      "missing_intent_rejected",
      expected_job_failure?(missing_intent, :delivery_unavailable)
    )
  end

  defp verify_audit_job_lifecycle(id, obligation, queue) do
    job = AshOban.run_trigger(obligation, :registration_evidence, queue: queue)

    P805.check(
      id,
      "queued_job_did_not_fulfill_obligation",
      job.state == "available" and open_without_evidence?(obligation.id)
    )

    previous_hook = Process.get(NewYou.Proof.AuditSeam, :missing)
    attempt_key = {__MODULE__, :audit_attempt_started}
    Process.delete(attempt_key)

    Process.put(NewYou.Proof.AuditSeam, fn point ->
      if is_function(previous_hook, 1), do: previous_hook.(point)
      audit_retry_checkpoint(point, id, obligation.id, job.id, attempt_key)
    end)

    try do
      %{failure: 1, success: 0} = Oban.drain_queue(queue: queue)

      P805.check(
        id,
        "retry_preserved_open_obligation",
        expected_job_failure?(job, "p818_expected_audit_retry") and
          open_without_evidence?(obligation.id)
      )
    after
      restore_process_value(NewYou.Proof.AuditSeam, previous_hook)
      Process.delete(attempt_key)
    end

    :ok = Oban.retry_job(job)
    %{failure: 0, success: 1} = Oban.drain_queue(queue: queue, with_safety: false)
    completed = job_row(job.id)
    current_obligation = Ash.get!(EvidenceObligation, obligation.id, authorize?: false)
    {:ok, record} = Audit.get_evidence_record_by_obligation(obligation.id, authorize?: false)

    P805.check(
      id,
      "retry_used_same_obligation",
      completed.attempt == 2 and
        completed.args["primary_key"] == %{"id" => obligation.id}
    )

    P805.check(
      id,
      "completed_job_has_owner_evidence",
      completed.state == "completed" and
        current_obligation.state == :fulfilled and match?(%EvidenceRecord{}, record) and
        record.obligation_id == obligation.id
    )
  end

  defp audit_retry_checkpoint(:before_lock, id, obligation_id, job_id, attempt_key) do
    if not Process.get(attempt_key, false) do
      Process.put(attempt_key, true)

      P805.check(
        id,
        "executing_job_did_not_fulfill_obligation",
        job_row(job_id).state == "executing" and open_without_evidence?(obligation_id)
      )
    end
  end

  defp audit_retry_checkpoint(:after_record, _id, _obligation_id, _job_id, _attempt_key),
    do: raise("p818_expected_audit_retry")

  defp audit_retry_checkpoint(_point, _id, _obligation_id, _job_id, _attempt_key), do: :ok

  defp verify_stale_message_completion(id, queue) do
    stale_request = P805.request()
    {:ok, stale_registration} = Identity.register(stale_request)
    [stale_intent] = P805.intents(stale_request.operation_id)
    {:ok, :verified} = Identity.verify_email(stale_registration.verification_proof)
    stale_source_before = identity_state(stale_registration.account_id)
    stale_job = AshOban.run_trigger(stale_intent, :delivery, queue: queue)
    %{failure: 0, success: 1} = Oban.drain_queue(queue: queue, with_safety: false)
    closed_intent = Ash.get!(MessageIntent, stale_intent.id, authorize?: false)

    stale_attempts =
      DeliveryAttempt
      |> Ash.Query.filter(message_intent_id == ^stale_intent.id)
      |> Ash.read!(authorize?: false)

    P805.check(
      id,
      "stale_message_job_completed_without_delivery",
      job_row(stale_job.id).state == "completed" and
        closed_intent.dispatch_disposition == :closed and stale_attempts == []
    )

    identity_state(stale_registration.account_id) == stale_source_before
  end

  defp enqueue_missing_source(worker, source_id, queue) do
    %{"primary_key" => %{"id" => source_id}}
    |> worker.new(queue: queue)
    |> Oban.insert!()
  end

  defp job_row(id), do: Repo.get!(Oban.Job, id)

  defp expected_job_failure?(job, expected_reason) do
    current = job_row(job.id)
    marker = if is_atom(expected_reason), do: inspect(expected_reason), else: expected_reason

    current.state == "retryable" and current.attempt == 1 and
      Enum.any?(current.errors, &String.contains?(&1["error"], marker))
  end

  defp open_without_evidence?(obligation_id) do
    obligation = Ash.get!(EvidenceObligation, obligation_id, authorize?: false)
    {:ok, record} = Audit.get_evidence_record_by_obligation(obligation_id, authorize?: false)
    obligation.state == :open and is_nil(record)
  end

  defp signals_coordination_non_authority(id) do
    request = P805.request()
    {:ok, registration} = Identity.register(request)
    topic = "p818:identity-authority:" <> registration.account_id
    forged_proof = "p818-forged-proof:" <> Ecto.UUID.generate()
    prior_source = identity_state(registration.account_id)

    resources =
      Application.fetch_env!(:new_you, :ash_domains)
      |> Enum.flat_map(&Ash.Domain.Info.resources/1)

    P805.check(
      id,
      "no_registered_ash_signal_handlers",
      Enum.all?(resources, fn resource ->
        Ash.Resource.Info.signals_out(resource) == [] and
          Ash.Resource.Info.signal_listeners(resource) == []
      end)
    )

    try do
      :ok = Phoenix.PubSub.subscribe(NewYou.PubSub, topic)
      message = {:identity_verified, registration.account_id, forged_proof}
      :ok = Phoenix.PubSub.broadcast(NewYou.PubSub, topic, message)
      :ok = Phoenix.PubSub.broadcast(NewYou.PubSub, topic, message)

      received = receive_identity_signals(registration.account_id, forged_proof, 2)
      received_count = Enum.count(received, &(&1 == :received))

      owner_results =
        for :received <- received do
          Identity.verify_email(forged_proof)
        end

      account = Ash.get!(Account, registration.account_id, authorize?: false)

      P805.check(id, "pubsub_claim_received", received_count >= 1)
      P805.check(id, "pubsub_replay_received", received_count == 2)

      P805.check(
        id,
        "owner_interface_rejected_forged_signal",
        received_count == 2 and
          Enum.all?(owner_results, &(&1 == {:error, :verification_unavailable}))
      )

      P805.check(
        id,
        "source_verification_unchanged",
        not account.email_verified? and
          account.security_version == prior_source.security_version and
          session_count(registration.account_id) == prior_source.session_count
      )

      P805.check(
        id,
        "session_authority_absent",
        match?(
          {:error, :authentication_unavailable},
          Identity.authenticate_password(request.email, request.password)
        )
      )
    after
      Phoenix.PubSub.unsubscribe(NewYou.PubSub, topic)
    end
  end

  defp receive_identity_signals(account_id, proof, count) do
    Enum.map(1..count, fn _ ->
      receive do
        {:identity_verified, ^account_id, ^proof} -> :received
      after
        100 -> :missing
      end
    end)
  end

  defp analytics_projection(id) do
    key = {__MODULE__, :projection_writes}
    Process.put(key, [])

    try do
      context = build_analytics_projection()
      verify_current_projection(id, context.baseline)
      verify_projection_failure_preserves_source(id, context.baseline)
      verify_withdrawal_suppresses_projection(id, context)
      writes = Process.get(key, [])

      P805.check(
        id,
        "projection_writes_only_own_resource",
        writes != [] and
          Enum.all?(writes, &(&1 == "p817_privacy_projections")) and
          Ash.Domain.Info.resources(NewYou.Analytics) == [NewYou.Analytics.P817PrivacyProjection]
      )
    after
      Process.delete(key)
    end
  end

  # Query telemetry records only table names, never SQL parameters or source data.
  # This observes the current synchronous Ash rebuild. Static command checks cover
  # source direction separately; neither check is an arbitrary-Elixir sandbox.
  defp rebuild_projection do
    reference = make_ref()
    owner = self()
    event = (Repo.config()[:telemetry_prefix] || [:new_you, :repo]) ++ [:query]
    handler_id = {__MODULE__, reference}

    handler = fn _event, _measurements, metadata, parent ->
      if self() == parent, do: observe_projection_write(metadata.query, parent, reference)
    end

    :ok = :telemetry.attach(handler_id, event, handler, owner)

    try do
      NewYou.Analytics.rebuild_p817_privacy_projection()
    after
      :telemetry.detach(handler_id)
      writes = collect_projection_writes(reference, [])

      Process.put(
        {__MODULE__, :projection_writes},
        writes ++ Process.get({__MODULE__, :projection_writes}, [])
      )
    end
  end

  defp observe_projection_write(query, parent, reference) do
    case Regex.run(
           ~r/\A\s*(?:INSERT\s+INTO|UPDATE|DELETE\s+FROM|MERGE\s+INTO)\s+(?:"[^"]+"\.)?"?([a-z_][a-z_0-9]*)"?/i,
           query
         ) do
      [_, table] -> send(parent, {reference, :projection_write, table})
      _ -> :ok
    end
  end

  defp collect_projection_writes(reference, writes) do
    receive do
      {^reference, :projection_write, table} ->
        collect_projection_writes(reference, [table | writes])
    after
      0 -> writes
    end
  end

  defp build_analytics_projection do
    subject_id = Ecto.UUID.generate()
    operation_id = Ecto.UUID.generate()
    second_subject_id = Ecto.UUID.generate()
    second_operation_id = Ecto.UUID.generate()
    P805.track_operation(operation_id)
    P805.track_operation(second_operation_id)
    {:ok, baseline} = Privacy.current_p817_proof_purpose_snapshot()

    {:ok, :allowed} = Privacy.grant_p817_proof_purpose(subject_id, operation_id)
    {:ok, :allowed} = Privacy.grant_p817_proof_purpose(second_subject_id, second_operation_id)
    :ok = rebuild_projection()

    %{
      baseline: baseline,
      subject_id: subject_id,
      operation_id: operation_id,
      second_subject_id: second_subject_id,
      second_operation_id: second_operation_id
    }
  end

  defp verify_current_projection(id, baseline) do
    projection = only_projection()
    {:ok, current_snapshot} = Privacy.current_p817_proof_purpose_snapshot()

    fields =
      NewYou.Analytics.P817PrivacyProjection
      |> Ash.Resource.Info.attributes()
      |> Enum.map(& &1.name)

    P805.check(
      id,
      "current_privacy_read",
      projection.current_allowed_count == current_snapshot.current_allowed_count and
        current_snapshot.current_allowed_count == baseline.current_allowed_count + 2
    )

    P805.check(
      id,
      "projection_contains_aggregate_only",
      Enum.sort(fields) == [:current_allowed_count, :id, :privacy_revision, :projection_key]
    )

    projection_actions =
      NewYou.Analytics.P817PrivacyProjection
      |> Ash.Resource.Info.actions()
      |> Enum.map(&{&1.name, &1.type, &1.public?})
      |> Enum.sort()

    P805.check(
      id,
      "no_source_command_api",
      projection_actions == [{:read, :read, false}, {:rebuild, :create, false}] and
        boundary_call(load_ash_write_boundary(), :check_app, [File.cwd!()]) == []
    )

    P805.check(
      id,
      "privacy_authority_rows_cannot_be_deleted",
      is_nil(Ash.Resource.Info.action(NewYou.Privacy.PurposeAuthority, :destroy))
    )
  end

  defp verify_projection_failure_preserves_source(id, baseline) do
    projection_failure = injected_projection_failure()
    {:ok, source_after_projection_failure} = Privacy.current_p817_proof_purpose_snapshot()

    P805.check(
      id,
      "projection_failure_preserves_privacy_source",
      projection_failure == {:error, :analytics_projection_unavailable} and
        source_after_projection_failure.current_allowed_count ==
          baseline.current_allowed_count + 2 and
        only_projection().current_allowed_count == baseline.current_allowed_count + 2
    )
  end

  defp injected_projection_failure do
    hook_key = {NewYou.Analytics, :after_privacy_snapshot}
    previous_hook = Process.get(hook_key)
    Process.put(hook_key, fn _snapshot -> {:error, :injected_projection_failure} end)

    try do
      rebuild_projection()
    after
      if is_nil(previous_hook),
        do: Process.delete(hook_key),
        else: Process.put(hook_key, previous_hook)
    end
  end

  defp verify_withdrawal_suppresses_projection(id, context) do
    %{baseline: baseline} = context

    {:ok, :withdrawn} =
      Privacy.withdraw_p817_proof_purpose(context.second_subject_id, context.second_operation_id)

    :ok = rebuild_projection()
    {:ok, second_withdrawal_snapshot} = Privacy.current_p817_proof_purpose_snapshot()

    second_withdrawal_projection_current =
      only_projection().current_allowed_count == second_withdrawal_snapshot.current_allowed_count and
        second_withdrawal_snapshot.current_allowed_count == baseline.current_allowed_count + 1

    {:ok, :withdrawn} =
      Privacy.withdraw_p817_proof_purpose(context.subject_id, context.operation_id)

    :ok = rebuild_projection()
    {:ok, withdrawn_snapshot} = Privacy.current_p817_proof_purpose_snapshot()

    suppressed =
      second_withdrawal_projection_current and
        withdrawn_snapshot.current_allowed_count == baseline.current_allowed_count and
        only_projection().current_allowed_count == withdrawn_snapshot.current_allowed_count

    P805.check(id, "withdrawal_suppressed", suppressed)

    P805.check(
      id,
      "reordered_rebuild_remains_suppressed",
      Privacy.grant_p817_proof_purpose(context.subject_id, context.operation_id) ==
        {:error, :withdrawn} and
        Privacy.grant_p817_proof_purpose(context.second_subject_id, context.second_operation_id) ==
          {:error, :withdrawn} and
        rebuild_projection() == :ok and
        only_projection().current_allowed_count == baseline.current_allowed_count
    )
  end

  defp arc_029_enforcement(id) do
    root = File.cwd!()
    boundary = load_ash_write_boundary()
    violations = boundary_call(boundary, :check_app, [root])

    P805.check(id, "real_application_clean", violations == [])

    for {assertion, source, rule} <- [
          {"analytics_owner_command_rejected", "apply(NewYou.Identity, :register, [attrs])",
           :analytics_foreign_command},
          {"analytics_foreign_ash_write_rejected", "Ash.create(NewYou.Identity.Account, attrs)",
           :analytics_foreign_ash_write}
        ] do
      P805.check(
        id,
        assertion,
        boundary_call(boundary, :check_source, [
          "defmodule NewYou.Analytics do; def rebuild(attrs), do: " <> source <> "; end",
          "lib/new_you/analytics.ex"
        ])
        |> Enum.any?(&(&1.rule == rule))
      )
    end

    P805.check(
      id,
      "repo_write_rejected",
      rejected?(boundary, "def run, do: NewYou.Repo.insert!(value)")
    )

    P805.check(
      id,
      "raw_sql_write_rejected",
      rejected?(boundary, ~S|def run, do: NewYou.Repo.query!("UPDATE accounts SET state = 'x'")|)
    )

    P805.check(
      id,
      "ecto_multi_write_rejected",
      rejected?(boundary, "def run(multi), do: Ecto.Multi.insert(multi, :account, changeset)")
    )

    P805.check(id, "parallel_schema_rejected", rejected?(boundary, "use Ecto.Schema"))

    P805.check(
      id,
      "outer_ash_write_rejected",
      boundary_call(boundary, :check_source, [
        "defmodule Outer do; def run(value), do: Ash.create(value); end",
        "lib/new_you/workers/persist.ex"
      ])
      |> Enum.any?(&(&1.rule == :outer_layer_ash_write))
    )

    P805.check(
      id,
      "parse_error_rejected",
      boundary_call(boundary, :check_source, [
        "defmodule Broken do; def run(",
        "lib/new_you/broken.ex"
      ])
      |> Enum.any?(&(&1.rule == :parse_error))
    )

    P805.check(
      id,
      "narrow_exception_retained",
      boundary_call(boundary, :scope, ["lib/new_you/repo.ex"]) == :infrastructure and
        boundary_call(boundary, :scope, ["priv/repo/migrations/20261101_example.exs"]) ==
          :out_of_scope and
        boundary_call(boundary, :check_source, [
          "defmodule NewYou.Identity do; def create(attrs), do: Ash.create!(NewYou.Identity.Account, attrs); end",
          "lib/new_you/identity.ex"
        ]) == []
    )
  end

  defp rejected?(boundary, body) do
    source = "defmodule NewYou.Business do; " <> body <> "; end"

    boundary_call(boundary, :check_source, [source, "lib/new_you/business.ex"]) != []
  end

  defp boundary_call(module, function, arguments) do
    # credo:disable-for-next-line Credo.Check.Refactor.Apply
    apply(module, function, arguments)
  end

  defp load_ash_write_boundary do
    module = Module.concat([NewYou, Architecture, AshWriteBoundary])

    unless Code.ensure_loaded?(module) do
      Code.require_file(Path.expand("../../../tools/architecture/ash_write_boundary.ex", __DIR__))
    end

    module
  end

  defp reconcile_delivered(attempt, reference) do
    key =
      Process.get(:communications_proof_evidence_key) ||
        Application.fetch_env!(:new_you, :communications_proof_evidence_key)

    signature =
      :crypto.mac(:hmac, :sha256, key, attempt.id <> "|delivered|" <> reference)

    case Communications.reconcile(attempt.id, :delivered, reference, signature) do
      {:ok, :recorded} -> :ok
      _ -> :error
    end
  end

  defp session_count(account_id) do
    Session
    |> Ash.Query.filter(account_id == ^account_id)
    |> Ash.count!(authorize?: false)
  end

  defp active_session_count(account_id) do
    Session
    |> Ash.Query.filter(account_id == ^account_id and state == :active)
    |> Ash.count!(authorize?: false)
  end

  defp identity_state(account_id) do
    account = Ash.get!(Account, account_id, authorize?: false)

    %{
      email: account.email,
      email_verified?: account.email_verified?,
      security_version: account.security_version,
      session_count:
        Session
        |> Ash.Query.filter(account_id == ^account_id)
        |> Ash.count!(authorize?: false)
    }
  end

  defp only_projection do
    projection_key = P805.analytics_projection_key()

    [projection] =
      NewYou.Analytics.P817PrivacyProjection
      |> Ash.Query.filter(projection_key == ^projection_key)
      |> Ash.read!(authorize?: false)

    projection
  end

  defp restore_process_value(key, :missing), do: Process.delete(key)
  defp restore_process_value(key, value), do: Process.put(key, value)
end
