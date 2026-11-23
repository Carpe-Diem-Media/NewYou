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

  @doc """
  Pass a transient payload to the compile-time adapter after invocation fencing.
  TEST callbacks can return arbitrary values or fail. The executor normalizes
  unrecognized results to `:unknown`. Disabled builds return `:unknown`.
  """
  @spec invoke(
          NewYou.Communications.DeliveryAttempt.t(),
          %NewYou.Communications.DeliveryPayload{}
        ) ::
          term()
  def invoke(attempt, payload), do: adapter().invoke(attempt, payload)

  @doc """
  Run an optional TEST checkpoint in the calling process. The callback can
  interrupt execution. With no callback or outside TEST, this returns `:ok`.
  """
  def checkpoint(point), do: adapter().checkpoint(point)

  @doc "Verify evidence for the bound attempt, outcome and reference. Outside TEST this returns false."
  @spec authenticated?(Ecto.UUID.t(), atom(), String.t(), binary()) :: boolean()
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
