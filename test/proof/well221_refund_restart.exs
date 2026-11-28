alias Ecto.Adapters.SQL.Sandbox
alias NewYou.Repo
alias NewYou.Commerce.FixtureRefund

%{"refund_id" => id, "phase" => phase} = IO.gets("") |> Jason.decode!()
:ok = Sandbox.checkout(Repo, sandbox: false)

try do
  trigger =
    case phase do
      "read" -> :read_due
      "acknowledge" -> :deliver
    end

  %{success: success, failure: 0, discard: 0, queues_not_drained: []} =
    AshOban.Test.schedule_and_run_triggers({FixtureRefund, trigger})

  true = success > 0
  %{state: :processed} = Ash.get!(FixtureRefund, id, authorize?: false)
  IO.puts("WELL221_COMPLETED")
after
  Sandbox.checkin(Repo)
end
