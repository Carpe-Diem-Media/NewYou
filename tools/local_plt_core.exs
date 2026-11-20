Mix.start()
Mix.ensure_application!(:dialyzer)

staging = System.fetch_env!("NEWYOU_PLT_STAGING")
plan = System.fetch_env!("NEWYOU_PLT_PLAN") |> Base.decode64!() |> :erlang.binary_to_term([:safe])

plts =
  Enum.map(plan, fn {basename, apps} ->
    plt_path = Path.join(staging, basename)
    app_atoms = Enum.map(apps, &String.to_existing_atom/1)
    {plt_path, app_atoms}
  end)

Dialyxir.Plt.check(plts)
