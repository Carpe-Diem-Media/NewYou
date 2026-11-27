alias Ecto.Adapters.SQL.Sandbox
alias NewYou.Commerce.FixtureDispute
alias NewYou.Repo

%{"id" => id} = IO.gets("") |> Jason.decode!()
:ok = Sandbox.checkout(Repo, sandbox: false)
IO.puts("P815_STARTED")

try do
  %FixtureDispute{} = Ash.get!(FixtureDispute, id, authorize?: false)
  IO.puts("P815_OPERATION")

  %{success: reads, failure: 0, discard: 0, queues_not_drained: []} =
    AshOban.Test.schedule_and_run_triggers({FixtureDispute, :read_due})

  true = reads > 0
  %{state: :restored} = Ash.get!(FixtureDispute, id, authorize?: false)
  IO.puts("P815_CHECKPOINT")

  %{success: effects, failure: 0, discard: 0, queues_not_drained: []} =
    AshOban.Test.schedule_and_run_triggers({FixtureDispute, :deliver})

  true = effects > 0

  %{state: :restored, effect_version: version, acknowledged_version: version} =
    Ash.get!(FixtureDispute, id, authorize?: false)

  IO.puts("WELL223_COMPLETED")
after
  Sandbox.checkin(Repo)
end
