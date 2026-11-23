# FP-002 focused implementation and ticket publication plan

- **Document version:** v0.2.0
- **Status:** REVIEW CANDIDATE — consolidates the existing ten-slice planning graph and seven source-linked engineering reviews. No implementation, exact-plan approval, `/to-tickets` approval, ticket Ready, provider execution or merge authority.
- **Predecessor:** [v0.1.0 implementation/ticket plan](FP-002_IMPLEMENTATION_AND_TICKET_PLAN_CANDIDATE_v0.1.0.md), Git blob `11bd7a2febfdc6274f094bd438fa5879571b3263`. The successor preserves its scoped ten-slice proposal and corrects obsolete gate ordering.
- **Source baseline:** NewYou `main` `1bfb351e295d8e03704e6b057b334f84429581aa`, verified 2026-11-23. Revalidate before review/publication.
- **Authoring receipt:** [WELL-22](https://app.plane.so/symphony-development/browse/WELL-22) comment `226b2eec-b0af-49e4-b846-d6d6eea429f8`.

## Approval and publication gates — current reconciled ledger

The earlier v0.1.0 plan still described the approvals for Phase 7B/7C, proof classification and exact P1 design as future tasks. **They have since been resolved**, and must not be repeated:

1. **COMPLETE / CURRENT:** FP-002 Phase 7B and Phase 7C v0.2.0 are certified on the live delivery router. The Roadmap, Domain owners and Product/Decision authority remain unchanged.
2. **SELECTED:** WELL-22 receipt `eacdaba6-7b02-420c-869c-d1ec25a3ab73` chose `NEW_TRACER_BULLET`.
3. **HUMAN-APPROVED EXACT SOURCE:** P1 v0.1.0 proof design P1-01..07, Git blob `9edee4c2b4a5206474a3499897ad615a2028f9e7`, WELL-22 receipt `aa879dbc-ba02-4026-ae23-d43731691652`. The approved design itself is **not edited** by this plan.
4. **CONDITIONALLY APPROVED:** bounded S1 synthetic continuation has its separate human receipt `00b97fcc-ccbf-403b-84ea-319530805966`, but only after P1 independent certification, distinct S1 exact scope and its own Ready. Not executable now.
5. **REVIEW CANDIDATE / NOT YET APPROVED:** this exact v0.2.0 implementation plan and linked [seven-pass engineering packet](planning/README.md). The 2026-11-23 user authorization permits conducting and incorporating the focused technology review and preparing a PR, **not** asserting source-byte certification or a general architecture amendment.
6. **KANBAN PLANNING AUTHORIZED, EXECUTION STILL GATED:** the owner instructed individual, detailed creation of all ten FP-002 cards **one at a time**. [WELL-189](https://app.plane.so/symphony-development/browse/WELL-189) already exists as the provisional P1 **Planning** child under WELL-22. Future E1/E2/S cards may be added individually as **Planning**, with full scope, Store reuse evidence, native dependencies and explicit blockers, even when implementation-stage evidence is pending. This is backlog preparation only: final source-specific plan approval, the separate `/to-tickets` approval/reconciliation, proof-source hygiene if actually required and independent Ready gate are **still pending**. Planning cards are **not executable**.
7. **READY/HANDOFF GATE:** independently verify the future child is Ready, dependency-cleared, its P1-01..07 acceptance criteria are executable, current main and pinned dependencies are still applicable, and no known upstream contradiction exists. Only then `/ticket-implement`. Do not infer provider operation approval from P1.
8. **PROVIDER STOP:** [WELL-176](https://app.plane.so/symphony-development/browse/WELL-176) is Blocked; OQ-004 and stage-specific Paystack preflight remain unresolved. **No provider operation in P1**; provider-dependent E1/E2 tickets require applicable evidence and scoped approvals.

### Seven independent planning lenses

- [Pass 1 authority/traceability](planning/pass_01_authority_and_traceability.md)
- [Pass 2 scope/non-scope](planning/pass_02_scope_and_nonscope.md)
- [Pass 3 Domain lifecycles](planning/pass_03_domain_boundaries_and_lifecycles.md)
- [Pass 4 code integration](planning/pass_04_code_reconnaissance_and_integration_seams.md)
- [Pass 5 verification](planning/pass_05_acceptance_and_verification_matrix.md)
- [Pass 6 JIT/implementation handoff](planning/pass_06_jit_decisions_and_execution_handoff.md)
- [Pass 7 technology/dependencies/scalability](planning/pass_07_technology_dependency_scalability_decisions.md)

These are engineering **supporting references**, not seven work items or new Product/Architecture/Domain law. Pass 7 selects the *existing pinned Ash/AshPostgres/PostgreSQL + AshOban/Oban* foundation as sufficient for backend-only P1. Reactor remains optional and is not the financial recovery authority. AshPhoenix is preferred for the first applicable Ash-backed UI slice after compatibility proof; AshAdmin restricted evaluation only; Signals, temporal Resources, AshStorage and extra infrastructure are not P1 prerequisites. No new package is adopted by this documentation PR.

### Technology/proof interface held constant

P1 requires authoritative Commerce Ash acceptance/qualification, atomic verified payment plus durable Commerce-owned consequence, Entitlements-owning grant after source validation, independent PostgreSQL idempotency, three crash cuts, compile-isolated TEST producer and Identity owner reconciliation. No Reactor compensation, Ash.Signal, queue delivery or cached state may stand in for a committed payment or grant. Exact Resource/module/action/transaction/index/worker selection is **JIT**; no tool-selection preference should invent new immutable Product semantics.

**Scope graph:** **TEN** proposed implementation units: P1; E1a/E1b/E1c; E2a/E2b/E2c; S1/S2/S3. The owner now requests one-at-a-time detailed **Planning** Kanban cards for all ten. This changes backlog-preparation sequencing only; no future item is Ready, executable or provider-authorised merely because its Planning card exists.

## Dependency and proof scope

Direct proposal edges appear below. Link a provider-evidence item only if its completion matches the applicable stage prerequisite. If it does not, resolve the stage-specific evidence tracker before publication and record the required receipt in the acceptance criteria. Global OQ-004 closure would incorrectly block tickets that produce some of its proof.

| Ticket | Direct proposed blockers | Proof entry |
| --- | --- | --- |
| P1 | None | FP-001 is satisfied through WELL-21. Phase 7, classification, proof design, plan and Ready still apply. No WELL-176 edge. |
| E1a | P1 | Applicable WELL-176 Wave 1 and channel/adapter input evidence. |
| E1b | E1a | Applicable sandbox ingress and payment evidence. Independently proves known-reference recovery. |
| E1c | E2c | Full mixed payment/refund/dispute scan. E1b runs without it. |
| E2a | P1 | Approved synthetic correction fixture and actor scope. |
| E2b | E1b, E2a | Applicable provider refund-stage entry and financial proof controls. |
| E2c | E2b | Applicable dispute-stage entry and financial proof controls. |
| S1 | P1 | P1 certification plus express bounded continuation approval, or its separately satisfied ordinary-slice architectural gate. |
| S2 | S1, E1b | Approved scope-specific proof, provider/channel evidence and content eligibility. |
| S3 | S1, E2c | Approved scope-specific proof, Finance approval/scopes and provider correction evidence. |

E1c is FP-002 exit proof. It depends on the corrections path because it exercises a mixed scan through payment, refund and dispute interfaces. It does not gate single-reference repair or S2. S3 starts from committed obligations, so there is no S2 edge. Preserve separate release gates for the approved channel, settlement, production key and webhook operations, dispute deadlines, Legal/Privacy, content, abuse controls and paid-pilot readiness.

## Ticket scopes, acceptance and completion evidence

### P1. Prove one standalone Plan purchase creates one held right

Use P1-01 through P1-07 in the proof design as the acceptance criteria. Reuse Identity current Session and Account authority, `RegistrationOperation` replay and the durable Audit/Communications obligation patterns. Build only the owning acceptance, evidence, payment and entitlement interfaces used by this proof. Completion requires the exact-head synthetic trace, counts after all commit cuts, production fixture exclusion, separation of held right from delivery and consumption, and Identity regression results. This ticket has no provider stage result.

### E1a. Prove hosted dispatch and ambiguity handling

Add the minimal Commerce provider adapter and dispatch entry. Persist the attempt before dispatch and count actual mutations on simultaneous admission and post-send response loss. Restart retains the known reference. Resumption requires evidence tied to that same attempt. Replacement remains fenced until the old attempt is irreversibly nonpayable and any in-flight collection is resolved. Prove environment, channel, fee, metadata, reusable authorisation and hosted card boundary controls at the affected stage. Exclude inbound processing and bulk scans. Completion includes exact HTTP client/middleware/proxy configuration, redacted request counts, EV-050 B and applicable EV-018–020, EV-035/036 and EV-040 evidence. Keep Wave 1 and EV-050 A as separate receipts.

### E1b. Prove signed ingress and scheduled recovery by known reference

Use real `NewYouWeb.Endpoint` dispatch and privacy controls for signed ingress. Verify the signed payload at the exact boundary, reject forged, unknown or misbound observations, and acknowledge only after durable receipt. Browser return and evidence replays do not grant access directly.

Independently exercise a persisted pending attempt with browser return and webhook delivery both absent and the E1c scanner unavailable. A durable schedule must rediscover or resume the known reference after a fresh process starts. Show that temporary verification failure preserves pending state and schedules another bounded read. If automatic attempts exhaust, the unresolved reference remains visible and recoverable. A later qualified verification applies exactly one payment and one source-specific right. Test repeated scheduled work, stale observations and a second restart after commit. Evidence includes the durable work and attempt observations and zero reliance on cross-object scans. Exclude general paginated scanning and correction paths.

Bind applicable EV-003–008, EV-014, EV-021, EV-034 and EV-052 stages. Track EV-037 as supporting evidence. Do not substitute local fixtures for pre-JIT provider observations.

### E2a. Prove correction adjudication and source-right convergence

Use qualified synthetic observations, the P1 owning interfaces and an immutable allocation fixture. Distinguish duplicate evidence, verified excess and distinct obligations. Assert one exact claimant and excess obligation under concurrency, original component attribution after repricing, and no correction or right change from unresolved partials. Replay after a correction or deletion cannot restore access. Preserve independent rights, lawful history and denied Finance bypass. Exclude refund/dispute transport and operator UI. Supply synthetic restart and money/access assertions for applicable EV-012/024/042 portions. Carry the unproved EV-024 provider-bound path into E2b.

### E2b. Prove refund dispatch and reconciliation

Use the E2a obligation and an E1b reconciled payment. For the applicable EV-024 NewYou stage, apply accepted evidence of two genuine collections through E2a and prove one valid purchased right and one exact make-whole obligation. Require separate sandbox evidence. Count Create Refund requests on lost response and restart, reconcile the original outcome and reject concurrent over-refund. Partial `reversed` evidence cannot assign a component by itself. Insufficient balance leaves the owed obligation visible and recoverable. Exclude disputes and operator UI. Retain EV-010/011/025–029/048/051/053 evidence at their declared stages, with separate EV-051 A and B results.

### E2c. Prove dispute and competing correction outcomes

Use Commerce's correction fence for dispute transitions. Exercise replays, stale success after reversal, refund/dispute overlap, partial attribution, restoration and final loss. Verify affected rights, preservation of independent rights and lawful history, and minimised dispute evidence. Exclude operator UI and live runbook certification. Record applicable EV-013/032/033/046/049/054 stages and preserve any separate release requirements.

### E1c. Prove cross-object reconciliation completeness

Use the proved payment, refund and dispute reconciliation interfaces. Exercise overlapping pages, late objects, crashes before and after checkpoint commit, `429` backoff and terminal pages. Assert no skipped object, one effect per source and bounded backlog recovery. Include settlement inputs only to the extent the approved internal case requires. Retain measured EV-043/044/055 completion evidence. E1b already proves known pending references without this scanner.

### S1. Admit eligible offers with Assessment interlocks

Extend P1's fixed version to versioned offers, disclosed allocation and canonical recipient eligibility. Prove stale quotes fail closed and repricing cannot alter accepted facts. Block Assessment and bundle for held/unused credit or a blocking delivery interval, and keep Plan-only available. Unavailable required source history blocks affected admission. Race distinct Assessment-bearing intents while a competing attempt can still pay and while a paid consequence is outstanding. Verify durable restart and replay. Use approved source fixtures for later delivery truth. Exclude dispatch and fulfilment. Require accountable Commerce approval of exact component amounts and disclosure before genuine bundle use. Record the explicit proof-entry approval alongside exact-head admission results.

### S2. Present hosted checkout and authoritative purchase status

Connect S1 offers to E1a/E1b through the real browser boundary. Repeated submit, missing return, refresh and reauthentication recover the same intent. Display owner-sourced pending, payment and entitlement outcomes without implying Plan delivery. Protect foreign payer/recipient data and fail closed on missing eligible locale. Require exact EN/AF wording eligibility and applicable privacy, accessibility and Hallmark proof. Exclude bulk scan and correction workflows.

### S3. Provide scoped Finance correction and Support visibility

Use the proved E2 interfaces and S1 accepted allocation. Show authorised inspection and mutation, reject revoked/stale/unscoped approval, and converge concurrent requests and lost acknowledgements. Show owed, unresolved and reconciled states with scoped actor, payer and recipient disclosure. Verify the affected component and preservation of independent rights. Existing Identity Support grants provide patterns only. Obtain approved Finance role and scope through the owning boundary. Exclude the Operations working elective remedy and broad operator administration.

## Implementation and verification order

After P1 is Ready, start with failing proof at the owning interfaces, including the Identity registration integration and production fixture denial. Implement the smallest owner actions and PostgreSQL constraints to pass, then exercise equivalent input, the independent transaction race and each process-loss cut. Use existing Ash/PostgreSQL and transactional consequence patterns. Keep provider I/O outside authoritative transactions in later tickets. E1 and E2 extend the proved actions in dependency order, with test-first negatives and recovery at their applicable seams.

For executable candidates, apply the repository's Mise/DevCore TEST verification and exact-head requirements, including focused tests, `mise exec -- devcore-project run test -- mix check` and applicable `mix check.deep`. Maintain the source-linked capability handoff. Review required CI and independent proof against the exact candidate. Revalidate evidence after material changes. FP-002 exit additionally requires all governed Roadmap outcomes and evidence. Paid release remains separately gated.

See the [manifest](../../jit/paystack_validation/NEWYOU_PAYSTACK_EMPIRICAL_MANIFEST_WORKING_v1.0.2.md) and [WELL-176 accepted evidence](https://app.plane.so/symphony-development/browse/WELL-176). Preserve the temporary EV-050 A pass, limited EV-001A observation, unexecuted EV-001B and original quarantined attempt. A mock never promotes a provider stage. Record explicit authority for any `GOVERNED_NA`.

---

## FP-002 complete execution blueprint: committed choices, scope and handoff

This section is the **single programme execution index** for all ten proposed units. The seven [engineering review passes](planning/README.md) are supporting evidence and alternatives, not additional Product/Architecture/Domain authorities or seven separate Plane tickets. The [certified Phase 7C Feature Pack](../../feature-contracts/fp-002/FP-002_FINAL_FEATURE_PACK_CONTRACT_v0.2.0.md), [Product/Decision law](../../../governance/product/00_PLATFORM_v1.20.0.md), [Architecture](../../../governance/architecture/03_ARCHITECTURE_v1.1.1.md), [Domain Map](../../../governance/domain/04_DOMAIN_MAP_v1.2.0.md), [Roadmap](../../../governance/roadmap/05_ROADMAP_v1.2.5.md), and exact accountable-human-approved [P1 proof design](../../proof/fp-002/FP-002_TRACER_BULLET_DESIGN_CANDIDATE_v0.1.0.md) take precedence. This is implementation planning, not a unilateral change to upstream durable semantics.

### Authority, approval, publication and development gates

| Gate | Entry / independent verification | Exit / exclusions |
| --- | --- | --- |
| Plan | Current routed 7B/7C, selected `NEW_TRACER_BULLET`, exact approved P1 proof design, seven technical passes, inspected live stack | Review and explicitly approve **the exact bytes** of this candidate plan. No development authority from a draft PR |
| `/to-tickets` | Approved exact plan and explicit approval of the scoped near-term breakdown | Create **only one** P1 child under WELL-22; preserve other nine units as plan outlines. New child starts non-Ready |
| Independent Ready | Published P1 child, source links and P1-01..07 coherent, dependency cleared, current main and package APIs verified, proof-source candidate status reconciled where necessary | Move that child to `Ready`. Never mark Ready just because a task exists |
| `/ticket-implement` | Exact Ready P1 child; worktree/branch isolation; current authority checked | TDD implementation through owners and PostgreSQL; open exact-head PR; no Paystack I/O |
| Technical certification | Complete code PR diff, risks, migrations, review, targeted tests, required exact-head CI, independent crash/concurrency/security proof | Independent Master Gate and human merge instruction; candidate-head change invalidates review |
| Post-merge | Verify resulting-main SHA/tree, no drift, integration CI and original proof conditions | Mark P1 Done and assess next eligible scoped work. Not an FP-002 programme exit |
| Later provider/release | Specific provider-operation authorization, WELL-176 stage receipts and exact ticket Ready; legal/clinical/privacy/copy/channel gates | Stage-specific evidence only. No blanket Paystack grant or automatic live release |

The user's authorization to prepare and commit the comprehensive implementation direction is not a substitute for accountable approval of the final exact bytes, a separate `/to-tickets` decision, a Ready gate or merge authority. Human-approved P1 proof semantics remain unchanged even though its GitHub source filename still contains `CANDIDATE`.

### Explicit dependency decisions and versions for FP-002

The definitive dependency **version lock** remains actual [mix.exs](../../../../mix.exs) + [mix.lock](../../../../mix.lock), verified on base main `1bfb351e295d8e03704e6b057b334f84429581aa`; every implementation handoff rechecks current main. A package capability may be selected without mandating that every new Resource use it. No dependency installation is part of this documentation plan.

| Technology | Verified baseline | Selection / exact scope | Correctness boundary / future trigger |
| --- | --- | --- | --- |
| Elixir/BEAM, Phoenix, LiveView | Existing modular release; Phoenix `~> 1.8.17`, LiveView `~> 1.2.0` declared | **RETAIN**; one application/release family, presentation boundary only | LiveView/session/ETS do not own commercial or entitlement state |
| Ash | `== 3.37.2` | **SELECT / P1**, all authoritative Commerce and Entitlements business writes through owning Ash interfaces | No parallel ordinary Repo/Ecto.Multi/raw SQL cross-Domain writes |
| AshPostgres + PostgreSQL | `== 2.15.2`; PostgreSQL 18.6 in Application CI | **SELECT / P1** as structured business authority, unique/foreign/check constraints, independent transactions, replay and recovery | CI database version does not independently prove production version; check migrations and actual production compatibility when needed |
| AshStateMachine | `== 0.3.0` | **RETAIN / use where material state-machine semantics benefit from extension** | Explicit transitions/guards/authorization/concurrency/idempotency required regardless of DSL choice |
| Oban + AshOban | Oban `== 2.24.2`, AshOban `== 0.10.2`; PostgreSQL Basic engine | **SELECT / P1 execution**, durable work processing and background rediscovery from persisted owner state | Queue uniqueness and successful job execution do not substitute for source-level idempotency or durable consequence |
| Reactor / Ash.Reactor | Reactor `== 1.0.1`, intentionally pinned | **RETAIN / OPTIONAL** for bounded coordination in later stages; **NOT REQUIRED FOR P1** | Reactor compensation is not cross-transaction ACID rollback or financial durable-state authority; no untested upgrade to prerelease dependencies |
| AshAuthentication, AshCloak | `== 5.0.0-rc.17`, `== 0.4.0` | **RETAIN** current identity/security implementation | No parallel Account/session authority or privileged synthetic browser input |
| AshPhoenix | Not installed | **CONDITIONALLY SELECT** `AshPhoenix.Form` for first suitable Ash-backed Phoenix UI slice (likely S2); **NOT P1** | At that ticket resolve exact compatible version with Igniter/locked graph and test actor/policy, validation, nested forms and sensitive errors |
| AshAdmin | Not installed | **DEFER** restricted dev/staging evaluation, no generic production Finance/Support super-admin | Any trial proves access restrictions, actor context, per-action policies, audit and PII protection; never bypass owner interfaces |
| Ash.Signals | Available in core Ash | **OPTIONAL NON-AUTHORITATIVE**, not mandatory payment-to-right delivery | Committed Commerce consequence must survive absent listeners/signals and restart |
| Ash Temporal Resources | Experimental Ash capability | **EXCLUDE FROM P1**; reevaluate for actual temporal-validity requirement | Not a substitute for immutable money facts, source identity, unique grant or financial audit history |
| AshStorage | Not installed | **DEFER**; current Hex release status not independently verified | First approved binary-object feature must prove registry/compatibility, metadata ownership, S3 data security, deletion/orphan recovery |
| AshMoney, PaperTrail/Archival, AuthenticationPhoenix, JsonApi/Graphql, AshAI and rate limiting | Not adopted in current P1 | **DEFER** to owning feature with concrete requirement | Cannot take over Commerce, Entitlements, Audit, Identity, Finance or Privacy law |
| Extra Repo, Redis/cache authority, Kafka, microservices, Rustler, extra services, app replicas, external workflow engine | Not justified by P1 | **NO NEW INFRASTRUCTURE** | Need measured bottleneck or proven invariant and explicit architecture/operations approval |

**Package-resolution rule:** installed dependency versions are locked by the current repository. Uninstalled future packages are *choices conditioned on a future scope*, **not** a fabricated exact version pin. Any new package must show alternatives, real compatible resolver output, security and transitive graph review, deliberate lock change, risk-appropriate tests and independent review. Primary-source links and more detailed comparative reasoning are in [Pass 7](planning/pass_07_technology_dependency_scalability_decisions.md).

### End-to-end ownership flow and invariant boundary

```text
Authenticated Identity Account + current actor
  -> Commerce-owned accept (immutable payer/recipient/Plan version/ZAR 39900 minor units)
  -> Commerce-owned known pending attempt
  -> TEST-only internal qualified observation through genuine Commerce owning action
  -> Commerce PostgreSQL atomic verified-payment + mandatory durable consequence
  -> restart/absence-of-job-safe discovery and Entitlements own source verification
  -> Entitlements PostgreSQL apply-once one held_unconsumed Plan component right
  -> authorised recipient can read the held right AFTER its commit only

Not included in P1: Paystack, public checkout, Plan fulfilment/content,
consumption, Assessment, bundle, refund, dispute or production synthetic producer.
```

**One authoritative owner per durable truth:** Identity owns Account/session/provenance, Commerce owns admission/purchase binding/attempt/payment and correction obligations plus committed outgoing consequence, Entitlements owns the resulting rights and their corrections. Audit/Communications/Privacy/Analytics keep their existing Domain ownership. Cross-Domain mutation traverses the owning Ash interface, and Entitlements verifies a committed source rather than trusting a caller-provided amount/status. Reactors, signals, PubSub, webhooks, callbacks, job acknowledgements, search projections and process-local data are never money or access authority.

### Meaningful lifecycle model — owner-visible contracts

The following describes required observable states and transitions without pre-selecting internal Resource names, columns or framework mechanics.

| Owned concept | States / transitions | Guards, consequences and terminal/recovery behavior |
| --- | --- | --- |
| Accepted purchase + attempt (Commerce) | immutable accepted binding -> known pending attempt -> qualified verified payment, or later proven nonpayable/closed outcome | Verified Identity actor, canonical payer/recipient, exact version/amount/currency and idempotency; same acceptance replays, changed binding denied. A pending/unqualified attempt cannot grant rights. Provider ambiguous state may not be silently replaced while payable |
| Payment source truth (Commerce) | absent/unqualified -> verified committed; later correction-affected status governed separately | Only Commerce qualifies matching genuine source/environment/attempt/binding; equivalent concurrent evidence must converge to one payment. On verify, one payment and one mandatory consequence commit atomically; never rewrite original accepted facts to mimic correction |
| Mandatory grant consequence (Commerce) | open -> being applied/claimed -> applied/reconciled; recoverable failed/stale/exhausted | Source identity, owning authorization, concurrency/idempotency; missed job or crash cannot erase the obligation. After grant-before-ack, fresh execution detects existing right and settles original consequence, no duplicate |
| Plan source right (Entitlements) | absent -> `held_unconsumed`; future governed delivered/consumed/reversed states **out of P1** | Verified committed Commerce source + correct recipient/component + owner action; one source-specific right; no direct Commerce write. Held is not delivered and authorizes no Plan content, delivery or consumption |
| Identity owner reconciliation | current proven acceptance; negative, unknown, missing, conflict, stale -> denied | New registered Commerce/Entitlements owner reviews must join the same fail-closed review; verify positive, negative, unknown and fresh-BEAM/restart regression without altering Identity owner truth |
| Later correction/refund/dispute (Commerce -> Entitlements) | owed/unresolved -> verified attributable correction -> reconciled or terminal lawful disposition | Approved scoped source and component allocation, concurrency fence, no duplicate refund/excess obligation, preserve independent rights and historical collections; do not infer full attribution from partial reversal |

**P1 access guard:** verified canonical Account + authorised recipient + committed qualified Commerce payment + correct persisted source consequence + committed Entitlements held right. A missing conjunct denies access; no inference from UI, browser return, fixture presence, Reactor/Oban success or signal emission.

**Concurrency and failure proof:** P1-02 uses **two independent PostgreSQL transactions**, not an in-memory serialization or sequential helper. Unique and source-binding DB constraints complement Ash policy checks. P1-03 rollback before Commerce commit leaves zero payment/consequence/right; P1-04 crash after Commerce commit before grant leaves discoverable consequence and one eventual held right; P1-05 crash after grant commit before ack reconciles without duplication. Proof must cross a genuinely fresh process/restart and include relevant SQL row identities/effect counts; a job may be missing/exhausted and discovery must still work.

### P1-01 through P1-07 approved proof traceability

The [accountable-human-approved proof design](../../proof/fp-002/FP-002_TRACER_BULLET_DESIGN_CANDIDATE_v0.1.0.md) controls exact semantics. This matrix is a **planning trace**, not a replacement or enlargement of its acceptance authority.

| Exact P1 case | Engineering check | Negative and durable result to demonstrate |
| --- | --- | --- |
| **P1-01** — Acceptance and qualified evidence | Canonical verified payer=recipient; fixed standalone Plan version, 39,900 ZAR minor units; one accepted purchase/known attempt | Same input idempotently replays; changed actor/recipient/version/amount/currency/integration/environment, pending or unqualified source produces no verified payment/right |
| **P1-02** — Independent concurrency and access | Two independently committed/contending PostgreSQL transactions apply equivalent qualified evidence through genuine Commerce/Entitlements Ash actions | Exactly **one verified payment, one durable consequence, one held source-specific right**; deny direct unauthorized grant, foreign read and any Plan content/delivery/consumption |
| **P1-03** — Pre-Commerce-commit failure | Abort Commerce authoritative payment/consequence transaction before commit | Zero verified payment/consequence/right, even if an earlier accepted pending attempt survives |
| **P1-04** — Post-Commerce commit/pre-grant crash | Fresh process reloads original committed consequence and asks Entitlements through owner interface | Access unavailable before grant commit; one held right after recovery, no lost consequence |
| **P1-05** — Post-grant commit/pre-ack crash | Fresh retry reconciles the original consequence against original source-specific held right | No duplicate right/payment, no delivered content/consumption or second source |
| **P1-06** — Production synthetic exclusion | Compile/test production profile to establish TEST producer absent; attempt ordinary forged input | No production browser, header, provider/callback or runtime switch can make synthetic evidence qualify |
| **P1-07** — Identity owner registration regression | Registered Commerce and Entitlements owner reviews integrated with Identity positive/negative/unknown/conflicting/stale and restart checks | Existing `UnreviewedProofDomain` fail-close retained; no Identity direct write to Commerce payment or Entitlements rights |

Required evidence: named focused test cases, source IDs/row counts at each crash cut, independent transaction overlap proof, real process restart, compile isolation, actor denials, migration/constraint safety, HIGH proof-menu applicability and exact-head CI. No synthetic case promotes Paystack or later FP-002 stage certification.

### Store Blueprint Hardening — mandatory reuse-first matrix for FP-002

**Source provenance and authority:** Store Blueprint Hardening [canonical inspected commit](https://github.com/Carpe-Diem-Media/Store_Blueprint_Hardening/tree/949821ac589addb6e595f6333370ed65cf8d5ef7); NewYou's existing [Commerce/Entitlements Store reuse matrix](../../jit/commerce_entitlements/NEWYOU_CER_EVIDENCE_INDEX_WORKING_v0.2.1.md#8-store-reuse-evidence); and the newer [source-level Store reuse assessment](../../proof/paystack/well-176-hosted-redirect/STORE-REUSE-ASSESSMENT.md). These are **implementation evidence, not NewYou Product/Architecture/Domain Law**. Older CER entries predate the current Store head and may be superseded by the newer focused assessment; do not silently promote an older "REUSE AFTER HARDENING" label into current approval.

**Required in every ticket:** recheck live Store `main` and current NewYou `main`; inspect actual matching Store code, migrations, tests and AGENTS.md; record both exact SHAs and source paths; classify each candidate **REUSE**, **EXTEND**, **COMPOSE**, **INTRODUCE** or **REPLACE**, with compliance, compatibility, NewYou owning-Ash interface and concrete test/proof. Prefer genuine suitable reuse instead of reinventing existing mechanisms. **Do not wholesale import Store modules, migrations, actor bypasses, Redis/Cache, Domain boundaries, shipping, inventory, subscriptions, or incomplete Paystack code**. Code reuse is not a mandate to copy an unsafe or incompatible implementation.

| Unit | Store code candidates (relative to Store SHA above) | Decision and NewYou-only guard |
| --- | --- | --- |
| **P1** | `lib/store/checkout/domain.ex` admission; `orders/snapshot_writer.ex` immutable pricing; `orders/payment_application.ex` unique apply-once; `payments/payment_attempt.ex` attempt evidence; `subscriptions/access_effect.ex` source consequence; `entitlements/entitlement_grant.ex` source identity | **REUSE/ADAPT/COMPOSE** proven uniqueness, immutable snapshot, durable source consequence and grant patterns through NewYou Commerce/Entitlements. No Store cart, inventory, shipping, subscription owner, generic `active` entitlement or foreign writes. P1-01..07 must prove fit |
| **E1a** | `payments/domain.ex` intent and missing-reference path; `subscriptions/renewal_collection_attempts.ex` locked exact-epoch dispatch claim; `payments/providers/paystack.ex` | **COMPOSE** pre-dispatch durable fence from stronger claim; **INTRODUCE** NewYou Paystack Hosted Redirect. Store one-off pending-refresh can re-dispatch and its Paystack `create_intent` is unimplemented. No provider calls without explicit stage approval |
| **E1b** | `payments/webhook_receipt.ex`, `provider_event.ex`, `observation_evidence.ex`, `store_web/controllers/webhook_controller.ex`, receipt worker | **EXTEND/ADAPT** raw-verified receipt, dedupe and known-reference recovery; never claim Store's webhook certifies Paystack signature rules, durable absent-job recovery or authorization |
| **E2a** | `payments/interlocks.ex`, `orders/payment_application.ex`, `entitlements/source_convergence.ex` | **REUSE/COMPOSE** late verified correction and apply-once; NewYou duplicate-vs-genuine collections, component attribution and DEC-314 obligations remain owner-specific |
| **E2b** | `payments/refund.ex`, `refund_attempt.ex`, `refunds.ex`, payment evidence | **ADAPT** proven financial/retry patterns; NewYou refund eligibility, over-refund, affected held right and Paystack stage verification remain separate |
| **E2c** | Store provider evidence/dedupe and source-grant identity | **REUSE evidence primitives / INTRODUCE** NewYou dispute-versus-refund lifecycle. Existing matrix explicitly marks Store dispute business semantics **NOT REUSABLE AS-IS** |
| **E1c** | Store known-reference selectors and durable worker patterns | **EXTEND** discoverability; **INTRODUCE** complete mixed payment/refund/dispute pagination/checkpoint scan. Store reference recovery does not prove `429`, overlap and terminal-page completeness |
| **S1** | Store immutable order snapshot, checkout admission locks, idempotent price version | **ADAPT** generic acceptance; NewYou R249/R399/R549 offers, Assessment held-credit guards, recipient and disclosed allocation are not Store membership policy |
| **S2** | Store checkout actor/status and browser-return patterns | **ADAPT** client reentry/status only after inspection; NewYou Hosted Redirect, EN/AF, current entitlement and no browser-payment authority must be newly proved |
| **S3** | Store refund/correction source identities and scoped observation patterns | **ADAPT** proof approach; NewYou Finance/Support approval, access, audit and purpose-bound writes never inherit generic Store administrator privileges |

**Ticket evidence is not satisfied by a link alone.** The implementer must identify the concrete Store source mechanism, the NewYou code/action that reuses or adapts it, the reason for any nonreuse and the focused tests. P1 specifically ties admission/snapshot to P1-01, unique financial application to P1-02/03, source consequence and Entitlements grant to P1-04/05, and owner authorization/isolation to P1-06/07. Reuse source code only with current APIs and checked-in version compatibility, and only through the owning NewYou Ash boundary.

### Ten-unit staged roadmap with entry, evidence and exclusions

| Proposed unit | Direct blockers | Executable outcome and proof boundary |
| --- | --- | --- |
| **P1** | Approved Phase 7/P1 exact design/plan/publication/Ready; FP-001 Done; **NOT WELL-176** | One real Commerce payment/durable consequence -> one Entitlements held right, P1-01..07, genuine independent SQL races and crash cuts. Zero provider network/Plan delivery/assessment/bundle |
| **E1a** | P1 + applicable WELL-176 Wave-1 provider authorization | Persist known payable attempt before hosted Initialize; ambiguity, lost send response, exact outbound mutation counts; no inbound webhook or bulk scan |
| **E1b** | E1a + applicable provider payment/ingress evidence | Signed endpoint intake, known-reference independently scheduled recovery without browser/webhook/E1c, absent/failed job recovery and double-restart proof |
| **E2a** | P1 + approved synthetic correction proof | Source-specific excess/duplicate distinction, adjustment obligation and affected-right convergence; no external refund/dispute |
| **E2b** | E1b + E2a + refund-stage operation/evidence | Provider refund attempt and recovery, genuine double collection, exactly-one excess obligation, no over-refund, provider-stage receipt |
| **E2c** | E2b + dispute-stage authorization/evidence | Dispute overlap/late evidence/refund concurrency, affected rights and history, secure dispute material |
| **E1c** | E2c for complete cross-object scan | Mixed payment/refund/dispute pagination, late objects, checkpoint crash, rate limiting, no skipped source; E1b does **not** depend on E1c |
| **S1** | Independent P1 certification + distinct scope approval + own Ready | Synthetic versioned offers, R249 Assessment/R399 Plan/R549 bundle eligibility, held credit/annual-delivery interlocks. Real bundle requires separately approved R99 allocation/disclosure; no provider dispatch/fulfilment |
| **S2** | S1 + E1b | Real Phoenix hosted checkout and authoritative pending/payment/held-right status. EN/AF, accessibility, privacy, identity and actor verification; no false Plan delivery |
| **S3** | S1 + E2c | Purpose-built, least-privilege Finance correction/Support visibility, concurrent repairs, lost ack and scoped disclosures; not an AshAdmin superuser shortcut |

**Ticket publication policy — 2026-11-23 owner instruction:** Populate the ten-item FP-002 Kanban **one detailed card at a time**, under WELL-22 and in **Planning**, with its own Store-source reuse verdict, testable scope, native dependency relations and future gate evidence. P1 is WELL-189. This is **not** approval for Ready/implementation, provider operations, or unreviewed release. E2a or conditionally S1 may enter development after independently certified P1 plus their own Ready; E1/E2 provider work still requires operation-specific approval and relevant WELL-176/OQ-004 evidence. Preserve FP exit and release gates separately.

### Security, performance, scalability and reliability acceptance

1. **Security/PII:** prove incorrect actor/payer/recipient/environment/attempt/amount/currency/version denial, missing source evidence, direct foreign-right grant/read denial, test-only fixture compile exclusion in production, sanitized logs, and no bypass through Phoenix or raw Repo. Different provider/Finance/health risks receive their own later HIGH proof.
2. **Financial correctness:** database-enforced uniqueness and source-binding constraints are correctness mechanisms, not optional indexes. Count real writes and identities under two independent SQL transactions. Duplicate provider messages are not evidence of two collections; distinct verified excess creates an exact make-whole obligation and source-specific correction, never a second paid right.
3. **Durability:** use PostgreSQL-committed immutable source+consequence, independently rediscoverable across deployment/process failure and absent/failed jobs. Oban queue uniqueness does not replace it. Exercise all P1-03..05 commit boundaries and fresh execution.
4. **Migration safety:** additive/reviewable migrations where possible, constraints validated against actual data, adjacent-version upgrade/restart/rollback strategy, no competing Repo and no destructive financial rewrite. HIGH migration/integrity proof recorded per exact code PR.
5. **Measured scalability:** start by profiling Ash query shapes, N+1/loading, bounded pagination, `EXPLAIN`/indexes, transaction lock waits, and a platform-wide finite PostgreSQL pool budget. Calibrate existing Oban queue throughput/backlog/reconciliation age against DB/provider limits. Do **not** assert universal TPS, p95, worker counts or a second service before representative measurements. Horizontal app replicas/Redis are evidence-gated, not P1 requirements.
6. **Observability:** instrument qualification rejection, payment commit, outstanding consequence, grant convergence, recovery lag, mutation count and denied foreign access with stable low-cardinality names. No health text, provider keys, high-cardinality Account labels or raw sensitive payloads in metrics/logs. Exporter/telemetry failure cannot block a correct payment.
7. **Release:** internal synthetic P1 is not a public paid feature, provider proof-stage certification or whole FP-002 completion. All stage-specific security, Legal/Privacy, content, EN/AF, provider environment, settlement and release-runbook requirements retain independent gates.

### First-ticket implementation handoff — what to verify, what to leave JIT

Before a **Ready** P1 ticket starts, inspect [AGENTS.md](../../../../AGENTS.md), current routers, the approved P1 design, [Identity reconciliation](../../../../lib/new_you/identity/reconciliation.ex) and its [negative regression tests](../../../../test/new_you/identity/reconciliation_test.exs), [registration operation](../../../../lib/new_you/identity/registration_operation.ex), [Audit durable obligations](../../../../lib/new_you/audit/evidence_obligation.ex), [Communications intent](../../../../lib/new_you/communications/message_intent.ex), [mix.exs](../../../../mix.exs), current migrations and package APIs. Existing `owner_reviews/1` must account for new Domains **in the same implementation change** with positive/negative/stale/restart cases. Follow current `.agents/skills/ash-framework/SKILL.md`, `.agents/skills/ticket-implement/SKILL.md`, Igniter-first supported structural changes, and repository implementation knowledge standard.

**Test-first:** start with P1-01..07 fail cases through real owning Ash interfaces, not fixture-only mocks; two independent database transaction races, fresh restart cut tests, read/authorization denials, production synthetic compile-proof, durable identity review. Choose the minimal owner actions, Resources, keys, migrations, constraints, transaction shapes, workers and internal modules during implementation and prove them; this document does not freeze those representations. Record all HIGH financial/entitlement proof-menu applicability decisions and exact-head CI; use repository Mise/DevCore TEST commands, focused `mix test`, `mise exec -- devcore-project run test -- mix check` and applicable deep checks. Produce a source-linked capability handoff under `docs/development/knowledge/` in the code PR.

The final master gate independently inspects the **exact base/head, full diff, immutable ownership and lifecycle, migration/locking/idempotency/restart/security, live Plane acceptance and same-head CI**. No merge without a specific user request. Once merged, validate resulting-main SHA/tree and required evidence before moving P1 Done/opening a dependent ticket.

### Explicitly deferred and unapproved questions

- Final Ash Resource/field/action/index/transaction/worker design remains ordinary **JIT**; omission alone is not a governance STOP.
- AshPhoenix exact package version waits for its relevant UI ticket; AshAdmin production management surface is **not approved**; Reactor upgrades and temporal/storage libraries need concrete compatibility/security proof.
- Approved commercial live bundle allocation and component disclosure, actual Paystack provider environment and mutation limits, stage EV receipts, Finance roles, EN/AF final channel copy and production scale topology are not silently settled here.
- P1 proof-design GitHub candidate filename remains exactly human-approved; resolve focused source-status/routing treatment if the workflow requires it without changing accepted design semantics.
- A true upstream STOP requires conflicting/insufficient exact governing statements, no reasonable compliant JIT implementation and the durable semantic that would otherwise be invented; ordinary engineering choices continue.

**Execution conclusion:** This detailed package establishes one concrete starting slice and a complete, dependency-ordered ten-unit FP-002 path. It does not automatically create Ready status, approve provider work, merge code or grant production release.