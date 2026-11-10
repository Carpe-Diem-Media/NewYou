defmodule NewYou.Identity.RecoveryConcurrencyTest do
  use ExUnit.Case, async: false

  alias NewYou.Proof.P815

  test "duplicate requests serialize on PostgreSQL and retain one recovery case" do
    assert P815.duplicate_request_race()
  end

  test "competing completions serialize and only one credential change commits" do
    assert P815.completion_race()
  end

  test "old password login waits for completion and cannot create a session" do
    assert P815.stale_login_race()
  end

  test "stale password reset proof cannot race past recovery completion" do
    assert P815.reset_vs_recovery_race()
  end

  test "proof acceptance rolls back when its transaction worker terminates" do
    assert P815.interrupted_acceptance()
  end

  test "recovery delivery and completion receipts survive fresh BEAM processes" do
    assert P815.restart_proof() == :ok
  end
end
