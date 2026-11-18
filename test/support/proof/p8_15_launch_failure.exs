import ExUnit.Assertions

alias NewYou.Proof.{P805, P805Fixture, P815Port}

# An intentionally unidentified launch must keep its fixture quarantined. Use a
# separate TEST BEAM so this negative proof cannot strand the parent test suite.
# No business fixtures are created, and the exact opened process is stopped.
IO.puts("P815_STARTED")
parent = self()
openings = :atomics.new(1, [])

Process.put({P805, :launch_checkpoint}, fn :opened, port ->
  if :atomics.add_get(openings, 1, 1) == 1 do
    {:os_pid, pid} = Port.info(port, :os_pid)
    send(parent, {:opened_before_identity, port, pid})
    true = Port.close(port)
    raise "deliberate post-open identity interruption"
  end
end)

try do
  P805.with_fixture(fn ->
    first = P815Port.run(System.find_executable("sh"), ["-c", "printf 'P815_REQUESTED\\n'"], "")
    second = P815Port.run(System.find_executable("sh"), ["-c", "printf 'P815_REQUESTED\\n'"], "")
    Process.put(:launch_results, {first, second})
  end)
rescue
  error in RuntimeError ->
    assert Exception.message(error) == "P8-05 fixture cleanup unconfirmed"
end

assert_receive {:opened_before_identity, port, pid}, 1_000
assert Port.info(port) == nil

stopped? = fn stopped?, remaining ->
  cond do
    P815Port.external_stopped?(pid) ->
      true

    remaining == 0 ->
      false

    true ->
      Process.sleep(10)
      stopped?.(stopped?, remaining - 1)
  end
end

assert stopped?.(stopped?, 200)
{first, second} = Process.get(:launch_results)

case System.argv() do
  ["classification"] ->
    assert first.cleanup == :unconfirmed
    assert first.status == :harness_failure

  ["second_launch"] ->
    assert :atomics.get(openings, 1) == 1
    assert second.cleanup == :unconfirmed
    assert second.marker == nil
end

fixture = P805.fixture_status()
assert fixture.phase == :quarantined
assert fixture.external_launch.port == port

assert {:error, :invalid_launch_transition} =
         P805Fixture.settle_external(
           fixture.reference,
           fixture.external_launch.reference,
           :not_started
         )

assert {:error, :stale_launch} =
         P805Fixture.settle_external(fixture.reference, make_ref(), :not_started)

assert {:error, :stale_launch} = P805Fixture.opened(fixture.reference, make_ref(), port)
assert {:error, :stale_launch} = P805Fixture.port(fixture.reference, make_ref(), port, pid)
assert P805.fixture_status() == fixture
assert {:error, :processes_unconfirmed} = P805.reconcile_fixture(fixture.reference)

assert_raise RuntimeError, "P8-05 fixture already active or quarantined", fn ->
  P805.with_fixture(fn -> flunk("an unidentified launch released admission") end)
end

IO.puts("P815_ACCEPTED")
