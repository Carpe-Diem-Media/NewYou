defmodule NewYou.Proof.P805PublicResponse do
  @moduledoc false

  @volatile [
    ~r/(<meta\b[^>]*name="csrf-token"[^>]*content=")[^"]*(")/,
    ~r/(<input\b[^>]*name="_csrf_token"[^>]*value=")[^"]*(")/,
    ~r/(<input\b[^>]*name="resend\[operation_id\]"[^>]*value=")[^"]*(")/
  ]

  def project(200, body, email, locale) when is_binary(body) and is_binary(email) do
    title = escaped_copy("identity.verification.pending.title", locale)
    notice = escaped_copy("identity.registration.accepted_neutral", locale)
    escaped_email = email |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()

    with true <- pending?(body, title, notice),
         true <- escaped_email != "" and String.contains?(body, escaped_email),
         {:ok, normalized} <- normalize_volatile(body) do
      {:ok,
       %{
         category: :verification_pending,
         status: 200,
         body: String.replace(normalized, escaped_email, "[email]")
       }}
    else
      _ -> {:error, :unexpected_response}
    end
  end

  def project(_, _, _, _), do: {:error, :unexpected_response}

  defp pending?(body, title, notice) do
    heading = Regex.scan(~r/<h1\b[^>]*id="pending-heading"[^>]*>(.*?)<\/h1>/s, body)
    statuses = Regex.scan(~r/<p\b[^>]*role="status"[^>]*>(.*?)<\/p>/s, body)

    match?([[_, ^title]], trim_matches(heading)) and
      match?([[_, ^notice]], trim_matches(statuses)) and
      String.contains?(body, "id=\"verification-resend-form\"")
  end

  defp trim_matches(matches),
    do: Enum.map(matches, fn [full, text] -> [full, String.trim(text)] end)

  defp normalize_volatile(body) do
    Enum.reduce_while(@volatile, {:ok, body}, fn pattern, {:ok, html} ->
      case Regex.scan(pattern, html) do
        [[_, _, _]] -> {:cont, {:ok, Regex.replace(pattern, html, "\\1[redacted]\\2")}}
        _ -> {:halt, {:error, :unexpected_response}}
      end
    end)
  end

  defp escaped_copy(key, locale) do
    key
    |> NewYouWeb.RegistrationHTML.copy(locale)
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end
end
