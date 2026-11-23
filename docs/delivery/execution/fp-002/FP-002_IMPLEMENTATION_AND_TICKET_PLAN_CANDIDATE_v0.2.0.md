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
6. **SEPARATELY PENDING:** final `/to-tickets` decomposition/publication approval. Only after both exact-plan and publication approvals, plus any strictly required proof-source status hygiene, create **one near-term P1 child** of [WELL-22](https://app.plane.so/symphony-development/browse/WELL-22) from the [detailed draft](planning/P1_PLANE_TICKET_DRAFT_NOT_PUBLISHED.md). It starts non-executable; no automatic Ready transition.
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

**Scope graph:** **TEN** proposed implementation units: P1; E1a/E1b/E1c; E2a/E2b/E2c; S1/S2/S3. Later units are *outline proposals*, not executable or approved-for-publication tickets.

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
