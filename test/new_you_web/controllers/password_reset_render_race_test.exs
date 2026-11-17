defmodule NewYouWeb.PasswordResetRenderRaceTest do
  use ExUnit.Case, async: false
  import Phoenix.ConnTest
  require Ash.Query

  alias NewYou.Identity
  alias NewYou.Audit.EvidenceObligation
  alias NewYou.Communications.MessageIntent
  alias NewYou.Content.PasswordResetBrowserCopy, as: Copy
  alias NewYou.Identity.{Account, Session, Token}
  alias NewYou.Proof.{P805, RegistrationSeam}

  @endpoint NewYouWeb.Endpoint
  @files ["well136-c02-v0.1.json", "well136-c02-owner-approval.json"]

  setup do
    root = Path.join(System.tmp_dir!(), "well136-render-race-#{Ecto.UUID.generate()}")
    File.mkdir_p!(Path.join(root, "docs/development/fixtures"))

    on_exit(fn -> File.rm_rf!(root) end)

    for file <- @files,
        do: File.cp!(Path.join("docs/development/fixtures", file), copy_path(root, file))

    Process.put({Copy, :evidence_root}, root)
    {:ok, root: root}
  end

  for {mutation, outcome} <- [
        {:request, :rollback},
        {:request, :commit},
        {:confirm, :rollback},
        {:confirm, :commit},
        {:confirm, :uncertain_commit}
      ] do
    @mutation mutation
    @commit? outcome != :rollback
    @uncertain? outcome == :uncertain_commit
    test "#{mutation} has a controlled copy-unavailable response after #{outcome}", %{
      root: root
    } do
      for {file, corruption} <- Enum.zip(@files, [:missing, :changed]), locale <- ["en", "af"] do
        path = copy_path(root, file)
        original = File.read!(path)

        P805.with_fixture(fn ->
          Application.put_env(:new_you, :fp001_development_entry, true)
          request = P805.request()
          {:ok, registration} = Identity.register(request)
          {:ok, :verified} = Identity.verify_email(registration.verification_proof)
          before = Ash.get!(Account, registration.account_id, authorize?: false)
          {:ok, credentials} = Identity.authenticate_password(request.email, request.password)
          session_before = Ash.get!(Session, credentials.session_id, authorize?: false)
          operation = operation()

          {route, params, initial_token, queued} =
            mutation_input(@mutation, request.email, before.id, locale, operation)

          # The existing Identity checkpoint is after all writes, before commit.
          # Returning commits; raising rolls every write back. Neither uses sleeps.
          Process.put(
            RegistrationSeam,
            {:observe,
             fn ->
               case corruption do
                 :missing -> File.rm!(path)
                 :changed -> File.write!(path, original <> "\n")
               end

               unless @commit?, do: raise("deterministic pre-commit interruption")
             end}
          )

          if @uncertain? do
            Process.put({RegistrationSeam, :reset_result}, fn result ->
              assert result == {:ok, :reset}
              Process.put(:render_race_committed_result_seen, true)
              raise "deterministic committed-result interruption"
            end)
          end

          response =
            try do
              post(build_conn(), route, params)
            rescue
              _ -> :uncontrolled_render_exception
            after
              Process.delete(RegistrationSeam)
              Process.delete({RegistrationSeam, :reset_result})
            end

          if @uncertain?, do: assert(Process.delete(:render_race_committed_result_seen) == true)

          # Check durable truth even in RED, when rendering currently raises.
          assert_consequences(
            @mutation,
            @commit?,
            before,
            session_before,
            initial_token,
            operation
          )

          assert_queued_unchanged(queued)
          assert response != :uncontrolled_render_exception
          assert response.status == 503
          assert response.resp_body == ""
          assert Plug.Conn.get_resp_header(response, "cache-control") == ["no-store"]
          assert Plug.Conn.get_resp_header(response, "referrer-policy") == ["no-referrer"]
          assert Plug.Conn.get_resp_header(response, "location") == []
          refute response.assigns[:current_account]

          # The same POST remains retryable once Content is eligible again. A lost
          # result never converts the durable receipt into another credential write.
          File.write!(path, original)
          recovered = post(build_conn(), route, params)
          assert recovered.status == 200
          assert recovered.resp_body =~ approved_result(@mutation, locale)
          assert_consequences(@mutation, true, before, session_before, initial_token, operation)
          stable = snapshot(before.id, operation)
          assert post(build_conn(), route, params).status == 200
          assert snapshot(before.id, operation) == stable

          assert_replay_rejected(@mutation, params)
          assert snapshot(before.id, operation) == stable
        end)
      end
    end
  end

  defp assert_replay_rejected(:request, _params), do: :ok

  defp assert_replay_rejected(:confirm, params) do
    assert {:error, :reset_unavailable} =
             Identity.reset_password(params.proof, params.password, operation())
  end

  defp assert_queued_unchanged(nil), do: :ok

  defp assert_queued_unchanged(queued),
    do: assert(Ash.get!(MessageIntent, queued.id, authorize?: false) == queued)

  defp mutation_input(:request, email, _account, locale, operation),
    do: {"/password/reset", %{email: email, locale: locale, operation_id: operation}, nil, nil}

  defp mutation_input(:confirm, email, account, locale, operation) do
    issuance = operation()
    :ok = Identity.request_password_reset(email, locale, issuance, :well136)
    token = proof(account)
    queued = intent(issuance)

    {:ok, {:ok, bearer}} =
      Ash.transact([Account, Token], fn ->
        Identity.password_reset_delivery(token.jti, email, locale)
      end)

    {"/password/reset/confirm",
     %{
       locale: locale,
       proof: bearer,
       password: "render race replacement password",
       operation_id: operation
     }, token, queued}
  end

  defp assert_consequences(:request, commit?, before, session, _token, operation) do
    assert Ash.get!(Account, before.id, authorize?: false) == before
    assert Ash.get!(Session, session.id, authorize?: false) == session
    assert audit(operation) == nil

    if commit? do
      token = proof(before.id)
      assert token != nil
      assert token.reset_request_id == operation
      assert intent(operation).source_reference == token.jti
      assert intent(operation).render_schema == "password-reset-well136-v1"
    else
      assert proof(before.id) == nil
      assert intent(operation) == nil
    end
  end

  defp assert_consequences(:confirm, commit?, before, session, token, operation) do
    current = Ash.get!(Account, before.id, authorize?: false)
    current_token = Ash.get!(Token, token.jti, authorize?: false)
    current_session = Ash.get!(Session, session.id, authorize?: false)

    if commit? do
      assert current.credential_version == before.credential_version + 1
      assert current.security_version == before.security_version + 1
      assert current.hashed_password != before.hashed_password
      assert current_token.purpose == "password_reset_consumed"
      assert current_token.reset_consumption_id == operation
      assert current_session.state == :revoked
      assert Ash.get!(Token, session.token_jti, authorize?: false).purpose == "revocation"
      assert audit(operation).evidence_type == :identity_password_reset
      assert audit(operation).outcome == :succeeded
    else
      assert current == before
      assert current_token == token
      assert current_session == session
      assert audit(operation) == nil
    end

    assert Ash.count!(Session |> Ash.Query.filter(account_id == ^before.id), authorize?: false) ==
             1
  end

  defp snapshot(account, operation),
    do: {
      Ash.get!(Account, account, authorize?: false),
      Token
      |> Ash.Query.filter(account_id == ^account)
      |> Ash.read!(authorize?: false)
      |> Enum.sort_by(& &1.jti),
      Session |> Ash.Query.filter(account_id == ^account) |> Ash.read!(authorize?: false),
      intent(operation),
      audit(operation)
    }

  defp proof(account),
    do:
      Token
      |> Ash.Query.filter(account_id == ^account and purpose == "password_reset")
      |> Ash.read_one!(authorize?: false)

  defp intent(operation),
    do:
      MessageIntent
      |> Ash.Query.filter(source_operation_id == ^operation and role == :password_reset)
      |> Ash.read_one!(authorize?: false)

  defp audit(operation),
    do:
      EvidenceObligation
      |> Ash.Query.filter(
        source_operation_id == ^operation and evidence_type == :identity_password_reset
      )
      |> Ash.read_one!(authorize?: false)

  defp copy_path(root, file), do: Path.join([root, "docs/development/fixtures", file])

  defp operation do
    id = Ecto.UUID.generate()
    P805.track_operation(id)
    id
  end

  defp approved_result(:request, "en"), do: "Check your email"
  defp approved_result(:request, "af"), do: "Gaan jou e-pos na"
  defp approved_result(:confirm, "en"), do: "Your password has been changed"
  defp approved_result(:confirm, "af"), do: "Jou wagwoord is gewysig"
end
