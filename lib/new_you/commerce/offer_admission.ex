defmodule NewYou.Commerce.OfferAdmission do
  @moduledoc """
  Commerce offers an exact disclosure, accepts it once and serves the immutable
  snapshot from Purchase and its quote. Admission binds current Identity
  authority to the operation and consults the Assessment owners under lock.
  S1 permits only TEST purchases with qualified party evidence.
  """

  alias NewYou.Commerce.{
    AssessmentAdmissions,
    OfferCatalogue,
    OfferVersion,
    Purchase,
    PurchaseQuote
  }

  alias NewYou.Identity

  @type evidence :: %{quote_id: Ecto.UUID.t(), state: atom(), decision: atom() | nil}

  require Ash.Query

  @offer_products if(Mix.env() == :dev, do: [:plan], else: [:plan, :assessment, :bundle])

  @type terms :: %{
          required(:quote_id) => Ecto.UUID.t(),
          required(:operation_id) => Ecto.UUID.t(),
          required(:language) => :en | :af,
          required(:disclosure_id) => Ecto.UUID.t(),
          required(:disclosure_fingerprint) => binary(),
          optional(atom()) => term()
        }

  @type snapshot :: %{
          purchase_id: Ecto.UUID.t(),
          attempt_id: Ecto.UUID.t(),
          payer_id: Ecto.UUID.t(),
          recipient_id: Ecto.UUID.t(),
          accepted_at: DateTime.t(),
          terms: terms()
        }

  @type denial ::
          :purchase_unavailable
          | :acceptance_conflict
          | :offer_unavailable
          | :stale_quote
          | :assessment_unavailable
          | {:assessment_unavailable, %{product: :plan, price_version: String.t()}}

  @doc """
  Quote an effective version in EN or AF. Only the signed operation's verified
  payer and recipient can obtain the quote. Repeating the operation returns its
  original terms if the product and language match.
  """
  @spec quote(map(), %{product: OfferCatalogue.product(), language: :en | :af}) ::
          {:ok, terms()} | {:error, denial()}
  def quote(authority, %{product: product, language: language} = request)
      when product in @offer_products and language in [:en, :af] and
             map_size(request) == 2 do
    transaction(fn ->
      with {:ok, parties} <- authorize_parties(authority),
           :ok <- current_parties_privacy(parties),
           {:ok, existing} <- quote_by_operation(parties.operation_id, nil) do
        offer_quote(existing, parties, product, language)
      end
    end)
  end

  def quote(_, _), do: {:error, :purchase_unavailable}

  @doc """
  Accept exactly the offered quote and disclosure fingerprint. A stale quote
  stays stale. Missing Assessment evidence can be retried. Exact replay returns
  the original snapshot even after repricing. No charge or grant occurs here.
  """
  @spec accept(map(), %{
          operation_id: Ecto.UUID.t(),
          quote_id: Ecto.UUID.t(),
          disclosure_fingerprint: binary()
        }) ::
          {:ok, snapshot()} | {:error, denial()}
  def accept(
        authority,
        %{operation_id: op, quote_id: id, disclosure_fingerprint: fingerprint} = request
      )
      when map_size(request) == 3 do
    transaction(fn -> accept_for(authority, op, id, fingerprint) end)
  end

  def accept(_, _), do: {:error, :purchase_unavailable}

  @doc "Read the original disclosure as its verified payer or canonical recipient."
  @spec read_quote(map(), Ecto.UUID.t()) :: {:ok, terms()} | {:error, :purchase_unavailable}
  def read_quote(credentials, quote_id),
    do: read_as_party(PurchaseQuote, credentials, quote_id, &quote_projection/1)

  @doc "Read the accepted versioned snapshot as its verified payer or canonical recipient."
  @spec snapshot(map(), Ecto.UUID.t()) :: {:ok, snapshot()} | {:error, :purchase_unavailable}
  def snapshot(credentials, purchase_id),
    do: read_as_party(Purchase, credentials, purchase_id, &bound_snapshot/1)

  @doc """
  Read the admission finding with a TEST owner grant for this exact quote and
  current account. The projection carries no parties, source data or history.
  """
  @spec review_admission(map(), term()) :: {:ok, evidence()} | {:error, :purchase_unavailable}
  if Mix.env() == :test do
    def review_admission(credentials, grant) do
      case NewYou.Proof.PlanPaymentObservation.verify(grant) do
        {:ok, %{scope: :s1_admission_review, quote_id: id, account_id: owner}} ->
          transaction(fn -> scoped_review(credentials, id, owner) end)

        _ ->
          {:error, :purchase_unavailable}
      end
    end

    defp scoped_review(credentials, id, owner) do
      with {:ok, %{account_id: ^owner}} <- Identity.authorize_canonical_session(credentials),
           {:ok, %PurchaseQuote{} = quote} <- Ash.get(PurchaseQuote, id, authorize?: false) do
        %{quote_id: id, state: quote.state, decision: quote.decision}
      else
        _ -> {:error, :purchase_unavailable}
      end
    end
  else
    def review_admission(_, _), do: {:error, :purchase_unavailable}
  end

  @doc false
  @spec accepted_terms(Purchase.t()) :: {:ok, terms()} | {:error, :purchase_unavailable}
  def accepted_terms(%Purchase{quote_id: id} = purchase) when not is_nil(id) do
    with {:ok, %PurchaseQuote{state: :accepted} = quote} <-
           Ash.get(PurchaseQuote, id, authorize?: false),
         true <- same_parties?(quote, purchase),
         true <- quote.operation_id == purchase.operation_id,
         {:ok, offer} <- fetch_offer(quote, nil),
         true <- approved_development_offer?(offer),
         true <-
           offer.price_version == purchase.price_version and
             offer.amount_minor == purchase.amount_minor and
             offer.currency == purchase.currency and exact_disclosure?(quote, offer) do
      {:ok, disclosed(quote, offer)}
    else
      _ -> {:error, :purchase_unavailable}
    end
  end

  def accepted_terms(_), do: {:error, :purchase_unavailable}

  @doc false
  @spec accepted_component_minor(terms(), atom()) :: pos_integer() | nil
  def accepted_component_minor(%{components: components}, component)
      when component in [:plan, :assessment] do
    case Map.get(components, component) do
      %{amount_minor: amount} -> amount
      nil -> nil
    end
  end

  def accepted_component_minor(_, _), do: nil

  if Mix.env() == :test do
    defp authorize_parties(authority),
      do: NewYou.Identity.SyntheticPurchaseParties.authorize(authority)

    defp current_privacy(id) do
      case NewYou.Privacy.SyntheticSuppression.locked_status(id) do
        {:ok, :allowed} -> :ok
        _ -> {:error, :purchase_unavailable}
      end
    end
  else
    if Mix.env() == :dev do
      defp authorize_parties(%{credentials: credentials}) do
        with {:ok, %{"payer_id" => id, "operation_id" => operation}} <-
               NewYou.Commerce.PaystackDevelopmentSource.authorize(credentials) do
          {:ok, %{operation_id: operation, payer_id: id, recipient_id: id}}
        end
      end

      defp authorize_parties(_), do: {:error, :purchase_unavailable}

      defp current_privacy(id), do: NewYou.Privacy.require_development_checkout_subject_locked(id)
    else
      defp authorize_parties(_), do: {:error, :purchase_unavailable}
      defp current_privacy(_), do: {:error, :purchase_unavailable}
    end
  end

  defp accept_for(authority, operation, id, fingerprint) do
    with {:ok, %{operation_id: ^operation} = parties} <- authorize_parties(authority),
         {:ok, %PurchaseQuote{} = quote} <- quote_by_operation(operation, :for_update),
         true <- same_parties?(quote, parties),
         :ok <- current_parties_privacy(quote),
         {:ok, offer} <- fetch_offer(quote, "FOR SHARE"),
         true <- approved_development_offer?(offer) do
      if quote.id == id and quote.disclosure_fingerprint == fingerprint and
           exact_disclosure?(quote, offer),
         do: accept_quote(quote, offer),
         else: {:refused, :acceptance_conflict}
    else
      {:ok, %{operation_id: _}} -> {:refused, :acceptance_conflict}
      _ -> {:error, :purchase_unavailable}
    end
  end

  defp read_as_party(resource, credentials, id, project) do
    case Ecto.UUID.cast(id) do
      {:ok, canonical_id} ->
        transaction(fn -> party_projection(resource, credentials, canonical_id, project) end)

      :error ->
        {:error, :purchase_unavailable}
    end
  end

  defp party_projection(resource, credentials, id, project) do
    with {:ok, %{account_id: account}} <- Identity.authorize_canonical_session(credentials),
         {:ok, record} when not is_nil(record) <-
           resource
           |> Ash.Query.filter(id == ^id and (payer_id == ^account or recipient_id == ^account))
           |> Ash.read_one(authorize?: false),
         :ok <- current_parties_privacy(record) do
      project.(record)
    else
      _ -> {:error, :purchase_unavailable}
    end
  end

  defp quote_projection(quote) do
    with {:ok, offer} <- fetch_offer(quote, nil),
         true <- exact_disclosure?(quote, offer) do
      disclosed(quote, offer)
    else
      _ -> {:error, :purchase_unavailable}
    end
  end

  @doc false
  @spec bound_snapshot(Purchase.t()) :: snapshot() | {:error, :purchase_unavailable}
  def bound_snapshot(purchase) do
    with {:ok, terms} <- accepted_terms(purchase), do: snapshot_for(purchase, terms)
  end

  @doc false
  @spec current_parties_privacy(%{
          required(:payer_id) => Ecto.UUID.t(),
          required(:recipient_id) => Ecto.UUID.t(),
          optional(atom()) => term()
        }) :: :ok | {:error, :purchase_unavailable}
  def current_parties_privacy(%{payer_id: payer, recipient_id: recipient}) do
    [payer, recipient]
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.reduce_while(:ok, fn id, :ok ->
      case current_privacy(id) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp transaction(operation) do
    case transact(operation) do
      {:ok, {:refused, reason}} -> {:error, reason}
      {:ok, result} when is_map(result) -> {:ok, result}
      _ -> {:error, :purchase_unavailable}
    end
  end

  if Mix.env() == :dev do
    defp transact(operation) do
      NewYou.Repo.without_query_telemetry(fn -> Ash.transact(Purchase, operation) end)
    end
  else
    defp transact(operation), do: Ash.transact(Purchase, operation)
  end

  defp offer_quote(nil, parties, product, language) do
    with {:ok, offer} <- checkout_offer(OfferCatalogue.current(product, "FOR SHARE")),
         attrs = disclosure_attributes(parties, offer, language),
         {:ok, quoted} <-
           Ash.create(PurchaseQuote, attrs, action: :offer, authorize?: false) do
      cond do
        not same_parties?(quoted, parties) -> {:error, :purchase_unavailable}
        Map.take(quoted, Map.keys(attrs)) == attrs -> disclosed(quoted, offer)
        true -> {:refused, :acceptance_conflict}
      end
    else
      {:error, :offer_unavailable} -> {:refused, :offer_unavailable}
      {:error, _} = error -> error
    end
  end

  defp offer_quote(
         %PurchaseQuote{} = quote,
         %{payer_id: payer, recipient_id: recipient},
         product,
         language
       )
       when quote.payer_id == payer and quote.recipient_id == recipient do
    with ^language <- quote.language,
         {:ok, %OfferVersion{product: ^product} = offer} <-
           checkout_offer(fetch_offer(quote, nil)),
         true <- exact_disclosure?(quote, offer) do
      disclosed(quote, offer)
    else
      _ -> {:refused, :acceptance_conflict}
    end
  end

  defp offer_quote(%PurchaseQuote{}, _, _, _), do: {:error, :purchase_unavailable}

  if Mix.env() == :dev do
    defp checkout_offer({:ok, offer} = result) do
      if approved_development_offer?(offer), do: result, else: {:error, :offer_unavailable}
    end

    defp checkout_offer(error), do: error

    defp approved_development_offer?(%OfferVersion{
           id: id,
           product: :plan,
           amount_minor: 39_900,
           currency: "ZAR",
           approval_id: approval,
           disclosure_en_id: en,
           disclosure_af_id: af
         }) do
      match?(
        {:ok,
         %{
           "offer_id" => ^id,
           "approval_id" => ^approval,
           "disclosure_en_id" => ^en,
           "disclosure_af_id" => ^af
         }},
        NewYou.LocalConfig.paystack_development_plan()
      )
    end

    defp approved_development_offer?(_), do: false
  else
    defp checkout_offer(result), do: result
  end

  defp accept_quote(%{state: :accepted} = quote, offer) do
    version = offer.price_version
    amount = offer.amount_minor

    with {:ok, %Purchase{price_version: ^version, amount_minor: ^amount} = purchase} <-
           Purchase |> Ash.Query.filter(quote_id == ^quote.id) |> Ash.read_one(authorize?: false) do
      snapshot_for(purchase, disclosed(quote, offer))
    end
  end

  defp accept_quote(%{state: :stale}, _), do: {:refused, :stale_quote}
  defp accept_quote(%{state: :rejected}, offer), do: {:refused, assessment_denial(offer)}

  defp accept_quote(%PurchaseQuote{} = quote, %OfferVersion{} = offer) do
    with true <- OfferCatalogue.effective?(offer),
         :ok <- eligible(quote, offer) do
      accepted_at = DateTime.utc_now()

      if OfferCatalogue.effective?(offer, accepted_at),
        do: persist_acceptance(quote, offer, accepted_at),
        else: stale(quote)
    else
      false -> stale(quote)
      {:denied, cause} -> refuse_assessment(quote, offer, cause)
    end
  end

  defp persist_acceptance(quote, offer, accepted_at) do
    attrs = %{
      operation_id: quote.operation_id,
      payer_id: quote.payer_id,
      recipient_id: quote.recipient_id,
      price_version: offer.price_version,
      amount_minor: offer.amount_minor,
      currency: offer.currency,
      acceptance_time: accepted_at,
      quote_id: quote.id
    }

    case Ash.create(Purchase, attrs, action: :accept, authorize?: false) do
      {:ok, %Purchase{quote_id: id} = purchase} when id == quote.id ->
        with :ok <- admit(purchase, offer),
             {:ok, accepted} <- decide(quote, :accepted, nil) do
          snapshot_for(purchase, disclosed(accepted, offer))
        end

      {:ok, %Purchase{}} ->
        {:refused, :acceptance_conflict}

      {:error, _} = error ->
        error
    end
  end

  defp eligible(_, %{product: :plan}), do: :ok
  defp eligible(quote, _), do: AssessmentAdmissions.eligible?(quote.recipient_id)
  defp admit(_, %{product: :plan}), do: :ok
  defp admit(purchase, _), do: AssessmentAdmissions.admit(purchase)

  defp stale(quote) do
    with {:ok, _} <- decide(quote, :stale, :offer_changed), do: {:refused, :stale_quote}
  end

  defp refuse_assessment(quote, offer, cause) do
    state =
      if cause in [:credit_evidence_unavailable, :delivery_evidence_unavailable],
        do: :reconciling,
        else: :rejected

    with {:ok, _} <- decide(quote, state, cause), do: {:refused, assessment_denial(offer)}
  end

  defp assessment_denial(%{product: :bundle}) do
    case OfferCatalogue.effective(:plan) do
      {:ok, terms} -> {:assessment_unavailable, Map.take(terms, [:product, :price_version])}
      _ -> :assessment_unavailable
    end
  end

  defp assessment_denial(_), do: :assessment_unavailable

  defp decide(quote, state, cause) do
    Ash.update(quote, %{state: state, decision: cause}, action: :decide, authorize?: false)
  end

  defp quote_by_operation(id, lock) do
    PurchaseQuote
    |> Ash.Query.filter(operation_id == ^id)
    |> Ash.Query.lock(lock)
    |> Ash.read_one(authorize?: false)
  end

  defp fetch_offer(quote, lock) do
    OfferVersion
    |> Ash.Query.filter(id == ^quote.offer_id)
    |> Ash.Query.lock(lock)
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, %OfferVersion{} = offer} -> {:ok, offer}
      _ -> {:error, :purchase_unavailable}
    end
  end

  defp same_parties?(left, right),
    do: left.payer_id == right.payer_id and left.recipient_id == right.recipient_id

  defp disclosed(quote, offer) do
    offer
    |> OfferCatalogue.terms()
    |> Map.merge(
      Map.take(quote, [:operation_id, :language, :disclosure_id, :disclosure_fingerprint])
    )
    |> Map.put(:quote_id, quote.id)
  end

  defp disclosure_attributes(parties, offer, language) do
    disclosure_id = disclosure_id(offer, language)

    fields =
      Map.merge(Map.take(parties, [:operation_id, :payer_id, :recipient_id]), %{
        offer_id: offer.id,
        language: language,
        disclosure_id: disclosure_id
      })

    fingerprint =
      :crypto.hash(
        :sha256,
        :erlang.term_to_binary({:s1_disclosure, fields, OfferCatalogue.terms(offer)}, [
          :deterministic
        ])
      )

    Map.put(fields, :disclosure_fingerprint, fingerprint)
  end

  defp exact_disclosure?(quote, offer) do
    attrs = disclosure_attributes(quote, offer, quote.language)
    Map.take(quote, Map.keys(attrs)) == attrs
  end

  defp disclosure_id(offer, :en), do: offer.disclosure_en_id
  defp disclosure_id(offer, :af), do: offer.disclosure_af_id

  defp snapshot_for(purchase, terms) do
    purchase
    |> Map.take([:attempt_id, :payer_id, :recipient_id, :accepted_at])
    |> Map.merge(%{purchase_id: purchase.id, terms: terms})
  end
end
