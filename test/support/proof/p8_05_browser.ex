defmodule NewYou.Proof.P805Browser do
  @moduledoc false
  alias NewYou.Proof.{P805, SelfTest}
  alias NewYou.Identity
  require Ash.Query

  def run_login(request, locale) do
    reference = make_ref()

    {:ok, server} =
      Bandit.start_link(
        plug: {NewYou.Proof.P805Browser.Endpoint, {self(), reference}},
        ip: {127, 0, 0, 1},
        port: 0
      )

    {:ok, {_address, port}} = ThousandIsland.listener_info(server)

    try do
      payload =
        Jason.encode!(%{
          mode: "login",
          port: port,
          locale: locale,
          email: request.email,
          password: request.password
        })

      result =
        run_port(
          System.find_executable("node"),
          Path.expand("../../proof/p8_05_browser.mjs", __DIR__),
          payload
        )

      true = result["cleanup"]
      result["checks"]
    after
      Supervisor.stop(server)
    end
  end

  def run_verification(registration, locale) do
    reference = make_ref()

    {:ok, server} =
      Bandit.start_link(
        plug: {NewYou.Proof.P805Browser.Endpoint, {self(), reference}},
        ip: {127, 0, 0, 1},
        port: 0
      )

    {:ok, {_address, port}} = ThousandIsland.listener_info(server)

    try do
      payload =
        Jason.encode!(%{
          mode: "verification",
          port: port,
          locale: locale,
          proof: registration.verification_proof
        })

      executable = System.find_executable("node") || raise "proof browser requires Node"

      result =
        run_port(executable, Path.expand("../../proof/p8_05_browser.mjs", __DIR__), payload)

      true = result["cleanup"]
      Map.put(result["checks"], "no_session", collect_sessions(reference, []) == [true, true])
    after
      Supervisor.stop(server)
    end
  end

  def run(id, locale) do
    SelfTest.cleanup_manifest!(workers_stopped: false)
    input = P805.request(%{preferred_language: String.to_existing_atom(locale)})

    reference = make_ref()

    {:ok, server} =
      Bandit.start_link(
        plug: {NewYou.Proof.P805Browser.Endpoint, {self(), reference}},
        ip: {127, 0, 0, 1},
        port: 0
      )

    {:ok, {_address, port}} = ThousandIsland.listener_info(server)

    try do
      payload =
        Jason.encode!(%{
          port: port,
          locale: locale,
          input: input,
          platform_name: NewYou.platform_name()
        })

      # Stdin keeps synthetic credentials out of argv and command diagnostics.
      executable = System.find_executable("node") || raise "proof browser requires Node"
      script = Path.expand("../../proof/p8_05_browser.mjs", __DIR__)
      result = run_port(executable, script, payload)
      true = result["cleanup"]
      Process.put({__MODULE__, :browser_stopped}, true)
      Enum.each(result["operations"] || [], fn operation -> P805.track_operation(operation) end)

      result = bind_durable_result(result, input)
      sessions = collect_sessions(reference, [])

      result =
        update_in(result, ["checks", "no_session"], &(&1 == true and sessions == [true, true]))

      for assertion <-
            ~w(approved_copy required_form legal_artifacts submitted_acceptances pending_copy explicit_resend locale_no_fallback no_session) do
        P805.check(id, assertion, get_in(result, ["checks", assertion]), true)
      end
    after
      Supervisor.stop(server)

      SelfTest.cleanup_manifest!(
        workers_stopped: Process.delete({__MODULE__, :browser_stopped}) == true
      )
    end
  end

  defp bind_durable_result(%{"operations" => [registration_id, resend_id]} = result, input) do
    operation =
      Identity.RegistrationOperation
      |> Ash.Query.filter(operation_id == ^registration_id)
      |> Ash.read_one!(domain: Identity, authorize?: false)

    account = P805.account!(operation.created_account_id)

    fields = [
      :first_name,
      :surname,
      :email,
      :preferred_language,
      :confirmed_age_18?,
      :terms_version_id,
      :privacy_version_id
    ]

    accepted =
      Map.take(account, fields) == Map.take(input, fields) and
        account.acceptance_locale == input.preferred_language and not account.email_verified? and
        match?(%DateTime{}, account.legal_accepted_at)

    resend =
      Identity.ResendOperation
      |> Ash.Query.filter(operation_id == ^resend_id)
      |> Ash.read_one!(domain: Identity, authorize?: false)

    resent =
      resend.outcome == :accepted and resend.account_id == account.id and
        length(P805.intents(resend_id)) == 1 and length(P805.challenges(account.id)) == 1

    result
    |> update_in(["checks", "submitted_acceptances"], &(&1 == true and accepted))
    |> update_in(["checks", "explicit_resend"], &(&1 == true and resent))
  end

  defp bind_durable_result(result, _input),
    do: put_in(result, ["checks", "submitted_acceptances"], false)

  defp run_port(executable, script, payload) do
    port =
      Port.open({:spawn_executable, executable}, [
        :binary,
        :exit_status,
        :use_stdio,
        args: [script]
      ])

    Port.command(port, payload <> "\n")
    collect(port, "")
  end

  defp collect_sessions(reference, sessions) do
    receive do
      {^reference, :session_safe, safe} -> collect_sessions(reference, [safe | sessions])
    after
      0 -> sessions
    end
  end

  defp collect(port, output) do
    receive do
      {^port, {:data, data}} when byte_size(output) + byte_size(data) <= 16_384 ->
        collect(port, output <> data)

      {^port, {:exit_status, 0}} ->
        Jason.decode!(output)

      {^port, {:exit_status, _}} ->
        raise "proof browser failed with bounded diagnostic"
    after
      45_000 ->
        Port.close(port)
        raise "proof browser deadline"
    end
  end
end

defmodule NewYou.Proof.P805Browser.Endpoint do
  @moduledoc false
  @behaviour Plug
  def init(opts), do: opts

  def call(conn, {parent, reference}) do
    conn =
      Plug.Conn.register_before_send(conn, fn response ->
        if response.method == "POST" do
          session = Plug.Conn.get_session(response)

          send(
            parent,
            {reference, :session_safe, Enum.all?(Map.keys(session), &(&1 == "_csrf_token"))}
          )
        end

        response
      end)

    :ok = Ecto.Adapters.SQL.Sandbox.checkout(NewYou.Repo, sandbox: false)

    try do
      NewYouWeb.Endpoint.call(conn, NewYouWeb.Endpoint.init([]))
    after
      :ok = Ecto.Adapters.SQL.Sandbox.checkin(NewYou.Repo)
    end
  end
end
