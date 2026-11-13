# NewYou

Root Phoenix/LiveView application with Ash, AshPostgres, and one `NewYou.Repo`.
WELL-3 installs the application foundation only. No business Domains or Resources
are defined.

## Local prerequisites

Use the versions in `.tool-versions`: Erlang/OTP 29.1.2 and Elixir 1.20.5.
Run all local Elixir/Mix commands with `mise exec --`, for example
`mise exec -- elixir --version`.
Install the workstation `devcore-project` CLI from the approved DevCore bootstrap
kit. The workstation owns the shared services; this repository never starts,
stops, recreates, or deletes them.

Read `.devcore/project.conf` and `.devcore/render-map.tsv`, then run:

```sh
devcore-project doctor
# If local state is missing or stale:
devcore-project activate
```

Activation provisions only NewYou's roles/databases and renders ignored
`.env.dev.local` and `.env.test.local` files. Never print or commit credentials.
Redis is disabled. Both roles have `NOCREATEDB`.

| Profile | Host | Port | Role | Database |
| --- | --- | --- | --- | --- |
| DEV | 127.0.0.1 | 55432 | new_you_dev | new_you_dev |
| TEST | 127.0.0.1 | 55433 | new_you_test | new_you_test |

The runtime checks each profile's host, port, role, and database against this
contract. TEST requires its own credentials, ignores DEV credentials and
`DATABASE_URL`, and rejects `MIX_TEST_PARTITION`. The TEST runner sets
`MIX_ENV=test`. Tests never create/drop databases or manage shared services.

## Development

In the primary checkout:

```sh
mise exec -- devcore-project run dev -- mix setup
mise exec -- devcore-project run dev -- mix phx.server
```

`mix setup` fetches dependencies, migrates the existing DEV database, installs
asset builders, and builds assets. It does not provision services or databases.

The primary checkout uses `http://127.0.0.1:4220`. A worktree must receive an
explicit `NEW_YOU_PORT` in `4221..4239`. WELL-3 uses `4221`:

```sh
mise exec -- env NEW_YOU_PORT=4221 devcore-project run dev -- mix setup
mise exec -- env NEW_YOU_PORT=4221 devcore-project run dev -- mix phx.server
```

An absent/invalid worktree port fails configuration. An occupied port fails
server startup. No port search or fallback occurs. Generic `PORT` does not
change local DEV ports.

Tidewave is DEV-only at `/tidewave/mcp` on the same endpoint, for example
`http://127.0.0.1:4220/tidewave/mcp` in the primary checkout or
`http://127.0.0.1:4221/tidewave/mcp` in the assigned worktree. The local server
binds to IPv4 loopback. Tidewave is excluded from TEST and production.

## Verification

```sh
mise exec -- mix deps.get
mise exec -- devcore-project run dev -- mix compile --warnings-as-errors
mise exec -- mix format --check-formatted
mise exec -- devcore-project run test -- mix test
# Equivalent minimal application check:
mise exec -- devcore-project run test -- mix check
mise exec -- devcore-project run test -- mix check.deep
```

The test alias migrates the existing TEST database, then runs ExUnit with SQL
Sandbox. Bootstrap tests query the real database identity and role privileges,
check the migration, and prove OTP/Repo boot. Configuration tests reject DEV
settings in TEST and verify the port rules. Generated controller tests exercise
the landing route and error responses.

Elixir tests live in `test/`. Existing Python foundation tests remain in
`tests/`. Foundation Smoke stays always-on under the existing workflow.
Foundation Full routing is unchanged. Application CI and deeper guardrails
remain bounded WELL-4 work.

## Selected framework versions

`mix.lock` records the resolved dependencies, including Phoenix 1.8.16,
LiveView 1.2.13, Ash 3.37.0, AshPostgres 2.15.1, Ecto 3.14.2,
Ecto SQL 3.14.0, Postgrex 0.22.4, Igniter 0.8.4, and Tidewave 0.9.1.
Reactor is constrained to stable 1.0.1 with libgraph 0.16.0 because Reactor
1.0.2 and later require the prerelease-only multigraph package. This satisfies
Ash's declared `~> 1.0` requirement. Revisit the constraint when that dependency
has a stable release. Reactor 1.0.2 also includes an Elixir compile fix,
so recheck the constraint before upgrading the pinned toolchain. Compilation
and tests below use Elixir 1.20.5 on OTP 29.1.2.
Stable release metadata and compatibility were checked against
[Hex](https://hex.pm/packages/ash),
[Phoenix installation requirements](https://hexdocs.pm/phoenix/installation.html),
[Elixir compatibility](https://hexdocs.pm/elixir/compatibility-and-deprecations.html),
[Igniter installation](https://github.com/ash-project/igniter), and
[Tidewave installation](https://github.com/tidewave-ai/tidewave_phoenix).

The application was generated outside this repository with `mise exec -- mix igniter.new`
using `phx.new`, then the Ash/AshPostgres installers and DEV-only Tidewave
installer. Application files were copied after collision review. The existing
`.gitignore` was extended; governance files, Python tests/tools, and GitHub
workflows were preserved.
