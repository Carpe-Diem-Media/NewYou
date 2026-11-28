defmodule NewYou.Commerce.PaystackTestIntegration do
  @moduledoc false

  if Mix.env() == :test do
    alias NewYou.Commerce.HostedDispatch
    alias Plug.Crypto.MessageEncryptor

    def settings(attempt_id) when is_binary(attempt_id) do
      with %{
             attempt_id: ^attempt_id,
             restricted_key: credential,
             email: email,
             capability_key: encryption_key,
             listener: listener
           } = config <- configuration(),
           true <-
             is_binary(credential) and Regex.match?(~r/\Ark_test_[a-zA-Z0-9_-]+\z/, credential),
           true <- valid_email?(email),
           true <- is_binary(encryption_key) and byte_size(encryption_key) == 32,
           true <- valid_listener?(listener) do
        {:ok, config}
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

    defp configuration do
      case Application.get_env(:new_you, :paystack_test_checkout) do
        %{listener: %{port: _, certificate: _}} = fixture -> fixture
        nil -> approved_configuration()
        _ -> :disabled
      end
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

    defp valid_email?(email) when is_binary(email) and byte_size(email) in 3..254,
      do: Regex.match?(~r/\A[A-Za-z0-9.!_%+-]+@[A-Za-z0-9.-]+\.[A-Za-z0-9-]+\z/, email)

    defp valid_email?(_), do: false

    defp valid_listener?(:paystack), do: true

    defp valid_listener?(%{port: port, certificate: certificate})
         when port in 1..65_535 and is_binary(certificate) and byte_size(certificate) in 1..8192,
         do: true

    defp valid_listener?(_), do: false
  end
end
