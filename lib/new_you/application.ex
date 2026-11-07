defmodule NewYou.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @magic_login_enabled Mix.env() in [:dev, :test] and
                         Application.compile_env(
                           :new_you,
                           :verification_development_fixtures,
                           false
                         )

  @impl true
  def start(_type, _args) do
    children =
      [
        NewYouWeb.Telemetry,
        NewYou.Repo,
        {Oban,
         AshOban.config(
           Application.fetch_env!(:new_you, :ash_domains),
           Application.fetch_env!(:new_you, Oban)
         )},
        {DNSCluster, query: Application.get_env(:new_you, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: NewYou.PubSub}
      ] ++
        identity_children() ++
        magic_login_children() ++
        [
          # Start a worker by calling: NewYou.Worker.start_link(arg)
          # {NewYou.Worker, arg},
          # Start to serve requests, typically the last entry
          NewYouWeb.Endpoint,
          {AshAuthentication.Supervisor, [otp_app: :new_you]}
        ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: NewYou.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp identity_children do
    if Application.get_env(:new_you, :identity_registration_expiry_enabled, true) do
      [NewYou.Identity.RegistrationOperationExpiry]
    else
      []
    end
  end

  if @magic_login_enabled do
    defp magic_login_children do
      [{Task.Supervisor, name: NewYou.Identity.MagicLogin.RequestSupervisor, max_children: 32}]
    end
  else
    defp magic_login_children, do: []
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    NewYouWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
