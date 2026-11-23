defmodule NewYou.Secrets do
  @moduledoc """
  AshAuthentication secret provider for Identity Account token signing.
  The configured value stays in application configuration and is returned only
  for the Account signing-secret DSL path. A missing or undersized value returns
  `:error`.
  """

  use AshAuthentication.Secret

  @impl true
  def secret_for(
        [:authentication, :tokens, :signing_secret],
        NewYou.Identity.Account,
        _opts,
        _context
      ) do
    case Application.get_env(:new_you, :identity_token_signing_secret) do
      secret when is_binary(secret) and byte_size(secret) >= 32 -> {:ok, secret}
      _ -> :error
    end
  end
end
