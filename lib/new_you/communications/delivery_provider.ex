defmodule NewYou.Communications.DeliveryProvider do
  @moduledoc """
  Fail-closed provider boundary. No production vendor or egress is configured.
  TEST builds alone can use the existing deterministic P8-04 provider machinery.
  A future provider requires its own governed authorization and authenticated
  evidence adapter. Runtime configuration cannot enable a production sender.
  """
  @adapter if Mix.env() == :test,
             do: NewYou.Proof.DeliveryAdapter,
             else: NewYou.Communications.DisabledProvider

  def available?, do: adapter().available?()
  def invoke(attempt, payload), do: adapter().invoke(attempt, payload)
  def checkpoint(point), do: adapter().checkpoint(point)

  def authenticated?(id, outcome, reference, signature),
    do: adapter().authenticated?(id, outcome, reference, signature)

  defp adapter, do: @adapter
end

defmodule NewYou.Communications.DisabledProvider do
  @moduledoc false
  def available?, do: false
  def invoke(_, _), do: :unknown
  def checkpoint(_), do: :ok
  def authenticated?(_, _, _, _), do: false
end
