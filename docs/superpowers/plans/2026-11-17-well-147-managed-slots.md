# WELL-147 managed local slots

Implement the reviewed DevCore consumer contract after WELL-145 resulting main
`1a46dcc54d3ac37fa554955e20c45555c0e08f5b`. NewYou base is
`87a9c6306cc08bea5accb5518692842c115a463b`. This branch owns no WELL-144 or
WELL-136 changes. This plan itself grants no installation, activation, existing
ACL change, database reset or destructive cleanup authorization. Separate owner
authorizations and their observed results are recorded below.

## Implementation sequence

1. Extend LocalConfig at its existing pure environment seam. Verify a complete
   live managed job through canonical DevCore, then compare every endpoint,
   identity, generation, worktree, profile and HTTP assignment. Declared managed
   mode rejects absent markers, including an older installed executable's legacy
   environment. Preserve deliberate legacy consumers and the existing CI-owned
   database contract. Production retains its separate path.
2. Reuse Proof.Result's existing LocalConfig comparison. Audit actual child BEAM,
   browser, migration, restart and production-probe launchers. Preserve loopback
   binds and ephemeral helper ports. Prove actual child database identity.
3. Add the exact opt-in pool declaration, source/version preflight and narrow
   wrappers. Coordinate mutable builds per worktree, without serializing separate
   worktrees or isolated focused tests. Keep secrets with DevCore.
4. Prepare toolchain/input-keyed shared core PLTs behind a cache-specific lock,
   use worktree-local mutable copies for Dialyxir, and release the shared lock
   before analysis or database suites. Preserve CI cache behavior.
5. Maintain one source-linked capability map and operational instructions.
   Preserve legacy booking instructions until activation and proof finish.
6. Make code and exact installation/cleanup/ACL procedures reviewable before
   requesting those separate authorizations. Then run the authorized two-worktree
   synthetic business-fixture, failed-retain, clean-reuse, child and PLT proofs,
   measure expensive-suite concurrency, and complete unchanged final gates/OCR,
   exact-head CI, independent review and resulting-main reconciliation.

## Behaviour and proof matrix

Risk is HIGH for database identity and cleanup propagation. Reuse DevCore's
reviewed lifecycle and ownership authority; introduce no parallel allocator or
application database owner. This infrastructure change adds no business schema,
action or entitlement. Ash is not applicable to configuration validation, but
real synthetic business fixtures must use existing owning Ash interfaces.

- Managed identity: start with a valid complete live-verifier response and
  canonical binding. Accept it; independently vary each marker, endpoint,
  database/role, slot/port and profile. Reject without database connection or
  secret disclosure. Cover stale/failed/malformed verification and missing
  markers under declared opt-in. Test injected external verifier failures only
  at that boundary. Run the pure LocalConfig ExUnit file with pinned Elixir;
  this proof needs no Repo, test-helper startup or shared TEST access.
- Legacy compatibility: preserve exact DEV/TEST targets and existing worktree
  port restrictions only in deliberately supported legacy mode. CI retains its
  fixed disposable allocation. A partial managed context always rejects,
  regardless of compatibility mode. Verify old-DevCore failure before any
  NewYou database startup.
- Child propagation: observe actual server database/current role, not just
  strings. Verify regular tests, migrations, child BEAMs, restart, production
  probes and browser paths. Missing or substituted context must reject. Preserve
  helper port 0 and loopback locality.
- Cache concurrency: distinct worktrees have local builds/deps/project PLTs.
  Concurrent cold requests serialize shared preparation only; after preparation
  independent analyses overlap and have local mutable cores. Faults release
  locks safely or retain an unavailable incomplete cache, never publish dirty
  content. Existing active caches are preserved.
- Real data isolation/reuse: after exact target authorizations, migrate each
  fresh generation from its branch, commit distinct synthetic fixtures through
  business interfaces, prove cross-slot denial and absence of the other marker.
  Retain a deliberate failure and its logs; prove exact release/reacquisition
  has no previous rows and stale credentials cannot access the new generation.
- Final proof: unchanged `mix check` and `mix check.deep`, current handoff helper,
  capability/history checks, bounded local OCR with disclosed coverage/errors,
  exact-head hosted CI, owner review and independent resulting-main binding.
  No production/load/restore experiment is implied by this local tooling task.

## Initial observed baseline

`mise current` resolves OTP 29.1.2, Elixir 1.20.5-otp-29 and Node 26.2.0.
`mise exec -- elixir --version` confirms OTP 29 / Elixir 1.20.5.
`mise exec -- elixir -r lib/new_you/local_config.ex -e 'ExUnit.start(); Code.require_file("test/new_you/local_config_test.exs")'`
passed all six existing pure tests. No Mix/Repo startup or database operation ran.
Read-only listener inspection found port 4237 occupied on loopback; it is
unavailable. No open holder was reported for the legacy lock at that instant.
Neither observation authorizes use of shared TEST or reclaiming a listener.

## Source checkpoint evidence

NewYou `origin/main` was refreshed and remained
`87a9c6306cc08bea5accb5518692842c115a463b` before this source checkpoint.
Checks apply to this branch's inspected source bytes, not a final PR candidate.

- `mise exec -- elixir -r lib/new_you/local_config.ex -e 'ExUnit.start(); Code.require_file("test/new_you/local_config_test.exs")'`
  passed 18 tests. The initial managed behavior tests failed for absent guards
  before implementation. Final coverage includes all 20 receipt-bound ports,
  stale/partial/substituted context, strict endpoint identities and deliberate
  legacy/CI compatibility. It starts no Repo.
- `python3 -m unittest tests.test_local_session tests.test_local_plt_cache tests.test_foundation_lane_routing tests.test_phase8_proof_workflow -v`
  passed 65 tests. Admission and cache tests use temporary metadata and owned
  temporary processes. They cover concurrent cache preparation, private copies,
  failed publication, tamper rejection, old-version rejection, redaction,
  same-worktree exclusion, cancellation and real Mise/Bash exec descriptor
  inheritance until a launcher-orphaned child finishes. They do not provision DBs.
- `mise exec -- mix deps.get` passed without changing `mix.lock`.
  `mise exec -- mix deps.compile jason dialyxir` passed; compiling those selected
  dependencies before Erlex produced undefined-Erlex warnings. The later complete
  `mise exec -- mix compile --warnings-as-errors` passed and compiled the actual
  application and task. Neither compile starts the application or Repo.
- `mise exec -- elixir -pa _build/dev/lib/jason/ebin -pa _build/dev/lib/dialyxir/ebin -e 'Mix.start(); Code.require_file("mix.exs"); Code.require_file("lib/mix/tasks/local_dialyzer.ex"); ExUnit.start(); Code.require_file("test/tools/dialyzer_cache_test.exs")'`
  passed eight pure task/configuration tests. This also runs the ten-test Python
  cache adapter suite. Missing-input guards had observed failing tests before
  implementation. No PLT analysis or database is part of these tests.
- The changed Elixir paths passed `mise exec -- mix format --check-formatted`
  after removing one extra final newline reported by its first check.
- `mise exec -- /usr/bin/time -v mix dialyzer --plt` passed real cold preparation
  and private project/core PLT creation, wall time `2:58.40`, maximum RSS `3692448`
  KiB, no swaps. It used the new cache namespace without a TEST lease or legacy
  TEST/PLT lock. This is not the final TEST-profile `mix check.deep` gate.
- `mise exec -- /usr/bin/time -v mix dialyzer --format dialyxir` failed with 20
  DEV-profile warnings. Two were introduced unknown-function warnings from the
  new task calling Dialyxir, which was absent from the project PLT. Focused
  configuration tests first failed, then passed after adding the already pinned
  `:dialyxir` to `plt_add_apps`. Fresh analysis of that changed input, the same
  command, failed with 18 warnings, none from LocalDialyzer. Communications and
  Privacy warnings remain unclassified against a separate base DEV run. No warnings
  were suppressed and neither DEV analysis is a passing check.
- `mise exec -- env MIX_ENV=test /usr/bin/time -v mix dialyzer --format dialyxir`
  passed TEST-profile static analysis with zero errors/skips, initially including
  cold preparation in `4:25.69`, maximum RSS `3465708` KiB. Peer preparation via
  `mise exec -- env MIX_ENV=test /usr/bin/time -v mix dialyzer --plt` passed in
  `4:11.22`, maximum RSS `4087804` KiB. Neither starts NewYou or Repo.
- The same TEST analysis command then ran concurrently in this worktree and
  `well-147-isolation-peer`, both at implementation source
  `e583d5cd22c42b7850711ecf07c15a27702bd85b`. Both passed, with analysis overlapping
  `17.385` seconds and the cache lock available during the overlap. Receipt:
  `/tmp/newyou-well147-final-parallel-analysis.json`; individual logs have the
  same prefix with `-1.log` and `-2.log`. This proves independent prepared-cache
  analysis, not actual simultaneous cold production of a shared core.
- Both worktrees passed `mise exec -- env MIX_ENV=test mix compile --warnings-as-errors`.
- `mise exec -- python3 -m unittest tests.test_capability_knowledge tests.test_knowledge_capture -v`
  passed 34 knowledge tests. The source-linked map remains descriptive, not approval.

Temporary native review identified a conditional CI-compatibility concern.
`NEW_YOU_DATABASE_MODE=ci` plus both CI flags is deliberately supported legacy
configuration, not authentication of hosted origin. The local wrapper rejects
that override, and partial managed markers always reject. The operating guide
forbids using those flags to bypass local allocation. Independent Master Gate
must assess this documented boundary; author judgment is not reviewer approval.
The review's descriptor-inheritance uncertainty has a passing real exec-chain
regression, but real DevCore supervisor failure remains covered by the separate
allocator contract and still requires the application pilot.

## Authorized workstation checkpoint

The owner separately approved the exact 1.2.0 source artifact installation,
the manifest-bounded disposable-generation contract and the guarded legacy TEST
ACL REVOKE in this task on 2026-11-17. The installer observed executable SHA-256
`e76cb9206d6e00226ab9549bfa2a342c4da867f2a7d21956240035b1bf65d93a`
and retained a backup matching previous 1.1.0 SHA-256
`df7dd3263197d33416b99699b5f09ee2b37bb4a45f55cc2a7bb4164dbbff9568`.
The working source/installer files were compared with resulting main before use.

The guarded transaction changed only
`REVOKE CONNECT ON DATABASE new_you_test FROM PUBLIC;`, with TEST container
identity, database OID `4687800`, owner identity, original ACL, NOCREATEDB,
NOSUPERUSER, zero memberships and no unknown connection roles checked before
mutation. A private receipt preserves original ACL and before/after identities.
Owner CONNECT remained true, PUBLIC CONNECT became false, existing owner
connections remained and no rows or databases were removed. Authenticated DEV
and TEST `mise exec -- devcore-project doctor` passed after installation/ACL.

The installed `slots manifest` contract equals reviewed digest
`3fb71d0ed24dfc4ab8ef75226916da624f5ca4a18343695a154733eb2a93e556`.
It reports 24 logical CPUs, `33562959872` memory bytes, provisional heavy cap two
and occupied port `4237`. No listener was stopped. Enable still requires the
owner's authenticated exact GitHub approval comment. No managed database has
been provisioned, and no routine cleanup has run on this workstation.

## Historical pre-pilot verification gap

WELL-147 is not review-ready. Required live migrations, two-worktree committed
business fixture isolation, child/restart/browser/prod-probe execution,
intentional failed test retention and fresh clean reuse remain unverified.
Full-suite resource measurements are also pending. After the authenticated
manifest approval enables the bounded
pilot, finish that proof, then run the stable final `mix check` and
`mix check.deep` through the required executor. Only passing local gates permit
bounded OCR, authenticated separate NewYou PR/history generation, exact-head CI
and independent Master Gate. No NewYou merge or Done claim is made here.

The actual `mise exec -- tools/newyou-local test -- mix test test/new_you/local_config_test.exs`
entry attempt exited 1 with `ERROR: slot activation and disposable cleanup authorization are required`.
It launched no Mix child and provisioned no database. The owner's chat consent is
recorded; the missing authenticated GitHub artifact is the remaining enable guard.

## Historical pre-pilot assessment

Task type IMPLEMENTATION, author self-assessment of WELL-147 only. Against the
seven live acceptance groups, PASS 0/7 in full: groups 1, 2, 3 and 6 are UNVERIFIED
with partial source/test evidence; groups 4, 5 and 7 are NOT_DONE. The groups cover
strict configuration, subprocess propagation, build/PLT isolation, real business
fixture isolation/reuse, measured heavy capacity, operational adoption, and final
gates/review respectively. No completed DevCore criterion is counted as a passed
NewYou criterion.

Implementation Score 5/10 = requirements 2/4 + observed verification 1/3 +
correctness/architecture/risk 1.5/2 + handoff 0.5/1. Confidence Score 85% in this
partial assessment, supported by focused negative/concurrency tests and actual
parallel static analysis. Positive managed database and child execution remain
the highest-risk unknowns. Verification Status BLOCKED for the live feature,
pending the authenticated approval artifact. Merge readiness
NOT_VERIFIED_FOR_MERGE.

The three-point gap to 8/10 reflects missing real application proof and full
repository/review evidence, not an estimate of remaining effort. First enable
against the owner's exact authenticated comment, then prove migrations, business
fixtures, child paths, retention/reuse and heavy capacity. Finish the required
executor gates, OCR, exact-head CI and independent Master Gate before reassessing.
No additional routine-operation consent is needed inside the approved contract.


## Corrective checkpoint after independent review, 2026-11-17

The earlier pre-pilot sections above are historical. The authenticated approval
artifact is now present and was accepted by installed DevCore 1.2.0. It is no
longer the activation blocker. WELL-147 remains Changes Requested.

At source `c5096feabd8c4bc482aaa0d79b87893eecf6b4f4`, based on
`87a9c6306cc08bea5accb5518692842c115a463b`, R1-R3 have permanent regressions:

- R1 duplicates the inheritable worktree lock descriptor above DevCore's heredoc
  descriptor. The regression kills the identified Bash launcher while the actual
  installed supervisor is blocked before job registration; admission stays locked.
- R2 uses the distinct `new_you_ci_test` CI database and role. Direct LocalConfig
  rejects workstation shared TEST even with both caller-controlled CI flags.
- R3 opens cache manifests without following symlinks and without blocking, then
  requires an owned regular file. FIFO, socket, directory, symlink, wrong-owner
  and interrupted-copy tests preserve the resource and release the cache lock.

Observed focused commands and results:

- `python3 -m unittest tests.test_local_session tests.test_local_plt_cache tests.test_foundation_lane_routing tests.test_phase8_proof_workflow -q`
  passed 72 tests. Log `/tmp/newyou-well147-corrections-final.log`.
- The focused LocalConfig run passed 19 tests. Cache and admission counts within
  the Python result are 14 and 11 respectively.
- `mise exec -- env ERL_FLAGS='+S 4:4' elixir -e 'Path.wildcard("_build/test/lib/*/ebin") |> Enum.each(&Code.append_path/1); Code.require_file("test/tools/managed_slot_probe_test.exs")'`
  passed eight pure probe tests. Log `/tmp/newyou-well147-probe-framing-green.log`.
- `mise exec -- python3 -m unittest tests.test_capability_knowledge tests.test_knowledge_capture -q`
  passed 34 tests in 11.755 seconds. Log `/tmp/newyou-well147-corrected-knowledge.log`.
- During the approved pilot, `mise exec -- env ERL_FLAGS='+S 4:4' tools/newyou-local test -- mix test test/new_you/bootstrap_test.exs test/new_you/proof/result_test.exs`
  ran current-branch migrations and passed 35 tests after two hard-coded legacy
  identity assertions were corrected. The original failing run and its diagnosis
  were retained before exact-target release. Log of the corrected run:
  `/tmp/newyou-well147-managed-tests-corrected.log`. This is focused proof, not a
  full application gate or a two-worktree isolation result.

The first parallel pilot failed one private environment preparation. Its generic
error did not retain the underlying renderer stderr. Independent temporary-state
reproduction then proved a canonical DevCore contention bug and descriptor
failure-path double-close. Separate WELL-154 corrects those defects in DevCore
1.2.1 source. The correction has passing contention, parallel-binding, timeout,
cancellation and full local suite evidence, but is not installed or integrated.
This NewYou source now rejects installed 1.2.0 before acquiring another slot.

A diagnostic staggered pilot reached two READY receipts with different databases,
one owned synthetic account each, zero peer accounts and browser login completed.
Its protocol then stalled behind DevCore's output redactor. The probe now frames
its receipt output, with a regression, but no subsequent live run is claimed.
Only the identified pilot controller was cancelled. Supervisor ownership later
became uncertain. Acquisition was disabled and guarded recovery quarantined both
generations. The preserved exact database targets are:

- Slot 01, lease `8cc90b5589204c89a5928c7b41bc446a`, generation
  `81b50e14dc024b308b420ef58e2ac679`, database
  `dc_new_you_s01_g81b50e14dc024b308b420ef58e2ac679`.
- Slot 02, lease `7b031a3f06e546578436ad5f01a67df7`, generation
  `3d5284ee0b1945f6b36d6b166f7c41f6`, database
  `dc_new_you_s02_g3d5284ee0b1945f6b36d6b166f7c41f6`.

Each recorded runtime role is the exact database name plus `_r`. Private receipt
`/tmp/newyou-well147-preserved-quarantine.json` and pilot directory
`/tmp/newyou-well147-pilot-dd1cb5cb454247fc96b2795beeb92786` retain diagnostics.
No database, secret entry or registry record was removed to bypass quarantine.
Existing DEV, shared TEST, active agents and the port 4237 listener were preserved.

Next, integrate and verify WELL-154, obtain exact authorization for its new
executable installation, and review an exact-target reconciliation procedure.
Do not treat the earlier 1.2.0 installation approval as covering 1.2.1. Do not
force release or edit quarantine records. After safe workstation preparation,
complete the automatic parallel pilot, child/restart/prod-probe paths, cross-slot
CONNECT denial, intentional failure retention and fresh generation reuse. Measure
heavy capacity and run the authorised final `mix check` and `mix check.deep`
executor, then NewYou OCR, Draft PR/history, exact-head CI and fresh Master Gate.

Current assessment: IMPLEMENTATION, author self-assessment of WELL-147. PASS 0/7
live acceptance groups in full. Groups 1, 2, 3 and 6 are UNVERIFIED with partial
proof; groups 4, 5 and 7 are NOT_DONE. Implementation Score 5/10 = requirements
2/4 + verification 1/3 + correctness/risk 1.5/2 + handoff 0.5/1. Confidence 85%
in this assessment, supported by focused regressions and observed managed
migrations. Verification Status BLOCKED for the live feature. Merge readiness
NOT_VERIFIED_FOR_MERGE. The principal uncertainty remains complete application
isolation and recovery/reuse under real child processes. The three-point gap to
8/10 requires the live proof and final gates above, then independent review;
planned work earns no points. DevCore's separate evidence does not complete a
NewYou acceptance group.


## DevCore source integration checkpoint

WELL-154 PR #7 has independent full-diff approval for exact head
`520c8a4db118d4d946a3ecb5096461b57a584b34`. Both hosted checks passed in run
`44125681091`, including five PostgreSQL integration-lane tests. All six OCR
exclusions were independently reviewed. The normal head-bound merge produced
`cc57a70c54478f93bf7a68cac5935486c58ee25a`. Its ordered parents equal reviewed
base/head, and its complete tree equals tested candidate
`889023ed0cdbca1a378fcdd5756e83ebe1f2ce60`. This is exact tested-tree reuse,
not a claim that separate main run `44132976402` passed; that run was pending.

The new executable SHA-256 is
`2ed9f8bba9abd3775b578bf159bb1c01787dac33cbbc668d71849752171916b7`.
It is staged from resulting main but not installed. Source approval expressly
excludes installation and quarantine cleanup. NewYou acquisition remains disabled
and its two quarantines remain preserved. WELL-147's implementation assessment
and outstanding live/final gates above are unchanged.

Fresh resulting-main CI run `44132976402` subsequently completed successfully
for exact `cc57a70c54478f93bf7a68cac5935486c58ee25a`. Both `checks` and
`postgres-integration` passed. The logs show 158 unit tests with 155 passes and
three opt-in SQL skips, plus five passing integration-lane tests. WELL-154 source
integration is complete; exact installation authorization and quarantine
reconciliation remain separate. This does not advance NewYou's application proof.
