defmodule NewYou.Proof.PassiveEvidenceTest do
  use ExUnit.Case, async: false
  import Phoenix.ConnTest
  import Plug.Conn
  alias NewYou.Proof.{P805, PassiveEvidence}
  alias NewYou.Identity

  test "the owner snapshot detects persisted Session issuance and token consumption" do
    P805.with_fixture(fn ->
      request = P805.request()
      {:ok, registered} = Identity.register(request)
      {:ok, :verified} = Identity.verify_email(registered.verification_proof)
      before = PassiveEvidence.snapshot(registered.account_id)
      assert before == PassiveEvidence.snapshot(registered.account_id)
      assert {:ok, _} = Identity.authenticate_password(request.email, request.password)
      refute before == PassiveEvidence.snapshot(registered.account_id)
    end)
  end

  test "passive response assertions reject identity sessions and missing security headers" do
    safe = response()
    assert :ok = PassiveEvidence.assert_response!(safe)

    for unsafe <- [
          put_session(safe, :identity_session_id, "synthetic-session"),
          put_session(safe, :identity_token, "synthetic-token"),
          delete_resp_header(safe, "cache-control"),
          delete_resp_header(safe, "referrer-policy")
        ] do
      assert_raise ExUnit.AssertionError, fn -> PassiveEvidence.assert_response!(unsafe) end
    end
  end

  test "neutrality normalizes only CSRF and the encrypted session cookie" do
    first =
      response()
      |> put_session(:_csrf_token, "first")
      |> put_resp_cookie("_new_you_key", "first", http_only: true)

    second =
      response()
      |> put_session(:_csrf_token, "second")
      |> put_resp_cookie("_new_you_key", "second", http_only: true)

    assert PassiveEvidence.public_response(first) == PassiveEvidence.public_response(second)

    for changed <- [
          put_resp_header(second, "location", "/known-account"),
          put_resp_header(second, "x-account-exists", "true"),
          put_resp_cookie(second, "account_exists", "true", http_only: true),
          put_resp_cookie(second, "_new_you_key", "second", http_only: false),
          put_session(second, :known_account, true),
          put_resp_header(second, "referrer-policy", "unsafe-url")
        ] do
      refute PassiveEvidence.public_response(first) == PassiveEvidence.public_response(changed)
    end
  end

  defp response do
    build_conn()
    |> init_test_session(%{})
    |> put_resp_header("cache-control", "no-store")
    |> put_resp_header("referrer-policy", "no-referrer")
    |> resp(200, "same public result")
  end
end
