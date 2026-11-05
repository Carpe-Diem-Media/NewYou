defmodule NewYou.Proof.P805 do
  @moduledoc """
  Deterministic WELL-53 callbacks. All business mutations use production owners.
  SQL is limited to observation, scoped fault DDL and synthetic-fixture teardown.
  Accepted cases use unboxed connections so the owner's real COMMIT executes.
  """
  alias Ecto.Adapters.SQL.Sandbox
  alias NewYou.{Audit, Communications, Identity, Repo}
  alias NewYou.Proof.{CutPoints, Scenario, SelfTest, RegistrationSeam}

  require Ash.Query

  @terms "NEWYOU-TERMS-EN-DEV-2026-10-27-001"
  @privacy "NEWYOU-PRIVACY-EN-DEV-2026-10-27-001"
  @tables ~w(accounts tokens registration_operations resend_operations message_intents communications_protected_envelopes communications_envelope_nonces evidence_obligations oban_jobs identity_pmr_reservations)
  @environment ~w(identity_registration_binding_keys identity_token_signing_secret communications_keyring p8_05_browser_development_fixtures identity_pmr_generator)a

  def run(case_id), do: with_fixture(fn -> execute(case_id) end)

  @doc false
  def with_fixture(callback) when is_function(callback, 0) do
    previous = Map.new(@environment, &{&1, Application.fetch_env(:new_you, &1)})
    configure()
    Process.put({__MODULE__, :operations}, [])
    Process.put({__MODULE__, :emails}, [])
    :ok = Sandbox.checkout(Repo, sandbox: false)

    try do
      callback.()
    after
      Process.delete(RegistrationSeam)

      try do
        cleanup()
        false = Repo.in_transaction?()
        0 = scalar("SELECT count(*) FROM pg_trigger WHERE tgname LIKE 'p805_fault_%'")
      after
        :ok = Sandbox.checkin(Repo)

        Enum.each(previous, fn
          {key, {:ok, value}} -> Application.put_env(:new_you, key, value)
          {key, :error} -> Application.delete_env(:new_you, key)
        end)
      end

      :ok = SelfTest.cleanup_manifest!(connections_released: true, locks_released: true)
    end
  end

  defp configure do
    Application.put_env(:new_you, :identity_registration_binding_keys, %{
      active_version: "proof-v1",
      keys: %{"proof-v1" => :crypto.strong_rand_bytes(32)}
    })

    Application.put_env(:new_you, :identity_token_signing_secret, :crypto.strong_rand_bytes(32))

    Application.put_env(:new_you, :communications_keyring, %{
      active: "proof-v1",
      keys: %{"proof-v1" => :crypto.strong_rand_bytes(32)}
    })

    Application.put_env(:new_you, :p8_05_browser_development_fixtures, true)
  end

  def request(overrides \\ %{}) do
    operation_id = Ecto.UUID.generate()

    request =
      Map.merge(
        %{
          operation_id: operation_id,
          first_name: "Proof",
          surname: "Participant",
          email: "proof-#{operation_id}@example.test",
          password: Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false),
          preferred_language: :af,
          confirmed_age_18?: true,
          terms_version_id: @terms,
          privacy_version_id: @privacy
        },
        overrides
      )

    track(request)
    request
  end

  def track_operation(operation), do: track(%{operation_id: operation})

  defp track(request) do
    Process.put({__MODULE__, :operations}, [
      request.operation_id | Process.get({__MODULE__, :operations}, [])
    ])

    if is_binary(request[:email]) do
      {:ok, email} = Identity.Email.canonicalize(request.email)
      Process.put({__MODULE__, :emails}, [email | Process.get({__MODULE__, :emails}, [])])
    end
  end

  def check(case_id, assertion, observed, expected \\ true) do
    SelfTest.expect_manifest!(case_id <> "." <> assertion, observed, expected)
    SelfTest.observe_manifest!(case_id <> "." <> assertion, observed == expected)
  end

  defp execute("p805.accepted" = id) do
    request = request(%{email: " Proof+#{Ecto.UUID.generate()}@EXAMPLE.TEST "})
    before = counts()

    Process.put(
      RegistrationSeam,
      {:observe,
       fn ->
         Process.put({__MODULE__, :transition}, accepted_snapshot(request))
       end}
    )

    {:ok, result} = Identity.register(request)
    Process.delete(RegistrationSeam)
    account = account!(result.account_id)
    snapshot = accepted_snapshot(request)
    check(id, "account_fields", account_fields?(account, request))

    check(
      id,
      "credential_same_transition",
      snapshot == Process.get({__MODULE__, :transition}) and snapshot.credential and
        snapshot.complete
    )

    check(id, "raw_password_absent", raw_password_absent?(request.password))
    check(id, "complete_consequences", delta(before, counts()), [1, 1, 1, 0, 1, 1, 1, 1, 1, 1])
    check(id, "audit_minimum_reference", snapshot.audit_minimum)
    check(id, "zero_communications_jobs", communications_jobs(), 0)
    check(id, "no_execution", no_execution?())
    check(id, "protected_capability_private", capability_private?(result, account, request))
  end

  defp execute("p805.rejected" = id) do
    before = counts()

    groups = [
      {"credential", [%{password: 42}, %{password: ""}, %{password: nil}]},
      {"required_fields",
       Enum.map([:first_name, :surname, :email, :password, :preferred_language], &%{&1 => nil})},
      {"age", [%{confirmed_age_18?: false}, %{confirmed_age_18?: nil}]},
      {"terms", [%{terms_version_id: nil}, %{terms_version_id: "ineligible"}]},
      {"privacy", [%{privacy_version_id: nil}, %{privacy_version_id: "ineligible"}]}
    ]

    for {assertion, inputs} <- groups do
      rejected =
        Enum.all?(inputs, fn overrides ->
          input = request()
          match?({:error, _}, Identity.register(Map.merge(input, overrides)))
        end)

      check(id, assertion, rejected)
    end

    check(id, "no_partial_consequences", counts(), before)
  end

  defp execute(id)
       when id in [
              "p805.envelope_rollback",
              "p805.audit_schedule_rollback",
              "p805.rollback_account",
              "p805.rollback_token",
              "p805.rollback_intent",
              "p805.rollback_nonce",
              "p805.rollback_obligation",
              "p805.rollback_operation"
            ] do
    table =
      Map.fetch!(
        %{
          "p805.envelope_rollback" => "communications_protected_envelopes",
          "p805.audit_schedule_rollback" => "oban_jobs",
          "p805.rollback_account" => "accounts",
          "p805.rollback_token" => "tokens",
          "p805.rollback_intent" => "message_intents",
          "p805.rollback_nonce" => "communications_envelope_nonces",
          "p805.rollback_obligation" => "evidence_obligations",
          "p805.rollback_operation" => "registration_operations"
        },
        id
      )

    before = counts()
    input = request()

    with_rejected_insert(table, fn reached ->
      result = Identity.register(input)
      check(id, "cut_reached", reached.())
      check(id, "unavailable", result, {:error, :registration_unavailable})
      check(id, "no_partial_consequences", counts(), before)
    end)
  end

  defp execute("p805.commit_rollback" = id) do
    input = request()
    before = counts()
    scenario = Scenario.start()

    try do
      :ok = CutPoints.arm(scenario, "transaction.before_commit", :registration, :raise)

      parent = self()
      reference = make_ref()

      {worker, monitor} =
        Scenario.spawn(scenario, :registration, fn ->
          :ok = Sandbox.checkout(Repo, sandbox: false)

          try do
            Process.put(
              RegistrationSeam,
              {:observe,
               fn ->
                 Process.put(
                   {__MODULE__, :complete_before_cut},
                   accepted_snapshot(input).complete
                 )

                 CutPoints.hit(scenario, "transaction.before_commit", :registration)
               end}
            )

            unavailable =
              try do
                Identity.register(input) == {:error, :registration_unavailable}
              rescue
                _ in Ash.Error.Unknown -> true
              end

            send(
              parent,
              {reference, unavailable, Process.get({__MODULE__, :complete_before_cut})}
            )
          after
            Process.delete(RegistrationSeam)
            :ok = Sandbox.checkin(Repo)
          end
        end)

      {unavailable, complete} =
        receive do
          {^reference, unavailable, complete} -> {unavailable, complete}
        after
          15_000 -> raise "proof commit cut deadline"
        end

      receive do
        {:DOWN, ^monitor, :process, ^worker, :normal} -> :ok
      after
        5_000 -> raise "proof commit worker cleanup deadline"
      end

      check(id, "cut_reached", CutPoints.verify_consumed(scenario), :ok)
      check(id, "complete_before_cut", complete)
      check(id, "unavailable", unavailable)
      check(id, "no_partial_consequences", counts(), before)
    after
      :ok = Scenario.stop(scenario)
    end
  end

  defp execute("p805.replay_neutrality" = id) do
    input = request()
    {:ok, first} = Identity.register(input)
    before = counts()
    {:ok, replay} = Identity.register(input)

    check(
      id,
      "same_operation",
      replay.account_id == first.account_id and is_nil(replay.verification_proof)
    )

    check(
      id,
      "changed_input",
      match?({:error, _}, Identity.register(%{input | surname: "Changed"}))
    )

    duplicate = request(%{email: input.email})
    {:ok, neutral} = Identity.register(duplicate)

    check(
      id,
      "duplicate_neutral",
      neutral.status == first.status and is_nil(neutral.account_id) and
        is_nil(neutral.verification_proof)
    )

    check(id, "no_duplicate_consequences", delta(before, counts()), [0, 0, 1, 0, 0, 0, 0, 0, 0, 0])
  end

  defp execute("p805.pmr_collision" = id) do
    first = request()
    {:ok, result} = Identity.register(first)
    pmr = account!(result.account_id).pmr
    {:ok, fresh} = Identity.PMR.generate()
    Process.put({__MODULE__, :pmr_calls}, 0)

    Application.put_env(:new_you, :identity_pmr_generator, fn ->
      count = Process.get({__MODULE__, :pmr_calls})
      Process.put({__MODULE__, :pmr_calls}, count + 1)
      {:ok, if(count == 0, do: pmr, else: fresh)}
    end)

    {:ok, second} = Identity.register(request())
    check(id, "unique", account!(second.account_id).pmr != pmr)
    check(id, "collision_retried", Process.get({__MODULE__, :pmr_calls}), 2)
    before = counts()
    Process.put({__MODULE__, :pmr_calls}, 0)

    Application.put_env(:new_you, :identity_pmr_generator, fn ->
      Process.put({__MODULE__, :pmr_calls}, Process.get({__MODULE__, :pmr_calls}) + 1)
      {:ok, pmr}
    end)

    result = Identity.register(request())

    check(
      id,
      "bounded_exhaustion",
      result == {:error, :registration_unavailable} and Process.get({__MODULE__, :pmr_calls}) == 5
    )

    check(id, "no_partial_consequences", counts(), before)
  end

  defp execute("p805.retired_pmr" = id) do
    input = request()
    {:ok, accepted} = Identity.register(input)
    retired = account!(accepted.account_id).pmr
    cleanup()

    check(
      id,
      "account_removed",
      scalar("SELECT count(*) FROM accounts WHERE pmr = $1", [retired]),
      0
    )

    check(
      id,
      "reservation_survives",
      scalar("SELECT count(*) FROM identity_pmr_reservations WHERE pmr = $1", [retired]),
      1
    )

    before = counts()
    Process.put({__MODULE__, :retired_pmr_calls}, 0)

    Application.put_env(:new_you, :identity_pmr_generator, fn ->
      calls = Process.get({__MODULE__, :retired_pmr_calls})
      Process.put({__MODULE__, :retired_pmr_calls}, calls + 1)
      {:ok, retired}
    end)

    result = Identity.register(request())

    check(
      id,
      "exhaustion",
      result == {:error, :registration_unavailable} and
        Process.get({__MODULE__, :retired_pmr_calls}) == 5
    )

    check(id, "no_reassignment", counts(), before)
  end

  defp execute("p805.same_email_race" = id), do: NewYou.Proof.P805Race.run(id)
  defp execute("p805.canonical_email_race" = id), do: NewYou.Proof.P805Race.run(id)
  defp execute("p805.same_operation_race" = id), do: NewYou.Proof.P805Race.run(id)
  defp execute("p805.pmr_collision_race" = id), do: NewYou.Proof.P805Race.run(id)

  defp execute("p805.post_commit_recovery" = id) do
    input = request()
    before = counts()
    parent = self()
    ref = make_ref()
    scenario = Scenario.start()

    try do
      :ok = CutPoints.arm(scenario, "transaction.after_commit", :registration, :terminate)

      {worker, worker_monitor} =
        Scenario.spawn(scenario, :registration, fn ->
          :ok = Sandbox.checkout(Repo, sandbox: false)

          try do
            backend = scalar("SELECT pg_backend_pid()")
            {:ok, _result} = Identity.register(input)
            send(parent, {ref, :committed, backend})
            CutPoints.hit(scenario, "transaction.after_commit", :registration)
            send(parent, {ref, :acknowledged})
          after
            Sandbox.checkin(Repo)
          end
        end)

      registration_backend =
        receive do
          {^ref, :committed, backend} -> backend
        after
          20_000 -> raise "post-commit deadline"
        end

      receive do
        {:DOWN, ^worker_monitor, :process, ^worker, :proof_terminated} -> :ok
      after
        10_000 -> raise "post-commit termination deadline"
      end

      consumed = CutPoints.verify_consumed(scenario)

      {reader, reader_monitor} =
        Scenario.spawn(scenario, :recovery, fn ->
          :ok = Sandbox.checkout(Repo, sandbox: false)

          try do
            backend = scalar("SELECT pg_backend_pid()")
            snapshot = accepted_snapshot(input)
            before_replay = counts()
            {:ok, replay} = Identity.register(input)

            send(
              parent,
              {ref, :recovered, backend, snapshot.complete and snapshot.credential,
               replay.status == :verification_pending and is_binary(replay.account_id) and
                 is_nil(replay.verification_proof), counts() == before_replay}
            )
          after
            :ok = Sandbox.checkin(Repo)
          end
        end)

      {reader_backend, complete, replayed, unchanged} =
        receive do
          {^ref, :recovered, backend, complete, replayed, unchanged} ->
            {backend, complete, replayed, unchanged}
        after
          20_000 -> raise "recovery result deadline"
        end

      receive do
        {:DOWN, ^reader_monitor, :process, ^reader, :normal} -> :ok
      after
        10_000 -> raise "recovery reader cleanup deadline"
      end

      acknowledged =
        receive do
          {^ref, :acknowledged} -> true
        after
          0 -> false
        end

      check(id, "cut_consumed", consumed, :ok)
      check(id, "acknowledgement_lost", not acknowledged)
      check(id, "fresh_connection", registration_backend != reader_backend)
      check(id, "complete_recovery", complete)
      check(id, "replay_converges", replayed and unchanged)
      check(id, "committed_once", delta(before, counts()), [1, 1, 1, 0, 1, 1, 1, 1, 1, 1])
    after
      :ok = Scenario.stop(scenario)
    end
  end

  defp execute("p805.browser_en" = id), do: NewYou.Proof.P805Browser.run(id, "en")
  defp execute("p805.browser_af" = id), do: NewYou.Proof.P805Browser.run(id, "af")

  defp execute("p805.resend" = id) do
    input = request()
    {:ok, result} = Identity.register(input)
    original = challenges(result.account_id) |> hd()
    before = counts()
    operation = %{operation_id: Ecto.UUID.generate(), account_id: result.account_id}
    track(operation)
    {:ok, :verification_pending} = Identity.resend_verification(operation)
    [replacement] = challenges(result.account_id)

    check(
      id,
      "separate_binding",
      operation.operation_id != input.operation_id and
        read(Identity.ResendOperation, Identity)
        |> Enum.any?(
          &(&1.operation_id == operation.operation_id and &1.account_id == result.account_id)
        )
    )

    check(
      id,
      "superseded",
      replacement.jti != original.jti and
        Enum.any?(
          read(Identity.Token, Identity),
          &(&1.jti == original.jti and &1.purpose == "revocation")
        )
    )

    intent = intents(operation.operation_id) |> hd()
    check(id, "one_new_intent", length(intents(operation.operation_id)), 1)

    check(
      id,
      "protected_envelope",
      scalar(
        "SELECT count(*) FROM communications_protected_envelopes WHERE message_intent_id = $1 AND source_reference = $2",
        [Ecto.UUID.dump!(intent.id), replacement.jti]
      ),
      1
    )

    check(id, "zero_communications_jobs", communications_jobs(), 0)
    check(id, "no_resend_audit", delta(before, counts()), [0, 1, 0, 1, 1, 1, 1, 0, 0, 0])

    check(
      id,
      "discoverable",
      intent.dispatch_disposition == :open and intent.source_reference == replacement.jti
    )

    after_resend = counts()
    {:ok, :verification_pending} = Identity.resend_verification(operation)

    check(
      id,
      "idempotent",
      counts() == after_resend and hd(challenges(result.account_id)).jti == replacement.jti
    )
  end

  defp execute("p805.resend_binding" = id) do
    input = request()
    unknown = %{operation_id: Ecto.UUID.generate(), email: input.email}
    track(unknown)
    before = counts()
    result = Identity.resend_verification_by_email(unknown)

    check(
      id,
      "unknown_neutral",
      result == {:ok, :verification_pending} and
        delta(before, counts()) == [0, 0, 0, 1, 0, 0, 0, 0, 0, 0]
    )

    known = request()
    {:ok, _} = Identity.register(known)
    before_changed = counts()

    check(
      id,
      "immutable_binding",
      Identity.resend_verification_by_email(%{unknown | email: known.email}) ==
        {:error, :resend_unavailable} and counts() == before_changed
    )

    {:ok, accepted} = Identity.register(input)
    before_replay = counts()

    check(
      id,
      "terminal_replay",
      Identity.resend_verification_by_email(unknown) == {:ok, :verification_pending} and
        counts() == before_replay
    )

    missing_account = %{operation_id: Ecto.UUID.generate(), account_id: Ecto.UUID.generate()}
    track(missing_account)

    check(
      id,
      "ineligible_neutral",
      Identity.resend_verification(missing_account) == {:ok, :verification_pending} and
        length(challenges(accepted.account_id)) == 1
    )
  end

  def account!(id), do: Ash.get!(Identity.Account, id, domain: Identity, authorize?: false)
  def read(resource, domain), do: Ash.read!(resource, domain: domain, authorize?: false)

  def intents(operation),
    do:
      Communications.MessageIntent
      |> Ash.Query.filter(source_operation_id == ^operation)
      |> Ash.read!(domain: Communications, authorize?: false)

  def challenges(account),
    do:
      Identity.Token
      |> Ash.Query.filter(account_id == ^account and purpose == "email_verification")
      |> Ash.read!(domain: Identity, authorize?: false)

  def counts, do: Enum.map(@tables, &scalar("SELECT count(*) FROM #{&1}"))
  def delta(before, after_counts), do: Enum.zip_with(after_counts, before, &(&1 - &2))

  def scalar(sql, args \\ []) do
    %{rows: [[value]]} = Repo.query!(sql, args)
    value
  end

  defp accepted_snapshot(input) do
    [operation] =
      Identity.RegistrationOperation
      |> Ash.Query.filter(operation_id == ^input.operation_id)
      |> Ash.read!(domain: Identity, authorize?: false)

    account = account!(operation.created_account_id)
    [token] = challenges(account.id)
    [intent] = intents(input.operation_id)

    [obligation] =
      Audit.EvidenceObligation
      |> Ash.Query.filter(source_operation_id == ^input.operation_id)
      |> Ash.read!(domain: Audit, authorize?: false)

    [job] =
      Repo.all(Oban.Job) |> Enum.filter(&(&1.args["primary_key"] == %{"id" => obligation.id}))

    %{
      credential:
        account.credential_status == :active and is_binary(account.hashed_password) and
          byte_size(account.hashed_password) > 0 and
          account.hashed_password == operation.password_verifier,
      complete:
        account_fields?(account, input) and Identity.PMR.valid?(account.pmr) and
          account.legal_accepted_at == operation.committed_at and
          delivery_bound?(intent, token, input) and audit_bound?(obligation, job, operation),
      audit_minimum:
        job.args == %{
          "primary_key" => %{"id" => obligation.id},
          "metadata" => %{},
          "action_arguments" => %{},
          "tenant" => nil
        }
    }
  end

  defp account_fields?(account, input) do
    {:ok, email} = Identity.Email.canonicalize(input.email)

    fields = [
      :first_name,
      :surname,
      :email,
      :preferred_language,
      :confirmed_age_18?,
      :terms_version_id,
      :privacy_version_id,
      :acceptance_locale,
      :email_verified?
    ]

    expected = %{
      first_name: input.first_name,
      surname: input.surname,
      email: email,
      preferred_language: input.preferred_language,
      confirmed_age_18?: true,
      terms_version_id: @terms,
      privacy_version_id: @privacy,
      acceptance_locale: input.preferred_language,
      email_verified?: false
    }

    Map.take(account, fields) == expected and match?(%DateTime{}, account.legal_accepted_at)
  end

  defp delivery_bound?(intent, token, input) do
    intent.source_reference == token.jti and intent.source_operation_id == input.operation_id and
      scalar(
        "SELECT count(*) FROM communications_protected_envelopes WHERE message_intent_id = $1 AND source_reference = $2",
        [Ecto.UUID.dump!(intent.id), token.jti]
      ) == 1
  end

  defp audit_bound?(obligation, job, operation) do
    obligation.state == :open and obligation.evidence_type == :account_registration_pmr_assignment and
      job.queue == "audit" and operation.state == :bound
  end

  defp raw_password_absent?(password) do
    Enum.all?(@tables, fn table ->
      scalar(
        "SELECT count(*) FROM #{table} AS row WHERE strpos(row_to_json(row)::text, $1) > 0",
        [password]
      ) == 0
    end)
  end

  defp capability_private?(result, account, input) do
    is_binary(result.verification_proof) and raw_password_absent?(result.verification_proof) and
      account.hashed_password != input.password
  end

  defp no_execution? do
    scalar("SELECT count(*) FROM oban_jobs WHERE attempted_at IS NOT NULL OR attempt <> 0") == 0 and
      read(Audit.EvidenceRecord, Audit) == []
  end

  defp communications_jobs,
    do: scalar("SELECT count(*) FROM oban_jobs WHERE queue = 'communications'")

  defp with_rejected_insert(table, callback) do
    suffix = System.unique_integer([:positive])
    name = "p805_fault_#{suffix}"

    try do
      Repo.query!("CREATE TEMP SEQUENCE #{name}")

      Repo.query!("""
      CREATE FUNCTION pg_temp.#{name}() RETURNS trigger LANGUAGE plpgsql AS $$
      BEGIN
        PERFORM nextval('pg_temp.#{name}');
        RAISE EXCEPTION 'bounded proof insertion cut' USING ERRCODE = '23514';
      END; $$
      """)

      Repo.query!("SELECT set_config('newyou.proof_cut', $1, false)", [name])

      Repo.query!(
        "CREATE TRIGGER #{name} BEFORE INSERT ON #{table} FOR EACH ROW WHEN (current_setting('newyou.proof_cut', true) = '#{name}') EXECUTE FUNCTION pg_temp.#{name}()"
      )

      callback.(fn -> scalar("SELECT is_called FROM pg_temp.#{name}") end)
    after
      Repo.query!("DROP TRIGGER IF EXISTS #{name} ON #{table}")
      Repo.query!("DROP FUNCTION IF EXISTS pg_temp.#{name}()")
      Repo.query!("DROP SEQUENCE IF EXISTS pg_temp.#{name}")
      Repo.query!("RESET newyou.proof_cut")
    end
  end

  # Fixture teardown only, never an application mutation interface. PMR
  # reservations deliberately remain permanent, as in existing owner tests.
  defp cleanup do
    operations =
      Process.delete({__MODULE__, :operations}) |> Enum.uniq() |> Enum.map(&Ecto.UUID.dump!/1)

    emails = Process.delete({__MODULE__, :emails}) |> Enum.uniq()

    # Browser IDs are recovered through durable owner provenance even when the
    # browser process dies before it can return its generated operation IDs.
    %{rows: discovered} =
      Repo.query!(
        "SELECT operation_id FROM registration_operations WHERE created_account_id IN (SELECT id FROM accounts WHERE email = ANY($1::text[])) UNION SELECT operation_id FROM resend_operations WHERE account_id IN (SELECT id FROM accounts WHERE email = ANY($1::text[]))",
        [emails]
      )

    operations = Enum.uniq(operations ++ Enum.map(discovered, &hd/1))

    %{rows: nonces} =
      Repo.query!(
        "SELECT e.nonce FROM communications_protected_envelopes e JOIN message_intents i ON i.id = e.message_intent_id WHERE i.source_operation_id = ANY($1::uuid[])",
        [operations]
      )

    Repo.query!(
      "DELETE FROM oban_jobs WHERE args->'primary_key'->>'id' IN (SELECT id::text FROM evidence_obligations WHERE source_operation_id = ANY($1::uuid[]))",
      [operations]
    )

    Repo.query!("DELETE FROM evidence_obligations WHERE source_operation_id = ANY($1::uuid[])", [
      operations
    ])

    Repo.query!(
      "DELETE FROM communications_protected_envelopes e USING message_intents i WHERE e.message_intent_id = i.id AND i.source_operation_id = ANY($1::uuid[])",
      [operations]
    )

    Enum.each(nonces, fn [nonce] ->
      Repo.query!("DELETE FROM communications_envelope_nonces WHERE nonce = $1", [nonce])
    end)

    Repo.query!("DELETE FROM message_intents WHERE source_operation_id = ANY($1::uuid[])", [
      operations
    ])

    Repo.query!(
      "DELETE FROM tokens WHERE account_id IN (SELECT id FROM accounts WHERE email = ANY($1::text[]))",
      [emails]
    )

    Repo.query!("DELETE FROM resend_operations WHERE operation_id = ANY($1::uuid[])", [operations])

    Repo.query!("DELETE FROM registration_operations WHERE operation_id = ANY($1::uuid[])", [
      operations
    ])

    Repo.query!("DELETE FROM accounts WHERE email = ANY($1::text[])", [emails])
  end
end
