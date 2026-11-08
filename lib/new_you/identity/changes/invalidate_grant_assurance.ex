defmodule NewYou.Identity.Changes.InvalidateGrantAssurance do
  @moduledoc false
  use Ash.Resource.Change
  require Ash.Query
  import Ash.Expr, only: [expr: 1]

  alias Ash.Changeset
  alias NewYou.Identity.{Account, IdentityGrant, Session}

  @impl true
  def change(changeset, _opts, _context) do
    Changeset.before_action(changeset, &invalidate_current/1)
  end

  defp invalidate_current(changeset) do
    # Protected actions and revocation serialize on the subject Account first.
    # Read current grant state after that lock so an old revoke cannot clear
    # assurance established after a separately approved replacement grant.
    with {:ok, account} when not is_nil(account) <-
           Account
           |> Ash.Query.filter(id == ^changeset.data.subject_account_id)
           |> Ash.Query.lock(:for_update)
           |> Ash.read_one(authorize?: false),
         {:ok, grant} when not is_nil(grant) <-
           Ash.get(IdentityGrant, changeset.data.id, authorize?: false),
         true <- grant.subject_account_id == account.id do
      invalidate_or_replay(changeset, account, grant)
    else
      _ -> unavailable(changeset)
    end
  end

  defp invalidate_or_replay(changeset, _account, %{state: :revoked} = grant),
    do: Changeset.set_result(changeset, {:ok, grant})

  defp invalidate_or_replay(changeset, account, %{state: :active} = grant) do
    with {:ok, _} <-
           Ash.update(account, %{}, action: :invalidate_grant_assurance, authorize?: false),
         :ok <- clear_sessions(account.id) do
      changeset
      |> Changeset.force_change_attribute(:state, :revoked)
      |> Changeset.force_change_attribute(:revoked_at, DateTime.utc_now())
      |> Changeset.force_change_attribute(:version, grant.version + 1)
      |> Changeset.filter(expr(state == :active and version == ^grant.version))
    else
      _ -> unavailable(changeset)
    end
  end

  defp invalidate_or_replay(changeset, _account, _grant), do: unavailable(changeset)

  defp clear_sessions(account_id) do
    Session
    |> Ash.Query.filter(account_id == ^account_id and not is_nil(step_up_at))
    |> Ash.Query.sort(id: :asc)
    |> Ash.Query.lock(:for_update)
    |> Ash.read(authorize?: false)
    |> case do
      {:ok, sessions} -> Enum.reduce_while(sessions, :ok, &clear_session/2)
      _ -> :error
    end
  end

  defp clear_session(session, :ok) do
    case Ash.update(session, %{}, action: :clear_step_up, authorize?: false) do
      {:ok, _} -> {:cont, :ok}
      _ -> {:halt, :error}
    end
  end

  defp unavailable(changeset),
    do: Changeset.add_error(changeset, message: "grant revocation unavailable")
end
