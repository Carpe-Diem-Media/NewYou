defmodule NewYou.Communications.MagicLoginDeliveryTest do
  use ExUnit.Case, async: false

  alias NewYou.{Communications, Identity}
  alias NewYou.Proof.P805
  alias NewYou.Identity.{Account, Session, Token}
  alias NewYou.Proof.DeliverySeam
  alias NewYou.Repo

  require Ash.Query
  import ExUnit.CaptureLog

  test "existing-account magic login is delivered from Identity proof without a protected envelope" do
    P805.with_fixture(fn ->
      request = P805.request(%{preferred_language: :en})
      _registration = register_verified(request)
      operation_id = Ecto.UUID.generate()
      P805.track_operation(operation_id)

      assert :ok = Identity.request_magic_login(request.email, "en", operation_id)

      [intent] =
        Communications.MessageIntent
        |> Ash.Query.filter(role == :magic_login and source_operation_id == ^operation_id)
        |> Ash.read!(authorize?: false)

      assert intent.source_operation_id == operation_id
      assert intent.source_purpose == "magic_login"
      assert intent.render_schema == "magic-login-v1"
      assert intent.destination == request.email
      assert intent.destination_provenance == "identity_magic_login_issuance"
      assert intent.locale == "en"

      Process.put(:p810_provider, fn _attempt, payload ->
        refute NewYou.Repo.in_transaction?()
        assert payload.destination == request.email
        has_subject? = String.contains?(payload.body, "subject: Sign in to Test Platform")
        has_magic_link? = String.contains?(payload.body, "/login/magic/confirm?locale=en&proof=")
        assert has_subject?
        assert has_magic_link?
        :delivered
      end)

      assert {:ok, :processed} = Communications.execute(intent.id)

      [attempt] =
        Communications.DeliveryAttempt
        |> Ash.Query.filter(message_intent_id == ^intent.id)
        |> Ash.read!(authorize?: false)

      assert attempt.message_intent_id == intent.id

      assert [] ==
               Communications.ProtectedEnvelope
               |> Ash.Query.filter(message_intent_id == ^intent.id)
               |> Ash.read!(authorize?: false)
    end)
  after
    Process.delete(:p810_provider)
  end

  test "magic login causal replay returns the same intent and cannot change its binding" do
    P805.with_fixture(fn ->
      request = P805.request(%{preferred_language: :en})
      _registration = register_verified(request)
      operation_id = Ecto.UUID.generate()
      P805.track_operation(operation_id)
      assert :ok = Identity.request_magic_login(request.email, "en", operation_id)

      [intent] =
        Communications.MessageIntent
        |> Ash.Query.filter(role == :magic_login and source_operation_id == ^operation_id)
        |> Ash.read!(authorize?: false)

      attrs =
        Map.take(intent, [
          :source_operation_id,
          :source_reference,
          :destination,
          :destination_provenance,
          :destination_authorized_at,
          :locale,
          :role,
          :source_purpose,
          :render_schema
        ])

      assert {:ok, replay} = Communications.establish_magic_login(attrs)
      assert replay.id == intent.id

      assert {:error, :magic_login_unavailable} =
               Communications.establish_magic_login(Map.put(attrs, :locale, "af"))
    end)
  end

  test "EN and AF deliveries render the exact bound approved bytes" do
    for locale <- ["en", "af"] do
      with_magic_login(locale, fn fixture ->
        {:ok, binding} = NewYou.Content.MagicLoginMessage.binding(locale)
        {:ok, exact_bytes} = NewYou.Content.MagicLoginMessage.eligible(binding)

        assert Map.take(fixture.intent, Map.keys(binding)) == binding

        Process.put(:p810_provider, fn _attempt, payload ->
          refute Repo.in_transaction?()
          assert payload.destination == fixture.request.email
          Process.put({__MODULE__, :payload}, payload)
          :delivered
        end)

        logs =
          capture_log(fn ->
            assert {:ok, :processed} = Communications.execute(fixture.intent.id)
          end)

        payload = Process.get({__MODULE__, :payload})
        assert is_map(payload)
        has_subject? = String.contains?(payload.body, "subject: ")

        has_magic_link? =
          String.contains?(payload.body, "/login/magic/confirm?locale=#{locale}&proof=")

        assert has_subject?
        assert has_magic_link?

        links =
          Regex.scan(~r{https://proof\.invalid/login/magic/confirm\?locale=[^\s]+}, payload.body)
          |> Enum.map(&hd/1)

        link = Enum.find(links, &is_binary/1)
        has_one_link? = length(links) == 1
        assert has_one_link?
        link = link || ""

        expected =
          exact_bytes
          |> String.replace("{{platform_name}}", NewYou.platform_name())
          |> String.replace("{{magic_login_link}}", link)

        exact_render? = payload.body == expected
        assert exact_render?

        encoded_proof =
          link
          |> URI.parse()
          |> Map.get(:query, "")
          |> URI.decode_query()
          |> Map.get("proof")

        bearer = if is_binary(encoded_proof), do: URI.decode_www_form(encoded_proof), else: ""
        assert bearer != ""
        bearer_logged? = String.contains?(logs, bearer)
        link_logged? = String.contains?(logs, link)
        refute bearer_logged?
        refute link_logged?

        persisted = persisted_magic_delivery_text(fixture)
        bearer_persisted? = String.contains?(persisted, bearer)
        link_persisted? = String.contains?(persisted, link)
        refute bearer_persisted?
        refute link_persisted?

        assert token(fixture).purpose == "magic_login"
        assert sessions(fixture) == []
        assert protected_envelopes(fixture.intent) == []
      end)
    end
  after
    Process.delete({__MODULE__, :payload})
    Process.delete(:p810_provider)
  end

  test "unknown and accepted provider outcomes leave the proof current and block duplicate attempts" do
    for outcome <- [:unknown, :accepted] do
      with_magic_login("en", fn fixture ->
        proof_before = token_snapshot(fixture)
        Process.put(:p810_provider, fn _attempt, _payload -> outcome end)

        assert {:ok, :processed} = Communications.execute(fixture.intent.id)
        assert {:ok, :waiting} = Communications.execute(fixture.intent.id)

        assert token_snapshot(fixture) == proof_before
        assert token(fixture).purpose == "magic_login"
        assert sessions(fixture) == []
        assert length(attempts(fixture.intent)) == 1
        assert protected_envelopes(fixture.intent) == []
      end)
    end
  after
    Process.delete(:p810_provider)
  end

  test "confirmed no-operation retries the same proof and delivered evidence still creates no Session" do
    with_magic_login("af", fn fixture ->
      proof_before = token_snapshot(fixture)
      Application.put_env(:new_you, :communications_proof_evidence_key, String.duplicate("k", 32))
      Process.put(:p810_provider, fn _attempt, _payload -> :unknown end)

      assert {:ok, :processed} = Communications.execute(fixture.intent.id)
      [first] = attempts(fixture.intent)
      assert first.provider_observation == :unknown

      evidence_ref = "magic-login-no-operation"

      signature =
        :crypto.mac(
          :hmac,
          :sha256,
          String.duplicate("k", 32),
          first.id <> "|confirmed_no_operation|" <> evidence_ref
        )

      assert {:ok, :recorded} =
               Communications.reconcile(
                 first.id,
                 :confirmed_no_operation,
                 evidence_ref,
                 signature
               )

      Process.put(:p810_provider, fn _attempt, payload ->
        assert payload.destination == fixture.request.email
        :delivered
      end)

      assert {:ok, :processed} = Communications.execute(fixture.intent.id)
      assert token_snapshot(fixture) == proof_before
      assert token(fixture).purpose == "magic_login"
      assert sessions(fixture) == []
      assert length(attempts(fixture.intent)) == 2
      assert protected_envelopes(fixture.intent) == []
    end)
  after
    Process.delete(:p810_provider)
    Application.delete_env(:new_you, :communications_proof_evidence_key)
  end

  test "a safe provider rejection permits one retry using the unchanged proof" do
    with_magic_login("en", fn fixture ->
      proof_before = token_snapshot(fixture)
      Process.put(:p810_provider, fn _attempt, _payload -> :rejected_before_submission end)
      assert {:ok, :processed} = Communications.execute(fixture.intent.id)

      [rejected] = attempts(fixture.intent)
      assert rejected.provider_observation == :rejected_before_submission

      Process.put(:p810_provider, fn _attempt, _payload -> :delivered end)
      assert {:ok, :processed} = Communications.execute(fixture.intent.id)

      assert token_snapshot(fixture) == proof_before
      assert token(fixture).purpose == "magic_login"
      assert sessions(fixture) == []
      assert length(attempts(fixture.intent)) == 2
    end)
  after
    Process.delete(:p810_provider)
  end

  test "conflicting authenticated evidence freezes a valid magic proof for reconciliation" do
    with_magic_login("en", fn fixture ->
      evidence_key = String.duplicate("k", 32)
      Application.put_env(:new_you, :communications_proof_evidence_key, evidence_key)
      Process.put(:p810_provider, fn _attempt, _payload -> :accepted end)

      assert {:ok, :processed} = Communications.execute(fixture.intent.id)
      [attempt] = attempts(fixture.intent)

      signature =
        :crypto.mac(
          :hmac,
          :sha256,
          evidence_key,
          attempt.id <> "|rejected_before_submission|conflicting-evidence"
        )

      assert {:ok, :recorded} =
               Communications.reconcile(
                 attempt.id,
                 :rejected_before_submission,
                 "conflicting-evidence",
                 signature
               )

      intent = Ash.get!(Communications.MessageIntent, fixture.intent.id, authorize?: false)
      attempt = Ash.get!(Communications.DeliveryAttempt, attempt.id, authorize?: false)
      assert intent.dispatch_disposition == :reconciliation_required
      assert intent.terminal_reason == "conflicting_provider_evidence"
      assert attempt.conflict?
      assert token(fixture).purpose == "magic_login"

      Process.put(:p810_provider, fn _, _ -> flunk("conflicted evidence allowed another send") end)

      assert {:ok, :waiting} = Communications.execute(fixture.intent.id)
      assert length(attempts(fixture.intent)) == 1
    end)
  after
    Process.delete(:p810_provider)
    Application.delete_env(:new_you, :communications_proof_evidence_key)
  end

  test "superseded, expired, revoked and consumed proofs cannot send before execution or after admission" do
    for phase <- [:before_execute, :after_admission],
        state <- [:superseded, :expired, :revoked, :consumed] do
      with_magic_login("en", fn fixture ->
        Process.put(:p810_provider, fn _attempt, _payload ->
          flunk("stale proof reached provider")
        end)

        if phase == :before_execute do
          invalidate(fixture, state)
          assert {:ok, :source_invalid} = Communications.execute(fixture.intent.id)
          assert attempts(fixture.intent) == []
        else
          Process.put(DeliverySeam, fn
            :after_admission -> invalidate(fixture, state)
            _ -> :ok
          end)

          assert {:ok, :source_invalid} = Communications.execute(fixture.intent.id)

          [attempt] = attempts(fixture.intent)
          assert attempt.admission == :closed_before_invocation
          assert attempt.invocation_started_at == nil
          refute attempt.active
        end

        assert protected_envelopes(fixture.intent) == []
        assert length(sessions(fixture)) == if(state == :consumed, do: 1, else: 0)
      end)
    end
  after
    Process.delete(:p810_provider)
    Process.delete(DeliverySeam)
  end

  test "AshOban delivery jobs contain only the intent id and magic login has no protected envelope" do
    with_magic_login("en", fn fixture ->
      trigger = AshOban.Info.oban_trigger(Communications.MessageIntent, :delivery)
      assert :ok = trigger.scheduler.perform(%Oban.Job{args: %{}})
      [job] = jobs(fixture.intent)

      assert job.args["primary_key"] == %{"id" => fixture.intent.id}

      assert Map.keys(job.args) --
               ["primary_key", "metadata", "action_arguments", "tenant", "actor"] == []

      assert job.args["actor"] == nil
      assert job.args["action_arguments"] in [nil, %{}]
      assert job.args["metadata"] in [nil, %{}]

      serialized = Jason.encode!(job.args)
      jti_scheduled? = String.contains?(serialized, fixture.token.jti)
      proof_scheduled? = String.contains?(serialized, "proof")
      refute jti_scheduled?
      refute proof_scheduled?
      assert protected_envelopes(fixture.intent) == []
    end)
  end

  defp with_magic_login(locale, callback) do
    P805.with_fixture(fn ->
      request = P805.request(%{preferred_language: if(locale == "af", do: :af, else: :en)})
      registration = register_verified(request)
      operation_id = Ecto.UUID.generate()
      P805.track_operation(operation_id)
      assert :ok = Identity.request_magic_login(request.email, locale, operation_id)

      [token] =
        Token
        |> Ash.Query.filter(magic_request_id == ^operation_id)
        |> Ash.read!(authorize?: false)

      [intent] =
        Communications.MessageIntent
        |> Ash.Query.filter(source_operation_id == ^operation_id and role == :magic_login)
        |> Ash.read!(authorize?: false)

      callback.(%{
        request: request,
        registration: registration,
        operation_id: operation_id,
        token: token,
        intent: intent
      })
    end)
  end

  defp register_verified(request) do
    result = Identity.register(request)
    registered? = match?({:ok, _registration}, result)
    assert registered?
    {:ok, registration} = result
    assert {:ok, :verified} = Identity.verify_email(registration.verification_proof)
    registration
  end

  defp invalidate(fixture, :superseded) do
    operation_id = Ecto.UUID.generate()
    P805.track_operation(operation_id)
    assert :ok = Identity.request_magic_login(fixture.request.email, "af", operation_id)
  end

  defp invalidate(fixture, :expired) do
    Repo.query!("UPDATE tokens SET expires_at = now() - interval '1 second' WHERE jti = $1", [
      fixture.token.jti
    ])
  end

  defp invalidate(fixture, :revoked) do
    account = Ash.get!(Account, fixture.registration.account_id, authorize?: false)

    assert :ok =
             AshAuthentication.TokenResource.Actions.revoke_jti(
               Token,
               fixture.token.jti,
               AshAuthentication.user_to_subject(account),
               authorize?: false,
               context: %{ash_authentication: %{user: account}}
             )
  end

  defp invalidate(fixture, :consumed) do
    {:ok, bearer} = materialize(fixture)
    consumed? = match?({:ok, _credentials}, Identity.authenticate_magic_link(bearer))
    assert consumed?
  end

  defp materialize(fixture) do
    Ash.transact([Account, Token], fn ->
      Identity.magic_login_delivery(
        fixture.token.jti,
        fixture.request.email,
        fixture.intent.locale
      )
    end)
    |> case do
      {:ok, {:ok, bearer}} -> {:ok, bearer}
      _ -> {:error, :source_invalid}
    end
  end

  defp token(fixture), do: Ash.get!(Token, fixture.token.jti, authorize?: false)

  defp token_snapshot(fixture) do
    proof = token(fixture)
    {proof.jti, proof.purpose, proof.expires_at, proof.magic_claims}
  end

  defp attempts(intent) do
    Communications.DeliveryAttempt
    |> Ash.Query.filter(message_intent_id == ^intent.id)
    |> Ash.read!(authorize?: false)
  end

  defp sessions(fixture) do
    Session
    |> Ash.Query.filter(account_id == ^fixture.registration.account_id)
    |> Ash.read!(authorize?: false)
  end

  defp protected_envelopes(intent) do
    Communications.ProtectedEnvelope
    |> Ash.Query.filter(message_intent_id == ^intent.id)
    |> Ash.read!(authorize?: false)
  end

  defp jobs(intent) do
    Enum.filter(Repo.all(Oban.Job), &(&1.args["primary_key"] == %{"id" => intent.id}))
  end

  defp persisted_magic_delivery_text(fixture) do
    queries = [
      {"SELECT row_to_json(t)::text FROM tokens t WHERE jti = $1", [fixture.token.jti]},
      {"SELECT row_to_json(i)::text FROM message_intents i WHERE id = $1",
       [Ecto.UUID.dump!(fixture.intent.id)]},
      {"SELECT row_to_json(a)::text FROM delivery_attempts a WHERE message_intent_id = $1",
       [Ecto.UUID.dump!(fixture.intent.id)]},
      {"SELECT args::text FROM oban_jobs WHERE args->'primary_key'->>'id' = $1",
       [fixture.intent.id]},
      {"SELECT row_to_json(s)::text FROM sessions s WHERE account_id = $1",
       [Ecto.UUID.dump!(fixture.registration.account_id)]}
    ]

    queries
    |> Enum.flat_map(fn {query, params} -> Repo.query!(query, params).rows |> List.flatten() end)
    |> Enum.join("\n")
  end
end
