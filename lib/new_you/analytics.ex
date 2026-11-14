defmodule NewYou.Analytics do
  @moduledoc """
  Analytics owns rebuildable derived projections and aggregates.

  P8-18 adds only one P8-17 proof fixture aggregate. An explicit rebuild reads
  Privacy's minimized current allowed count and then writes this Domain's
  projection. Privacy supplies an owner-managed revision with the count, and
  Analytics rejects an older upsert if a newer rebuild already committed. The
  projection remains eventually consistent between rebuilds and may lag after
  a source change until it is rebuilt. It is not a current authority read and
  must not decide authorization or suppression; Privacy remains authoritative
  for those decisions. This module exposes no command for another Domain.
  """

  use Ash.Domain,
    otp_app: :new_you

  resources do
    resource NewYou.Analytics.P817PrivacyProjection
  end

  @type projection_error ::
          {:error, :privacy_authority_unavailable | :analytics_projection_unavailable}

  if Mix.env() in [:dev, :test] do
    @doc "Rebuild the P8-17 proof aggregate from Privacy's current allowed state."
    @spec rebuild_p817_privacy_projection() :: :ok | projection_error()
    def rebuild_p817_privacy_projection do
      with {:ok, snapshot} <- NewYou.Privacy.current_p817_proof_purpose_snapshot(),
           :ok <- after_privacy_snapshot_read(snapshot),
           {:ok, _projection} <- write_projection(snapshot) do
        :ok
      else
        {:error, :privacy_authority_unavailable} -> {:error, :privacy_authority_unavailable}
        _ -> {:error, :analytics_projection_unavailable}
      end
    end

    defp write_projection(snapshot) do
      Ash.create(
        NewYou.Analytics.P817PrivacyProjection,
        %{
          projection_key: "p817_current_privacy_aggregate",
          current_allowed_count: snapshot.current_allowed_count,
          privacy_revision: snapshot.revision
        },
        action: :rebuild,
        domain: __MODULE__,
        authorize?: false,
        upsert?: true,
        upsert_identity: :single_projection,
        upsert_fields: [:current_allowed_count, :privacy_revision],
        return_skipped_upsert?: true,
        touch_update_defaults?: false
      )
    end

    if Mix.env() == :test do
      defp after_privacy_snapshot_read(snapshot) do
        case Process.get({__MODULE__, :after_privacy_snapshot}) do
          callback when is_function(callback, 1) -> callback.(snapshot)
          _ -> :ok
        end
      end
    else
      defp after_privacy_snapshot_read(_snapshot), do: :ok
    end
  else
    @doc "Rebuild the P8-17 proof aggregate when the development proof surface is enabled."
    @spec rebuild_p817_privacy_projection() :: :ok | projection_error()
    def rebuild_p817_privacy_projection, do: {:error, :analytics_projection_unavailable}
  end
end
