alias Ash.Error.Invalid
alias Ash.Error.Invalid.NoPrimaryAction
alias NewYou.Commerce.{FixtureDispute, FixtureDisputeReceipt}

false = Mix.env() == :test
context = AshOban.build_context(false, %Oban.Job{})
%{private: %{ash_oban?: true}} = context

for resource <- [FixtureDispute, FixtureDisputeReceipt], authorize? <- [true, false] do
  nil = Ash.Resource.Info.primary_action(resource, :read)

  {:error, %Invalid{errors: [%NoPrimaryAction{type: :read}]}} =
    Ash.read(resource, context: context, authorize?: authorize?)
end

IO.puts("E2c-F non-TEST AshOban fixture read exclusion passed")
