defmodule NewYou.Proof.P816Restart do
  @moduledoc false

  alias Ecto.Adapters.SQL.Sandbox
  alias NewYou.{Identity, Repo}

  def run(input) do
    secret = Base.decode64!(input["signing_secret"])
    Application.put_env(:new_you, :identity_token_signing_secret, secret)

    Application.put_env(:new_you, :p8_16_primary_email_change_policy, %{
      delay_seconds: 0,
      requires_review?: false
    })

    Sandbox.unboxed_run(Repo, fn ->
      with {:ok, :confirmed} <- Identity.confirm_primary_email_change(input["proof"]),
           {:ok, :applied} <- Identity.apply_primary_email_change(input["operation_id"]) do
        :applied
      else
        _ -> :denied
      end
    end)
  end
end

input = IO.gets("") |> Jason.decode!()

try do
  result = NewYou.Proof.P816Restart.run(input)
  IO.puts("P816_" <> (result |> Atom.to_string() |> String.upcase()))
rescue
  error ->
    IO.puts(:stderr, "P816_FAILURE_CLASS_" <> inspect(error.__struct__))
    IO.puts("P816_ERROR")
end
