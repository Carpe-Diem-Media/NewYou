# Managed local TEST slots

WELL-147 consumes DevCore's WELL-145 source capability. A bounded real two-agent
TEST lifecycle demonstrated independent Ash writes, isolation, automatic cleanup
and fresh empty reacquisition, but the private pilot controller exited 1 while
publishing its final report. Canonical exact-head local verification was stopped
before execution by two private supervision-wrapper defects. **PR #273 is still
blocked, not merge-certified and not routinely activated.** See the dated
[WELL-147 pause and resume handoff](well-147-pause-and-resume.md) for exact evidence,
open guards, and the safe resumption sequence; live status belongs in Plane.
Existing active agents and legacy worktrees have not been migrated. Keep legacy
TEST booking and its cooperating `/tmp/newyou-shared-test-plt.lock` protocol
for those worktrees.

## Installation and activation checkpoint

DevCore PR #6 integrated as `1a46dcc54d3ac37fa554955e20c45555c0e08f5b`, after
independent approval of `df6ed3952f31070107dee42229e695f6edee63c3`. Resulting-main
[CI run 44095123947](https://github.com/Carpe-Diem-Media/devcore-project/actions/runs/44095123947)
passed both checks, including real disposable PostgreSQL isolation and reuse.
That source evidence does not prove NewYou's migrations or business fixtures.

The owner separately authorized installation on 2026-11-17. The checksum-verifying
installer initially installed source version 1.2.0; its historical executable SHA-256 is
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
changed. At that checkpoint, managed-role denial against legacy TEST had not yet been verified.

The owner also authorized the exact disposable-generation contract in chat. The
[authenticated approval](https://github.com/Carpe-Diem-Media/devcore-project/pull/6#issuecomment-6952421506)
now supplies the exact required text. The R1–R3 corrections requested by
independent checkpoint review have focused passing
regressions. Enable accepted that comment and exact digest for the bounded pilot.
Fresh current-branch migrations and 35 bootstrap/result tests passed, and their
generations were cleaned through the approved exact-target procedure. The first
run's two legacy-only assertions failed before being corrected; its diagnosis is
preserved rather than counted as a pass.

The initial parallel pilot did not pass. One attempt failed private environment
rendering while the other progressed. A diagnostic staggered attempt committed
distinct synthetic fixtures and completed browser login, but the probe protocol
stalled behind the output redactor. Its supervisor ownership was later lost;
guarded recovery quarantined both generations. Their databases and records remain
preserved, and new acquisitions are disabled. No successful two-worktree child,
cross-slot-denial or clean-reuse claim follows from these attempts.

WELL-154 supplies the separate canonical DevCore 1.2.1 rendering correction.
PR #7 was independently approved at `520c8a4` and merged at
`cc57a70c54478f93bf7a68cac5935486c58ee25a`. Its resulting tree equals the tested
candidate; the separate main CI run `44132976402` passed both checks.
Live WELL-147 comment `7532bb56-a394-4dc9-8db1-e9a0edb58b66` records the
separately verified installation of 1.2.1 with executable SHA-256
`2ed9f8bba9abd3775b578bf159bb1c01787dac33cbbc668d71849752171916b7`.
This is recorded installation evidence, not a fresh checksum observation by
this source change. Installation does not establish activation. Acquisition was
last recorded disabled, with two quarantined generations preserved. Re-enable
only after the exact-target reconciliation and authorized pilot gates below.
Quarantine reconciliation requires an independently reviewed procedure for its exact targets;
do not erase registry records or bypass the recovery guards.

## Later bounded verification evidence

At source `bbcc272a7973bf1c1099564987a326f0bebae1e6`, against base
`fc8e12fb2b5710322f8011fdcfff4322cbfd244d`, the owner separately authorized
one six-file diagnostic and one later canonical fast/deep invocation on
2026-11-19. The diagnostic passed 79 tests. The canonical executor passed 139
focused Python tests, the complete fast gate with 1,046 application tests, and
`check.deep` with zero Dialyzer errors or skips. Each successful managed
generation received ordinary automatic cleanup, followed by independent catalog
and registry checks. Admission was disabled afterward. Original quarantines 1
and 2 and retained pilot B remained unchanged. Catalog checks also confirmed the
managed roles had no legacy TEST CONNECT privilege.

The earlier browser failure did not reproduce. Existing asset files were present
and unchanged during the diagnostic, so these results do not establish the old
failure's cause. The full fast run placed asset executables inside the selected
worktree build directory and left no downloader binaries in the source root.

These observations supersede earlier pending-execution statements only within
this measured scope. The recorded single-job window and resource samples do not
certify two simultaneous full suites. Keep heavy engineering work bounded to one
until further reviewed admission proof. No routine activation, quarantine
reconciliation, hosted CI, founder Master Gate, merge or resulting-main proof is
certified by these local results. The canonical capability map records the exact
source and proof limits; raw diagnostic evidence remains private.

## Verification consumers

This bounded consumer update changes command routing and instructions only.
The root integrator maintains the existing capability map for the assembled
WELL-147 implementation; this package does not create a second map.

This file is the canonical operating guide for command selection. The
code-change-verification skill remains the owner of final engineering gates;
its handoff executor selects both focused Mix tests and broad gates using this
worktree's declaration. An opted-in worktree enters through `tools/newyou-local`.
The wrapper and DevCore must validate admission and activation before execution.
A disabled pool or invalid proof stops the command without shared TEST fallback.
Inside an existing managed job, the executor uses `devcore-project run test`.
DevCore verifies live ownership and descendant membership before reusing that
assignment, without acquiring another lease. Partial managed markers fail closed.
The wrapper owns mutable-build admission for that job, including nested commands.
Do not start concurrent mutable builds inside it.

Non-opt-in worktrees retain `mise exec -- devcore-project run dev|test -- ...`,
manual legacy port coordination and the shared TEST/PLT lock protocol until they
consent and cut over. Existing agents must not switch during active jobs.

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
requires reviewed DevCore 1.2.1 or compatible 1.x. DevCore supplies command-local
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

Compound TEST commands that the automatic classifier cannot recognize must
request the same heavy gate explicitly through the wrapper:

```sh
mise exec -- tools/newyou-local test --heavy -- mix do ecto.migrate, run test/proof/managed_slot_probe.exs
```

This syntax is TEST-only and still requires the separate operational pilot
authorization. The wrapper retains its build lock and prior-job checks before
calling DevCore `slots run --heavy test -- ...`. It accepts no generic option
forwarding. Arguments after the separator belong to the child command. Existing
DEV/TEST commands retain their behavior, and nested managed jobs continue to use
the verified DevCore reuse path. A direct allocator invocation is not a substitute
for the wrapper's build admission.

The automatic expensive-command capacity is provisionally at most two, bounded
further by CPU and memory. Focused tests in different worktrees do not share that
gate. Workstation suite memory/throughput and the final capacity remain unmeasured;
twenty configured slots do not establish capacity for twenty heavy suites.

## Probe control for an authorized pilot

The probe input requires an absolute `control_directory` for seed and empty
modes. The coordinator supplies a fresh directory owned by the invoking user
with mode `0700`, without symlinked path components. Records are exclusive
`0600` files, bounded to 4096 payload bytes. A complete record ends in a newline;
stdout remains diagnostic and must not drive readiness.

`test/proof/managed_slot_coordinator.py` exposes `coordinate(directories,
identities, inputs, timeout=30, cancelled=...)` for two already-owned probe
stdin streams. The caller supplies independently verified exact lease,
generation, job, worktree, database and role identities. The coordinator waits
for both `ready.json` records before sending ready acknowledgements with peer
database names, then waits for both `done.json` records before acknowledging
completion. The probe validates every acknowledgement against its identity.
The caller must check actual process exits and preserve their logs and receipts.
The coordinator does not acquire, release, retain, enable or clean resources.

Malformed, oversized, replaced or unsafe records, wrong identity, cancellation
or timeout stop coordination. Cancellation is sent to the owned streams where
possible; evidence stays in place and process/lease disposition remains with the
single database coordinator. A failed acknowledgement or child exit must retain
the managed run for diagnosis. These controls do not authorize a pilot or
supervisor-loss reconciliation. Standalone subprocess tests exercise the actual
seed barriers with synthetic adapters; live SQL and child execution still need
the authorized application proof.

### Reviewed pilot driver

`python3 tools/well147_pilot.py --expected-source REVIEWED_SHA` performs read-only
prerequisite checks by default. It binds the exact two pilot worktrees, source,
installed tool and manifest. Dry-run success grants no execution authority.

The execute path requires `--execute`, the reviewed source SHA, a fresh private
`--evidence-root`, an owned `0600` `--window-receipt`, and separate owner,
exclusive-window, legacy-owner-clearance and capacity references. These references
are externally approved evidence, not authority authenticated by the program.
The receipt binds all references, the exact worktrees, manifest and tool checksum,
coordinator PID, UTC expiry of at most 30 minutes and maximum two heavy jobs.
An authorized coordinator must prepare it in the same process before invoking
`main`, or preserve that PID through exec. The driver never creates approval.

The driver launches the fixed migration/probe commands through explicit heavy
wrapper admission, queues initial input immediately and verifies independent
status/process/catalog identity before advancing barriers. It accepts the known
owned preparation states while waiting for a job. Occupied TEST reservation ports
must belong to the captured supervisor and bind loopback. Foreign allocations,
listeners, source drift, unknown capacity or failed window checks refuse.
Completion requires actual process exits, exact job receipts, successful cleanup
of the successful new generation, and the deliberately retained synthetic failure.

The driver cannot enable, disable, acquire directly, release retained generations,
recover quarantines, change ACLs or terminate supervisors. Enabling admission and
its closeout require separate owner authorization and independent operational
review. Failures send only protocol cancellation to owned streams, wait boundedly,
and preserve private logs, control records, read diagnostics and surviving PID
receipts. Do not retry an acquisition or remove retained resources automatically.
Current synthetic source tests do not establish live readiness or suite capacity.

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

The explicit `NEW_YOU_DATABASE_MODE=ci` path requires both existing CI flags and
the distinct ephemeral database and role `new_you_ci_test` on loopback port
55433. It rejects the retained workstation `new_you_test` identity even with all
flags set. These caller-controlled flags select a fixed CI binding and provide
no authentication. The local entry point rejects that mode; partial managed
markers always reject even in CI mode. The hosted service provisions only its
ephemeral CI identity. Workstation CI databases are not provisioned by this task.

Pure LocalConfig, temporary-metadata cache and admission tests alone do not
prove real NewYou database isolation. The bounded 2026-11-20 two-agent pilot
observed successful migrations, distinguishable Ash-backed fixtures, isolation,
children and fresh empty cleanup in actual managed TEST databases. However, its
private controller exited 1 before publishing `acceptance.json`; the independent
17-check offline reconciliation is supplemental, not a successful original
acceptance receipt. Outstanding requirements include final-head canonical local
gates and independent review, adjudication of remaining child/browser/recovery
and intentional failure-retention criteria, full-suite resource/capacity limits,
exact-head hosted CI, and separately approved merge and activation. See the
[dated resume handoff](well-147-pause-and-resume.md); do not infer readiness to
merge or activate from the successful backend seed/empty lifecycle.
