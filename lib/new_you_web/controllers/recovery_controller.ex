defmodule NewYouWeb.RecoveryController do
  @moduledoc """
  Bounded development recovery transport. Responses contain no case, Account or
  proof-validity information. Passive retrieval is an empty non-consuming response.
  This adds no participant wording or delivery/content approval.
  """
  use NewYouWeb, :controller
  alias NewYou.Identity

  @enabled Mix.env() in [:dev, :test] and
             Application.compile_env(:new_you, :verification_development_fixtures, false)
  plug :require_proof_environment

  def show(conn, _params), do: neutral(conn)

  def request(conn, params) do
    Identity.request_recovery(params["email"], params["locale"], params["operation_id"])
    neutral(conn)
  end

  def confirm(conn, params) do
    Identity.submit_recovery_proof(params["proof"], params["operation_id"])
    neutral(conn)
  end

  def complete(conn, params) do
    case Identity.complete_recovery(params["proof"], params["password"], params["operation_id"]) do
      {:ok, outcome} when outcome in [:completed, :already_completed] ->
        conn |> configure_session(renew: true) |> clear_session() |> neutral()

      _ ->
        neutral(conn)
    end
  end

  def cancel(conn, params) do
    Identity.cancel_recovery(params["proof"], params["operation_id"])
    neutral(conn)
  end

  defp require_proof_environment(conn, _opts) do
    if :erlang.andalso(
         @enabled,
         Application.get_env(:new_you, :p8_15_browser_development_fixtures) == true
       ),
       do: conn,
       else: conn |> headers() |> send_resp(404, "") |> halt()
  end

  defp neutral(conn), do: conn |> headers() |> send_resp(204, "")

  defp headers(conn) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> put_resp_header("referrer-policy", "no-referrer")
    |> put_resp_header("content-security-policy", "default-src 'none'; frame-ancestors 'none'")
  end
end
