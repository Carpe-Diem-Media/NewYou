defmodule NewYouWeb.OrdinaryPasswordResetTest do
  use ExUnit.Case, async: false
  import Phoenix.ConnTest
  @endpoint NewYouWeb.Endpoint

  setup do
    keys = [:fp001_development_entry, :p8_12_browser_development_fixtures]
    previous = Map.new(keys, &{&1, Application.get_env(:new_you, &1)})
    Application.put_env(:new_you, :fp001_development_entry, true)
    Application.put_env(:new_you, :p8_12_browser_development_fixtures, false)

    on_exit(fn ->
      Enum.each(previous, fn {key, value} ->
        if is_nil(value),
          do: Application.delete_env(:new_you, key),
          else: Application.put_env(:new_you, key, value)
      end)
    end)

    :ok
  end

  test "real login exposes the approved reset journey with legacy flags off" do
    for {locale, link, title} <- [
          {"en", "Forgot your password?", "Reset your password"},
          {"af", "Wagwoord vergeet?", "Wysig jou wagwoord"}
        ] do
      login = get(build_conn(), "/login?locale=#{locale}")
      assert login.status == 200
      assert login.resp_body =~ link
      assert login.resp_body =~ "/password/reset?locale=#{locale}"
      request = get(build_conn(), "/password/reset?locale=#{locale}")
      assert request.status == 200
      assert request.resp_body =~ title
      assert request.resp_body =~ "/login?locale=#{locale}"
    end
  end

  test "unavailable Content context shows the exact service message for every address" do
    root = Path.join(System.tmp_dir!(), "well136-unavailable-#{Ecto.UUID.generate()}")
    File.mkdir_p!(root)
    File.cp_r!("docs", Path.join(root, "docs"))

    path =
      Path.join(
        root,
        "docs/delivery/content-evidence/content_media/password_reset_messages/PASSWORD_RESET_MESSAGE_WELL136_PHASE9_ELIGIBILITY_v0.3.0.json"
      )

    File.rm!(path)
    Process.put({NewYou.Content.PasswordResetMessage, :evidence_root}, root)

    try do
      for {locale, message} <- [
            {"en", "Password reset isn&#39;t available right now. Please try again later."},
            {"af", "Jy kan nie tans jou wagwoord wysig nie. Probeer asseblief later weer."}
          ] do
        page = get(build_conn(), "/password/reset?locale=#{locale}")
        assert page.status == 503
        assert page.resp_body =~ message

        for email <- ["unknown@example.test", "invalid"] do
          response =
            post(build_conn(), "/password/reset", %{
              locale: locale,
              email: email,
              operation_id: Ecto.UUID.generate()
            })

          assert response.status == 503
          assert response.resp_body == page.resp_body
        end
      end
    after
      Process.delete({NewYou.Content.PasswordResetMessage, :evidence_root})
      File.rm_rf!(root)
    end
  end

  test "confirmation rejects proof locale tampering without consuming it" do
    NewYou.Proof.P805.with_fixture(fn ->
      request = NewYou.Proof.P805.request()
      {:ok, registration} = NewYou.Identity.register(request)
      assert {:ok, :verified} = NewYou.Identity.verify_email(registration.verification_proof)
      operation = Ecto.UUID.generate()
      NewYou.Proof.P805.track_operation(operation)
      assert :ok = NewYou.Identity.request_password_reset(request.email, "en", operation)
      require Ash.Query

      proof =
        NewYou.Identity.Token
        |> Ash.Query.filter(
          account_id == ^registration.account_id and purpose == "password_reset"
        )
        |> Ash.read_one!(authorize?: false)

      {:ok, {:ok, bearer}} =
        Ash.transact([NewYou.Identity.Account, NewYou.Identity.Token], fn ->
          NewYou.Identity.password_reset_delivery(proof.jti, request.email, "en")
        end)

      response =
        post(build_conn(), "/password/reset/confirm", %{
          locale: "af",
          proof: bearer,
          password: "replacement ordinary password",
          operation_id: Ecto.UUID.generate()
        })

      assert response.status == 200
      assert response.resp_body =~ "Jou wagwoord kan nie gewysig word nie"

      assert Ash.get!(NewYou.Identity.Token, proof.jti, authorize?: false).purpose ==
               "password_reset"
    end)
  end

  test "unconfirmed reset exceptions render the approved uncertain result" do
    NewYou.Proof.P805.with_fixture(fn ->
      request = NewYou.Proof.P805.request()
      {:ok, registration} = NewYou.Identity.register(request)
      {:ok, :verified} = NewYou.Identity.verify_email(registration.verification_proof)
      operation = Ecto.UUID.generate()
      NewYou.Proof.P805.track_operation(operation)
      :ok = NewYou.Identity.request_password_reset(request.email, "en", operation)
      require Ash.Query

      proof =
        NewYou.Identity.Token
        |> Ash.Query.filter(
          account_id == ^registration.account_id and purpose == "password_reset"
        )
        |> Ash.read_one!(authorize?: false)

      {:ok, {:ok, bearer}} =
        Ash.transact([NewYou.Identity.Account, NewYou.Identity.Token], fn ->
          NewYou.Identity.password_reset_delivery(proof.jti, request.email, "en")
        end)

      confirmation = Ecto.UUID.generate()
      NewYou.Proof.P805.track_operation(confirmation)

      Process.put(
        NewYou.Proof.RegistrationSeam,
        {:observe, fn -> raise "synthetic reset interruption" end}
      )

      try do
        response =
          post(build_conn(), "/password/reset/confirm", %{
            locale: "en",
            proof: bearer,
            password: "uncertain replacement",
            operation_id: confirmation
          })

        assert response.status == 200
        assert response.resp_body =~ "We couldn&#39;t confirm the result"
        refute response.resp_body =~ "Your password has been changed"

        assert Ash.get!(NewYou.Identity.Token, proof.jti, authorize?: false).purpose ==
                 "password_reset"
      after
        Process.delete(NewYou.Proof.RegistrationSeam)
      end
    end)
  end
end
