defmodule NewYou.BootstrapTest do
  use NewYou.DataCase, async: true

  test "the OTP application and its one repo start" do
    assert {:new_you, _, _} = List.keyfind(Application.started_applications(), :new_you, 0)
    assert Process.whereis(NewYou.Supervisor)
    assert Process.whereis(NewYou.Repo)

    assert {Oban, oban_pid, :supervisor, [Oban]} =
             List.keyfind(Supervisor.which_children(NewYou.Supervisor), Oban, 0)

    assert is_pid(oban_pid)
    assert Application.fetch_env!(:new_you, :ecto_repos) == [NewYou.Repo]

    assert Application.fetch_env!(:new_you, :ash_domains) == [
             NewYou.Communications,
             NewYou.Identity,
             NewYou.Audit,
             NewYou.Privacy
           ]
  end

  test "the real connection uses the TEST cluster, role and database without CREATEDB" do
    assert Mix.env() == :test
    config = NewYou.Repo.config()

    assert {config[:hostname], config[:port], config[:username], config[:database]} ==
             {"127.0.0.1", 55433, "new_you_test", "new_you_test"}

    refute config[:url]

    result =
      Ecto.Adapters.SQL.query!(
        NewYou.Repo,
        """
        SELECT current_database(), current_user, inet_server_port(), rolcreatedb, rolsuper,
               rolcreaterole, rolreplication, rolbypassrls
        FROM pg_roles WHERE rolname = current_user
        """,
        []
      )

    assert result.rows == [
             ["new_you_test", "new_you_test", 5432, false, false, false, false, false]
           ]
  end

  test "the generated Ash functions migration has been applied" do
    result =
      Ecto.Adapters.SQL.query!(
        NewYou.Repo,
        "SELECT ash_elixir_or(NULL::boolean, true), version FROM schema_migrations WHERE version = 20261022104847",
        []
      )

    assert result.rows == [[true, 20_261_022_104_847]]
  end

  test "tests do not serve Tidewave or start an HTTP listener" do
    refute NewYouWeb.Endpoint.config(:server)
    refute Code.ensure_loaded?(Tidewave)
    conn = Phoenix.ConnTest.build_conn() |> NewYouWeb.Endpoint.call([])
    assert conn.status == 200
  end
end
