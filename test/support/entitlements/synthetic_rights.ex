defmodule NewYou.Entitlements.SyntheticRights do
  @moduledoc """
  Entitlements' TEST-only convergence boundary. A correction affects only its
  paid source and component. Source and Privacy locks remain held until the
  Entitlements commit.
  """
  alias NewYou.Commerce.SyntheticCorrections
  alias NewYou.Entitlements.PlanRight
  alias NewYou.Privacy.SyntheticSuppression
  require Ash.Query

  @doc """
  Converge the current right set from committed Commerce and Privacy facts.
  Suppressed sources create no rights. Missing Privacy authority fails closed.
  """
  @spec converge(String.t()) :: {:ok, [PlanRight.t()]} | {:error, :grant_unavailable}
  def converge(id) do
    with false <- Ash.DataLayer.in_transaction?(PlanRight),
         {:ok, rights} when is_list(rights) <-
           Ash.transact(PlanRight, fn -> converge_from_source(id) end) do
      {:ok, rights}
    else
      _ -> {:error, :grant_unavailable}
    end
  end

  @doc """
  Apply only the effect committed by Commerce. A correction may end an
  existing right or leave it absent. Suppression still permits ending an
  existing right. Only the original grant may create rights.
  """
  @spec apply_correction(String.t()) :: :ok | {:error, :grant_unavailable}
  def apply_correction(id) do
    with false <- Ash.DataLayer.in_transaction?(PlanRight),
         {:ok, :ok} <-
           Ash.transact(PlanRight, fn -> apply_current_effect(id) end) do
      :ok
    else
      _ -> {:error, :grant_unavailable}
    end
  end

  defp converge_from_source(id) do
    with {:ok, scope} <- SyntheticCorrections.locked_paid_scope(id), do: converge_locked(scope)
  end

  defp apply_current_effect(id) do
    with {:ok, scope, effect} <- SyntheticCorrections.locked_effect(id),
         do: apply_effect(scope, effect)
  end

  defp apply_current_p1(id) do
    with {:ok, scope} <- SyntheticCorrections.locked_p1_grant_scope(id), do: apply_p1(scope)
  end

  defp apply_effect(scope, effect) do
    case SyntheticSuppression.locked_status(scope.recipient_id) do
      {:ok, status} when status in [:allowed, :suppressed] ->
        apply_committed_effect(scope, effect)

      _ ->
        {:error, :grant_unavailable}
    end
  end

  defp apply_committed_effect(scope, %{kind: :component_end, component: component}) do
    if MapSet.member?(scope.ended_components, component) do
      with {:ok, _} <- end_component(scope, component), do: :ok
    else
      {:error, :grant_unavailable}
    end
  end

  defp apply_committed_effect(_scope, %{kind: :excess_satisfied}), do: :ok

  @doc "Apply the original P1 grant under current Commerce and Privacy authority."
  @spec grant_p1(String.t()) :: {:ok, PlanRight.t() | :withheld} | {:error, :grant_unavailable}
  def grant_p1(consequence_id) do
    case Ash.transact(PlanRight, fn -> apply_current_p1(consequence_id) end) do
      {:ok, outcome} when outcome == :withheld or is_struct(outcome, PlanRight) -> {:ok, outcome}
      _ -> {:error, :grant_unavailable}
    end
  end

  defp apply_p1({:qualified, scope}) do
    case converge_locked(scope) do
      [] -> :withheld
      [right] -> right
      error -> error
    end
  end

  defp apply_p1({:legacy, scope}) do
    case SyntheticSuppression.locked_status(scope.recipient_id) do
      {:ok, :allowed} ->
        with {:ok, right} <- Ash.create(PlanRight, scope, action: :grant, authorize?: false) do
          right
        end

      {:ok, :suppressed} ->
        :withheld

      _ ->
        {:error, :grant_unavailable}
    end
  end

  defp converge_locked(scope) do
    case SyntheticSuppression.locked_status(scope.recipient_id) do
      {:ok, :allowed} -> converge_components(scope)
      {:ok, :suppressed} -> []
      _ -> {:error, :grant_unavailable}
    end
  end

  defp converge_components(scope) do
    Enum.reduce_while(scope.components, [], fn component, rights ->
      case apply_component(scope, component) do
        {:ok, nil} -> {:cont, rights}
        {:ok, right} -> {:cont, [right | rights]}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      rights when is_list(rights) -> Enum.reverse(rights)
      error -> error
    end
  end

  defp apply_component(scope, component) do
    if MapSet.member?(scope.ended_components, component) do
      end_component(scope, component)
    else
      attrs = Map.take(scope, [:purchase_id, :payment_id, :recipient_id])

      Ash.create(PlanRight, Map.put(attrs, :component, component),
        action: :grant,
        authorize?: false
      )
    end
  end

  defp end_component(scope, component) do
    query =
      Ash.Query.filter(
        PlanRight,
        purchase_id == ^scope.purchase_id and component == ^component
      )

    case Ash.read_one(query, authorize?: false) do
      {:ok, %{state: :held_unconsumed} = right} ->
        Ash.update(right, %{}, action: :end_component, authorize?: false)

      result ->
        result
    end
  end
end
