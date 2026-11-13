defmodule NewYouWeb.PrimaryEmailChangeController do
  use NewYouWeb, :controller

  def show(conn, params), do: handle(conn, params, :confirm)
  def confirm(conn, params), do: handle(conn, params, :consume)

  defp handle(conn, %{"locale" => locale} = params, mode) when locale in ["en", "af"] do
    if content_eligible?(locale) do
      proof = Map.get(params, "proof", "")
      result = result(mode, proof)

      conn
      |> put_resp_header("cache-control", "no-store")
      |> put_resp_header("referrer-policy", "no-referrer")
      |> put_resp_header(
        "content-security-policy",
        "default-src 'none'; style-src 'self'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'"
      )
      |> put_view(html: NewYouWeb.PrimaryEmailChangeHTML)
      |> put_root_layout(false)
      |> render(:confirmation,
        locale: locale,
        result: result,
        proof:
          if(result == :confirm and is_binary(proof) and byte_size(proof) <= 8192,
            do: proof,
            else: ""
          )
      )
    else
      send_resp(conn, 404, "")
    end
  end

  defp handle(conn, _params, _mode), do: send_resp(conn, 404, "")

  # Retrieval and scanner activity never ask Identity to consume the proof.
  defp result(:confirm, _proof), do: :confirm

  defp result(:consume, proof) do
    case NewYou.Identity.confirm_primary_email_change(proof) do
      {:ok, :confirmed} -> :confirmed
      _ -> :unavailable
    end
  end

  defp content_eligible?(locale),
    do:
      Mix.env() in [:dev, :test] and
        match?(
          {:ok, _},
          NewYou.Content.PrimaryEmailChangeMessage.binding(:email_change_confirmation, locale)
        )
end
