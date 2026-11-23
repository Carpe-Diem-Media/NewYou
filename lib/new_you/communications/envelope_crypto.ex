defmodule NewYou.Communications.EnvelopeCrypto do
  @moduledoc false

  @typep binding :: {binary(), binary(), binary()}
  @typep envelope :: %{nonce: binary(), ciphertext: binary(), tag: binary()}
  @typep decrypt_envelope :: envelope() | NewYou.Communications.ProtectedEnvelope.t()
  @typep invalid_envelope :: {:error, :invalid_envelope}

  # Communications reserves the nonce for this key version before encrypting.
  # Intent, source and purpose are authenticated with the ciphertext.
  @spec encrypt(binary(), binding(), binary(), binary()) :: {:ok, envelope()} | invalid_envelope()
  def encrypt(key, {intent, source, purpose}, bearer, nonce)
      when is_binary(key) and byte_size(key) == 32 and is_binary(intent) and
             is_binary(source) and is_binary(purpose) and is_binary(bearer) and
             byte_size(bearer) > 0 and is_binary(nonce) and byte_size(nonce) == 12 do
    aad =
      :erlang.term_to_binary({:verification_envelope_v1, intent, source, purpose}, [
        :deterministic
      ])

    {ciphertext, tag} =
      :crypto.crypto_one_time_aead(:aes_256_gcm, key, nonce, bearer, aad, 16, true)

    {:ok, %{nonce: nonce, ciphertext: ciphertext, tag: tag}}
  rescue
    _ -> {:error, :invalid_envelope}
  end

  def encrypt(_, _, _, _), do: {:error, :invalid_envelope}

  # A malformed envelope, wrong binding or failed authentication all fail closed.
  @spec decrypt(binary(), binding(), decrypt_envelope()) :: {:ok, binary()} | invalid_envelope()
  def decrypt(
        key,
        {intent, source, purpose} = binding,
        %{nonce: nonce, ciphertext: ciphertext, tag: tag} = envelope
      )
      when is_binary(key) and byte_size(key) == 32 do
    if valid_binding?(binding) and valid_envelope?(envelope) do
      decrypt_authenticated(key, intent, source, purpose, nonce, ciphertext, tag)
    else
      {:error, :invalid_envelope}
    end
  end

  def decrypt(_, _, _), do: {:error, :invalid_envelope}

  defp decrypt_authenticated(key, intent, source, purpose, nonce, ciphertext, tag) do
    aad =
      :erlang.term_to_binary({:verification_envelope_v1, intent, source, purpose}, [
        :deterministic
      ])

    case :crypto.crypto_one_time_aead(:aes_256_gcm, key, nonce, ciphertext, aad, tag, false) do
      :error -> {:error, :invalid_envelope}
      plaintext when is_binary(plaintext) -> {:ok, plaintext}
    end
  rescue
    _ -> {:error, :invalid_envelope}
  end

  defp valid_binding?({intent, source, purpose}),
    do: is_binary(intent) and is_binary(source) and is_binary(purpose)

  defp valid_envelope?(%{nonce: nonce, ciphertext: ciphertext, tag: tag}),
    do:
      is_binary(nonce) and byte_size(nonce) == 12 and is_binary(tag) and byte_size(tag) == 16 and
        is_binary(ciphertext) and byte_size(ciphertext) > 0

  # Read with the recorded version only, including during key rotation.
  @spec decrypt_versioned(
          %{optional(String.t()) => binary()},
          String.t(),
          binding(),
          decrypt_envelope()
        ) :: {:ok, binary()} | invalid_envelope()
  def decrypt_versioned(keys, version, binding, envelope)
      when is_map(keys) and is_binary(version) do
    case Map.fetch(keys, version) do
      {:ok, key} -> decrypt(key, binding, envelope)
      :error -> {:error, :invalid_envelope}
    end
  end

  def decrypt_versioned(_, _, _, _), do: {:error, :invalid_envelope}
end
