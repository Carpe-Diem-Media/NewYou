defmodule NewYou.Identity.Actions.ResetPassword do
  @moduledoc false
  use Ash.Resource.Actions.Implementation

  @impl true
  def run(input, _opts, _context),
    do:
      NewYou.Identity.PasswordReset.reset(
        input.arguments.proof,
        input.arguments.password,
        input.arguments.operation_id
      )
end
