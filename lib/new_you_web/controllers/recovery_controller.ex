defmodule NewYouWeb.RecoveryController do
  @moduledoc """
  Bounded development recovery transport. Responses contain no case, Account or
  Account-existence information. Passive retrieval renders an explicit form and
  never reads or consumes Identity authority. Content approval does not enable
  an external sender or production routes.
  """
  use NewYouWeb, :controller
  alias NewYou.Content.RecoveryBrowserCopy
  alias NewYou.Identity

  @enabled Mix.env() in [:dev, :test] and
             Application.compile_env(:new_you, :verification_development_fixtures, false)
  plug :require_proof_environment
  plug :require_current_copy

  @doc "Returns the approved request title when ordinary Recovery can be opened in the given locale."
  @spec discovery_title(String.t()) :: String.t() | nil
  def discovery_title(locale) do
    with :well183 <- entry_context(),
         {:ok, copy} <- RecoveryBrowserCopy.load(locale) do
      Map.fetch!(copy, "identity.recovery.request.title")
    else
      _ -> nil
    end
  end

  def new(conn, %{"locale" => locale}) when locale in ["en", "af"],
    do: page(conn, :request, locale)

  def new(conn, _params), do: neutral(conn)

  def show(conn, %{"locale" => locale} = params) when locale in ["en", "af"] do
    proof = safe_proof(params["proof"])

    page(conn, :confirmation, locale,
      proof: proof,
      operation_id: confirmation_operation_id(proof)
    )
  end

  def show(conn, _params), do: neutral(conn)

  def request(conn, params) do
    Identity.request_recovery(
      params["email"],
      params["locale"],
      params["operation_id"],
      conn.assigns.recovery_context
    )

    result(conn, params, :requested)
  end

  def confirm(conn, params) do
    case Identity.submit_recovery_proof(
           params["proof"],
           params["operation_id"],
           params["locale"],
           conn.assigns.recovery_context
         ) do
      {:ok, :accepted} -> result(conn, params, :credential, proof: safe_proof(params["proof"]))
      _ -> result(conn, params, :unavailable)
    end
  end

  def complete(conn, params) do
    case Identity.complete_recovery(
           params["proof"],
           params["password"],
           params["operation_id"],
           params["locale"],
           conn.assigns.recovery_context
         ) do
      {:ok, outcome} when outcome in [:completed, :already_completed] ->
        conn |> configure_session(renew: true) |> clear_session() |> result(params, :completed)

      _ ->
        result(conn, params, :unavailable)
    end
  end

  def cancel(conn, params) do
    Identity.cancel_recovery(
      params["proof"],
      params["operation_id"],
      params["locale"],
      conn.assigns.recovery_context
    )

    neutral(conn)
  end

  defp require_proof_environment(conn, _opts) do
    case entry_context() do
      nil -> conn |> headers() |> send_resp(404, "") |> halt()
      context -> assign(conn, :recovery_context, context)
    end
  end

  if @enabled do
    defp entry_context do
      cond do
        Application.get_env(:new_you, :fp001_development_entry) == true ->
          if NewYouWeb.DevelopmentEntry.enabled?(), do: :well183

        Application.get_env(:new_you, :p8_15_browser_development_fixtures) == true ->
          :p8_15

        true ->
          nil
      end
    end
  else
    defp entry_context, do: nil
  end

  defp require_current_copy(%{assigns: %{recovery_context: :well183}} = conn, _opts) do
    case conn.params["locale"] do
      locale when locale in ["en", "af"] ->
        case RecoveryBrowserCopy.load(locale) do
          {:ok, copy} -> assign(conn, :recovery_copy, copy)
          _ -> conn |> headers() |> send_resp(503, "") |> halt()
        end

      _ ->
        conn |> neutral() |> halt()
    end
  end

  defp require_current_copy(conn, _opts), do: conn

  defp neutral(conn), do: conn |> headers() |> send_resp(204, "")

  defp result(conn, params, stage, assigns \\ [])

  defp result(conn, %{"locale" => locale}, stage, assigns) when locale in ["en", "af"],
    do: page(conn, stage, locale, assigns)

  defp result(conn, _, _, _), do: neutral(conn)

  defp page(conn, stage, locale, assigns \\ []) do
    conn
    |> headers()
    |> put_root_layout(false)
    |> put_view(html: NewYouWeb.RecoveryHTML)
    |> render(
      :journey,
      Map.merge(
        %{
          stage: stage,
          locale: locale,
          copy: conn.assigns[:recovery_copy],
          proof: "",
          operation_id: Ecto.UUID.generate()
        },
        Map.new(assigns)
      )
    )
  end

  # This untrusted identifier is only a stable form retry key, never assurance.
  # GET performs no Identity lookup or signature admission. The explicit POST
  # verifies the signed proof and current durable case through Identity.
  defp confirmation_operation_id(proof) do
    with {:ok, %{"purpose" => "recovery", "case_id" => case_id}} <- Joken.peek_claims(proof),
         {:ok, id} <- Ecto.UUID.cast(case_id) do
      id
    else
      _ -> Ecto.UUID.generate()
    end
  end

  defp safe_proof(proof) when is_binary(proof) and byte_size(proof) <= 8192, do: proof
  defp safe_proof(_), do: ""

  defp headers(conn) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> put_resp_header("referrer-policy", "no-referrer")
    |> put_resp_header(
      "content-security-policy",
      "default-src 'none'; style-src 'self'; font-src 'self'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'"
    )
  end
end
