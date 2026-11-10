defmodule NewYouWeb.DesignSystemLive do
  @moduledoc """
  Development-only visual reference for NewYou's shared CSS tokens.

  Grid count, alignment and preview viewport are bounded, URL-backed display
  choices. The page never writes theme values or business state. A browser hook
  reads computed CSS for measurements; the iframe uses the same app stylesheet
  and semantic components in a real viewport.
  """
  use NewYouWeb, :live_view

  import NewYouWeb.Components.Design.Button, only: [primary_button: 1, secondary_button: 1]
  import NewYouWeb.Components.Design.Card
  import NewYouWeb.Components.Design.Link
  import NewYouWeb.DesignSystemComponents

  @counts ~w(1 2 3 4 5 6 7 8 9)
  @alignments ~w(start center)
  @viewports ~w(auto phone tablet desktop wide)

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Design system", page_language: "en")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    count = choice(params["count"], @counts, "5")

    {:noreply,
     assign(socket,
       count: count,
       card_count: String.to_integer(count),
       alignment: choice(params["alignment"], @alignments, "start"),
       viewport: choice(params["viewport"], @viewports, "auto"),
       counts: @counts,
       preview?: socket.assigns.live_action == :preview
     )}
  end

  @impl true
  def handle_event("grid", %{"grid" => values}, socket) when is_map(values) do
    patch_choices(socket,
      count: choice(values["count"], @counts, "5"),
      alignment: choice(values["alignment"], @alignments, "start")
    )
  end

  def handle_event("viewport", %{"viewport" => value}, socket) do
    patch_choices(socket, viewport: choice(value, @viewports, "auto"))
  end

  def handle_event("grid", _params, socket), do: {:noreply, socket}
  def handle_event("viewport", _params, socket), do: {:noreply, socket}

  defp patch_choices(socket, updates) do
    choices =
      socket.assigns
      |> Map.take([:count, :alignment, :viewport])
      |> Map.merge(Map.new(updates))

    {:noreply, push_patch(socket, to: ~p"/dev/design-system?#{choices}", replace: true)}
  end

  defp choice(value, allowed, fallback) when is_binary(value) do
    if value in allowed, do: value, else: fallback
  end

  defp choice(_value, _allowed, fallback), do: fallback
end
