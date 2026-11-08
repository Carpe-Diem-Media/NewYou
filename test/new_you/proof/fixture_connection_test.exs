defmodule NewYou.Proof.FixtureConnectionTest do
  use ExUnit.Case, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias NewYou.{Identity, Repo}
  alias NewYou.Proof.P805
  import ExUnit.CaptureLog

  test "fixture teardown survives a borrowed connection being disconnected" do
    capture_log(fn ->
      assert :callback_completed =
               P805.with_fixture(fn ->
                 guardian = Process.get({P805, :guardian})

                 on_exit(fn ->
                   monitor = Process.monitor(guardian)

                   receive do
                     {:DOWN, ^monitor, :process, ^guardian, reason}
                     when reason in [:normal, :noproc] ->
                       :ok
                   after
                     5_000 -> flunk("fixture guardian did not finish recovery")
                   end
                 end)

                 input = P805.request()
                 {:ok, registration} = Identity.register(input)
                 Process.put(:disconnected_fixture_account, registration.account_id)

                 task =
                   Task.Supervisor.async_nolink(
                     NewYou.Identity.MagicLogin.RequestSupervisor,
                     fn -> Repo.query!("SELECT pg_sleep(1)", [], timeout: 25) end
                   )

                 assert {:exit, _reason} = Task.yield(task, 2_000)
                 :callback_completed
               end)
    end)

    account_id = Process.delete(:disconnected_fixture_account)

    Sandbox.unboxed_run(Repo, fn ->
      assert P805.scalar("SELECT count(*) FROM accounts WHERE id = $1", [
               Ecto.UUID.dump!(account_id)
             ]) == 0
    end)
  end
end
