defmodule NewYou.Audit.RegistrationEvidenceTest do
  use NewYou.DataCase, async: false

  @terms_id "NEWYOU-TERMS-EN-DEV-2026-10-27-001"
  @privacy_id "NEWYOU-PRIVACY-EN-DEV-2026-10-27-001"

  setup do
    previous_keys = Application.get_env(:new_you, :identity_registration_binding_keys)
    previous_token_secret = Application.get_env(:new_you, :identity_token_signing_secret)
    previous_communications_keyring = Application.get_env(:new_you, :communications_keyring)

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
      restore_app_env(:identity_registration_binding_keys, previous_keys)
      restore_app_env(:identity_token_signing_secret, previous_token_secret)
      restore_app_env(:communications_keyring, previous_communications_keyring)
    end)

    {:ok,
     nonce_count: row_count("communications_envelope_nonces"),
     pmr_reservation_count: row_count("identity_pmr_reservations")}
  end

  test "successful registration creates one open E2 obligation and its Audit job" do
    request = valid_request()

    assert {:ok, %{status: :verification_pending, account_id: account_id}} =
             NewYou.Identity.register(request)

    assert is_binary(account_id)

    account =
      Ash.get!(NewYou.Identity.Account, account_id, domain: NewYou.Identity, authorize?: false)

    assert NewYou.Identity.PMR.valid?(account.pmr)

    [obligation] = audit_records("EvidenceObligation")
    assert obligation.evidence_type == :account_registration_pmr_assignment
    assert obligation.source_operation_id == request.operation_id
    assert obligation.state == :open

    [job] = scheduled_audit_jobs()
    assert job.queue == "audit"

    assert job.args == %{
             "primary_key" => %{"id" => obligation.id},
             "metadata" => %{},
             "action_arguments" => %{},
             "tenant" => nil
           }
  end

  test "the Identity owner action repeats registration admission and derives its binding" do
    request = %{valid_request() | email: "Alice+campaign.Example@EXAMPLE.COM"}
    pmr = valid_pmr()

    assert {:ok, %{status: :verification_pending, account_id: account_id}} =
             accept_registration_directly(request, pmr)

    account =
      Ash.get!(NewYou.Identity.Account, account_id, domain: NewYou.Identity, authorize?: false)

    assert account.email == "Alice+campaign.Example@example.com"

    assert {:ok, %{account_id: ^account_id, verification_proof: nil}} =
             NewYou.Identity.register(request)

    assert length(audit_records("EvidenceObligation")) == 1
    assert length(scheduled_audit_jobs()) == 1
  end

  test "the Identity owner action rejects requests that fail registration admission" do
    request = valid_request()
    pmr = valid_pmr()

    attacks = [
      {%{request | operation_id: "not-a-uuid"}, pmr},
      {%{request | operation_id: "018ecb40-c457-73e6-a400-000398daddd9"}, pmr},
      {%{request | preferred_language: :fr}, pmr},
      {%{request | terms_version_id: "unapproved-terms"}, pmr},
      {%{request | privacy_version_id: "unapproved-privacy"}, pmr},
      {Map.delete(request, :confirmed_age_18?), pmr},
      {%{request | confirmed_age_18?: false}, pmr},
      {request, "PMR-0123456789ABCDEFB"}
    ]

    for {input, assigned_pmr} <- attacks do
      assert {:error, _} = accept_registration_directly(input, assigned_pmr)
    end

    assert NewYou.Identity.Account |> Ash.read!(domain: NewYou.Identity, authorize?: false) == []

    assert NewYou.Identity.RegistrationOperation
           |> Ash.read!(domain: NewYou.Identity, authorize?: false) == []

    assert audit_records("EvidenceObligation") == []
    assert scheduled_audit_jobs() == []
    assert row_count("tokens") == 0
  end

  test "an identical registration retry does not multiply the obligation or schedule" do
    request = valid_request()

    assert {:ok, %{account_id: account_id}} = NewYou.Identity.register(request)

    assert {:ok, %{account_id: ^account_id, verification_proof: nil}} =
             NewYou.Identity.register(request)

    assert length(audit_records("EvidenceObligation")) == 1
    assert length(scheduled_audit_jobs()) == 1
  end

  test "a neutral duplicate-email registration creates no additional E2 obligation or job" do
    first_request = valid_request()
    duplicate_request = %{valid_request() | email: "alice+campaign.example@EXAMPLE.COM"}

    assert {:ok, %{account_id: account_id}} = NewYou.Identity.register(first_request)
    assert is_binary(account_id)

    assert {:ok, %{account_id: nil}} = NewYou.Identity.register(duplicate_request)

    assert length(audit_records("EvidenceObligation")) == 1
    assert length(scheduled_audit_jobs()) == 1
  end

  test "a failed Audit schedule rolls back all registration acceptance writes", %{
    nonce_count: nonce_count,
    pmr_reservation_count: pmr_reservation_count
  } do
    reject_inserts("oban_jobs", "audit_schedule_failure")

    assert {:error, :registration_unavailable} = NewYou.Identity.register(valid_request())

    assert NewYou.Identity.Account |> Ash.read!(domain: NewYou.Identity, authorize?: false) == []

    assert NewYou.Identity.RegistrationOperation
           |> Ash.read!(domain: NewYou.Identity, authorize?: false) == []

    assert audit_records("EvidenceObligation") == []
    assert row_count("tokens") == 0
    assert row_count("message_intents") == 0
    assert row_count("communications_protected_envelopes") == 0
    assert row_count("communications_envelope_nonces") == nonce_count
    assert row_count("identity_pmr_reservations") == pmr_reservation_count
    assert scheduled_audit_jobs() == []
  end

  test "a failed obligation creation rolls back all registration acceptance writes", %{
    nonce_count: nonce_count,
    pmr_reservation_count: pmr_reservation_count
  } do
    reject_inserts("evidence_obligations", "evidence_obligation_failure")

    assert {:error, :registration_unavailable} = NewYou.Identity.register(valid_request())

    assert NewYou.Identity.Account |> Ash.read!(domain: NewYou.Identity, authorize?: false) == []

    assert NewYou.Identity.RegistrationOperation
           |> Ash.read!(domain: NewYou.Identity, authorize?: false) == []

    assert audit_records("EvidenceObligation") == []
    assert row_count("tokens") == 0
    assert row_count("message_intents") == 0
    assert row_count("communications_protected_envelopes") == 0
    assert row_count("communications_envelope_nonces") == nonce_count
    assert row_count("identity_pmr_reservations") == pmr_reservation_count
    assert scheduled_audit_jobs() == []
  end

  test "a later Identity write failure rolls back the inserted Audit job", %{
    nonce_count: nonce_count,
    pmr_reservation_count: pmr_reservation_count
  } do
    reject_inserts("registration_operations", "late_identity_acceptance_failure")

    assert {:error, :registration_unavailable} = NewYou.Identity.register(valid_request())

    assert NewYou.Identity.Account |> Ash.read!(domain: NewYou.Identity, authorize?: false) == []

    assert NewYou.Identity.RegistrationOperation
           |> Ash.read!(domain: NewYou.Identity, authorize?: false) == []

    assert audit_records("EvidenceObligation") == []
    assert row_count("tokens") == 0
    assert row_count("message_intents") == 0
    assert row_count("communications_protected_envelopes") == 0
    assert row_count("communications_envelope_nonces") == nonce_count
    assert row_count("identity_pmr_reservations") == pmr_reservation_count
    assert scheduled_audit_jobs() == []
  end

  test "Audit materialisation is idempotent and leaves Identity truth unchanged" do
    request = valid_request()
    assert {:ok, %{account_id: account_id}} = NewYou.Identity.register(request)
    [obligation] = audit_records("EvidenceObligation")
    [job] = scheduled_audit_jobs()

    identity_before = identity_truth(account_id)

    worker =
      AshOban.Info.oban_trigger(NewYou.Audit.EvidenceObligation, :registration_evidence).worker

    oban_job = %Oban.Job{args: job.args, attempt: 1, max_attempts: 10}

    assert :ok = worker.perform(oban_job)
    assert :ok = worker.perform(oban_job)

    fulfilled =
      Ash.get!(NewYou.Audit.EvidenceObligation, obligation.id,
        domain: NewYou.Audit,
        authorize?: false
      )

    assert fulfilled.state == :fulfilled
    assert length(audit_records("EvidenceRecord")) == 1
    assert identity_truth(account_id) == identity_before

    refute function_exported?(NewYou.Audit, :create_evidence_record, 2)
    refute function_exported?(NewYou.Audit, :fulfill_evidence_obligation, 3)

    refute Ash.Resource.Info.action(NewYou.Audit.EvidenceRecord, :update)
    refute Ash.Resource.Info.action(NewYou.Audit.EvidenceRecord, :destroy)

    assert {:error, _} =
             Ash.update(fulfilled, %{},
               action: :fulfill,
               domain: NewYou.Audit,
               authorize?: false
             )
  end

  test "an open obligation cannot be fulfilled until its EvidenceRecord exists" do
    assert {:ok, _} = NewYou.Identity.register(valid_request())
    [obligation] = audit_records("EvidenceObligation")

    assert {:error, _} =
             Ash.update(obligation, %{},
               action: :fulfill,
               domain: NewYou.Audit,
               authorize?: false
             )

    refreshed =
      Ash.get!(NewYou.Audit.EvidenceObligation, obligation.id,
        domain: NewYou.Audit,
        authorize?: false
      )

    assert refreshed.state == :open
    assert audit_records("EvidenceRecord") == []
  end

  test "an open obligation cannot be stranded by standalone record creation" do
    assert {:ok, _} = NewYou.Identity.register(valid_request())
    [obligation] = audit_records("EvidenceObligation")

    refute function_exported?(NewYou.Audit, :create_evidence_record, 2)

    refreshed =
      Ash.get!(NewYou.Audit.EvidenceObligation, obligation.id,
        domain: NewYou.Audit,
        authorize?: false
      )

    assert refreshed.state == :open
    assert audit_records("EvidenceRecord") == []
  end

  test "Audit exposes only purpose-bound mutation and read interfaces" do
    refute function_exported?(NewYou.Audit, :create_evidence_record, 2)
    refute function_exported?(NewYou.Audit, :fulfill_evidence_obligation, 3)
    refute function_exported?(NewYou.Audit, :list_evidence_obligations, 0)
    refute function_exported?(NewYou.Audit, :list_evidence_obligations, 1)
    refute function_exported?(NewYou.Audit, :list_evidence_records, 0)
    refute function_exported?(NewYou.Audit, :list_evidence_records, 1)
    assert function_exported?(NewYou.Audit, :materialize_registration_evidence, 2)
  end

  test "PostgreSQL rejects lifecycle values outside the EvidenceObligation contract" do
    assert {:ok, _} = NewYou.Identity.register(valid_request())
    [obligation] = audit_records("EvidenceObligation")

    assert_raise Postgrex.Error, fn ->
      Repo.query!("UPDATE evidence_obligations SET state = 'invalid' WHERE id = $1", [
        Ecto.UUID.dump!(obligation.id)
      ])
    end

    refreshed =
      Ash.get!(NewYou.Audit.EvidenceObligation, obligation.id,
        domain: NewYou.Audit,
        authorize?: false
      )

    assert refreshed.state == :open
  end

  test "PostgreSQL enforces one obligation per source operation and the EvidenceRecord foreign key" do
    request = valid_request()
    assert {:ok, _} = NewYou.Identity.register(request)
    [obligation] = audit_records("EvidenceObligation")

    assert {:error, _} =
             NewYou.Audit.establish_registration_obligation(
               %{
                 source_operation_id: request.operation_id,
                 source_occurred_at: DateTime.utc_now()
               },
               authorize?: false
             )

    assert {:error, _} =
             Ash.create(NewYou.Audit.EvidenceRecord, %{obligation_id: Ecto.UUID.generate()},
               action: :materialize,
               domain: NewYou.Audit,
               authorize?: false
             )

    assert length(audit_records("EvidenceObligation")) == 1
    assert audit_records("EvidenceRecord") == []
    assert length(scheduled_audit_jobs()) == 1
    assert is_binary(obligation.id)
  end

  test "an open obligation with a committed record recovers the same assertion" do
    assert {:ok, _} = NewYou.Identity.register(valid_request())
    [obligation] = audit_records("EvidenceObligation")

    record =
      Ash.create!(NewYou.Audit.EvidenceRecord, %{obligation_id: obligation.id},
        action: :materialize,
        domain: NewYou.Audit,
        authorize?: false
      )

    assert {:ok, %{evidence_record_id: record_id}} =
             NewYou.Audit.materialize_registration_evidence(%{primary_key: %{id: obligation.id}},
               authorize?: false
             )

    assert record_id == record.id
    assert [%{id: ^record_id}] = audit_records("EvidenceRecord")

    assert %{state: :fulfilled} =
             NewYou.Audit.get_evidence_obligation!(obligation.id, authorize?: false)
  end

  test "the durable scheduler recreates missing execution from open obligations" do
    assert {:ok, _} = NewYou.Identity.register(valid_request())
    [obligation] = audit_records("EvidenceObligation")
    Repo.query!("DELETE FROM oban_jobs WHERE queue = 'audit'")
    trigger = AshOban.Info.oban_trigger(NewYou.Audit.EvidenceObligation, :registration_evidence)

    configured =
      AshOban.config(
        Application.fetch_env!(:new_you, :ash_domains),
        Application.fetch_env!(:new_you, Oban)
      )

    assert {"* * * * *", trigger.scheduler, []} in configured[:cron][:crontab]
    assert is_atom(trigger.scheduler) and not is_nil(trigger.scheduler)
    assert :ok = trigger.scheduler.perform(%Oban.Job{args: %{}})
    assert [%{args: %{"primary_key" => %{"id" => id}}}] = scheduled_audit_jobs()
    assert id == obligation.id
  end

  test "PostgreSQL refuses fulfilled obligations without evidence" do
    assert {:ok, _} = NewYou.Identity.register(valid_request())
    [obligation] = audit_records("EvidenceObligation")

    assert_raise Postgrex.Error, fn ->
      Repo.query!(
        "UPDATE evidence_obligations SET state = 'fulfilled', fulfilled_at = now() WHERE id = $1",
        [Ecto.UUID.dump!(obligation.id)]
      )
    end
  end

  test "PostgreSQL preserves pending provenance and refuses terminal insertion" do
    assert {:ok, _} = NewYou.Identity.register(valid_request())

    for assignment <- [
          "source_operation_id = gen_random_uuid()",
          "source_occurred_at = now()",
          "evidence_type = 'other'",
          "id = gen_random_uuid()",
          "created_at = now()"
        ] do
      assert_raise Postgrex.Error, fn ->
        Repo.query!("UPDATE evidence_obligations SET " <> assignment)
      end
    end

    assert_raise Postgrex.Error, fn ->
      Repo.query!("""
      INSERT INTO evidence_obligations (source_operation_id, source_occurred_at, evidence_type, state, fulfilled_at)
      VALUES (gen_random_uuid(), now(), 'account_registration_pmr_assignment', 'fulfilled', now())
      """)
    end
  end

  test "PostgreSQL preserves evidence and its terminal immutable provenance" do
    assert {:ok, _} = NewYou.Identity.register(valid_request())
    [obligation] = audit_records("EvidenceObligation")

    assert {:ok, _} =
             NewYou.Audit.materialize_registration_evidence(%{primary_key: %{id: obligation.id}},
               authorize?: false
             )

    for statement <- [
          "UPDATE evidence_records SET created_at = now()",
          "DELETE FROM evidence_records",
          "TRUNCATE evidence_records",
          "UPDATE evidence_obligations SET source_occurred_at = now()",
          "UPDATE evidence_obligations SET state = 'open', fulfilled_at = NULL",
          "DELETE FROM evidence_obligations",
          "TRUNCATE evidence_obligations CASCADE"
        ] do
      assert_raise Postgrex.Error, fn -> Repo.query!(statement) end
    end
  end

  test "PostgreSQL rejects a second assertion even through a direct insert" do
    assert {:ok, _} = NewYou.Identity.register(valid_request())
    [obligation] = audit_records("EvidenceObligation")

    assert {:ok, _} =
             NewYou.Audit.materialize_registration_evidence(
               %{primary_key: %{id: obligation.id}},
               authorize?: false
             )

    assert_raise Postgrex.Error, fn ->
      Repo.query!(
        "INSERT INTO evidence_records (obligation_id) VALUES ($1)",
        [Ecto.UUID.dump!(obligation.id)]
      )
    end

    assert length(audit_records("EvidenceRecord")) == 1
  end

  test "corrupt fulfilled evidence fails safely without rebuilding source truth" do
    assert {:ok, %{account_id: account_id}} = NewYou.Identity.register(valid_request())
    [obligation] = audit_records("EvidenceObligation")

    assert {:ok, _} =
             NewYou.Audit.materialize_registration_evidence(
               %{primary_key: %{id: obligation.id}},
               authorize?: false
             )

    before = identity_truth(account_id)

    # Synthetic corruption is possible only after deliberately disabling a DB
    # guard. The sandbox rolls back this fixture and its transactional DDL.
    Repo.query!("ALTER TABLE evidence_records DISABLE TRIGGER evidence_records_immutable")
    Repo.query!("DELETE FROM evidence_records")
    Repo.query!("ALTER TABLE evidence_records ENABLE TRIGGER evidence_records_immutable")

    assert {:error, error} =
             NewYou.Audit.materialize_registration_evidence(
               %{primary_key: %{id: obligation.id}},
               authorize?: false
             )

    assert Exception.message(error) =~ "evidence_obligation_integrity_mismatch"
    assert identity_truth(account_id) == before
    assert audit_records("EvidenceRecord") == []

    assert %{state: :fulfilled} =
             NewYou.Audit.get_evidence_obligation!(obligation.id, authorize?: false)
  end

  test "untrusted materialisation selectors and excess evidence payload fail closed" do
    assert {:ok, %{account_id: account_id}} = NewYou.Identity.register(valid_request())
    [obligation] = audit_records("EvidenceObligation")
    before = identity_truth(account_id)

    for key <- [%{}, %{id: "invalid"}, %{id: Ecto.UUID.generate()}] do
      assert {:error, _} =
               NewYou.Audit.materialize_registration_evidence(
                 %{primary_key: key},
                 authorize?: false
               )
    end

    assert {:error, _} =
             Ash.create(
               NewYou.Audit.EvidenceRecord,
               %{obligation_id: obligation.id, source_payload: "forbidden", bearer: "forbidden"},
               action: :materialize,
               domain: NewYou.Audit,
               authorize?: false
             )

    assert identity_truth(account_id) == before
    assert audit_records("EvidenceRecord") == []
  end

  defp valid_request do
    %{
      operation_id: Ecto.UUID.generate(),
      first_name: "Alice",
      surname: "Example",
      email: "alice+campaign.example@example.com",
      password: Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false),
      preferred_language: :en,
      confirmed_age_18?: true,
      terms_version_id: @terms_id,
      privacy_version_id: @privacy_id
    }
  end

  defp valid_pmr do
    {:ok, pmr} = NewYou.Identity.PMR.generate()
    pmr
  end

  defp accept_registration_directly(registration_input, pmr) do
    NewYou.Identity.accept_new_registration(
      %{
        registration_input: registration_input,
        pmr: pmr
      },
      authorize?: false
    )
  end

  defp audit_records(resource_name) do
    resource = Module.concat([NewYou, Audit, resource_name])

    if Code.ensure_loaded?(resource) do
      Ash.read!(resource, domain: Module.concat([NewYou, Audit]), authorize?: false)
    else
      []
    end
  end

  defp scheduled_audit_jobs do
    case Repo.query!("SELECT to_regclass('public.oban_jobs')") do
      %{rows: [[nil]]} ->
        []

      %{rows: [[_table]]} ->
        %{rows: rows} =
          Repo.query!(
            "SELECT queue, args FROM public.oban_jobs WHERE queue = $1 ORDER BY id",
            ["audit"]
          )

        Enum.map(rows, fn [queue, args] -> %{queue: queue, args: args} end)
    end
  end

  defp identity_truth(account_id) do
    account =
      Ash.get!(NewYou.Identity.Account, account_id, domain: NewYou.Identity, authorize?: false)

    operations =
      Ash.read!(NewYou.Identity.RegistrationOperation, domain: NewYou.Identity, authorize?: false)

    %{account: account, operations: operations, token_count: row_count("tokens")}
  end

  defp row_count(table) do
    %{rows: [[count]]} = Repo.query!("SELECT count(*) FROM #{table}")
    count
  end

  defp reject_inserts(table, name) do
    function_name = "#{name}_function"
    trigger_name = name

    Repo.query!("""
    CREATE FUNCTION #{function_name}() RETURNS trigger
    LANGUAGE plpgsql AS $$
    BEGIN
      RAISE EXCEPTION 'forced #{name}' USING ERRCODE = '23514';
    END;
    $$
    """)

    Repo.query!("""
    CREATE TRIGGER #{trigger_name}
    BEFORE INSERT ON #{table}
    FOR EACH ROW EXECUTE FUNCTION #{function_name}()
    """)
  end

  defp restore_app_env(key, nil), do: Application.delete_env(:new_you, key)
  defp restore_app_env(key, value), do: Application.put_env(:new_you, key, value)
end
