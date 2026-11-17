defmodule NewYou.Identity.Actions.ResetPassword do
  @moduledoc false
  use Ash.Resource.Actions.Implementation

  @impl true
  def run(input, _opts, _context) do
    case NewYou.Identity.PasswordReset.reset(
           input.arguments.proof,
           input.arguments.password,
           input.arguments.operation_id
         ) do
      {:ok, result} -> {:ok, result}
      # Preserve owner outcomes across Ash's generic error normalization. These
      # atoms are action results, never successful password-change assertions.
      {:error, result} when result in [:reset_unavailable, :reset_uncertain] -> {:ok, result}
    end
  end
end
