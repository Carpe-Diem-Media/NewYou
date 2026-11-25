alias Ecto.Adapters.SQL.Sandbox
alias NewYou.Commerce.SyntheticCorrections
alias NewYou.Entitlements.SyntheticRights

:ok = Sandbox.checkout(NewYou.Repo, sandbox: false)

case System.argv() do
  ["apply", id] -> :ok = SyntheticRights.apply_correction(id)
  ["deliver", id] -> {:ok, _} = SyntheticCorrections.deliver(id)
end

IO.puts("E2A_COMPLETED")
