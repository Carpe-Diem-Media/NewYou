defmodule NewYou.Audit.SyntheticCorrectionEvidence do
  @moduledoc """
  Audit reads selected synthetic Commerce dispositions through an explicit
  source-scoped TEST grant. Commerce retains the durable adjudication records.
  """
  alias NewYou.Commerce.SyntheticCorrections

  @doc "Read the recorded disposition kinds without monetary or participant identifiers."
  @spec read(map(), String.t(), term()) :: {:ok, map()} | {:error, :read_unavailable}
  def read(credentials, source_id, grant),
    do: SyntheticCorrections.read_evidence(credentials, source_id, :audit, grant)
end
