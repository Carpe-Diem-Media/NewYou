defmodule NewYou.Proof.EntryJourney do
  @moduledoc false
  import ExUnit.Assertions
  alias NewYou.{Audit, Identity, Repo}
  alias NewYou.Proof.{P805, P805Browser, P819Browser, SelfTest}
  require Ash.Query

  @terms "NEWYOU-TERMS-EN-DEV-2026-10-27-001"
  @privacy "NEWYOU-PRIVACY-EN-DEV-2026-10-27-001"
  @browser_checks ~w(root_entry locale_switch approved_copy required_form legal_artifacts submitted_acceptances pending_copy explicit_resend locale_no_fallback no_session explicit_verification verified_result safe_replay return_locale responsive reduced_motion stylesheet_loaded associated_labels keyboard_focus validation_errors protected_access_denied)

  def run(locale) when locale in ["en", "af"] do
    Mix.Task.run("assets.build")

    P805.with_fixture(fn ->
      input = P805.request(%{preferred_language: String.to_existing_atom(locale)})
      previous = save_flags()
      enable_entry_only()
      reference = make_ref()
      Process.put({__MODULE__, reference}, false)

      {:ok, server} =
        Bandit.start_link(
          plug: {__MODULE__.Endpoint, {self(), reference}},
          ip: {127, 0, 0, 1},
          port: 0
        )

      {:ok, {_address, port}} = ThousandIsland.listener_info(server)

      try do
        payload =
          Jason.encode!(%{
            mode: "entry",
            port: port,
            locale: locale,
            input: input,
            platform_name: NewYou.platform_name()
          })

        executable = System.find_executable("node") || raise "entry browser requires Node"
        script = Path.expand("../proof/p8_05_browser.mjs", __DIR__)
        result = P805Browser.run_port(executable, script, payload)
        Process.put({__MODULE__, reference}, result["cleanup"] == true)
        Enum.each(result["operations"] || [], &P805.track_operation/1)
        assert_journey(result, reference, input)
      after
        Supervisor.stop(server)
        browser_stopped? = Process.delete({__MODULE__, reference}) == true
        restore_flags(previous)

        SelfTest.cleanup_manifest!(
          workers_stopped: not Process.alive?(server) and browser_stopped?
        )
      end
    end)
  end

  defp assert_journey(result, reference, input) do
    assert result["cleanup"] == true
    checks = result["checks"] || %{}
    observations = session_observations(reference, [])
    assert observations != []
    assert Enum.all?(observations, & &1)

    for check <- @browser_checks do
      assert checks[check] == true, "entry journey obligation failed: #{check}"
    end

    assert_accepted_account!(result["operations"], input)
  end

  defp assert_accepted_account!([registration_operation | _], input) do
    [operation] = P805.registration_operations(registration_operation)
    account = P805.account!(operation.created_account_id)

    [obligation] =
      Audit.EvidenceObligation
      |> Ash.Query.filter(source_operation_id == ^registration_operation)
      |> Ash.read!(domain: Audit, authorize?: false)

    accounts_with_email =
      Identity.Account
      |> Ash.Query.filter(email == ^input.email)
      |> Ash.read!(domain: Identity, authorize?: false)

    sessions =
      Identity.Session
      |> Ash.Query.filter(account_id == ^account.id)
      |> Ash.read!(domain: Identity, authorize?: false)

    assert account.preferred_language == input.preferred_language
    assert account.acceptance_locale == input.preferred_language
    assert account.terms_version_id == @terms
    assert account.privacy_version_id == @privacy
    assert account.confirmed_age_18?
    assert match?(%DateTime{}, account.legal_accepted_at)
    assert Identity.PMR.valid?(account.pmr)
    assert account.email_verified?
    assert obligation.source_operation_id == registration_operation
    assert obligation.evidence_type == :account_registration_pmr_assignment
    assert length(accounts_with_email) == 1
    assert sessions == []
  end

  defp save_flags do
    keys = [
      :fp001_development_entry,
      :p8_05_browser_development_fixtures,
      :p8_07_browser_development_fixtures
    ]

    Map.new(keys, &{&1, Application.fetch_env(:new_you, &1)})
  end

  defp enable_entry_only do
    Application.put_env(:new_you, :fp001_development_entry, true)
    Application.put_env(:new_you, :p8_05_browser_development_fixtures, false)
    Application.put_env(:new_you, :p8_07_browser_development_fixtures, false)
  end

  defp restore_flags(flags) do
    Enum.each(flags, fn
      {key, {:ok, value}} -> Application.put_env(:new_you, key, value)
      {key, :error} -> Application.delete_env(:new_you, key)
    end)
  end

  defp session_observations(reference, observations) do
    receive do
      {^reference, :session_safe, safe} -> session_observations(reference, [safe | observations])
    after
      0 -> observations
    end
  end

  defmodule Endpoint do
    @moduledoc false
    @behaviour Plug
    @impl Plug
    def init(options), do: options

    @impl Plug
    def call(%{request_path: "/__proof/delivery"} = conn, _observer),
      do: P819Browser.Endpoint.call(conn, [])

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

      :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo, sandbox: false)

      try do
        NewYouWeb.Endpoint.call(conn, NewYouWeb.Endpoint.init([]))
      after
        :ok = Ecto.Adapters.SQL.Sandbox.checkin(Repo)
      end
    end
  end
end
