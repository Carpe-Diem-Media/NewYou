defmodule NewYouWeb.PasswordResetController do
  use NewYouWeb, :controller

  alias NewYou.Identity

  @development_environment Mix.env() in [:dev, :test]
  @verification_development_fixtures Application.compile_env(
                                       :new_you,
                                       :verification_development_fixtures,
                                       false
                                     )

  plug :require_proof_environment

  def new(conn, %{"locale" => locale}) when locale in ["en", "af"] do
    render_page(conn, :request, locale, %{operation_id: Ecto.UUID.generate()})
  end

  def new(conn, _params), do: not_found(conn)

  def request(conn, %{"locale" => locale, "email" => email, "operation_id" => operation_id})
      when locale in ["en", "af"] and is_binary(email) and is_binary(operation_id) do
    if valid_operation_id?(operation_id),
      do: safely_request_password_reset(email, locale, operation_id)

    render_page(conn, :request_result, locale, %{})
  end

  def request(conn, _params), do: not_found(conn)

  # The GET only carries the proof into an explicit, CSRF-protected form. A
  # scanner, prefetcher or HEAD request cannot consume the Identity capability.
  def show(conn, %{"locale" => locale} = params) when locale in ["en", "af"] do
    proof = Map.get(params, "proof", "")

    render_page(conn, :confirmation, locale, %{
      proof: if(is_binary(proof) and byte_size(proof) <= 8192, do: proof, else: ""),
      operation_id: Ecto.UUID.generate()
    })
  end

  def show(conn, _params), do: not_found(conn)

  def confirm(conn, %{
        "locale" => locale,
        "proof" => proof,
        "password" => password,
        "operation_id" => operation_id
      })
      when locale in ["en", "af"] do
    outcome = Identity.reset_password(proof, password, operation_id)

    if match?({:ok, result} when result in [:reset, :already_reset], outcome) do
      conn
      |> configure_session(renew: true)
      |> clear_session()
      |> render_page(:confirmation_result, locale, %{completed?: true})
    else
      render_page(conn, :confirmation_result, locale, %{completed?: false})
    end
  end

  def confirm(conn, %{"locale" => locale}) when locale in ["en", "af"],
    do: render_page(conn, :confirmation_result, locale, %{completed?: false})

  def confirm(conn, _params), do: not_found(conn)

  defp require_proof_environment(conn, _opts) do
    if :erlang.andalso(
         @development_environment,
         :erlang.andalso(
           @verification_development_fixtures == true,
           Application.get_env(:new_you, :p8_12_browser_development_fixtures) == true
         )
       ) do
      conn
    else
      conn |> not_found() |> halt()
    end
  end

  defp valid_operation_id?(operation_id), do: match?({:ok, _}, Ecto.UUID.cast(operation_id))

  defp safely_request_password_reset(email, locale, operation_id) do
    Identity.request_password_reset(email, locale, operation_id)
  rescue
    _ -> :unavailable
  catch
    _, _ -> :unavailable
  end

  defp render_page(conn, template, locale, assigns) do
    conn
    |> security_headers()
    |> put_root_layout(false)
    |> put_view(html: NewYouWeb.PasswordResetHTML)
    |> render(template, Map.merge(%{locale: locale}, assigns))
  end

  defp security_headers(conn) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> put_resp_header("referrer-policy", "no-referrer")
    |> put_resp_header(
      "content-security-policy",
      "default-src 'none'; style-src 'self'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'"
    )
  end

  defp not_found(conn), do: conn |> security_headers() |> send_resp(404, "")
end
