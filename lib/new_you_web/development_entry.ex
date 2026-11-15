defmodule NewYouWeb.DevelopmentEntry do
  @moduledoc """
  Admits the bounded FP-001 journey in explicitly enabled development builds.

  This grants no public, production, pilot or real-participant eligibility.
  Content owns the exact legal and bilingual versions; Identity still owns every
  registration and verification mutation. Runtime flags cannot enable a PROD build.
  """

  @development_build Mix.env() in [:dev, :test]

  @doc "Returns whether the normal development entry has its exact eligible content."
  @spec enabled?() :: boolean()
  def enabled? do
    :erlang.andalso(
      @development_build,
      Application.get_env(:new_you, :fp001_development_entry, false) == true and
        NewYou.Content.EntryCopy.available?() and
        match?({:ok, _}, NewYou.Content.Registration.legal_versions())
    )
  end
end
