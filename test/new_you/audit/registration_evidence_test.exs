defmodule NewYou.Audit.RegistrationEvidenceTest do
  use NewYou.DataCase, async: false
  require Ash.Query

  @terms_id "NEWYOU-TERMS-EN-DEV-2026-10-27-001"
  @privacy_id "NEWYOU-PRIVACY-EN-DEV-2026-10-27-001"

  setup do
    Process.put({__MODULE__, :operation_ids}, [])
    Process.put({__MODULE__, :emails}, [])
    Process.put({__MODULE__, :generated_pmrs}, [])
    previous_keys = Application.get_env(:new_you, :identity_registration_binding_keys)
    previous_token_secret = Application.get_env(:new_you, :identity_token_signing_secret)
    previous_communications_keyring = Application.get_env(:new_you, :communications_keyring)
    previous_pmr_generator = Application.get_env(:new_you, :identity_pmr_generator)

    Application.put_env(:new_you, :identity_registration_binding_keys, %{
      active_version: "test-v1",
      keys: %{"test-v1" => :crypto.strong_rand_bytes(32)}
    })

    Application.put_env(:new_you, :identity_token_signing_secret, :crypto.strong_rand_bytes(32))

    Application.put_env(:new_you, :communications_keyring, %{
      active: "test-v1",
      keys: %{"test-v1" => :crypto.strong_rand_bytes(32)}
    })

    Application.put_env(:new_you, :identity_pmr_generator, fn ->
      {:ok, pmr} = NewYou.Identity.PMR.generate()

      Process.put(
        {__MODULE__, :generated_pmrs},
        [pmr | Process.get({__MODULE__, :generated_pmrs}, [])]
      )

      {:ok, pmr}
    end)

    on_exit(fn ->
      restore_app_env(:identity_registration_binding_keys, previous_keys)
      restore_app_env(:identity_token_signing_secret, previous_token_secret)
      restore_app_env(:communications_keyring, previous_communications_keyring)
      restore_app_env(:identity_pmr_generator, previous_pmr_generator)
    end)

    {:ok, nonce_count: row_count("communications_envelope_nonces")}
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

    assert identity_records(NewYou.Identity.Account) == []
    assert identity_records(NewYou.Identity.RegistrationOperation) == []

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
    duplicate_email = String.replace(first_request.email, "@example.test", "@EXAMPLE.TEST")
    duplicate_request = %{valid_request() | email: duplicate_email}

    assert {:ok, %{account_id: account_id}} = NewYou.Identity.register(first_request)
    assert is_binary(account_id)

    assert {:ok, %{account_id: nil}} = NewYou.Identity.register(duplicate_request)

    assert length(audit_records("EvidenceObligation")) == 1
    assert length(scheduled_audit_jobs()) == 1
  end

  test "a failed Audit schedule rolls back all registration acceptance writes", %{
    nonce_count: nonce_count
  } do
    reject_inserts("oban_jobs", "audit_schedule_failure")

    assert {:error, :registration_unavailable} = NewYou.Identity.register(valid_request())

    assert identity_records(NewYou.Identity.Account) == []
    assert identity_records(NewYou.Identity.RegistrationOperation) == []

    assert audit_records("EvidenceObligation") == []
    assert row_count("tokens") == 0
    assert row_count("message_intents") == 0
    assert row_count("communications_protected_envelopes") == 0
    assert row_count("communications_envelope_nonces") == nonce_count
    assert fixture_pmr_reservation_count() == 0
    assert scheduled_audit_jobs() == []
  end

  test "a failed obligation creation rolls back all registration acceptance writes", %{
    nonce_count: nonce_count
  } do
    reject_inserts("evidence_obligations", "evidence_obligation_failure")

    assert {:error, :registration_unavailable} = NewYou.Identity.register(valid_request())

    assert identity_records(NewYou.Identity.Account) == []
    assert identity_records(NewYou.Identity.RegistrationOperation) == []

    assert audit_records("EvidenceObligation") == []
    assert row_count("tokens") == 0
    assert row_count("message_intents") == 0
    assert row_count("communications_protected_envelopes") == 0
    assert row_count("communications_envelope_nonces") == nonce_count
    assert fixture_pmr_reservation_count() == 0
    assert scheduled_audit_jobs() == []
  end

  test "a later Identity write failure rolls back the inserted Audit job", %{
    nonce_count: nonce_count
  } do
    reject_inserts("registration_operations", "late_identity_acceptance_failure")

    assert {:error, :registration_unavailable} = NewYou.Identity.register(valid_request())

    assert identity_records(NewYou.Identity.Account) == []
    assert identity_records(NewYou.Identity.RegistrationOperation) == []

    assert audit_records("EvidenceObligation") == []
    assert row_count("tokens") == 0
    assert row_count("message_intents") == 0
    assert row_count("communications_protected_envelopes") == 0
    assert row_count("communications_envelope_nonces") == nonce_count
    assert fixture_pmr_reservation_count() == 0
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

  test "standalone record creation is not exposed through a Domain interface" do
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
    request = valid_request()
    assert {:ok, _} = NewYou.Identity.register(request)
    [obligation] = audit_records("EvidenceObligation")

    Repo.query!(
      "DELETE FROM oban_jobs WHERE queue = 'audit' AND args->'primary_key'->>'id' = $1",
      [obligation.id]
    )

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
    [obligation] = audit_records("EvidenceObligation")

    for assignment <- [
          "source_operation_id = gen_random_uuid()",
          "source_occurred_at = now()",
          "evidence_type = 'other'",
          "id = gen_random_uuid()",
          "created_at = now()"
        ] do
      assert_raise Postgrex.Error, fn ->
        Repo.query!(
          "UPDATE evidence_obligations SET " <> assignment <> " WHERE id = $1",
          [Ecto.UUID.dump!(obligation.id)]
        )
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
    request = valid_request()
    assert {:ok, _} = NewYou.Identity.register(request)
    [obligation] = audit_records("EvidenceObligation")

    assert {:ok, _} =
             NewYou.Audit.materialize_registration_evidence(%{primary_key: %{id: obligation.id}},
               authorize?: false
             )

    [record] = audit_records("EvidenceRecord")

    for {statement, id} <- [
          {"UPDATE evidence_records SET created_at = now() WHERE id = $1", record.id},
          {"DELETE FROM evidence_records WHERE id = $1", record.id},
          {"UPDATE evidence_obligations SET source_occurred_at = now() WHERE id = $1",
           obligation.id},
          {"UPDATE evidence_obligations SET state = 'open', fulfilled_at = NULL WHERE id = $1",
           obligation.id},
          {"DELETE FROM evidence_obligations WHERE id = $1", obligation.id}
        ] do
      assert_raise Postgrex.Error, fn ->
        Repo.query!(statement, [Ecto.UUID.dump!(id)])
      end
    end
  end

  test "both Audit tables attach enabled truncate guards whose installed function rejects truncation" do
    # Never TRUNCATE a shared Audit table. Check its exact trigger attachment,
    # then exercise the same installed function on disposable transaction-local
    # tables. This proves attachment plus function behavior, not a destructive
    # end-to-end TRUNCATE of historical evidence.
    for table <- ~w(evidence_records evidence_obligations) do
      trigger = table <> "_no_truncate"

      assert %{rows: [[34, enabled, 0, nil, "public", "audit_e2_immutable"]]} =
               Repo.query!(
                 """
                 SELECT t.tgtype, t.tgenabled::text, t.tgnargs, t.tgqual::text,
                        n.nspname::text, p.proname::text
                 FROM pg_trigger t
                 JOIN pg_proc p ON p.oid = t.tgfoid
                 JOIN pg_namespace n ON n.oid = p.pronamespace
                 WHERE t.tgname = $1 AND t.tgrelid = $2::text::regclass AND NOT t.tgisinternal
                 """,
                 [trigger, "public." <> table]
               )

      assert enabled in ["O", "A"]
      probe = "well114_" <> table
      Repo.query!("CREATE TEMP TABLE #{probe} (marker integer) ON COMMIT DROP")
      Repo.query!("INSERT INTO pg_temp.#{probe} VALUES (1)")

      Repo.query!("""
      CREATE TRIGGER #{trigger} BEFORE TRUNCATE ON pg_temp.#{probe}
      FOR EACH STATEMENT EXECUTE FUNCTION public.audit_e2_immutable()
      """)

      error = assert_raise Postgrex.Error, fn -> Repo.query!("TRUNCATE pg_temp.#{probe}") end
      assert error.postgres.code == :check_violation
      assert error.postgres.message == "audit_e2_immutable"
      assert %{rows: [[1]]} = Repo.query!("SELECT count(*) FROM pg_temp.#{probe}")

      # Negative control proves this probe can distinguish a missing guard.
      Repo.query!("ALTER TABLE pg_temp.#{probe} DISABLE TRIGGER #{trigger}")
      Repo.query!("TRUNCATE pg_temp.#{probe}")
      assert %{rows: [[0]]} = Repo.query!("SELECT count(*) FROM pg_temp.#{probe}")
    end
  end

  test "operation scoped reads do not decode a synthetic unsupported foreign obligation" do
    before = foreign_obligation_signature()
    request = valid_request()
    assert {:ok, %{account_id: account_id}} = NewYou.Identity.register(request)
    foreign_id = Ecto.UUID.generate()
    foreign_operation = Ecto.UUID.generate()
    unsupported = "well114_unsupported_foreign"
    scoped_read = make_ref()

    constraint_query =
      "SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conrelid = 'public.evidence_obligations'::regclass AND conname = 'evidence_obligations_evidence_type'"

    %{rows: [[constraint_before]]} = Repo.query!(constraint_query)

    # The explicit transaction always rolls back the synthetic row and DDL.
    # Its table lock excludes writers while the CHECK is absent. No retained
    # row is edited, and the immutable-provenance trigger remains enabled.
    assert {:error, decoder_error} =
             Repo.transaction(fn ->
               assert Repo.in_transaction?()
               Repo.query!("SET LOCAL lock_timeout = '2s'")

               Repo.query!(
                 "ALTER TABLE evidence_obligations DROP CONSTRAINT evidence_obligations_evidence_type"
               )

               Repo.query!(
                 """
                 INSERT INTO evidence_obligations
                   (id, source_operation_id, evidence_type, source_occurred_at, state, actor_id, target_id, outcome)
                 VALUES ($1, $2, $3, now(), 'open', $4, $4, 'succeeded')
                 """,
                 [
                   Ecto.UUID.dump!(foreign_id),
                   Ecto.UUID.dump!(foreign_operation),
                   unsupported,
                   Ecto.UUID.dump!(account_id)
                 ]
               )

               assert [%{source_operation_id: operation_id}] = audit_records("EvidenceObligation")
               assert operation_id == request.operation_id

               assert foreign_obligation_signature() == before

               assert %{rows: [[^unsupported]]} =
                        Repo.query!(
                          "SELECT evidence_type FROM evidence_obligations WHERE id = $1",
                          [Ecto.UUID.dump!(foreign_id)]
                        )

               send(self(), {:scoped_read_passed, scoped_read})

               # Ash rolls decoder errors back through the enclosing transaction.
               # Selecting only our incompatible row is a clean-CI negative control.
               NewYou.Audit.EvidenceObligation
               |> Ash.Query.filter(id == ^foreign_id)
               |> Ash.read!(domain: NewYou.Audit, authorize?: false)

               flunk("unsupported synthetic evidence type unexpectedly decoded")
             end)

    assert_receive {:scoped_read_passed, ^scoped_read}
    assert %Ash.Query{errors: errors} = decoder_error

    assert Enum.any?(errors, fn error ->
             message = Exception.message(error)
             message =~ unsupported and message =~ "cannot load"
           end)

    assert %{rows: [[0]]} =
             Repo.query!(
               "SELECT count(*) FROM evidence_obligations WHERE id = $1",
               [Ecto.UUID.dump!(foreign_id)]
             )

    assert %{rows: [[^constraint_before]]} = Repo.query!(constraint_query)

    assert foreign_obligation_signature() == before
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

    Repo.query!("DELETE FROM evidence_records WHERE obligation_id = $1", [
      Ecto.UUID.dump!(obligation.id)
    ])

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
    request = %{
      operation_id: Ecto.UUID.generate(),
      first_name: "Alice",
      surname: "Example",
      email: "alice-#{Ecto.UUID.generate()}@example.test",
      password: Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false),
      preferred_language: :en,
      confirmed_age_18?: true,
      terms_version_id: @terms_id,
      privacy_version_id: @privacy_id
    }

    Process.put(
      {__MODULE__, :operation_ids},
      [request.operation_id | Process.get({__MODULE__, :operation_ids}, [])]
    )

    Process.put(
      {__MODULE__, :emails},
      [request.email | Process.get({__MODULE__, :emails}, [])]
    )

    request
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
    operation_ids = fixture_operation_ids()

    cond do
      resource == NewYou.Audit.EvidenceObligation and operation_ids != [] ->
        resource
        |> Ash.Query.filter(source_operation_id in ^operation_ids)
        |> Ash.read!(domain: NewYou.Audit, authorize?: false)

      resource == NewYou.Audit.EvidenceRecord ->
        obligation_ids = Enum.map(audit_records("EvidenceObligation"), & &1.id)

        if obligation_ids == [] do
          []
        else
          resource
          |> Ash.Query.filter(obligation_id in ^obligation_ids)
          |> Ash.read!(domain: NewYou.Audit, authorize?: false)
        end

      Code.ensure_loaded?(resource) ->
        []

      true ->
        []
    end
  end

  defp scheduled_audit_jobs do
    obligation_ids = Enum.map(audit_records("EvidenceObligation"), & &1.id)

    if obligation_ids == [] do
      []
    else
      %{rows: rows} =
        Repo.query!(
          "SELECT queue, args FROM public.oban_jobs WHERE queue = $1 AND args->'primary_key'->>'id' = ANY($2::text[]) ORDER BY id",
          ["audit", obligation_ids]
        )

      Enum.map(rows, fn [queue, args] -> %{queue: queue, args: args} end)
    end
  end

  defp identity_truth(account_id) do
    account =
      Ash.get!(NewYou.Identity.Account, account_id, domain: NewYou.Identity, authorize?: false)

    operations =
      NewYou.Identity.RegistrationOperation
      |> Ash.Query.filter(created_account_id == ^account_id)
      |> Ash.read!(domain: NewYou.Identity, authorize?: false)

    token_count =
      NewYou.Identity.Token
      |> Ash.Query.filter(account_id == ^account_id)
      |> Ash.read!(domain: NewYou.Identity, authorize?: false)
      |> length()

    %{account: account, operations: operations, token_count: token_count}
  end

  defp row_count(table) do
    operation_ids = Enum.map(fixture_operation_ids(), &Ecto.UUID.dump!/1)

    {query, params} =
      case table do
        "tokens" ->
          {"SELECT count(*) FROM tokens WHERE account_id IN (SELECT created_account_id FROM registration_operations WHERE operation_id = ANY($1::uuid[]))",
           [operation_ids]}

        "message_intents" ->
          {"SELECT count(*) FROM message_intents WHERE source_operation_id = ANY($1::uuid[])",
           [operation_ids]}

        "communications_protected_envelopes" ->
          {"SELECT count(*) FROM communications_protected_envelopes e JOIN message_intents i ON i.id = e.message_intent_id WHERE i.source_operation_id = ANY($1::uuid[])",
           [operation_ids]}

        "communications_envelope_nonces" ->
          {"SELECT count(*) FROM communications_envelope_nonces n WHERE n.nonce IN (SELECT e.nonce FROM communications_protected_envelopes e JOIN message_intents i ON i.id = e.message_intent_id WHERE i.source_operation_id = ANY($1::uuid[]))",
           [operation_ids]}
      end

    %{rows: [[count]]} = Repo.query!(query, params)
    count
  end

  defp fixture_pmr_reservation_count do
    pmrs = Process.get({__MODULE__, :generated_pmrs}, []) |> Enum.uniq()

    %{rows: [[count]]} =
      Repo.query!(
        "SELECT count(*) FROM identity_pmr_reservations WHERE pmr = ANY($1::text[])",
        [pmrs]
      )

    count
  end

  defp fixture_operation_ids do
    Process.get({__MODULE__, :operation_ids}, []) |> Enum.uniq()
  end

  defp identity_records(NewYou.Identity.Account) do
    emails =
      Process.get({__MODULE__, :emails}, [])
      |> Enum.uniq()

    NewYou.Identity.Account
    |> Ash.Query.filter(email in ^emails)
    |> Ash.read!(domain: NewYou.Identity, authorize?: false)
  end

  defp identity_records(NewYou.Identity.RegistrationOperation) do
    operation_ids = fixture_operation_ids()

    NewYou.Identity.RegistrationOperation
    |> Ash.Query.filter(operation_id in ^operation_ids)
    |> Ash.read!(domain: NewYou.Identity, authorize?: false)
  end

  defp foreign_obligation_signature do
    %{rows: rows} =
      Repo.query!(
        "SELECT id::text, source_operation_id::text, evidence_type, created_at::text FROM evidence_obligations WHERE evidence_type = 'identity_recovery_completed' ORDER BY id"
      )

    :crypto.hash(:sha256, :erlang.term_to_binary(rows))
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
