defmodule NewYou.Proof.Well156Browser do
  @moduledoc false
  @behaviour Plug

  import ExUnit.Assertions
  import Plug.Conn

  alias NewYou.{Identity, Repo}
  alias NewYou.Identity.Account
  alias NewYou.Proof.{P805, P805Browser, P813HoldFixture}

  def run(locale) do
    P813HoldFixture.with_fixture(fn fixture ->
      previous = Application.fetch_env(:new_you, :well156_primary_email_change_proof_policy)

      Application.put_env(:new_you, :well156_primary_email_change_proof_policy, %{
        delay_seconds: 120,
        requires_review?: true
      })

      try do
        run_fixture(locale, fixture)
      after
        case previous do
          {:ok, policy} ->
            Application.put_env(:new_you, :well156_primary_email_change_proof_policy, policy)

          :error ->
            Application.delete_env(:new_you, :well156_primary_email_change_proof_policy)
        end
      end
    end)
  end

  defp run_fixture(locale, fixture) do
    target = P805.request().email
    account = P805.account!(fixture.target.id)
    request = %{email: account.email, password: fixture.target.password}

    operations =
      Map.new([:cancel, :expire, :apply, :hold], fn kind ->
        id = Ecto.UUID.generate()
        P805.track_operation(id)
        {kind, id}
      end)

    {:ok, server} =
      Bandit.start_link(
        plug: {__MODULE__, {fixture, operations, request.email, target, locale}},
        ip: {127, 0, 0, 1},
        port: 0
      )

    try do
      {:ok, {_, port}} = ThousandIsland.listener_info(server)
      assert_browser(locale, request, port, operations, target)

      assert %{
               email: ^target,
               security_posture: :held,
               primary_email_change_state: :held
             } = P805.account!(account.id)
    after
      Supervisor.stop(server)
    end
  end

  defp assert_browser(locale, request, port, operations, target) do
    payload =
      Jason.encode!(%{
        mode: "ordinary_email_change",
        port: port,
        locale: locale,
        email: request.email,
        password: request.password,
        target: target,
        operations: operations
      })

    result =
      P805Browser.run_port(
        System.find_executable("node"),
        Path.expand("../../proof/p8_05_browser.mjs", __DIR__),
        payload
      )

    assert result["cleanup"]

    for check <- ~w(entry stylesheet keyboard_focus reflow text_resize reduced_motion
                    accessible_form rejected error_focus error_layout requested reauthentication_label cancelled expired
                    pending confirm confirmed replay_unavailable delayed review reviewed review_layout
                    applied fresh_sign_in held_denial held_confirmation held_login) do
      assert result["checks"][check] == true, "WELL-156 browser check failed: #{check}"
    end
  end

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, {fixture, operations, original, target, locale}) do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo, sandbox: false)

    try do
      dispatch(conn, fixture, operations, original, target, locale)
    after
      Ecto.Adapters.SQL.Sandbox.checkin(Repo)
    end
  end

  defp dispatch(conn, fixture, operations, original, target, locale) do
    case {conn.method, conn.request_path} do
      {"GET", "/__well156/proof/" <> id} when id in [operations.apply, operations.hold] ->
        destination = if id == operations.apply, do: target, else: original
        proof(conn, fixture.target.id, id, destination, locale)

      {"POST", "/__well156/due/" <> id} when id == operations.apply ->
        change_deadline(conn, fixture.target.id, id, :due)

      {"POST", "/__well156/expire/" <> id} when id == operations.expire ->
        change_deadline(conn, fixture.target.id, id, :expire)

      {"POST", "/__well156/hold/" <> id} when id == operations.hold ->
        assert %{
                 primary_email_change_operation_id: ^id,
                 primary_email_change_state: :new_address_pending
               } =
                 P805.account!(fixture.target.id)

        assert {:ok, :ok} = P813HoldFixture.step_up(fixture.actor, :place_security_hold)

        assert {:ok, %{status: :held}} =
                 Identity.place_security_hold(P813HoldFixture.request(fixture, :place, 0))

        send_resp(conn, 204, "")

      _ ->
        NewYouWeb.Endpoint.call(conn, NewYouWeb.Endpoint.init([]))
    end
  end

  # Scope synthetic time to this Account, operation and live state. The browser
  # can exercise the real predicates without sleeping through a policy delay.
  defp change_deadline(conn, account_id, id, kind) do
    {column, state} =
      case kind do
        :due -> {"primary_email_change_apply_after", "delayed"}
        :expire -> {"primary_email_change_expires_at", "requested"}
      end

    assert %{num_rows: 1} =
             Repo.query!(
               """
               UPDATE accounts SET #{column} = NOW() - interval '1 second'
               WHERE id = $1 AND primary_email_change_operation_id = $2
                 AND primary_email_change_state = $3
               """,
               [Ecto.UUID.dump!(account_id), Ecto.UUID.dump!(id), state]
             )

    if kind == :expire do
      assert {:ok, :expired} = Identity.expire_primary_email_change(id)
    end

    send_resp(conn, 204, "")
  end

  # Loopback test fixture reads only the seeded Account's held proof. The
  # application never exposes this endpoint or sends the email to a provider.
  defp proof(conn, account_id, operation_id, target, locale) do
    assert %{
             primary_email_change_operation_id: ^operation_id,
             primary_email_change_token_jti: jti
           } =
             Ash.get!(Account, account_id, authorize?: false)

    assert {:ok, {:ok, bearer}} =
             Repo.transaction(fn ->
               Identity.primary_email_change_delivery(jti, target, locale)
             end)

    conn
    |> put_resp_header("cache-control", "no-store")
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{proof: bearer}))
  end
end
