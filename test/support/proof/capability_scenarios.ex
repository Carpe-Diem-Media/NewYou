defmodule NewYou.Proof.VerificationCases do
  @moduledoc false
  import ExUnit.Assertions
  alias NewYou.Identity
  alias NewYou.Proof.P805

  def fail_closed() do
    P805.with_fixture(fn -> fail_closed_fixture() end)
  end

  defp fail_closed_fixture() do
    {:ok, registration} = Identity.register(P805.request())
    user = account(registration)

    {:ok, wrong, _} =
      AshAuthentication.Jwt.token_for_user(user, %{"purpose" => "account_recovery"},
        purpose: :account_recovery,
        authorize?: false
      )

    {:ok, expired, _} =
      AshAuthentication.Jwt.token_for_user(user, %{"purpose" => "email_verification"},
        purpose: :email_verification,
        token_lifetime: {-1, :seconds},
        authorize?: false
      )

    for proof <- [nil, "invalid", wrong, expired] do
      assert {:error, :verification_unavailable} = Identity.verify_email(proof)
      refute account(registration).email_verified?
    end

    assert :ok =
             AshAuthentication.TokenResource.Actions.revoke_jti(
               Identity.Token,
               token_jti(registration.verification_proof),
               AshAuthentication.user_to_subject(user),
               authorize?: false,
               context: %{ash_authentication: %{user: user}}
             )

    assert {:error, :verification_unavailable} =
             Identity.verify_email(registration.verification_proof)

    assert {:ok, :verification_pending} =
             Identity.resend_verification(%{
               operation_id: Ecto.UUID.generate(),
               account_id: user.id
             })

    refute account(registration).email_verified?

    assert {:error, :verification_unavailable} =
             Identity.verify_email(registration.verification_proof)
  end

  def account(registration) do
    Ash.get!(Identity.Account, registration.account_id, authorize?: false)
  end

  def run_case(id) do
    registration = Enum.find(NewYou.Proof.P807Catalog.registrations(), &(&1.case_id == id))
    manifest = Map.put(registration.manifest, :version, "p8-07.1")

    {result, cleanup} =
      NewYou.Proof.SelfTest.execute_registered_case(manifest, registration.callback)

    assert result["verdict"] == "PASS", inspect(result)
    assert Enum.all?(cleanup, fn {_key, value} -> value == true end), inspect(cleanup)
  end

  def token_jti(proof) do
    {:ok, claims} = AshAuthentication.Jwt.peek(proof)
    claims["jti"]
  end
end

defmodule NewYou.Proof.ResetCases do
  @moduledoc false
  import ExUnit.Assertions
  require Ash.Query
  alias NewYou.{Identity, Repo}
  alias NewYou.Identity.{Account, Token, Session}
  alias NewYou.Proof.P805

  def fail_closed() do
    P805.with_fixture(fn -> fail_closed_fixture() end)
  end

  defp fail_closed_fixture() do
    {request, registration} = account()
    initial = Ash.get!(Account, registration.account_id, authorize?: false)

    for disposition <- [:expired, :revoked, :superseded] do
      {proof, bearer} = issue(request, registration)

      case disposition do
        :expired ->
          Repo.query!(
            "UPDATE tokens SET expires_at = now() - interval '1 second' WHERE jti = $1",
            [proof.jti]
          )

        :revoked ->
          Repo.query!("UPDATE tokens SET purpose = 'revocation' WHERE jti = $1", [proof.jti])

        :superseded ->
          Identity.request_password_reset(request.email, "af", operation())
      end

      assert reset(bearer) == {:error, :reset_unavailable}
      assert delivery(proof, request.email) == {:error, :source_invalid}
      assert Ash.get!(Account, initial.id, authorize?: false) == initial
    end

    {_, bearer} = issue(request, registration)

    for password <- [nil, "", String.duplicate("a", 1025)] do
      assert Identity.reset_password(bearer, password, operation()) ==
               {:error, :reset_unavailable}
    end

    assert reset(bearer <> "x") == {:error, :reset_unavailable}
    assert reset(registration.verification_proof) == {:error, :reset_unavailable}
    :ok = Identity.request_magic_login(request.email, "af", operation())

    magic =
      Token
      |> Ash.Query.filter(account_id == ^initial.id and purpose == "magic_login")
      |> Ash.read_one!(authorize?: false)

    {:ok, {:ok, magic_bearer}} =
      Ash.transact([Account, Token], fn ->
        Identity.magic_login_delivery(magic.jti, request.email, "af")
      end)

    assert reset(magic_bearer) == {:error, :reset_unavailable}
    assert Identity.authenticate_magic_link(bearer) == {:error, :authentication_unavailable}
    assert Identity.verify_email(bearer) == {:error, :verification_unavailable}
    assert {:ok, :reset} = reset(bearer)
    assert reset(bearer) == {:error, :reset_unavailable}
  end

  def reset_security_snapshot(account_id) do
    obligation_ids = "SELECT id FROM evidence_obligations WHERE target_id = $1 OR actor_id = $1"

    for {table, where, order} <- [
          {"accounts", "id = $1", "id"},
          {"tokens", "account_id = $1", "jti"},
          {"sessions", "account_id = $1", "id"},
          {"device_assurances", "account_id = $1", "id"},
          {"registration_operations", "created_account_id = $1", "id"},
          {"evidence_obligations", "target_id = $1 OR actor_id = $1", "id"},
          {"evidence_records", "obligation_id IN (#{obligation_ids})", "id"},
          {"oban_jobs",
           "args->'primary_key'->>'id' IN (SELECT id::text FROM (#{obligation_ids}) obligations)",
           "id"}
        ],
        into: %{} do
      rows =
        Repo.query!(
          "SELECT row_to_json(snapshot)::text FROM #{table} snapshot WHERE #{where} ORDER BY #{order}",
          [Ecto.UUID.dump!(account_id)]
        ).rows

      {table, :crypto.hash(:sha256, :erlang.term_to_binary(rows, [:deterministic]))}
    end
  end

  def reset(bearer) do
    Identity.reset_password(bearer, "replacement", operation())
  end

  def account do
    request = P805.request()
    {:ok, result} = Identity.register(request)
    {:ok, :verified} = Identity.verify_email(result.verification_proof)
    {request, result}
  end

  def issue(request, registration) do
    :ok = Identity.request_password_reset(request.email, "af", operation())
    proof = current_proof(registration.account_id)
    {:ok, bearer} = delivery(proof, request.email)
    {proof, bearer}
  end

  def current_proof(id) do
    Token
    |> Ash.Query.filter(account_id == ^id and purpose == "password_reset")
    |> Ash.read_one!(authorize?: false)
  end

  def delivery(proof, email, locale \\ "af") do
    case Ash.transact([Account, Token], fn ->
           Identity.password_reset_delivery(proof.jti, email, locale)
         end) do
      {:ok, result} -> result
      _ -> {:error, :source_invalid}
    end
  end

  def operation do
    id = Ecto.UUID.generate()
    P805.track_operation(id)
    id
  end
end

defmodule NewYou.Proof.MagicCases do
  @moduledoc false
  import ExUnit.Assertions
  require Ash.Query
  alias Ecto.Adapters.SQL.Sandbox
  alias NewYou.Identity
  alias NewYou.Identity.{Account, Session, Token}
  alias NewYou.Proof.P805

  def fail_closed() do
    P805.with_fixture(fn -> fail_closed_fixture() end)
  end

  defp fail_closed_fixture() do
    {request, registration} = verified_account()

    for disposition <- [:expired, :revoked, :superseded] do
      operation = operation()
      proof = request_current_proof(request.email, registration.account_id, operation)
      bearer = delivery!(proof, request.email, "af")

      case disposition do
        :expired ->
          NewYou.Repo.query!(
            "UPDATE tokens SET expires_at = now() - interval '1 second' WHERE jti = $1",
            [proof.jti]
          )

        :revoked ->
          NewYou.Repo.query!("UPDATE tokens SET purpose = 'revocation' WHERE jti = $1", [
            proof.jti
          ])

        :superseded ->
          request_current_proof(request.email, registration.account_id, operation())
      end

      rejected = delivery_rejected?(proof.jti, request.email, "af")
      outcome = consume(bearer)
      assert rejected, "invalidated delivery proof was accepted"
      assert outcome == :denied, "invalidated magic proof created a Session"
    end

    operation = operation()
    proof = request_current_proof(request.email, registration.account_id, operation)
    bearer = delivery!(proof, request.email, "af")
    first = consume(bearer)
    replay = consume(bearer)
    assert first == :accepted, "current magic proof did not create a Session"
    assert replay == :denied, "consumed magic proof replay was accepted"
  end

  def verified_account do
    request = P805.request()
    {:ok, registration} = Identity.register(request)
    {:ok, :verified} = Identity.verify_email(registration.verification_proof)
    {request, registration}
  end

  def operation do
    id = Ecto.UUID.generate()
    P805.track_operation(id)
    id
  end

  def current_proof(account_id) do
    Token
    |> Ash.Query.filter(account_id == ^account_id and purpose == "magic_login")
    |> Ash.read_one!(authorize?: false)
  end

  def no_magic_proof?(account_id) do
    Token
    |> Ash.Query.filter(account_id == ^account_id and not is_nil(magic_request_id))
    |> Ash.read!(authorize?: false)
    |> Enum.empty?()
  end

  def current_purpose(jti) do
    NewYou.Repo.query!("SELECT purpose FROM tokens WHERE jti = $1", [jti]).rows
    |> case do
      [[purpose]] -> purpose
      _ -> nil
    end
  end

  def magic_proof_snapshot(jti) do
    NewYou.Repo.query!(
      "SELECT magic_request_id, purpose, expires_at, magic_claims, magic_account_binding, magic_locale, created_at, updated_at FROM tokens WHERE jti = $1",
      [jti]
    ).rows
  end

  def token_count_for_operation(operation) do
    P805.scalar("SELECT count(*) FROM tokens WHERE magic_request_id = $1", [
      Ecto.UUID.dump!(operation)
    ])
  end

  def session_count(account_id) do
    NewYou.Repo.query!("SELECT count(*) FROM sessions WHERE account_id = $1", [
      Ecto.UUID.dump!(account_id)
    ]).rows
    |> hd()
    |> hd()
  end

  def delivery!(proof, destination, locale) do
    case Ash.transact([Account, Token], fn ->
           Identity.magic_login_delivery(proof.jti, destination, locale)
         end) do
      {:ok, {:ok, bearer}} when is_binary(bearer) -> bearer
      {:ok, bearer} when is_binary(bearer) -> bearer
      _ -> raise "expected current magic-login delivery proof"
    end
  end

  def request_current_proof(email, account_id, operation_id) do
    proof =
      Enum.reduce_while(1..3, nil, fn _, _ ->
        Sandbox.unboxed_run(NewYou.Repo, fn ->
          :ok = Identity.request_magic_login(email, "af", operation_id)
        end)

        :ok = Sandbox.checkout(NewYou.Repo, sandbox: false)

        case current_proof(account_id) do
          %Token{magic_request_id: ^operation_id} = current -> {:halt, current}
          _ -> {:cont, nil}
        end
      end)

    assert match?(%Token{magic_request_id: ^operation_id}, proof),
           "request fixture did not commit the expected current magic proof"

    proof
  end

  def delivery_rejected?(jti, destination, locale) do
    case Ash.transact([Account, Token], fn ->
           Identity.magic_login_delivery(jti, destination, locale)
         end) do
      {:ok, {:ok, bearer}} when is_binary(bearer) -> false
      {:ok, bearer} when is_binary(bearer) -> false
      _ -> true
    end
  end

  def consume(bearer) do
    case Identity.authenticate_magic_link(bearer) do
      {:ok, %{session_id: session_id, token: token}}
      when is_binary(session_id) and is_binary(token) ->
        case Ash.get(Session, session_id, authorize?: false) do
          {:ok, %Session{}} -> :accepted
          _ -> :denied
        end

      _ ->
        :denied
    end
  end

  def alter_locale_claim(bearer) do
    [header, payload, signature] = String.split(bearer, ".")
    claims = payload |> Base.url_decode64!(padding: false) |> Jason.decode!()

    tampered =
      claims |> Map.put("locale", "en") |> Jason.encode!() |> Base.url_encode64(padding: false)

    Enum.join([header, tampered, signature], ".")
  end

  def value_for("email", value, _original) do
    value
  end

  def value_for(_column, _value, original) do
    original
  end
end

defmodule NewYou.Proof.VerificationScannerCases do
  @moduledoc false
  import ExUnit.Assertions
  import Phoenix.ConnTest
  import Plug.Conn
  alias NewYou.Identity
  alias NewYou.Proof.{P805, PassiveEvidence}
  @endpoint NewYouWeb.Endpoint
  def scanner() do
    for locale <- ["en", "af"] do
      P805.with_fixture(fn -> scanner_fixture(locale) end)
    end
  end

  defp scanner_fixture(locale) do
    {:ok, registration} = Identity.register(P805.request())
    before = P805.counts()
    owner_before = PassiveEvidence.snapshot(registration.account_id)

    url =
      "/verification/confirm?" <>
        URI.encode_query(%{proof: registration.verification_proof, locale: locale})

    for {method, headers} <- [
          get: [],
          head: [],
          get: [{"purpose", "prefetch"}],
          get: [{"sec-purpose", "prefetch;prerender"}],
          get: [{"user-agent", "MailScanner/1.0 link-preview"}]
        ] do
      request =
        Enum.reduce(headers, build_conn(), fn {k, v}, conn -> put_req_header(conn, k, v) end)

      conn = dispatch(request, @endpoint, method, url)
      assert conn.status == 200
      assert before == P805.counts()
      assert :ok = PassiveEvidence.assert_unchanged!(registration.account_id, owner_before)
      assert :ok = PassiveEvidence.assert_response!(conn)
      refute account(registration).email_verified?
      assert :ok = no_login(conn)
      assert get_resp_header(conn, "referrer-policy") == ["no-referrer"]
      assert get_resp_header(conn, "cache-control") == ["no-store"]
    end

    page = get(build_conn(), url)
    assert :ok = PassiveEvidence.assert_unchanged!(registration.account_id, owner_before)
    assert :ok = PassiveEvidence.assert_response!(page)
    [_, csrf] = Regex.run(~r/name="_csrf_token"[^>]*value="([^"]+)"/, page.resp_body)

    missing =
      build_conn()
      |> put_private(:plug_skip_csrf_protection, false)
      |> post("/verification/confirm", %{proof: registration.verification_proof, locale: locale})

    assert missing.status == 403
    refute account(registration).email_verified?

    confirmed =
      page
      |> recycle()
      |> put_private(:plug_skip_csrf_protection, false)
      |> post("/verification/confirm", %{
        proof: registration.verification_proof,
        locale: locale,
        _csrf_token: csrf
      })

    assert confirmed.status == 200
    assert account(registration).email_verified?
    refute confirmed.resp_body =~ registration.verification_proof
    assert :ok = no_login(confirmed)
    assert PassiveEvidence.snapshot(registration.account_id).sessions == owner_before.sessions
    assert before == P805.counts()
  end

  def account(registration) do
    Ash.get!(Identity.Account, registration.account_id, authorize?: false)
  end

  def no_login(conn) do
    assert Enum.all?(Map.keys(get_session(conn)), &(&1 == "_csrf_token"))
    :ok
  end
end

defmodule NewYou.Proof.ResetScannerCases do
  @moduledoc false
  import ExUnit.Assertions
  import Phoenix.ConnTest
  import Plug.Conn
  alias NewYou.Identity
  alias NewYou.Identity.{Account, Token}
  alias NewYou.Proof.{P805, PassiveEvidence}
  require Ash.Query
  @endpoint NewYouWeb.Endpoint
  def scanner() do
    P805.with_fixture(fn -> scanner_fixture() end)
  end

  defp scanner_fixture() do
    request = P805.request()
    {:ok, registration} = Identity.register(request)
    {:ok, :verified} = Identity.verify_email(registration.verification_proof)
    {:ok, credentials} = Identity.authenticate_password(request.email, request.password)
    :ok = Identity.request_password_reset(request.email, "af", operation())

    proof =
      Token
      |> Ash.Query.filter(account_id == ^registration.account_id and purpose == "password_reset")
      |> Ash.read_one!(authorize?: false)

    {:ok, {:ok, bearer}} =
      Ash.transact([Account, Token], fn ->
        Identity.password_reset_delivery(proof.jti, request.email, "af")
      end)

    url = "/password/reset/confirm?" <> URI.encode_query(%{proof: bearer, locale: "af"})
    before = snapshot(registration.account_id)

    for {method, headers} <- [
          get: [],
          head: [],
          get: [{"purpose", "prefetch"}],
          get: [{"sec-purpose", "prefetch;prerender"}],
          get: [{"user-agent", "MailScanner/1.0 link-preview"}]
        ] do
      conn = Enum.reduce(headers, build_conn(), fn {k, v}, c -> put_req_header(c, k, v) end)
      response = dispatch(conn, @endpoint, method, url)
      assert response.status == 200
      assert get_resp_header(response, "cache-control") == ["no-store"]
      assert get_resp_header(response, "referrer-policy") == ["no-referrer"]
      assert snapshot(registration.account_id) == before
      assert :ok = PassiveEvidence.assert_response!(response)
    end

    page = get(build_conn(), url)
    assert snapshot(registration.account_id) == before
    assert :ok = PassiveEvidence.assert_response!(page)
    csrf = field(page, "_csrf_token")
    operation = field(page, "operation_id")
    P805.track_operation(operation)

    bad =
      build_conn()
      |> put_private(:plug_skip_csrf_protection, false)
      |> post("/password/reset/confirm", %{
        locale: "af",
        proof: bearer,
        password: "replacement",
        operation_id: operation
      })

    assert bad.status == 403
    assert snapshot(registration.account_id) == before

    response =
      page
      |> recycle()
      |> put_private(:plug_skip_csrf_protection, false)
      |> post("/password/reset/confirm", %{
        locale: "af",
        proof: bearer,
        password: "replacement",
        operation_id: operation,
        _csrf_token: csrf
      })

    assert response.status == 200
    assert get_session(response, :identity_session_id) == nil
    assert get_session(response, :identity_token) == nil
    assert Identity.authorize_session(credentials) == {:error, :authentication_unavailable}
    assert {:ok, _} = Identity.authenticate_password(request.email, "replacement")
  end

  def field(page, name) do
    [_, value] = Regex.run(~r/name="#{name}"[^>]*value="([^"]+)"/, page.resp_body)
    value
  end

  def operation do
    id = Ecto.UUID.generate()
    P805.track_operation(id)
    id
  end

  def snapshot(id) do
    NewYou.Repo.query!("SELECT row_to_json(a)::text FROM accounts a WHERE id = $1", [
      Ecto.UUID.dump!(id)
    ]).rows ++
      NewYou.Repo.query!(
        "SELECT row_to_json(t)::text FROM tokens t WHERE account_id = $1 ORDER BY jti",
        [Ecto.UUID.dump!(id)]
      ).rows ++
      NewYou.Repo.query!(
        "SELECT row_to_json(s)::text FROM sessions s WHERE account_id = $1 ORDER BY id",
        [Ecto.UUID.dump!(id)]
      ).rows
  end
end

defmodule NewYou.Proof.MagicScannerCases do
  @moduledoc false
  import ExUnit.Assertions
  import Phoenix.ConnTest
  import Plug.Conn
  alias NewYou.Identity
  alias NewYou.Proof.{P805, PassiveEvidence}
  alias NewYou.Identity.Token
  require Ash.Query
  @endpoint NewYouWeb.Endpoint
  def scanner() do
    P805.with_fixture(fn -> scanner_fixture() end)
  end

  defp scanner_fixture() do
    proof = magic_proof("af")
    url = "/login/magic/confirm?" <> URI.encode_query(%{proof: proof, locale: "af"})
    {:ok, claims} = Joken.peek_claims(proof)
    account_id = Ash.get!(Token, claims["jti"], authorize?: false).account_id
    before = PassiveEvidence.snapshot(account_id)
    page = get(build_conn(), url)
    assert :ok = PassiveEvidence.assert_response!(page)
    assert :ok = PassiveEvidence.assert_unchanged!(account_id, before)
    [_, csrf] = Regex.run(~r/name="_csrf_token"[^>]*value="([^"]+)"/, page.resp_body)

    for {method, headers} <- [
          get: [],
          head: [],
          get: [{"purpose", "prefetch"}],
          get: [{"sec-purpose", "prefetch;prerender"}],
          get: [{"user-agent", "MailScanner/1.0 link-preview"}]
        ] do
      request =
        Enum.reduce(headers, build_conn(), fn {key, value}, conn ->
          put_req_header(conn, key, value)
        end)

      conn = dispatch(request, @endpoint, method, url)
      assert conn.status == 200

      if method == :get do
        assert conn.resp_body =~ NewYouWeb.MagicLoginCopy.text!("confirm.title", "af")
        assert conn.resp_body =~ ~s(value="#{proof}")
      end

      assert :ok = PassiveEvidence.assert_unchanged!(account_id, before)
      assert :ok = PassiveEvidence.assert_response!(conn)
      assert get_resp_header(conn, "cache-control") == ["no-store"]
      assert get_resp_header(conn, "referrer-policy") == ["no-referrer"]
      assert :ok = no_identity_session(conn)
    end

    confirmation =
      page
      |> recycle()
      |> put_private(:plug_skip_csrf_protection, false)
      |> post("/login/magic/confirm", %{proof: proof, locale: "af", _csrf_token: csrf})

    assert confirmation.status == 303
  end

  def no_identity_session(conn) do
    assert Enum.all?(Map.keys(get_session(conn)), &(&1 == "_csrf_token"))
    :ok
  end

  def magic_proof(locale) do
    request = P805.request()
    {:ok, registration} = Identity.register(request)
    {:ok, :verified} = Identity.verify_email(registration.verification_proof)
    operation_id = Ecto.UUID.generate()
    P805.track_operation(operation_id)
    :ok = Identity.request_magic_login(request.email, locale, operation_id)

    token =
      Token
      |> Ash.Query.filter(account_id == ^registration.account_id and purpose == "magic_login")
      |> Ash.read_one!(authorize?: false)

    {:ok, {:ok, proof}} =
      Ash.transact([NewYou.Identity.Account, Token], fn ->
        Identity.magic_login_delivery(token.jti, request.email, locale)
      end)

    proof
  end
end
