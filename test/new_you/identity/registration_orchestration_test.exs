defmodule NewYou.Identity.RegistrationOrchestrationTest do
  use NewYou.DataCase, async: false

  import Ecto.Query
  alias Ecto.Adapters.SQL.Sandbox

  alias NewYou.{Communications, Identity, Repo}
  alias NewYou.Audit.EvidenceObligation
  alias NewYou.Communications.MessageIntent

  @terms_id "NEWYOU-TERMS-EN-DEV-2026-10-27-001"
  @privacy_id "NEWYOU-PRIVACY-EN-DEV-2026-10-27-001"

  setup do
    previous = %{
      binding_keys: Application.get_env(:new_you, :identity_registration_binding_keys),
      token_secret: Application.get_env(:new_you, :identity_token_signing_secret),
      communications_keyring: Application.get_env(:new_you, :communications_keyring)
    }

    Application.put_env(:new_you, :identity_registration_binding_keys, %{
      active_version: "test-v1",
      keys: %{"test-v1" => :crypto.strong_rand_bytes(32)}
    })

    Application.put_env(:new_you, :identity_token_signing_secret, :crypto.strong_rand_bytes(32))

    Application.put_env(:new_you, :communications_keyring, %{
      active: "test-v1",
      keys: %{"test-v1" => :crypto.strong_rand_bytes(32)}
    })

    on_exit(fn ->
      restore_env(:identity_registration_binding_keys, previous.binding_keys)
      restore_env(:identity_token_signing_secret, previous.token_secret)
      restore_env(:communications_keyring, previous.communications_keyring)
    end)

    {:ok,
     nonce_count: row_count("communications_envelope_nonces"),
     pmr_reservation_count: row_count("identity_pmr_reservations")}
  end

  test "registration commits one protected MessageIntent and the initial Audit schedule", %{
    nonce_count: nonce_count
  } do
    request = valid_request()

    assert {:ok, %{status: :verification_pending, account_id: account_id} = result} =
             Identity.register(request)

    account = Ash.get!(Identity.Account, account_id, domain: Identity, authorize?: false)
    [token] = records(Identity.Token, Identity)
    [intent] = records(MessageIntent, Communications)
    [obligation] = records(EvidenceObligation, NewYou.Audit)
    [audit_job] = Repo.all(from job in Oban.Job)

    assert account.credential_status == :active
    assert account.hashed_password
    assert Identity.PMR.valid?(account.pmr)
    assert intent.source_operation_id == request.operation_id
    assert intent.source_reference == token.jti
    assert intent.destination == account.email
    assert intent.locale == "af"
    assert intent.dispatch_disposition == :open
    assert obligation.source_operation_id == request.operation_id
    assert audit_job.queue == "audit"
    assert audit_job.args["primary_key"] == %{"id" => obligation.id}
    assert audit_job.args["metadata"] == %{}
    assert audit_job.args["action_arguments"] == %{}
    assert audit_job.args["tenant"] == nil
    assert result.verification_proof

    assert %{rows: [[source_reference, ciphertext]]} =
             Repo.query!(
               "SELECT source_reference, ciphertext FROM communications_protected_envelopes WHERE message_intent_id = $1",
               [Ecto.UUID.dump!(intent.id)]
             )

    assert source_reference == token.jti
    assert is_binary(ciphertext)
    refute ciphertext == result.verification_proof
    refute String.contains?(inspect(audit_job.args), result.verification_proof)
    refute String.contains?(inspect(audit_job.args), account.email)
    assert row_count("message_intents") == 1
    assert row_count("communications_protected_envelopes") == 1
    assert row_count("communications_envelope_nonces") == nonce_count + 1
    assert length(Repo.all(from job in Oban.Job)) == 1
  end

  test "an identical registration retry reuses its committed delivery consequence" do
    request = valid_request()

    assert {:ok, first} = Identity.register(request)
    assert {:ok, replay} = Identity.register(request)

    assert replay.account_id == first.account_id
    assert resource_count(Identity.Account, Identity) == 1
    assert resource_count(Identity.Token, Identity) == 1
    assert resource_count(MessageIntent, Communications) == 1
    assert resource_count(EvidenceObligation, NewYou.Audit) == 1
    assert row_count("communications_protected_envelopes") == 1
    assert length(Repo.all(from job in Oban.Job)) == 1
  end

  test "changed registration input reusing an operation ID has no new consequence" do
    request = valid_request()
    assert {:ok, _} = Identity.register(request)

    assert {:error, _} = Identity.register(%{request | surname: "Changed"})

    assert resource_count(Identity.Account, Identity) == 1
    assert resource_count(Identity.Token, Identity) == 1
    assert resource_count(MessageIntent, Communications) == 1
    assert resource_count(EvidenceObligation, NewYou.Audit) == 1
    assert row_count("communications_protected_envelopes") == 1
    assert length(Repo.all(from job in Oban.Job)) == 1
  end

  test "a distinct operation for an existing canonical email adds no delivery or Audit state", %{
    nonce_count: nonce_count,
    pmr_reservation_count: pmr_reservation_count
  } do
    first = valid_request()
    duplicate = %{valid_request() | email: "Alice+campaign.Example@EXAMPLE.COM"}

    assert {:ok, %{account_id: account_id}} = Identity.register(first)
    assert {:ok, %{account_id: nil}} = Identity.register(duplicate)

    assert is_binary(account_id)
    assert resource_count(Identity.Account, Identity) == 1
    assert resource_count(Identity.Token, Identity) == 1
    assert resource_count(MessageIntent, Communications) == 1
    assert resource_count(EvidenceObligation, NewYou.Audit) == 1
    assert row_count("communications_protected_envelopes") == 1
    assert row_count("communications_envelope_nonces") == nonce_count + 1
    assert row_count("identity_pmr_reservations") == pmr_reservation_count + 1
    assert length(Repo.all(from job in Oban.Job)) == 1
  end

  test "a protected-envelope failure rolls back every registration consequence", %{
    nonce_count: nonce_count,
    pmr_reservation_count: pmr_reservation_count
  } do
    reject_inserts("communications_protected_envelopes", "registration_envelope_failure")

    assert {:error, :registration_unavailable} = Identity.register(valid_request())

    assert resource_count(Identity.Account, Identity) == 0
    assert resource_count(Identity.Token, Identity) == 0
    assert resource_count(Identity.RegistrationOperation, Identity) == 0
    assert resource_count(MessageIntent, Communications) == 0
    assert resource_count(EvidenceObligation, NewYou.Audit) == 0
    assert row_count("communications_protected_envelopes") == 0
    assert row_count("communications_envelope_nonces") == nonce_count
    assert row_count("identity_pmr_reservations") == pmr_reservation_count
    assert Repo.all(from job in Oban.Job) == []
  end

  test "an accepted resend creates one replacement challenge and no central Audit schedule", %{
    nonce_count: nonce_count
  } do
    assert {:ok, %{account_id: account_id}} = Identity.register(valid_request())
    operation_id = Ecto.UUID.generate()

    assert {:ok, :verification_pending} =
             Identity.resend_verification(%{operation_id: operation_id, account_id: account_id})

    tokens = records(Identity.Token, Identity)
    active_challenges = Enum.filter(tokens, &(&1.purpose == "email_verification"))
    [replacement] = active_challenges
    intents = records(MessageIntent, Communications)
    [registration_intent, resend_intent] = intents

    assert length(tokens) == 2
    [revocation] = Enum.filter(tokens, &(&1.purpose == "revocation"))
    assert revocation.account_id == account_id
    assert resource_count(Identity.ResendOperation, Identity) == 1
    assert resource_count(EvidenceObligation, NewYou.Audit) == 1
    assert row_count("communications_protected_envelopes") == 2
    assert row_count("communications_envelope_nonces") == nonce_count + 2
    assert length(Repo.all(from job in Oban.Job)) == 1
    assert resend_intent.source_operation_id == operation_id
    refute resend_intent.source_reference == registration_intent.source_reference
    assert resend_intent.source_reference == replacement.jti
    assert resend_intent.destination == registration_intent.destination
  end

  test "a protected-envelope failure rolls back challenge replacement and resend records", %{
    nonce_count: nonce_count
  } do
    assert {:ok, %{account_id: account_id}} = Identity.register(valid_request())
    [original] = current_challenges()
    operation_id = Ecto.UUID.generate()

    reject_inserts("communications_protected_envelopes", "resend_envelope_failure")

    assert {:error, :resend_unavailable} =
             Identity.resend_verification(%{operation_id: operation_id, account_id: account_id})

    [still_current] = current_challenges()
    assert still_current.jti == original.jti
    assert length(records(Identity.Token, Identity)) == 1
    assert resource_count(Identity.ResendOperation, Identity) == 0
    assert resource_count(MessageIntent, Communications) == 1
    assert resource_count(EvidenceObligation, NewYou.Audit) == 1
    assert row_count("communications_protected_envelopes") == 1
    assert row_count("communications_envelope_nonces") == nonce_count + 1
    assert length(Repo.all(from job in Oban.Job)) == 1
  end

  test "same-ID resend replay does not create a second challenge, intent, or envelope" do
    assert {:ok, %{account_id: account_id}} = Identity.register(valid_request())
    request = %{operation_id: Ecto.UUID.generate(), account_id: account_id}

    assert {:ok, :verification_pending} = Identity.resend_verification(request)
    [first_challenge] = current_challenges()
    assert {:ok, :verification_pending} = Identity.resend_verification(request)
    [replayed_challenge] = current_challenges()

    assert replayed_challenge.jti == first_challenge.jti
    assert resource_count(Identity.ResendOperation, Identity) == 1
    assert resource_count(MessageIntent, Communications) == 2
    assert resource_count(EvidenceObligation, NewYou.Audit) == 1
    assert row_count("communications_protected_envelopes") == 2
    assert length(Repo.all(from job in Oban.Job)) == 1
  end

  test "resend by canonical email stays inside Identity and returns the neutral outcome" do
    registration = valid_request()
    assert {:ok, %{account_id: account_id}} = Identity.register(registration)

    resend = %{operation_id: Ecto.UUID.generate(), email: registration.email}
    send_resend = &Identity.resend_verification_by_email/1

    assert {:ok, :verification_pending} = send_resend.(resend)
    assert {:ok, :verification_pending} = send_resend.(resend)
    assert resource_count(Identity.ResendOperation, Identity) == 1
    assert resource_count(MessageIntent, Communications) == 2

    [resend_operation] = records(Identity.ResendOperation, Identity)
    assert resend_operation.account_id == account_id

    missing = %{
      operation_id: Ecto.UUID.generate(),
      email: "missing-#{System.unique_integer([:positive])}@example.test"
    }

    assert {:ok, :verification_pending} = send_resend.(missing)
    assert resource_count(Identity.ResendOperation, Identity) == 1
    assert resource_count(MessageIntent, Communications) == 2
  end

  test "replaying resend A after resend B leaves B as the current challenge" do
    assert {:ok, %{account_id: account_id}} = Identity.register(valid_request())
    resend_a = %{operation_id: Ecto.UUID.generate(), account_id: account_id}
    resend_b = %{operation_id: Ecto.UUID.generate(), account_id: account_id}

    assert {:ok, :verification_pending} = Identity.resend_verification(resend_a)
    assert {:ok, :verification_pending} = Identity.resend_verification(resend_b)
    [challenge_b] = current_challenges()

    assert {:ok, :verification_pending} = Identity.resend_verification(resend_a)
    [still_current] = current_challenges()

    assert still_current.jti == challenge_b.jti
    assert resource_count(Identity.ResendOperation, Identity) == 2
    assert resource_count(MessageIntent, Communications) == 3
    assert resource_count(EvidenceObligation, NewYou.Audit) == 1
    assert row_count("communications_protected_envelopes") == 3
    assert length(Repo.all(from job in Oban.Job)) == 1
  end

  test "a resend operation ID cannot be rebound to another account" do
    assert {:ok, %{account_id: account_a}} = Identity.register(valid_request())
    second_request = %{valid_request() | email: "second@example.test"}
    assert {:ok, %{account_id: account_b}} = Identity.register(second_request)
    operation_id = Ecto.UUID.generate()

    assert {:ok, :verification_pending} =
             Identity.resend_verification(%{operation_id: operation_id, account_id: account_a})

    assert {:error, :resend_unavailable} =
             Identity.resend_verification(%{operation_id: operation_id, account_id: account_b})

    assert resource_count(Identity.ResendOperation, Identity) == 1
    assert resource_count(MessageIntent, Communications) == 3
    assert row_count("communications_protected_envelopes") == 3
  end

  test "a revoked Account receives a neutral resend response without new state" do
    assert {:ok, %{account_id: account_id}} = Identity.register(valid_request())
    [original] = current_challenges()

    Repo.query!("UPDATE accounts SET credential_status = 'revoked' WHERE id = $1", [
      Ecto.UUID.dump!(account_id)
    ])

    assert {:ok, :verification_pending} =
             Identity.resend_verification(%{
               operation_id: Ecto.UUID.generate(),
               account_id: account_id
             })

    assert [challenge] = current_challenges()
    assert challenge.jti == original.jti
    assert resource_count(Identity.ResendOperation, Identity) == 0
    assert resource_count(MessageIntent, Communications) == 1
    assert row_count("communications_protected_envelopes") == 1
    assert length(Repo.all(from job in Oban.Job)) == 1
  end

  test "Token cleanup does not allow an accepted resend operation ID to be reused" do
    assert {:ok, %{account_id: account_id}} = Identity.register(valid_request())
    request = %{operation_id: Ecto.UUID.generate(), account_id: account_id}
    assert {:ok, :verification_pending} = Identity.resend_verification(request)

    Repo.query!("UPDATE tokens SET expires_at = now() - interval '1 hour'")
    assert :ok = AshAuthentication.TokenResource.Actions.expunge_expired(Identity.Token)

    assert records(Identity.Token, Identity) == []
    assert {:ok, :verification_pending} = Identity.resend_verification(request)
    assert records(Identity.Token, Identity) == []
    assert resource_count(Identity.ResendOperation, Identity) == 1
    assert resource_count(MessageIntent, Communications) == 2
    assert row_count("communications_protected_envelopes") == 2
  end

  test "same-ID and distinct-ID resend races converge on one current challenge" do
    registration = %{
      valid_request()
      | email: "race-#{System.unique_integer([:positive])}@example.test"
    }

    assert {:ok, %{account_id: account_id}} =
             Sandbox.unboxed_run(Repo, fn -> Identity.register(registration) end)

    on_exit(fn -> cleanup_unboxed_registration(account_id) end)

    same_id = %{operation_id: Ecto.UUID.generate(), account_id: account_id}

    assert_concurrent_resends(List.duplicate(same_id, 6))

    distinct_ids =
      for _ <- 1..2 do
        %{operation_id: Ecto.UUID.generate(), account_id: account_id}
      end

    assert_concurrent_resends(distinct_ids)

    operation_ids = [
      registration.operation_id,
      same_id.operation_id | Enum.map(distinct_ids, & &1.operation_id)
    ]

    summary =
      Sandbox.unboxed_run(Repo, fn ->
        active_challenges =
          Ash.read!(Identity.Token,
            domain: Identity,
            authorize?: false
          )
          |> Enum.filter(&(&1.account_id == account_id and &1.purpose == "email_verification"))

        intents = Enum.sum(Enum.map(operation_ids, &intent_count/1))

        envelopes =
          Enum.sum(
            Enum.map(operation_ids, fn operation_id ->
              count_for_query!(
                "SELECT count(*) FROM communications_protected_envelopes e JOIN message_intents i ON i.id = e.message_intent_id WHERE i.source_operation_id = $1",
                [Ecto.UUID.dump!(operation_id)]
              )
            end)
          )

        %{
          operations:
            length(Ash.read!(Identity.ResendOperation, domain: Identity, authorize?: false)),
          active_challenges: active_challenges,
          intents: intents,
          envelopes: envelopes
        }
      end)

    assert summary.operations == 3
    assert length(summary.active_challenges) == 1
    assert summary.intents == 4
    assert summary.envelopes == 4
  end

  defp valid_request do
    %{
      operation_id: Ecto.UUID.generate(),
      first_name: "Alice",
      surname: "Example",
      email: " Alice+campaign.Example@EXAMPLE.COM ",
      password: Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false),
      preferred_language: :af,
      confirmed_age_18?: true,
      terms_version_id: @terms_id,
      privacy_version_id: @privacy_id
    }
  end

  defp current_challenges do
    Enum.filter(records(Identity.Token, Identity), &(&1.purpose == "email_verification"))
  end

  defp records(resource, domain),
    do: Ash.read!(resource, domain: domain, authorize?: false)

  defp resource_count(resource, domain), do: length(records(resource, domain))

  defp row_count(table) do
    %{rows: [[count]]} = Repo.query!("SELECT count(*) FROM #{table}")
    count
  end

  defp assert_concurrent_resends(requests) do
    parent = self()

    tasks =
      Enum.map(requests, fn request ->
        Task.async(fn ->
          send(parent, {:resend_ready, self()})

          receive do
            :start -> Sandbox.unboxed_run(Repo, fn -> Identity.resend_verification(request) end)
          after
            15_000 -> {:error, :resend_barrier_timeout}
          end
        end)
      end)

    for _ <- requests do
      assert_receive {:resend_ready, _pid}, 5_000
    end

    Enum.each(tasks, &send(&1.pid, :start))
    results = Enum.map(tasks, &Task.await(&1, 60_000))

    assert Enum.all?(results, &(&1 == {:ok, :verification_pending}))
  end

  defp intent_count(operation_id) do
    count_for_query!(
      "SELECT count(*) FROM message_intents WHERE source_operation_id = $1",
      [Ecto.UUID.dump!(operation_id)]
    )
  end

  defp count_for_query!(query, params) do
    %{rows: [[count]]} = Repo.query!(query, params)
    count
  end

  defp reject_inserts(table, name) do
    function_name = "#{name}_function"

    Repo.query!("""
    CREATE FUNCTION #{function_name}() RETURNS trigger
    LANGUAGE plpgsql AS $$
    BEGIN
      RAISE EXCEPTION 'forced #{name}' USING ERRCODE = '23514';
    END;
    $$
    """)

    Repo.query!("""
    CREATE TRIGGER #{name}
    BEFORE INSERT ON #{table}
    FOR EACH ROW EXECUTE FUNCTION #{function_name}()
    """)
  end

  defp cleanup_unboxed_registration(account_id) do
    Sandbox.unboxed_run(Repo, fn ->
      Repo.transaction(fn -> cleanup_unboxed_registration_rows(account_id) end)
    end)
  end

  defp cleanup_unboxed_registration_rows(account_id) do
    account_binary = Ecto.UUID.dump!(account_id)

    %{rows: registration_rows} =
      Repo.query!(
        "SELECT operation_id FROM registration_operations WHERE created_account_id = $1",
        [
          account_binary
        ]
      )

    %{rows: resend_rows} =
      Repo.query!("SELECT operation_id FROM resend_operations WHERE account_id = $1", [
        account_binary
      ])

    registration_operation_ids = Enum.map(registration_rows, fn [id] -> id end)
    operation_ids = registration_operation_ids ++ Enum.map(resend_rows, fn [id] -> id end)

    %{rows: nonce_rows} =
      Repo.query!(
        "SELECT e.nonce FROM communications_protected_envelopes e JOIN message_intents i ON i.id = e.message_intent_id WHERE i.source_operation_id = ANY($1::uuid[])",
        [operation_ids]
      )

    if registration_operation_ids != [] do
      Repo.query!(
        "DELETE FROM oban_jobs WHERE args->'primary_key'->>'id' IN (SELECT id::text FROM evidence_obligations WHERE source_operation_id = ANY($1::uuid[]))",
        [registration_operation_ids]
      )

      Repo.query!(
        "DELETE FROM evidence_obligations WHERE source_operation_id = ANY($1::uuid[])",
        [registration_operation_ids]
      )
    end

    Repo.query!(
      "DELETE FROM communications_protected_envelopes e USING message_intents i WHERE i.id = e.message_intent_id AND i.source_operation_id = ANY($1::uuid[])",
      [operation_ids]
    )

    for [nonce] <- nonce_rows do
      Repo.query!("DELETE FROM communications_envelope_nonces WHERE nonce = $1", [nonce])
    end

    Repo.query!("DELETE FROM message_intents WHERE source_operation_id = ANY($1::uuid[])", [
      operation_ids
    ])

    Repo.query!("DELETE FROM tokens WHERE account_id = $1", [account_binary])
    Repo.query!("DELETE FROM resend_operations WHERE account_id = $1", [account_binary])

    Repo.query!("DELETE FROM registration_operations WHERE created_account_id = $1", [
      account_binary
    ])

    Repo.query!("DELETE FROM accounts WHERE id = $1", [account_binary])

    # PMR reservations are permanent Identity history and cannot be cleaned up.
  end

  defp restore_env(key, nil), do: Application.delete_env(:new_you, key)
  defp restore_env(key, value), do: Application.put_env(:new_you, key, value)
end
