defmodule NewYou.Proof.P805PublicResponseTest do
  use ExUnit.Case, async: true

  alias NewYou.Proof.P805PublicResponse

  test "compares the actual pending response while masking only request-specific values" do
    first = response("first@example.test", "csrf-one", "operation-one")
    second = response(" FIRST@EXAMPLE.TEST ", "csrf-two", "operation-two")

    assert {:ok, a} = P805PublicResponse.project(200, first, "first@example.test", "en")
    assert {:ok, b} = P805PublicResponse.project(200, second, " FIRST@EXAMPLE.TEST ", "en")
    assert a.category == :verification_pending
    assert a == b

    assert {:ok, changed} =
             P805PublicResponse.project(
               200,
               second <> "<p>Account already exists</p>",
               " FIRST@EXAMPLE.TEST ",
               "en"
             )

    refute a == changed
  end

  test "rejects a different outward category, status, or missing per-request fields" do
    body = response("first@example.test", "csrf-one", "operation-one")
    assert {:error, _} = P805PublicResponse.project(400, body, "first@example.test", "en")

    assert {:error, _} =
             P805PublicResponse.project(
               200,
               String.replace(body, "pending-heading", "other-heading"),
               "first@example.test",
               "en"
             )

    assert {:error, _} =
             P805PublicResponse.project(
               200,
               String.replace(body, "resend[operation_id]", "other"),
               "first@example.test",
               "en"
             )
  end

  defp response(email, csrf, operation) do
    title = NewYouWeb.RegistrationHTML.copy("identity.verification.pending.title", "en")
    notice = NewYouWeb.RegistrationHTML.copy("identity.registration.accepted_neutral", "en")

    """
    <meta name="csrf-token" content="#{csrf}">
    <main><h1 id="pending-heading">#{title}</h1><p>#{email}</p><p role="status">#{notice}</p>
    <form id="verification-resend-form"><input name="_csrf_token" value="#{csrf}">
    <input name="resend[operation_id]" value="#{operation}"><input name="resend[email]" value="#{email}"></form></main>
    """
  end
end
