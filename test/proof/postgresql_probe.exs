{:ok, _postgresql_version} = NewYou.Proof.Result.capture_postgresql()

scenario = NewYou.Proof.Scenario.start()

result =
  try do
    NewYou.Proof.Concurrent.infrastructure_fixture(scenario, timeout: 10_000)
  after
    :ok = NewYou.Proof.Scenario.stop(scenario)
  end

case result do
  {:ok, %{contention_observed: true, cleanup: %{confirmed: true}} = observation} ->
    IO.puts(Jason.encode!(%{status: "pass", observation: observation}))

  {:ok, _observation} ->
    IO.puts(Jason.encode!(%{status: "fail", reason: "invalid_observation"}))
    System.halt(1)

  {:error, _reason} ->
    IO.puts(Jason.encode!(%{status: "fail", reason: "contention_or_cleanup_failed"}))
    System.halt(1)
end
