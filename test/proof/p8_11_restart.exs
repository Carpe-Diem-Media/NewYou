[mode, obligation_id] = System.argv()
:ok = Ecto.Adapters.SQL.Sandbox.checkout(NewYou.Repo, sandbox: false)

try do
  trigger = AshOban.Info.oban_trigger(NewYou.Audit.EvidenceObligation, :registration_evidence)
  :ok = trigger.scheduler.perform(%Oban.Job{args: %{}})

  if mode == "execute" do
    jobs =
      NewYou.Repo.all(Oban.Job)
      |> Enum.filter(&(&1.args["primary_key"] == %{"id" => obligation_id}))

    true = Enum.any?(jobs, &(&1.state == "available"))
    # Deliberately execute every copy, including an exhausted original. This
    # proves convergence without treating job uniqueness as evidence authority.
    Enum.each(jobs, fn job -> :ok = trigger.worker.perform(job) end)
  end

  IO.puts("P811_RESTART_OK")
after
  Ecto.Adapters.SQL.Sandbox.checkin(NewYou.Repo)
end
