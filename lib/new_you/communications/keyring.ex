defmodule NewYou.Communications.Keyring do
  @moduledoc false

  @typep keyring :: %{active: String.t(), keys: %{optional(String.t()) => binary()}}

  # Load a nonempty JSON version map of Base64-encoded 32-byte keys.
  # Reject the entire configuration if any entry or the active version is invalid.
  @spec from_environment(String.t() | nil, String.t() | nil) :: {:ok, keyring()} | :error
  def from_environment(active, encoded)
      when is_binary(active) and byte_size(active) > 0 and is_binary(encoded) do
    with {:ok, versions} when is_map(versions) and map_size(versions) > 0 <- Jason.decode(encoded),
         {:ok, keys} <- decode_keys(versions),
         true <- Map.has_key?(keys, active) do
      {:ok, %{active: active, keys: keys}}
    else
      _ -> :error
    end
  end

  def from_environment(_, _), do: :error

  defp decode_keys(versions) do
    Enum.reduce_while(versions, {:ok, %{}}, fn
      {version, encoded}, {:ok, acc}
      when is_binary(version) and byte_size(version) > 0 and is_binary(encoded) ->
        case Base.decode64(encoded) do
          {:ok, key} when byte_size(key) == 32 -> {:cont, {:ok, Map.put(acc, version, key)}}
          _ -> {:halt, :error}
        end

      _, _ ->
        {:halt, :error}
    end)
  end
end
