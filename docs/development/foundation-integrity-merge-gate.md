# Foundation Integrity merge gate

This is the current operational CI contract. The workflows define executable behaviour; this document explains their lane boundaries.

## Required gate

The procedural Master Gate requires a successful **Foundation Integrity** check. GitHub Free does not enforce that requirement or protect `main` in this private repository. A writer can bypass the procedure, an owner-accepted risk described in [GitHub branch governance](github-branch-governance.md). Every pull request runs Foundation Smoke. Ordinary pushes to `main` do not start this workflow. Application CI runs when the change contains application or engineering paths. Foundation Full runs only in the nightly hardening workflow and is not part of PR checks or the required aggregate.

The aggregate requires successful routing and Smoke, plus successful Application CI and Hex security audit when selected. It does not wait for Foundation Full.

## Semantic path ownership

The repository path communicates the normal CI route:

| Paths | Route |
| --- | --- |
| `docs/governance/**` | Smoke |
| `docs/history/**` | Smoke |
| Foundation Full/provenance machinery | Smoke |
| `docs/delivery/**` | Smoke + applicable Application CI |
| `docs/development/**` | Smoke + applicable engineering CI |
| application source, migrations and tests | Smoke + Application CI |
| `.agents/**`, `AGENTS.md` and normal engineering files | Smoke + applicable engineering CI |
| unknown, empty or unclassifiable diffs | route job fails; Smoke still runs |

Classification is explicit. Python files under `tests/` do not select Application CI by language or location alone. Foundation Full tests and tooling are named directly in the classifier so governance-owned changes can skip Application CI. No PR path selects Foundation Full. Unknown paths and unreadable ranges fail the required route job.

Delivery state such as Ready, blockers, dependencies, PR review and Done remains in Plane project `WELL`; it is not mirrored into repository documents.

## Foundation Smoke

Smoke validates both current routers:

- `docs/governance/CURRENT_GOVERNANCE_ROUTER.json` routes current durable law and genuine supporting authority only.
- `docs/delivery/CURRENT_DELIVERY_ROUTER.json` routes current Feature, JIT, proof, execution and content-evidence contracts beneath governance.

Smoke runs the path-classification regression tests and checks router identity, route containment, target existence, hashes, required authority inventories, the `docs/README.md` entrypoint, required historical files and merge-gate topology. Governance cannot route into delivery or history; delivery cannot route into governance or history. No current route may resolve into an archive.

## Foundation Full

Full runs only through the scheduled Nightly hardening workflow against `main`. Its nominal schedule is 02:00 Africa/Johannesburg. It validates the frozen `docs/history/CURRENT_AUTHORITY_MANIFEST_v1.0.0.json` and historical certification suite. The frozen `docs/history/02_OPEN_WORK_v1.2.90.md` remains evidence only; it is not live execution authority.

Foundation Full has no PR or manual-dispatch trigger. A regression is detected after merge by a later nightly run and must be triaged against that run's recorded main SHA. GitHub may delay or drop scheduled starts, so 02:00 SAST is the configured target, not a guaranteed runner start.

## Application CI

Application CI runs the canonical `mix check` gate for routed application and engineering changes. The slower `mix check.deep` Dialyzer lane runs when application source, migrations or the dependency/toolchain definition changes. Documentation-only delivery/development changes, agent guidance and test-only changes skip the deep lane. The classifier never selects Full solely because a change is under `docs/delivery/**`, `docs/development/**`, `.agents/**` or `tests/**`.

The historical pre-migration suite and audit use temporary compatibility views inside Foundation Full. They rebuild pinned baseline files at frozen paths, then overlay `docs/history/` evidence so provenance mutations remain visible. The temporary views do not add a legacy documentation root to the repository or either current router. Foundation Smoke validates current governance and delivery routing directly.

See [Foundation Integrity CI](foundation-integrity-ci.md) for certification history and command details.

## Independent resulting-main attestation

The independent Master Gate reviews the exact PR head and diff, confirms all
review and security conditions, and verifies the private repository and
unprotected branch state before merging. Capture evidence while the PR is open, after the
required gate succeeds. The collector reads GitHub's PR, repository, branch, run,
check-run, job, checkout-log and Git commit APIs. The reviewer supplies the
head they independently reviewed; this command does not perform the review.
Use a trusted checkout containing the reviewed attestation tool and a `gh`
session authorised to read the repository and Actions logs.

```bash
python3 -m tools.ci_attestation before --trust-mode private-procedural --review-record review.json --pr PR_NUMBER --reviewed-head REVIEWED_HEAD_SHA --run RUN_ID > before.json
```

The independent reviewer records `reviewed_head`, `reviewer`, `review_reference`
and the SHA-256 `diff_sha256` of the reviewed full diff in `review.json`:

```json
{"reviewed_head":"<40-character head SHA>","reviewer":"<independent reviewer>","review_reference":"<durable review reference>","diff_sha256":"<64-character SHA-256>"}
```

Independently verify the review
reference, reviewer, full diff and digest, and retain the record in trusted
custody. The collector validates their presence and binding, but does not verify
the review itself or calculate the diff digest. Record the command output and its digest with the independent review evidence.
Do not use a file produced by an untrusted PR checkout. The PR Actions API's
`head_sha` identifies the PR head, not the merge candidate. The collector
requires the exact candidate from checkout logs for each executed required
job, and verifies its parents and tree. It also requires the successful
`Foundation Integrity` check identity from the latest run, the explicit
private procedural mode and reported branch state. Full is non-blocking;
investigate a relevant Full failure.
Any changed head, base, candidate, run attempt, checkout, or review invalidates
the evidence. Recapture and re-review as appropriate. Immediately before an
authorised merge, recheck the PR and current main; use a merge commit with
`gh pr merge PR_NUMBER --merge --match-head-commit REVIEWED_HEAD_SHA`. Do not
use auto-merge or a bypass. This command requires separate merge authorisation.

After an authorised merge, immediately run from the trusted checkout:

```bash
python3 -m tools.ci_attestation after --trust-mode private-procedural --review-record review.json --pr PR_NUMBER --reviewed-head REVIEWED_HEAD_SHA --run RUN_ID --before before.json > after.json
```

The collector re-reads GitHub evidence and requires the resulting main to be
the PR merge commit, with exactly the reviewed base and head as parents and
the CI-tested candidate tree. It rejects squash and rebase merges, unknown
methods, concurrent main drift, missing logs and mismatches. Those cases
require explicit fresh exact-SHA verification and independent reconciliation
before Plane Done or dependent work. For that exception, check out the exact
resulting-main SHA in a trusted isolated workspace, verify its SHA and tree,
run Foundation Smoke and the applicable `mix check` and `mix check.deep` gates
with DevCore, and record their output. Foundation Full remains deferred to the
next nightly run and does not delay this verification. Resolve provenance or
review failures separately; passing fresh tests cannot repair an unreviewed merge.
The saved evidence is not itself a signature or a review approval; the
independent reviewer must preserve and check its provenance. Reusing PR CI does not create a check run on main.
Foundation Full is part of nightly hardening only; there is no manual dispatch.

## Hex security audit

WELL-83 adds an independent blocking Hex lane to the same required Foundation
Integrity aggregate. Foundation Full is not selected from PR paths. The audit
selects dependency/toolchain inputs, production source and configuration, all
workflows and tools, Python regression tests, and the compiled authentication
reachability guard. Unknown or unreadable event ranges select the audit. These
extra source/config inputs detect changes to exception reachability.
The aggregate rejects a missing routing decision and any required audit result
other than success. Smoke runs the audit boundary regression tests on every PR.

The separate `hex-security-audit.yml` schedule checks out current `main` at run
time, only on the main ref. It does not depend on a PR diff or Foundation Full.
A failing nightly job is a maintainer obligation to triage in Plane, not permission
to suppress findings. No external scanner or policy service is introduced.

Hex 2.6.0 was verified on 2026-11-04 against its official installation manifest,
tagged task/SARIF source and the actual CLI on Elixir 1.20.5 / OTP 29.1.2.
References: [audit task](https://hex.hexdocs.pm/Mix.Tasks.Hex.Audit.html),
[tagged implementation](https://github.com/hexpm/hex/blob/v2.6.0/lib/mix/tasks/hex.audit.ex),
[installation manifest](https://builds.hex.pm/installs/hex-1.x.csv).
The task emits SARIF 2.1.0 and exits 1 for findings. Suppressed findings disappear
from SARIF, so the runner does not evaluate the application project or inherit
Hex ignores. It generates a minimal project with every locked Hex package as an
exact root, copies the committed lock, uses fresh temporary Hex/Mix homes, installs
exact Hex 2.6.0, and runs `deps.get --check-locked` followed by `hex.audit`.
No compilation, application loading/startup or project aliases run. The lock must
remain byte-identical. Git asset dependencies remain in the lock but are outside
Hex package-registry coverage and are not fetched. Unsupported lock shapes fail.
No registry, dependency or advisory caches are restored. CLI output and SARIF stay
in job logs. Missing reports, malformed evidence, network failures and unexpected
exit codes fail visibly. The audit is absent from ordinary `mix check`.

### Retained Assent disposition lifecycle

The active record is `tools/hex_audit/assent_exception.json`. Independent approval
is WELL-91 comment `b8ac8764-c2c8-4dd9-b13e-802039e34790`, for PR #190 candidate
`4bec2a65aefbe2c6359c3857a4a53f20a8cf997c`. The candidate's lock, source and config
match WELL-83 base `c4da7161814a32ca9545a01e61ecbe450ac27a74`. JC remains accountable.
WELL-91 remains open for remediation/revalidation. This implementation grants no
new exception and no extension.

- Proposed records cannot disposition a failure. Activation requires independent
  review of the exact dependency graph, authentication strategies/routes/callers,
  advisory evidence, owner, follow-up and deadline through a reviewed PR.
- Active records pass only for the sole unsuppressed finding, package `assent`,
  version `0.2.13`, the exact EEF/CVE/GHSA alias set, reviewed summary, URL and
  critical severity. The result says `CONTROLLED DISPOSITION`, never clean.
- A changed lock, toolchain, `mix.exs`, any production source/config or the auth
  guard invalidates the input digest. This deliberately includes newly added
  files and unrelated production changes rather than risk missing a new caller.
  Updating a hash does not grant approval. A new stable AshAuthentication release
  also fails pending review, even if its Assent constraint has not changed.
  A new stable Assent 0.2 backport also fails pending revalidation.
  The release checks use the official Hex API, fail on unavailable/malformed
  evidence and does not install a release. Changed advisory details or aliases,
  new findings, retirement, wrong package/version and unmatched records fail.
- Expiry is exclusive at `2026-11-18T00:00:00Z`, a conservative interpretation of
  the latest authorised deadline. Dates before approval also fail. An expired or
  invalidated record cannot return to active without a new independent decision.
- Resolved or superseded records are terminal and cannot disposition findings.
  A reviewed remediation removes the active record by replacing it with `{}`.
  Only a fresh successful audit with zero findings then reports clean. A successor
  needs its own independent approval and future tracked obligation. This ticket
  does not authorise one.

Each run reconstructs the decision from committed evidence and current UTC time.
Retries start with a fresh home and registry fetch. No mutable lifecycle database,
process state, automatic renewal, environment escape hatch or broad ignore exists.
Audit script/workflow changes select the gate and require full-diff review. As with
other repository CI, an author able to rewrite the scanner or tests cannot be
restrained by those same files alone. Independent Master Gate review remains the
approval boundary.

### HIGH / privileged_security proof matrix

- Positive/negative and invariant proof applies. Tests cover exact disposition,
  a second vulnerability, retirement/unrecognised rules, wrong package/version,
  known and unknown aliases, changed severity/details, stale entries, expiry,
  inactive/unauthorised metadata, malformed/missing reports and conflicting exits.
- Lifecycle and authorization proof applies. Fixed approval/owner/deadline checks,
  production-input binding, stable-release invalidation and exclusive expiry
  reject unreviewed transitions. No application capability is granted.
- Routing/bypass proof applies. Tests cover dependency/source/config/tool/workflow
  changes and execute the aggregate shell against success, failure, cancellation,
  skipped and missing decisions. Smoke checks the aggregate dependency topology.
- Failure/retry/recovery proof applies. Installation/resolution failures stop the
  run, missing evidence cannot become a fabricated clean result, subprocesses and
  metadata requests have timeouts, and retries reconstruct from fresh state.
- Provider evidence applies to Hex only. The real fresh-home CLI run reports
  Assent with exit 1; the wrapper makes its distinct controlled decision. The
  stable parent release probe fails closed and never upgrades dependencies.
- Leakage review applies. Jobs have `contents: read` only, no application/database
  secrets, no persisted checkout credentials and no upload write permission.
  Package metadata and committed public lock evidence appear in diagnostics.
- Concurrency, duplicate/reorder and idempotent business writes are N/A. The audit
  has no business mutations or shared mutable exception state. Concurrent jobs
  use isolated temporary homes and independently compute the same decision.
- Migration/rollback, financial calculations, participant copy and privacy deletion
  are N/A. This change alters CI evidence only, with no schema, application
  behaviour, participant data or financial calculation changes.
- Independent security review applies. A read-only reviewer checked the audit,
  routing and exception boundary and identified the negative-rule-index parser
  case, now rejected with permanent regression coverage. Final exact-head
  approval remains with ChatGPT Master Gate.
