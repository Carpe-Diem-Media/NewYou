defmodule NewYou.Communications.ScopeTest do
  use ExUnit.Case, async: true

  test "Communications keeps exactly two business Resources and its existing technical stores" do
    assert Enum.sort(Ash.Domain.Info.resources(NewYou.Communications)) ==
             Enum.sort([
               NewYou.Communications.MessageIntent,
               NewYou.Communications.DeliveryAttempt,
               NewYou.Communications.ProtectedEnvelope,
               NewYou.Communications.EnvelopeNonce
             ])

    assert AshOban in Spark.extensions(NewYou.Communications.MessageIntent)

    for resource <- [
          NewYou.Communications.ProtectedEnvelope,
          NewYou.Communications.EnvelopeNonce,
          NewYou.Communications.DeliveryAttempt
        ] do
      refute AshOban in Spark.extensions(resource)
    end

    action = Ash.Resource.Info.action(NewYou.Communications.MessageIntent, :execute_delivery)
    refute action.transaction?
  end
end
