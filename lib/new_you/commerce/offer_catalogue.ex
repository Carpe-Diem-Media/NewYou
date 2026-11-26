defmodule NewYou.Commerce.OfferCatalogue do
  @moduledoc """
  Commerce owns each once-off offer's priced terms, allocation and approval.
  Publishing a new version supersedes the preceding version in one transaction.
  S1 permits only qualified TEST configuration. An approved row here has no
  commercial activation outside that scope.
  """

  alias NewYou.Commerce.OfferVersion
  require Ash.Query

  @type product :: :assessment | :plan | :bundle
  @type component :: :assessment | :plan
  @type allocation :: %{
          list_minor: pos_integer(),
          discount_minor: non_neg_integer(),
          amount_minor: pos_integer()
        }

  @type terms :: %{
          offer_id: Ecto.UUID.t(),
          product: product(),
          price_version: String.t(),
          currency: String.t(),
          amount_minor: pos_integer(),
          list_minor: pos_integer(),
          discount_minor: non_neg_integer(),
          promotion_version: String.t() | nil,
          allocation_version: String.t() | nil,
          components: %{optional(component()) => allocation()}
        }

  @doc "Create one immutable draft from qualified TEST configuration. A used version identifier cannot be overwritten."
  @spec draft(term()) :: {:ok, OfferVersion.t()} | {:error, :offer_unavailable}
  def draft(evidence) do
    with {:ok, %{scope: :s1_offer_draft, terms: attrs}} <- verify(evidence),
         {:ok, offer} <- Ash.create(OfferVersion, attrs, action: :draft, authorize?: false) do
      {:ok, offer}
    else
      _ -> {:error, :offer_unavailable}
    end
  end

  @doc """
  Publish a specific immutable draft with distinct allocation approval for a
  bundle and disclosure approvals for EN and AF. On contention, retry the
  operation against the current catalogue. Lost acknowledgement can replay the
  same approval while the offer remains approved.
  """
  @spec approve(term()) :: {:ok, OfferVersion.t()} | {:error, :offer_unavailable}
  def approve(evidence) do
    with {:ok, %{scope: :s1_offer_approval, offer_id: id} = fields} <- verify(evidence),
         {:ok, %OfferVersion{product: product}} <- Ash.get(OfferVersion, id, authorize?: false),
         {:ok, %OfferVersion{} = offer} <-
           Ash.transact(OfferVersion, fn -> approve_locked(product, id, fields) end) do
      {:ok, offer}
    else
      _ -> {:error, :offer_unavailable}
    end
  end

  @doc "Withdraw an approved offer using qualified TEST evidence. Historical quotes retain their original terms."
  @spec withdraw(term()) :: {:ok, OfferVersion.t()} | {:error, :offer_unavailable}
  def withdraw(evidence) do
    with {:ok, %{scope: :s1_offer_withdrawal, offer_id: id, withdrawal_id: withdrawal}} <-
           verify(evidence),
         {:ok, %OfferVersion{} = offer} <-
           Ash.transact(OfferVersion, fn -> withdraw_locked(id, withdrawal) end) do
      {:ok, offer}
    else
      _ -> {:error, :offer_unavailable}
    end
  end

  @doc "Return currently effective, approved pricing for the requested product, without quote or actor data."
  @spec effective(product()) :: {:ok, terms()} | {:error, :offer_unavailable}
  def effective(product) when product in [:plan, :assessment, :bundle] do
    case current(product, nil) do
      {:ok, offer} -> {:ok, terms(offer)}
      error -> error
    end
  end

  def effective(_), do: {:error, :offer_unavailable}

  @doc false
  @spec current(product(), String.t() | nil) ::
          {:ok, OfferVersion.t()} | {:error, :offer_unavailable}
  def current(product, lock) do
    with {:ok, %OfferVersion{} = offer} <- approved(product, lock),
         true <- effective?(offer) do
      {:ok, offer}
    else
      _ -> {:error, :offer_unavailable}
    end
  end

  @doc false
  @spec effective?(OfferVersion.t()) :: boolean()
  def effective?(offer), do: effective?(offer, DateTime.utc_now())

  @doc false
  @spec effective?(OfferVersion.t(), DateTime.t()) :: boolean()
  def effective?(%OfferVersion{state: :approved} = offer, now) do
    DateTime.compare(offer.approved_at, now) != :gt and
      (is_nil(offer.expires_at) or DateTime.compare(offer.expires_at, now) == :gt)
  end

  def effective?(%OfferVersion{}, _), do: false

  @doc false
  @spec terms(OfferVersion.t()) :: terms()
  def terms(offer) do
    components =
      [
        assessment: {offer.assessment_list_minor, offer.assessment_discount_minor},
        plan: {offer.plan_list_minor, offer.plan_discount_minor}
      ]
      |> Map.new(fn {component, {list, discount}} ->
        {component, %{list_minor: list, discount_minor: discount, amount_minor: list - discount}}
      end)
      |> Map.reject(fn {_component, value} -> value.list_minor == 0 end)

    %{
      offer_id: offer.id,
      product: offer.product,
      price_version: offer.price_version,
      currency: offer.currency,
      amount_minor: offer.amount_minor,
      list_minor: offer.assessment_list_minor + offer.plan_list_minor,
      discount_minor: offer.assessment_discount_minor + offer.plan_discount_minor,
      promotion_version: offer.promotion_version,
      allocation_version: offer.allocation_version,
      components: components
    }
  end

  defp approve_locked(product, id, fields) do
    attrs =
      Map.take(fields, [
        :approval_id,
        :allocation_approval_id,
        :disclosure_en_id,
        :disclosure_af_id
      ])

    with {:ok, current} <- approved(product, "FOR UPDATE"),
         {:ok, %OfferVersion{} = candidate} <- locked(id) do
      publish(candidate, current, attrs)
    end
  end

  defp publish(%{state: :approved} = candidate, _current, attrs) do
    if Map.take(candidate, Map.keys(attrs)) == attrs,
      do: candidate,
      else: {:error, :offer_unavailable}
  end

  defp publish(%{state: :draft} = candidate, current, attrs) do
    with :ok <- supersede(current),
         {:ok, offer} <-
           Ash.update(candidate, Map.put(attrs, :approved_at, DateTime.utc_now()),
             action: :approve,
             authorize?: false
           ) do
      offer
    end
  end

  defp publish(_, _, _), do: {:error, :offer_unavailable}

  defp supersede(nil), do: :ok

  defp supersede(offer) do
    with {:ok, _} <- Ash.update(offer, %{}, action: :supersede, authorize?: false), do: :ok
  end

  defp withdraw_locked(id, withdrawal) do
    case locked(id) do
      {:ok, %{state: :withdrawn, withdrawal_id: ^withdrawal} = offer} ->
        offer

      {:ok, %{state: :approved} = offer} ->
        with {:ok, withdrawn} <-
               Ash.update(offer, %{withdrawal_id: withdrawal},
                 action: :withdraw,
                 authorize?: false
               ) do
          withdrawn
        end

      _ ->
        {:error, :offer_unavailable}
    end
  end

  defp locked(id) do
    OfferVersion
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.lock(:for_update)
    |> Ash.read_one(authorize?: false)
  end

  defp approved(product, lock) do
    OfferVersion
    |> Ash.Query.filter(product == ^product and state == :approved)
    |> Ash.Query.lock(lock)
    |> Ash.read_one(authorize?: false)
  end

  if Mix.env() == :test do
    defp verify(evidence), do: NewYou.Proof.PlanPaymentObservation.verify(evidence)
  else
    defp verify(_), do: {:error, :offer_unavailable}
  end
end
