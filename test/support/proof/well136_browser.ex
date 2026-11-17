defmodule NewYou.Proof.Well136Browser do
  @moduledoc false
  import ExUnit.Assertions
  require Ash.Query
  alias NewYou.Identity
  alias NewYou.Identity.{Account, Token, Session}
  alias NewYou.Proof.{P805, P805Browser}

  def run(locale) do
    P805.with_fixture(fn ->
      Application.put_env(:new_you, :fp001_development_entry, true)

      for key <- [
            :p8_05_browser_development_fixtures,
            :p8_07_browser_development_fixtures,
            :p8_08_browser_development_fixtures,
            :p8_09_browser_development_fixtures,
            :p8_12_browser_development_fixtures
          ] do
        Application.put_env(:new_you, key, false)
      end

      request = P805.request(%{preferred_language: String.to_existing_atom(locale)})
      {:ok, registration} = Identity.register(request)
      {:ok, :verified} = Identity.verify_email(registration.verification_proof)
      reference = make_ref()

      with_browser_fixture(registration.account_id, reference, fn port ->
        assert_browser_journey(locale, request, registration.account_id, port)
      end)
    end)
  end

  defp assert_browser_journey(locale, request, account_id, port) do
    payload =
      Jason.encode!(%{
        mode: "ordinary_reset",
        port: port,
        locale: locale,
        email: request.email,
        password: request.password,
        replacement: "ordinary browser replacement"
      })

    result =
      P805Browser.run_port(
        System.find_executable("node"),
        Path.expand("../../proof/p8_05_browser.mjs", __DIR__),
        payload
      )

    assert result["cleanup"] == true
    Enum.each(result["operations"], &P805.track_operation/1)

    assert_checks!(result["checks"])

    consumed =
      Token
      |> Ash.Query.filter(account_id == ^account_id and purpose == "password_reset_consumed")
      |> Ash.read!(authorize?: false)

    assert length(consumed) == 1

    sessions =
      Session
      |> Ash.Query.filter(account_id == ^account_id)
      |> Ash.read!(authorize?: false)

    assert Enum.count(sessions, &(&1.state == :revoked)) == 1
    assert Enum.count(sessions, &(&1.state == :active)) == 1
    account = Ash.get!(Account, account_id, authorize?: false)
    assert account.credential_version == 2
  end

  @doc false
  def assert_checks!(checks) do
    for {key, value} <- checks,
        do:
          assert(
            value == true,
            "WELL-136 browser check failed: #{key}; resize #{inspect(checks["resize_diagnostics"])}"
          )

    for key <- ~w(
          public_entry prior_session forgot_password approved_request labels stylesheet
          responsive text_resize reduced_motion keyboard_focus csrf neutral_request accepted_copy
          real_delivery scanner_safe confirmation_copy completed_copy no_automatic_login
          proof_not_rendered persisted_reset stale_session_denied replay_denied retry_navigation
          old_password_denied fresh_sign_in expired_link withdrawal_blocks_delivery
          failed_attempts_preserve_credential
        ) do
      assert checks[key] == true, "WELL-136 required browser check missing or failed: #{key}"
    end
  end

  defp with_browser_fixture(account_id, reference, callback) do
    evidence_root = Path.join(System.tmp_dir!(), "well136-browser-#{Ecto.UUID.generate()}")
    # Atomic creation establishes ownership; never remove an existing directory.
    File.mkdir!(evidence_root)

    try do
      setup_checkpoint(:evidence_directory_created, evidence_root)
      File.cp_r!("docs", Path.join(evidence_root, "docs"))
      with_server(account_id, reference, evidence_root, callback)
    after
      File.rm_rf!(evidence_root)
      drain_operations(reference)
    end
  end

  defp with_server(account_id, reference, evidence_root, callback) do
    {:ok, server} =
      Bandit.start_link(
        plug: {__MODULE__.Endpoint, {self(), reference, account_id, evidence_root}},
        ip: {127, 0, 0, 1},
        port: 0
      )

    try do
      setup_checkpoint(:server_started, server)
      {:ok, {_, port}} = ThousandIsland.listener_info(server)
      callback.(port)
    after
      if Process.alive?(server), do: Supervisor.stop(server)
    end
  end

  defp setup_checkpoint(stage, value) do
    case Process.get({__MODULE__, :setup_checkpoint}) do
      callback when is_function(callback, 2) -> callback.(stage, value)
      _ -> :ok
    end
  end

  defp drain_operations(reference) do
    receive do
      {^reference, :operation, id} ->
        P805.track_operation(id)
        drain_operations(reference)
    after
      0 -> :ok
    end
  end
end

defmodule NewYou.Proof.Well136Browser.Endpoint do
  @moduledoc false
  @behaviour Plug
  import Plug.Conn
  require Ash.Query
  alias NewYou.{Communications, Identity, Repo}
  alias NewYou.Identity.{Token, Session}

  def init(opts), do: opts

  def call(conn, {parent, reference, account_id, evidence_root}) do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo, sandbox: false)

    try do
      Process.put({NewYou.Content.PasswordResetMessage, :evidence_root}, evidence_root)

      case conn.request_path do
        "/__well136/delivery" ->
          deliver(conn, account_id)

        "/__well136/snapshot" ->
          snapshot(conn, account_id)

        "/__well136/expire" ->
          expire(conn, account_id)

        "/__well136/withdraw" ->
          withdraw(conn, evidence_root)

        _ ->
          conn =
            register_before_send(conn, fn response ->
              if response.method == "POST" and is_binary(response.params["operation_id"]),
                do: send(parent, {reference, :operation, response.params["operation_id"]})

              response
            end)

          NewYouWeb.Endpoint.call(conn, NewYouWeb.Endpoint.init([]))
      end
    after
      Process.delete(:p810_provider)
      Process.delete({__MODULE__, :proof})
      Process.delete({NewYou.Content.PasswordResetMessage, :evidence_root})
      Ecto.Adapters.SQL.Sandbox.checkin(Repo)
    end
  end

  defp deliver(conn, account_id) do
    conn = fetch_query_params(conn)
    operation = conn.query_params["operation"]

    intent =
      Communications.MessageIntent
      |> Ash.Query.filter(source_operation_id == ^operation and role == :password_reset)
      |> Ash.read_one!(authorize?: false)

    proof = Ash.get!(Token, intent.source_reference, authorize?: false)
    true = proof.account_id == account_id and intent.render_schema == "password-reset-well136-v1"

    Process.put(:p810_provider, fn _, payload ->
      [_, encoded] = Regex.run(~r{/password/reset/confirm\?[^\s]*proof=([^&\s]+)}, payload.body)
      Process.put({__MODULE__, :proof}, URI.decode_www_form(encoded))
      :delivered
    end)

    outcome = Communications.execute(intent.id)
    bearer = Process.delete({__MODULE__, :proof})

    case outcome do
      {:ok, :processed} ->
        true = is_binary(bearer)
        json(conn, %{proof: bearer})

      {:ok, :held} ->
        true = is_nil(bearer)
        json(conn, %{held: true})
    end
  end

  # Scoped TEST fault injection, never an application write interface.
  defp expire(conn, account_id) do
    conn = fetch_query_params(conn)
    operation = conn.query_params["operation"]

    intent =
      Communications.MessageIntent
      |> Ash.Query.filter(source_operation_id == ^operation and role == :password_reset)
      |> Ash.read_one!(authorize?: false)

    Repo.query!(
      "UPDATE tokens SET expires_at = NOW() - interval '1 second' WHERE jti = $1 AND account_id = $2",
      [intent.source_reference, Ecto.UUID.dump!(account_id)]
    )

    json(conn, %{expired: true})
  end

  defp withdraw(conn, root) do
    path =
      Path.join(
        root,
        "docs/delivery/content-evidence/content_media/password_reset_messages/PASSWORD_RESET_MESSAGE_WELL136_PHASE9_ELIGIBILITY_v0.3.0.json"
      )

    packet = path |> File.read!() |> Jason.decode!()
    File.write!(path, Jason.encode!(put_in(packet, ["lifecycle", "state"], "withdrawn")))
    json(conn, %{withdrawn: true})
  end

  defp snapshot(conn, account_id) do
    account = Ash.get!(Identity.Account, account_id, authorize?: false)

    proofs =
      Token
      |> Ash.Query.filter(account_id == ^account_id and purpose == "password_reset")
      |> Ash.read!(authorize?: false)

    sessions =
      Session
      |> Ash.Query.filter(account_id == ^account_id and state == :active)
      |> Ash.read!(authorize?: false)

    json(conn, %{
      credential_version: account.credential_version,
      current_proofs: length(proofs),
      active_sessions: length(sessions)
    })
  end

  defp json(conn, value),
    do:
      conn
      |> put_resp_header("cache-control", "no-store")
      |> put_resp_content_type("application/json")
      |> send_resp(200, Jason.encode!(value))
end
