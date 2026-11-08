input = IO.gets("") |> Jason.decode!()

Application.put_env(
  :new_you,
  :identity_token_signing_secret,
  Base.decode64!(input["signing_secret"])
)

:ok = Ecto.Adapters.SQL.Sandbox.checkout(NewYou.Repo, sandbox: false)

try do
  r = input["request"]

  request = %{
    case_id: r["case_id"],
    operation_id: r["operation_id"],
    expected_version: r["expected_version"],
    grant_id: r["grant_id"],
    credentials: %{session_id: r["credentials"]["session_id"], token: r["credentials"]["token"]}
  }

  {:ok, record} = NewYou.Identity.apply_reconciliation(request)
  loser = Ash.get!(NewYou.Identity.Account, record.candidate_id, authorize?: false)
  canonical = Ash.get!(NewYou.Identity.Account, record.canonical_id, authorize?: false)

  true =
    record.status == :applied and loser.pmr_status == :retired and
      loser.pmr == input["retired_pmr"]

  true = canonical.pmr_status == :active and canonical.account_status == :open

  {:ok, _} =
    NewYou.Audit.materialize_registration_evidence(%{primary_key: %{id: input["obligation_id"]}},
      authorize?: false
    )

  IO.puts("P814_RECONSTRUCTED")
after
  Ecto.Adapters.SQL.Sandbox.checkin(NewYou.Repo)
end
