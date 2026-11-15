defmodule NewYou.Communications.DeliveryTest do
  use ExUnit.Case, async: false

  test "admission commits before provider I/O and delivery never verifies Identity" do
    NewYou.Proof.DeliveryScenarios.scenario_admission_commits_before_provider_i_o_and_delivery_never_verifies_identity()
  end

  test "unknown blocks blind retry and only authenticated no-operation allows a new attempt" do
    NewYou.Proof.DeliveryScenarios.scenario_unknown_blocks_blind_retry_and_only_authenticated_no_operation_allows_a_new_attempt()
  end

  test "consumed source closes send authority and destroys the envelope" do
    NewYou.Proof.DeliveryScenarios.scenario_consumed_source_closes_send_authority_and_destroys_the_envelope()
  end

  test "source invalidation during unresolved delivery clears secrets without permitting retry" do
    NewYou.Proof.DeliveryScenarios.scenario_source_invalidation_during_unresolved_delivery_clears_secrets_without_permitting_retry()
  end

  test "outer transactions cannot encompass provider I/O" do
    NewYou.Proof.DeliveryScenarios.scenario_outer_transactions_cannot_encompass_provider_i_o()
  end

  test "consumption between admission and invocation truthfully closes the uninvoked attempt" do
    NewYou.Proof.DeliveryScenarios.scenario_consumption_between_admission_and_invocation_truthfully_closes_the_uninvoked_attempt()
  end
end
