defmodule NewYou.LocalConfigTest do
  use ExUnit.Case, async: true

  alias NewYou.LocalConfig

  defp environment(overrides \\ %{}) do
    values =
      Map.merge(
        %{
          "DEV_DATABASE_HOST" => "127.0.0.1",
          "DEV_DATABASE_PORT" => "55432",
          "DEV_DATABASE_USERNAME" => "new_you_dev",
          "DEV_DATABASE_NAME" => "new_you_dev",
          "DEV_DATABASE_PASSWORD" => "dev-test-placeholder",
          "TEST_DATABASE_HOST" => "127.0.0.1",
          "TEST_DATABASE_PORT" => "55433",
          "TEST_DATABASE_USERNAME" => "new_you_test",
          "TEST_DATABASE_NAME" => "new_you_test",
          "TEST_DATABASE_PASSWORD" => "test-placeholder"
        },
        overrides
      )

    &Map.get(values, &1)
  end

  test "DEV and TEST have distinct deterministic database targets" do
    dev = LocalConfig.repo(:dev, environment(), managed_required?: false)
    test = LocalConfig.repo(:test, environment(), managed_required?: false)

    assert {dev[:hostname], dev[:port], dev[:username], dev[:database]} ==
             {"127.0.0.1", 55432, "new_you_dev", "new_you_dev"}

    assert {test[:hostname], test[:port], test[:username], test[:database]} ==
             {"127.0.0.1", 55433, "new_you_test", "new_you_test"}

    refute test[:password] == dev[:password]
  end

  test "TEST rejects DEV endpoint, role, or database even when credentials exist" do
    for {key, value} <- [
          {"TEST_DATABASE_PORT", "55432"},
          {"TEST_DATABASE_HOST", "localhost"},
          {"TEST_DATABASE_USERNAME", "new_you_dev"},
          {"TEST_DATABASE_NAME", "new_you_dev"}
        ] do
      assert_raise ArgumentError, ~r/DevCore contract/, fn ->
        LocalConfig.repo(:test, environment(%{key => value}), managed_required?: false)
      end
    end
  end

  test "missing TEST credentials never fall back to DEV or DATABASE_URL" do
    env =
      environment(%{
        "TEST_DATABASE_PASSWORD" => nil,
        "DATABASE_URL" => "ecto://new_you_dev:placeholder@127.0.0.1:55432/new_you_dev"
      })

    assert_raise ArgumentError, ~r/TEST_DATABASE_PASSWORD.*devcore-project/, fn ->
      LocalConfig.repo(:test, env, managed_required?: false)
    end
  end

  test "empty credentials and test partitions fail closed" do
    assert_raise ArgumentError, fn ->
      LocalConfig.repo(:test, environment(%{"TEST_DATABASE_PASSWORD" => ""}),
        managed_required?: false
      )
    end

    assert_raise ArgumentError, ~r/MIX_TEST_PARTITION/, fn ->
      LocalConfig.repo(:test, environment(%{"MIX_TEST_PARTITION" => "1"}),
        managed_required?: false
      )
    end
  end

  test "primary checkout uses only 4220" do
    assert LocalConfig.port(false, nil, environment(), managed_required?: false) == 4220
    assert LocalConfig.port(false, "4220", environment(), managed_required?: false) == 4220

    assert_raise ArgumentError, fn ->
      LocalConfig.port(false, "4221", environment(), managed_required?: false)
    end
  end

  test "worktree requires an explicit port in 4221 through 4239" do
    for port <- 4221..4239 do
      assert LocalConfig.port(true, Integer.to_string(port), environment(),
               managed_required?: false
             ) == port
    end

    for port <- [nil, "", "4220", "4240", "4221oops"] do
      assert_raise ArgumentError, fn ->
        LocalConfig.port(true, port, environment(), managed_required?: false)
      end
    end
  end

  defp managed_context(overrides \\ %{}) do
    lease = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    generation = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    database = "dc_new_you_s20_gbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

    markers = %{
      "DEVCORE_SLOT_PROJECT" => "new_you",
      "DEVCORE_SLOT_LEASE" => lease,
      "DEVCORE_SLOT_GENERATION" => generation,
      "DEVCORE_SLOT_JOB" => "cccccccccccccccccccccccccccccccc",
      "DEVCORE_SLOT_WORKTREE" => "/tmp/newyou-managed-worktree",
      "NEW_YOU_PORT" => "4240",
      "TEST_DATABASE_NAME" => database,
      "TEST_DATABASE_USERNAME" => database <> "_r"
    }

    receipt = %{
      "project" => "new_you",
      "slot" => 20,
      "port" => 4240,
      "lease_id" => lease,
      "generation" => generation,
      "worktree" => "/tmp/newyou-managed-worktree",
      "database" => database,
      "role" => database <> "_r",
      "test_host" => "127.0.0.1",
      "test_port" => 55433,
      "profile" => "test"
    }

    {environment(Map.merge(markers, overrides)), receipt}
  end

  test "a verified managed job selects its isolated TEST identity and slot 20 port" do
    {env, receipt} = managed_context()
    verify = fn _markers -> {:ok, receipt} end

    repo = LocalConfig.repo(:test, env, verify: verify)
    assert repo[:database] == "dc_new_you_s20_gbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    assert repo[:username] == "dc_new_you_s20_gbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb_r"
    assert {repo[:hostname], repo[:port]} == {"127.0.0.1", 55433}
    assert LocalConfig.port(true, "4240", env, verify: verify) == 4240

    assert_raise ArgumentError, fn ->
      LocalConfig.port(true, "4239", env, verify: verify)
    end
  end

  test "managed endpoint and generation substitutions reject without exposing credentials" do
    for {key, value} <- [
          {"TEST_DATABASE_HOST", "localhost"},
          {"TEST_DATABASE_PORT", "55432"},
          {"TEST_DATABASE_NAME", "new_you_test"},
          {"TEST_DATABASE_USERNAME", "new_you_dev"},
          {"DEVCORE_SLOT_GENERATION", "dddddddddddddddddddddddddddddddd"},
          {"NEW_YOU_PORT", "4239"}
        ] do
      {env, receipt} = managed_context(%{key => value})

      error =
        assert_raise ArgumentError, fn ->
          LocalConfig.repo(:test, env, verify: fn _ -> {:ok, receipt} end)
        end

      refute Exception.message(error) =~ "test-placeholder"
    end
  end

  test "every configured slot binds its exact port and generation identity" do
    {base_env, base_receipt} = managed_context()

    for slot <- 1..20 do
      database =
        "dc_new_you_s" <>
          String.pad_leading(Integer.to_string(slot), 2, "0") <>
          "_g" <> base_receipt["generation"]

      port = 4220 + slot

      receipt =
        Map.merge(base_receipt, %{
          "slot" => slot,
          "port" => port,
          "database" => database,
          "role" => database <> "_r"
        })

      binding = %{
        "NEW_YOU_PORT" => Integer.to_string(port),
        "TEST_DATABASE_NAME" => database,
        "TEST_DATABASE_USERNAME" => database <> "_r"
      }

      env = fn key -> Map.get(binding, key, base_env.(key)) end
      verify = fn _ -> {:ok, receipt} end

      assert LocalConfig.repo(:test, env, verify: verify)[:database] == database
      assert LocalConfig.port(true, Integer.to_string(port), env, verify: verify) == port
    end
  end

  test "partial markers cannot fall back to valid legacy credentials" do
    env = environment(%{"DEVCORE_SLOT_JOB" => "cccccccccccccccccccccccccccccccc"})

    assert_raise ArgumentError, ~r/managed/, fn ->
      LocalConfig.repo(:test, env)
    end
  end

  test "declared managed mode rejects a marker-free old executable environment" do
    assert_raise ArgumentError, ~r/managed/, fn ->
      LocalConfig.repo(:test, environment(), managed_required?: true)
    end
  end

  test "unavailable or stale live verification never falls back to shared TEST" do
    {env, _receipt} = managed_context()

    for result <- [:error, {:ok, %{}}, {:ok, nil}] do
      assert_raise ArgumentError, ~r/managed/, fn ->
        LocalConfig.repo(:test, env, verify: fn _ -> result end)
      end
    end
  end

  test "a TEST-origin job cannot select shared DEV, while a DEV-origin job can use TEST" do
    {env, receipt} = managed_context()

    assert_raise ArgumentError, ~r/managed/, fn ->
      LocalConfig.repo(:dev, env, verify: fn _ -> {:ok, receipt} end)
    end

    verify = fn _ -> {:ok, %{receipt | "profile" => "dev"}} end
    assert LocalConfig.repo(:dev, env, verify: verify)[:database] == "new_you_dev"

    assert LocalConfig.repo(:test, env, verify: verify)[:database] ==
             "dc_new_you_s20_gbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  end

  test "each complete marker is verified and every partial combination rejects" do
    {env, receipt} = managed_context()

    for key <- ~w(PROJECT LEASE GENERATION JOB WORKTREE) do
      marker = "DEVCORE_SLOT_" <> key
      {incomplete, _receipt} = managed_context(%{marker => nil})

      assert_raise ArgumentError, ~r/managed/, fn ->
        LocalConfig.repo(:test, incomplete,
          verify: fn _ -> flunk("partial context reached verification") end
        )
      end
    end

    verify = fn markers ->
      assert markers["DEVCORE_SLOT_PROJECT"] == "new_you"
      assert markers["DEVCORE_SLOT_LEASE"] == "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      assert markers["DEVCORE_SLOT_GENERATION"] == "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
      assert markers["DEVCORE_SLOT_JOB"] == "cccccccccccccccccccccccccccccccc"
      assert markers["DEVCORE_SLOT_WORKTREE"] == "/tmp/newyou-managed-worktree"
      {:ok, receipt}
    end

    assert LocalConfig.repo(:test, env, verify: verify)[:database] == receipt["database"]
  end

  test "a verifier response must bind all identities and the exact bounded slot" do
    {env, receipt} = managed_context()

    for {key, value} <- [
          {"project", "other_project"},
          {"slot", 0},
          {"slot", 21},
          {"slot", "20"},
          {"port", 4239},
          {"test_host", "localhost"},
          {"test_port", 55432},
          {"database", "new_you_test"},
          {"role", "new_you_dev"},
          {"lease_id", "dddddddddddddddddddddddddddddddd"},
          {"generation", "dddddddddddddddddddddddddddddddd"},
          {"worktree", "/tmp/another-worktree"},
          {"profile", "all"}
        ] do
      verify = fn _ -> {:ok, Map.put(receipt, key, value)} end

      assert_raise ArgumentError, ~r/managed/, fn ->
        LocalConfig.repo(:test, env, verify: verify)
      end
    end
  end

  test "forged markers alone cannot satisfy the installed live verifier" do
    {env, _receipt} = managed_context()

    error = assert_raise ArgumentError, ~r/managed/, fn -> LocalConfig.repo(:test, env) end
    refute Exception.message(error) =~ "test-placeholder"
  end

  test "declared opt-in rejects a marker-free environment by default" do
    assert_raise ArgumentError, ~r/managed/, fn -> LocalConfig.repo(:test, environment()) end
  end

  test "CI flags cannot select workstation shared TEST in an opted-in worktree" do
    shared =
      environment(%{"NEW_YOU_DATABASE_MODE" => "ci", "GITHUB_ACTIONS" => "true", "CI" => "true"})

    assert_raise ArgumentError, fn -> LocalConfig.repo(:test, shared) end
  end

  test "CI accepts only its distinct ephemeral database and role" do
    ci =
      environment(%{
        "NEW_YOU_DATABASE_MODE" => "ci",
        "GITHUB_ACTIONS" => "true",
        "CI" => "true",
        "TEST_DATABASE_NAME" => "new_you_ci_test",
        "TEST_DATABASE_USERNAME" => "new_you_ci_test"
      })

    assert LocalConfig.repo(:test, ci)[:database] == "new_you_ci_test"
    assert LocalConfig.repo(:test, ci)[:username] == "new_you_ci_test"

    assert_raise ArgumentError, ~r/managed/, fn -> LocalConfig.repo(:dev, ci) end

    for {key, value} <- [
          {"TEST_DATABASE_HOST", "localhost"},
          {"TEST_DATABASE_PORT", "55432"},
          {"TEST_DATABASE_NAME", "new_you_test"},
          {"TEST_DATABASE_USERNAME", "new_you_test"}
        ] do
      env = fn name -> if name == key, do: value, else: ci.(name) end
      assert_raise ArgumentError, fn -> LocalConfig.repo(:test, env) end
    end

    partial =
      environment(%{
        "NEW_YOU_DATABASE_MODE" => "ci",
        "GITHUB_ACTIONS" => "true",
        "CI" => "true",
        "TEST_DATABASE_NAME" => "new_you_ci_test",
        "TEST_DATABASE_USERNAME" => "new_you_ci_test",
        "DEVCORE_SLOT_JOB" => "cccccccccccccccccccccccccccccccc"
      })

    assert_raise ArgumentError, ~r/managed/, fn -> LocalConfig.repo(:test, partial) end

    for overrides <- [
          %{"NEW_YOU_DATABASE_MODE" => "ci"},
          %{"NEW_YOU_DATABASE_MODE" => "legacy"},
          %{"NEW_YOU_DATABASE_MODE" => "ci", "GITHUB_ACTIONS" => "true"}
        ] do
      assert_raise ArgumentError, ~r/managed/, fn ->
        LocalConfig.repo(:test, environment(overrides))
      end
    end
  end
end
