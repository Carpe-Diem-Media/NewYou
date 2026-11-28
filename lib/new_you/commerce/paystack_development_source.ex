if Mix.env() == :dev do
  defmodule NewYou.Commerce.PaystackDevelopmentSource do
    @moduledoc false

    alias NewYou.Identity

    # A local operator attests exact source and disclosure approvals. This
    # input never activates the provider or authorizes a session by itself.
    def authorize(credentials) do
      with {:ok, %{"payer_id" => payer_id} = source} <-
             NewYou.LocalConfig.paystack_development_plan(),
           {:ok, %{account_id: ^payer_id}} <- Identity.authorize_canonical_session(credentials) do
        {:ok, source}
      else
        _ -> {:error, :purchase_unavailable}
      end
    end
  end
end
