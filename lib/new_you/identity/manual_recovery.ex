defmodule NewYou.Identity.ManualRecovery do
  @moduledoc false

  alias NewYou.Audit
  alias NewYou.Identity.{PrivilegedAccess, Recovery, RecoveryCase, Token}

  @enabled Mix.env() in [:dev, :test] and
             Application.compile_env(:new_you, :verification_development_fixtures, false)
  @capability_approve :approve_manual_recovery
  @capability_complete :complete_manual_recovery

  defmacrop checkpoint do
    if Mix.env() == :test do
      quote do: NewYou.Proof.RegistrationSeam.checkpoint()
    else
      quote do: :ok
    end
  end

  def approve(request) when is_map(request) do
    with true <- @enabled,
         {:ok, input} <- parse(request),
         {:ok, snapshot} <- recovery(input.case_id),
         {:ok, preflight} <-
           Recovery.transaction(fn -> approval_authority(input, snapshot.account_id) end),
         {:ok, admission} <- Audit.admit_recovery(preflight.envelope) do
      case source_approval(input, snapshot.account_id, preflight, admission) do
        {:ok, result} ->
          {:ok, result}

        _ ->
          record_failure(
            input,
            snapshot.account_id,
            preflight,
            admission,
            :identity_recovery_review
          )

          unavailable()
      end
    else
      _ -> unavailable()
    end
  rescue
    _ -> unavailable()
  end

  def approve(_), do: unavailable()

  defp source_approval(input, target_id, preflight, admission) do
    Recovery.transaction(fn -> approve_locked(input, target_id, preflight, admission) end)
  rescue
    _ -> unavailable()
  end

  def complete(request) when is_map(request) do
    with true <- @enabled,
         {:ok, input} <- parse(request),
         true <- is_binary(request[:password]) and byte_size(request.password) in 1..1024,
         {:ok, snapshot} <- recovery(input.case_id),
         {:ok, preflight} <- Recovery.transaction(fn -> completion_authority(input, snapshot) end),
         {:ok, admission} <- Audit.admit_recovery(preflight.envelope),
         result <-
           source_completion(input, request.password, snapshot.account_id, preflight, admission) do
      case result do
        {:ok, value} when value in [:completed, :already_completed] ->
          {:ok, value}

        _ ->
          record_failure(
            input,
            snapshot.account_id,
            preflight,
            admission,
            :identity_recovery_completed
          )

          unavailable()
      end
    else
      _ -> unavailable()
    end
  rescue
    _ -> unavailable()
  end

  def complete(_), do: unavailable()

  defp source_completion(input, password, target_id, preflight, admission) do
    Recovery.transaction(fn ->
      complete_locked(input, password, target_id, preflight, admission)
    end)
  rescue
    _ -> unavailable()
  end

  defp approval_authority(input, target_id) do
    with {:ok, authority} <-
           PrivilegedAccess.authorize_locked(
             input.credentials,
             input.grant_id,
             target_id,
             @capability_approve
           ),
         {:ok, recovery} <- Recovery.lock_case(input.case_id),
         account <- authority.target,
         :ok <- valid_approval_case(recovery, account, input),
         :ok <- eligible_approval(recovery, account, authority) do
      {:ok, %{authority: authority, envelope: admission(input, authority, recovery)}}
    else
      _ -> unavailable()
    end
  end

  defp approve_locked(input, target_id, preflight, admission) do
    with {:ok, current} <- approval_authority(input, target_id),
         true <- current.envelope == preflight.envelope,
         :ok <- valid_admission(admission, preflight.envelope),
         {:ok, recovery} <- Recovery.lock_case(input.case_id) do
      approve_current(input, current.authority, recovery, current.authority.target, admission)
    else
      _ -> unavailable()
    end
  end

  defp completion_authority(input, snapshot) do
    review = snapshot.review

    with true <- is_map(review),
         true <-
           snapshot.version == input.expected_version or
             (snapshot.state == :completed and snapshot.completion_id == input.operation_id and
                snapshot.version == input.expected_version + 1),
         {:ok, authority} <-
           PrivilegedAccess.authorize_locked(
             input.credentials,
             input.grant_id,
             snapshot.account_id,
             @capability_complete,
             [review["reviewer_id"]]
           ),
         {:ok, reviewer} <-
           PrivilegedAccess.authorize_recorded_locked(
             review,
             snapshot.account_id,
             @capability_approve,
             Map.fetch!(authority.accounts, review["reviewer_id"])
           ),
         {:ok, recovery} <- Recovery.lock_case(input.case_id),
         account <- authority.target,
         :ok <- valid_case_or_receipt(recovery, account, input),
         :ok <- valid_review(recovery, account, reviewer, reviewer.grant),
         true <- authority.actor.id != reviewer.actor.id,
         true <- authority.actor.id != snapshot.account_id,
         :ok <- current_completion_case(recovery, account, input),
         envelope <- admission(input, authority, snapshot) do
      {:ok, %{authority: authority, reviewer: reviewer, envelope: envelope}}
    else
      _ -> unavailable()
    end
  end

  defp complete_locked(input, password, target_id, preflight, admission) do
    review = preflight.reviewer.review

    with {:ok, authority} <-
           PrivilegedAccess.authorize_locked(
             input.credentials,
             input.grant_id,
             target_id,
             @capability_complete,
             [review["reviewer_id"]]
           ),
         {:ok, reviewer} <-
           PrivilegedAccess.authorize_recorded_locked(
             review,
             target_id,
             @capability_approve,
             Map.fetch!(authority.accounts, review["reviewer_id"])
           ),
         {:ok, recovery} <- Recovery.lock_case(input.case_id),
         account <- authority.target,
         true <- admission(input, authority, recovery) == preflight.envelope,
         :ok <- valid_admission(admission, preflight.envelope) do
      complete_authorized(
        input,
        password,
        recovery,
        account,
        authority,
        reviewer,
        preflight,
        admission
      )
    else
      _ -> unavailable()
    end
  end

  defp eligible_approval(recovery, account, authority) do
    with true <- recovery.state == :held_manual_review,
         true <- recovery.satisfied_assurance >= 1,
         true <- account.security_posture == :held,
         true <- Recovery.current?(recovery, account),
         true <- authority.actor.id != account.id do
      :ok
    else
      _ -> unavailable()
    end
  end

  defp approve_current(input, authority, recovery, account, admission) do
    if recovery.review["operation_id"] == input.operation_id and
         recovery.version == input.expected_version + 1 do
      {:ok, %{status: :approved, version: recovery.version}}
    else
      record_approval(input, authority, recovery, account, admission)
    end
  end

  defp record_approval(input, authority, recovery, account, admission) do
    review = review_record(input, authority, recovery, account)

    with {:ok, reviewed} <- Recovery.transition(recovery, :record_review, %{review: review}),
         {:ok, _} <- review_evidence(input, authority, account, reviewed, admission) do
      checkpoint()
      {:ok, %{status: :approved, version: reviewed.version}}
    else
      _ -> unavailable()
    end
  end

  defp complete_authorized(
         input,
         password,
         recovery,
         account,
         authority,
         reviewer,
         preflight,
         admission
       ) do
    with true <- authority.actor.id != reviewer.actor.id,
         true <- authority.actor.id != account.id,
         :ok <- valid_review(recovery, account, reviewer, preflight.reviewer.grant) do
      if recovery.state == :completed and recovery.completion_id == input.operation_id and
           recovery.version == input.expected_version + 1 do
        {:ok, :already_completed}
      else
        finish_recovery(input, password, recovery, account, authority, admission)
      end
    else
      _ -> unavailable()
    end
  end

  defp finish_recovery(input, password, recovery, account, authority, admission) do
    with :ok <- valid_case(recovery, account, input.expected_version),
         true <- recovery.required_assurance == 2 and recovery.satisfied_assurance >= 1,
         true <- Recovery.current?(recovery, account),
         true <- account.security_posture == :held,
         {:ok, proof} <- current_recovery_proof(recovery, account),
         {:ok, :completed} <-
           Recovery.finish(
             recovery,
             account,
             proof,
             password,
             input.operation_id,
             %{
               actor: authority.actor,
               admission_id: admission.id,
               grant: authority.grant,
               session: authority.session,
               reason_code: input.reason_code
             }
           ) do
      {:ok, :completed}
    else
      _ -> unavailable()
    end
  end

  defp parse(request) do
    with {:ok, case_id} <- uuid(request[:case_id]),
         {:ok, grant_id} <- uuid(request[:grant_id]),
         {:ok, operation_id} <- uuid(request[:operation_id]),
         {:ok, expected_version} <- non_negative(request[:expected_version]),
         :verified_recovery <- request[:reason_code],
         credentials when is_map(credentials) <- request[:credentials] do
      {:ok,
       %{
         case_id: case_id,
         grant_id: grant_id,
         operation_id: operation_id,
         expected_version: expected_version,
         reason_code: :verified_recovery,
         credentials: credentials
       }}
    else
      _ -> unavailable()
    end
  end

  defp recovery(id) do
    case Ash.get(RecoveryCase, id, authorize?: false) do
      {:ok, %RecoveryCase{} = recovery} -> {:ok, recovery}
      _ -> unavailable()
    end
  end

  defp valid_case(recovery, account, expected_version) do
    with true <- recovery.account_id == account.id,
         true <- recovery.version == expected_version,
         true <- DateTime.compare(DateTime.utc_now(), recovery.expires_at) == :lt,
         true <- recovery.state == :held_manual_review,
         true <- account.account_status == :open and account.credential_status == :active do
      :ok
    else
      _ -> unavailable()
    end
  end

  defp valid_case_or_receipt(recovery, account, input) do
    if recovery.state == :completed and recovery.completion_id == input.operation_id and
         recovery.account_id == account.id and recovery.version == input.expected_version + 1 and
         account.account_status == :open and account.credential_status == :active do
      :ok
    else
      valid_case(recovery, account, input.expected_version)
    end
  end

  defp current_completion_case(recovery, account, input) do
    if recovery.state == :completed and recovery.completion_id == input.operation_id and
         recovery.version == input.expected_version + 1 do
      :ok
    else
      with true <- recovery.required_assurance == 2 and recovery.satisfied_assurance >= 1,
           true <- Recovery.current?(recovery, account),
           true <- account.security_posture == :held do
        :ok
      else
        _ -> unavailable()
      end
    end
  end

  defp valid_approval_case(recovery, account, input) do
    if recovery.version == input.expected_version + 1 and
         recovery.review["operation_id"] == input.operation_id and
         recovery.account_id == account.id and
         DateTime.compare(DateTime.utc_now(), recovery.expires_at) == :lt and
         account.account_status == :open and account.credential_status == :active do
      :ok
    else
      valid_case(recovery, account, input.expected_version)
    end
  end

  defp review_record(input, authority, recovery, account) do
    expires_at =
      [recovery.expires_at, authority.grant.expires_at, authority.session.step_up_expires_at]
      |> Enum.min_by(&DateTime.to_unix(&1, :microsecond))

    %{
      "operation_id" => input.operation_id,
      "reviewer_id" => authority.actor.id,
      "grant_id" => authority.grant.id,
      "grant_version" => authority.grant.version,
      "session_id" => authority.session.id,
      "mfa_version" => authority.actor.mfa_version,
      "security_version" => authority.actor.security_version,
      "case_version" => recovery.version + 1,
      "hold_version" => account.hold_version,
      "expires_at" => DateTime.to_iso8601(expires_at)
    }
  end

  defp review_evidence(input, authority, account, recovery, admission) do
    Audit.establish_identity_security_obligation(%{
      source_operation_id: input.operation_id,
      source_occurred_at: admission.admitted_at,
      evidence_type: :identity_recovery_review,
      actor_id: authority.actor.id,
      target_id: account.id,
      grant_id: authority.grant.id,
      session_id: authority.session.id,
      reason_code: input.reason_code,
      admission_id: admission.id,
      case_id: recovery.id,
      outcome: :succeeded
    })
  end

  defp record_failure(input, target_id, preflight, admission, evidence_type) do
    authority = preflight.authority

    outcome = %{
      source_operation_id: input.operation_id,
      source_occurred_at: admission.admitted_at,
      evidence_type: evidence_type,
      actor_id: authority.actor.id,
      target_id: target_id,
      grant_id: authority.grant.id,
      session_id: authority.session.id,
      reason_code: input.reason_code,
      admission_id: admission.id,
      case_id: input.case_id,
      outcome: :failed
    }

    case Ash.transact(NewYou.Audit.EvidenceObligation, fn ->
           Audit.establish_identity_security_obligation(outcome)
         end) do
      {:ok, _} -> :ok
      _ -> :error
    end
  rescue
    _ -> :error
  end

  defp admission(input, authority, snapshot) do
    %{
      attempt_id: input.operation_id,
      actor_id: authority.actor.id,
      target_id: snapshot.account_id,
      grant_id: authority.grant.id,
      grant_version: authority.grant.version,
      session_id: authority.session.id,
      expected_version: input.expected_version,
      reason_code: input.reason_code,
      case_id: snapshot.id
    }
  end

  defp valid_review(recovery, account, reviewer, grant) do
    review = recovery.review

    if review_authority_matches?(review, reviewer, grant) and
         review_case_matches?(review, recovery) and review_hold_matches?(review, account) and
         current_expiry?(review["expires_at"], DateTime.utc_now()),
       do: :ok,
       else: unavailable()
  end

  defp review_authority_matches?(review, reviewer, grant) when is_map(review) do
    review["reviewer_id"] == reviewer.actor.id and review["grant_id"] == grant.id and
      review["grant_version"] == grant.version and review["session_id"] == reviewer.session.id and
      review["mfa_version"] == reviewer.actor.mfa_version and
      review["security_version"] == reviewer.actor.security_version
  end

  defp review_authority_matches?(_, _, _), do: false

  defp review_case_matches?(review, recovery) do
    case_version = review["case_version"]

    is_integer(case_version) and
      (case_version == recovery.version or
         (recovery.state == :completed and case_version + 1 == recovery.version))
  end

  defp review_hold_matches?(review, account),
    do: review["hold_version"] == account.hold_version and account.security_posture == :held

  defp current_recovery_proof(recovery, account) do
    with true <- is_binary(recovery.proof_jti),
         true <- not is_nil(recovery.proof_acceptance_id),
         {:ok, %Token{} = proof} <- Recovery.token(recovery.proof_jti, true),
         true <- proof.purpose == "recovery_consumed",
         true <- proof.account_id == account.id,
         true <- proof.recovery_case_id == recovery.id,
         claims when is_map(claims) <- proof.recovery_claims,
         true <- claims["purpose"] == "recovery",
         true <- claims["jti"] == proof.jti,
         true <- claims["case_id"] == recovery.id,
         true <- claims["sub"] == AshAuthentication.user_to_subject(account) do
      {:ok, proof}
    else
      _ -> unavailable()
    end
  end

  defp valid_admission(admission, envelope) do
    fields = Map.keys(envelope) ++ [:action_class]

    if admission.assertion_kind == :admission and admission.action_class == :identity_recovery and
         Map.take(Map.from_struct(admission), fields) ==
           Map.put(envelope, :action_class, :identity_recovery),
       do: :ok,
       else: unavailable()
  end

  defp current_expiry?(value, now) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, expiry, _} -> DateTime.compare(now, expiry) == :lt
      _ -> false
    end
  end

  defp current_expiry?(_, _), do: false

  defp uuid(value) do
    case Ecto.UUID.cast(value) do
      {:ok, value} when is_binary(value) -> {:ok, value}
      _ -> unavailable()
    end
  end

  defp non_negative(value) when is_integer(value) and value >= 0, do: {:ok, value}
  defp non_negative(_), do: unavailable()
  defp unavailable, do: {:error, :recovery_unavailable}
end
