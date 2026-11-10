defmodule NewYou.Audit.PrivilegedEvidence do
  @moduledoc false
  require Ash.Query
  alias NewYou.Audit.{EvidenceObligation, EvidenceRecord}

  @admission_fields ~w(attempt_id actor_id target_id grant_id grant_version session_id expected_version reason_code)a
  @uuid_fields ~w(attempt_id actor_id target_id grant_id session_id)a
  @reasons ~w(suspected_compromise security_review verified_recovery mistaken_hold)a
  @outcome_fields ~w(source_operation_id source_occurred_at evidence_type actor_id target_id grant_id session_id reason_code admission_id outcome case_id)a
  @security_types ~w(security_hold_placement security_hold_review security_hold_release_result identity_mfa_confirmed identity_grant_revoked identity_reconciliation_result identity_reconciliation_review identity_password_reset)a

  defmacrop checkpoint(point) do
    if Mix.env() == :test do
      quote do: NewYou.Proof.AuditSeam.checkpoint(unquote(point))
    else
      quote do: :ok
    end
  end

  def admit(envelope, action_class \\ :security_hold_release)

  def admit(envelope, action_class)
      when is_map(envelope) and action_class in [:security_hold_release, :identity_reconciliation] do
    with false <- Ash.DataLayer.in_transaction?(EvidenceRecord),
         {:ok, envelope} <- admission_envelope(envelope, action_class) do
      case read_admission(envelope.attempt_id) do
        {:ok, nil} -> create_admission(envelope)
        {:ok, record} -> bound_admission(record, envelope)
        _ -> unavailable()
      end
    else
      _ -> unavailable()
    end
  rescue
    _ -> unavailable()
  end

  def admit(_, _), do: unavailable()

  defp create_admission(envelope) do
    # The action commits synchronously. A unique-key loser reads the winner only
    # after its failed INSERT transaction has rolled back.
    :ok = checkpoint(:before_admission)

    case Ash.create(EvidenceRecord, Map.put(envelope, :admitted_at, DateTime.utc_now()),
           action:
             if(envelope.action_class == :identity_reconciliation,
               do: :admit_reconciliation,
               else: :admit_security_hold_release
             ),
           authorize?: false
         ) do
      {:ok, record} ->
        {:ok, record}

      {:error, _} ->
        case read_admission(envelope.attempt_id) do
          {:ok, record} when not is_nil(record) -> bound_admission(record, envelope)
          _ -> unavailable()
        end
    end
  end

  defp read_admission(attempt_id) do
    EvidenceRecord
    |> Ash.Query.filter(attempt_id == ^attempt_id and assertion_kind == :admission)
    |> Ash.read_one(authorize?: false)
  end

  defp bound_admission(record, envelope) do
    if Map.take(record, Map.keys(envelope)) == envelope, do: {:ok, record}, else: unavailable()
  end

  defp admission_envelope(envelope, action_class) do
    fields =
      if action_class == :identity_reconciliation,
        do: @admission_fields ++ [:case_id, :canonical_grant_id, :canonical_grant_version],
        else: @admission_fields

    valid? =
      Enum.sort(Map.keys(envelope)) == Enum.sort(fields) and
        Enum.all?(@uuid_fields, fn key -> valid_uuid?(envelope[key]) end) and
        valid_admission_versions?(envelope) and
        envelope.reason_code in @reasons and
        valid_reconciliation_scope?(envelope, action_class)

    if valid?, do: {:ok, Map.put(envelope, :action_class, action_class)}, else: unavailable()
  end

  defp valid_reconciliation_scope?(envelope, :identity_reconciliation) do
    valid_uuid?(envelope[:case_id]) and valid_uuid?(envelope[:canonical_grant_id]) and
      is_integer(envelope[:canonical_grant_version]) and envelope[:canonical_grant_version] > 0
  end

  defp valid_reconciliation_scope?(_envelope, _action_class), do: true

  defp valid_admission_versions?(envelope),
    do:
      is_integer(envelope.grant_version) and envelope.grant_version > 0 and
        is_integer(envelope.expected_version) and envelope.expected_version >= 0

  def establish_outcome(envelope) when is_map(envelope) do
    with true <- Ash.DataLayer.in_transaction?(EvidenceObligation),
         true <- Enum.all?(Map.keys(envelope), &(&1 in @outcome_fields)),
         true <- envelope[:evidence_type] in @security_types,
         true <- envelope[:outcome] in [:succeeded, :denied, :failed],
         true <-
           Enum.all?([:source_operation_id, :actor_id, :target_id], &valid_uuid?(envelope[&1])),
         {:ok, existing} <- read_outcome(envelope.source_operation_id) do
      create_or_replay_outcome(existing, envelope)
    else
      _ -> {:error, :evidence_outcome_unavailable}
    end
  end

  def establish_outcome(_), do: {:error, :evidence_outcome_unavailable}

  defp create_or_replay_outcome(nil, envelope),
    do:
      Ash.create(EvidenceObligation, envelope,
        action: :establish_identity_security,
        authorize?: false
      )

  defp create_or_replay_outcome(record, envelope) do
    if Map.take(record, Map.keys(envelope)) == envelope,
      do: {:ok, record},
      else: {:error, :evidence_outcome_unavailable}
  end

  defp read_outcome(operation_id) do
    EvidenceObligation
    |> Ash.Query.filter(source_operation_id == ^operation_id)
    |> Ash.read_one(authorize?: false)
  end

  defp valid_uuid?(id) do
    case Ecto.UUID.cast(id) do
      {:ok, ^id} when is_binary(id) -> true
      _ -> false
    end
  end

  defp unavailable, do: {:error, :evidence_admission_unavailable}
end
