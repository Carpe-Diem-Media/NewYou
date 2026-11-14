defmodule NewYou.Analytics do
  @moduledoc """
  Analytics owns rebuildable derived projections and aggregates.

  P8-18 adds only one P8-17 proof fixture aggregate. Rebuilding reads minimized
  current Privacy authority and writes this Domain's projection. This module
  exposes no command for another Domain.
  """

  use Ash.Domain,
    otp_app: :new_you

  resources do
    resource NewYou.Analytics.P817PrivacyProjection
  end

  @type projection_error :: {:error, :privacy_projection_unavailable}

  if Mix.env() in [:dev, :test] do
    @doc "Rebuild the P8-17 proof aggregate from Privacy's current allowed state."
    @spec rebuild_p817_privacy_projection() :: :ok | projection_error()
    def rebuild_p817_privacy_projection do
      with {:ok, current_allowed_count} <- NewYou.Privacy.current_p817_proof_purpose_count(),
           {:ok, _projection} <- write_projection(current_allowed_count) do
        :ok
      else
        _ -> {:error, :privacy_projection_unavailable}
      end
    rescue
      _ -> {:error, :privacy_projection_unavailable}
    catch
      _, _ -> {:error, :privacy_projection_unavailable}
    end

    defp write_projection(current_allowed_count) do
      Ash.create(
        NewYou.Analytics.P817PrivacyProjection,
        %{
          projection_key: "p817_current_privacy_aggregate",
          current_allowed_count: current_allowed_count
        },
        action: :rebuild,
        domain: __MODULE__,
        authorize?: false,
        upsert?: true,
        upsert_identity: :single_projection,
        upsert_fields: [:current_allowed_count],
        touch_update_defaults?: false
      )
    end
  else
    @doc "Rebuild the P8-17 proof aggregate when the development proof surface is enabled."
    @spec rebuild_p817_privacy_projection() :: :ok | projection_error()
    def rebuild_p817_privacy_projection, do: {:error, :privacy_projection_unavailable}
  end
end
