defmodule NewYou.Identity.Actions.Recovery do
  @moduledoc false
  use Ash.Resource.Actions.Implementation

  @impl true
  def run(input, opts, _context),
    do: NewYou.Identity.Recovery.run(Keyword.fetch!(opts, :operation), input.arguments.request)
end
