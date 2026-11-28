defmodule NewYou.LocalConfig do
  @moduledoc """
  Fail-closed workstation configuration for the DevCore database allocation.
  Production uses its separate runtime configuration.
  """

  def repo(env, get_env \\ &System.get_env/1) when env in [:dev, :test] do
    if env == :test and get_env.("MIX_TEST_PARTITION") not in [nil, ""] do
      raise ArgumentError, "MIX_TEST_PARTITION is unsupported while TEST has NOCREATEDB"
    end

    {prefix, port, name} =
      case env do
        :dev -> {"DEV", 55432, "new_you_dev"}
        :test -> {"TEST", 55433, "new_you_test"}
      end

    for {suffix, expected} <- [
          {"HOST", "127.0.0.1"},
          {"PORT", Integer.to_string(port)},
          {"USERNAME", name},
          {"NAME", name}
        ] do
      key = "#{prefix}_DATABASE_#{suffix}"

      unless get_env.(key) == expected do
        raise ArgumentError,
              "#{key} must match the DevCore contract; run devcore-project activate"
      end
    end

    password_key = "#{prefix}_DATABASE_PASSWORD"
    password = get_env.(password_key)

    if password in [nil, ""] do
      raise ArgumentError,
            "#{password_key} is missing; use devcore-project run #{env} -- <command>"
    end

    [hostname: "127.0.0.1", port: port, username: name, database: name, password: password]
  end

  def port(worktree?, value) do
    case {worktree?, value && Integer.parse(value)} do
      {false, nil} ->
        4220

      {false, {4220, ""}} ->
        4220

      {true, {port, ""}} when port in 4221..4239 ->
        port

      _ ->
        raise ArgumentError,
              "NEW_YOU_PORT must be 4220 in the primary checkout or explicitly 4221..4239 in a worktree"
    end
  end

  if Mix.env() == :dev do
    @doc false
    def paystack_development_plan do
      fields = ~w(approval_id disclosure_af_id disclosure_en_id offer_id operation_id payer_id)

      with json when is_binary(json) and byte_size(json) <= 2_048 <-
             System.get_env("NEW_YOU_PAYSTACK_DEV_PLAN_APPROVAL"),
           {:ok, source} when is_map(source) <- Jason.decode(json),
           true <- Enum.sort(Map.keys(source)) == fields,
           true <- Enum.all?(source, fn {_, id} -> match?({:ok, ^id}, Ecto.UUID.cast(id)) end),
           true <- source["disclosure_en_id"] != source["disclosure_af_id"] do
        {:ok, source}
      else
        _ -> {:error, :purchase_unavailable}
      end
    end
  end
end
