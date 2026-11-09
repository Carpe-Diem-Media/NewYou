defmodule NewYou.Security.PasswordRevocationRegressionTest do
  use ExUnit.Case, async: false

  alias NewYou.Security.PasswordRevocationTest.{Token, User}

  test "non-atomic password change revokes all prior target tokens and preserves another user" do
    target = user("target@example.test")
    control = user("control@example.test")
    target_tokens = for _ <- 1..3, do: token(target)
    control_token = token(control)

    for bearer <- target_tokens ++ [control_token] do
      assert {:ok, _, _} = AshAuthentication.Jwt.verify(bearer, User)
      assert authenticated_user(bearer).id in [target.id, control.id]
    end

    assert {:ok, updated} = change_password(target, "replacement-password")
    assert Argon2.verify_pass("replacement-password", updated.hashed_password)

    for bearer <- target_tokens do
      assert AshAuthentication.TokenResource.token_revoked?(Token, bearer)
      assert :error = AshAuthentication.Jwt.verify(bearer, User)
      assert authenticated_user(bearer) == nil
    end

    refute AshAuthentication.TokenResource.token_revoked?(Token, control_token)
    assert {:ok, _, _} = AshAuthentication.Jwt.verify(control_token, User)
    assert authenticated_user(control_token).id == control.id

    strategy = AshAuthentication.Info.strategy!(User, :log_out_everywhere)

    for _ <- 1..2 do
      assert :ok =
               AshAuthentication.Strategy.action(
                 strategy,
                 :log_out_everywhere,
                 %{user: updated},
                 []
               )
    end

    assert authenticated_user(control_token).id == control.id
  end

  test "invalid password update and non-password update preserve existing tokens" do
    target = user("unchanged@example.test")
    bearer = token(target)
    assert {:error, _} = change_password(target, nil)

    assert {:ok, updated} =
             target
             |> Ash.Changeset.for_update(:change_email, %{email: "changed@example.test"})
             |> Ash.update()

    assert updated.hashed_password == target.hashed_password
    refute AshAuthentication.TokenResource.token_revoked?(Token, bearer)
    assert {:ok, _, _} = AshAuthentication.Jwt.verify(bearer, User)
  end

  test "token presence rejects an unstored or tampered bearer" do
    target = user("presence@example.test")

    {:ok, unstored, _} =
      Joken.generate_and_sign(
        AshAuthentication.Jwt.Config.default_claims(User),
        %{"sub" => AshAuthentication.user_to_subject(target)},
        AshAuthentication.Jwt.Config.token_signer(User)
      )

    assert {:ok, _, _} = AshAuthentication.Jwt.verify(unstored, User)
    assert authenticated_user(unstored) == nil
    assert authenticated_user(token(target) <> "tampered") == nil
  end

  defp authenticated_user(bearer) do
    Plug.Test.conn(:get, "/")
    |> Plug.Conn.put_req_header("authorization", "Bearer " <> bearer)
    |> AshAuthentication.Plug.Helpers.retrieve_from_bearer(User)
    |> Map.fetch!(:assigns)
    |> Map.get(:current_user)
  end

  defp user(email) do
    User
    |> Ash.Changeset.for_create(:create, %{email: email, password: "initial-password"})
    |> Ash.create!()
  end

  defp token(user) do
    {:ok, bearer, _} = AshAuthentication.Jwt.token_for_user(user)
    bearer
  end

  defp change_password(user, password) do
    user |> Ash.Changeset.for_update(:change_password, %{password: password}) |> Ash.update()
  end
end
