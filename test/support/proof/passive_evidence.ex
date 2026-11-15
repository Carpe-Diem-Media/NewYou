defmodule NewYou.Proof.PassiveEvidence do
  @moduledoc false
  import ExUnit.Assertions
  import Plug.Conn
  require Ash.Query
  alias NewYou.Identity.{Account, DeviceAssurance, RecoveryCase, Session, Token}

  # Read the fixture owner's full persisted attributes, not global row counts.
  # Only digests leave this function; assertion failures must not render secrets.
  def snapshot(account_id) do
    %{
      account: digest(Account, [Ash.get!(Account, account_id, authorize?: false)]),
      tokens: scoped_digest(Token, account_id, :jti),
      sessions: scoped_digest(Session, account_id, :id),
      device_assurances: scoped_digest(DeviceAssurance, account_id, :id),
      recovery_cases: scoped_digest(RecoveryCase, account_id, :id)
    }
  end

  def assert_unchanged!(account_id, before) do
    assert snapshot(account_id) == before, "passive request changed persisted owner state"
    :ok
  end

  def assert_response!(conn) do
    assert conn.status == 200
    assert get_resp_header(conn, "cache-control") == ["no-store"]
    assert get_resp_header(conn, "referrer-policy") == ["no-referrer"]
    assert Enum.all?(Map.keys(get_session(conn)), &(&1 == "_csrf_token"))
    :ok
  end

  # Compare every response header, cookie attribute and non-CSRF session value.
  # Request IDs and authenticated encryption of the anonymous session vary per
  # request. All other cookie values and metadata remain part of the comparison.
  def public_response(conn) do
    assert byte_size(conn.resp_body) <= 65_536
    assert length(conn.resp_headers) <= 64

    headers =
      conn.resp_headers
      |> Enum.map(fn
        {"x-request-id", _} -> {"x-request-id", "[request-id]"}
        {"set-cookie", value} -> {"set-cookie", session_cookie(value)}
        other -> other
      end)
      |> Enum.sort()

    cookies =
      Map.new(conn.resp_cookies, fn
        {"_new_you_key", cookie} -> {"_new_you_key", Map.put(cookie, :value, "[session-cookie]")}
        other -> other
      end)

    session =
      Map.new(get_session(conn), fn
        {"_csrf_token", _} -> {"_csrf_token", "[csrf-token]"}
        other -> other
      end)

    body =
      Regex.replace(~r/(name="_csrf_token"[^>]*value=")[^"]+/, conn.resp_body, "\\1[csrf-token]")

    {conn.status, body, headers, cookies, session}
  end

  defp session_cookie(value),
    do: Regex.replace(~r/\A(_new_you_key=)[^;]*/, value, "\\1[session-cookie]")

  defp scoped_digest(resource, account_id, sort) do
    records =
      resource
      |> Ash.Query.filter(account_id == ^account_id)
      |> Ash.Query.sort(sort)
      |> Ash.read!(authorize?: false)

    digest(resource, records)
  end

  defp digest(resource, records) do
    attributes = Enum.map(Ash.Resource.Info.attributes(resource), & &1.name)
    rows = Enum.map(records, &Map.take(&1, attributes))
    :crypto.hash(:sha256, :erlang.term_to_binary(rows, [:deterministic]))
  end
end
