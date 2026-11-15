defmodule NewYou.Proof.SignInJourney do
  @moduledoc false
  import ExUnit.Assertions
  require Ash.Query
  alias NewYou.{Communications, Identity, Repo}
  alias NewYou.Proof.{P805, P805Browser}

  @checks ~w(normal_navigation locale invalid_correction password protected_reload logout stale_cookie magic_request passive_confirmation magic_sign_in magic_replay recovery responsive text_resize focus reduced_motion stylesheet_loaded unfinished)

  def run(locale) do
    Mix.Task.run("assets.build")

    P805.with_fixture(fn ->
      input = P805.request()
      {:ok, registration} = Identity.register(input)
      {:ok, :verified} = Identity.verify_email(registration.verification_proof)

      keys =
        ~w(fp001_development_entry p8_08_browser_development_fixtures p8_09_browser_development_fixtures)a

      previous = Map.new(keys, &{&1, Application.fetch_env(:new_you, &1)})

      try do
        Application.put_env(:new_you, :fp001_development_entry, true)
        Application.put_env(:new_you, :p8_08_browser_development_fixtures, false)
        Application.put_env(:new_you, :p8_09_browser_development_fixtures, false)
        run_browser(locale, input)
        assert_sessions(registration.account_id)
      after
        Enum.each(previous, fn
          {key, {:ok, value}} -> Application.put_env(:new_you, key, value)
          {key, :error} -> Application.delete_env(:new_you, key)
        end)
      end
    end)
  end

  defp run_browser(locale, input) do
    {:ok, server} = Bandit.start_link(plug: __MODULE__.Endpoint, ip: {127, 0, 0, 1}, port: 0)

    try do
      {:ok, {_, port}} = ThousandIsland.listener_info(server)
      payload = Jason.encode!(%{mode: "signin", locale: locale, port: port, input: input})

      result =
        P805Browser.run_port(
          System.find_executable("node"),
          Path.expand("../proof/p8_05_browser.mjs", __DIR__),
          payload
        )

      Enum.each(result["operations"] || [], &P805.track_operation/1)
      assert result["cleanup"] == true

      for key <- @checks,
          do:
            assert(
              result["checks"][key] == true,
              "ordinary sign-in browser obligation failed: #{key}"
            )
    after
      Supervisor.stop(server)
    end
  end

  defp assert_sessions(id) do
    sessions =
      Identity.Session |> Ash.Query.filter(account_id == ^id) |> Ash.read!(authorize?: false)

    assert length(sessions) == 3
    assert Enum.count(sessions, &(&1.state == :logged_out)) == 2
    assert Enum.count(sessions, &(&1.state == :active)) == 1
    assert Enum.count(sessions, &(&1.authentication_method == :magic_login)) == 1
    assert Enum.count(sessions, &(&1.authentication_method == :password)) == 2

    user_tokens =
      Identity.Token
      |> Ash.Query.filter(account_id == ^id and purpose == "user")
      |> Ash.read!(authorize?: false)

    assert length(user_tokens) == 3

    assert Enum.all?(sessions, fn session ->
             Enum.any?(user_tokens, &(&1.jti == session.token_jti))
           end)

    [proof] =
      Identity.Token
      |> Ash.Query.filter(account_id == ^id and not is_nil(magic_request_id))
      |> Ash.read!(authorize?: false)

    assert proof.purpose == "magic_login_consumed"
    magic_session = Enum.find(sessions, &(&1.authentication_method == :magic_login))
    assert magic_session.authentication_proof_jti == proof.jti
  end

  defmodule Endpoint do
    @moduledoc false
    @behaviour Plug
    import Plug.Conn
    require Ash.Query
    def init(opts), do: opts

    def call(conn, _) do
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo, sandbox: false)

      try do
        if conn.request_path == "/__well134/delivery",
          do: deliver(conn),
          else: NewYouWeb.Endpoint.call(conn, NewYouWeb.Endpoint.init([]))
      after
        Process.delete(:p810_provider)
        Process.delete({__MODULE__, :proof})
        Ecto.Adapters.SQL.Sandbox.checkin(Repo)
      end
    end

    defp deliver(conn) do
      conn = fetch_query_params(conn)
      operation = Map.fetch!(conn.query_params, "operation")

      intent =
        Communications.MessageIntent
        |> Ash.Query.filter(source_operation_id == ^operation)
        |> Ash.read_one!(authorize?: false)

      Process.put(:p810_provider, fn _, payload ->
        [_, encoded] = Regex.run(~r{/login/magic/confirm\?[^\s]*proof=([^&\s]+)}, payload.body)
        Process.put({__MODULE__, :proof}, URI.decode_www_form(encoded))
        :delivered
      end)

      {:ok, :processed} = Communications.execute(intent.id)
      proof = Process.get({__MODULE__, :proof})
      assert is_binary(proof)

      conn
      |> put_resp_content_type("application/json")
      |> put_resp_header("cache-control", "no-store")
      |> send_resp(200, Jason.encode!(%{proof: proof}))
    end
  end
end
