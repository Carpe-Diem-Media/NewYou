defmodule NewYou.Commerce.Paystack.TestCardsTest do
  use ExUnit.Case, async: true

  alias NewYou.Commerce.Paystack.TestCards

  test "includes the ten published scenarios with their exact synthetic card inputs" do
    published = %{
      no_validation: {"4084084084084081", "408", %{}},
      pin_validation: {"507850785078507812", "081", %{pin: "1111"}},
      pin_otp_validation: {"5060666666666666666", "123", %{pin: "1234", otp: "123456"}},
      pin_phone_otp_validation: {"507850785078507804", "884", %{pin: "0000", otp: "123456"}},
      bank_auth_simulation: {"5192602720584796", "123", %{}},
      declined: {"4084080000005408", "001", %{}},
      token_not_generated: {"507850785078507853", "082", %{pin: "0000"}},
      refund_failed: {"4084080000671803", "180", %{}},
      refund_needs_attention: {"4084080000671902", "190", %{}},
      insufficient_funds: {"4084080000670037", "787", %{}}
    }

    actual =
      Map.new(TestCards.all(), fn {id, card} ->
        {id, {card.number, card.cvv, Map.take(card, [:pin, :phone, :otp])}}
      end)

    assert actual == published
  end

  test "describes published validation, reusability and expected outcomes" do
    cards = TestCards.all()

    assert %{validation: [], reusable: true, expected: :success} = cards.no_validation
    assert %{validation: [:pin], expected: :success} = cards.pin_validation
    assert %{validation: [:pin, :otp], expected: :success} = cards.pin_otp_validation

    assert %{validation: [:pin, :phone, :otp], expected: :success} =
             cards.pin_phone_otp_validation

    assert %{validation: [:bank_auth], reusable: true, expected: :success} =
             cards.bank_auth_simulation

    assert %{expected: :declined} = cards.declined
    assert %{expected: :token_not_generated} = cards.token_not_generated
    assert %{expected: :success, expected_refund: :failed} = cards.refund_failed
    assert %{expected: :success, expected_refund: :needs_attention} = cards.refund_needs_attention
    assert %{expected: :insufficient_funds} = cards.insufficient_funds

    assert Enum.sort(for {id, %{reusable: _}} <- cards, do: id) ==
             [:bank_auth_simulation, :no_validation]
  end

  test "both lookups generate a future expiry from the current UTC month" do
    before = Date.utc_today()
    cards = TestCards.all()
    card = TestCards.fetch!(:no_validation)
    after_lookup = Date.utc_today()

    assert Map.delete(card, :expiry) == Map.delete(cards.no_validation, :expiry)

    for fixture <- [card | Map.values(cards)] do
      expiry = fixture.expiry
      assert %Date{day: 1} = expiry
      assert Date.after?(expiry, after_lookup)

      # A lookup on either side of UTC midnight is valid.
      assert {expiry.year, expiry.month} in [
               {before.year + 1, before.month},
               {after_lookup.year + 1, after_lookup.month}
             ]
    end
  end

  test "expiry advances to the new month and year at UTC year rollover" do
    december = TestCards.all(~D[2026-12-31])
    january = TestCards.all(~D[2027-01-01])

    assert Enum.uniq(for card <- Map.values(december), do: card.expiry) == [~D[2027-12-01]]
    assert Enum.uniq(for card <- Map.values(january), do: card.expiry) == [~D[2028-01-01]]
  end

  test "fetch! raises for an unknown fixture ID" do
    assert_raise KeyError, fn -> TestCards.fetch!(:unknown_fixture) end
  end
end
