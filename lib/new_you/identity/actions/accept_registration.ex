defmodule NewYou.Identity.Actions.AcceptRegistration do
  use Ash.Resource.Actions.Implementation

  @test_build Mix.env() == :test

  @operation_lifetime_seconds 24 * 60 * 60
  @verifier_provider "AshAuthentication.Argon2Provider"
  @verifier_version "argon2_elixir-4.1.3"
  @verification_token_lifetime {24, :hours}

  @impl true
  def run(input, _opts, _context) do
    with {:ok, admission} <-
           NewYou.Identity.validate_registration_acceptance(
             input.arguments.registration_input,
             input.arguments.pmr
           ) do
      accept(admission)
    end
  end

  defp accept(admission) do
    registration = admission.registration_input
    committed_at = NewYou.Identity.registration_now()

    with {:ok, account} <- create_account(registration, admission.pmr, committed_at),
         {:ok, verification_proof, claims} <- issue_verification_proof(account),
         {:ok, _intent} <-
           establish_verification_intent(registration, committed_at, claims, verification_proof),
         {:ok, _obligation} <-
           NewYou.Audit.establish_registration_obligation(
             %{
               source_operation_id: registration.operation_id,
               source_occurred_at: committed_at
             },
             authorize?: false
           ),
         {:ok, _operation} <-
           create_operation(%{
             operation_id: registration.operation_id,
             request_fingerprint: admission.request_fingerprint,
             fingerprint_key_version: admission.fingerprint_key_version,
             password_verifier: account.hashed_password,
             verifier_provider: @verifier_provider,
             verifier_version: @verifier_version,
             outcome: :verification_pending,
             committed_at: committed_at,
             expires_at: DateTime.add(committed_at, @operation_lifetime_seconds, :second),
             created_account_id: account.id
           }) do
      # The checkpoint is compiled out of non-TEST builds. It runs after all
      # owner writes, still inside the existing Ash acceptance transaction.
      if @test_build do
        NewYou.Proof.RegistrationSeam.checkpoint()
      end

      {:ok,
       %{
         status: :verification_pending,
         account_id: account.id,
         verification_proof: verification_proof
       }}
    end
  end

  defp create_account(input, pmr, committed_at) do
    attributes = %{
      first_name: input.first_name,
      surname: input.surname,
      email: input.email,
      preferred_language: input.preferred_language,
      confirmed_age_18?: input.confirmed_age_18?,
      terms_version_id: input.terms_version_id,
      privacy_version_id: input.privacy_version_id,
      legal_accepted_at: committed_at,
      acceptance_locale: input.acceptance_locale,
      pmr: pmr,
      password: input.password
    }

    Ash.create(NewYou.Identity.Account, attributes,
      action: :register,
      domain: NewYou.Identity,
      authorize?: false
    )
  end

  defp create_operation(attributes) do
    Ash.create(NewYou.Identity.RegistrationOperation, attributes,
      action: :bind,
      domain: NewYou.Identity,
      authorize?: false
    )
  end

  defp issue_verification_proof(account) do
    case AshAuthentication.Jwt.token_for_user(
           account,
           %{"purpose" => "email_verification"},
           purpose: :email_verification,
           token_lifetime: @verification_token_lifetime,
           domain: NewYou.Identity,
           authorize?: false
         ) do
      {:ok, token, claims} -> {:ok, token, claims}
      _ -> {:error, :token_creation_failed}
    end
  rescue
    _ -> {:error, :token_creation_failed}
  end

  defp establish_verification_intent(registration, committed_at, claims, verification_proof) do
    NewYou.Communications.establish_verification(
      %{
        source_operation_id: registration.operation_id,
        source_reference: claims["jti"],
        destination: registration.email,
        destination_provenance: "identity_challenge_issuance",
        destination_authorized_at: committed_at,
        locale: Atom.to_string(registration.preferred_language)
      },
      verification_proof
    )
  end
end
