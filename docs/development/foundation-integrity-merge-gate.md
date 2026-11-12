# Foundation Integrity merge gate

This is the current operational CI and merge contract. The workflows define the executable lanes; this document explains their boundaries, review authorization and resulting-main proof.

## Required gate

The public repository protects `main` with active ruleset `24191860`, which requires a pull request and a successful **Foundation Integrity** status check. Eligible development follows the review and merge procedure below. Apply stronger approval only when a governing or external obligation requires it. Foundation Integrity comes from hosted pull request CI. Every pull request runs Foundation Smoke. Application CI and the Hex security audit run when changed paths select them. Foundation Full runs only in the scheduled nightly hardening workflow and is not part of PR checks or the required aggregate. The application cache warmer is separate. It may save dependency caches from trusted `main` pushes; PR runs may restore those caches but do not save them. Cache entries contain no test results or build output.

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

## Automatic implementation knowledge

Foundation Smoke regenerates each PR's committed history record from the event's exact base/head using the pinned Elixir parser. A mismatch, invalid ticket metadata or missing record fails the existing required gate. It validates capability-map source hashes and runs extraction regressions. The job has read-only contents permission, no Plane credentials and no branch mutation. See [knowledge](knowledge/README.md) for generation, current index queries and known extraction limits. Independent review verifies semantic claims separately.

## Foundation Full

Full runs only through the scheduled Nightly hardening workflow against `main`. Its nominal schedule is 02:00 Africa/Johannesburg. It validates the frozen `docs/history/CURRENT_AUTHORITY_MANIFEST_v1.0.0.json` and historical certification suite. The frozen `docs/history/02_OPEN_WORK_v1.2.90.md` remains evidence only; it is not live execution authority.

Foundation Full has no PR or manual-dispatch trigger. A regression is detected after merge by a later nightly run and must be triaged against that run's recorded main SHA. GitHub may delay or drop scheduled starts, so 02:00 SAST is the configured target, not a guaranteed runner start.

## Application CI

Application CI runs the canonical `mix check` gate for routed application and engineering changes. The slower `mix check.deep` Dialyzer lane runs when application source, migrations or the dependency/toolchain definition changes. Documentation-only delivery/development changes, agent guidance and test-only changes skip the deep lane. The classifier never selects Full solely because a change is under `docs/delivery/**`, `docs/development/**`, `.agents/**` or `tests/**`.

The historical pre-migration suite and audit use temporary compatibility views inside Foundation Full. They rebuild pinned baseline files at frozen paths, then overlay `docs/history/` evidence so provenance mutations remain visible. The temporary views do not add a legacy documentation root to the repository or either current router. Foundation Smoke validates current governance and delivery routing directly.

See [Foundation Integrity CI](foundation-integrity-ci.md) for certification history and command details.

## Eligible development merge

For eligible development work, ChatGPT Master Gate completes the technical review and publishes one authenticated JCSchoeman96 APPROVED review for the exact final head. That review is both technical approval and standing merge authorization. That is the only approval comment required for this route. Do not add a second founder comment or a base-SHA line. The implementing agent must not use founder credentials. Re-review any changed head.

Apply stronger approval only when a governing or external obligation requires it. Assess the actual consequence and obligations of the change. Paths or edits to CI, agent instructions, approval tooling or governance do not by themselves require a stricter route. If the governing approval requirement is unclear, stop the affected merge and resolve that specific requirement.

Before merge, verify the PR still targets the expected base, the exact final head has the authenticated APPROVED review, the current required CI is successful, and live branch protection still has the expected rules. From trusted integrated `main`, run the existing read-only candidate check:

```bash
python3 -m tools.ci_attestation native-candidate --pr NUMBER --reviewed-head REVIEWED_HEAD_SHA --run RUN_ID
```

The check verifies the current PR, base/head, review, required run, exact tested candidate, and live protected-main settings. It writes no evidence files and stores no merge intent. If it passes, perform the ordinary merge bound to the reviewed head:

```bash
gh pr merge --repo Carpe-Diem-Media/NewYou --merge --match-head-commit REVIEWED_HEAD_SHA NUMBER
```

Do not use an administrative bypass. If the merge request times out or its result is unclear, read the PR and current `main` before doing anything else. Never repeat the merge based only on a timeout or client error.

After merge, run the existing read-only result check from trusted integrated `main`:

```bash
python3 -m tools.ci_attestation native-result --pr NUMBER --reviewed-head REVIEWED_HEAD_SHA --run RUN_ID --candidate TESTED_CANDIDATE_SHA
```

The result must show that `main` points to the merge commit, whose ordered parents are the reviewed base then head, and whose tree equals the tested candidate. This check writes no files and creates no status check. If GitHub shows no merge or the result check cannot establish those facts, stop completion and resolve the discrepancy before moving Plane to Done or opening dependent work.

### PR #224 establishing transition

PR #224 remains under the current `main` requirements and cannot use the proposed future settings to approve itself. It requires fresh complete review and successful current CI, followed by explicit owner authorization for the exact merge transition. Collection-only comment 6821263762 is not merge authorization. Do not self-approve or self-merge PR #224. Since `.github/CODEOWNERS` is read from the base branch, its proposed contents cannot enforce review on this establishing PR.

### One-time GitHub settings after PR #224

After PR #224 integrates with explicit authorization, a separate authorization is required before changing GitHub settings or account access. The proposed configuration retains ruleset 24191860's required Foundation Integrity check, PR-only integration, no bypass, force-push and deletion protections, and merge-only method. It adds one approval, code-owner approval using the exact `.github/CODEOWNERS` entry `* @JCSchoeman96`, stale-review dismissal, approval of the latest push, and resolved review threads. Change rules before granting JC-Agents repository Write and organization Member access. Preserve JCSchoeman96's existing organization-owner/repository-admin access; do not grant those privileges to JC-Agents. Independently inspect the live ruleset, branch protections, CODEOWNERS errors, and access after the change. Do not describe the new enforcement as active until that verification passes.

The proposal in [founder-merge-admin-proposal.md](founder-merge-admin-proposal.md) is not authorization and does not change current settings.

### Legacy strict attestation lifecycle

The `ci_attestation before` and `ci_attestation after` file-based lifecycle is legacy. Do not use it for routine development merges. Use it only when a specific governing or external obligation explicitly requires that lifecycle. Existing archived attestations remain historical records and are not evidence for a new candidate. No new private custody files, JSON review records, before/after files, or custom merge wrapper are part of the routine route.

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

### Assent disposition history and WELL-100 retirement approval

The former active record and approval in WELL-91 comment
`b8ac8764-c2c8-4dd9-b13e-802039e34790` applied to PR #190 candidate
`4bec2a65aefbe2c6359c3857a4a53f20a8cf997c`, not the current dependency graph.
Its input digest is invalidated by the WELL-100 lock and source changes. The
approval, owner and exclusive expiry `2026-11-18T00:00:00Z` remain historical
evidence; this PR does not renew or extend them.

The current runner has no controlled-disposition path and does not read
`tools/hex_audit/assent_exception.json`. It accepts only a complete clean SARIF
report with no rules or results. Any result, including a suppressed one, fails.
Malformed or missing evidence, conflicting exit status, a changed lock during
resolution, or a dependency-resolution failure also fails closed. It no longer
probes for a later parent or Assent release because no exception is available to
revalidate.

The WELL-100 candidate resolves Assent `0.3.2`, which satisfies
AshAuthentication `5.0.0-rc.17` and is fixed for the referenced advisory. The
exception record now says `retirement_approved`. The accountable maintainer
approved retirement for dependency candidate head
`2376dda3a530f31b99d633f9061df0ece2d6977b`; the decision is recorded in
[WELL-91 comment `feab6ecf-0a09-4b9c-8240-0d055e700075`](https://app.plane.so/symphony-development/browse/WELL-91)
and the [WELL-100 addendum](ash-authentication-v5-well-100.md). The record is
not read by CI. Owner approval does not certify the current PR head or change
`main`. Independent Master Gate must review the exact head, graph, advisory,
route and action reachability, and both clean audit results before merge. The
exception retirement becomes effective on `main` only when the approved change
merges. WELL-91 remains in Planning with its original expiry unchanged. Any new
audit finding fails; no suppression, automatic renewal, environment escape hatch
or broad ignore exists.

Each audit still runs from fresh temporary Hex/Mix homes, pins Hex `2.6.0`, uses
the committed lock as exact dependency roots, verifies locked resolution and
byte-identical lock content, and prints its SARIF evidence. Audit script/workflow
changes select the gate and require full-diff review. As with other repository
CI, an author able to rewrite the scanner or tests cannot be restrained by those
same files alone. Independent Master Gate review remains the approval boundary.

### HIGH / privileged_security proof matrix

- Positive/negative and invariant proof applies. Tests cover a clean report, any
  finding, suppressed findings, malformed/missing evidence, scanner mismatch,
  lock resolution and unchanged-lock checks. The former exception behavior is
  removed rather than rebound.
- Lifecycle and authorization proof applies. There is no active exception state
  to transition and no application capability is granted. The owner approved
  retirement for dependency candidate head
  `2376dda3a530f31b99d633f9061df0ece2d6977b`; independent Master Gate must
  certify the current PR head before merge. Retirement takes effect on `main`
  only when the approved change merges.
- Routing/bypass proof applies. Tests cover dependency/source/config/tool/workflow
  changes and execute the aggregate shell against success, failure, cancellation,
  skipped and missing decisions. Smoke checks the aggregate dependency topology.
- Failure/retry/recovery proof applies. Installation/resolution failures stop the
  run, missing evidence cannot become a fabricated clean result, subprocesses and
  metadata requests have timeouts, and retries reconstruct from fresh state.
- Provider evidence applies to Hex only. For the WELL-100 candidate, the real
  fresh-home CLI run completed with exit 0 and no findings. The wrapper accepts
  that clean report only; an audit finding fails the job. No stable-release probe
  is needed because the exception path was removed.
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
