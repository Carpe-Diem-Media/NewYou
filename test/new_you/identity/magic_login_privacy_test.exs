defmodule NewYou.Identity.MagicLoginPrivacyTest do
  use ExUnit.Case, async: false
  import Phoenix.ConnTest
  import ExUnit.CaptureLog
  require Ash.Query

  alias NewYou.{Communications, Identity}
  alias NewYou.Identity.{Account, Token}
  alias NewYou.Proof.P805
  @endpoint NewYouWeb.Endpoint

  test "bearers stay out of ordinary records, id-only jobs, logs and request telemetry" do
    P805.with_fixture(fn ->
      request = P805.request()
      {:ok, registration} = Identity.register(request)
      {:ok, :verified} = Identity.verify_email(registration.verification_proof)
      operation_id = Ecto.UUID.generate()
      P805.track_operation(operation_id)
      :ok = Identity.request_magic_login(request.email, "af", operation_id)

      proof =
        Token
        |> Ash.Query.filter(magic_request_id == ^operation_id)
        |> Ash.read_one!(authorize?: false)

      {:ok, {:ok, bearer}} =
        Ash.transact([Account, Token], fn ->
          Identity.magic_login_delivery(proof.jti, request.email, "af")
        end)

      intent =
        Communications.MessageIntent
        |> Ash.Query.filter(source_reference == ^proof.jti)
        |> Ash.read_one!(authorize?: false)

      handler = "magic-login-privacy-#{System.unique_integer([:positive])}"
      reference = make_ref()
      previous = Application.fetch_env(:new_you, :p8_09_browser_development_fixtures)
      Application.put_env(:new_you, :p8_09_browser_development_fixtures, true)

      events = [
        [:phoenix, :endpoint, :start],
        [:phoenix, :endpoint, :stop],
        [:phoenix, :router_dispatch, :start],
        [:phoenix, :router_dispatch, :stop]
      ]

      :ok = :telemetry.attach_many(handler, events, &__MODULE__.observe/4, {self(), reference})

      try do
        log =
          capture_log([level: :debug], fn ->
            page =
              get(
                build_conn(),
                "/login/magic/confirm?" <> URI.encode_query(%{locale: "af", proof: bearer})
              )

            assert page.status == 200

            authenticated =
              post(build_conn(), "/login/magic/confirm", %{locale: "af", proof: bearer})

            assert authenticated.status == 303
            failed = post(build_conn(), "/login/magic/confirm", %{locale: "af", proof: bearer})
            assert failed.status == 200
          end)

        observations = telemetry(reference, [])
        assert length(observations) >= 6
        log_leaked? = String.contains?(log, bearer)
        telemetry_leaked? = String.contains?(inspect(observations, limit: :infinity), bearer)
        refute log_leaked?
        refute telemetry_leaked?

        trigger = AshOban.Info.oban_trigger(Communications.MessageIntent, :delivery)
        assert :ok = trigger.scheduler.perform(%Oban.Job{args: %{}})

        for table <-
              ~w(tokens sessions message_intents delivery_attempts evidence_obligations evidence_records oban_jobs) do
          rows = NewYou.Repo.query!("SELECT row_to_json(r)::text FROM #{table} r").rows
          persisted? = String.contains?(inspect(rows, limit: :infinity), bearer)
          refute persisted?, "bearer persisted in #{table}"
        end

        assert [] ==
                 Ash.read!(
                   Ash.Query.filter(
                     Communications.ProtectedEnvelope,
                     message_intent_id == ^intent.id
                   ),
                   authorize?: false
                 )
      after
        :telemetry.detach(handler)

        case previous do
          {:ok, value} ->
            Application.put_env(:new_you, :p8_09_browser_development_fixtures, value)

          :error ->
            Application.delete_env(:new_you, :p8_09_browser_development_fixtures)
        end
      end
    end)
  end

  def observe(event, _measurements, metadata, {parent, reference}),
    do: send(parent, {reference, event, metadata})

  defp telemetry(reference, acc) do
    receive do
      {^reference, event, metadata} -> telemetry(reference, [{event, metadata} | acc])
    after
      0 -> acc
    end
  end
end
