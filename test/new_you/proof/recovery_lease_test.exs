defmodule NewYou.Proof.RecoveryLeaseTest do
  use ExUnit.Case, async: true
  alias NewYou.Proof.RecoveryLease

  test "only the exact client and timeout on the monitored exit classify as expiry" do
    client = "#PID<0.100.0>"

    msg =
      "client #{client} timed out because it queued and checked out the connection for longer than 350ms"

    reason = fn text -> {:shutdown, %DBConnection.ConnectionError{message: text}} end
    assert RecoveryLease.classify(reason.(msg <> "\nprivate stack"), client) == :checkout_deadline
    assert RecoveryLease.classify(reason.(msg), "#PID<0.101.0>") == :unknown
    assert RecoveryLease.classify(reason.(msg <> "0"), client) == :unknown

    assert RecoveryLease.classify(reason.(String.replace(msg, "350ms", "250ms")), client) ==
             :unknown

    assert RecoveryLease.classify(:noproc, client) == :unknown
  end

  test "rejects private data, impossible durations and out-of-range ordinals in child reports" do
    assert RecoveryLease.parse("private data") == []

    assert RecoveryLease.parse("P815_LEASE 0 unknown transition lease_lost 999999999999 2 3") ==
             []

    assert RecoveryLease.parse("P815_LEASE 0 unknown private lease_lost 1 2 3") == []

    assert RecoveryLease.parse("P815_LEASE 10 checkout_deadline transition lease_lost 1 2 -1") ==
             []

    assert RecoveryLease.parse("P815_LEASE checkout_deadline transition lease_lost 1 2 -1") == []

    assert [%{ordinal: 0, closure: :checkout_deadline, operation: :transition}] =
             RecoveryLease.parse("P815_LEASE 0 checkout_deadline transition lease_lost 1 2 -1")
  end
end
