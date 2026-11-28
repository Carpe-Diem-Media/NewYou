defmodule NewYou.Commerce.PaystackTestIntegrationTest do
  use ExUnit.Case, async: false

  alias NewYou.Commerce.PaystackTestIntegration

  @attempt "1179dc31-72bc-4f01-a2cd-78f59ccd45ac"
  @credential "rk_test_restricted_canary"
  @email "private-customer-canary@example.test"
  @key :binary.copy(<<119>>, 32)
  @enabled "NEW_YOU_PAYSTACK_TEST_ENABLED"
  @approved "NEW_YOU_PAYSTACK_TEST_APPROVED_ATTEMPT_ID"
  @restricted "NEW_YOU_PAYSTACK_TEST_RESTRICTED_KEY"
  @email_setting "NEW_YOU_PAYSTACK_TEST_EMAIL"
  @capability "NEW_YOU_PAYSTACK_TEST_CAPABILITY_KEY"

  setup do
    valid = %{
      @enabled => "true",
      @approved => @attempt,
      @restricted => @credential,
      @email_setting => @email,
      @capability => Base.encode64(@key)
    }

    prior = Map.new(valid, fn {key, _} -> {key, System.get_env(key)} end)
    previous_config = Application.fetch_env(:new_you, :paystack_test_checkout)
    Application.delete_env(:new_you, :paystack_test_checkout)
    System.put_env(valid)

    on_exit(fn ->
      for {key, value} <- prior, do: restore(key, value)

      case previous_config do
        {:ok, settings} -> Application.put_env(:new_you, :paystack_test_checkout, settings)
        :error -> Application.delete_env(:new_you, :paystack_test_checkout)
      end
    end)

    %{valid: valid}
  end

  test "the real runtime path validates exact activation and redacts its values", %{valid: valid} do
    assert {:ok, settings} = PaystackTestIntegration.settings(@attempt)
    assert settings.listener == :paystack
    assert settings.restricted_key == @credential
    assert settings.email == @email
    assert settings.capability_key == @key

    for secret <- [@credential, @email, @attempt, @key, Base.encode64(@key)] do
      refute inspect(settings) =~ secret
    end

    assert {:error, :checkout_unavailable} =
             PaystackTestIntegration.settings("3dce6b9f-686f-4e86-a424-e5018e8110b0")

    for {setting, invalid} <- [
          {@enabled, nil},
          {@enabled, "false"},
          {@approved, nil},
          {@restricted, nil},
          {@restricted, "rk_live_canary"},
          {@restricted, "sk_test_unrestricted_canary"},
          {@restricted, "rk_test_x y"},
          {@email_setting, nil},
          {@email_setting, "invalid\nemail"},
          {@email_setting, "email@."},
          {@email_setting, "noncanonical@example.TEST"},
          {@capability, nil},
          {@capability, "invalid*base64"},
          {@capability, Base.encode64(<<0>>)}
        ] do
      restore(setting, invalid)
      assert {:error, :checkout_unavailable} = PaystackTestIntegration.settings(@attempt)
      System.put_env(setting, Map.fetch!(valid, setting))
    end
  end

  test "a fixture listener and explicit provider activation cannot share configuration" do
    Application.put_env(:new_you, :paystack_test_checkout, %{
      attempt_id: @attempt,
      restricted_key: @credential,
      email: @email,
      capability_key: @key,
      listener: %{port: 1, certificate: <<0>>}
    })

    assert {:error, :checkout_unavailable} = PaystackTestIntegration.settings(@attempt)

    System.delete_env(@enabled)
    assert {:ok, %{listener: %{port: 1}}} = PaystackTestIntegration.settings(@attempt)
  end

  defp restore(key, nil), do: System.delete_env(key)
  defp restore(key, value), do: System.put_env(key, value)
end
