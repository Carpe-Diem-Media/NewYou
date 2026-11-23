defmodule NewYou.Identity.TrustedDevices do
  @moduledoc false

  require Ash.Query

  alias NewYou.Audit
  alias NewYou.Identity.DeviceAssurance

  @trust_seconds 30 * 24 * 60 * 60

  # The caller holds the Account lock and the presenting Token and Session locks.
  # All Account-wide invalidation and device mutations use the same Account lock.
  def execute(account, session, operation) do
    with :ok <- expire_due(account) do
      execute_current(account, session, operation)
    end
  end

  defp execute_current(account, session, :list),
    do: execute_current(account, session, {:list, nil})

  defp execute_current(account, _session, {:list, artifact}) do
    current = fingerprint(artifact)

    with {:ok, rows} <-
           account
           |> current_devices()
           |> Ash.Query.sort(id: :desc)
           |> Ash.read(authorize?: false) do
      {:device_result, Enum.map(rows, &projection(&1, current))}
    end
  end

  defp execute_current(account, session, {:grant, <<_::256>> = artifact}) do
    digest = fingerprint(artifact)

    with {:ok, record} <-
           account
           |> devices()
           |> Ash.Query.filter(fingerprint == ^digest)
           |> Ash.read_one(authorize?: false) do
      grant(account, session, record, digest)
    end
  end

  defp execute_current(account, session, {:revoke, id}) do
    with {:ok, id} <- Ecto.UUID.cast(id),
         {:ok, %DeviceAssurance{} = device} <- find_device(account, id) do
      revoke(account, session, device)
    else
      {:error, _} = error -> error
      _ -> :denied
    end
  end

  defp execute_current(account, _session, {:rename, id, name})
       when is_binary(name) and byte_size(name) <= 320 do
    with {:ok, id} <- Ecto.UUID.cast(id),
         true <- String.valid?(name),
         trimmed = String.trim(name),
         true <- String.length(trimmed) in 1..80,
         {:ok, %DeviceAssurance{state: :trusted} = device} <- find_device(account, id),
         true <- current?(account, device),
         {:ok, _} <- Ash.update(device, %{name: trimmed}, action: :name, authorize?: false) do
      {:device_result, :renamed}
    else
      {:error, _} = error -> error
      _ -> :denied
    end
  end

  defp execute_current(_account, _session, _operation), do: :denied

  defp grant(account, session, nil, digest) do
    attrs = %{
      account_id: account.id,
      fingerprint: digest,
      security_version: account.security_version,
      expires_at: DateTime.add(DateTime.utc_now(), @trust_seconds)
    }

    with {:ok, pending} <-
           Ash.create(DeviceAssurance, attrs, action: :record_consent, authorize?: false),
         {:ok, device} <- Ash.update(pending, %{}, action: :trust, authorize?: false),
         {:ok, _} <-
           evidence(account, session, device, :identity_device_trust_granted, device.created_at) do
      {:device_result, projection(device, digest)}
    end
  end

  defp grant(account, _session, record, digest) do
    if current?(account, record), do: {:device_result, projection(record, digest)}, else: :denied
  end

  defp revoke(account, session, device) do
    if current?(account, device) do
      with {:ok, revoked} <- Ash.update(device, %{}, action: :revoke, authorize?: false),
           {:ok, _} <-
             evidence(
               account,
               session,
               revoked,
               :identity_device_trust_revoked,
               revoked.revoked_at
             ) do
        {:device_result, :revoked}
      end
    else
      {:device_result, :already_ended}
    end
  end

  defp evidence(account, session, device, type, occurred_at) do
    Audit.establish_identity_security_obligation(%{
      source_operation_id: device.id,
      source_occurred_at: occurred_at,
      evidence_type: type,
      actor_id: account.id,
      target_id: account.id,
      session_id: session.id,
      outcome: :succeeded
    })
  end

  defp expire_due(account) do
    checked_at = DateTime.utc_now()

    with {:ok, rows} <-
           account
           |> devices()
           |> Ash.Query.filter(state == :trusted and expires_at <= ^checked_at)
           |> Ash.Query.sort(:id)
           |> Ash.read(authorize?: false) do
      Enum.reduce_while(rows, :ok, fn row, :ok -> expire(row, checked_at) end)
    end
  end

  defp expire(row, checked_at) do
    case Ash.update(row, %{checked_at: checked_at}, action: :expire, authorize?: false) do
      {:ok, _} -> {:cont, :ok}
      {:error, _} = error -> {:halt, error}
    end
  end

  defp current?(account, device) do
    device.state == :trusted and device.security_version == account.security_version and
      DateTime.after?(device.expires_at, DateTime.utc_now())
  end

  defp find_device(account, id) do
    account
    |> devices()
    |> Ash.Query.filter(id == ^id)
    |> Ash.read_one(authorize?: false)
  end

  defp current_devices(account) do
    checked_at = DateTime.utc_now()

    account
    |> devices()
    |> Ash.Query.filter(
      state == :trusted and security_version == ^account.security_version and
        expires_at > ^checked_at
    )
  end

  defp devices(account), do: Ash.Query.filter(DeviceAssurance, account_id == ^account.id)

  defp fingerprint(<<_::256>> = artifact), do: :crypto.hash(:sha256, artifact)
  defp fingerprint(_), do: nil

  defp projection(device, digest) do
    device
    |> Map.take([:id, :name, :expires_at])
    |> Map.put(:current?, device.fingerprint == digest)
  end
end
