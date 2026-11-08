defmodule NewYou.Identity.MfaVault do
  @moduledoc false

  # AshCloak's vault callbacks use the authenticated encryptor already supplied
  # by Phoenix. Purpose and key version are authenticated, never caller inputs.
  @prefix "NYMFA1"
  @purpose "newyou:identity:mfa:v1:"

  @spec encrypt!(binary()) :: binary()
  def encrypt!(plaintext) when is_binary(plaintext) and byte_size(plaintext) <= 4096 do
    %{active_version: version, keys: keys} = keyring!()
    key = Map.fetch!(keys, version)
    sealed = Plug.Crypto.MessageEncryptor.encrypt(plaintext, @purpose <> version, key, "")
    @prefix <> <<byte_size(version)>> <> version <> sealed
  rescue
    _ -> unavailable!()
  end

  def encrypt!(_), do: unavailable!()

  @spec decrypt!(binary()) :: binary()
  def decrypt!(ciphertext) when is_binary(ciphertext) and byte_size(ciphertext) <= 16_384 do
    with <<@prefix, size, rest::binary>> <- ciphertext,
         true <- size in 1..32,
         <<version::binary-size(^size), "XCP.", _::binary>> <- rest,
         %{keys: keys} <- keyring!(),
         {:ok, key} <- Map.fetch(keys, version),
         sealed <- binary_part(rest, size, byte_size(rest) - size),
         {:ok, plaintext} <-
           Plug.Crypto.MessageEncryptor.decrypt(sealed, @purpose <> version, key, "") do
      plaintext
    else
      _ -> unavailable!()
    end
  rescue
    _ -> unavailable!()
  end

  def decrypt!(_), do: unavailable!()

  defp keyring! do
    case Application.get_env(:new_you, :identity_mfa_keyring) do
      %{active_version: active, keys: keys} = keyring
      when is_binary(active) and is_map(keys) and map_size(keys) in 1..8 ->
        if Map.has_key?(keys, active) and Enum.all?(keys, &valid_key?/1),
          do: keyring,
          else: unavailable!()

      _ ->
        unavailable!()
    end
  end

  defp valid_key?({version, key}) do
    is_binary(version) and byte_size(version) in 1..32 and
      Regex.match?(~r/\A[a-zA-Z0-9_-]+\z/, version) and is_binary(key) and byte_size(key) == 32
  end

  defp unavailable!, do: raise(ArgumentError, "MFA vault unavailable")
end
