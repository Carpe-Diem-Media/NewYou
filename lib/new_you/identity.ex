defmodule NewYou.Identity do
  use Ash.Domain, otp_app: :new_you

  @moduledoc """
  Identity owns Accounts, credentials, PMR assignment, purpose-bound Tokens,
  durable Sessions, and registration and resend operation bindings.

  Registration coordinates with Audit and Communications through their owner
  interfaces. Communications owns MessageIntents and protected envelopes; Audit owns
  the initial registration evidence obligation and durable schedule. Identity does
  not own delivery execution or Audit materialisation.
  """

  require Ash.Query

  alias NewYou.Identity.{
    Account,
    Email,
    PMR,
    RegistrationBinding,
    RegistrationOperation,
    ResendOperation,
    RegistrationResult,
    Token,
    IdentityGrant
  }

  @operation_lifetime_seconds 24 * 60 * 60
  @registration_operation_expiry_batch_size 100
  @verifier_provider "AshAuthentication.Argon2Provider"
  @verifier_version "argon2_elixir-4.1.3"
  @verification_token_lifetime {24, :hours}
  @development_terms_id "NEWYOU-TERMS-EN-DEV-2026-10-27-001"
  @development_privacy_id "NEWYOU-PRIVACY-EN-DEV-2026-10-27-001"

  resources do
    resource Account
    resource Token
    resource NewYou.Identity.DeviceAssurance

    resource RegistrationOperation do
      define :accept_new_registration, action: :accept_registration
    end

    resource NewYou.Identity.ResendOperation
    resource NewYou.Identity.Session
    resource IdentityGrant
    resource NewYou.Identity.ReconciliationCase
    resource NewYou.Identity.RecoveryCase
  end

  @doc "Start or reuse a recovery case with a neutral result. Requests alone do not change Account security or access. A missing channel remains unproven until the existing Identity verification boundary establishes it."
  @spec request_recovery(term(), term(), term()) :: :ok
  def request_recovery(email, locale, operation_id),
    do: NewYou.Identity.Recovery.request(email, locale, operation_id)

  @doc "Accept current proof explicitly. Proof consumption and case assurance commit together."
  @spec submit_recovery_proof(term(), term()) ::
          {:ok, :accepted | :failed | :expired} | {:error, :recovery_unavailable}
  def submit_recovery_proof(proof, operation_id),
    do: recovery_action(:submit_recovery_proof, %{proof: proof, operation_id: operation_id})

  @doc "Complete ordinary recovery once. An unchanged operation retry returns its committed receipt and cannot apply another password."
  @spec complete_recovery(term(), term(), term()) ::
          {:ok, :completed | :already_completed | :failed | :expired}
          | {:error, :recovery_unavailable}
  def complete_recovery(proof, password, operation_id),
    do:
      recovery_action(:complete_recovery, %{
        proof: proof,
        password: password,
        operation_id: operation_id
      })

  @doc "Record case-bound current scoped manual review. This does not complete recovery or release a security hold."
  @spec approve_manual_recovery(term()) ::
          {:ok, %{status: :approved, version: non_neg_integer()}}
          | {:error, :recovery_unavailable}
  def approve_manual_recovery(request), do: recovery_action(:approve_manual_recovery, request)

  @doc "Complete after distinct current scoped approval and independently committed E1 admission. All Identity effects and required owner obligations commit together."
  @spec complete_manual_recovery(term()) ::
          {:ok, :completed | :already_completed} | {:error, :recovery_unavailable}
  def complete_manual_recovery(request), do: recovery_action(:complete_manual_recovery, request)

  @doc "Cancel a current case with its purpose-bound claimant proof. Terminal cases remain final."
  @spec cancel_recovery(term(), term()) ::
          {:ok, :cancelled | :failed | :expired} | {:error, :recovery_unavailable}
  def cancel_recovery(proof, operation_id),
    do: recovery_action(:cancel_recovery, %{proof: proof, operation_id: operation_id})

  @doc "Trusted transient proof serialization inside a delivery transaction. Content eligibility remains independently required before sending."
  @spec recovery_delivery(term(), term(), term()) ::
          {:ok, binary()} | {:error, :source_invalid | :capability_unavailable}
  def recovery_delivery(reference, destination, locale),
    do: NewYou.Identity.Recovery.delivery(reference, destination, locale)

  defp recovery_action(name, request) when is_map(request) do
    NewYou.Identity.RecoveryCase
    |> Ash.ActionInput.for_action(name, %{request: request}, authorize?: false)
    |> Ash.run_action()
    |> case do
      {:ok, result} -> {:ok, result}
      _ -> {:error, :recovery_unavailable}
    end
  rescue
    _ -> {:error, :recovery_unavailable}
  end

  defp recovery_action(_, _), do: {:error, :recovery_unavailable}

  @doc "Request a password-reset link through the neutral, bounded development boundary. No Account or Session is created."
  @spec request_password_reset(term(), term(), term()) :: :ok
  def request_password_reset(email, locale, operation_id),
    do: NewYou.Identity.PasswordReset.request(email, locale, operation_id)

  @doc "Explicitly replace a password using current reset proof. A retry of the committed confirmation operation returns its prior outcome without applying new input. No login occurs."
  @spec reset_password(term(), term(), term()) ::
          {:ok, :reset | :already_reset} | {:error, :reset_unavailable}
  def reset_password(proof, password, operation_id)
      when is_binary(proof) and byte_size(proof) in 1..8192 do
    Account
    |> Ash.ActionInput.for_action(
      :reset_password,
      %{proof: proof, password: password, operation_id: operation_id},
      authorize?: false
    )
    |> Ash.run_action()
    |> case do
      {:ok, outcome} when outcome in [:reset, :already_reset] -> {:ok, outcome}
      _ -> {:error, :reset_unavailable}
    end
  rescue
    _ -> {:error, :reset_unavailable}
  end

  def reset_password(_, _, _), do: {:error, :reset_unavailable}

  @doc "Trusted Communications-only transient serialization of current reset proof. Requires its delivery transaction and rechecks current Identity authority."
  @spec password_reset_delivery(String.t(), String.t(), String.t()) ::
          {:ok, binary()} | {:error, :source_invalid | :capability_unavailable}
  def password_reset_delivery(reference, destination, locale),
    do: NewYou.Identity.PasswordReset.delivery(reference, destination, locale)

  @doc "Request optional existing-Account sign-in. Every public outcome is neutral; this never registers or authenticates an Account."
  @spec request_magic_login(term(), term(), term()) :: :ok
  def request_magic_login(email, locale, operation_id),
    do: NewYou.Identity.MagicLogin.request(email, locale, operation_id)

  @doc "Consume a magic-login proof only after explicit participant confirmation. Returns the existing Session transport or one neutral failure."
  @spec authenticate_magic_link(term()) :: {:ok, map()} | {:error, :authentication_unavailable}
  def authenticate_magic_link(proof) when is_binary(proof) and byte_size(proof) in 1..8192 do
    Account
    |> Ash.ActionInput.for_action(:authenticate_magic_link, %{proof: proof}, authorize?: false)
    |> Ash.run_action()
    |> case do
      {:ok, credentials} -> {:ok, credentials}
      _ -> {:error, :authentication_unavailable}
    end
  rescue
    _ -> {:error, :authentication_unavailable}
  end

  def authenticate_magic_link(_), do: {:error, :authentication_unavailable}

  @doc "Trusted Communications-only seam inside its transaction. Revalidate current Identity proof and return its transient serialization; never persist the result."
  @spec magic_login_delivery(String.t(), String.t(), String.t()) ::
          {:ok, binary()} | {:error, :source_invalid | :capability_unavailable}
  def magic_login_delivery(reference, destination, locale),
    do: NewYou.Identity.MagicLogin.delivery(reference, destination, locale)

  @doc """
  Authenticate a password and atomically issue an Identity-owned Session and token.

  The returned token is a transient bearer. Callers must protect it and must not
  store it in the Session or logs. All unavailable outcomes share one error.
  """
  @spec authenticate_password(term(), term()) ::
          {:ok, map()} | {:error, :authentication_unavailable}
  def authenticate_password(email, password),
    do: NewYou.Identity.PasswordSession.authenticate(email, password)

  @doc "Revalidate current Session, token and Account authority and return only the Account ID."
  @spec authorize_session(term()) ::
          {:ok, %{account_id: String.t()}} | {:error, :authentication_unavailable}
  def authorize_session(credentials), do: NewYou.Identity.PasswordSession.authorize(credentials)

  @doc "Begin or resume pending Support MFA setup after current Session/password reauthentication. Active factors never return setup material."
  @spec enroll_privileged_mfa(term(), term()) ::
          {:ok, %{secret: binary()}} | {:error, :privileged_access_unavailable}
  def enroll_privileged_mfa(credentials, password),
    do: NewYou.Identity.PrivilegedAccess.enroll_mfa(credentials, password)

  @doc "Confirm pending Support MFA with the reauthenticated password and a current TOTP code."
  @spec confirm_privileged_mfa(term(), term(), term()) ::
          {:ok, :ok} | {:error, :privileged_access_unavailable}
  def confirm_privileged_mfa(credentials, password, code),
    do: NewYou.Identity.PrivilegedAccess.confirm_mfa(credentials, password, code)

  @doc "Bind fresh password and TOTP assurance to the current Session for one Support capability."
  @spec step_up_privileged(term(), term(), term(), term()) ::
          {:ok, :ok} | {:error, :privileged_access_unavailable}
  def step_up_privileged(credentials, password, code, purpose),
    do: NewYou.Identity.PrivilegedAccess.step_up(credentials, password, code, purpose)

  @doc "Look up one grant-bound Account by its canonical email and return only minimum Identity context."
  @spec lookup_support_identity(term(), term(), term(), term()) ::
          {:ok, map() | :not_found} | {:error, :support_lookup_unavailable}
  def lookup_support_identity(credentials, grant_id, target_account_id, email),
    do:
      NewYou.Identity.SupportLookup.lookup(
        credentials,
        grant_id,
        target_account_id,
        email
      )

  @doc "Place a version-bound security hold under current scoped Support authority and revoke the target's active Sessions."
  @spec place_security_hold(map()) :: {:ok, map()} | {:error, :security_hold_unavailable}
  def place_security_hold(request),
    do: NewYou.Identity.SecurityHold.run(:place_security_hold, request)

  @doc "Record independent current security review of one held generation. This does not release the hold."
  @spec review_security_hold(map()) :: {:ok, map()} | {:error, :security_hold_unavailable}
  def review_security_hold(request),
    do: NewYou.Identity.SecurityHold.run(:review_security_hold, request)

  @doc "Release a reviewed hold after Audit E1 commits and current Identity authority is revalidated. Admission survives source failure."
  @spec release_security_hold(map()) :: {:ok, map()} | {:error, :security_hold_unavailable}
  def release_security_hold(request),
    do: NewYou.Identity.SecurityHold.run(:release_security_hold, request)

  @doc "Open a duplicate-identity case using grant_id and canonical_grant_id scoped to its two Accounts. Detection never applies a canonical decision."
  @spec open_reconciliation(map()) ::
          {:ok, NewYou.Identity.ReconciliationCase.t()} | {:error, :reconciliation_unavailable}
  defdelegate open_reconciliation(request), to: NewYou.Identity.Reconciliation, as: :open

  @doc "Advance review under grants for both Accounts. Approval requires verified controls and owner review; reopening approval preserves its evidence and requires fresh review."
  @spec review_reconciliation(map()) ::
          {:ok, NewYou.Identity.ReconciliationCase.t()} | {:error, :reconciliation_unavailable}
  defdelegate review_reconciliation(request), to: NewYou.Identity.Reconciliation, as: :review

  @doc "Apply the reviewed canonical decision after independent Audit E1 admission. Replays preserve the committed outcome."
  @spec apply_reconciliation(map()) ::
          {:ok, NewYou.Identity.ReconciliationCase.t()} | {:error, :reconciliation_unavailable}
  defdelegate apply_reconciliation(request),
    to: NewYou.Identity.Reconciliation,
    as: :apply_decision

  @doc "Log out the identified Session."
  @spec logout(term()) :: :ok | {:error, :authentication_unavailable}
  def logout(credentials), do: NewYou.Identity.PasswordSession.logout(credentials)

  @doc "Revoke the identified Session."
  @spec revoke_session(term()) :: :ok | {:error, :authentication_unavailable}
  def revoke_session(credentials), do: NewYou.Identity.PasswordSession.revoke(credentials)

  @doc "Reconcile a bounded batch of Sessions whose expiry deadlines have passed."
  @spec expire_due_sessions() :: {:ok, non_neg_integer()} | {:error, :authentication_unavailable}
  def expire_due_sessions, do: NewYou.Identity.PasswordSession.expire_due()

  @doc "Request an Account-owned primary-email change under the current authenticated Session."
  @spec request_primary_email_change(term(), term(), term(), term()) ::
          {:ok, :requested} | {:error, :primary_email_change_unavailable}
  def request_primary_email_change(credentials, target, locale, operation_id),
    do: NewYou.Identity.PrimaryEmailChange.request(credentials, target, locale, operation_id)

  @doc "Require fresh password and current Session assurance before issuing or refreshing proof authority."
  @spec reauthenticate_primary_email_change(term(), term(), term()) ::
          {:ok, :proof_pending | :assurance_refreshed}
          | {:error, :primary_email_change_unavailable}
  def reauthenticate_primary_email_change(credentials, password, operation_id),
    do: NewYou.Identity.PrimaryEmailChange.reauthenticate(credentials, password, operation_id)

  @doc "Explicitly consume the current new-address proof. Confirmation does not apply the email."
  @spec confirm_primary_email_change(term()) ::
          {:ok, :confirmed} | {:error, :primary_email_change_unavailable}
  def confirm_primary_email_change(proof),
    do: NewYou.Identity.PrimaryEmailChange.confirm(proof)

  @doc "Apply a current, confirmed primary-email change after its Identity-owned guards pass."
  @spec apply_primary_email_change(term()) ::
          {:ok,
           :applied | :already_applied | :held | :already_held | :rejected | :already_rejected}
          | {:error, :primary_email_change_unavailable}
  def apply_primary_email_change(operation_id),
    do: NewYou.Identity.PrimaryEmailChange.apply(operation_id)

  @doc "Cancel the current primary-email-change operation from its authenticated Account Session."
  @spec cancel_primary_email_change(term(), term()) ::
          {:ok, :cancelled | :already_cancelled}
          | {:error, :primary_email_change_unavailable}
  def cancel_primary_email_change(credentials, operation_id),
    do: NewYou.Identity.PrimaryEmailChange.cancel(credentials, operation_id)

  @doc "Expire one current primary-email-change operation after its persisted deadline."
  @spec expire_primary_email_change(term()) ::
          {:ok, :expired | :already_expired | :not_expired}
          | {:error, :primary_email_change_unavailable}
  def expire_primary_email_change(operation_id),
    do: NewYou.Identity.PrimaryEmailChange.expire(operation_id)

  @doc "Reconcile due primary-email-change operations from durable Account state."
  @spec expire_due_primary_email_changes(pos_integer()) ::
          {:ok, non_neg_integer()} | {:error, :primary_email_change_unavailable}
  def expire_due_primary_email_changes(limit \\ 100),
    do: NewYou.Identity.PrimaryEmailChange.expire_due(limit)

  @doc "Review a risk-required operation after fresh password and current applicable MFA step-up."
  @spec review_primary_email_change(term(), term(), term()) ::
          {:ok, :reviewed | :already_reviewed}
          | {:error, :primary_email_change_unavailable}
  def review_primary_email_change(credentials, password, operation_id),
    do: NewYou.Identity.PrimaryEmailChange.review(credentials, password, operation_id)

  @doc false
  @spec primary_email_change_delivery(String.t(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, :source_invalid | :capability_unavailable}
  def primary_email_change_delivery(reference, destination, locale),
    do: NewYou.Identity.PrimaryEmailChange.delivery(reference, destination, locale)

  @doc """
  Consumes an email-verification capability and verifies its Account atomically.

  Call only for explicit participant confirmation. The bearer is transient. The
  action rechecks signed claims, stored proof and current Account under database
  locks. Replays and every unavailable outcome share one public error. This never
  authenticates the participant or issues a Session.
  """
  @spec verify_email(term()) :: {:ok, :verified} | {:error, :verification_unavailable}
  def verify_email(proof) when is_binary(proof) and byte_size(proof) in 1..8192 do
    Account
    |> Ash.ActionInput.for_action(:confirm_email, %{proof: proof}, authorize?: false)
    |> Ash.run_action()
    |> case do
      {:ok, :verified} -> {:ok, :verified}
      _ -> {:error, :verification_unavailable}
    end
  rescue
    _ -> {:error, :verification_unavailable}
  catch
    _, _ -> {:error, :verification_unavailable}
  end

  def verify_email(_), do: {:error, :verification_unavailable}

  @doc """
  Accepts a registration bound to its opaque operation ID.

  A new Account commits with its credential, PMR, verification Token, Communications
  MessageIntent and protected envelope, and the initial Audit obligation and schedule
  in one source transaction. Replaying the same immutable request returns its prior
  result without repeating those effects. A distinct operation for an existing
  canonical email returns the neutral pending result without creating another Account
  or its consequences. A first accepted result contains the transient verification
  proof used to establish the protected envelope; replays do not return that proof.
  """
  @spec register(map()) :: {:ok, RegistrationResult.t()} | {:error, atom()}
  def register(request) when is_map(request) do
    with {:ok, operation_id} <- operation_id(request),
         {:ok, existing} <- read_operation(operation_id) do
      case existing do
        nil -> register_new(request, operation_id)
        operation -> replay_or_reject(operation, request)
      end
    else
      _ -> {:error, :invalid_registration}
    end
  end

  def register(_), do: {:error, :invalid_registration}

  @doc """
  Accepts a verification resend for an active, unverified Account.

  Every valid request permanently binds the operation ID to a keyed fingerprint of
  its immutable request, including neutral outcomes. An exact replay returns the
  same neutral public result; changed input returns `:resend_unavailable`. Accepted
  requests supersede active verification Tokens and commit one replacement Token,
  Communications MessageIntent, protected envelope and Identity resend record in one
  transaction. The operation does not create an Audit obligation or Communications
  job.
  """
  @spec resend_verification(map()) :: {:ok, :verification_pending} | {:error, :resend_unavailable}
  def resend_verification(request) when is_map(request) do
    with {:ok, operation_id} <- resend_operation_id(Map.get(request, :operation_id)),
         {:ok, account_id} <- account_id(Map.get(request, :account_id)),
         result <- accept_resend(operation_id, :account_id, account_id, {:account_id, account_id}) do
      result
    else
      _ -> {:error, :resend_unavailable}
    end
  rescue
    _ -> {:error, :resend_unavailable}
  catch
    _, _ -> {:error, :resend_unavailable}
  end

  def resend_verification(_), do: {:error, :resend_unavailable}

  @doc """
  Accepts a resend request addressed by canonical email without exposing an Account ID
  to the browser. An unknown or ineligible address receives the same neutral pending
  outcome. Accepted requests use the same Identity-owned operation binding as
  `resend_verification/1`.
  """
  @spec resend_verification_by_email(map()) ::
          {:ok, :verification_pending} | {:error, :resend_unavailable}
  def resend_verification_by_email(request) when is_map(request) do
    with {:ok, operation_id} <- resend_operation_id(Map.get(request, :operation_id)),
         {:ok, email} <- Email.canonicalize(Map.get(request, :email)),
         result <- accept_resend(operation_id, :email, email, {:email, email}) do
      result
    else
      _ -> {:error, :resend_unavailable}
    end
  rescue
    _ -> {:error, :resend_unavailable}
  catch
    _, _ -> {:error, :resend_unavailable}
  end

  def resend_verification_by_email(_), do: {:error, :resend_unavailable}

  def registration_now, do: now()

  @doc false
  @spec validate_registration_acceptance(map(), term()) ::
          {:ok, map()} | {:error, :invalid_registration}
  def validate_registration_acceptance(registration_input, pmr) when is_map(registration_input) do
    with {:ok, operation_id} <- operation_id(registration_input),
         {:ok, registration} <- validate_request(registration_input, operation_id),
         true <- PMR.valid?(pmr),
         {:ok, request_fingerprint, fingerprint_key_version} <-
           RegistrationBinding.fingerprint(registration) do
      {:ok,
       %{
         registration_input: registration,
         request_fingerprint: request_fingerprint,
         fingerprint_key_version: fingerprint_key_version,
         pmr: pmr
       }}
    else
      _ -> {:error, :invalid_registration}
    end
  end

  def validate_registration_acceptance(_, _), do: {:error, :invalid_registration}

  @doc "Tombstone live registration bindings linked to an Account after an Identity invalidation."
  @spec invalidate_registration_operations(String.t()) :: :ok | {:error, atom()}
  def invalidate_registration_operations(account_id) when is_binary(account_id) do
    with {:ok, account_id} <- Ecto.UUID.cast(account_id),
         query <- Ash.Query.filter(RegistrationOperation, created_account_id == ^account_id),
         {:ok, operations} <- Ash.read(query, domain: __MODULE__, authorize?: false),
         {:ok, :ok} <-
           Ash.transaction([RegistrationOperation], fn ->
             tombstone_operations(operations)
           end) do
      :ok
    else
      _ -> {:error, :registration_unavailable}
    end
  end

  def invalidate_registration_operations(_), do: {:error, :registration_unavailable}

  @doc "Tombstone expired registration bindings in bounded Identity-owned batches."
  @spec expire_registration_operations() :: {:ok, non_neg_integer()} | {:error, atom()}
  def expire_registration_operations do
    now = now()

    query =
      Ash.Query.filter(
        RegistrationOperation,
        state == :bound and expires_at <= ^now
      )
      |> Ash.Query.sort(expires_at: :asc)
      |> Ash.Query.limit(@registration_operation_expiry_batch_size)

    with {:ok, operations} <- Ash.read(query, domain: __MODULE__, authorize?: false),
         {:ok, count} <- tombstone_expired_operations(operations) do
      {:ok, count}
    else
      _ -> {:error, :registration_unavailable}
    end
  rescue
    _ -> {:error, :registration_unavailable}
  catch
    _, _ -> {:error, :registration_unavailable}
  end

  defp tombstone_operations(operations) do
    Enum.reduce_while(operations, :ok, fn operation, :ok ->
      case tombstone_if_bound(operation) do
        :ok -> {:cont, :ok}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp tombstone_expired_operations([]), do: {:ok, 0}

  defp tombstone_expired_operations(operations) do
    case Ash.transaction([RegistrationOperation], fn -> tombstone_expired_batch(operations) end) do
      {:ok, count} when is_integer(count) -> {:ok, count}
      _ -> {:error, :registration_unavailable}
    end
  end

  defp tombstone_expired_batch(operations) do
    case tombstone_operations(operations) do
      :ok -> length(operations)
      {:error, _} = error -> error
    end
  end

  defp register_new(request, operation_id) do
    with {:ok, input} <- validate_request(request, operation_id),
         {:ok, fingerprint, key_version} <- RegistrationBinding.fingerprint(input) do
      allocate_account(input, fingerprint, key_version, 1)
    else
      _ -> {:error, :invalid_registration}
    end
  end

  defp accept_resend(operation_id, subject_type, subject_value, selector) do
    case RegistrationBinding.resend_fingerprint(operation_id, subject_type, subject_value) do
      {:ok, request_fingerprint, fingerprint_key_version} ->
        input = %{
          operation_id: operation_id,
          subject_type: subject_type,
          subject_value: subject_value,
          selector: selector,
          request_fingerprint: request_fingerprint,
          fingerprint_key_version: fingerprint_key_version
        }

        case resend_transaction(input) do
          {:ok, {:ok, :verification_pending}} ->
            {:ok, :verification_pending}

          {:ok, :verification_pending} ->
            {:ok, :verification_pending}

          {:ok, {:error, _reason}} ->
            {:error, :resend_unavailable}

          {:error, error} ->
            resend_transaction_error(input, error)

          _ ->
            {:error, :resend_unavailable}
        end

      _ ->
        {:error, :resend_unavailable}
    end
  end

  defp resend_transaction(input) do
    Ash.transact(
      [
        Account,
        Token,
        ResendOperation,
        NewYou.Communications.MessageIntent,
        NewYou.Communications.ProtectedEnvelope,
        NewYou.Communications.EnvelopeNonce
      ],
      fn -> accept_resend_locked(input) end
    )
  end

  defp accept_resend_locked(input) do
    case read_resend_operation(input.operation_id) do
      {:ok, %ResendOperation{} = operation} -> replay_resend_operation(operation, input)
      {:ok, nil} -> accept_resend_after_initial_read(input)
      _ -> {:error, :resend_unavailable}
    end
  end

  defp accept_resend_after_initial_read(input) do
    with {:ok, account} <- lock_resend_account(input.selector),
         {:ok, operation} <- read_resend_operation(input.operation_id) do
      case operation do
        %ResendOperation{} = operation -> replay_resend_operation(operation, input)
        nil -> accept_resend_state(account, input)
      end
    else
      _ -> {:error, :resend_unavailable}
    end
  end

  defp accept_resend_state(nil, input), do: record_neutral_resend(input)

  defp accept_resend_state(
         %Account{credential_status: :active, email_verified?: false} = account,
         input
       ),
       do: establish_resend(account, input)

  defp accept_resend_state(%Account{}, input), do: record_neutral_resend(input)

  defp resend_transaction_error(input, error) do
    if resend_operation_id_collision?(error) do
      replay_resend_after_race(input)
    else
      {:error, :resend_unavailable}
    end
  end

  defp lock_resend_account({:account_id, account_id}) do
    query =
      Account
      |> Ash.Query.filter(id == ^account_id)
      |> Ash.Query.lock(:for_update)

    read_locked_resend_account(query)
  end

  defp lock_resend_account({:email, email}) do
    query =
      Account
      |> Ash.Query.filter(email == ^email)
      |> Ash.Query.lock(:for_update)

    read_locked_resend_account(query)
  end

  defp read_locked_resend_account(query) do
    case Ash.read(query, domain: __MODULE__, authorize?: false) do
      {:ok, [account]} -> {:ok, account}
      {:ok, []} -> {:ok, nil}
      _ -> {:error, :resend_unavailable}
    end
  end

  defp establish_resend(%Account{} = account, input) do
    accepted_at = registration_now()

    with :ok <- supersede_active_challenges(account),
         {:ok, bearer, claims} <- issue_resend_proof(account),
         {:ok, _intent} <-
           establish_resend_intent(account, input.operation_id, accepted_at, claims, bearer),
         {:ok, _operation} <-
           record_resend_operation(input, :accepted, account.id, accepted_at) do
      {:ok, :verification_pending}
    else
      error -> error
    end
  end

  defp record_neutral_resend(input) do
    with {:ok, _operation} <- record_resend_operation(input, :neutral, nil, nil) do
      {:ok, :verification_pending}
    end
  end

  defp record_resend_operation(input, outcome, account_id, accepted_at) do
    Ash.create(
      ResendOperation,
      %{
        operation_id: input.operation_id,
        account_id: account_id,
        accepted_at: accepted_at,
        request_fingerprint: input.request_fingerprint,
        fingerprint_key_version: input.fingerprint_key_version,
        outcome: outcome
      },
      action: :accept,
      domain: __MODULE__,
      authorize?: false
    )
  end

  defp supersede_active_challenges(account) do
    now = registration_now()

    query =
      Ash.Query.filter(
        Token,
        account_id == ^account.id and purpose == "email_verification" and expires_at > ^now
      )

    case Ash.read(query, domain: __MODULE__, authorize?: false) do
      {:ok, tokens} -> revoke_active_challenges(tokens, account)
      _ -> {:error, :resend_unavailable}
    end
  end

  defp revoke_active_challenges(tokens, account) do
    Enum.reduce_while(tokens, :ok, fn token, :ok ->
      case AshAuthentication.TokenResource.Actions.revoke_jti(
             Token,
             token.jti,
             token.subject,
             domain: __MODULE__,
             authorize?: false,
             context: %{ash_authentication: %{user: account}}
           ) do
        :ok -> {:cont, :ok}
        _ -> {:halt, {:error, :resend_unavailable}}
      end
    end)
  end

  defp issue_resend_proof(account) do
    case AshAuthentication.Jwt.token_for_user(
           account,
           %{"purpose" => "email_verification"},
           purpose: :email_verification,
           token_lifetime: @verification_token_lifetime,
           domain: __MODULE__,
           authorize?: false
         ) do
      {:ok, bearer, claims} when is_binary(bearer) and is_map(claims) ->
        {:ok, bearer, claims}

      _ ->
        {:error, :token_creation_failed}
    end
  rescue
    _ -> {:error, :token_creation_failed}
  end

  defp establish_resend_intent(account, operation_id, accepted_at, claims, bearer) do
    NewYou.Communications.establish_verification(
      %{
        source_operation_id: operation_id,
        source_reference: claims["jti"],
        destination: account.email,
        destination_provenance: "identity_challenge_issuance",
        destination_authorized_at: accepted_at,
        locale: Atom.to_string(account.preferred_language)
      },
      bearer
    )
  end

  defp replay_resend_after_race(input) do
    case read_resend_operation(input.operation_id) do
      {:ok, %ResendOperation{} = operation} -> replay_resend_operation(operation, input)
      _ -> {:error, :resend_unavailable}
    end
  end

  defp read_resend_operation(operation_id) do
    query = Ash.Query.filter(ResendOperation, operation_id == ^operation_id)

    case Ash.read(query, domain: __MODULE__, authorize?: false) do
      {:ok, [operation]} -> {:ok, operation}
      {:ok, []} -> {:ok, nil}
      _ -> {:error, :resend_unavailable}
    end
  end

  defp replay_resend_operation(
         %ResendOperation{fingerprint_key_version: "legacy-account-id-v1"} = operation,
         input
       ) do
    with {:ok, account_id} <- legacy_resend_account_id(operation, input),
         fingerprint <-
           RegistrationBinding.legacy_resend_fingerprint(operation.operation_id, account_id),
         true <- RegistrationBinding.equal?(operation.request_fingerprint, fingerprint),
         :accepted <- operation.outcome do
      {:ok, :verification_pending}
    else
      _ -> {:error, :resend_unavailable}
    end
  end

  defp replay_resend_operation(%ResendOperation{} = operation, input) do
    with {:ok, fingerprint} <-
           RegistrationBinding.resend_fingerprint_for_version(
             input.operation_id,
             input.subject_type,
             input.subject_value,
             operation.fingerprint_key_version
           ),
         true <- RegistrationBinding.equal?(operation.request_fingerprint, fingerprint),
         true <- operation.outcome in [:accepted, :neutral] do
      {:ok, :verification_pending}
    else
      _ -> {:error, :resend_unavailable}
    end
  end

  defp legacy_resend_account_id(
         %ResendOperation{account_id: account_id},
         %{subject_type: :account_id, subject_value: account_id}
       ),
       do: {:ok, account_id}

  defp legacy_resend_account_id(
         %ResendOperation{account_id: account_id},
         %{subject_type: :email, subject_value: email}
       ) do
    query =
      Account
      |> Ash.Query.filter(id == ^account_id and email == ^email)

    case Ash.read(query, domain: __MODULE__, authorize?: false) do
      {:ok, [%Account{}]} -> {:ok, account_id}
      {:ok, []} -> {:error, :resend_unavailable}
      _ -> {:error, :resend_unavailable}
    end
  end

  defp legacy_resend_account_id(_, _), do: {:error, :resend_unavailable}

  defp resend_operation_id(value) do
    with {:ok, operation_id} when is_binary(operation_id) <- Ecto.UUID.cast(value),
         {:ok, <<_timestamp::48, 4::4, _random_a::12, 2::2, _random_b::62>>} <-
           Ecto.UUID.dump(operation_id) do
      {:ok, operation_id}
    else
      _ -> {:error, :invalid_operation_id}
    end
  end

  defp account_id(value) do
    case Ecto.UUID.cast(value) do
      {:ok, account_id} -> {:ok, account_id}
      _ -> {:error, :invalid_account_id}
    end
  end

  defp resend_operation_id_collision?(error) do
    error_has_unique_field?(error, :operation_id) or
      case error do
        %Ecto.ConstraintError{
          type: :unique,
          constraint: "resend_operations_opaque_operation_id_index"
        } ->
          true

        %{errors: errors} when is_list(errors) ->
          Enum.any?(errors, &resend_operation_id_collision?/1)

        _ ->
          false
      end
  end

  defp replay_or_reject(operation, request) do
    now = now()

    cond do
      operation.state == :tombstoned ->
        {:error, :registration_unavailable}

      is_nil(operation.expires_at) or DateTime.compare(now, operation.expires_at) != :lt ->
        _ = tombstone(operation)
        {:error, :registration_unavailable}

      operation.state != :bound ->
        {:error, :registration_unavailable}

      true ->
        with {:ok, input} <- validate_request(request, operation.operation_id),
             {:ok, fingerprint} <-
               RegistrationBinding.fingerprint_for_version(
                 input,
                 operation.fingerprint_key_version
               ),
             true <- RegistrationBinding.equal?(operation.request_fingerprint, fingerprint),
             true <- password_matches?(operation, input.password) do
          {:ok,
           %RegistrationResult{
             status: operation.outcome,
             account_id: operation.created_account_id,
             verification_proof: nil
           }}
        else
          _ -> {:error, :registration_unavailable}
        end
    end
  end

  defp allocate_account(input, fingerprint, key_version, attempt) do
    case next_pmr() do
      {:ok, pmr} -> create_registration_with_pmr(input, fingerprint, key_version, pmr, attempt)
      _ -> {:error, :registration_unavailable}
    end
  end

  defp create_registration_with_pmr(input, fingerprint, key_version, pmr, attempt) do
    result =
      accept_new_registration(
        %{
          registration_input: input,
          pmr: pmr
        },
        authorize?: false
      )

    case result do
      {:ok, %{status: :verification_pending} = accepted} ->
        {:ok,
         %RegistrationResult{
           status: accepted.status,
           account_id: accepted.account_id,
           verification_proof: accepted.verification_proof
         }}

      {:error, error} ->
        route_allocation_error(error, input, fingerprint, key_version, attempt)

      _ ->
        {:error, :registration_unavailable}
    end
  end

  defp route_allocation_error(error, input, fingerprint, key_version, attempt) do
    cond do
      attempt < 5 and error_has_unique_field?(error, :pmr) ->
        allocate_account(input, fingerprint, key_version, attempt + 1)

      error_has_unique_field?(error, :email) ->
        bind_duplicate_email(input, fingerprint, key_version)

      operation_id_collision?(error) ->
        replay_after_race(input)

      true ->
        {:error, :registration_unavailable}
    end
  end

  defp bind_duplicate_email(input, fingerprint, key_version) do
    case hash_password(input.password) do
      {:ok, password_verifier} ->
        store_duplicate_email_operation(input, fingerprint, key_version, password_verifier)

      _ ->
        {:error, :registration_unavailable}
    end
  end

  defp store_duplicate_email_operation(input, fingerprint, key_version, password_verifier) do
    operation_result =
      Ash.transaction([RegistrationOperation], fn ->
        committed_at = now()

        persist_duplicate_email_operation(
          input,
          fingerprint,
          key_version,
          password_verifier,
          committed_at
        )
      end)

    case operation_result do
      {:ok, %RegistrationResult{} = accepted} ->
        {:ok, accepted}

      {:error, error} ->
        if operation_id_collision?(error),
          do: replay_after_race(input),
          else: {:error, :registration_unavailable}

      _ ->
        {:error, :registration_unavailable}
    end
  end

  defp persist_duplicate_email_operation(
         input,
         fingerprint,
         key_version,
         password_verifier,
         committed_at
       ) do
    attributes = %{
      operation_id: input.operation_id,
      request_fingerprint: fingerprint,
      fingerprint_key_version: key_version,
      password_verifier: password_verifier,
      verifier_provider: @verifier_provider,
      verifier_version: @verifier_version,
      outcome: :verification_pending,
      committed_at: committed_at,
      expires_at: DateTime.add(committed_at, @operation_lifetime_seconds, :second),
      created_account_id: nil
    }

    case create_operation(attributes) do
      {:ok, _operation} -> %RegistrationResult{status: :verification_pending, account_id: nil}
      {:error, error} -> {:error, error}
    end
  end

  defp replay_after_race(input) do
    case read_operation(input.operation_id) do
      {:ok, %RegistrationOperation{} = operation} -> replay_or_reject(operation, input)
      _ -> {:error, :registration_unavailable}
    end
  end

  defp create_operation(attributes) do
    Ash.create(RegistrationOperation, attributes,
      action: :bind,
      domain: __MODULE__,
      authorize?: false
    )
  end

  defp read_operation(operation_id) do
    query = Ash.Query.filter(RegistrationOperation, operation_id == ^operation_id)

    case Ash.read(query, domain: __MODULE__, authorize?: false) do
      {:ok, [operation]} -> {:ok, operation}
      {:ok, []} -> {:ok, nil}
      {:ok, _} -> {:error, :registration_unavailable}
      {:error, _} -> {:error, :registration_unavailable}
    end
  end

  defp tombstone_if_bound(%RegistrationOperation{state: :bound} = operation),
    do: tombstone(operation)

  defp tombstone_if_bound(%RegistrationOperation{}), do: :ok

  defp tombstone(operation) do
    case Ash.update(operation, %{},
           action: :tombstone,
           domain: __MODULE__,
           authorize?: false
         ) do
      {:ok, _operation} -> :ok
      {:error, _} -> {:error, :registration_unavailable}
    end
  end

  defp validate_request(request, operation_id) do
    with {:ok, first_name} <- nonblank_text(Map.get(request, :first_name)),
         {:ok, surname} <- nonblank_text(Map.get(request, :surname)),
         {:ok, email_input} <- required_text(Map.get(request, :email)),
         {:ok, email} <- Email.canonicalize(email_input),
         {:ok, password} <- required_password(Map.get(request, :password)),
         {:ok, preferred_language} <- language(Map.get(request, :preferred_language)),
         true <- Map.get(request, :confirmed_age_18?) == true,
         {:ok, terms_version_id, privacy_version_id} <- legal_versions(request) do
      {:ok,
       %{
         operation_id: operation_id,
         first_name: first_name,
         surname: surname,
         email: email,
         password: password,
         preferred_language: preferred_language,
         acceptance_locale: preferred_language,
         confirmed_age_18?: true,
         terms_version_id: terms_version_id,
         privacy_version_id: privacy_version_id
       }}
    else
      _ -> {:error, :invalid_registration}
    end
  end

  defp operation_id(request) do
    with {:ok, operation_id} when is_binary(operation_id) <-
           Ecto.UUID.cast(Map.get(request, :operation_id)),
         {:ok, <<_timestamp::48, 4::4, _random_a::12, 2::2, _random_b::62>>} <-
           Ecto.UUID.dump(operation_id) do
      {:ok, operation_id}
    else
      _ -> {:error, :invalid_registration}
    end
  end

  defp nonblank_text(value) do
    with {:ok, value} <- required_text(value),
         true <- String.trim(value) != "" do
      {:ok, value}
    else
      _ -> {:error, :invalid_registration}
    end
  end

  defp required_text(value) when is_binary(value) and byte_size(value) > 0,
    do: {:ok, value}

  defp required_text(_), do: {:error, :invalid_registration}

  defp required_password(value) when is_binary(value) and byte_size(value) > 0,
    do: {:ok, value}

  defp required_password(_), do: {:error, :invalid_registration}

  defp language(:af), do: {:ok, :af}
  defp language(:en), do: {:ok, :en}
  defp language("af"), do: {:ok, :af}
  defp language("en"), do: {:ok, :en}
  defp language(_), do: {:error, :invalid_registration}

  defp legal_versions(request) do
    terms = Map.get(request, :terms_version_id)
    privacy = Map.get(request, :privacy_version_id)

    if allowed_development_legal_versions?() and terms == @development_terms_id and
         privacy == @development_privacy_id do
      {:ok, terms, privacy}
    else
      {:error, :invalid_registration}
    end
  end

  defp allowed_development_legal_versions? do
    Application.get_env(:new_you, :identity_registration_legal_versions) == %{
      terms_version_id: @development_terms_id,
      privacy_version_id: @development_privacy_id
    }
  end

  defp password_matches?(%RegistrationOperation{} = operation, password) do
    operation.verifier_provider == @verifier_provider and
      operation.verifier_version == @verifier_version and
      is_binary(operation.password_verifier) and
      safe_password_verify(password, operation.password_verifier)
  end

  defp safe_password_verify(password, verifier) do
    AshAuthentication.Argon2Provider.valid?(password, verifier)
  rescue
    _ -> false
  end

  defp hash_password(password) do
    case AshAuthentication.Argon2Provider.hash(password) do
      {:ok, verifier} when is_binary(verifier) -> {:ok, verifier}
      _ -> {:error, :password_hash_failed}
    end
  rescue
    _ -> {:error, :password_hash_failed}
  end

  defp next_pmr do
    generator = Application.get_env(:new_you, :identity_pmr_generator, &PMR.generate/0)

    case generator.() do
      {:ok, pmr} when is_binary(pmr) ->
        if PMR.valid?(pmr), do: {:ok, pmr}, else: {:error, :generation_failed}

      _ ->
        {:error, :generation_failed}
    end
  rescue
    _ -> {:error, :generation_failed}
  end

  defp error_has_unique_field?(error, field) do
    case error do
      %Ash.Error.Changes.InvalidAttribute{field: ^field, private_vars: private_vars} ->
        Keyword.get(private_vars || [], :constraint_type) == :unique

      %{errors: errors} when is_list(errors) ->
        Enum.any?(errors, &error_has_unique_field?(&1, field))

      _ ->
        false
    end
  end

  defp operation_id_collision?(error) do
    error_has_unique_field?(error, :operation_id) or
      case error do
        %Ecto.ConstraintError{
          type: :unique,
          constraint: "registration_operations_opaque_operation_id_index"
        } ->
          true

        %{errors: errors} when is_list(errors) ->
          Enum.any?(errors, &operation_id_collision?/1)

        _ ->
          false
      end
  end

  defp now do
    clock = Application.get_env(:new_you, :identity_clock, &DateTime.utc_now/0)
    clock.() |> DateTime.truncate(:microsecond)
  end
end
