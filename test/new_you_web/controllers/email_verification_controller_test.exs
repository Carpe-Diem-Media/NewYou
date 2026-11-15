defmodule NewYouWeb.EmailVerificationControllerTest do
  use ExUnit.Case, async: false
  import NewYou.Proof.VerificationScannerCases
  import Phoenix.ConnTest
  import ExUnit.CaptureLog

  alias NewYou.Identity
  alias NewYou.Proof.P805
  @endpoint NewYouWeb.Endpoint

  test "bearers are absent from logs, endpoint telemetry, ordinary rows and job arguments" do
    P805.with_fixture(fn ->
      {:ok, registration} = Identity.register(P805.request())
      parent = self()
      handler = "p807-#{System.unique_integer([:positive])}"

      :ok =
        :telemetry.attach_many(
          handler,
          [[:phoenix, :endpoint, :start], [:phoenix, :endpoint, :stop]],
          fn event, _, metadata, _ -> send(parent, {:p807_telemetry, event, metadata}) end,
          nil
        )

      try do
        logs =
          capture_log([level: :debug], fn ->
            url =
              "/verification/confirm?" <>
                URI.encode_query(%{proof: registration.verification_proof, locale: "en"})

            get(build_conn(), url)

            post(build_conn(), "/verification/confirm", %{
              proof: registration.verification_proof,
              locale: "en"
            })

            post(build_conn(), "/verification/confirm", %{
              proof: registration.verification_proof,
              locale: "en"
            })
          end)

        refute String.contains?(logs, registration.verification_proof)

        for _ <- 1..6 do
          assert_receive {:p807_telemetry, _event, metadata}
          refute String.contains?(inspect(metadata), registration.verification_proof)
        end

        for resource <- [
              Identity.Account,
              Identity.Token,
              Identity.RegistrationOperation,
              Identity.ResendOperation,
              NewYou.Communications.MessageIntent,
              NewYou.Audit.EvidenceObligation,
              NewYou.Audit.EvidenceRecord
            ] do
          records = Ash.read!(resource, authorize?: false)
          # term_to_binary also inspects fields deliberately hidden by Inspect.
          refute :binary.match(:erlang.term_to_binary(records), registration.verification_proof) !=
                   :nomatch
        end

        refute :binary.match(
                 :erlang.term_to_binary(NewYou.Repo.all(Oban.Job)),
                 registration.verification_proof
               ) != :nomatch

        filtered? =
          Phoenix.Logger.filter_values(%{"proof" => registration.verification_proof})["proof"] ==
            "[FILTERED]"

        assert filtered?
      after
        :telemetry.detach(handler)
      end
    end)
  end

  setup do
    previous = Application.get_env(:new_you, :p8_07_browser_development_fixtures)
    Application.put_env(:new_you, :p8_07_browser_development_fixtures, "p8-07-temporary-v1")

    on_exit(fn ->
      if previous,
        do: Application.put_env(:new_you, :p8_07_browser_development_fixtures, previous),
        else: Application.delete_env(:new_you, :p8_07_browser_development_fixtures)
    end)
  end

  test "GET, HEAD, previews, scanners and prefetch are passive; real CSRF POST verifies EN/AF" do
    NewYou.Proof.VerificationScannerCases.scanner()
  end

  test "disabled fixtures, unsupported locale, provider requests and public invalid results fail safely" do
    P805.with_fixture(fn ->
      {:ok, registration} = Identity.register(P805.request())
      assert get(build_conn(), "/verification/confirm?locale=zz").status == 404

      assert post(build_conn(), "/verification/provider", %{
               proof: registration.verification_proof
             }).status == 404

      invalid = post(build_conn(), "/verification/confirm", %{proof: "invalid", locale: "en"})
      assert invalid.status == 200
      refute account(registration).email_verified?
      Application.delete_env(:new_you, :p8_07_browser_development_fixtures)
      assert get(build_conn(), "/verification/confirm?locale=en").status == 404

      assert post(build_conn(), "/verification/confirm", %{
               proof: registration.verification_proof,
               locale: "en"
             }).status == 404

      refute account(registration).email_verified?
    end)
  end

  test "a stale confirmation page cannot bypass a current security hold or fixture eligibility" do
    P805.with_fixture(fn ->
      {:ok, registration} = Identity.register(P805.request())

      url =
        "/verification/confirm?" <>
          URI.encode_query(%{proof: registration.verification_proof, locale: "af"})

      page = get(build_conn(), url)
      assert page.status == 200

      NewYou.Repo.query!("UPDATE accounts SET security_posture = 'held' WHERE id = $1", [
        Ecto.UUID.dump!(registration.account_id)
      ])

      result =
        post(build_conn(), "/verification/confirm", %{
          proof: registration.verification_proof,
          locale: "af"
        })

      assert result.status == 200

      assert result.resp_body =~
               NewYouWeb.VerificationCopy.text!(
                 "identity.verification.result.unavailable.title",
                 "af"
               )

      refute account(registration).email_verified?
      Application.put_env(:new_you, :p8_07_browser_development_fixtures, "unknown-version")
      assert get(build_conn(), url).status == 404
      Application.put_env(:new_you, :p8_07_browser_development_fixtures, "p8-07-temporary-v1")
      previous = Application.get_env(:new_you, :verification_development_fixtures)

      try do
        Application.put_env(:new_you, :verification_development_fixtures, false)
        assert get(build_conn(), url).status == 404
      after
        Application.put_env(:new_you, :verification_development_fixtures, previous)
      end
    end)
  end
end
