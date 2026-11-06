# Synthetic proof configuration arrives over the anonymous pipe, never CLI args,
# Oban args or persisted fixtures. No DevCore secret is read or copied here.
input = IO.gets("") |> Jason.decode!()

keyring = %{
  active: input["key_version"],
  keys: %{input["key_version"] => Base.decode64!(input["envelope_key"])}
}

Application.put_env(:new_you, :communications_keyring, keyring)
:ok = Ecto.Adapters.SQL.Sandbox.checkout(NewYou.Repo, sandbox: false)
scenario = NewYou.Proof.Scenario.start()

try do
  :ok =
    NewYou.Proof.Provider.configure(scenario, %{"restart-operation" => [{:submit, :accepted}]})

  Process.put(:p810_provider, fn _, _ ->
    {:ok, event} = NewYou.Proof.Provider.next(scenario, "restart-operation", :submit)
    event.outcome
  end)

  trigger = AshOban.Info.oban_trigger(NewYou.Communications.MessageIntent, :delivery)
  :ok = trigger.scheduler.perform(%Oban.Job{args: %{}})

  jobs =
    Enum.filter(
      NewYou.Repo.all(Oban.Job),
      &(&1.args["primary_key"] == %{"id" => input["intent_id"]})
    )

  true = Enum.any?(jobs, &(&1.state == "available"))
  Enum.each(jobs, fn job -> :ok = trigger.worker.perform(job) end)
  IO.puts("P810_RESTART_OK")
after
  :ok = NewYou.Proof.Scenario.stop(scenario)
  Ecto.Adapters.SQL.Sandbox.checkin(NewYou.Repo)
end
