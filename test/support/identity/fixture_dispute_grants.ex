defmodule NewYou.Identity.FixtureDisputeGrants do
  @moduledoc false

  alias NewYou.{Identity, Repo}
  alias NewYou.Identity.{Account, IdentityGrant, Session}

  require Ash.Query

  @authority %{
    finance:
      {:finance_dispute_disclosure, :finance_disclosure_approver,
       :approve_finance_dispute_disclosure},
    audit_reader:
      {:audit_dispute_evidence, :audit_access_approver, :approve_audit_dispute_evidence}
  }
  @unavailable {:error, :disclosure_grant_unavailable}

  @doc false
  def issue(credentials, %{
        role: role,
        subject_account_id: subject,
        target_account_id: target,
        dispute_id: dispute,
        source_operation_id: operation,
        expires_at: %DateTime{} = expiry
      }) do
    transact(fn ->
      with {scope, _, _} <- Map.get(@authority, role),
           {:ok, approval} <- authorize_approver(credentials, role, subject, target),
           now = DateTime.utc_now(),
           :gt <- DateTime.compare(expiry, now) do
        Ash.create(
          IdentityGrant,
          %{
            role: role,
            scope: scope,
            subject_account_id: subject,
            target_account_id: target,
            approver_account_id: approval.subject_account_id,
            approval_grant_id: approval.id,
            dispute_id: dispute,
            source_operation_id: operation,
            starts_at: now,
            expires_at: expiry,
            reason_code: :security_review
          },
          action: :approve_fixture_dispute_disclosure,
          authorize?: false
        )
      else
        _ -> @unavailable
      end
    end)
  end

  def issue(_, _), do: @unavailable

  @doc false
  def revoke(credentials, grant_id) do
    transact(fn ->
      with {:ok, %IdentityGrant{} = grant} <- Ash.get(IdentityGrant, grant_id, authorize?: false),
           {:ok, approval} <-
             authorize_approver(
               credentials,
               grant.role,
               grant.subject_account_id,
               grant.target_account_id
             ) do
        Ash.update(
          grant,
          %{actor_id: approval.subject_account_id, reason_code: :security_review},
          action: :revoke,
          authorize?: false
        )
      else
        _ -> @unavailable
      end
    end)
  end

  @doc false
  def require_current(%{
        actor_id: actor,
        subject_id: target,
        source_id: dispute,
        operation_id: operation,
        finance_grant_id: finance,
        audit_grant_id: audit
      }) do
    with true <- Ash.DataLayer.in_transaction?(IdentityGrant),
         {:ok, finance} <- Ecto.UUID.cast(finance),
         {:ok, audit} <- Ecto.UUID.cast(audit),
         ids = [finance, audit],
         {:ok, grants} <-
           current_grants()
           |> Ash.Query.filter(
             id in ^ids and subject_account_id == ^actor and target_account_id == ^target and
               dispute_id == ^dispute and source_operation_id == ^operation
           )
           |> Ash.Query.sort(id: :asc)
           |> Ash.Query.lock("FOR SHARE")
           |> Ash.read(authorize?: false),
         %{
           ^finance => {:finance, :finance_dispute_disclosure},
           ^audit => {:audit_reader, :audit_dispute_evidence}
         } <- Map.new(grants, &{&1.id, {&1.role, &1.scope}}) do
      :ok
    else
      _ -> @unavailable
    end
  end

  def require_current(_), do: @unavailable

  defp authorize_approver(%{session_id: id} = credentials, role, subject, target) do
    with {_, approver_role, scope} <- Map.get(@authority, role),
         {:ok, %Session{account_id: actor}} <- Ash.get(Session, id, authorize?: false),
         true <- actor != subject,
         :ok <- lock_accounts([actor, subject, target]),
         {:ok, %{account_id: ^actor}} <- Identity.authorize_canonical_session(credentials),
         {:ok, %IdentityGrant{} = grant} <-
           current_grants()
           |> Ash.Query.filter(
             subject_account_id == ^actor and target_account_id == ^target and
               role == ^approver_role and scope == ^scope
           )
           |> Ash.Query.lock("FOR SHARE")
           |> Ash.read_one(authorize?: false) do
      {:ok, grant}
    else
      _ -> @unavailable
    end
  end

  defp authorize_approver(_, _, _, _), do: @unavailable

  # Revocation reuses the Support lifecycle's subject Account lock. Lock all
  # involved Accounts in the same order before validating the approver's session.
  defp lock_accounts(ids) do
    ids = Enum.uniq(ids)

    case Account
         |> Ash.Query.filter(id in ^ids)
         |> Ash.Query.sort(id: :asc)
         |> Ash.Query.lock(:for_update)
         |> Ash.read(authorize?: false) do
      {:ok, accounts} when length(accounts) == length(ids) -> :ok
      _ -> @unavailable
    end
  end

  defp current_grants do
    now = DateTime.utc_now()

    Ash.Query.filter(
      IdentityGrant,
      state == :active and is_nil(revoked_at) and starts_at <= ^now and expires_at > ^now
    )
  end

  defp transact(operation) do
    Repo.without_query_telemetry(fn ->
      case Ash.transact([Account, IdentityGrant], operation) do
        {:ok, {:ok, %IdentityGrant{} = grant}} -> {:ok, grant}
        _ -> @unavailable
      end
    end)
  end
end
