# Managed local TEST slots

WELL-147 consumes DevCore's WELL-145 source capability. This implementation is
pending live proof and activation. Existing databases, active agents and legacy
worktrees have not been migrated. Keep legacy TEST booking and its cooperating
`/tmp/newyou-shared-test-plt.lock` protocol for those worktrees.

## Installation and activation checkpoint

DevCore PR #6 integrated as `1a46dcc54d3ac37fa554955e20c45555c0e08f5b`, after
independent approval of `df6ed3952f31070107dee42229e695f6edee63c3`. Resulting-main
[CI run 44095123947](https://github.com/Carpe-Diem-Media/devcore-project/actions/runs/44095123947)
passed both checks, including real disposable PostgreSQL isolation and reuse.
That source evidence does not prove NewYou's migrations or business fixtures.

The owner separately authorized installation on 2026-11-17. The checksum-verifying
installer installed source version 1.2.0; its observed executable SHA-256 is
`e76cb9206d6e00226ab9549bfa2a342c4da867f2a7d21956240035b1bf65d93a`.
The retained installer backup matches the previous 1.1.0 checksum
`df7dd3263197d33416b99699b5f09ee2b37bb4a45f55cc2a7bb4164dbbff9568`.
Follow DevCore's reviewed
[verification and installation procedure](https://github.com/Carpe-Diem-Media/devcore-project/blob/1a46dcc54d3ac37fa554955e20c45555c0e08f5b/docs/activation/newyou-verification.md).
Source installation is not a published release or permission to change active jobs.

The reviewed
[exact workstation manifest](https://github.com/Carpe-Diem-Media/devcore-project/blob/1a46dcc54d3ac37fa554955e20c45555c0e08f5b/docs/activation/newyou-workstation-manifest.json)
has digest `3fb71d0ed24dfc4ab8ef75226916da624f5ca4a18343695a154733eb2a93e556`.
It bounds creation and cleanup to newly registered NewYou TEST generations on
`127.0.0.1:55433`. The registry is
`~/.config/dev-core/slots/new_you`; slot NN uses database
`dc_new_you_sNN_g<32 lowercase UUID hex>` and role `<database>_r`.
DevCore owns the databases as `devcore_admin`; runtime roles remain NOCREATEDB
and never acquire ownership or unrelated administrative privileges.

Run `devcore-project slots manifest`, compare the contract and digest with the
reviewed manifest, then obtain the owner's exact `approval_text` in an authenticated
GitHub comment. Only after that authorization, run:

```sh
devcore-project slots enable --manifest 3fb71d0ed24dfc4ab8ef75226916da624f5ca4a18343695a154733eb2a93e556 --approval-ref OWNER_COMMENT_URL
```

This contract excludes `new_you_dev`, `new_you_test`, maintenance/template,
production, unrelated and unregistered databases. A prefix is not ownership.
Cleanup requires exact recorded identities, OIDs, ownership comments, generation,
no managed jobs and zero database clients. Uncertainty quarantines the slot;
unknown sessions are never terminated to make cleanup pass.

The separate
[legacy TEST ACL proposal](https://github.com/Carpe-Diem-Media/devcore-project/blob/1a46dcc54d3ac37fa554955e20c45555c0e08f5b/docs/activation/newyou-legacy-connect-proposal.md)
requires explicit approval for exactly
`REVOKE CONNECT ON DATABASE new_you_test FROM PUBLIC;` on that TEST endpoint.
Recheck the container, database OID/owner, original ACL and connection-role
identities, capture a private receipt and preserve owner CONNECT before the
reviewed transactional operation. Stop on unknown dependencies. This is neither
a reset nor authorization to change DEV or other privileges. Cleanup approval
does not authorize this ACL change. Provisioning refuses the existing default
PUBLIC CONNECT boundary until it has been resolved.

The owner authorized that exact guarded ACL operation on 2026-11-17. It committed
against OID `4687800`, owner `new_you_test`, after binding the immutable container
and preserving a private original-ACL receipt. Rechecks confirmed owner CONNECT
true, PUBLIC CONNECT false and unchanged NOCREATEDB/NOSUPERUSER flags. DevCore
doctor passed authenticated DEV and TEST reconnection afterward. Existing owner
connections were preserved. No rows, databases, passwords or other privileges
changed. Managed-role denial against legacy TEST still needs the live pilot.

The owner also authorized the exact disposable-generation contract in chat.
Allocator enable remains pending the required authenticated GitHub approval
comment. No managed database has yet been provisioned on this workstation.

## Routine commands after activation

Run doctor first. If only ignored local environment files are absent or stale,
render them and repeat doctor using the existing central credentials. Preserve
the existing rule against automatically running `activate` or repairing shared
services. No owner needs to assign a slot, copy credentials or book ordinary
managed tests in chat.

```sh
mise exec -- devcore-project doctor
mise exec -- tools/newyou-local test -- mix test test/new_you/local_config_test.exs
mise exec -- tools/newyou-local test -- mix check
mise exec -- tools/newyou-local test -- mix check.deep
mise exec -- tools/newyou-local dev -- mix phx.server
devcore-project slots status
```

The wrapper admits one mutable build command per worktree. Other worktrees have
independent locks. It rejects unresolved prior jobs before starting new work and
requires reviewed DevCore 1.2 or compatible 1.x. DevCore supplies command-local
environment snapshots, verifies mutable build/dependency paths remain within the
canonical worktree, and owns the lease and every managed descendant. Running
children retain ownership after launcher loss. Do not rewrite environment files
under running jobs.

Within an existing managed job, use the familiar nested command to reuse its
verified assignment instead of entering the wrapper again:

```sh
mise exec -- devcore-project run test -- mix test test/PATH_test.exs
```

Twenty configured HTTP slots map N to `4220 + N`, ports 4221 through 4240.
Primary legacy port 4220 remains outside the pool. Occupied ports block a slot;
never kill an unknown listener. Temporary browser servers keep loopback port 0.
Managed TEST databases are independent. DEV still writes the shared
`new_you_dev` database, so simultaneous DEV writes need their existing care.

The automatic expensive-command capacity is provisionally at most two, bounded
further by CPU and memory. Focused tests in different worktrees do not share that
gate. Workstation suite memory/throughput and the final capacity remain unmeasured;
twenty configured slots do not establish capacity for twenty heavy suites.

## Retention, release and recovery

Successful commands release their generation after all children finish and
cleanup succeeds. Failed commands retain diagnosis and remain unavailable.
Status exposes non-secret lease/generation/state/endpoints. Preserve logs and
results before release; do not export participant data as routine evidence.
Use the exact IDs from status:

```sh
devcore-project slots retain --lease LEASE --generation GENERATION
devcore-project slots release --lease LEASE --generation GENERATION
devcore-project slots recover
```

Release is ownership checked and uses only the approved registered-generation
cleanup contract. Recover reconciles dead jobs conservatively; it cannot claim a
resource solely because a heartbeat elapsed. Live or uncertain jobs remain
unavailable. Inspect the non-secret quarantine diagnosis and resolve its exact
cause. Do not reset shared TEST, terminate unknown sessions or erase registry
records as recovery shortcuts.

Rollback starts by stopping new managed admission and allowing consenting jobs
to finish or retaining their resources. Executable rollback uses the reviewed
DevCore installer procedure only after separate authorization; it does not
release databases. Existing source branches without `SLOT_POOL` retain legacy
behavior. Never reopen PUBLIC CONNECT while managed identities remain live;
the inverse ACL operation needs its own authorization.

## Builds, PLTs and proof boundary

Project builds, dependencies and project PLTs remain in the worktree. Local
Dialyzer prepares a baseline under `${XDG_CACHE_HOME:-~/.cache}/newyou/local-plt/v1`
with a cache-key-specific lock, then uses mutable copies in
`_build/plts/local-core`. The key covers full OTP version, architecture, Elixir,
Dialyxir source/version and core BEAM inputs. The shared lock ends before
worktree copy use or analysis. Existing Mix-home PLTs are not imported or
modified. CI keeps its existing `_build/plts` cache and analysis obligations.
The project PLT additionally includes the already pinned `:dialyxir` dependency,
because the new build task calls its API. This necessary input extension prevents
unknown-function warnings for that task; it does not suppress analysis findings.

The first real local `mise exec -- /usr/bin/time -v mix dialyzer --plt` preparation
passed on OTP 29.1.2 / Elixir 1.20.5, elapsed `2:58.40`, maximum RSS
`3692448` KiB and no swaps. It used the new baseline namespace and private local
core copies, without a TEST lease. TEST preparation plus analysis then passed in
`4:25.69`, maximum RSS `3465708` KiB. Peer TEST preparation passed in `4:11.22`,
maximum RSS `4087804` KiB. Full-suite capacity remains unmeasured.

A DEV-profile analysis then failed with 20 warnings. Adding the pinned build-tool
input and rerunning reduced that to 18 warnings in Communications and Privacy,
with no remaining LocalDialyzer unknown-function warnings. Those application
warnings have not been classified against a separate base DEV run. Neither DEV
analysis is recorded as passing. TEST-profile static analysis passed with zero
errors, skips or unnecessary skips; this does not replace `mix check.deep`.

At source `e583d5cd22c42b7850711ecf07c15a27702bd85b`, two independent worktrees
ran `mise exec -- env MIX_ENV=test /usr/bin/time -v mix dialyzer --format dialyxir`
concurrently. Both passed with zero errors. Analysis overlapped for `17.385`
seconds, and the shared cache lock was available during that overlap. Neither
command used a TEST lease or the legacy TEST/PLT lock. Permanent temporary-cache
tests cover concurrent cold preparation; this real proof used the prepared cache.

The explicit `NEW_YOU_DATABASE_MODE=ci` compatibility path preserves the hosted
runner's disposable `new_you_test` allocation and requires both existing CI flags.
Those caller-controlled flags are not authentication. This is deliberate legacy
compatibility, not a managed lease. The local entry point rejects that mode;
partial managed markers always reject even in CI mode. Do not set it locally to
bypass allocation or the legacy TEST lock.

Pure LocalConfig, temporary-metadata cache and admission tests do not prove real
NewYou database isolation. Before activation claims, WELL-147 still requires
two independent worktrees with their own migrations and distinguishable committed
synthetic fixtures, child/restart/browser paths, failure retention and clean
reuse, measured heavy capacity,
full repository gates, bounded OCR, exact-head CI and independent review.
