defmodule NewYou.Architecture.AshWriteBoundaryTest do
  # Pure AST tests: no database, no application start.
  use ExUnit.Case, async: true

  Code.require_file(Path.expand("../../../tools/architecture/ash_write_boundary.ex", __DIR__))

  alias NewYou.Architecture.AshWriteBoundary

  @app_path "lib/new_you/accounts.ex"
  @web_path "lib/new_you_web/controllers/profile_controller.ex"

  defp rules(source, path \\ @app_path) do
    source
    |> AshWriteBoundary.check_source(path)
    |> Enum.map(& &1.rule)
  end

  describe "negative fixtures: bypasses that must FAIL" do
    test "ordinary Repo business insert fails" do
      source = """
      defmodule NewYou.Accounts do
        def create(attrs), do: NewYou.Repo.insert(Ecto.Changeset.change(%{}, attrs))
      end
      """

      assert [%{rule: :repo_write, line: 2}] = AshWriteBoundary.check_source(source, @app_path)
    end

    test "aliased Repo update and delete_all fail" do
      source = """
      defmodule NewYou.Accounts do
        alias NewYou.Repo
        def touch(cs), do: cs |> Repo.update!()
        def purge(query), do: Repo.delete_all(query)
      end
      """

      assert [:repo_write, :repo_write] == rules(source)
    end

    test "raw mutating SQL fails" do
      source = """
      defmodule NewYou.Accounts do
        def hack, do: NewYou.Repo.query!("UPDATE accounts SET locked = true")
      end
      """

      assert [:raw_sql_write] == rules(source)
    end

    test "raw SQL writes through a Repo module variable fail" do
      source = """
      defmodule NewYou.Accounts do
        def hack do
          repo = NewYou.Repo
          repo.query!("UPDATE accounts SET locked = true", [])
        end
      end
      """

      assert [:raw_sql_write] == rules(source)
    end

    test "Repo writes through a module attribute fail" do
      source = """
      defmodule NewYou.Accounts do
        @repo NewYou.Repo

        def persist(changeset), do: @repo.insert(changeset)
      end
      """

      assert [:repo_write] == rules(source)
    end

    test "SELECT calls to unknown database functions fail closed" do
      for sql <- ["SELECT lock_account($1)", "SELECT lock_account /* gap */ ($1)"] do
        source = """
        defmodule NewYou.Accounts do
          def hack, do: NewYou.Repo.query!(#{inspect(sql)}, [1])
        end
        """

        assert [:raw_sql_write] == rules(source)
      end
    end

    test "ordinary SQL strings do not hide calls after a backslash" do
      sql = ~S|SELECT 'a\', nextval('accounts_seq')::text, 'x'|

      source = """
      defmodule NewYou.Accounts do
        def inspect_literal, do: NewYou.Repo.query!(#{inspect(sql)}, [])
      end
      """

      assert [:raw_sql_write] == rules(source)
    end

    test "non-ASCII SQL function calls fail closed" do
      source = """
      defmodule NewYou.Accounts do
        def read, do: NewYou.Repo.query!("SELECT функция_записи()", [])
      end
      """

      assert [:raw_sql_write] == rules(source)
    end

    test "SELECT INTO table writes fail" do
      source = """
      defmodule NewYou.Accounts do
        def archive, do: NewYou.Repo.query!("SELECT * INTO archived_accounts FROM accounts", [])
      end
      """

      assert [:raw_sql_write] == rules(source)
    end

    test "non-literal raw SQL fails closed" do
      source = """
      defmodule NewYou.Accounts do
        def run(sql), do: Ecto.Adapters.SQL.query!(NewYou.Repo, sql, [])
      end
      """

      assert [:raw_sql_write] == rules(source)
    end

    test "Ecto.Multi business write fails" do
      source = """
      defmodule NewYou.Accounts do
        def go(cs) do
          Ecto.Multi.new()
          |> Ecto.Multi.insert(:account, cs)
          |> NewYou.Repo.transaction()
        end
      end
      """

      assert :ecto_multi_write in rules(source)
    end

    test "Ecto.Multi.run fails because its callback receives the Repo" do
      source = """
      defmodule NewYou.Accounts do
        def persist(changeset) do
          Ecto.Multi.new()
          |> Ecto.Multi.run(:write, fn repo, _changes -> {:ok, repo.insert(changeset)} end)
        end
      end
      """

      assert [:ecto_multi_write] == rules(source)
    end

    test "imported Repo writes fail" do
      source = """
      defmodule NewYou.Accounts do
        import NewYou.Repo, only: [insert: 1]
        def persist(changeset), do: insert(changeset)
      end
      """

      assert [:repo_write] == rules(source)
    end

    test "imported raw SQL mutations fail" do
      source = """
      defmodule NewYou.Accounts do
        import NewYou.Repo, only: [query!: 2]
        def mutate, do: query!("UPDATE accounts SET locked = true", [])
      end
      """

      assert [:raw_sql_write] == rules(source)
    end

    test "imported Multi.run fails" do
      source = """
      defmodule NewYou.Accounts do
        import Ecto.Multi, only: [run: 3]
        def persist(changeset, multi), do: run(multi, :write, fn repo, _changes -> {:ok, repo.insert(changeset)} end)
      end
      """

      assert [:ecto_multi_write] == rules(source)
    end

    test "parallel Ecto business schema fails" do
      source = """
      defmodule NewYou.Accounts.User do
        use Ecto.Schema

        schema "users" do
          field :email, :string
        end
      end
      """

      assert [:parallel_ecto_schema] == rules(source)
    end

    test "controller direct write fails" do
      source = """
      defmodule NewYouWeb.ProfileController do
        def update(conn, params) do
          NewYou.Repo.update(Ecto.Changeset.change(%{}, params))
          conn
        end
      end
      """

      assert [%{rule: :repo_write, message: message}] =
               AshWriteBoundary.check_source(source, @web_path)

      assert message =~ "web layer"
    end

    test "worker direct delete fails" do
      source = """
      defmodule NewYou.Workers.Cleanup do
        def perform, do: NewYou.Repo.delete_all(Ecto.Query.from(t in "tokens"))
      end
      """

      assert [:repo_write] == rules(source, "lib/new_you/workers/cleanup.ex")
    end

    test "generic Ash mutations fail in controllers, LiveViews and workers" do
      for path <- [
            @web_path,
            "lib/new_you_web/live/profile_live.ex",
            "lib/new_you/workers/cleanup.ex",
            "lib/new_you/accounts/workers/cleanup.ex",
            "lib/new_you/jobs/cleanup.ex",
            "lib/new_you/accounts/cleanup_worker.ex",
            "lib/new_you/delivery/worker.ex"
          ],
          function <-
            ~w(create create! update update! destroy destroy! bulk_create bulk_create! bulk_update bulk_update! bulk_destroy bulk_destroy!) do
        source = "defmodule Outer do; def run(value), do: Ash.#{function}(value); end"
        assert [:outer_layer_ash_write] == rules(source, path)
      end
    end

    test "aliased Ash mutation in a worker fails" do
      source = """
      defmodule NewYou.Workers.Cleanup do
        alias Ash, as: Persistence
        def perform(value), do: value |> Persistence.destroy!()
      end
      """

      assert [:outer_layer_ash_write] == rules(source, "lib/new_you/workers/cleanup.ex")
    end

    test "imported Ash mutations fail in workers" do
      source = """
      defmodule NewYou.Workers.Cleanup do
        import Ash, only: [create!: 3, update!: 2, destroy!: 1]
        def create(attrs), do: create!(NewYou.Accounts.User, attrs, action: :register)
        def update(record), do: update!(record, %{})
        def destroy(record), do: destroy!(record)
      end
      """

      violations = AshWriteBoundary.check_source(source, "lib/new_you/delivery/worker.ex")

      assert Enum.count(violations, &(&1.rule == :outer_layer_ash_write)) == 3
    end

    test "an imported Ash action remains valid in its owning application module" do
      source = """
      defmodule NewYou.Accounts do
        import Ash, only: [create!: 3]
        def create(attrs), do: create!(NewYou.Accounts.User, attrs, action: :register)
      end
      """

      assert [] == rules(source)
    end

    test "unparseable governed file fails closed" do
      assert [:parse_error] == rules("defmodule Broken do def x(", @app_path)
    end
  end

  describe "positive fixtures: legitimate use that must PASS" do
    test "Ash domain action passes" do
      source = """
      defmodule NewYou.Accounts do
        def create(attrs), do: Ash.create!(NewYou.Accounts.Account, attrs, action: :register)
      end
      """

      assert [] == rules(source)
    end

    test "outer layers may call owning interfaces and generic Ash reads" do
      source = """
      defmodule Outer do
        import Ash, only: [read!: 1]
        def run(value) do
          NewYou.Accounts.register(value)
          read!(NewYou.Accounts.Account)
        end
      end
      """

      assert [] == rules(source, @web_path)
      assert [] == rules(source, "lib/new_you/workers/cleanup.ex")
    end

    test "ordinary Repo reads pass" do
      source = """
      defmodule NewYou.Accounts do
        alias NewYou.Repo
        def fetch(id), do: Repo.get(NewYou.Accounts.Account, id)
        def count(query), do: Repo.aggregate(query, :count)
      end
      """

      assert [] == rules(source)
    end

    test "approved read-only connectivity query passes" do
      source = """
      defmodule NewYou.Health do
        def ping, do: NewYou.Repo.query!("SELECT 1", [])
      end
      """

      assert [] == rules(source)
    end

    test "read-only Ecto SQL adapter query passes" do
      source = """
      defmodule NewYou.Health do
        def ping, do: Ecto.Adapters.SQL.query(NewYou.Repo, "SELECT 1", [])
      end
      """

      assert [] == rules(source)
    end

    test "SQL string contents do not look like SQL functions or comments" do
      for sql <- [
            "SELECT 'lock_account()'",
            "SELECT E'lock_account()'",
            "SELECT '-- /* update */'",
            "SELECT $$lock_account()$$",
            "SELECT $payload$lock_account() -- /* update */$payload$"
          ] do
        source = """
        defmodule NewYou.Health do
          def inspect_literal, do: NewYou.Repo.query!(#{inspect(sql)}, [])
        end
        """

        assert [] == rules(source)
      end
    end

    test "quoted SQL identifiers are not keywords or comments" do
      for sql <- ["SELECT 1 AS \"into\"", "SELECT 1 AS \"col--name\""] do
        source = """
        defmodule NewYou.Health do
          def inspect_identifier, do: NewYou.Repo.query!(#{inspect(sql)}, [])
        end
        """

        assert [] == rules(source)
      end
    end

    test "non-ASCII dollar quote tags are masked" do
      sql = "SELECT $тег$update$тег$"

      source = """
      defmodule NewYou.Health do
        def inspect_literal, do: NewYou.Repo.query!(#{inspect(sql)}, [])
      end
      """

      assert [] == rules(source)
    end

    test "imported read-only SQL passes" do
      source = """
      defmodule NewYou.Health do
        import NewYou.Repo, only: [query!: 2]
        def ping, do: query!("SELECT 1", [])
      end
      """

      assert [] == rules(source)
    end

    test "Repo module definition passes" do
      source = """
      defmodule NewYou.Repo do
        use Ecto.Repo, otp_app: :new_you, adapter: Ecto.Adapters.Postgres
        def mutate(cs), do: insert(cs)
      end
      """

      assert [] == rules(source, "lib/new_you/repo.ex")
    end

    test "migration SQL passes because migrations are out of scope" do
      source = """
      defmodule NewYou.Repo.Migrations.Seed do
        use Ecto.Migration
        def up, do: execute("INSERT INTO accounts (id) VALUES (1)")
      end
      """

      assert [] == rules(source, "priv/repo/migrations/20261022000000_seed.exs")
    end

    test "sandbox configuration in test support passes" do
      source = """
      Ecto.Adapters.SQL.Sandbox.mode(NewYou.Repo, :manual)
      """

      assert [] == rules(source, "test/test_helper.exs")
      assert [] == rules(source, "lib/new_you/sandbox_probe.ex")
    end
  end

  test "the real application tree satisfies the boundary" do
    root = Path.expand("../../..", __DIR__)
    assert [] == AshWriteBoundary.check_app(root)
  end
end
