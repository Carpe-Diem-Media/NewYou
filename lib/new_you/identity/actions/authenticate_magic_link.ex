defmodule NewYou.Identity.Actions.AuthenticateMagicLink do
  @moduledoc false
  use Ash.Resource.Actions.Implementation

  @impl true
  def run(input, _opts, _context),
    do: NewYou.Identity.MagicLogin.authenticate(input.arguments.proof)
end
