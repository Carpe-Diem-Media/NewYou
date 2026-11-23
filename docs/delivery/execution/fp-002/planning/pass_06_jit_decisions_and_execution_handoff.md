# FP-002 planning enhancement — Pass 6 of 7
## JIT engineering decision boundary, P1 handoff and ticket-publication gate

**Status:** Draft engineering handoff, not a finished implementation design or a Ready ticket. **Verified basis:** `main` `1bfb351e295d8e03704e6b057b334f84429581aa`, 2026-11-23; [plan v0.1.0 blob `11bd7a2...`](https://github.com/Carpe-Diem-Media/NewYou/blob/main/docs/delivery/execution/fp-002/FP-002_IMPLEMENTATION_AND_TICKET_PLAN_CANDIDATE_v0.1.0.md), [human-approved P1 design](https://github.com/Carpe-Diem-Media/NewYou/blob/main/docs/delivery/proof/fp-002/FP-002_TRACER_BULLET_DESIGN_CANDIDATE_v0.1.0.md), [AGENTS.md](https://github.com/Carpe-Diem-Media/NewYou/blob/main/AGENTS.md).

### 6.1 Three-way classification of the remaining P1 decisions

| Question / choice | Classification | Reason / required action |
|---|---|---|
| Who owns accepted purchase, attempt, payment and mandatory consequence? | **LOCKED** | Commerce only, [Domain §6.10](https://github.com/Carpe-Diem-Media/NewYou/blob/main/docs/governance/domain/04_DOMAIN_MAP_v1.2.0.md). |
| Who creates/owns purchased Plan right and current read authorisation? | **LOCKED** | Entitlements only, §6.11. Cross-Domain calls are through owning Ash interfaces. |
| Does synthetic verified evidence from a fixture mean provider evidence is verified? | **LOCKED: NO** | Qualified TEST-only source, bounded P1 sub-proof; zero Paystack evidence stage promotion. |
| Which source/amount/value must P1 exercise? | **LOCKED** | One R399 / 39,900-minor-unit ZAR Plan, one known attempt, synthetic verified payer=recipient. |
| When does payment produce grant consequence? | **LOCKED** | Payment and mandatory durable consequence atomically; separately owned right later, recoverable across restart. |
| Is `held_unconsumed` content delivery or consumption? | **LOCKED: NO** | No Plan generation, delivery or content access in P1. |
| What must race/failed/replayed cases prove? | **LOCKED** | Seven P1 cases, independent PostgreSQL transactions, commit cuts, source-specific one-right, forbidden reads and production fixture absence. |
| What if Commerce/Entitlements register as new Ash Domains? | **LOCKED** | Identity `owner_reviews/1` exact guard and owning review must be updated together; unknown/stale/conflicting review must fail closed. |
| Which specific Ash Resource/action/code-interface names and module layout? | **JIT IMPLEMENTATION CHOICE** | Follow repository current Ash conventions. Choose simplest owner-scoped public/private boundaries with clear typed contracts; implement/test rather than amend governance. |
| Which DB table names, columns, unique keys, check constraints, transaction composition or locking? | **JIT IMPLEMENTATION CHOICE with hard proof guards** | Must enforce source+component idempotency, atomic payment/consequence and real concurrent writers. Select DB mechanism justified by the invariant and current AshPostgres APIs; migrations must be safe. |
| AshStateMachine extension vs normal Ash updates/other compliant state representation? | **JIT IMPLEMENTATION CHOICE** | Use existing dependency and minimal lifecycle semantics; no forced package architecture. |
| How is persisted grant work redetected/claimed/scheduled across restart? | **JIT IMPLEMENTATION CHOICE** | Must be durable and recoverable even when executor job is lost/exhausted; current AshOban/Oban patterns are reference implementations, not mandates for exact queue or cron. |
| What are internal result/error structs or negative test helper names? | **JIT IMPLEMENTATION CHOICE** | Consistent, fail-closed, non-enumerating, source-safe and testable; no invented durable Product law. |
| Is a new governance decision necessary to choose the table index or action name? | **NO** | Missing internal representation is never itself an upstream contradiction. |

**Governance STOP requires all three proofs:** (1) exact current governing statements conflict or omit a **material durable semantic**, (2) why no reasonable compliant JIT implementation can satisfy them, and (3) what irreversible consequential business decision would otherwise be invented/changed. Without all three, solve in code/tests and continue. This review found **no** such current contradiction for P1.

### 6.2 Candidate implementation sequence — intentionally mechanism-agnostic

1. **Read readiness first:** current GitHub routers, plan approval, exact P1 human receipt, live Plane `Ready`, dependencies, actual code/lockfile, ticket `.agents/skills/ticket-implement/SKILL.md`, installed current Ash usage skill. Do not use `Backlog` WELL-22 as a Ready work item.
2. **Prove existing integration constraints:** verify normal `mix check` and source baseline, check Identity actor and reconciliation interface, one PostgreSQL Repo and real SQL Sandbox setup, existing durable obligations/constraints. Record proof baseline, don't automatically refactor unrelated code.
3. **Test the owner boundaries first:** P1-01 rejection/replay; no right before grant; foreign read denied; TEST-only producer cannot be invoked from production. Write failing focused tests for exact observable behaviour.
4. **Implement minimal Commerce-owned accepted obligation, pending attempt, qualified evidence application and atomic payment + durable consequence.** Keep all business writes within Commerce Ash owning actions; no cross-Domain direct SQL.
5. **Implement minimum Entitlements source/component grant and recipient read.** Recheck committed Commerce consequence, current actor/recipient and source; persist held state once, deny content/delivery/consumption inference.
6. **Constrain and prove concurrency.** Select DB-level uniqueness/serialization to defeat independent transactions, test the race; use real transaction overlap, not a single sandbox transaction replayed twice.
7. **Prove three crash cuts:** no committed payment/consequence pre-commit; one open obligation after Commerce commit before grant; already granted right after Entitlements commit before ack, with durable restart/recovery. Expose unresolved work to operations safely.
8. **Register new Domains with their Identity owner reviews in same change.** Keep unknown/stale/concurrent mismatches fail closed. Run positive, negative, replay and fresh BEAM Identity tests, including existing unreviewed-Domain regression.
9. **Schema and release safety:** migration validation, mixed code/database version strategy as required, safe secret/log handling, no general fixture escape, no provider/outbound operation, no customer/production activation.
10. **Verification and PR:** focused tests, repository `mise exec -- devcore-project run test -- mix check`, applicable deep checks, capability map + exact proof receipts, open a focused PR; wait for independent exact-head Master Gate, required CI and separate merge authorization.

These are **engineering goals**, not instructions to implement before a published, dependency-cleared Ready P1 ticket. New code should use clear module/function names, comments explaining consequential guards, and meaningful typespecs/contracts at cross-Domain interfaces; avoid comments that merely restate code.

### 6.3 JIT decision record template for the implementation agent

Each **material** choice that survives review should be recorded concisely in the PR/code/capability map, not as a new governance law:

| Field | Required record |
|---|---|
| Consequential boundary | Invariant/owner/guard/transition from Pass 3 and governing citation |
| Alternatives considered | A small set of actual supported Ash/PostgreSQL options, not theoretical infrastructure |
| Chosen JIT mechanism | Module/action/migration/constraint/transaction/recovery approach after checking current code |
| Why compliant | Explains how owner authority, atomicity, idempotency, concurrency, retries and recovery are enforced |
| Tests and proof | Names exact P1 case(s), DB counts and failure cuts, negative tests and migration safety |
| Knowledge and link | PR SHA, relevant Plane ticket, `docs/development/knowledge/<capability_id>.json`, code/test locators |

For example, **which PostgreSQL uniqueness fence to use** is JIT; **the requirement that the same source/component cannot produce two grants in two independent transactions** is LOCKED. The reviewer verifies the mechanism against the invariant, not against an imagined pre-approved schema.

### 6.4 Remaining planning/source-status corrections (narrow, no scope expansion)

| Finding | Verified status | Focused treatment before publishing executable ticket |
|---|---|---|
| Base plan's first approval gates still say approve 7B/7C and classification | [7B and 7C](https://github.com/Carpe-Diem-Media/NewYou/blob/main/docs/delivery/CURRENT_DELIVERY_ROUTER.json) are **CERTIFIED/CURRENT**; [WELL-22](https://app.plane.so/symphony-development/browse/WELL-22) has selected NEW_TRACER_BULLET and exact P1 owner approval | Reword next plan revision's status ledger to **completed** decisions; do not repeat approvals or restart `/grilling`/`to-spec`. Plan and `/to-tickets` **still pending**. |
| P1 proof design file says candidate | Owner approved exact bytes (WELL-22 comment `aa879dbc-ba02-4026-ae23-d43731691652`); candidate wording remains on GitHub | Resolve whether focused routing/status promotion is needed for executable proof; preserve the approved design semantics and approval byte receipt. |
| FP-002 7A skeleton still has candidate status | 7B/7C certified with 7A as recorded preparation/provenance input | Reconcile source-status hygiene only as required by actual workflow; do not claim candidate 7A is certified. |
| Provider evidence blocked | [WELL-176](https://app.plane.so/symphony-development/browse/WELL-176) is **Blocked** at current Plane state and latest Master Gate says provider execution STOP; OQ-004 remains open | No WELL-176 dependency on **TEST-only** P1; E1/E2 provider work requires stage-specific receipts and scoped operation approval. |
| Performance/observability currently broad in plan | 7C/Roadmap require callback bursts, bounded latency/backlog under interruption at **FP exit** | Assign costed, quantitative, stage-appropriate evidence to E1a/E1b/E1c and E2 tickets as they approach Ready; avoid inventing P1-only SLA or global load-test mandate. |

### 6.5 Ticket-publication decision — one near-term P1 child, not six tickets

The **six passes are review lenses**, not six implementation work units. The existing ten-slice graph P1, E1a–c, E2a–c and S1–S3 remains appropriate. One near-term P1 ticket is cohesive because acceptance, evidence qualification, Commerce consequence, Entitlements grant and Identity registration must prove a single architectural crossing together.

**Required order before creating P1 in Plane:** (A) independent approval of exact expanded planning artifact; (B) separate final `/to-tickets` decomposition/publication approval; (C) if required, P1 design source-status resolution; (D) create one child of WELL-22 with exact P1-01..07 acceptance and references, no WELL-176 direct blocker; (E) independent Ready assessment; (F) only then `/ticket-implement`. S1 conditional human approval is already recorded but S1 stays blocked on independently certified P1 and its own scope/Ready.

**Suggested P1 ticket title:** `FP-002 P1 — Prove synthetic Plan payment → one held Entitlements right (P1-01..07)`.

**Minimum ticket description fields:** approved exact plan/file SHA and P1 owner receipt; scope and exclusions (Pass 2); lock/Domain/lifecycle sources (Passes 1/3); verified code hotspots (Pass 4); the **full seven-case matrix** (Pass 5) or precise reference; risk HIGH (`financial`, `entitlement`); production fixture exclusion; migration/recovery/Identity gates; explicit definition of done and exact-head CI. State should remain non-executable until own Ready gate. A draft ticket description is supplied separately; **no Plane ticket is created by these passes**.

### 6.6 Handoff decisions for later slices (do not publish now)

- **E1a → E1b:** provider-dispatch ambiguity and a **known pending reference recovery** with absent browser/webhook must be independently proven, even when E1c doesn't exist.
- **E1c after E2c:** retained only for the chosen mixed payment/refund/dispute cross-object pagination claim and full FP exit, **not** a blanket dependency on E1b.
- **E2a:** purely synthetic Commerce correction/source-right convergence may follow P1 without a provider dependency; **E2b/E2c** require their relevant Paystack stage entry.
- **S1:** owner-approved conditional bounded synthetic continuation only after certified P1 + exact S1 scope and own Ready; genuine bundle activation also needs exact component allocation/disclosure approval.
- **S2/S3:** browser and Finance scopes require separately eligible content/roles and provider/correction proofs; paid release is independently gated.

**Pass-6 disposition:** Ready to submit the six-draft package for focused plan and `/to-tickets` approval. **Not yet** authority to publish, mark Ready, implement, call Paystack or merge. Planning is now substantially more actionable without creating a speculative code specification.