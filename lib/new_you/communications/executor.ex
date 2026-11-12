defmodule NewYou.Communications.Executor do
  @moduledoc """
  Internal Communications lifecycle implementation. The intent lock serializes
  admission, invocation fencing and evidence changes. Provider I/O runs only
  after admission and invocation-marker transactions have committed. A lost
  executor with a marker is uncertain, even when it died before the actual call.
  Recovery never uses timeouts as proof of non-submission.
  """
  require Ash.Query
  alias NewYou.Communications

  alias Communications.{
    DeliveryAttempt,
    DeliveryProvider,
    EnvelopeCrypto,
    MessageIntent,
    ProtectedEnvelope
  }

  @binding [
    :locale,
    :content_item_id,
    :content_version_id,
    :translation_version_id,
    :content_sha256,
    :render_schema,
    :render_provenance,
    :render_digest
  ]
  @safe [:rejected_before_submission, :bounced_or_failed]
  @observations [:accepted, :delivered, :rejected_before_submission, :bounced_or_failed, :unknown]

  @spec execute(String.t()) :: {:ok, atom()} | {:error, atom()}
  def execute(id) do
    with {:ok, id} <- Ecto.UUID.cast(id),
         false <- NewYou.Repo.in_transaction?(),
         {:ok, result} <- transaction(fn -> prepare(id) end) do
      execute_prepared(result)
    else
      _ -> {:error, :delivery_unavailable}
    end
  rescue
    _ -> {:error, :delivery_unavailable}
  end

  defp execute_prepared({:admitted, attempt}) do
    DeliveryProvider.checkpoint(:after_admission)

    case transaction(fn -> fence_invocation(attempt) end) do
      {:ok, {:invoke, payload}} -> invoke(attempt, payload)
      {:ok, status} when is_atom(status) -> {:ok, status}
      _ -> {:error, :delivery_unavailable}
    end
  end

  defp execute_prepared(result) when is_atom(result), do: {:ok, result}

  defp prepare(id) do
    with {:ok, %MessageIntent{} = intent} <- lock_intent(id),
         {:ok, attempts} <- attempts(id) do
      if intent.dispatch_disposition == :closed do
        {:ok, :closed}
      else
        prepare_current(intent, attempts)
      end
    else
      _ -> {:error, :delivery_unavailable}
    end
  end

  defp prepare_current(intent, attempts) do
    case source_eligibility(intent) do
      :ok ->
        prepare_eligible(intent, attempts)

      {:error, :source_invalid} ->
        close_source(intent)

      {:error, :capability_unavailable} ->
        with {:ok, _} <- disposition(intent, :held), do: {:ok, :held}
    end
  end

  defp source_eligibility(
         %{role: :account_verification, source_purpose: "email_verification"} = intent
       ),
       do:
         NewYou.Identity.DeliveryEligibility.verification(
           intent.source_reference,
           intent.destination
         )

  defp source_eligibility(%{role: :magic_login, source_purpose: "magic_login"} = intent) do
    case NewYou.Identity.magic_login_delivery(
           intent.source_reference,
           intent.destination,
           intent.locale
         ) do
      {:ok, bearer} when is_binary(bearer) and byte_size(bearer) > 0 -> :ok
      {:error, :capability_unavailable} -> {:error, :capability_unavailable}
      _ -> {:error, :source_invalid}
    end
  end

  defp source_eligibility(%{role: :password_reset, source_purpose: "password_reset"} = intent) do
    case NewYou.Identity.password_reset_delivery(
           intent.source_reference,
           intent.destination,
           intent.locale
         ) do
      {:ok, bearer} when is_binary(bearer) and byte_size(bearer) > 0 -> :ok
      {:error, :capability_unavailable} -> {:error, :capability_unavailable}
      _ -> {:error, :source_invalid}
    end
  end

  defp source_eligibility(%{role: role, content_item_id: nil})
       when role in [:account_recovery, :recovery_security_notice],
       do: {:error, :capability_unavailable}

  defp source_eligibility(%{role: :account_recovery, source_purpose: "recovery"} = intent),
    do:
      NewYou.Identity.DeliveryEligibility.recovery(
        intent.source_reference,
        intent.destination,
        intent.locale,
        intent.source_operation_id
      )

  defp source_eligibility(
         %{role: :recovery_security_notice, source_purpose: "recovery_completed"} = intent
       ),
       do:
         NewYou.Identity.DeliveryEligibility.recovery_notice(
           intent.source_reference,
           intent.locale,
           intent.source_operation_id
         )

  defp source_eligibility(_), do: {:error, :source_invalid}

  defp prepare_eligible(intent, attempts) do
    cond do
      Enum.any?(attempts, & &1.conflict?) -> {:ok, :waiting}
      active = Enum.find(attempts, & &1.active) -> recover(intent, active)
      true -> admit_guarded(intent)
    end
  end

  defp recover(intent, %{invocation_started_at: nil} = attempt) do
    with {:ok, _} <- record(attempt, %{admission: :closed_before_invocation, active: false}) do
      reopen_guarded(intent)
    end
  end

  defp recover(intent, %{provider_observation: :pending} = attempt) do
    with {:ok, _} <- record(attempt, %{provider_observation: :unknown}),
         {:ok, _} <- disposition(intent, :reconciliation_required) do
      {:ok, :waiting}
    end
  end

  defp recover(_intent, _attempt), do: {:ok, :waiting}

  defp admit_guarded(intent) do
    with {:ok, _payload} <- delivery_payload(intent),
         {:ok, attempt} <-
           Ash.create(
             DeliveryAttempt,
             Map.merge(Map.take(intent, @binding), %{message_intent_id: intent.id}),
             action: :admit,
             authorize?: false
           ),
         {:ok, _} <- disposition(intent, :reconciliation_required) do
      {:ok, {:admitted, attempt}}
    else
      {:error, :source_invalid} -> close_source(intent)
      _ -> with {:ok, _} <- disposition(intent, :held), do: {:ok, :held}
    end
  end

  defp delivery_payload(intent) do
    case {intent.role, intent.source_purpose} do
      {:account_verification, "email_verification"} -> verification_payload(intent)
      {:magic_login, "magic_login"} -> magic_login_payload(intent)
      {:password_reset, "password_reset"} -> password_reset_payload(intent)
      {:account_recovery, "recovery"} -> recovery_payload(intent)
      {:recovery_security_notice, "recovery_completed"} -> recovery_payload(intent)
      _ -> {:error, :source_invalid}
    end
  end

  defp recovery_payload(intent) do
    with :ok <- source_eligibility(intent),
         {:ok, bytes} <- NewYou.Content.RecoveryMessage.eligible(intent),
         true <- valid_recovery_render?(intent),
         {:ok, replacement} <- recovery_replacement(intent),
         true <- DeliveryProvider.available?() do
      token =
        if intent.role == :account_recovery,
          do: "{{account_recovery_link}}",
          else: "{{support_contact}}"

      body =
        bytes
        |> String.replace("{{platform_name}}", intent.platform_name)
        |> String.replace(token, replacement)

      {:ok, %NewYou.Communications.DeliveryPayload{destination: intent.destination, body: body}}
    else
      {:error, :source_invalid} -> {:error, :source_invalid}
      _ -> {:error, :delivery_prerequisite_unavailable}
    end
  end

  defp recovery_replacement(%{role: :account_recovery} = intent) do
    with {:ok, bearer} <-
           NewYou.Identity.recovery_delivery(
             intent.source_reference,
             intent.destination,
             intent.locale
           ) do
      {:ok,
       "https://proof.invalid/recovery/confirm?locale=" <>
         intent.locale <> "&proof=" <> URI.encode_www_form(bearer)}
    end
  end

  defp recovery_replacement(%{role: :recovery_security_notice} = intent) do
    with {:ok, contact} <- NewYou.Content.RecoveryMessage.support_contact(),
         true <- contact == intent.support_contact do
      {:ok, contact}
    else
      _ -> {:error, :delivery_prerequisite_unavailable}
    end
  end

  defp valid_recovery_render?(intent) do
    intent.render_provenance == "application_platform_name" and
      intent.render_digest ==
        Communications.recovery_render_digest(
          intent.render_schema,
          intent.platform_name,
          intent.support_contact
        )
  end

  defp verification_payload(intent) do
    with :ok <- source_eligibility(intent),
         {:ok, bytes} <- NewYou.Content.VerificationMessage.eligible(intent),
         true <- valid_render?(intent),
         {:ok, bearer} <- capability(intent),
         true <- DeliveryProvider.available?() do
      body =
        bytes
        |> String.replace("{{platform_name}}", intent.platform_name)
        |> String.replace(
          "{{verification_link}}",
          "https://proof.invalid/verification/confirm?locale=" <>
            intent.locale <> "&proof=" <> URI.encode_www_form(bearer)
        )

      {:ok, %NewYou.Communications.DeliveryPayload{destination: intent.destination, body: body}}
    else
      {:error, :source_invalid} -> {:error, :source_invalid}
      _ -> {:error, :delivery_prerequisite_unavailable}
    end
  end

  defp magic_login_payload(intent) do
    with :ok <- source_eligibility(intent),
         {:ok, bytes} <- NewYou.Content.MagicLoginMessage.eligible(intent),
         true <- valid_magic_login_render?(intent),
         {:ok, bearer} <-
           NewYou.Identity.magic_login_delivery(
             intent.source_reference,
             intent.destination,
             intent.locale
           ),
         true <- DeliveryProvider.available?() do
      link =
        "https://proof.invalid/login/magic/confirm?locale=" <>
          intent.locale <> "&proof=" <> URI.encode_www_form(bearer)

      body =
        bytes
        |> String.replace("{{platform_name}}", intent.platform_name)
        |> String.replace("{{magic_login_link}}", link)

      {:ok, %NewYou.Communications.DeliveryPayload{destination: intent.destination, body: body}}
    else
      {:error, :source_invalid} -> {:error, :source_invalid}
      _ -> {:error, :delivery_prerequisite_unavailable}
    end
  end

  defp password_reset_payload(intent) do
    with :ok <- source_eligibility(intent),
         {:ok, bytes} <- NewYou.Content.PasswordResetMessage.eligible(intent),
         true <- valid_password_reset_render?(intent),
         {:ok, bearer} <-
           NewYou.Identity.password_reset_delivery(
             intent.source_reference,
             intent.destination,
             intent.locale
           ),
         true <- DeliveryProvider.available?() do
      link =
        "https://proof.invalid/password/reset/confirm?locale=" <>
          intent.locale <> "&proof=" <> URI.encode_www_form(bearer)

      body =
        bytes
        |> String.replace("{{platform_name}}", intent.platform_name)
        |> String.replace("{{password_reset_link}}", link)

      {:ok, %NewYou.Communications.DeliveryPayload{destination: intent.destination, body: body}}
    else
      {:error, :source_invalid} -> {:error, :source_invalid}
      _ -> {:error, :delivery_prerequisite_unavailable}
    end
  end

  defp valid_render?(intent) do
    digest =
      :crypto.hash(
        :sha256,
        :erlang.term_to_binary({"verification-v1", intent.platform_name}, [:deterministic])
      )
      |> Base.encode16(case: :lower)

    intent.render_schema == "verification-v1" and
      intent.render_provenance == "application_platform_name" and intent.render_digest == digest
  end

  defp valid_magic_login_render?(intent) do
    digest =
      :crypto.hash(
        :sha256,
        :erlang.term_to_binary({"magic-login-v1", intent.platform_name}, [:deterministic])
      )
      |> Base.encode16(case: :lower)

    intent.render_schema == "magic-login-v1" and
      intent.render_provenance == "application_platform_name" and intent.render_digest == digest
  end

  defp valid_password_reset_render?(intent) do
    digest =
      :crypto.hash(
        :sha256,
        :erlang.term_to_binary({"password-reset-v1", intent.platform_name}, [:deterministic])
      )
      |> Base.encode16(case: :lower)

    intent.render_schema == "password-reset-v1" and
      intent.render_provenance == "application_platform_name" and intent.render_digest == digest
  end

  defp capability(intent) do
    with {:ok, %ProtectedEnvelope{} = envelope} <-
           Ash.get(ProtectedEnvelope, intent.id, authorize?: false),
         true <-
           envelope.source_reference == intent.source_reference and
             envelope.purpose == intent.source_purpose,
         %{keys: keys} <- Application.get_env(:new_you, :communications_keyring),
         {:ok, bearer} <-
           EnvelopeCrypto.decrypt_versioned(
             keys,
             envelope.key_version,
             {intent.id, intent.source_reference, intent.source_purpose},
             envelope
           ) do
      {:ok, bearer}
    else
      _ -> {:error, :capability_unavailable}
    end
  end

  defp fence_invocation(attempt) do
    with {:ok, intent} <- lock_intent(attempt.message_intent_id),
         {:ok, current} <- Ash.get(DeliveryAttempt, attempt.id, authorize?: false) do
      if current.active and current.invocation_started_at == nil and not current.conflict? and
           intent.dispatch_disposition == :reconciliation_required and
           intent.terminal_reason != "conflicting_provider_evidence" do
        validate_invocation(intent, current)
      else
        {:ok, :waiting}
      end
    end
  end

  defp validate_invocation(intent, attempt) do
    with true <- Map.take(intent, @binding) == Map.take(attempt, @binding),
         {:ok, payload} <- delivery_payload(intent),
         {:ok, _} <- record(attempt, %{invocation_started_at: DateTime.utc_now()}) do
      {:ok, {:invoke, payload}}
    else
      {:error, :source_invalid} ->
        with {:ok, _} <- record(attempt, %{admission: :closed_before_invocation, active: false}),
             do: close_source(intent)

      _ ->
        with {:ok, _} <- record(attempt, %{admission: :closed_before_invocation, active: false}),
             {:ok, _} <- disposition(intent, :held),
             do: {:ok, :held}
    end
  end

  defp invoke(attempt, payload) do
    # No outer transaction may cause Ash.transact to be only a savepoint.
    false = NewYou.Repo.in_transaction?()
    DeliveryProvider.checkpoint(:before_invoke)
    outcome = provider_result(attempt, payload)
    DeliveryProvider.checkpoint(:after_invoke)

    with {:ok, :recorded} <- observe(attempt.id, outcome, "synchronous", true),
         do: {:ok, :processed}
  end

  defp provider_result(attempt, payload) do
    case DeliveryProvider.invoke(attempt, payload) do
      result when result in @observations -> result
      _ -> :unknown
    end
  rescue
    _ -> :unknown
  catch
    _, _ -> :unknown
  end

  @spec reconcile(String.t(), atom(), String.t(), binary()) :: {:ok, :recorded} | {:error, atom()}
  def reconcile(id, outcome, reference, signature) do
    with {:ok, id} <- Ecto.UUID.cast(id),
         true <- outcome in (@observations ++ [:confirmed_no_operation]),
         true <- is_binary(reference) and Regex.match?(~r/\A[a-zA-Z0-9_-]{1,64}\z/, reference),
         true <- DeliveryProvider.authenticated?(id, outcome, reference, signature) do
      observe(id, outcome, reference, true)
    else
      _ -> {:error, :unauthenticated}
    end
  rescue
    _ -> {:error, :unauthenticated}
  end

  defp observe(id, outcome, reference, authenticated?) do
    case Ash.get(DeliveryAttempt, id, authorize?: false) do
      {:ok, %DeliveryAttempt{} = locator} ->
        transaction(fn -> observe_locked(locator, outcome, reference, authenticated?) end)

      _ ->
        {:error, :delivery_unavailable}
    end
  end

  defp observe_locked(locator, outcome, reference, authenticated?) do
    with {:ok, intent} <- lock_intent(locator.message_intent_id),
         {:ok, attempt} <- Ash.get(DeliveryAttempt, locator.id, authorize?: false) do
      apply_evidence(intent, attempt, outcome, reference, authenticated?)
    end
  end

  defp apply_evidence(intent, attempt, outcome, reference, true) do
    fingerprint =
      :crypto.hash(:sha256, reference <> "|" <> to_string(outcome)) |> Base.encode16(case: :lower)

    cond do
      fingerprint in attempt.evidence_refs -> {:ok, :recorded}
      length(attempt.evidence_refs) >= 64 -> conflict(intent, attempt)
      attempt.admission == :closed_before_invocation -> conflict(intent, attempt)
      attempt.invocation_started_at == nil -> conflict(intent, attempt)
      compatible?(attempt, outcome) -> update_evidence(intent, attempt, outcome, fingerprint)
      stale?(attempt, outcome) -> {:ok, :recorded}
      true -> conflict(intent, attempt)
    end
  end

  defp compatible?(%{reconciliation: :confirmed_no_operation}, :confirmed_no_operation), do: true

  defp compatible?(attempt, :confirmed_no_operation),
    do: attempt.provider_observation in [:unknown, :pending] and attempt.reconciliation == :none

  defp compatible?(%{reconciliation: :confirmed_no_operation}, _), do: false

  defp compatible?(%{provider_observation: existing}, outcome) do
    existing == outcome or existing in [:pending, :unknown] or
      (existing == :accepted and outcome in [:delivered, :bounced_or_failed])
  end

  defp stale?(%{reconciliation: :none, provider_observation: existing}, outcome),
    do:
      existing in [:accepted, :delivered, :bounced_or_failed] and outcome in [:accepted, :unknown] and
        existing != outcome

  defp stale?(_, _), do: false

  defp update_evidence(intent, attempt, outcome, fingerprint) do
    attrs =
      if outcome == :confirmed_no_operation,
        do: %{reconciliation: outcome},
        else: %{provider_observation: outcome}

    active? = outcome not in (@safe ++ [:delivered, :confirmed_no_operation])

    attrs =
      Map.merge(attrs, %{
        active: active?,
        observed_at: DateTime.utc_now(),
        evidence_refs: [fingerprint | attempt.evidence_refs]
      })

    with {:ok, _} <- record(attempt, attrs) do
      # The parent lock and partial unique index identify this sole active
      # admission. Historical repeats retain evidence without changing the
      # disposition of a newer operation or a held/closed obligation.
      if attempt.active, do: apply_disposition(intent, outcome), else: {:ok, :recorded}
    end
  end

  defp apply_disposition(%{terminal_reason: "conflicting_provider_evidence"}, _),
    do: {:ok, :recorded}

  defp apply_disposition(%{terminal_reason: "source_invalid"}, _), do: {:ok, :recorded}

  defp apply_disposition(intent, :delivered) do
    with {:ok, _} <- disposition(intent, :closed, "delivery_observed"),
         :ok <- clear_capability(intent),
         do: {:ok, :recorded}
  end

  defp apply_disposition(%{dispatch_disposition: :closed}, outcome)
       when outcome in @safe or outcome == :confirmed_no_operation,
       do: {:ok, :recorded}

  defp apply_disposition(intent, outcome)
       when outcome in @safe or outcome == :confirmed_no_operation do
    with {:ok, _status} <- reopen_guarded(intent), do: {:ok, :recorded}
  end

  defp apply_disposition(intent, _) do
    with {:ok, _} <- disposition(intent, :reconciliation_required), do: {:ok, :recorded}
  end

  # A terminal admission or safe provider outcome never grants current send
  # eligibility. Both paths re-read the same owner guards under the intent lock.
  defp reopen_guarded(intent) do
    case delivery_payload(intent) do
      {:ok, _payload} ->
        with {:ok, _} <- disposition(intent, :open), do: {:ok, :waiting}

      {:error, :source_invalid} ->
        close_source(intent)

      _ ->
        with {:ok, _} <- disposition(intent, :held), do: {:ok, :held}
    end
  end

  defp conflict(intent, attempt) do
    with {:ok, _} <- record(attempt, %{conflict?: true}) do
      flag_current_conflict(intent, attempt)
    end
  end

  defp flag_current_conflict(
         %{dispatch_disposition: :closed, terminal_reason: "delivery_observed"} = intent,
         attempt
       ),
       do: flag_conflict(intent, attempt)

  defp flag_current_conflict(%{dispatch_disposition: :closed}, _attempt),
    do: {:ok, :recorded}

  defp flag_current_conflict(intent, attempt) do
    case source_eligibility(intent) do
      :ok ->
        flag_conflict(intent, attempt)

      {:error, :capability_unavailable} ->
        flag_conflict(intent, attempt)

      {:error, :source_invalid} ->
        with {:ok, :source_invalid} <- close_source(intent), do: {:ok, :recorded}
    end
  end

  defp flag_conflict(intent, attempt) do
    with {:ok, _} <-
           Ash.update(intent, %{attempt_id: attempt.id},
             action: :flag_evidence_conflict,
             authorize?: false
           ),
         do: {:ok, :recorded}
  end

  defp close_source(intent) do
    with {:ok, _} <- disposition(intent, :closed, "source_invalid"),
         :ok <- clear_capability(intent),
         do: {:ok, :source_invalid}
  end

  defp clear_capability(intent) do
    case Ash.get(ProtectedEnvelope, intent.id, authorize?: false, not_found_error?: false) do
      {:ok, nil} -> :ok
      {:ok, envelope} -> Ash.destroy(envelope, action: :clear, authorize?: false)
      _ -> {:error, :delivery_unavailable}
    end
  end

  defp disposition(intent, state, reason \\ nil),
    do:
      Ash.update(intent, %{terminal_reason: reason},
        action:
          Map.fetch!(
            %{
              open: :resume,
              held: :hold,
              reconciliation_required: :require_reconciliation,
              closed: :close
            },
            state
          ),
        authorize?: false
      )

  defp record(attempt, attrs), do: Ash.update(attempt, attrs, action: :record, authorize?: false)

  defp attempts(id),
    do: Ash.read(Ash.Query.filter(DeliveryAttempt, message_intent_id == ^id), authorize?: false)

  defp lock_intent(id) do
    DeliveryProvider.checkpoint(:before_lock)

    result =
      MessageIntent
      |> Ash.Query.filter(id == ^id)
      |> Ash.Query.lock(:for_update)
      |> Ash.read_one(authorize?: false)

    DeliveryProvider.checkpoint(:after_lock)
    result
  end

  defp transaction(fun) do
    case Ash.transact(
           [
             MessageIntent,
             DeliveryAttempt,
             ProtectedEnvelope,
             NewYou.Identity.Account,
             NewYou.Identity.Token
           ],
           fun
         ) do
      {:ok, {:ok, result}} -> {:ok, result}
      {:ok, {:error, _}} -> {:error, :delivery_unavailable}
      other -> other
    end
  end
end
