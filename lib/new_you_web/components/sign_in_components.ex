defmodule NewYouWeb.SignInComponents do
  @moduledoc "Shared presentation for the existing bilingual sign-in and Session pages."
  use NewYouWeb, :html

  attr :title, :string, required: true
  attr :locale, :string, required: true
  attr :locale_path, :string, default: nil
  attr :heading_id, :string, default: "sign-in-heading"
  slot :inner_block, required: true

  @doc "Renders the existing development-entry shell without account or bearer context."
  @spec auth_shell(map()) :: Phoenix.LiveView.Rendered.t()
  def auth_shell(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang={@locale}>
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="referrer" content="no-referrer" />
        <title>{@title}</title>
        <link rel="stylesheet" href={~p"/assets/css/app.css"} />
      </head>
      <body>
        <main id="main" class="min-h-svh bg-design-canvas text-design-ink font-design-sans">
          <header class="mx-auto grid w-full max-w-7xl gap-design-base border-b border-design-hairline px-design-base py-design-lg design-tablet:px-design-lg design-desktop:px-design-2xl">
            <p class="font-design-bold text-design-body-sm">{NewYou.platform_name()}</p>
            <nav
              :if={@locale_path}
              aria-label={NewYouWeb.CopyRegistry.text!("shared.language.change", @locale)}
              class="flex flex-wrap gap-design-base"
            >
              <a
                :for={language <- ~w(en af)}
                lang={language}
                href={"#{@locale_path}?locale=#{language}"}
                aria-current={if language == @locale, do: "page"}
                class="min-h-11 w-fit content-center text-design-body-xs leading-design-body-xs text-design-ink underline decoration-design-primary underline-offset-4 hover:text-design-primary active:text-design-primary-deep focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-design-primary"
              >
                {NewYouWeb.CopyRegistry.text!(
                  "shared.language.#{if language == "en", do: "english", else: "afrikaans"}",
                  @locale
                )}
              </a>
            </nav>
          </header>
          <section
            aria-labelledby={@heading_id}
            class="mx-auto grid w-full max-w-7xl content-start gap-design-lg px-design-base py-design-2xl design-tablet:px-design-lg design-desktop:px-design-2xl"
          >
            <h1
              id={@heading_id}
              class="max-w-3xl min-w-0 break-words text-balance font-design-bold text-design-display-sm leading-design-display-sm tracking-design-display-sm design-tablet:text-design-display-md design-tablet:leading-design-display-md design-tablet:tracking-design-display-md"
            >
              {@title}
            </h1>
            {render_slot(@inner_block)}
          </section>
        </main>
      </body>
    </html>
    """
  end
end
