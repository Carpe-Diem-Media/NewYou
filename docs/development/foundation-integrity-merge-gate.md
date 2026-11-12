# Foundation Integrity merge gate

This is the current operational CI and merge contract. The workflows define the executable lanes; this document explains their boundaries and the independent review procedure.

## Required gate

The public repository protects `main` with active ruleset `24191860`, which requires a pull request and a successful **Foundation Integrity** status check. Eligible development uses the solo-founder gate below. Strict work uses the independent review and resulting-main procedure. Foundation Integrity comes from hosted pull request CI. Every pull request runs Foundation Smoke. Application CI and the Hex security audit run when changed paths select them. Foundation Full runs only in the scheduled nightly hardening workflow and is not part of PR checks or the required aggregate. The application cache warmer is separate. It may save dependency caches from trusted `main` pushes; PR runs may restore those caches but do not save them. Cache entries contain no test results or build output.

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

## Solo-founder development merge

For eligible non-production founder-development changes, JC-Agents implements and opens the PR. ChatGPT independently reviews the complete exact-head diff, source, tests, current authority, live Plane and CI. The JCSchoeman96 GitHub connector publishes a genuine APPROVED review. That review supplies standing owner merge delegation for this scope, without another founder comment or manual attestation files. It authenticates the founder account, not a separate physical person. Implementers must never use founder credentials to approve their own work.

The review includes one plain-text line, `Founder-development base: <40-character base SHA>`, after the reviewer establishes that no stronger approval applies. GitHub already binds the review to its head commit. The line binds eligible scope and the reviewed base; it is part of the technical review, not another approval ceremony. Changed head or base requires a fresh review. Regulated, clinical, legal, production-security, privileged and release changes retain their actual higher-risk independent-approval rules. Changes to approval tooling, agent instructions, CI workflows and governing authority always use the strict route. Ambiguity refuses the routine route.

Run `python3 -m tools.founder_gate check --pr NUMBER` from a clean, trusted checkout of integrated main using JC-Agents credentials. The guard reads live GitHub account/membership, PR, reviews, resolved threads, effective protected-main rules and the latest Foundation Integrity run. It reuses existing exact candidate/job-checkout verification. It requires one native approval, stale-review dismissal, last-push approval, resolved threads, strict required CI, regular merge only and no bypass. No App, new workflow, external approval service or candidate-controlled approval file is required. A PR cannot certify the guard that it changes.

After all checks pass, `python3 -m tools.founder_gate merge --pr NUMBER` recollects live facts, saves one automatic intent using the existing private locked custody helper, then calls the regular merge API bound to the exact head. It never uses bypass or auto-merge. Immediately afterward it verifies resulting main SHA, ordered parents and tree against the tested candidate. The automatic intent is recovery data, not an approval dossier. The command emits concise machine-readable status; no manually assembled manual attestation files is required for this route.

Lifecycle: AWAITING_REVIEW or AWAITING_CI remains non-authorizing. Valid live guards yield READY_TO_MERGE. Durable intent enters MERGING before the network request. Exact resulting-main proof yields VERIFIED; only then may satisfied Plane work move to Done. Any changed fact blocks before merge. An interrupted request or failed reconciliation retains its intent and refuses a second merge. `python3 -m tools.founder_gate reconcile --pr NUMBER` retries read-only reconciliation using the originally trusted base checkout. If GitHub still reports unmerged or main has drifted, preserve the record and obtain a narrow recovery decision; do not reset it or repeat the merge automatically.

GitHub settings and implementation-account permissions require separate owner approval before mutation. The routine guard remains fail-closed until enforcement is live-verified. Do not add a dedicated status producer or CODEOWNERS ceremony merely for this route. The agent needs Write/Member access rather than administrative bypass. See the owner-only settings proposal for exact differences from current rules.

PR #224 establishes these rules and cannot use them to approve or merge itself. Current main governance governs its final combined head. Fresh ChatGPT Master Gate review, fresh CI and an expressly authorized current-law transition remain required. Earlier PR #223 or #224 approvals do not carry to a changed head.

## Strict independent review and resulting-main reconciliation

The independent reviewer examines the complete diff at the exact PR head,
confirms the current base and checks the hosted Foundation Integrity run,
including the exact merge candidate checked out by each required job. Capture
evidence while the PR is open and after all required checks succeed. The
collector reads GitHub's PR, repository, ruleset, run, check-run, job,
checkout-log and Git commit APIs. It binds the reviewer's exact head and
attributable review record to hosted CI evidence. The collector does not
perform the review or calculate the independent full-diff digest.

Use a trusted checkout containing the reviewed attestation tool and a `gh`
session authorized to read the repository and Actions logs. The trusted
operator materializes `review.json` from the independent review:

```json
{"reviewed_head":"<40-character head SHA>","reviewer":"<independent reviewer>","review_reference":"<durable review reference>","diff_sha256":"<64-character SHA-256>"}
```

Independently verify the review reference, reviewer, complete diff and digest.
Keep the record in trusted custody with collector output, process exit status,
stderr and SHA-256 digests. Do not commit these artifacts or use a file from an
untrusted PR checkout. The PR Actions API `head_sha` identifies the PR head,
not the merge candidate. The collector must verify the exact candidate from
checkout logs for every executed required job, including its parents and tree,
and confirm the successful `Foundation Integrity` check identity. Foundation
Full is non-blocking; investigate a relevant failure in its scheduled lane.

Before merge, run from the trusted checkout:

```bash
python3 -m tools.ci_attestation before --trust-mode public-protected --review-record review.json --pr PR_NUMBER --reviewed-head REVIEWED_HEAD_SHA --run RUN_ID > before.json
```

Any changed head, base, candidate, run attempt, checkout or review invalidates
the corresponding evidence. Recapture CI evidence and repeat review as needed.
Immediately before a regular merge, recheck the PR, active ruleset and current
`main`. Do not use a bypass or merge when a required check is missing or
unsuccessful. Separate owner authorization is required before executing
`gh pr merge PR_NUMBER --merge --match-head-commit REVIEWED_HEAD_SHA`. Do not use auto-merge.

After merge, immediately reconcile resulting `main` using the trusted evidence:

```bash
python3 -m tools.ci_attestation after --trust-mode public-protected --review-record review.json --pr PR_NUMBER --reviewed-head REVIEWED_HEAD_SHA --run RUN_ID --before before.json > after.json
```

Preserve both outputs, exit statuses, stderr and digests in trusted custody.
Do not commit them.

The collector re-reads GitHub evidence and verifies that resulting `main` is
the merge commit, has the reviewed base and head as parents, and has the tree
tested by hosted PR CI. It rejects squash and rebase merges, unknown methods,
concurrent `main` changes, missing logs and mismatches. This post-merge step is
read-only. It does not repeat tests or create a check run on `main`. If
reconciliation fails, stop completion and dependent work. Resolve the evidence
or merge discrepancy through an authorized process, then obtain fresh
independent review and hosted CI for any new candidate. Passing tests alone
does not repair a merge that lacked required review or checks.

The saved evidence is not itself a signature or review approval. The
independent reviewer must preserve and verify its provenance. Foundation Full
remains in the scheduled nightly lane; it is not a post-merge duplicate test.

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
