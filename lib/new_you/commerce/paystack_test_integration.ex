defmodule NewYou.Commerce.PaystackTestIntegration do
  @moduledoc false

  if Mix.env() in [:dev, :test] do
    alias NewYou.Commerce.HostedDispatch
    alias Plug.Crypto.MessageEncryptor

    @derive {Inspect, only: []}
    defstruct [:attempt_id, :restricted_key, :email, :capability_key, :listener]

    def settings(attempt_id) when is_binary(attempt_id) do
      with %{
             attempt_id: ^attempt_id,
             restricted_key: credential,
             email: email,
             capability_key: <<_::256>>
           } = config <- configuration(),
           true <-
             is_binary(credential) and Regex.match?(~r/\Ark_test_[a-zA-Z0-9_-]+\z/, credential),
           {:ok, ^email} <- NewYou.Identity.Email.canonicalize(email) do
        {:ok, struct!(__MODULE__, config)}
      else
        _ -> {:error, :checkout_unavailable}
      end
    end

    def settings(_), do: {:error, :checkout_unavailable}

    # Finch can expose the raw request in event metadata. The owning checkout
    # emits a separate event containing only transport timing and classification.
    def transport_observers_safe?, do: :telemetry.list_handlers([:finch]) == []

    def seal(%HostedDispatch{} = attempt, url, key),
      do: MessageEncryptor.encrypt(url, capability_context(attempt), key, "")

    def unseal(%HostedDispatch{provider_capability: ciphertext} = attempt, key)
        when is_binary(ciphertext),
        do: MessageEncryptor.decrypt(ciphertext, capability_context(attempt), key, "")

    def unseal(_, _), do: :error

    defp capability_context(attempt) do
      :erlang.term_to_binary(
        {:paystack_hosted_checkout_v1, attempt.integration, attempt.environment,
         attempt.attempt_id, attempt.claim_id, attempt.reference, attempt.source_digest},
        [:deterministic]
      )
    end

    if Mix.env() == :test do
      defp configuration do
        case {System.get_env("NEW_YOU_PAYSTACK_TEST_ENABLED"),
              Application.get_env(:new_you, :paystack_test_checkout)} do
          {_, nil} ->
            approved_configuration()

          {enabled, %{listener: %{port: port, certificate: certificate}} = fixture}
          when enabled != "true" and port in 1..65_535 and
                 is_binary(certificate) and byte_size(certificate) in 1..8192 ->
            fixture

          _ ->
            :disabled
        end
      end
    else
      defp configuration, do: approved_configuration()
    end

    defp approved_configuration do
      with "true" <- System.get_env("NEW_YOU_PAYSTACK_TEST_ENABLED"),
           {:ok, key} <- Base.decode64(System.get_env("NEW_YOU_PAYSTACK_TEST_CAPABILITY_KEY", "")) do
        %{
          attempt_id: System.get_env("NEW_YOU_PAYSTACK_TEST_APPROVED_ATTEMPT_ID"),
          restricted_key: System.get_env("NEW_YOU_PAYSTACK_TEST_RESTRICTED_KEY"),
          email: System.get_env("NEW_YOU_PAYSTACK_TEST_EMAIL"),
          capability_key: key,
          listener: :paystack
        }
      else
        _ -> :disabled
      end
    end
  end
end
