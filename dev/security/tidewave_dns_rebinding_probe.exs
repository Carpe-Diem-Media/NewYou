unless Mix.env() == :dev do
  raise "run the Tidewave DNS-rebinding probe in MIX_ENV=dev"
end

defmodule NewYou.TidewaveDnsRebindingProbe do
  import Plug.Conn

  @port NewYouWeb.Endpoint.config(:http)[:port]
  @attacker_host "dns-rebinding-attacker.example"
  @local_host "127.0.0.1"

  def run do
    paths = metadata_paths()

    hostile_connect = request("/tidewave/connect", @attacker_host)
    connect_leaked_paths = leaked_paths(hostile_connect.resp_body, paths)

    assert(
      hostile_connect.status == 403,
      "hostile /tidewave/connect returned #{hostile_connect.status}; " <>
        "config_meta?=#{hostile_connect.resp_body =~ ~s|<meta name=\"tidewave:config\"|}; " <>
        "filesystem_path_count=#{length(connect_leaked_paths)}"
    )

    refute_disclosure(hostile_connect.resp_body, paths, "hostile /tidewave/connect")

    hostile_html = request("/legal/terms", @attacker_host)
    assert(hostile_html.status == 200, "legal HTML route should remain available")
    assert_html(hostile_html)

    assert(
      hostile_html.resp_body =~ ~s|<meta name="tidewave:error"|,
      "hostile HTML response should report that Tidewave is unavailable for this Host"
    )

    refute(
      hostile_html.resp_body =~ ~s|<meta name="tidewave:config"|,
      "hostile HTML response must not contain Tidewave configuration metadata"
    )

    refute_disclosure(hostile_html.resp_body, paths, "hostile HTML response")

    local_connect = request("/tidewave/connect", @local_host)
    assert(local_connect.status == 200, "local /tidewave/connect should remain available")

    assert(
      local_connect.resp_body =~ ~s|<meta name="tidewave:config"|,
      "local /tidewave/connect should still expose Tidewave's expected local config"
    )

    IO.puts("PASS: hostile loopback Host cannot read /tidewave/connect metadata")
    IO.puts("PASS: hostile HTML response contains no Tidewave config or filesystem paths")
    IO.puts("PASS: legitimate local Host can access /tidewave/connect")
  end

  defp request(path, host) do
    # Plug.Test parses the request authority into conn.host, the field Bandit
    # populates from the incoming Host header.
    conn = Plug.Test.conn(:get, "http://#{host}:#{@port}#{path}")
    assert(conn.host == host, "request authority should become the Host value")

    conn =
      conn
      |> Map.put(:remote_ip, {127, 0, 0, 1})
      |> put_req_header("sec-fetch-site", "same-origin")

    assert(get_req_header(conn, "origin") == [], "probe requests must omit Origin")

    conn = NewYouWeb.Endpoint.call(conn, NewYouWeb.Endpoint.init([]))

    if conn.state == :set do
      Plug.Conn.send_resp(conn)
    else
      conn
    end
  end

  defp metadata_paths do
    [Tidewave.MCP.root() | Map.values(Mix.Project.deps_paths())]
    |> Enum.uniq()
    |> Enum.filter(&(is_binary(&1) and &1 != ""))
  end

  defp assert_html(conn) do
    assert(
      Enum.any?(get_resp_header(conn, "content-type"), &String.starts_with?(&1, "text/html")),
      "expected an HTML response from /legal/terms"
    )
  end

  defp refute_disclosure(body, paths, request_name) do
    leaked_paths = leaked_paths(body, paths)

    refute(
      leaked_paths != [],
      "#{request_name} disclosed #{length(leaked_paths)} filesystem paths"
    )
  end

  defp leaked_paths(body, paths), do: Enum.filter(paths, &String.contains?(body, &1))

  defp assert(value, message) do
    unless value, do: raise(message)
  end

  defp refute(value, message) do
    if value, do: raise(message)
  end
end

NewYou.TidewaveDnsRebindingProbe.run()
