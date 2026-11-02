defmodule NewYouWeb.RegistrationControllerTest do
  use NewYouWeb.ConnCase, async: true

  describe "GET /register" do
    test "renders the approved English P8-05 registration copy without locale fallback", %{conn: conn} do
      html = conn |> get("/register?locale=en") |> html_response(200)

      assert html =~ "Health and lifestyle support built around real life"
      assert html =~ "Create your Test Platform account"
      assert html =~ "First name"
      assert html =~ "Read the Terms and Conditions (English)"
      assert html =~
               "I accept the Test Platform Privacy Notice for registration. This is not consent to every processing purpose."

      assert html =~ ~s(name="registration[operation_id]")
      refute html =~ "Gesondheids- en leefstylondersteuning vir die werklike lewe"
    end

    test "renders the approved Afrikaans P8-05 registration copy without locale fallback", %{conn: conn} do
      html = conn |> get("/register?locale=af") |> html_response(200)

      assert html =~ "Gesondheids- en leefstylondersteuning vir die werklike lewe"
      assert html =~ "Skep jou Test Platform-rekening"
      assert html =~ "Voornaam"
      assert html =~ "Lees die Bepalings en Voorwaardes (Engels)"
      assert html =~
               "Ek aanvaar die Test Platform-privaatheidsbeleid vir registrasie. Dit is nie toestemming vir elke verwerkingsdoel nie."

      assert html =~ ~s(name="registration[operation_id]")
      refute html =~ "Health and lifestyle support built around real life"
    end
  end
end
