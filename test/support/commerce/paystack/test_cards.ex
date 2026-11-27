defmodule NewYou.Commerce.Paystack.TestCards do
  @moduledoc """
  Paystack's published synthetic card scenarios for test fixtures.

  Source: https://paystack.com/docs/payments/test-payments/#cards
  Verified on 2026-11-27.

  The fixture values are strings to preserve leading zeroes. Optional fields
  appear only where Paystack publishes the corresponding value or behavior.
  The phone challenge has no published phone value. Refund fixtures describe
  a successful payment followed by the specified refund outcome.

  Lookups calculate expiry from the current UTC month. This module is compiled
  only in the Mix test environment and performs no provider operations.
  """

  @type card :: %{
          required(:number) => String.t(),
          required(:cvv) => String.t(),
          required(:expiry) => Date.t(),
          required(:expected) =>
            :success | :declined | :token_not_generated | :insufficient_funds,
          optional(:validation) => [:pin | :phone | :otp | :bank_auth],
          optional(:reusable) => true,
          optional(:pin) => String.t(),
          optional(:otp) => String.t(),
          optional(:expected_refund) => :failed | :needs_attention
        }

  @cards %{
    no_validation: %{
      number: "4084084084084081",
      cvv: "408",
      validation: [],
      reusable: true,
      expected: :success
    },
    pin_validation: %{
      number: "507850785078507812",
      cvv: "081",
      pin: "1111",
      validation: [:pin],
      expected: :success
    },
    pin_otp_validation: %{
      number: "5060666666666666666",
      cvv: "123",
      pin: "1234",
      otp: "123456",
      validation: [:pin, :otp],
      expected: :success
    },
    pin_phone_otp_validation: %{
      number: "507850785078507804",
      cvv: "884",
      pin: "0000",
      otp: "123456",
      validation: [:pin, :phone, :otp],
      expected: :success
    },
    bank_auth_simulation: %{
      number: "5192602720584796",
      cvv: "123",
      validation: [:bank_auth],
      reusable: true,
      expected: :success
    },
    declined: %{number: "4084080000005408", cvv: "001", expected: :declined},
    token_not_generated: %{
      number: "507850785078507853",
      cvv: "082",
      pin: "0000",
      expected: :token_not_generated
    },
    refund_failed: %{
      number: "4084080000671803",
      cvv: "180",
      expected: :success,
      expected_refund: :failed
    },
    refund_needs_attention: %{
      number: "4084080000671902",
      cvv: "190",
      expected: :success,
      expected_refund: :needs_attention
    },
    insufficient_funds: %{number: "4084080000670037", cvv: "787", expected: :insufficient_funds}
  }

  @doc """
  Returns the fixture for `id` with a fresh expiry. Raises `KeyError` for unknown IDs.
  """
  @spec fetch!(atom()) :: card()
  def fetch!(id), do: @cards |> Map.fetch!(id) |> Map.put(:expiry, expiry())

  @doc "Returns the fixtures keyed by scenario ID, with one expiry date for the catalogue."
  @spec all() :: %{atom() => card()}
  def all do
    expiry = expiry()
    Map.new(@cards, fn {id, card} -> {id, Map.put(card, :expiry, expiry)} end)
  end

  defp expiry do
    today = Date.utc_today()
    Date.new!(today.year + 1, today.month, 1)
  end
end
