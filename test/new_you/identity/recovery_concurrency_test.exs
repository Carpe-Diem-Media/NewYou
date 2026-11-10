defmodule NewYou.Identity.RecoveryConcurrencyTest do
  use ExUnit.Case, async: false

  alias NewYou.Proof.P815

  test "duplicate requests serialize on PostgreSQL and retain one recovery case" do
    assert P815.duplicate_request_race()
  end

  test "parallel zero-assurance requests cannot impose an Account restriction" do
    assert P815.duplicate_request_race(false)
  end

  test "parallel proof acceptance imposes one justified hold and one E2 consequence" do
    assert P815.assurance_race()
  end

  test "zero-assurance recovery survives restart without restricting the Account" do
    assert P815.unverified_restart_proof() == :ok
  end

  test "restarted recovery retries the same case after a bounded request loses its lease" do
    assert P815.unverified_restart_proof(interrupt_resume?: true) == :ok
  end

  test "recovery waits for an earlier email fixture commit and rejects its stale binding" do
    assert P815.prior_email_commit_race()
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
