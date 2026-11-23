defmodule NewYouWeb.ReconciliationController do
  @moduledoc false
  use NewYouWeb, :controller

  alias NewYou.Identity
  alias NewYouWeb.ReconciliationHTML

  @state_salt "operator-reconciliation-state-v1"
  @control_salt "operator-reconciliation-control-v1"
  @max_age 300

  plug :require_current_session

  def show(conn, _params), do: page(conn, :start)

  def submit(%{body_params: %{"intent" => intent} = body} = conn, _params) do
    case perform(intent, body, credentials(conn), conn) do
      {:case, record, grants} ->
        case_page(conn, record, grants)

      {:confirm, request, pair} ->
        state = seal(conn, request, @state_salt)
        page(conn, :confirm, state: state, pair: pair)

      {:control, proof} ->
        page(conn, :control, proof: proof)

      _ ->
        unavailable(conn)
    end
  end

  def submit(conn, _params), do: unavailable(conn)

  defp perform("detect", body, credentials, _conn) do
    with {:ok, grants} <- grants(body),
         {:ok, candidate} <- Ecto.UUID.cast(body["candidate_id"]),
         {:ok, canonical} <- Ecto.UUID.cast(body["canonical_id"]),
         {:ok, operation} <- Ecto.UUID.cast(body["operation_id"]),
         :ok <- step_up(credentials, body, :review_reconciliation),
         {:ok, record} <-
           Identity.open_reconciliation(
             Map.merge(grants, %{
               credentials: credentials,
               candidate_id: candidate,
               canonical_id: canonical,
               operation_id: operation,
               detection_basis: :reported_duplicate
             })
           ) do
      {:case, record, grants}
    end
  end

  defp perform("resume", body, credentials, _conn) do
    with {:ok, grants} <- grants(body),
         {:ok, case_id} <- Ecto.UUID.cast(body["case_id"]),
         :ok <- step_up(credentials, body, :review_reconciliation),
         {:ok, record} <-
           Identity.reconciliation_status(
             Map.merge(grants, %{credentials: credentials, case_id: case_id})
           ) do
      {:case, record, grants}
    end
  end

  defp perform("control", body, credentials, conn) do
    with {:ok, case_id} <- Ecto.UUID.cast(body["case_id"]),
         {:ok, binding} <- Identity.reconciliation_control_binding(credentials, case_id) do
      {:control, Phoenix.Token.encrypt(conn, @control_salt, {binding, credentials})}
    end
  end

  defp perform("review", body, credentials, conn) do
    with {:ok, %{status: _} = request} <- unseal(conn, body["state"], credentials.session_id),
         {:ok, decision} <- review_decision(body["decision"]),
         {:ok, controls} <- controls(conn, decision, body, request),
         {:ok, record} <-
           Identity.review_reconciliation(
             request
             |> Map.take([:case_id, :expected_version, :grant_id, :canonical_grant_id])
             |> Map.merge(%{credentials: credentials, decision: decision, controls: controls})
           ) do
      {:case, record, Map.take(request, [:grant_id, :canonical_grant_id])}
    end
  end

  defp perform("prepare", body, credentials, conn) do
    with {:ok, %{status: :approved} = state} <-
           unseal(conn, body["state"], credentials.session_id),
         :ok <- step_up(credentials, body, :apply_reconciliation),
         request = apply_request(state, credentials.session_id),
         :ok <- Identity.prepare_reconciliation_apply(Map.put(request, :credentials, credentials)) do
      {:confirm, request, state.pair}
    end
  end

  defp perform("apply", body, credentials, conn) do
    with {:ok, %{operation_id: _} = request} <-
           unseal(conn, body["state"], credentials.session_id),
         {:ok, %{status: :applied} = record} <-
           Identity.apply_reconciliation(Map.put(request, :credentials, credentials)) do
      {:case, record, %{}}
    end
  end

  defp perform(_, _, _, _), do: :error

  defp review_decision("candidate"), do: {:ok, :candidate}
  defp review_decision("review"), do: {:ok, :review}
  defp review_decision("approved"), do: {:ok, :approved}
  defp review_decision("conflict"), do: {:ok, :conflict}
  defp review_decision("rejected"), do: {:ok, :rejected}
  defp review_decision(_), do: :error

  defp controls(conn, :approved, body, request) do
    binding = {request.case_id, request.expected_version}

    with {:ok, {^binding, candidate}} <- decrypt(conn, @control_salt, body["candidate_control"]),
         {:ok, {^binding, canonical}} <- decrypt(conn, @control_salt, body["canonical_control"]) do
      {:ok, [candidate, canonical]}
    else
      _ -> :error
    end
  end

  defp controls(_conn, _decision, _body, _request), do: {:ok, []}

  defp grants(body) do
    with {:ok, candidate} <- Ecto.UUID.cast(body["grant_id"]),
         {:ok, canonical} <- Ecto.UUID.cast(body["canonical_grant_id"]) do
      {:ok, %{grant_id: candidate, canonical_grant_id: canonical}}
    end
  end

  defp step_up(credentials, %{"password" => password, "code" => code}, purpose)
       when is_binary(password) and byte_size(password) in 1..1024 do
    case Identity.step_up_privileged(credentials, password, code, purpose) do
      {:ok, :ok} -> :ok
      _ -> :error
    end
  end

  defp step_up(_, _, _), do: :error

  defp apply_request(state, session_id) do
    request = Map.take(state, [:case_id, :expected_version, :grant_id, :canonical_grant_id])

    # A reconfirmation for the same session, pair of grants and review version
    # retries the same owner operation, including after a lost response.
    binding = {:browser_reconciliation_apply_v1, session_id, request}
    <<uuid::binary-size(16), _::binary>> = :crypto.hash(:sha256, :erlang.term_to_binary(binding))
    Map.put(request, :operation_id, Ecto.UUID.load!(uuid))
  end

  defp case_page(conn, %{status: status} = record, grants) do
    state =
      if status not in [:applied, :rejected] do
        seal(
          conn,
          Map.merge(grants, %{
            case_id: record.id,
            status: status,
            expected_version: record.version,
            pair: {record.candidate_id, record.canonical_id}
          }),
          @state_salt
        )
      end

    page(conn, :case, state: state, reference: record.id, status: status)
  end

  defp seal(conn, state, salt) do
    Phoenix.Token.encrypt(conn, salt, {credentials(conn).session_id, state})
  end

  defp unseal(conn, token, session_id) do
    case decrypt(conn, @state_salt, token) do
      {:ok, {^session_id, state}} -> {:ok, state}
      _ -> :error
    end
  end

  defp decrypt(conn, salt, token) when is_binary(token) and byte_size(token) in 1..8192,
    do: Phoenix.Token.decrypt(conn, salt, token, max_age: @max_age)

  defp decrypt(_, _, _), do: :error

  defp require_current_session(conn, _opts) do
    with true <- NewYouWeb.DevelopmentEntry.enabled?(),
         {:ok, _} <- Identity.authorize_session(credentials(conn)) do
      conn
    else
      _ -> conn |> send_resp(404, "") |> halt()
    end
  end

  defp credentials(conn) do
    %{
      session_id: get_session(conn, :identity_session_id),
      token: get_session(conn, :identity_token)
    }
  end

  defp unavailable(conn), do: page(put_status(conn, :forbidden), :unavailable)

  defp page(conn, view, assigns \\ []) do
    conn
    |> put_resp_header(
      "content-security-policy",
      "default-src 'none'; script-src 'self'; style-src 'self'; font-src 'self'; connect-src 'self'; form-action 'none'; base-uri 'none'; frame-ancestors 'none'"
    )
    |> put_root_layout(false)
    |> put_view(html: ReconciliationHTML)
    |> render(:index, Keyword.merge([view: view, operation_id: Ecto.UUID.generate()], assigns))
  end
end
