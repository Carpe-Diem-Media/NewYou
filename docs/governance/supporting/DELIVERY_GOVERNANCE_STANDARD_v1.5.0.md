# DELIVERY_GOVERNANCE_STANDARD_v1.5.0.md

- **Document status:** CURRENT / SUPPORTING DELIVERY GOVERNANCE STANDARD
- **Document version:** v1.5.0
- **Predecessor:** `docs/governance/supporting/DELIVERY_GOVERNANCE_STANDARD_v1.4.0.md`
- **SemVer transition:** `v1.4.0 → v1.5.0`. One-time historical closeout authority for WELL-125.
- **Date:** 2026-11-20
- **Authority class:** SUPPORTING DELIVERY GOVERNANCE AUTHORITY
- **Scope:** live delivery-state ownership, planning proportionality, agent/Symphony execution readiness, implementation-discovery escalation, current-authority routing and CI lane boundaries.
- **Upstream authority:** Product Law → Architecture Law → Domain Law → governing Roadmap. This standard may not amend those authorities.
- **Implementation boundary:** this standard governs how authorised work is represented and executed; it does not itself authorise a Feature Pack, release, production use or participant-facing capability.

## v1.3.0 Amendment Scope

This successor moves Foundation Full out of pull request routing and removes manual workflow dispatch. The scheduled nightly workflow is its only caller and targets 02:00 Africa/Johannesburg. Foundation Smoke and the required aggregate remain on every PR; unclassifiable or unreadable changes fail the routing job. GitHub may delay or drop scheduled runs, so the configured time is not a guaranteed runner start time. The historical scripts and audit remain in use by the nightly lane.

## v1.2.0 Amendment Scope

This successor records the separate current governance and delivery routers, frozen provenance boundary and CI lane behavior established by the semantic-root migration. It does not create Product, Architecture, Domain, Roadmap, Feature, runtime or release authority.

## 1. Purpose

NewYou separates durable governance from volatile delivery state.

GitHub is the durable constitutional record for Product, Decision, Architecture, Domain, governing Roadmap, Operating, Engineering, Frontend and semantic Feature/JIT/proof contracts where such contracts are required. Plane is the **authoritative execution** system beneath that durable law.

This split exists so ordinary delivery movement does not require governance-successor commits, manifest churn or historical Foundation Full certification.

If Plane and durable GitHub authority conflict, durable GitHub authority wins and the affected work stops until the conflict is reconciled. Plane never silently amends Product, Architecture, Domain, Roadmap, safety, security, privacy, entitlement or other governed law.

## 2. Plane live execution authority

Plane is authoritative for current delivery state, including:

- active delivery-roadmap projection;
- work-item state and priority;
- exact implementation tickets and acceptance criteria;
- blockers and dependencies;
- sequencing within already-governed outcomes;
- bugs, defects and discovered/deferred work;
- security, privacy, architecture and proof gaps discovered during delivery;
- implementation readiness;
- review, merge and post-merge reconciliation state.

The high-level roadmap represented in Plane is an execution projection of the governed GitHub Roadmap. Moving work inside an already-governed outcome is a Plane decision. Changing a Feature Pack outcome, durable dependency, Domain owner, Product rule or governing sequencing law requires the appropriate GitHub authority amendment first.

Plane should stay focused. Do not create every conceivable future implementation task merely for completeness. Keep the active delivery projection and the near-term decomposition necessary to make the next legitimate work executable.

## 3. Ready is the execution boundary

The only Symphony/local-agent executable Plane state is **`Ready`**.

Only `Ready` means the work has enough authority, acceptance criteria and dependency clearance for an implementation agent to begin. `Backlog`, `Planning`, `Blocked`, `In Progress`, `In Review`, `Changes Requested`, `Ready to Merge`, `Merging`, `Done` and other states are not permission for a fresh implementation agent to start new scope.

An implementing agent may continue work it already owns through the execution/review lifecycle, but it must not pull unrelated work that has not reached `Ready`.

Durable authority plus a dependency-cleared Plane `Ready` ticket is sufficient permission to implement the ticket's authorised scope. Runtime grants do not separately block ordinary implementation in non-production development. A real runtime Account, IdentityGrant, staff-role assignment or production capability grant is not an additional implementation prerequisite. Implementing or proving the real authorization/provisioning mechanism may include creating or validating real grants as the ticket's deliverable; those grants must not be treated as pre-existing entry prerequisites for starting that development. Only an explicit, narrowly scoped external real-world requirement that is intrinsically necessary even for the bounded development action may block implementation from starting. It must be justified by governing authority; a future production role or grant requirement alone is not an implementation prerequisite.

Development must still design and test runtime authorization, including permitted and denied paths, missing grants, wrong scopes, expiry, revocation, sensitive-role boundaries and audit behaviour. Isolated local/test/bounded-development environments may use deterministic synthetic Accounts, roles, grants and fixtures for that proof. They confer no production authority and development-only shortcuts must be impossible or fail closed in production/release contexts. This implementation permission creates no runtime role, production capability or release approval.

Symphony and other coding agents consume focused Plane tickets. They do not infer implementation scope from Open Work, Roadmap prose, chat summaries or derived status documents.

## 4. Planning proportionality

Before material planning or implementation, perform repository reconnaissance against current durable authority, the relevant semantic contracts, live Plane state and actual code/tests/migrations/dependencies.

Use the lightest process that safely resolves the work:

- **Narrow, settled work:** one focused Plane ticket is sufficient.
- **Major slice with material ambiguity:** use `/grilling` to pressure-test ownership, lifecycle, invariants, concurrency, failure/recovery, security/privacy/safety and proof obligations.
- Use `to-spec` only when grilling or reconnaissance proves that a durable implementation contract is genuinely missing.
- Use `to-tickets` only when the slice has independent testable/reviewable parts, sequencing dependencies or would otherwise be unsafe/unwieldy as one ticket.
- Do not re-grill, re-spec or re-ticket settled decisions merely because implementation has started.

The output of planning that affects execution belongs in Plane. Durable semantic law belongs in GitHub only when the authority hierarchy actually requires it.

## 5. Implementation-discovery classification

Every material implementation discovery is classified before expanding scope:

### `LOCKED`

Current authority already answers the question. Follow it. Do not reopen settled law without new contradictory evidence or changed scope.

### `JIT IMPLEMENTATION CHOICE`

Authority intentionally leaves the implementation detail open. Choose the simplest compliant option, verify current framework/package facts when material, test it, and record significant discovered work in Plane. Examples may include ordinary indexes, local naming, reversible implementation structure and API details that do not change governed semantics.

### `UPSTREAM GOVERNANCE CONTRADICTION`

Implementation conclusively exposes missing or conflicting Product, Architecture, Domain, Roadmap, ownership, lifecycle, security, privacy, safety, entitlement or another expensive-to-reverse governed semantic. STOP the affected work, record the blocker and evidence in Plane, identify the smallest correct upstream authority and amend that authority before continuing the affected path.

Implementation details do not become governance merely because they were learned during coding.

## 6. Open Work retirement

`docs/history/02_OPEN_WORK_v1.2.90.md` is the final **frozen legacy** Open Work snapshot.

It is preserved as historical evidence of the pre-WELL-66 planning model. It is not live execution authority after WELL-66 becomes current, and no successor is required for status-only changes.

Ready/In Progress/Blocked/Done movement, dependency edits, PR/review state, discovered work and implementation sequencing are Plane-only unless they reveal an `UPSTREAM GOVERNANCE CONTRADICTION`.

No agent may use stale Open Work status to override live Plane state or current durable law.

## 7. Derived and semantic working artifacts

Delivery Atlas, Feature Pack Skeleton, HARDEN contracts, JIT dossiers, proof contracts and similar working artifacts are not dashboards.

They change when their **semantic contract** changes. They do not receive a successor merely because a Plane ticket changed state, a dependency cleared, a PR merged or a reviewer updated an execution status.

Existing ticket/status prose in those artifacts is freeze-time or historical context unless a current semantic contract expressly makes it part of durable law. Live execution status comes from Plane.

## 8. Current routing and historical integrity

Current repository orientation and routing are defined by:

- `docs/README.md`, the documentation entrypoint;
- `docs/governance/CURRENT_GOVERNANCE_ROUTER.json`, for current durable Product, Architecture, Domain and Roadmap law and genuine supporting authority; and
- `docs/delivery/CURRENT_DELIVERY_ROUTER.json`, for current Feature, JIT, proof, execution and content-evidence contracts beneath governance.

The governance router's `architecture_references` provide deep Architecture and exact-source evidence; they are not additional default governing roots. The governance router does not contain delivery contracts, Plane state or historical snapshots. The delivery router does not contain governance or history routes. Neither router grants authority beyond its semantic class.

Plane remains authoritative for live execution state, including status, blockers, dependencies, sequencing and review readiness. `docs/history/02_OPEN_WORK_v1.2.90.md` is frozen legacy evidence, not live execution state. `docs/history/CURRENT_AUTHORITY_MANIFEST_v1.0.0.json` is the frozen pre-WELL-66 provenance baseline used by Foundation Full, not a current router.

Historical evidence remains valid evidence of what was true when it was recorded. It must not be rewritten merely to resemble current delivery state.

## 9. CI topology

### Foundation Smoke — required current safety net

Foundation Smoke runs on every PR and verifies both current routers, their route hashes and semantic boundaries, required current files, the documentation entrypoint, preserved historical files and merge-gate topology. Governance cannot route into delivery or history, and delivery cannot route into governance or history. It is part of the required `Foundation Integrity` merge gate.

### Application CI — required when engineering paths change

Application and engineering paths route to the repository's canonical engineering gates, including `mix check`. The slower `mix check.deep` lane runs only when the path classifier selects application source, migrations or dependency/toolchain changes; documentation-only delivery/development changes and test-only changes do not select it.

### Foundation Full — historical/provenance evidence

Foundation Full runs only through the scheduled Nightly hardening workflow against `main`. Its nominal schedule is 02:00 Africa/Johannesburg. It verifies the historical Python suite and frozen `docs/history/CURRENT_AUTHORITY_MANIFEST_v1.0.0.json` baseline. It has no pull request or manual-dispatch trigger. Its scripts remain available for the nightly workflow and local diagnosis.

Foundation Full is post-merge evidence. The required merge aggregate waits on routing, always-on Foundation Smoke and Application CI when selected; it never waits on Foundation Full. A later nightly regression is triaged against the recorded main SHA and related change.

Paths under `docs/governance/**`, `docs/history/**` and explicit Foundation Full/provenance machinery run Foundation Smoke without selecting Application CI by location alone. Unknown paths, empty ranges and unreadable ranges fail the route job; they do not silently skip CI or start Foundation Full. Ordinary delivery state remains in Plane. Current delivery contracts under `docs/delivery/**` run Smoke and applicable Application CI.

GitHub scheduled starts are best effort and may be delayed or dropped. The 02:00 SAST schedule is the configured target, not a guaranteed runner start time.

## 10. Review and integration gates

Every material PR remains subject to independent exact-head Master Gate review. A changed reviewed head invalidates prior certification until the new exact head is reviewed.

Before merge recommendation, verify the exact PR base/head, complete diff, governing authority, Plane ticket/acceptance criteria, ownership/lifecycle/concurrency/security/privacy implications, migrations/persistence semantics, relevant tests and required exact-head CI.

Merge alone does not complete work. After merge, independently verify the resulting-main SHA/tree, candidate integration/no drift and required resulting-main CI/proof before reconciling Plane to `Done` or opening dependent work.

No agent may self-authorise a merge merely because CI is green.

### 10.1 One-time historical closeout for WELL-125 / PR #244

WELL-162 authorizes Master Gate to decide the historical Plane closeout of WELL-125 using the retrospective proof below. The exception applies once, solely to the already merged [Carpe-Diem-Media/NewYou PR #244](https://github.com/Carpe-Diem-Media/NewYou/pull/244) targeting `main`. It grants no authority to merge a PR and creates no procedure for any other past or future closeout. The ordinary native candidate and result requirements apply in full to the WELL-162 amendment itself and all ordinary merges and closeouts.

**Historical record.** AC7 remains **FAILED**. On 17 November 2026, before PR #244 merged, `handoff.py finish --ticket WELL-125 --disposition-review 5937587697` exited 1 because OCR finding 1 lacked an independent disposition. The exact-head approval had an empty body. The entry audit stopped before `native-candidate`, and no contemporaneous execution of either `native-candidate` or `native-result` is evidenced. The subsequent independent Master Gate classified OCR session `bdf5f585-96dc-457b-b4cd-ed01cfaebeb0`, finding 1, as **NON-BLOCKING**. WELL-151 / PR #267 made OCR optional prospectively. The author reported private local verification and OCR receipts that the independent review did not inspect. The exception leaves those receipts unverified and makes no determination about the cause of earlier intermittent failures. Preserve the original evidence, timestamps, and GitHub review body.

Historical Plane evidence is in [WELL-125](https://app.plane.so/b6463529-12d8-44a7-9778-620b8fe112bc/browse/WELL-125). The entry audit is comment `3b6e98b2-adbc-4f7c-a76e-490623b39e41`, the independent disposition is `48b7fd17-d374-4ee7-a214-2dfc54d4c7e6`, and the owner's conditional authorization to pursue the amendment is `0a0e5554-a02e-450d-884d-15a0577dbe68`.

**Exact evidence required.**

| Evidence | Required value |
| --- | --- |
| Base | `4cefa3955a27a144cfb9730e9cedce08fd3ba4fa` |
| Approved head | `db9f6abb4471154ad20d193e3a088cd6876a1b21` |
| GitHub approval | [Review 5937587697](https://github.com/Carpe-Diem-Media/NewYou/pull/244#pullrequestreview-5937587697), authenticated `JCSchoeman96`, `APPROVED` on the exact head, empty body |
| Hosted CI | [Foundation Integrity run 44073316162](https://github.com/Carpe-Diem-Media/NewYou/actions/runs/44073316162), attempt 1, successful `pull_request` run for the approved head |
| Tested candidate | `c5173a5c36a7a3f8185792624357c06ab5b9c666` |
| Actual merge | `87a9c6306cc08bea5accb5518692842c115a463b` |
| Ordered parents of candidate and actual merge | Base first, approved head second, exactly as listed above |
| Tree of candidate and actual merge | `c73386cd2e5ebe20dd9384af24a0c6c78ba4e6ed` |

**Independent retrospective procedure.** Master Gate performs these checks read-only against live GitHub, Git and Plane after the amendment's own closeout proof is available.

1. Confirm live `main` contains this routed amendment. Verify its PR had ordinary authenticated independent exact-head approval, required exact-candidate CI and a protected merge. Require successful `native-candidate` and `native-result` for that PR and verification of its resulting-main SHA, ordered parents and tested tree under the ordinary procedure.
2. Read the historical PR and review through authenticated GitHub. Confirm the repository, PR number, target branch, merged status, base, head, merge SHA, review ID, authenticated reviewer, status, approved commit, empty body and approval before merge.
3. Read the specified hosted run and attempt's jobs, logs and required check metadata. Require success for routing, Foundation Smoke, routed Application `mix check` with 964 passing ExUnit tests, routed Hex audit, and the GitHub Actions Foundation Integrity aggregate bound to that exact head and run. Verify that routing left `mix check.deep` unselected. Verify the checkout SHA in each required job that checks out source against the tested candidate above.
4. Retrieve the tested candidate and actual GitHub merge commit. Verify both ordered parent lists and both tree IDs against the required values. Verify the actual merge is on the first-parent history of the freshly resolved live `main` and record that live main SHA. The run is PR-tested tree evidence.
5. Verify live WELL-125 acceptance, dependency clearance and the historical Plane evidence. Record the outcome as **retrospective substitute proof under the one-time WELL-125 exception**. It does not establish successful execution of either historical native command or change AC7 to PASS.

Any missing, unreadable or mismatched required input fails the exception. A different PR, unmerged PR, changed commit, missing or invalid review, failed required CI, or different parent order or tree cannot qualify. Keep WELL-125 Blocked and record the exact unmet condition in Plane if any guard fails. Only after all checks succeed may independent Master Gate record the exact proof and historical deviation in WELL-125 and reconcile that item to Done. The transition consumes this one-time authorization.

## 11. Transition and non-goals

WELL-66 is a one-time operating transition. It does not redesign Product Law, Architecture Law, Domain Law, Feature Pack outcomes or participant-facing behaviour.

The transition deliberately removes status bookkeeping from durable governance while retaining strong upstream stop conditions and exact integration proof.

After WELL-66 resulting-main verification:

- GitHub remains durable law;
- Plane is authoritative execution state;
- only `Ready` is agent/Symphony executable;
- Open Work v1.2.90 remains frozen legacy evidence;
- semantic contracts change only for semantic reasons; and
- upstream governance changes only when development supplies conclusive evidence that upstream law is missing, contradictory or materially wrong.


## v1.4.0 amendment scope

For eligible development, ChatGPT Master Gate completes the technical review and publishes one authenticated JCSchoeman96 GitHub APPROVED review for the exact final head. That review is both technical approval and standing merge authorization. No second founder comment or base-SHA line is required. The implementing agent must not use founder credentials.

Before merge, verify the current required CI and live branch protection. Run the read-only `tools.ci_attestation native-candidate` check from trusted integrated `main`, perform the normal GitHub merge bound to the reviewed head, then run `tools.ci_attestation native-result` with the tested candidate. These checks create no persisted evidence files or merge intent. If the merge result is uncertain, inspect the PR and `main` before taking further action. Reconcile Plane to Done only after the resulting commit, ordered parents and tested tree match.

Require stronger approval only when a governing or external obligation requires it. Paths and edits to CI, agent instructions, approval tooling or governance do not by themselves require a stricter route. PR #224 remains under current-main requirements and needs fresh complete review, successful CI and explicit owner authorization for its exact merge transition. Collection-only comment 6821263762 is not authorization; do not self-approve or self-merge. Any settings change after its authorized integration needs separate authorization and independent live verification.

This amendment changes no Product, Architecture, Domain or participant-facing authority.
