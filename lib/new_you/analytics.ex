defmodule NewYou.Analytics do
  @moduledoc """
  Analytics owns rebuildable derived projections and aggregates.

  P8-18 adds only a P8-17 proof aggregate. An explicit rebuild reads Privacy's
  minimized current allowed count and then writes this Domain's projection.
  The rebuild interface is available only in development and test; production
  returns `:analytics_projection_unavailable` because this proof has no
  production purpose or rebuild path. The projection reserves one fixed
  production key in its schema. Test proof fixtures use an opaque per-fixture
  key so cleanup cannot erase another fixture's row.
  Privacy supplies an owner-managed revision with the count, and Analytics
  rejects an older upsert if a newer rebuild already committed. The projection
  remains eventually consistent between rebuilds and may lag after a source
  change until it is rebuilt. It is not a current authority read and must not
  decide authorization or suppression; Privacy remains authoritative for those
  decisions. This module exposes no command for another Domain.
  """

  use Ash.Domain,
    otp_app: :new_you

  @production_projection_key "p817_current_privacy_aggregate"
  @test_projection_key {__MODULE__, :p817_test_projection_key}

  resources do
    resource NewYou.Analytics.P817PrivacyProjection
  end

  @type projection_error ::
          {:error, :privacy_authority_unavailable | :analytics_projection_unavailable}

  @doc """
  Rebuild the P8-17 proof aggregate from Privacy's minimized current allowed
  count and revision. The rebuild path is available only in development and
  test; production returns `:analytics_projection_unavailable` because this
  proof defines no production purpose or rebuild flow.
  """
  @spec rebuild_p817_privacy_projection() :: :ok | projection_error()
  if Mix.env() in [:dev, :test] do
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
          projection_key: projection_key(),
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

    if Mix.env() == :test do
      defp projection_key do
        Process.get(@test_projection_key, @production_projection_key)
      end
    else
      defp projection_key, do: @production_projection_key
    end
  else
    def rebuild_p817_privacy_projection, do: {:error, :analytics_projection_unavailable}

    defp projection_key, do: @production_projection_key
  end
end
