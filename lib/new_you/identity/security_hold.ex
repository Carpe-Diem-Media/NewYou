defmodule NewYou.Identity.SecurityHold do
  @moduledoc false
  require Ash.Query

  alias NewYou.Identity.{Account, IdentityGrant, PrivilegedAccess, Session, Token}
  alias NewYou.Audit

  @resources [Account, Token, Session, IdentityGrant, Audit.EvidenceObligation]
  @fields ~w(credentials grant_id target_id expected_version operation_id reason_code)a
  @reasons ~w(suspected_compromise security_review verified_recovery mistaken_hold)a

  defmacrop checkpoint(point) do
    if Mix.env() == :test do
      quote do: NewYou.Proof.SecurityHoldSeam.checkpoint(unquote(point))
    else
      quote do: :ok
    end
  end

  def run(kind, request) do
    with {:ok, request} <- validate_request(request),
         false <- Ash.DataLayer.in_transaction?(Account) do
      case kind do
        :release_security_hold ->
          release(request)

        kind when kind in [:place_security_hold, :review_security_hold] ->
          source_transaction(kind, request)

        _ ->
          unavailable()
      end
    else
      _ -> unavailable()
    end
  rescue
    _ -> unavailable()
  end

  defp release(request) do
    with {:ok, initial} <- preflight(request),
         {:ok, admission} <- Audit.admit_security_hold_release(initial) do
      attempt_release(request, admission)
    else
      _ -> unavailable()
    end
  end

  defp preflight(request) do
    transaction(fn ->
      with {:ok, authority} <- authority(request, :release_security_hold),
           :ok <- initial_release_eligible(authority, request) do
        {:ok, admission_envelope(authority, request)}
      end
    end)
  end

  defp initial_release_eligible(authority, request) do
    case prior_result(authority, request, :release_security_hold) do
      {:ok, _result} -> :ok
      :new -> held_and_reviewed(authority, request)
      _ -> unavailable()
    end
  end

  defp attempt_release(request, admission) do
    result =
      try do
        :ok = checkpoint(:after_admission)
        source_transaction(:release_security_hold, request, admission)
      rescue
        _ -> unavailable()
      end

    case result do
      {:ok, _} ->
        :ok = checkpoint(:after_source_commit)
        result

      _ ->
        record_failed_attempt(request, admission)
        unavailable()
    end
  end

  defp source_transaction(kind, request, admission \\ nil) do
    transaction(fn -> source_locked(kind, request, admission) end)
  end

  defp source_locked(kind, request, admission) do
    with :ok <- checkpoint(:before_authority),
         {:ok, authority} <- authority(request, kind),
         :ok <- admission_matches(admission, authority, request) do
      case prior_result(authority, request, kind) do
        {:ok, result} -> {:ok, result}
        :new -> apply_transition(kind, authority, request, admission)
        _ -> unavailable()
      end
    end
  end

  defp authority(request, capability) do
    # A reviewed hold adds one Account to the lock set. Lock all Accounts before
    # Token/Session/grants, including when the actor is also the prior reviewer.
    with {:ok, target} when not is_nil(target) <-
           Ash.get(Account, request.target_id, authorize?: false),
         {:ok, session} when not is_nil(session) <-
           Ash.get(Session, request.credentials[:session_id], authorize?: false),
         ids <- account_lock_ids(session.account_id, target),
         {:ok, _} <-
           Account
           |> Ash.Query.filter(id in ^ids)
           |> Ash.Query.sort(id: :asc)
           |> Ash.Query.lock(:for_update)
           |> Ash.read(authorize?: false),
         {:ok, authority} <-
           PrivilegedAccess.authorize_locked(
             request.credentials,
             request.grant_id,
             request.target_id,
             capability
           ),
         true <- Enum.all?(account_lock_ids(authority.actor.id, authority.target), &(&1 in ids)),
         true <- authority.actor.id != authority.target.id,
         true <- authority.target.account_status == :open do
      {:ok, authority}
    else
      _ -> unavailable()
    end
  end

  defp account_lock_ids(actor_id, target) do
    [actor_id, target.id, (target.hold_review || %{})["reviewer_id"]]
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp apply_transition(:place_security_hold = kind, authority, request, _admission) do
    with true <- authority.target.security_posture == :normal,
         true <- authority.target.hold_version == request.expected_version,
         :ok <- revoke_target_sessions(authority.target.id),
         {:ok, target} <- write_transition(kind, authority, request),
         {:ok, _} <- establish_outcome(kind, authority, request, :succeeded, nil) do
      {:ok, %{status: :held, version: target.hold_version}}
    else
      _ -> unavailable()
    end
  end

  defp apply_transition(:review_security_hold = kind, authority, request, _admission) do
    with true <- authority.target.security_posture == :held,
         true <- authority.target.hold_version == request.expected_version,
         {:ok, target} <- write_transition(kind, authority, request),
         {:ok, _} <- establish_outcome(kind, authority, request, :succeeded, nil) do
      {:ok, %{status: :reviewed, version: target.hold_version}}
    else
      _ -> unavailable()
    end
  end

  defp apply_transition(:release_security_hold = kind, authority, request, admission) do
    with :ok <- held_and_reviewed(authority, request),
         :ok <- checkpoint(:before_release),
         {:ok, authority} <- authority(request, kind),
         :ok <- admission_matches(admission, authority, request),
         :ok <- held_and_reviewed(authority, request),
         {:ok, target} <- write_transition(kind, authority, request),
         {:ok, _} <- establish_outcome(kind, authority, request, :succeeded, admission),
         :ok <- checkpoint(:after_release_before_commit) do
      {:ok, %{status: :released, version: target.hold_version}}
    else
      _ -> unavailable()
    end
  end

  defp held_and_reviewed(authority, request) do
    target = authority.target
    review = target.hold_review || %{}

    with true <- target.security_posture == :held,
         true <- target.hold_version == request.expected_version,
         true <- review["hold_version"] == target.hold_version,
         true <- review["reviewer_id"] not in [nil, authority.actor.id, target.id],
         {:ok, reviewer} when not is_nil(reviewer) <-
           Ash.get(Account, review["reviewer_id"], authorize?: false),
         true <- reviewer.account_status == :open and reviewer.security_posture == :normal,
         true <- reviewer.email_verified? and reviewer.credential_status == :active,
         true <- reviewer.mfa_enrollment_state == :active,
         {:ok, grant} when not is_nil(grant) <-
           IdentityGrant
           |> Ash.Query.filter(id == ^review["grant_id"])
           |> Ash.Query.lock(:for_update)
           |> Ash.read_one(authorize?: false),
         true <- review_grant_current?(grant, reviewer, target, review) do
      :ok
    else
      _ -> unavailable()
    end
  end

  defp review_grant_current?(grant, reviewer, target, review) do
    review_grant_scope?(grant, reviewer, target) and review_grant_live?(grant, review) and
      reviewer.mfa_version == review["mfa_version"] and
      reviewer.security_version == review["security_version"]
  end

  defp review_grant_scope?(grant, reviewer, target) do
    grant.subject_account_id == reviewer.id and grant.target_account_id == target.id and
      grant.role == :support and grant.capability == :review_security_hold and
      grant.approver_account_id != reviewer.id
  end

  defp review_grant_live?(grant, review) do
    now = DateTime.utc_now()

    grant.state == :active and is_nil(grant.revoked_at) and
      grant.version == review["grant_version"] and
      DateTime.compare(now, grant.starts_at) != :lt and
      DateTime.compare(now, grant.expires_at) == :lt
  end

  defp write_transition(kind, authority, request) do
    target = authority.target

    version =
      if kind == :review_security_hold, do: target.hold_version, else: target.hold_version + 1

    result = result_entry(authority, request, kind, :succeeded, version)

    attrs = %{
      hold_operations: Map.put(target.hold_operations, request.operation_id, result),
      expected_hold_version: target.hold_version
    }

    attrs =
      if kind == :review_security_hold do
        Map.put(attrs, :hold_review, %{
          "reviewer_id" => authority.actor.id,
          "grant_id" => authority.grant.id,
          "grant_version" => authority.grant.version,
          "hold_version" => target.hold_version,
          "mfa_version" => authority.actor.mfa_version,
          "security_version" => authority.actor.security_version
        })
      else
        Map.merge(attrs, %{hold_version: version, security_version: target.security_version + 1})
      end

    Ash.update(target, attrs, action: kind, authorize?: false)
  end

  defp revoke_target_sessions(target_id) do
    Session
    |> Ash.Query.filter(account_id == ^target_id and state == :active)
    |> Ash.Query.sort(id: :asc)
    |> Ash.Query.lock(:for_update)
    |> Ash.read(authorize?: false)
    |> case do
      {:ok, sessions} ->
        Enum.reduce_while(sessions, :ok, &revoke_session/2)

      _ ->
        unavailable()
    end
  end

  defp revoke_session(session, :ok) do
    case Ash.update(session, %{}, action: :revoke, authorize?: false) do
      {:ok, _} -> {:cont, :ok}
      _ -> {:halt, unavailable()}
    end
  end

  defp prior_result(authority, request, kind) do
    case authority.target.hold_operations[request.operation_id] do
      nil ->
        :new

      %{"binding" => binding, "outcome" => "succeeded", "version" => version} ->
        if binding == binding(authority, request, kind),
          do: {:ok, %{status: status(kind), version: version}},
          else: unavailable()

      _ ->
        unavailable()
    end
  end

  defp binding(authority, request, kind) do
    %{
      "kind" => Atom.to_string(kind),
      "actor_id" => authority.actor.id,
      "grant_id" => authority.grant.id,
      "grant_version" => authority.grant.version,
      "session_id" => authority.session.id,
      "expected_version" => request.expected_version,
      "reason_code" => Atom.to_string(request.reason_code)
    }
  end

  defp result_entry(authority, request, kind, outcome, version) do
    %{
      "binding" => binding(authority, request, kind),
      "outcome" => Atom.to_string(outcome),
      "version" => version
    }
  end

  defp admission_envelope(authority, request) do
    %{
      attempt_id: request.operation_id,
      actor_id: authority.actor.id,
      target_id: authority.target.id,
      grant_id: authority.grant.id,
      grant_version: authority.grant.version,
      session_id: authority.session.id,
      expected_version: request.expected_version,
      reason_code: request.reason_code
    }
  end

  defp admission_matches(nil, _authority, _request), do: :ok

  defp admission_matches(admission, authority, request) do
    expected = admission_envelope(authority, request)
    if Map.take(admission, Map.keys(expected)) == expected, do: :ok, else: unavailable()
  end

  defp establish_outcome(kind, authority, request, outcome, admission) do
    envelope = %{
      source_operation_id: request.operation_id,
      source_occurred_at: DateTime.utc_now(),
      evidence_type: evidence_type(kind),
      actor_id: authority.actor.id,
      target_id: authority.target.id,
      grant_id: authority.grant.id,
      session_id: authority.session.id,
      reason_code: request.reason_code,
      outcome: outcome
    }

    envelope = if admission, do: Map.put(envelope, :admission_id, admission.id), else: envelope
    Audit.establish_identity_security_obligation(envelope)
  end

  defp record_failed_attempt(request, admission) do
    # This records the source's failed attempt, not permission to mutate posture.
    # It commits together with the E2 obligation so evidence recovery needs no
    # authority to retry the protected release.
    transaction(fn -> record_failure_locked(request, admission) end)
  rescue
    _ -> unavailable()
  end

  defp record_failure_locked(request, admission) do
    with {:ok, target} when not is_nil(target) <-
           Account
           |> Ash.Query.filter(id == ^request.target_id)
           |> Ash.Query.lock(:for_update)
           |> Ash.read_one(authorize?: false) do
      if Map.has_key?(target.hold_operations, request.operation_id),
        do: {:ok, :recorded},
        else: persist_failed_result(target, request, admission)
    end
  end

  defp persist_failed_result(target, request, admission) do
    authority = %{
      actor: %{id: admission.actor_id},
      target: target,
      grant: %{id: admission.grant_id, version: admission.grant_version},
      session: %{id: admission.session_id}
    }

    entry = result_entry(authority, request, :release_security_hold, :failed, target.hold_version)

    attrs = %{
      hold_operations: Map.put(target.hold_operations, request.operation_id, entry),
      expected_hold_version: target.hold_version
    }

    with {:ok, _} <-
           Ash.update(target, attrs, action: :record_security_hold_attempt, authorize?: false),
         {:ok, _} <-
           establish_outcome(:release_security_hold, authority, request, :failed, admission) do
      {:ok, :recorded}
    end
  end

  defp transaction(callback) do
    case Ash.transact(@resources, callback) do
      {:ok, {:ok, result}} -> {:ok, result}
      {:ok, {:error, _}} -> unavailable()
      {:ok, result} -> {:ok, result}
      _ -> unavailable()
    end
  end

  defp validate_request(request) when is_map(request) do
    valid? =
      Enum.sort(Map.keys(request)) == Enum.sort(@fields) and
        is_map(request.credentials) and is_integer(request.expected_version) and
        request.expected_version >= 0 and request.reason_code in @reasons and
        Enum.all?([:grant_id, :target_id, :operation_id], fn key ->
          case Ecto.UUID.cast(request[key]) do
            {:ok, id} -> id == request[key]
            _ -> false
          end
        end)

    if valid?, do: {:ok, request}, else: unavailable()
  end

  defp validate_request(_), do: unavailable()
  defp evidence_type(:place_security_hold), do: :security_hold_placement
  defp evidence_type(:review_security_hold), do: :security_hold_review
  defp evidence_type(:release_security_hold), do: :security_hold_release_result
  defp status(:place_security_hold), do: :held
  defp status(:review_security_hold), do: :reviewed
  defp status(:release_security_hold), do: :released
  defp unavailable, do: {:error, :security_hold_unavailable}
end
