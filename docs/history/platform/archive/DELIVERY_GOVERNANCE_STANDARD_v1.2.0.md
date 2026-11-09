# DELIVERY_GOVERNANCE_STANDARD_v1.2.0.md

- **Document status:** CURRENT / SUPPORTING DELIVERY GOVERNANCE STANDARD
- **Document version:** v1.2.0
- **Predecessor:** `docs/history/platform/archive/DELIVERY_GOVERNANCE_STANDARD_v1.1.0.md`
- **SemVer transition:** `v1.1.0 → v1.2.0` — separate governance and delivery routing and align CI lane descriptions with semantic roots.
- **Date:** 2026-11-01
- **Authority class:** SUPPORTING DELIVERY GOVERNANCE AUTHORITY
- **Scope:** live delivery-state ownership, planning proportionality, agent/Symphony execution readiness, implementation-discovery escalation, current-authority routing and CI lane boundaries.
- **Upstream authority:** Product Law → Architecture Law → Domain Law → governing Roadmap. This standard may not amend those authorities.
- **Implementation boundary:** this standard governs how authorised work is represented and executed; it does not itself authorise a Feature Pack, release, production use or participant-facing capability.

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

Foundation Full runs for changes to `docs/governance/**`, `docs/history/**`, its own provenance machinery and unknown paths that cannot safely be classified. It verifies the historical Python suite and frozen `docs/history/CURRENT_AUTHORITY_MANIFEST_v1.0.0.json` baseline. It is also available for nightly/manual exact-SHA certification.

Foundation Full is separate, non-blocking evidence. The required merge aggregate waits on routing, always-on Foundation Smoke and Application CI when selected; it does not wait for Foundation Full unless a specific governing contract requires that certification for the change.

Ordinary delivery state remains in Plane. Current delivery contracts under `docs/delivery/**` run Smoke and applicable Application CI without selecting Foundation Full solely because of their location.

## 10. Review and integration gates

Every material PR remains subject to independent exact-head Master Gate review. A changed reviewed head invalidates prior certification until the new exact head is reviewed.

Before merge recommendation, verify the exact PR base/head, complete diff, governing authority, Plane ticket/acceptance criteria, ownership/lifecycle/concurrency/security/privacy implications, migrations/persistence semantics, relevant tests and required exact-head CI.

Merge alone does not complete work. After merge, independently verify the resulting-main SHA/tree, candidate integration/no drift and required resulting-main CI/proof before reconciling Plane to `Done` or opening dependent work.

No agent may self-authorise a merge merely because CI is green.

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
