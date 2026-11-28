alias Ecto.Adapters.SQL.Sandbox
alias NewYou.Commerce.SyntheticCorrections
alias NewYou.Entitlements.SyntheticRights

:ok = Sandbox.checkout(NewYou.Repo, sandbox: false)

[stage, source_id] = System.argv()
{:ok, open_effects} = SyntheticCorrections.open_consequences(source_id)

case {stage, open_effects} do
  {"apply", [_ | _] = effects} ->
    Enum.each(effects, fn id -> :ok = SyntheticRights.apply_correction(id) end)

  {"deliver", [_ | _] = effects} ->
    Enum.each(effects, fn id -> {:ok, _} = SyntheticCorrections.deliver(id) end)

  {"replay", []} ->
    :ok
end

IO.puts("E2A_COMPLETED")
