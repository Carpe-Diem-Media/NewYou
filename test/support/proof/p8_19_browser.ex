defmodule NewYou.Proof.P819Browser do
  @moduledoc false
  import ExUnit.Assertions
  alias NewYou.Proof.{P805, P805Browser, SelfTest}
  require Ash.Query

  def run(locale) do
    P805.with_fixture(fn ->
      input = P805.request(%{preferred_language: String.to_existing_atom(locale)})
      reference = make_ref()

      {:ok, server} =
        Bandit.start_link(
          plug: {__MODULE__.Endpoint, {self(), reference}},
          ip: {127, 0, 0, 1},
          port: 0
        )

      {:ok, {_, port}} = ThousandIsland.listener_info(server)
      SelfTest.cleanup_manifest!(workers_stopped: false)
      Process.put({__MODULE__, reference}, false)

      try do
        payload =
          Jason.encode!(%{
            mode: "spine",
            port: port,
            locale: locale,
            input: input,
            platform_name: NewYou.platform_name()
          })

        result =
          P805Browser.run_port(
            System.find_executable("node"),
            Path.expand("../../proof/p8_05_browser.mjs", __DIR__),
            payload
          )

        Process.put({__MODULE__, reference}, result["cleanup"] == true)
        assert result["cleanup"] == true
        Enum.each(result["operations"], &P805.track_operation/1)

        checks =
          Map.put(
            result["checks"],
            "verification_no_session",
            session_observations(reference, []) == [true, true, true, false]
          )

        for key <-
              ~w(approved_copy required_form legal_artifacts submitted_acceptances pending_copy explicit_resend locale_no_fallback no_session explicit_verification verification_no_session login_form protected_access reloaded_access),
            do: assert(checks[key] == true, "continuous browser obligation failed: #{key}")

        [registration_id, _resend_id] = result["operations"]
        [operation] = P805.registration_operations(registration_id)
        account = P805.account!(operation.created_account_id)
        assert account.email == input.email
        assert account.email_verified?
        assert NewYou.Identity.PMR.valid?(account.pmr)

        assert P805.scalar("SELECT count(*) FROM sessions WHERE account_id = $1", [
                 Ecto.UUID.dump!(account.id)
               ]) == 1
      after
        Supervisor.stop(server)
        browser_stopped? = Process.delete({__MODULE__, reference}) == true

        SelfTest.cleanup_manifest!(
          workers_stopped: not Process.alive?(server) and browser_stopped?
        )
      end
    end)
  end

  defp session_observations(reference, observations) do
    receive do
      {^reference, :session_safe, safe} -> session_observations(reference, observations ++ [safe])
    after
      0 -> observations
    end
  end
end

defmodule NewYou.Proof.P819Browser.Endpoint do
  @moduledoc false
  @behaviour Plug
  import Plug.Conn
  require Ash.Query
  alias NewYou.{Communications, Repo}

  def init(options), do: options

  # This endpoint exists only in TEST proof support. It delivers a synthetic
  # message through the real Communications owner to the same browser context.
  def call(%{request_path: "/__proof/delivery"} = conn, _) do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo, sandbox: false)

    try do
      conn = fetch_query_params(conn)
      operation_id = Map.fetch!(conn.query_params, "operation")

      intent =
        Communications.MessageIntent
        |> Ash.Query.filter(source_operation_id == ^operation_id)
        |> Ash.read_one!(authorize?: false)

      Process.put(:p810_provider, fn _, payload ->
        [_, encoded] = Regex.run(~r{/verification/confirm\?[^\s]*proof=([^&\s]+)}, payload.body)
        Process.put({__MODULE__, :delivered_proof}, URI.decode_www_form(encoded))
        :delivered
      end)

      {:ok, :processed} = Communications.execute(intent.id)
      proof = Process.delete({__MODULE__, :delivered_proof})
      true = is_binary(proof)

      conn
      |> put_resp_content_type("application/json")
      |> put_resp_header("cache-control", "no-store")
      |> send_resp(200, Jason.encode!(%{proof: proof}))
    after
      Process.delete(:p810_provider)
      Process.delete({__MODULE__, :delivered_proof})
      Ecto.Adapters.SQL.Sandbox.checkin(Repo)
    end
  end

  def call(conn, observer), do: NewYou.Proof.P805Browser.Endpoint.call(conn, observer)
end
