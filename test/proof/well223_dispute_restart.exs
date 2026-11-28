alias Ecto.Adapters.SQL.Sandbox
alias NewYou.Commerce.{FixtureDispute, FixtureDisputeReceipt}
alias NewYou.Repo

%{"id" => id} = payload = IO.gets("") |> Jason.decode!()
terminal = if payload["terminal"] == "lost", do: :lost, else: :restored
effect_only? = payload["phase"] == "effect"
:ok = Sandbox.checkout(Repo, sandbox: false)
IO.puts("P815_STARTED")

try do
  IO.puts("P815_OPERATION")

  if payload["phase"] == "receipt" do
    %{state: :pending, source: :webhook} =
      Ash.get!(FixtureDisputeReceipt, id, authorize?: false)

    %{success: processed, failure: 0, discard: 0, queues_not_drained: []} =
      AshOban.Test.schedule_and_run_triggers({FixtureDisputeReceipt, :process})

    IO.puts("P815_CHECKPOINT")
    true = processed >= 2
    %{state: :applied} = Ash.get!(FixtureDisputeReceipt, id, authorize?: false)
  else
    %FixtureDispute{} = Ash.get!(FixtureDispute, id, authorize?: false)

    unless effect_only? do
      %{success: reads, failure: 0, discard: 0, queues_not_drained: []} =
        AshOban.Test.schedule_and_run_triggers({FixtureDispute, :read_due})

      true = reads > 0
    end

    %{state: ^terminal} = Ash.get!(FixtureDispute, id, authorize?: false)

    %{success: effects, failure: 0, discard: 0, queues_not_drained: []} =
      AshOban.Test.schedule_and_run_triggers({FixtureDispute, :deliver})

    IO.puts("P815_CHECKPOINT")
    true = if effect_only?, do: effects == 2, else: effects > 0

    %{state: ^terminal, conflict?: false, effect_version: version, acknowledged_version: version} =
      Ash.get!(FixtureDispute, id, authorize?: false)

    if effect_only? do
      # The scheduler itself succeeds, but it must enqueue no second delivery.
      %{success: 1, failure: 0, discard: 0, queues_not_drained: []} =
        AshOban.Test.schedule_and_run_triggers({FixtureDispute, :deliver})
    end
  end

  IO.puts("WELL223_COMPLETED")
after
  Sandbox.checkin(Repo)
end
