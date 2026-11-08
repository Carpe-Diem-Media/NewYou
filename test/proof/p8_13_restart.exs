input = IO.gets("") |> Jason.decode!()

Application.put_env(
  :new_you,
  :identity_token_signing_secret,
  Base.decode64!(input["signing_secret"])
)

:ok = Ecto.Adapters.SQL.Sandbox.checkout(NewYou.Repo, sandbox: false)

try do
  result =
    case input["mode"] do
      "mfa_enroll" ->
        ring = input["keyring"]

        Application.put_env(:new_you, :identity_mfa_keyring, %{
          active_version: ring["active_version"],
          keys: Map.new(ring["keys"], fn {version, key} -> {version, Base.decode64!(key)} end)
        })

        credentials = %{
          session_id: input["credentials"]["session_id"],
          token: input["credentials"]["token"]
        }

        case NewYou.Identity.enroll_privileged_mfa(credentials, input["password"]) do
          {:ok, %{secret: secret}} ->
            if Base.encode64(:crypto.hash(:sha256, secret)) == input["expected_digest"],
              do: "P813_ENROLLMENT_RESUMED",
              else: "P813_ENROLLMENT_OTHER"

          _ ->
            "P813_DENIED"
        end

      "authorize" ->
        credentials = %{
          session_id: input["credentials"]["session_id"],
          token: input["credentials"]["token"]
        }

        case Ash.transact(
               [
                 NewYou.Identity.Account,
                 NewYou.Identity.Session,
                 NewYou.Identity.Token,
                 NewYou.Identity.IdentityGrant
               ],
               fn ->
                 NewYou.Identity.PrivilegedAccess.authorize_locked(
                   credentials,
                   input["grant_id"],
                   input["target_id"],
                   :release_security_hold
                 )
               end
             ) do
          {:ok, {:ok, _}} -> "P813_AUTHORIZED"
          _ -> "P813_DENIED"
        end

      "materialize" ->
        {:ok, _} =
          NewYou.Audit.materialize_registration_evidence(
            %{primary_key: %{id: input["obligation_id"]}},
            authorize?: false
          )

        "P813_MATERIALIZED"

      _ ->
        "P813_DENIED"
    end

  IO.puts(result)
after
  Ecto.Adapters.SQL.Sandbox.checkin(NewYou.Repo)
end
