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

      :ok = reconcile_delivered(verification_attempt, "p818-verification-delivered")

      account = Ash.get!(Account, registration.account_id, authorize?: false)

      P805.check(id, "provider_acceptance_did_not_verify", not account.email_verified?)

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
    unknown_id = Ecto.UUID.generate()

    obligation_worker =
      AshOban.Info.oban_trigger(EvidenceObligation, :registration_evidence).worker

    message_worker = AshOban.Info.oban_trigger(MessageIntent, :delivery).worker

    job_states = [{:available, 1}, {:executing, 2}, {:completed, 3}, {:retryable, 5}]

    job_results =
      for {state, attempt} <- job_states do
        {
          perform_unknown_job(obligation_worker, unknown_id, state, attempt, 10),
          perform_unknown_job(message_worker, unknown_id, state, attempt, 5)
        }
      end

    obligation_missing =
      EvidenceObligation
      |> Ash.Query.filter(id == ^unknown_id)
      |> Ash.read_one!(authorize?: false)
      |> is_nil()

    P805.check(
      id,
      "missing_obligation_rejected",
      obligation_missing
    )

    intent_missing =
      MessageIntent
      |> Ash.Query.filter(id == ^unknown_id)
      |> Ash.read_one!(authorize?: false)
      |> is_nil()

    P805.check(id, "missing_intent_rejected", intent_missing)

    P805.check(
      id,
      "all_job_states_rejected_missing_sources",
      obligation_missing and intent_missing and
        Enum.all?(job_results, fn {obligation_result, intent_result} ->
          obligation_result == :source_unavailable and intent_result == :source_unavailable
        end)
    )

    P805.check(
      id,
      "source_truth_unchanged",
      identity_state(registration.account_id).email_verified? == false and
        match?(
          {:error, :authentication_unavailable},
          Identity.authenticate_password(request.email, request.password)
        )
    )
  end

  defp signals_coordination_non_authority(id) do
    request = P805.request()
    {:ok, registration} = Identity.register(request)
    topic = "p818:identity-authority:" <> registration.account_id
    forged_proof = "p818-forged-proof:" <> Ecto.UUID.generate()
    prior_source = identity_state(registration.account_id)

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

      P805.check(id, "signal_received", received_count >= 1)
      P805.check(id, "signal_replay_received", received_count == 2)

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
    context = build_analytics_projection()
    verify_current_projection(id, context.baseline)
    verify_projection_failure_preserves_source(id, context.baseline)
    verify_withdrawal_suppresses_projection(id, context)
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
    :ok = NewYou.Analytics.rebuild_p817_privacy_projection()

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
      not Enum.any?(fields, &(&1 in [:subject_id, :source_operation_id, :account_id]))
    )

    P805.check(
      id,
      "projection_writes_only_own_resource",
      Ash.Domain.Info.resources(NewYou.Analytics) == [NewYou.Analytics.P817PrivacyProjection]
    )

    projection_actions =
      NewYou.Analytics.P817PrivacyProjection
      |> Ash.Resource.Info.actions()
      |> Enum.map(&{&1.name, &1.type, &1.public?})
      |> Enum.sort()

    P805.check(
      id,
      "no_source_command_api",
      projection_actions == [{:read, :read, false}, {:rebuild, :create, false}]
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
      NewYou.Analytics.rebuild_p817_privacy_projection()
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

    :ok = NewYou.Analytics.rebuild_p817_privacy_projection()
    {:ok, second_withdrawal_snapshot} = Privacy.current_p817_proof_purpose_snapshot()

    second_withdrawal_projection_current =
      only_projection().current_allowed_count == second_withdrawal_snapshot.current_allowed_count and
        second_withdrawal_snapshot.current_allowed_count == baseline.current_allowed_count + 1

    {:ok, :withdrawn} =
      Privacy.withdraw_p817_proof_purpose(context.subject_id, context.operation_id)

    :ok = NewYou.Analytics.rebuild_p817_privacy_projection()
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
        NewYou.Analytics.rebuild_p817_privacy_projection() == :ok and
        only_projection().current_allowed_count == baseline.current_allowed_count
    )
  end

  defp arc_029_enforcement(id) do
    root = File.cwd!()
    boundary = load_ash_write_boundary()
    violations = boundary_call(boundary, :check_app, [root])

    P805.check(id, "real_application_clean", violations == [])

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

  defp perform_unknown_job(worker, id, state, attempt, max_attempts) do
    worker.perform(%Oban.Job{
      args: %{"primary_key" => %{"id" => id}},
      attempt: attempt,
      max_attempts: max_attempts,
      state: state
    })
  rescue
    _error in Ash.Error.Unknown -> :source_unavailable
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
