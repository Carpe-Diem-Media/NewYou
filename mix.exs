defmodule NewYou.MixProject do
  use Mix.Project

  def project do
    [
      app: :new_you,
      version: "0.1.0",
      elixir: "~> 1.20.4",
      elixirc_paths: elixirc_paths(Mix.env()),
      # This proof helper is compiled through test/support, not an ExUnit test.
      test_load_filters: [
        fn path ->
          String.ends_with?(path, "_test.exs") and path != "test/proof/self_test.exs"
        end
      ],
      test_ignore_filters: [
        ~r"^test/proof/(self_test|run|postgresql_probe|p8_09_restart|p8_09_magic_restart|p8_10_restart|p8_11_restart|fixtures/provider_fixtures)\.exs$"
      ],
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader],
      consolidate_protocols: Mix.env() != :dev,
      usage_rules: usage_rules(),
      dialyzer: dialyzer()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {NewYou.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [check: :test, "check.deep": :test]
    ]
  end

  # UsageRules runs in skills-only mode: it generates framework and dependency
  # skills under .agents/skills and never writes AGENTS.md (no `file:` key).
  # Regenerate with `mix usage_rules.sync`; verify with `mix usage_rules.sync --check`.
  defp usage_rules do
    [
      skills: [
        location: ".agents/skills",
        deps: [:igniter],
        build: [
          "elixir-otp": [
            description:
              "Use when writing or reviewing Elixir or OTP code: pattern matching, processes, GenServer, supervision, and idiomatic Elixir style.",
            usage_rules: [:elixir, :otp]
          ],
          # Explicit dependency lists, not regexes: a regex would pull in
          # dev-only or test-only packages and make the output depend on the
          # Mix environment that ran the sync.
          "ash-framework": [
            description:
              "Use when working with Ash resources, domains, actions, changes, policies, data layers, or AshPostgres.",
            usage_rules: [:ash, :ash_postgres, :ash_authentication]
          ],
          "phoenix-framework": [
            description:
              "Use when working with Phoenix controllers, routers, LiveViews, components, endpoints, or Phoenix.Ecto and Phoenix.HTML helpers.",
            usage_rules: [:phoenix]
          ]
        ]
      ]
    ]
  end

  defp dialyzer do
    [
      plt_local_path: "_build/plts",
      plt_core_path: "_build/plts",
      plt_add_apps: [:mix, :ex_unit]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:ash_cloak, "== 0.4.0"},
      {:nimble_totp, "== 1.0.0"},
      {:ash_state_machine, "== 0.3.0"},
      {:oban, "== 2.24.2"},
      {:ash_oban, "== 0.10.2"},
      {:argon2_elixir, "== 4.1.3"},
      {:picosat_elixir, "~> 0.2"},
      {:ash_authentication, "== 4.15.1"},
      {:tidewave, "== 0.9.2", only: [:dev]},
      {:ash_postgres, "== 2.15.2"},
      {:ash, "== 3.37.2"},
      # Reactor >= 1.0.2 requires prerelease multigraph; keep the dependency tree stable.
      {:reactor, "== 1.0.1"},
      {:igniter, "~> 0.8.4", only: [:dev, :test]},
      {:usage_rules, "== 1.2.8", only: [:dev, :test], runtime: false},
      {:credo, "== 1.7.19", only: [:dev, :test], runtime: false},
      {:sobelow, "== 0.16.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "== 1.4.8", only: [:dev, :test], runtime: false},
      {:phoenix, "~> 1.8.16"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "== 4.4.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.2.0"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.5", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:daisyui,
       github: "saadeghi/daisyui",
       tag: "v5.5.20",
       sparse: "packages/bundle",
       app: false,
       compile: false,
       depth: 1},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2.0"},
      {:bandit, "~> 1.5"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.migrate", "assets.setup", "assets.build"],
      test: ["ecto.migrate --quiet", "test --warnings-as-errors"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["compile", "tailwind new_you", "esbuild new_you"],
      "assets.deploy": [
        "tailwind new_you --minify",
        "esbuild new_you --minify",
        "phx.digest"
      ],
      # Fast, blocking, fail-fast gate ordered cheapest and highest-signal first.
      # Historical Foundation Full is never part of this alias.
      check: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "design.check",
        "check.architecture",
        "usage_rules.sync --check",
        "credo --strict",
        "sobelow --exit --skip --private --strict --router lib/new_you_web/router.ex",
        "test"
      ],
      # Slower engineering gate. Dialyzer owns its PLT build and caching.
      "check.deep": ["dialyzer --format dialyxir"],
      "check.architecture": ["run --no-start tools/architecture/check_ash_writes.exs"]
    ]
  end
end
