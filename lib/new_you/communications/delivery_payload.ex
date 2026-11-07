defmodule NewYou.Communications.DeliveryPayload do
  @moduledoc false
  # Even test failures or accidental inspection must not print transient secrets.
  @derive {Inspect, only: []}
  defstruct [:destination, :body]
end
