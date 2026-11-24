# HISTORICAL DRAFTING REFERENCE — FP-002 P1 / WELL-189

- **Ticket:** [WELL-189](https://app.plane.so/symphony-development/browse/WELL-189) — synthetic Plan payment to held right (P1-01..07).
- **Parent:** [WELL-22](https://app.plane.so/symphony-development/browse/WELL-22).
- **State:** existing provisional Planning; no execution authority until independent dependency-cleared Ready.
- **Risk:** HIGH — `financial`, `entitlement`.
- **Direct blocking relations:** none; no WELL-176 edge. FP-001 prerequisite via WELL-21 is satisfied. Exact plan approval and separate acceptance of existing `/to-tickets` decomposition precede Ready.
**Current snapshot:** NewYou `main` `1bfb351e295d8e03704e6b057b334f84429581aa`, checked 2026-11-23. Recheck before publication.

## Governing sources and approvals

- [Live governance router](../../../../governance/CURRENT_GOVERNANCE_ROUTER.json), [delivery router](../../../CURRENT_DELIVERY_ROUTER.json), [AGENTS.md](../../../../../AGENTS.md).
- [Product §21R.1–2](../../../../governance/product/00_PLATFORM_v1.20.0.md), [DEC-299, DEC-300, DEC-303, DEC-314](../../../../governance/product/01_DECISIONS_v1.20.0.md), [Architecture §§4.2–4.3, 7–8](../../../../governance/architecture/03_ARCHITECTURE_v1.1.1.md), [Domain Map §§6.1, 6.10–6.11](../../../../governance/domain/04_DOMAIN_MAP_v1.2.0.md), [Roadmap FP-002](../../../../governance/roadmap/05_ROADMAP_v1.2.5.md), [Engineering Standards v1.1.0](../../../../governance/supporting/ENGINEERING_STANDARDS_v1.1.0.md).
- [Certified Phase 7B v0.2.0](../../../proof/fp-002/FP-002_PHASE_7B_RECONCILIATION_v0.2.0.md), [certified Phase 7C v0.2.0](../../../feature-contracts/fp-002/FP-002_FINAL_FEATURE_PACK_CONTRACT_v0.2.0.md).
- **Classification:** `NEW_TRACER_BULLET` selected in WELL-22 comment `eacdaba6-7b02-420c-869c-d1ec25a3ab73`.
- **P1 exact owner-approved source:** [P1 design candidate v0.1.0](../../../proof/fp-002/FP-002_TRACER_BULLET_DESIGN_CANDIDATE_v0.1.0.md), Git blob `9edee4c2b4a5206474a3499897ad615a2028f9e7`, owner receipt `aa879dbc-ba02-4026-ae23-d43731691652` in WELL-22.
- **Planning:** [implementation plan candidate v0.2.0](../FP-002_IMPLEMENTATION_AND_TICKET_PLAN_CANDIDATE_v0.2.0.md) and [seven supporting review passes](README.md) are **not yet approved**. Separate exact plan and `/to-tickets` approval remain required. Reconcile the existing card with the final approved integrated plan Git blob/SHA and approval receipts before Ready; do not cite a pending PR as an accepted plan.

## Objective

Using existing NewYou real Ash owner interfaces and PostgreSQL, one **synthetic verified Account** (payer = recipient) accepts a single standalone Plan price version at **39,900 ZAR minor units**, stores one known pending attempt, qualifies one **TEST-only** synthetic observation through real Commerce checks, persists **one authoritative Commerce payment plus its mandatory durable consequence** and subsequently applies **one** source/component-specific Entitlements right in `held_unconsumed`. Right is readable only by authorised recipient after the Entitlements commit. There is **no** Plan delivery, consumption or access to delivered Plan content. Test proof produces **zero Paystack/provider stage results**.

## Acceptance criteria — all must pass

- **P1-01 Acceptance + evidence:** same accepted input replays one purchase; changed actor/payer/recipient/attempt/environment/integration/amount/currency binding fails. Pending, unqualified, forged and misbound observations produce **zero** payment/right; qualified internally originated TEST evidence follows genuine Commerce checks.
- **P1-02 Independent PostgreSQL race:** two genuinely independent DB transactions applying equivalent qualified evidence converge to **one payment, one durable consequence, one held Plan right**. Deny direct unauthorised grant, foreign recipient right reads, all Plan delivery/consumption/content access. Durable source IDs remain unchanged on replay.
- **P1-03 Before Commerce commit:** rollback yields **zero verified payment, zero committed grant consequence and zero right** (the previously accepted pending purchase may persist); no phantom access.
- **P1-04 After Commerce commit / before Entitlements apply:** payment + one open durable consequence persist. Fresh execution independently rediscovers it and Entitlements grants exactly one held right; access denied until grant commit.
- **P1-05 After Entitlements commit / before acknowledgement:** fresh retry recognises the existing source-specific held right and completes original consequence without duplicate payment, right, delivery or consumption.
- **P1-06 Production isolation:** TEST-only synthetic source is absent in production compilation and unreachable via runtime switches, browser/provider inputs, headers or public endpoints. Ordinary forged paths fail closed.
- **P1-07 Identity registration/reconciliation:** register both owner reviews in the same change; Apply the full exact human-approved P1-07, including authorized empty scope preserving the canonical Account, one active PMR, losing-PMR retirement and Communications/Audit provenance; preserve purchase/right/payer provenance in any supported uncontested history; deny unsupported nonempty scope, mismatched pair, missing/unknown/conflicting owner and independently committed stale review without retirement or financial/right effects; fresh BEAM applied replay preserves provenance and conflict replay stays denied. Retain `UnreviewedProofDomain` regression. No Identity write to Commerce payment or Entitlements right truth.

## Technology selection before code

Use [Pass 7 dependency and scalability selection](pass_07_technology_dependency_scalability_decisions.md). P1 has **no mandated new package**: retain pinned Ash/AshPostgres, AshStateMachine, AshOban/Oban and optional Reactor 1.0.1. Do not add AshPhoenix/AshAdmin/Signals/Temporal/Storage as a substitute for durable financial authority; AshPhoenix is separately evaluated at the first applicable UI slice. Reconfirm `mix.lock` at dispatch.

## Required code and test reconnaissance (not a frozen module design)

Inspect [`lib/new_you/identity/reconciliation.ex#L541`](../../../../../lib/new_you/identity/reconciliation.ex#L541), [`test/new_you/identity/reconciliation_test.exs#L581`](../../../../../test/new_you/identity/reconciliation_test.exs#L581), [`lib/new_you/identity/registration_operation.ex`](../../../../../lib/new_you/identity/registration_operation.ex), [`lib/new_you/audit/evidence_obligation.ex`](../../../../../lib/new_you/audit/evidence_obligation.ex), [`lib/new_you/communications/message_intent.ex`](../../../../../lib/new_you/communications/message_intent.ex), [`config/config.exs`](../../../../../config/config.exs), [`mix.exs`](../../../../../mix.exs) and current test/DB/migration conventions. **Exact new Resources, actions, constraints, indexes, workers and transaction mechanism remain JIT choices.**

## Explicit exclusions

No Paystack network/SDK/keys/test provider operations, hosted checkout, public callback/webhook, Assessment, bundles or R99 allocation, payment refunds/disputes, merchant settlement, cross-object scanner, Plan fulfilment or content, runtime release, paid pilot, or whole FP-002 Phase 8 certification. Do not turn the synthetic proof into general Commerce/Entitlements scope.

## Definition of done / evidence

- All P1-01..07 with test IDs and durable per-cut counts; real independent PostgreSQL transaction overlap and fresh-execution/restart receipts; verified current actor/recipient denials; held-not-delivered assertion.
- New Domain review and Identity regression suite passing; proper owner interfaces and database-enforced uniqueness; migration/adjacent-version safety proof; TEST producer production compile exclusion.
- HIGH proof menu with applicability/N/A rationale, privacy/security/redaction and unresolved work observability; no new infrastructure without authority.
- Source-linked capability record in `docs/development/knowledge/` and clear consequential code contracts as required by current repository standard.
- Focused tests, `mise exec -- devcore-project run test -- mix check`, applicable deep verification, exact-head hosted CI and independent Master Gate. No merge without explicit authorization; resulting-main SHA/tree/CI must be checked before Done.

## Readiness checks before dispatch

Plan and `/to-tickets` exact approvals confirmed; P1 proof source-status/routing treatment reconciled if required; child ticket exists and is independently `Ready`; live dependencies clear; current `main`, AC and pinned package APIs reverified; no newly discovered upstream contradiction. Only then invoke `/ticket-implement` and transition Ready → In Progress.

**Historical drafting reference — do not publish a duplicate or set Ready until independent readiness assessment.**
