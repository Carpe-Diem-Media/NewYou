alias Ecto.Adapters.SQL.Sandbox
alias NewYou.Commerce.{AssessmentAdmissions, OfferAdmission}
alias NewYou.Entitlements.SyntheticAssessmentCredit
alias NewYou.Proof.PlanPaymentObservation
alias NewYou.Repo

[stage, id] = System.argv()
:ok = Sandbox.checkout(Repo, sandbox: false)

try do
  succeeded =
    case stage do
      "replay" ->
        input = IO.gets("") |> Jason.decode!()

        Application.put_env(
          :new_you,
          :identity_token_signing_secret,
          Base.decode64!(input["signing_key"])
        )

        credentials = fn party ->
          %{
            session_id: input[party]["session_id"],
            token: input[party]["token"]
          }
        end

        scope =
          PlanPaymentObservation.produce(%{
            scope: :s1_purchase_parties,
            operation_id: input["operation_id"],
            payer_id: input["payer_id"],
            recipient_id: input["recipient_id"]
          })

        request = %{
          operation_id: input["operation_id"],
          quote_id: input["quote_id"],
          disclosure_fingerprint: Base.decode64!(input["disclosure_fingerprint"])
        }

        case OfferAdmission.accept(
               %{
                 payer: credentials.("payer"),
                 recipient: credentials.("recipient"),
                 authorization: scope
               },
               request
             ) do
          {:ok, %{purchase_id: ^id, attempt_id: attempt, terms: %{amount_minor: amount}}} ->
            attempt == input["attempt_id"] and amount == input["amount_minor"]

          _ ->
            false
        end

      "grant" ->
        case AssessmentAdmissions.open_credit_consequence(id) do
          {:ok, consequence} when not is_nil(consequence) ->
            match?(
              {:ok, %{state: :held_unconsumed, component: :assessment}},
              SyntheticAssessmentCredit.grant(consequence)
            )

          _ ->
            false
        end

      "ack" ->
        with {:ok, consequence} when not is_nil(consequence) <-
               AssessmentAdmissions.open_credit_consequence(id),
             :ok <- AssessmentAdmissions.acknowledge_credit(consequence) do
          AssessmentAdmissions.open_credit_consequence(id) == {:ok, nil}
        else
          _ -> false
        end
    end

  unless succeeded, do: raise("versioned admission could not recover from durable state")
  IO.puts("S1_COMPLETED")
after
  Sandbox.checkin(Repo)
end
