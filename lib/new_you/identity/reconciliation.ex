defmodule NewYou.Identity.Reconciliation do
  @moduledoc false
  require Ash.Query
  alias NewYou.{Audit, Communications, Identity}

  alias NewYou.Identity.{
    Account,
    IdentityGrant,
    PrivilegedAccess,
    ReconciliationCase,
    Session,
    Token
  }

  @resources [
    Account,
    ReconciliationCase,
    Token,
    Session,
    IdentityGrant,
    Audit.EvidenceObligation
  ]
  @transitions %{
    detected: [:candidate, :rejected],
    candidate: [:review, :rejected],
    review: [:approved, :rejected, :conflict],
    conflict: [:review, :rejected],
    approved: [:review, :rejected]
  }

  defmacrop checkpoint(point) do
    if Mix.env() == :test do
      quote do: NewYou.Proof.ReconciliationSeam.checkpoint(unquote(point))
    else
      quote do: :ok
    end
  end

  defmacrop control_time do
    if Mix.env() == :test do
      quote do: NewYou.Proof.ReconciliationSeam.control_time()
    else
      quote do: DateTime.utc_now()
    end
  end

  def open(request) when is_map(request) do
    with true <-
           keys?(
             request,
             ~w(credentials grant_id canonical_grant_id candidate_id canonical_id operation_id detection_basis)a,
             [:compensates_id]
           ),
         true <- request.candidate_id != request.canonical_id,
         false <- Ash.DataLayer.in_transaction?(Account) do
      transaction(fn -> open_locked(request) end)
    else
      _ -> unavailable()
    end
  rescue
    _ -> unavailable()
  end

  def open(_), do: unavailable()

  defp open_locked(request) do
    with {:ok, authority, accounts} <- authority(request, request, :review_reconciliation),
         :ok <- eligible_accounts(request, accounts),
         :ok <- compensation_eligible(request),
         {:ok, existing} <-
           ReconciliationCase
           |> Ash.Query.filter(operation_id == ^request.operation_id)
           |> Ash.read_one(authorize?: false) do
      detect_or_replay(existing, authority, request)
    end
  end

  def review(request) when is_map(request) do
    with true <-
           keys?(
             request,
             ~w(credentials grant_id canonical_grant_id case_id expected_version controls decision)a
           ),
         false <- Ash.DataLayer.in_transaction?(Account),
         {:ok, initial} when not is_nil(initial) <-
           Ash.get(ReconciliationCase, request.case_id, authorize?: false) do
      transaction(fn -> review_locked(initial, request) end)
    else
      _ -> unavailable()
    end
  rescue
    _ -> unavailable()
  end

  def review(_), do: unavailable()

  defp review_locked(initial, request) do
    with {:ok, authority, accounts} <- authority(request, initial, :review_reconciliation),
         {:ok, current} <- locked_case(initial.id),
         true <- current.version == request.expected_version,
         true <- request.decision in Map.get(@transitions, current.status, []),
         :ok <- eligible_review_accounts(request.decision, current, accounts),
         {:ok, evidence} <- review_evidence(request, current, authority, accounts) do
      persist_review(current, request, authority, evidence)
    else
      _ -> unavailable()
    end
  end

  defp persist_review(current, request, authority, evidence) do
    operation_id = Ecto.UUID.generate()
    entry = Map.put(event(authority, request.decision), "operation_id", operation_id)

    entry =
      if current.status == :approved,
        do: Map.put(entry, "superseded_review", current.review),
        else: entry

    with {:ok, reviewed} <-
           Ash.update(
             current,
             %{
               status: request.decision,
               review: evidence,
               history: current.history ++ [entry],
               expected_version: current.version
             },
             action: :record_review,
             authorize?: false
           ),
         :ok <- review_outcome(reviewed, request, authority, operation_id) do
      {:ok, reviewed}
    end
  end

  defp review_outcome(current, %{decision: decision}, authority, operation_id)
       when decision in [:conflict, :rejected] do
    case Audit.establish_identity_security_obligation(%{
           source_operation_id: operation_id,
           source_occurred_at: DateTime.utc_now(),
           evidence_type: :identity_reconciliation_review,
           case_id: current.id,
           actor_id: authority.actor.id,
           target_id: current.candidate_id,
           grant_id: authority.grant.id,
           session_id: authority.session.id,
           reason_code: :security_review,
           outcome: :denied
         }) do
      {:ok, _} -> :ok
      _ -> unavailable()
    end
  end

  defp review_outcome(_current, _request, _authority, _operation_id), do: :ok

  def apply_decision(request) when is_map(request) do
    with true <-
           keys?(
             request,
             ~w(credentials grant_id canonical_grant_id case_id expected_version operation_id)a
           ),
         false <- Ash.DataLayer.in_transaction?(Account),
         {:ok, initial} when not is_nil(initial) <-
           Ash.get(ReconciliationCase, request.case_id, authorize?: false),
         {:ok, envelope} <- preflight(initial, request),
         {:ok, admission} <- Audit.admit_reconciliation(envelope) do
      attempt_apply(initial, request, admission)
    else
      _ -> unavailable()
    end
  rescue
    _ -> unavailable()
  end

  def apply_decision(_), do: unavailable()

  defp preflight(initial, request) do
    transaction(fn ->
      with {:ok, authority, accounts} <- authority(request, initial, :apply_reconciliation),
           {:ok, current} <- locked_case(initial.id),
           :ok <- applicable(current, request, authority, accounts) do
        {:ok, envelope(current, request, authority)}
      end
    end)
  end

  defp attempt_apply(initial, request, admission) do
    result =
      try do
        :ok = checkpoint(:after_admission)

        transaction(fn ->
          :ok = checkpoint(:before_source_transaction)

          with {:ok, authority, accounts} <- authority(request, initial, :apply_reconciliation),
               {:ok, current} <- locked_case(initial.id),
               true <-
                 Map.take(admission, Map.keys(envelope(current, request, authority))) ==
                   envelope(current, request, authority),
               :ok <- applicable(current, request, authority, accounts) do
            commit_or_replay(current, request, authority, accounts, admission)
          else
            _ -> unavailable()
          end
        end)
      rescue
        _ -> unavailable()
      end

    case result do
      {:ok, record} ->
        :ok = checkpoint(:after_source_commit)
        {:ok, record}

      _ ->
        record_failure(initial, request, admission)
        unavailable()
    end
  end

  defp commit_or_replay(
         %{status: :applied} = current,
         _request,
         _authority,
         _accounts,
         _admission
       ),
       do: {:ok, current}

  defp commit_or_replay(current, request, authority, accounts, admission) do
    with :ok <- revoke_sessions(current.candidate_id),
         {:ok, _} <-
           Ash.update(
             accounts[current.candidate_id],
             %{canonical_account_id: current.canonical_id},
             action: :retire_reconciled_identity,
             authorize?: false
           ),
         {:ok, _} <-
           Ash.update(accounts[current.canonical_id], %{},
             action: :advance_reconciliation_version,
             authorize?: false
           ),
         {:ok, applied} <-
           Ash.update(
             current,
             %{
               expected_version: current.version,
               applied_operation_id: request.operation_id,
               applied_at: DateTime.utc_now(),
               apply_binding: binding(current, request, authority),
               history: current.history ++ [event(authority, :applied)]
             },
             action: :apply_decision,
             authorize?: false
           ),
         {:ok, _} <- outcome(current, request, admission, :succeeded),
         :ok <- checkpoint(:before_source_commit) do
      {:ok, applied}
    else
      _ -> unavailable()
    end
  end

  defp applicable(%{status: :applied} = current, request, authority, _accounts) do
    if current.applied_operation_id == request.operation_id and
         current.apply_binding == binding(current, request, authority),
       do: :ok,
       else: unavailable()
  end

  defp applicable(current, request, _authority, accounts) do
    with true <- current.status == :approved and current.version == request.expected_version,
         :ok <- eligible_accounts(current, accounts),
         true <- current.review["accounts"] == account_versions(current, accounts),
         :ok <- current_reviewer(current, accounts),
         :ok <- current_controls(current),
         {:ok, domains} <- owner_reviews(current),
         true <- current.review["domains"] == domains,
         {:ok, nil} <-
           Audit.EvidenceObligation
           |> Ash.Query.filter(source_operation_id == ^request.operation_id)
           |> Ash.read_one(authorize?: false) do
      :ok
    else
      _ -> unavailable()
    end
  end

  defp authority(request, candidates, capability) do
    with {:ok, session} when not is_nil(session) <-
           Ash.get(Session, request.credentials[:session_id], authorize?: false),
         reviewer_id <- get_in(Map.get(candidates, :review) || %{}, ["actor_id"]),
         ids <-
           Enum.sort(
             Enum.uniq(
               Enum.reject(
                 [
                   session.account_id,
                   candidates.candidate_id,
                   candidates.canonical_id,
                   reviewer_id
                 ],
                 &is_nil/1
               )
             )
           ),
         {:ok, locked} <-
           Account
           |> Ash.Query.filter(id in ^ids)
           |> Ash.Query.sort(id: :asc)
           |> Ash.Query.lock(:for_update)
           |> Ash.read(authorize?: false),
         true <- length(locked) == length(ids),
         {:ok, _grants} <- lock_pair_grants(request.grant_id, request.canonical_grant_id),
         {:ok, authority} <-
           PrivilegedAccess.authorize_locked(
             request.credentials,
             request.grant_id,
             candidates.candidate_id,
             capability
           ),
         {:ok, canonical_authority} <-
           PrivilegedAccess.authorize_locked(
             request.credentials,
             request.canonical_grant_id,
             candidates.canonical_id,
             capability
           ),
         true <- authority.actor.id not in [candidates.candidate_id, candidates.canonical_id] do
      {:ok, Map.put(authority, :canonical_grant, canonical_authority.grant),
       Map.new(locked, &{&1.id, &1})}
    else
      _ -> unavailable()
    end
  end

  # The union of actor, reviewer and candidate Accounts is already locked.
  # Grant revocation takes its subject Account first, so these sorted locks
  # cannot race a revoker or reverse the order for overlapping cases.
  defp lock_pair_grants(candidate_grant_id, canonical_grant_id) do
    ids = Enum.sort(Enum.uniq([candidate_grant_id, canonical_grant_id]))

    IdentityGrant
    |> Ash.Query.filter(id in ^ids)
    |> Ash.Query.sort(id: :asc)
    |> Ash.Query.lock(:for_update)
    |> Ash.read(authorize?: false)
  end

  defp review_evidence(%{decision: :approved} = request, current, authority, accounts) do
    with true <- is_list(request.controls) and length(request.controls) == 2,
         {:ok, controls} <- verify_controls(request.controls, current),
         true <-
           Enum.sort(Enum.map(controls, & &1["account_id"])) ==
             Enum.sort([current.candidate_id, current.canonical_id]),
         {:ok, domains} <- owner_reviews(current) do
      {:ok,
       %{
         "actor_id" => authority.actor.id,
         "grant_id" => authority.grant.id,
         "grant_version" => authority.grant.version,
         "canonical_grant_id" => authority.canonical_grant.id,
         "canonical_grant_version" => authority.canonical_grant.version,
         "mfa_version" => authority.actor.mfa_version,
         "security_version" => authority.actor.security_version,
         "controls" => controls,
         "accounts" => account_versions(current, accounts),
         "domains" => domains
       }}
    else
      _ -> unavailable()
    end
  end

  defp review_evidence(_request, _current, _authority, _accounts), do: {:ok, nil}

  defp verify_controls(controls, current) do
    Enum.reduce_while(controls, {:ok, []}, fn credentials, {:ok, evidence} ->
      case Ash.get(Session, credentials[:session_id], authorize?: false) do
        {:ok, %{account_id: id}} when id in [current.candidate_id, current.canonical_id] -> :ok
        _ -> raise "control does not belong to this case"
      end

      case Identity.authorize_session(credentials) do
        {:ok, %{account_id: id}} ->
          {:cont,
           {:ok,
            evidence ++
              [
                %{
                  "account_id" => id,
                  "session_id" => credentials.session_id,
                  "verified_at" => DateTime.to_iso8601(control_time())
                }
              ]}}

        _ ->
          {:halt, unavailable()}
      end
    end)
  end

  defp current_reviewer(current, accounts) do
    review = current.review
    actor = accounts[review["actor_id"]]

    with true <-
           not is_nil(actor) and actor.account_status == :open and
             actor.security_posture == :normal,
         true <-
           actor.mfa_enrollment_state == :active and actor.mfa_version == review["mfa_version"] and
             actor.security_version == review["security_version"],
         {:ok, grants} <- lock_pair_grants(review["grant_id"], review["canonical_grant_id"]),
         true <-
           Enum.all?(
             [
               {review["grant_id"], review["grant_version"], current.candidate_id},
               {review["canonical_grant_id"], review["canonical_grant_version"],
                current.canonical_id}
             ],
             fn {id, version, target} ->
               grant = Enum.find(grants, &(&1.id == id))

               valid_recorded_grant?(grant, actor, target, version)
             end
           ) do
      :ok
    else
      _ -> unavailable()
    end
  end

  defp valid_recorded_grant?(nil, _actor, _target, _version), do: false

  defp valid_recorded_grant?(grant, actor, target, version) do
    grant.target_account_id == target and grant.subject_account_id == actor.id and
      grant.approver_account_id != actor.id and grant.version == version and
      live_review_grant?(grant) and
      DateTime.compare(DateTime.utc_now(), grant.starts_at) != :lt and
      DateTime.compare(DateTime.utc_now(), grant.expires_at) == :lt
  end

  defp live_review_grant?(grant),
    do:
      grant.state == :active and is_nil(grant.revoked_at) and
        IdentityGrant.permits?(grant, :review_reconciliation)

  defp current_controls(current) do
    now = control_time()

    valid? =
      Enum.all?(current.review["controls"], fn control ->
        with {:ok, checked_at, _} <- DateTime.from_iso8601(control["verified_at"]),
             true <- DateTime.diff(now, checked_at, :microsecond) in 0..300_000_000,
             {:ok, session} when not is_nil(session) <-
               Session
               |> Ash.Query.filter(id == ^control["session_id"])
               |> Ash.Query.lock(:for_update)
               |> Ash.read_one(authorize?: false) do
          current_control_token?(session, now) and
            session.account_id == control["account_id"] and session.state == :active and
            DateTime.compare(now, session.expires_at) == :lt and
            DateTime.compare(now, session.idle_expires_at) == :lt
        else
          _ -> false
        end
      end)

    if valid?, do: :ok, else: unavailable()
  end

  defp current_control_token?(session, now) do
    with {:ok, token} when not is_nil(token) <-
           Token
           |> Ash.Query.filter(
             jti == ^session.token_jti and account_id == ^session.account_id and purpose == "user"
           )
           |> Ash.read_one(authorize?: false),
         true <- DateTime.compare(now, token.expires_at) == :lt,
         false <-
           Token
           |> Ash.Query.filter(jti == ^session.token_jti and purpose == "revocation")
           |> Ash.exists?(authorize?: false) do
      true
    else
      _ -> false
    end
  end

  defp owner_reviews(current) do
    # This bounded phase has only these implemented business owners. A later
    # Domain must supply its own review before it can participate in apply.
    # Privacy is registered for the P8-17 proof purpose but does not participate
    # in reconciliation or own any reconciliation consequence.
    with true <-
           Enum.sort(Application.get_env(:new_you, :ash_domains, [])) ==
             Enum.sort([Identity, Communications, Audit, NewYou.Privacy]),
         {:ok, communications} <-
           Communications.review_identity_reconciliation(
             current.candidate_id,
             current.canonical_id
           ),
         {:ok, audit} <-
           Audit.review_identity_reconciliation(current.candidate_id, current.canonical_id) do
      {:ok, %{"communications" => communications, "audit" => audit}}
    else
      _ -> unavailable()
    end
  end

  defp account_versions(current, accounts) do
    Map.new([current.candidate_id, current.canonical_id], fn id ->
      a = accounts[id]

      {id,
       %{
         "security_version" => a.security_version,
         "reconciliation_version" => a.reconciliation_version
       }}
    end)
  end

  # Closing a stale case changes only its provenance. It must remain possible
  # after another case retires a candidate, under current authority for both.
  defp eligible_review_accounts(:rejected, _current, _accounts), do: :ok

  defp eligible_review_accounts(_decision, current, accounts),
    do: eligible_accounts(current, accounts)

  defp eligible_accounts(current, accounts) do
    eligible? =
      Enum.all?([current.candidate_id, current.canonical_id], fn id ->
        a = accounts[id]

        a.account_status == :open and a.security_posture == :normal and a.email_verified? and
          a.credential_status == :active and a.pmr_status == :active and
          is_nil(a.canonical_account_id)
      end)

    if eligible?, do: :ok, else: unavailable()
  end

  defp compensation_eligible(%{compensates_id: id} = request) when not is_nil(id) do
    case Ash.get(ReconciliationCase, id, authorize?: false) do
      {:ok, %{status: :applied, canonical_id: candidate}}
      when candidate == request.candidate_id ->
        :ok

      _ ->
        unavailable()
    end
  end

  defp compensation_eligible(_), do: :ok

  defp detect_or_replay(nil, authority, request) do
    Ash.create(
      ReconciliationCase,
      Map.merge(
        Map.take(request, [
          :operation_id,
          :candidate_id,
          :canonical_id,
          :detection_basis,
          :compensates_id
        ]),
        %{detected_by_id: authority.actor.id}
      ),
      action: :detect,
      authorize?: false
    )
  end

  defp detect_or_replay(existing, authority, request) do
    expected =
      Map.merge(
        Map.take(request, [:operation_id, :candidate_id, :canonical_id, :detection_basis]),
        %{compensates_id: request[:compensates_id], detected_by_id: authority.actor.id}
      )

    if Map.take(existing, Map.keys(expected)) == expected,
      do: {:ok, existing},
      else: unavailable()
  end

  defp locked_case(id),
    do:
      ReconciliationCase
      |> Ash.Query.filter(id == ^id)
      |> Ash.Query.lock(:for_update)
      |> Ash.read_one(authorize?: false)

  defp revoke_sessions(id) do
    sessions =
      Session
      |> Ash.Query.filter(account_id == ^id and state == :active)
      |> Ash.Query.sort(id: :asc)
      |> Ash.Query.lock(:for_update)
      |> Ash.read!(authorize?: false)

    Enum.each(sessions, &Ash.update!(&1, %{}, action: :revoke, authorize?: false))
    :ok
  end

  defp envelope(current, request, authority),
    do: %{
      attempt_id: request.operation_id,
      case_id: current.id,
      actor_id: authority.actor.id,
      target_id: current.candidate_id,
      grant_id: authority.grant.id,
      grant_version: authority.grant.version,
      canonical_grant_id: authority.canonical_grant.id,
      canonical_grant_version: authority.canonical_grant.version,
      session_id: authority.session.id,
      expected_version: request.expected_version,
      reason_code: :security_review
    }

  defp binding(current, request, authority),
    do:
      envelope(current, request, authority)
      |> Map.new(fn {k, v} ->
        {Atom.to_string(k), if(is_atom(v), do: Atom.to_string(v), else: v)}
      end)

  defp event(authority, status),
    do: %{
      "actor_id" => authority.actor.id,
      "grant_id" => authority.grant.id,
      "canonical_grant_id" => authority.canonical_grant.id,
      "status" => Atom.to_string(status),
      "at" => DateTime.to_iso8601(DateTime.utc_now())
    }

  defp outcome(current, request, admission, result) do
    Audit.establish_identity_security_obligation(%{
      source_operation_id: request.operation_id,
      source_occurred_at: DateTime.utc_now(),
      evidence_type: :identity_reconciliation_result,
      case_id: current.id,
      actor_id: admission.actor_id,
      target_id: current.candidate_id,
      grant_id: admission.grant_id,
      session_id: admission.session_id,
      reason_code: :security_review,
      admission_id: admission.id,
      outcome: result
    })
  end

  defp record_failure(initial, request, admission) do
    transaction(fn ->
      with {:ok, current} <- locked_case(initial.id),
           {:ok, existing} <-
             Audit.EvidenceObligation
             |> Ash.Query.filter(source_operation_id == ^request.operation_id)
             |> Ash.read_one(authorize?: false) do
        failed_outcome(existing, current, request, admission)
      end
    end)
  rescue
    _ -> unavailable()
  end

  defp failed_outcome(nil, current, request, admission),
    do: outcome(current, request, admission, :failed)

  defp failed_outcome(existing, _current, _request, _admission), do: {:ok, existing}

  defp keys?(request, required, optional \\ []) do
    Enum.all?(required, &Map.has_key?(request, &1)) and
      Enum.all?(Map.keys(request), &(&1 in (required ++ optional)))
  end

  defp transaction(callback) do
    case Ash.transact(@resources, callback) do
      {:ok, {:ok, result}} -> {:ok, result}
      {:ok, result} when is_map(result) -> {:ok, result}
      _ -> unavailable()
    end
  end

  defp unavailable, do: {:error, :reconciliation_unavailable}
end
