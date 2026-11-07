defmodule NewYou.Identity.MfaVaultTest do
  use ExUnit.Case, async: false
  alias NewYou.Identity.MfaVault

  setup do
    previous = Application.fetch_env(:new_you, :identity_mfa_keyring)

    on_exit(fn ->
      case previous do
        {:ok, value} -> Application.put_env(:new_you, :identity_mfa_keyring, value)
        :error -> Application.delete_env(:new_you, :identity_mfa_keyring)
      end
    end)

    :ok
  end

  test "maintained authenticated encryption randomises ciphertext and supports explicit key rotation" do
    first = :crypto.strong_rand_bytes(32)
    second = :crypto.strong_rand_bytes(32)
    put_keyring("v1", %{"v1" => first})
    plaintext = :crypto.strong_rand_bytes(20)
    old = MfaVault.encrypt!(plaintext)
    refute old == MfaVault.encrypt!(plaintext)
    assert MfaVault.decrypt!(old) == plaintext
    refute String.contains?(old, plaintext)

    put_keyring("v2", %{"v1" => first, "v2" => second})
    current = MfaVault.encrypt!(plaintext)
    assert <<"NYMFA1", 2, "v2", "XCP.", _::binary>> = current
    assert MfaVault.decrypt!(old) == plaintext
    assert MfaVault.decrypt!(current) == plaintext

    put_keyring("v2", %{"v2" => second})
    assert_raise ArgumentError, "MFA vault unavailable", fn -> MfaVault.decrypt!(old) end
  end

  test "purpose/version and ciphertext tampering fail without exposing payload or key" do
    key = :crypto.strong_rand_bytes(32)
    put_keyring("v1", %{"v1" => key, "v2" => key})
    encrypted = MfaVault.encrypt!(:crypto.strong_rand_bytes(20))
    <<"NYMFA1", 2, "v1", sealed::binary>> = encrypted
    changed_version = "NYMFA1" <> <<2>> <> "v2" <> sealed

    assert_raise ArgumentError, "MFA vault unavailable", fn ->
      MfaVault.decrypt!(changed_version)
    end

    <<prefix::binary-size(18), byte, tail::binary>> = encrypted
    tampered = prefix <> <<Bitwise.bxor(byte, 1)>> <> tail
    assert_raise ArgumentError, "MFA vault unavailable", fn -> MfaVault.decrypt!(tampered) end
  end

  test "missing and malformed runtime keyrings fail closed" do
    Application.delete_env(:new_you, :identity_mfa_keyring)
    assert_raise ArgumentError, "MFA vault unavailable", fn -> MfaVault.encrypt!("synthetic") end

    for keyring <- [
          %{},
          %{active_version: "v1", keys: %{}},
          %{active_version: "v1", keys: %{"v1" => <<0>>}}
        ] do
      Application.put_env(:new_you, :identity_mfa_keyring, keyring)

      assert_raise ArgumentError, "MFA vault unavailable", fn ->
        MfaVault.encrypt!("synthetic")
      end
    end

    assert_raise ArgumentError, "MFA vault unavailable", fn -> MfaVault.decrypt!("malformed") end

    assert_raise ArgumentError, "MFA vault unavailable", fn ->
      MfaVault.decrypt!(:binary.copy("x", 16_385))
    end
  end

  defp put_keyring(active, keys),
    do:
      Application.put_env(:new_you, :identity_mfa_keyring, %{active_version: active, keys: keys})
end
