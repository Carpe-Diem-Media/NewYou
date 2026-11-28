defmodule NewYou.Proof.PlanPaymentObservation do
  @moduledoc false
  @signing_key :crypto.strong_rand_bytes(32)

  @enforce_keys [:fields, :signature]
  defstruct [:fields, :signature]
  @type t :: %__MODULE__{fields: map(), signature: binary()}

  @doc false
  def produce(fields) when is_map(fields) do
    %__MODULE__{fields: fields, signature: sign(fields)}
  end

  @doc false
  def verify(%__MODULE__{fields: fields, signature: signature}) when is_map(fields) do
    if is_binary(signature) and byte_size(signature) == 32 and
         :crypto.hash_equals(signature, sign(fields)) do
      {:ok, fields}
    else
      {:error, :unqualified}
    end
  end

  def verify(_), do: {:error, :unqualified}

  defp sign(fields), do: :crypto.mac(:hmac, :sha256, @signing_key, :erlang.term_to_binary(fields))
end
