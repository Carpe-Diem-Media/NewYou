defmodule NewYou.Proof.FaultInjectionTest do
  use ExUnit.Case, async: false
  alias Ecto.Adapters.SQL.Sandbox
  alias NewYou.Repo
  alias NewYou.Proof.P805

  test "insertion cuts restore prior connection state and remove only owned DDL" do
    Sandbox.unboxed_run(Repo, fn ->
      previous = setting()
      sentinel = "outer_" <> Ecto.UUID.generate()
      Repo.query!("SELECT set_config('newyou.proof_cut', $1, false)", [sentinel])

      try do
        for outcome <- [:return, :raise, :throw, :exit] do
          run = fn ->
            P805.with_rejected_insert("oban_jobs", fn reached ->
              name = setting()
              send(self(), {:owned_cut, name})
              assert name =~ ~r/^p805_fault_[a-f0-9]{32}$/
              assert ddl_counts(name) == [1, 1, 1]
              refute reached.()

              case outcome do
                :return -> :ok
                :raise -> raise "proof interrupted"
                :throw -> throw(:proof_cancelled)
                :exit -> exit(:proof_terminated)
              end
            end)
          end

          case outcome do
            :return -> assert run.() == :ok
            :raise -> assert_raise RuntimeError, "proof interrupted", run
            :throw -> assert catch_throw(run.()) == :proof_cancelled
            :exit -> assert catch_exit(run.()) == :proof_terminated
          end

          assert_receive {:owned_cut, name}
          assert setting() == sentinel
          assert ddl_counts(name) == [0, 0, 0]
        end
      after
        Repo.query!("SELECT set_config('newyou.proof_cut', $1, false)", [previous || ""])
      end
    end)
  end

  test "nested insertion cuts preserve the outer cut and its reached evidence" do
    Sandbox.unboxed_run(Repo, fn ->
      P805.with_rejected_insert("oban_jobs", fn outer_reached ->
        outer = setting()

        P805.with_rejected_insert("oban_jobs", fn inner_reached ->
          inner = setting()
          refute inner == outer
          assert ddl_counts(outer) == [1, 1, 1]
          assert ddl_counts(inner) == [1, 1, 1]

          assert {:error, %Postgrex.Error{postgres: %{code: :check_violation}}} =
                   reject_job()

          assert inner_reached.()
          refute outer_reached.()
        end)

        assert setting() == outer
        assert ddl_counts(outer) == [1, 1, 1]
        assert {:error, %Postgrex.Error{postgres: %{code: :check_violation}}} = reject_job()
        assert outer_reached.()
      end)
    end)
  end

  test "killed proof connection removes its temporary fault dependency" do
    Sandbox.unboxed_run(Repo, fn ->
      owner = self()
      reference = make_ref()

      {worker, monitor} =
        spawn_monitor(fn ->
          Sandbox.unboxed_run(Repo, fn ->
            P805.with_rejected_insert("oban_jobs", fn _reached ->
              send(owner, {reference, setting()})
              receive do: (:release -> :ok)
            end)
          end)
        end)

      assert_receive {^reference, name}, 5_000

      try do
        assert P805.scalar("SELECT count(*) FROM pg_trigger WHERE tgname = $1", [name]) == 1
        Process.exit(worker, :kill)
        assert_receive {:DOWN, ^monitor, :process, ^worker, :killed}, 5_000
        assert trigger_removed?(name, System.monotonic_time(:millisecond) + 5_000)
      after
        if Process.alive?(worker), do: send(worker, :release)
      end
    end)
  end

  defp reject_job() do
    Repo.query(
      "INSERT INTO oban_jobs (queue, worker, args) VALUES ('audit', 'test-only-cut', '{}') RETURNING id"
    )
  end

  defp setting, do: P805.scalar("SELECT current_setting('newyou.proof_cut', true)")

  defp ddl_counts(name) do
    [
      P805.scalar("SELECT count(*) FROM pg_trigger WHERE tgname = $1", [name]),
      P805.scalar(
        "SELECT count(*) FROM pg_proc WHERE proname = $1 AND pronamespace = pg_my_temp_schema()",
        [name]
      ),
      P805.scalar(
        "SELECT count(*) FROM pg_class WHERE relname = $1 AND relnamespace = pg_my_temp_schema()",
        [name]
      )
    ]
  end

  defp trigger_removed?(name, deadline) do
    cond do
      P805.scalar("SELECT count(*) FROM pg_trigger WHERE tgname = $1", [name]) == 0 ->
        true

      System.monotonic_time(:millisecond) >= deadline ->
        false

      true ->
        Process.sleep(10)
        trigger_removed?(name, deadline)
    end
  end
end
