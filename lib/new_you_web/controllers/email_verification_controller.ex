defmodule NewYouWeb.EmailVerificationController do
  use NewYouWeb, :controller
  alias NewYouWeb.VerificationCopy

  def show(conn, params), do: handle(conn, params, :confirm)
  def confirm(conn, params), do: handle(conn, params, :consume)

  defp handle(conn, %{"locale" => locale} = params, mode) when locale in ["en", "af"] do
    if VerificationCopy.enabled?() do
      proof = Map.get(params, "proof", "")
      result = result(mode, proof)

      conn
      |> put_resp_header("cache-control", "no-store")
      |> put_resp_header("referrer-policy", "no-referrer")
      |> put_resp_header(
        "content-security-policy",
        "default-src 'none'; style-src 'self'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'"
      )
      |> put_view(html: NewYouWeb.EmailVerificationHTML)
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

  # Rendering, HEAD and prefetch never call Identity. Only the protected POST
  # reaches this clause; all unavailable causes share the same public result.
  defp result(:confirm, _proof), do: :confirm

  defp result(:consume, proof) do
    case NewYou.Identity.verify_email(proof) do
      {:ok, :verified} -> :verified
      _ -> :unavailable
    end
  end
end
