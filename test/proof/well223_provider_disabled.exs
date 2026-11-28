alias Ash.Error.Invalid
alias Ash.Error.Invalid.NoPrimaryAction
alias NewYou.Audit.{EvidenceRecord, FixtureDisputeDisclosure}
alias NewYou.Commerce.{FixtureDispute, FixtureDisputeReceipt}
alias NewYou.Entitlements.PlanRight
alias NewYou.Identity.IdentityGrant

alias NewYou.Privacy.{
  FixtureDisputePurposeAuthority,
  FixtureDisputePurposeEvent,
  PurposeAuthority
}

:dev = Mix.env()
nil = Process.whereis(NewYou.Repo)
nil = Process.whereis(NewYouWeb.Endpoint)
context = AshOban.build_context(false, %Oban.Job{})
%{private: %{ash_oban?: true}} = context

resources = [
  FixtureDispute,
  FixtureDisputeReceipt,
  FixtureDisputeDisclosure,
  FixtureDisputePurposeAuthority,
  FixtureDisputePurposeEvent
]

for resource <- resources, authorize? <- [true, false] do
  nil = Ash.Resource.Info.primary_action(resource, :read)

  {:error, %Invalid{errors: [%NoPrimaryAction{type: :read}]}} =
    Ash.read(resource, context: context, authorize?: authorize?)
end

# TEST-only actions and the AshOban trigger declarations must not exist in DEV.
for resource <- resources do
  for action <- [
        :bind,
        :qualify,
        :record_conflict,
        :confirm_terminal,
        :refund_claimed,
        :acknowledge,
        :reserve_read,
        :deliver,
        :read_due,
        :receive,
        :classify,
        :process,
        :grant_fixture_only,
        :withdraw_fixture_only,
        :record_fixture_transition,
        :record_disclosure
      ] do
    nil = Ash.Resource.Info.action(resource, action)
  end
end

for resource <- [FixtureDispute, FixtureDisputeReceipt] do
  [] = AshOban.Info.oban_triggers_and_scheduled_actions(resource)
end

for action <- [:suspend_component, :restore_component] do
  nil = Ash.Resource.Info.action(PlanRight, action)
end

false = Code.ensure_loaded?(NewYouWeb.FixtureWebhook)
false = Code.ensure_loaded?(NewYou.Commerce.FixtureDisputeEvidence)
false = Code.ensure_loaded?(NewYou.Commerce.FixtureDisputes)
false = Code.ensure_loaded?(NewYou.Commerce.FixtureDisputeWork)
false = Code.ensure_loaded?(NewYou.Commerce.Workers.DeliverFixtureDispute)
false = Code.ensure_loaded?(NewYou.Commerce.Workers.ReadFixtureDispute)
false = Code.ensure_loaded?(NewYou.Commerce.Workers.ProcessFixtureDisputeReceipt)
false = Code.ensure_loaded?(NewYou.Commerce.Schedulers.DeliverFixtureDispute)
false = Code.ensure_loaded?(NewYou.Commerce.Schedulers.ReadFixtureDispute)
false = Code.ensure_loaded?(NewYou.Commerce.Schedulers.ProcessFixtureDisputeReceipt)
false = Code.ensure_loaded?(NewYou.Identity.FixtureDisputeGrants)

for action <- [:provision_fixture_dispute_approver, :approve_fixture_dispute_disclosure] do
  nil = Ash.Resource.Info.action(IdentityGrant, action)
end

# No fixture request builder can reach a provider from the DEV build.
true = Code.ensure_loaded?(NewYou.Commerce.PaystackCheckout)

for {builder, arity} <- [
      build: 3,
      build_verify: 2,
      build_refund: 2,
      build_refund_read: 2,
      build_dispute_read: 2
    ] do
  false = function_exported?(NewYou.Commerce.PaystackCheckout, builder, arity)
end

# Public Domain wrappers keep fixture-only paths fail closed outside TEST.
{:error, :dispute_unavailable} = NewYou.Commerce.apply_fixture_dispute_receipt("fixture-only")
{:error, :dispute_unavailable} = NewYou.Commerce.deliver_fixture_dispute("fixture-only")
{:error, :grant_unavailable} = NewYou.Entitlements.apply_fixture_dispute("fixture-only")
{:error, :recipient_unavailable} = NewYou.Identity.locked_fixture_recipient("fixture-only")
{:error, :disclosure_grant_unavailable} = NewYou.Identity.issue_fixture_dispute_grant(%{}, %{})

{:error, :disclosure_grant_unavailable} =
  NewYou.Identity.revoke_fixture_dispute_grant(%{}, "fixture-only")

{:error, :disclosure_grant_unavailable} = NewYou.Identity.require_fixture_dispute_grants(%{})

# Privacy and Audit evidence readers retain their ordinary Ash denial in DEV.
for resource <- [PurposeAuthority, EvidenceRecord] do
  {:ok, []} = Ash.read(resource, authorize?: true)
end

IO.puts("WELL-223 DEV provider and fixture exclusion proof passed")
