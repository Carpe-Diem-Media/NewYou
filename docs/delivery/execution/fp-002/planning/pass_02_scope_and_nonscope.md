# FP-002 planning enhancement — Pass 2 of 7
## Scope, non-scope, dependencies and completion boundary

**Status:** Draft planning analysis. **P1 approved design is unchanged.** [Plan v0.1.0](https://github.com/Carpe-Diem-Media/NewYou/blob/main/docs/delivery/execution/fp-002/FP-002_IMPLEMENTATION_AND_TICKET_PLAN_CANDIDATE_v0.1.0.md) is the base partition, not yet approved for publication. Read with [Phase 7C](https://github.com/Carpe-Diem-Media/NewYou/blob/main/docs/delivery/feature-contracts/fp-002/FP-002_FINAL_FEATURE_PACK_CONTRACT_v0.2.0.md) and [P1 design](https://github.com/Carpe-Diem-Media/NewYou/blob/main/docs/delivery/proof/fp-002/FP-002_TRACER_BULLET_DESIGN_CANDIDATE_v0.1.0.md).

### P1: single bounded transaction-to-entitlement proof

**Objective:** In real NewYou Ash/PostgreSQL owner interfaces, one synthetic verified Account acting as its own payer and recipient accepts one **R399 Plan / 39,900 ZAR minor units**, retains one accepted obligation and known attempt, qualifies one synthetic TEST-only observation, commits exactly one Commerce payment plus mandatory durable consequence, and eventually creates exactly one Entitlements `held_unconsumed` Plan right. The authorised recipient can read the right only after the entitlement commit; an unrelated Account cannot. This proves bounded cross-Domain convergence and does **not** prove the provider or participant experience.

**Required in P1:**

- Minimal Commerce owning Ash acceptance, attempt/evidence qualification, verified payment and durable consequence interfaces needed by the proof. A payment must never commit without its durable consequence.
- Minimal Entitlements owning Ash source/component-specific grant/read interface; read permissions enforce canonical recipient and current authority. Grant once even across duplicate, concurrent, retry or recovery.
- Strict source identity binding (accepted purchase, payer, recipient, Plan component, known attempt/reference, synthetic TEST environment, ZAR and exact amount) and rejection of modified/unqualified/forged input.
- Three failure cut cases: rollback before Commerce commit, recovery after Commerce commit before grant, recovery after Entitlements commit before acknowledgement; fresh-process replay and durable counts.
- Two **independent PostgreSQL transactions** racing qualified equivalent evidence, not merely repeated calls in one process/sandbox connection.
- Registration of Commerce/Entitlements Domains together with their Identity reconciliation owner review in the same change; positive/negative, stale-owner, conflict and fresh-BEAM tests.
- Production *absence* of the TEST-only synthetic evidence producer, and rejection of fixture hints submitted over ordinary browser/provider-facing inputs.
- HIGH risk proof matrix, DB integrity, migrations/adjacent deployment safety, current relevant CI and a source-linked capability handoff appropriate to an implemented material cross-Domain capability.

**Not in P1:** Paystack SDK/network/key/hosted card/callback/webhook; open checkout UI; Assessment or bundle purchase; R99 allocation split; source-specific refund/dispute mechanics; merchant settlement; general scanner; plan generation, delivery, consumption or delivered Plan content; customer messaging; release, paid pilot and full FP-002 certification. P1 does not implement broader Commerce/Entitlements engines just to anticipate these future tickets.

**Functional stopping conditions:** Owner-sourced truth and constraints prove all P1-01..07; no protected content access; zero additional financial/right effects on replay; production fixture exclusion verified; Identity regression green; relevant exact-head CI/proof available. **Not sufficient for success:** an ExUnit in-memory simulation, a mock payment receipt, a synthetic provider stage, one transaction used for both competing writers, or only “job ran” evidence without durable owner state.

### Keep future slices bounded (not yet detailed implementation tickets)

| Slice | Direct blocker from existing candidate plan | Unique scope and proof | Hard non-scope / gate |
|---|---|---|---|
| E1a | P1 + applicable WELL-176 Wave 1/adapter evidence | Hosted dispatch; stored attempt before I/O, no blind retries, actual HTTP call count, ambiguous outcome fencing | No ingress or cross-object scan; operation-specific provider authorisation |
| E1b | E1a + signed ingress/payment stage evidence | Signed actual endpoint receipt, qualified payment, **known reference** durable recovery with browser/webhook absent and independent of E1c | No bulk scan, no correction; no provider-stage claim from P1 |
| E1c | E2c | Mixed payment/refund/dispute cross-object pagination and checkpoint correctness, bounded backlog/recovery | Does not block E1b known-reference recovery or S2 |
| E2a | P1 | Synthetic excess/claimant, immutable component attribution, correction-to-right convergence, deletion no resurrection | No provider refund/dispute transport or operator UI |
| E2b | E1b + E2a + refund-stage evidence | Real refund ambiguity, monetary make-whole, over-refund fence, insufficient-balance recovery | No disputes/UI; independent provider sandbox stage receipts |
| E2c | E2b + dispute-stage evidence | Disputes/restoration/final loss and competing correction fence, scoped disclosure | No operator UI or live runbook certification |
| S1 | Certified P1 + separate S1 scope/Ready | Synthetic versioned offers, Assessment unused-credit block, admission races/stale quotes, original accepted allocation | No genuine bundle activation without exact separately approved allocation; no provider I/O or fulfilment |
| S2 | S1 + E1b + appropriate channel/copy gates | Browser hosted checkout and owner-sourced status/recovery, EN/AF eligible copy | No delivery or provider scan; release separately gated |
| S3 | S1 + E2c + Finance scope decision | Finance correction and Support visibility through owner interfaces | No unapproved Finance bypass or broad admin |

**Dependency precision:** Existing native WELL-21 → WELL-22 is already satisfied; **do not** add WELL-176 as blocker of synthetic P1. For future provider tickets distinguish exact **stage** prerequisites rather than using blanket OQ-004 closure as a prerequisite to producing OQ-004 evidence. E1b must prove independent pending-reference recovery without E1c. Preserve E1c after E2c for the *chosen full mixed-scan claim*; review this edge if the scan scope materially changes, rather than treating it as universal dependency law.

### Publication criteria (separate from implementation)

1. Approve exact updated planning artifact **and** `/to-tickets` decomposition through the accountable workflow. Clarify stale plan wording that wrongly asks for reapproval of already certified 7B/7C, and the source-status treatment of P1 candidate text.
2. Create **one** near-term P1 child of WELL-22 with P1-01..07 as measurable acceptance, direct authority links and exact approval receipts. No six “planning pass” tickets: that fragments one review activity without independent work.
3. Leave the child **non-executable** until independent Ready verification. Do not publish all long-tail entries merely because the plan has a table.
4. S1 may be recorded as a future dependency, but a current executable S1 ticket needs separate approved scope and independent P1 certification.

**Pass-2 disposition:** Preserve the ten-slice graph and improve P1 explicit boundaries; no new decomposition needed within P1 unless the later implementation finds an independently reviewable, dependency-sensitive slice.