defmodule NewYouWeb.ReconciliationControllerTest do
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Plug.Conn

  alias NewYou.Identity
  alias NewYou.Proof.{P805, P813HoldFixture, PrivilegedAccessSeam, ReconciliationSeam}
  alias NewYou.Proof.ReconciliationScenarios, as: Proof

  @endpoint NewYouWeb.Endpoint
  @path "/dev/support/reconciliation"

  test "scoped detection creates a case with no Account retirement or apply admission" do
    P813HoldFixture.with_fixture(fn fixture ->
      Application.put_env(:new_you, :fp001_development_entry, true)
      survivor = P813HoldFixture.member()

      grant =
        P813HoldFixture.grant(
          fixture.actor,
          fixture.target,
          fixture.approver,
          :identity_reconciliation
        )

      survivor_grant =
        P813HoldFixture.grant(fixture.actor, survivor, fixture.approver, :identity_reconciliation)

      credentials = fixture.actor.credentials
      {conn, csrf} = transport(credentials)

      assert html_response(get(conn.(), @path), 200) =~ "Duplicate Account reconciliation"
      assert response(get(conn.(), @path <> "?case_id=" <> Ecto.UUID.generate()), 404) == ""

      timestamp = System.os_time(:second)
      Process.put(PrivilegedAccessSeam, timestamp)
      operation_id = Ecto.UUID.generate()

      params = %{
        "intent" => "detect",
        "candidate_id" => fixture.target.id,
        "canonical_id" => survivor.id,
        "grant_id" => grant.id,
        "canonical_grant_id" => survivor_grant.id,
        "operation_id" => operation_id,
        "password" => fixture.actor.password,
        "code" => NimbleTOTP.verification_code(fixture.actor.secret, time: timestamp)
      }

      assert response(post(conn.(), @path, params), 403) == ""

      result = post(conn.(), @path, Map.put(params, "_csrf_token", csrf))
      assert html_response(result, 200) =~ "Detected"
      assert get_resp_header(result, "cache-control") == ["no-store"]
      assert result.body_params == %{}
      assert Map.delete(result.private, :phoenix_recycled) == %{}

      for value <- [
            credentials.token,
            fixture.actor.password,
            params["code"],
            grant.id,
            survivor_grant.id
          ] do
        refute result.resp_body =~ value
      end

      assert [%{status: :detected}] =
               Proof.read(Identity.ReconciliationCase, "operation_id", operation_id)

      assert Proof.admissions_for_target(fixture.target.id) == []
      assert P805.account!(fixture.target.id).pmr_status == :active
      assert P805.account!(survivor.id).pmr_status == :active
    end)
  after
    Process.delete(PrivilegedAccessSeam)
  end

  test "case and confirmation state fail closed after stale versions, wrong Sessions and source failure" do
    Proof.with_case(fn fixture ->
      Application.put_env(:new_you, :fp001_development_entry, true)
      {conn, csrf} = transport(fixture.actor.credentials)
      timestamp = System.os_time(:second)
      account = P805.account!(fixture.actor.id)

      {:ok, other_credentials} =
        Identity.authenticate_password(account.email, fixture.actor.password)

      {other, other_csrf} = transport(other_credentials)

      assert {:ok, :ok} =
               P813HoldFixture.step_up(
                 %{fixture.actor | credentials: other_credentials},
                 :review_reconciliation
               )

      assert {:ok, %{status: :detected}} =
               Identity.reconciliation_status(%{
                 credentials: other_credentials,
                 case_id: fixture.case.id,
                 grant_id: fixture.reconciliation_grant.id,
                 canonical_grant_id: fixture.canonical_grant.id
               })

      scope = %{
        "grant_id" => fixture.reconciliation_grant.id,
        "canonical_grant_id" => fixture.canonical_grant.id,
        "case_id" => fixture.case.id
      }

      resume = fn time, fields ->
        post_intent(conn, csrf, "resume", Map.merge(fields, step_up(fixture.actor, time)))
      end

      # Both attempts have valid current step-up. A mismatched grant conceals
      # the real case exactly as it conceals a nonexistent case.
      wrong = Map.put(scope, "canonical_grant_id", fixture.grants.place.id)
      denied = resume.(timestamp + 30, wrong)
      absent = resume.(timestamp + 60, Map.put(wrong, "case_id", Ecto.UUID.generate()))
      assert html_response(denied, 403) =~ "Reconciliation unavailable."
      assert html_response(absent, 403) == denied.resp_body

      initial = resume.(timestamp + 90, scope)
      assert html_response(initial, 200) =~ "Detected"
      state = state!(initial)
      review = %{"state" => state, "decision" => "candidate"}
      assert post_intent(other, other_csrf, "review", review).status == 403
      assert post_intent(conn, csrf, "review", review).status == 200
      assert post_intent(conn, csrf, "review", review).status == 403

      request = Proof.review_request(fixture)

      {:ok, reviewing} =
        Identity.review_reconciliation(%{
          request
          | expected_version: fixture.case.version + 1,
            decision: :review
        })

      {candidate, candidate_csrf} = transport(fixture.target.credentials)
      {canonical, canonical_csrf} = transport(fixture.survivor.credentials)

      control = fn account, token ->
        response = post_intent(account, token, "control", %{"case_id" => fixture.case.id})
        [_, proof] = Regex.run(~r/id="control-proof"[^>]*>([^<]+)</, html_response(response, 200))
        String.trim(proof)
      end

      candidate_proof = control.(candidate, candidate_csrf)
      canonical_proof = control.(canonical, canonical_csrf)
      current = resume.(timestamp + 120, scope)
      assert html_response(current, 200) =~ "In review"

      approval = %{
        "state" => state!(current),
        "decision" => "approved",
        "candidate_control" => candidate_proof,
        "canonical_control" => canonical_proof
      }

      Process.put(ReconciliationSeam, fn
        :before_audit_owner_review -> {:error, :owner_unavailable}
        _ -> :ok
      end)

      assert post_intent(conn, csrf, "review", approval).status == 403
      assert Proof.admissions_for_target(fixture.target.id) == []
      Process.delete(ReconciliationSeam)

      assert :ok = Identity.logout(fixture.target.credentials)
      assert post_intent(conn, csrf, "review", approval).status == 403

      assert Ash.get!(Identity.ReconciliationCase, reviewing.id, authorize?: false).version ==
               reviewing.version

      # A real replacement Session restores the owner's control prerequisite.
      target = P805.account!(fixture.target.id)
      {:ok, fresh} = Identity.authenticate_password(target.email, fixture.target.password)

      {:ok, approved} =
        Identity.review_reconciliation(%{
          request
          | expected_version: reviewing.version,
            controls: [fresh, fixture.survivor.credentials]
        })

      page = resume.(timestamp + 150, scope)
      assert html_response(page, 200) =~ "Approved"
      assert post_intent(conn, csrf, "apply", %{"state" => state!(page)}).status == 403

      confirmation =
        post_intent(
          conn,
          csrf,
          "prepare",
          Map.put(step_up(fixture.actor, timestamp + 180), "state", state!(page))
        )

      assert html_response(confirmation, 200) =~ "Confirm the canonical decision"
      assert Proof.admissions_for_target(target.id) == []

      Process.put(ReconciliationSeam, fn
        :after_admission -> raise "synthetic pre-commit failure"
        _ -> :ok
      end)

      failed = post_intent(conn, csrf, "apply", %{"state" => state!(confirmation)})
      assert html_response(failed, 403) =~ "Reconciliation unavailable."
      refute failed.resp_body =~ "Identity recorded the canonical decision"
      assert [%{attempt_id: attempt}] = Proof.admissions_for_target(target.id)
      assert [%{outcome: :failed}] = Proof.outcomes(attempt)
      assert P805.account!(target.id).pmr_status == :active

      assert Ash.get!(Identity.ReconciliationCase, approved.id, authorize?: false).status ==
               :approved

      assert post_intent(conn, csrf, "apply", %{"state" => state!(confirmation)}).status == 403
      assert [%{attempt_id: ^attempt}] = Proof.admissions_for_target(target.id)
      assert [%{outcome: :failed}] = Proof.outcomes(attempt)

      assert :ok = Identity.logout(fixture.actor.credentials)
      assert post_intent(conn, csrf, "apply", %{"state" => state!(confirmation)}).status == 404
    end)
  after
    Process.delete(PrivilegedAccessSeam)
    Process.delete(ReconciliationSeam)
  end

  test "control proof requires authentic, current evidence for this case and review generation" do
    Proof.with_case(fn fixture ->
      Application.put_env(:new_you, :fp001_development_entry, true)
      operator = transport(fixture.actor.credentials)
      candidate = transport(fixture.target.credentials)
      canonical = transport(fixture.survivor.credentials)
      unrelated = transport(fixture.approver.credentials)
      time = System.os_time(:second)

      request = Proof.review_request(fixture)
      first = fixture.case |> transition(request, :candidate) |> transition(request, :review)

      assert {:ok, second_detected} =
               Identity.open_reconciliation(
                 request
                 |> Map.take([:credentials, :grant_id, :canonical_grant_id])
                 |> Map.merge(%{
                   candidate_id: fixture.target.id,
                   canonical_id: fixture.survivor.id,
                   operation_id: Ecto.UUID.generate(),
                   detection_basis: :reported_duplicate
                 })
               )

      second =
        second_detected |> transition(request, :candidate) |> transition(request, :review)

      assert first.id != second.id
      assert first.version == second.version
      case_ids = [first.id, second.id]

      {unrelated_conn, unrelated_csrf} = unrelated

      assert {:ok, %{account_id: unrelated_id}} =
               Identity.authorize_session(fixture.approver.credentials)

      assert unrelated_id == fixture.approver.id

      assert_reconciliation_denied(fixture, case_ids, fn ->
        response =
          post_intent(unrelated_conn, unrelated_csrf, "control", %{"case_id" => first.id})

        proof_rendered? = String.contains?(response.resp_body, ~s(id="control-proof"))
        refute proof_rendered?
        response
      end)

      first_candidate = control_proof(candidate, first.id)
      first_canonical = control_proof(canonical, first.id)
      first_state = review_state(operator, fixture, first.id, time + 30)

      assert_reconciliation_denied(fixture, case_ids, fn ->
        submit_approval(operator, first_state, tamper_control(first_candidate), first_canonical)
      end)

      assert_reconciliation_denied(fixture, case_ids, fn ->
        submit_approval(operator, first_state, expire_control(first_candidate), first_canonical)
      end)

      second_state = review_state(operator, fixture, second.id, time + 60)
      second_candidate = control_proof(candidate, second.id)
      second_canonical = control_proof(canonical, second.id)

      assert_reconciliation_denied(fixture, case_ids, fn ->
        submit_approval(operator, second_state, first_candidate, second_canonical)
      end)

      # Keep the pair and the per-case generation equal in the wrong-case check.
      assert html_response(
               submit_approval(operator, second_state, second_candidate, second_canonical),
               200
             ) =~ "Approved"

      latest = first |> transition(request, :conflict) |> transition(request, :review)
      latest_state = review_state(operator, fixture, latest.id, time + 90)
      latest_candidate = control_proof(candidate, latest.id)
      latest_canonical = control_proof(canonical, latest.id)

      assert_reconciliation_denied(fixture, case_ids, fn ->
        submit_approval(operator, latest_state, first_candidate, latest_canonical)
      end)

      assert html_response(
               submit_approval(operator, latest_state, latest_candidate, latest_canonical),
               200
             ) =~ "Approved"

      assert Ash.get!(Identity.ReconciliationCase, latest.id, authorize?: false).status ==
               :approved

      assert Proof.admissions_for_target(fixture.target.id) == []
    end)
  after
    Process.delete(PrivilegedAccessSeam)
  end

  test "Chromium verifies both Accounts, cancels, applies, and reopens the committed case" do
    P813HoldFixture.with_fixture(fn fixture ->
      Application.put_env(:new_you, :fp001_development_entry, true)
      Mix.Task.run("assets.build")

      survivor = P813HoldFixture.member()

      grant =
        P813HoldFixture.grant(
          fixture.actor,
          fixture.target,
          fixture.approver,
          :identity_reconciliation
        )

      canonical_grant =
        P813HoldFixture.grant(fixture.actor, survivor, fixture.approver, :identity_reconciliation)

      candidate_before = P805.account!(fixture.target.id)
      canonical_before = P805.account!(survivor.id)
      timestamp = System.os_time(:second)

      {:ok, server} =
        Bandit.start_link(
          plug: {__MODULE__.BrowserEndpoint, {timestamp, :atomics.new(1, [])}},
          ip: {127, 0, 0, 1},
          port: 0
        )

      handler = {__MODULE__, make_ref()}

      :ok =
        :telemetry.attach_many(
          handler,
          [[:bandit, :request, :stop], [:new_you, :repo, :query]],
          &__MODULE__.observe_transport/4,
          self()
        )

      try do
        {:ok, {_, port}} = ThousandIsland.listener_info(server)

        payload =
          Jason.encode!(%{
            mode: "operator_reconciliation",
            locale: "en",
            port: port,
            operator: browser_account(fixture.actor),
            accounts: Enum.map([fixture.target, survivor], &browser_account/1),
            pair: %{candidate_id: fixture.target.id, canonical_id: survivor.id},
            grants: %{grant_id: grant.id, canonical_grant_id: canonical_grant.id},
            codes:
              for(
                index <- 0..19,
                do:
                  NimbleTOTP.verification_code(fixture.actor.secret, time: timestamp + index * 30)
              )
          })

        result =
          NewYou.Proof.P805Browser.run_port(
            System.find_executable("node"),
            Path.expand("../../proof/p8_05_browser.mjs", __DIR__),
            payload
          )

        assert result["cleanup"]

        for check <-
              ~w(signed_in reflow keyboard detected focused_result candidate review conflict
                        review_again independent_controls approved confirmation confirmed_pair
                        cancelled resumed_approved reconfirmed applied private_history scrubbed_on_leave
                        back_blank forward resumed_applied) do
          assert result["checks"][check], "Reconciliation browser check failed: #{check}"
        end

        assert [%{status: :applied} = record] =
                 Proof.read(Identity.ReconciliationCase, "candidate_id", fixture.target.id)

        assert Enum.map(record.history, & &1["status"]) ==
                 ~w(candidate review conflict review approved applied)

        assert [%{attempt_id: attempt_id}] = Proof.admissions_for_target(fixture.target.id)
        assert attempt_id == record.applied_operation_id
        assert [%{outcome: :succeeded}] = Proof.outcomes(attempt_id)

        assert %{pmr_status: :retired, pmr: retired_pmr, canonical_account_id: canonical_id} =
                 P805.account!(fixture.target.id)

        assert retired_pmr == candidate_before.pmr
        assert canonical_id == survivor.id
        assert %{pmr_status: :active, pmr: active_pmr} = P805.account!(survivor.id)
        assert active_pmr == canonical_before.pmr
        assert_receive {:operator_transport, true}
        refute_received {:operator_transport, false}
        refute_received :operator_query_payload
      after
        :telemetry.detach(handler)
        Supervisor.stop(server)
      end
    end)
  end

  @doc false
  def observe_transport(
        [:bandit, :request, :stop],
        _measurements,
        %{conn: %{request_path: @path, method: "POST"} = conn},
        test_pid
      ) do
    safe? =
      conn.params == %{} and conn.body_params == %{} and conn.assigns == %{} and
        conn.private == %{} and conn.req_headers == [] and conn.resp_cookies == %{} and
        get_resp_header(conn, "set-cookie") == [] and is_nil(conn.resp_body)

    send(test_pid, {:operator_transport, safe?})
  end

  # Oban's Postgres notifier emits only its fixed queue wakeup here. Any
  # additional fields or a different query carrying values fail the proof.
  def observe_transport(
        [:new_you, :repo, :query],
        _measurements,
        %{
          query:
            "SELECT pg_notify($1, payload) FROM json_array_elements_text($2::json) AS payload",
          params: ["public.oban_insert", [~s({"queue":"audit"})]]
        },
        _test_pid
      ),
      do: :ok

  def observe_transport([:new_you, :repo, :query], _measurements, metadata, test_pid) do
    payload? =
      metadata.params not in [[], nil] or match?({:ok, %{rows: [_ | _]}}, metadata.result)

    if Process.get({__MODULE__, :reconciliation_request}) && payload?,
      do: send(test_pid, :operator_query_payload)
  end

  def observe_transport([:bandit, :request, :stop], _measurements, _metadata, _test_pid),
    do: :ok

  defp transport(credentials) do
    csrf = Plug.CSRFProtection.get_csrf_token()
    csrf_state = Plug.CSRFProtection.dump_state()

    conn = fn ->
      build_conn()
      |> put_private(:plug_skip_csrf_protection, false)
      |> put_req_header("x-newyou-operator-request", "1")
      |> Plug.Test.init_test_session(%{
        "_csrf_token" => csrf_state,
        "identity_session_id" => credentials.session_id,
        "identity_token" => credentials.token
      })
    end

    {conn, csrf}
  end

  defp post_intent(conn, csrf, intent, fields),
    do: post(conn.(), @path, Map.merge(fields, %{"_csrf_token" => csrf, "intent" => intent}))

  defp transition(record, request, decision) do
    {:ok, next} =
      Identity.review_reconciliation(%{
        request
        | case_id: record.id,
          expected_version: record.version,
          decision: decision
      })

    next
  end

  defp review_state({conn, csrf}, fixture, case_id, time) do
    scope = %{
      "grant_id" => fixture.reconciliation_grant.id,
      "canonical_grant_id" => fixture.canonical_grant.id,
      "case_id" => case_id
    }

    response = post_intent(conn, csrf, "resume", Map.merge(scope, step_up(fixture.actor, time)))
    assert html_response(response, 200) =~ "In review"
    state!(response)
  end

  defp control_proof({conn, csrf}, case_id) do
    response = post_intent(conn, csrf, "control", %{"case_id" => case_id})
    [_, proof] = Regex.run(~r/id="control-proof"[^>]*>([^<]+)</, html_response(response, 200))
    String.trim(proof)
  end

  defp submit_approval({conn, csrf}, state, candidate, canonical) do
    post_intent(conn, csrf, "review", %{
      "state" => state,
      "decision" => "approved",
      "candidate_control" => candidate,
      "canonical_control" => canonical
    })
  end

  defp tamper_control(proof) do
    [prefix, payload] = String.split(proof, ".", parts: 2)
    <<first, rest::binary>> = Base.url_decode64!(payload, padding: false)
    prefix <> "." <> Base.url_encode64(<<Bitwise.bxor(first, 1), rest::binary>>, padding: false)
  end

  defp expire_control(proof) do
    salt = "operator-reconciliation-control-v1"
    {:ok, evidence} = Phoenix.Token.decrypt(@endpoint, salt, proof, max_age: 300)

    expired =
      Phoenix.Token.encrypt(@endpoint, salt, evidence, signed_at: System.os_time(:second) - 301)

    result = Phoenix.Token.decrypt(@endpoint, salt, expired, max_age: 300)
    expired? = match?({:error, :expired}, result)
    assert expired?
    expired
  end

  defp assert_reconciliation_denied(fixture, case_ids, submit) do
    before = reconciliation_snapshot(fixture, case_ids)
    response = submit.()
    assert response.status == 403
    assert html_response(response, 403) =~ "Reconciliation unavailable."
    assert reconciliation_snapshot(fixture, case_ids) == before
    assert Enum.all?(before.admissions, &(&1 == []))
  end

  defp reconciliation_snapshot(fixture, case_ids) do
    accounts = [fixture.target.id, fixture.survivor.id]

    %{
      cases:
        Enum.map(case_ids, fn id ->
          Identity.ReconciliationCase
          |> Ash.get!(id, authorize?: false)
          |> Map.take([:version, :status, :review, :history, :applied_operation_id])
        end),
      admissions: Enum.map(accounts, &Proof.admissions_for_target/1),
      accounts:
        Enum.map(accounts, fn id ->
          P805.account!(id)
          |> Map.take([
            :account_status,
            :security_version,
            :reconciliation_version,
            :pmr,
            :pmr_status,
            :canonical_account_id,
            :updated_at
          ])
        end)
    }
  end

  defp step_up(actor, time) do
    Process.put(PrivilegedAccessSeam, time)

    %{
      "password" => actor.password,
      "code" => NimbleTOTP.verification_code(actor.secret, time: time)
    }
  end

  defp state!(conn) do
    [_, state] = Regex.run(~r/name="state"[^>]*value="([^"]+)"/, conn.resp_body)
    state
  end

  defp browser_account(account),
    do: %{email: P805.account!(account.id).email, password: account.password}

  defmodule BrowserEndpoint do
    @moduledoc false
    @behaviour Plug

    def init(options), do: options

    def call(
          %{method: "POST", request_path: "/dev/support/reconciliation"} = conn,
          {time, attempts}
        ) do
      attempt = :atomics.add_get(attempts, 1, 1)
      Process.put(PrivilegedAccessSeam, time + 30 * (attempt - 1))
      Process.put({NewYouWeb.ReconciliationControllerTest, :reconciliation_request}, true)
      NewYou.Proof.SignInJourney.Endpoint.call(conn, [])
    after
      Process.delete(PrivilegedAccessSeam)
      Process.delete({NewYouWeb.ReconciliationControllerTest, :reconciliation_request})
    end

    def call(conn, _options), do: NewYou.Proof.SignInJourney.Endpoint.call(conn, [])
  end
end
