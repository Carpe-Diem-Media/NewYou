defmodule NewYou.Proof.FreshMix do
  @moduledoc false

  def command(arguments) do
    if System.get_env("GITHUB_ACTIONS") == "true" do
      {System.find_executable("mix"), arguments}
    else
      {System.find_executable("mise"),
       ["exec", "--", "devcore-project", "run", "test", "--", "mix" | arguments]}
    end
  end
end
