defmodule NewYou.Proof.DeliveryAdapter do
  @moduledoc false
  def available?, do: is_function(Process.get(:p810_provider), 2)
  def invoke(attempt, payload), do: Process.get(:p810_provider).(attempt, payload)
  def checkpoint(point), do: NewYou.Proof.DeliverySeam.checkpoint(point)

  def authenticated?(attempt_id, outcome, evidence_ref, signature) do
    key = Application.get_env(:new_you, :communications_proof_evidence_key)

    if is_binary(key) and byte_size(key) >= 32 and is_binary(signature) and
         byte_size(signature) == 32 do
      expected =
        :crypto.mac(
          :hmac,
          :sha256,
          key,
          attempt_id <> "|" <> to_string(outcome) <> "|" <> evidence_ref
        )

      Plug.Crypto.secure_compare(expected, signature)
    else
      false
    end
  end
end
