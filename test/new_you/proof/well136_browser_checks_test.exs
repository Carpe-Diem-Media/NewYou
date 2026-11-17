defmodule NewYou.Proof.Well136BrowserChecksTest do
  use ExUnit.Case, async: true
  alias NewYou.Proof.Well136Browser

  @checks ~w(public_entry prior_session forgot_password approved_request labels stylesheet responsive text_resize reduced_motion keyboard_focus csrf neutral_request accepted_copy real_delivery scanner_safe confirmation_copy completed_copy no_automatic_login proof_not_rendered persisted_reset stale_session_denied replay_denied retry_navigation old_password_denied fresh_sign_in expired_link withdrawal_blocks_delivery failed_attempts_preserve_credential)

  test "complete ordinary EN/AF proof accepts every required successful predicate" do
    checks = Map.new(@checks, &{&1, true})
    Well136Browser.assert_checks!(checks)
  end

  for key <- @checks do
    @key key
    test "omitting #{@key} fails even with more than twenty other passing checks" do
      checks = Map.new(@checks, &{&1, true}) |> Map.delete(@key)
      assert map_size(checks) > 20
      assert_raise ExUnit.AssertionError, fn -> Well136Browser.assert_checks!(checks) end
    end
  end

  test "a reported failure cannot be hidden by other successful predicates" do
    checks = Map.new(@checks, &{&1, true}) |> Map.put("scanner_safe", false)
    assert_raise ExUnit.AssertionError, fn -> Well136Browser.assert_checks!(checks) end
  end
end
