# FP-002 planning enhancement — Pass 3 of 7
## Domain boundaries, consequential lifecycles and recovery invariants

**Status:** Draft planning analysis only; not an amendment to Product, Architecture, Domain, 7C or the human-approved P1 design. **Verified source:** NewYou `main` `1bfb351e295d8e03704e6b057b334f84429581aa` on 2026-11-23. **Scope:** bounded synthetic P1 (one R399 / 39,900-minor-unit ZAR standalone Plan purchase). See [Pass 1](pass_01_authority_and_traceability.md), [Pass 2](pass_02_scope_and_nonscope.md), [certified Phase 7C](../../../feature-contracts/fp-002/FP-002_FINAL_FEATURE_PACK_CONTRACT_v0.2.0.md), [approved-in-Plane P1 proof design](../../../proof/fp-002/FP-002_TRACER_BULLET_DESIGN_CANDIDATE_v0.1.0.md).

**Interpretation:** The labels below describe **required observable semantic conditions**, **not mandated database enum values, Resource names, schema design or worker architecture**. `LOCKED` means direct governing requirement. `JIT` means the agent selects a compliant representation and proves it. Do not claim P1 implements all future lifecycle transitions.

### 3.1 Exactly one authoritative Domain for each business truth

| Consequential truth | Sole owner | Permitted interfaces / interactions | Forbidden authority crossing | Authority |
|---|---|---|---|---|
| Actor, verified Account, current Session, canonical identity and reconciliation authorisation | **Identity & Access** | Commerce/Entitlements request current authenticated actor/recipient evidence through Identity-owned APIs | Provider identity, browser inputs or payment state must not create/rewrite Identity truth | [Domain §6.1](../../../../governance/domain/04_DOMAIN_MAP_v1.2.0.md), [7B Identity review](../../../proof/fp-002/FP-002_PHASE_7B_RECONCILIATION_v0.2.0.md) |
| Accepted offer and purchase obligation, payer/recipient commercial binding, known attempt, evidence qualification, verified financial effect | **Commerce** | Owning Ash actions/code interfaces; records payment **and the mandatory durable downstream consequence in the same authoritative commit** | Entitlements, Audit, UI, browser or synthetic evidence producer cannot directly decide commercial payment truth | [Domain §6.10](../../../../governance/domain/04_DOMAIN_MAP_v1.2.0.md), [7C Payment evidence](../../../feature-contracts/fp-002/FP-002_FINAL_FEATURE_PACK_CONTRACT_v0.2.0.md) |
| Source/component-specific purchased right, `held_unconsumed`, current recipient read decision, grant idempotency | **Entitlements** | Revalidate Commerce's committed authoritative consequence and current recipient/policy; apply only through owning Ash interface | Commerce cannot write entitlement tables as a second business-write API; an Audit entry or job success is not an entitlement | [Domain §6.11](../../../../governance/domain/04_DOMAIN_MAP_v1.2.0.md), [Product §21R.1](../../../../governance/product/00_PLATFORM_v1.20.0.md) |
| Plan generation and successful delivery | **Plans** | Later governed delivery signals to Entitlements | Creation of a P1 right cannot mean a Plan has been delivered, consumed or made readable | [Product §21R.1](../../../../governance/product/00_PLATFORM_v1.20.0.md), [DEC-299](../../../../governance/product/01_DECISIONS_v1.20.0.md) |
| Pathway / clinical eligibility | **Safety & Eligibility** | Later policy decisions | P1 payment or entitlement must not manufacture clinical/safety eligibility | [7C](../../../feature-contracts/fp-002/FP-002_FINAL_FEATURE_PACK_CONTRACT_v0.2.0.md) |
| Purpose, deletion, retention restrictions | **Privacy & Consent** | Authoritative policy/owner interfaces when applicable | Retained financial history must not regenerate deleted participant access | [Domain §6.2](../../../../governance/domain/04_DOMAIN_MAP_v1.2.0.md) |
| Selected independent evidence | **Audit & Evidence** | Own append/recovery, strictly observational | Audit state cannot grant a right or apply money | [7B](../../../proof/fp-002/FP-002_PHASE_7B_RECONCILIATION_v0.2.0.md) |

**P1 simplification:** same *synthetic* verified Account is payer and recipient. Do not generalise that identity equality into production Commerce/Entitlements design. Separate payer and recipient fields/semantics must be preserved even when their values coincide in this proof.

### 3.2 P1 observable lifecycle: acceptance / purchase obligation (Commerce)

| Condition / transition | Entry guard and authority | Durable consequence | Failure, retry or terminal semantics |
|---|---|---|---|
| No accepted obligation → **accepted Plan obligation** | Current authorised verified actor, canonical recipient, fixed approved Plan version, **ZAR 39,900 minor units**, coherent immutable purchase binding | Exactly one accepted commercial intent/obligation with payer, recipient, version and value tied to the proof input | Identical acceptance replay returns the **same** obligation; changed binding or wrong actor is rejected. Scope is intentionally one Plan, not Assessment/bundle. |
| Accepted obligation → **known pending attempt** | Commerce alone binds a uniquely identifiable attempt/reference to the accepted obligation, with expected environment/integration and amount/currency | Durable attempt/reference exists before any qualification or restart | No provider dispatch exists in P1. Pending is **not** paid, failed or nonpayable. No eventual paid effect can be inferred from an unknown state. |
| Attempt evidence **unqualified / mismatched / pending** | Wrong source, actor, attempt, environment, binding, amount/currency or unqualified observation | **No** verified payment or downstream consequence; retain defensible known attempt/evidence state | Replays remain harmless; unresolved does not become success or terminal failure. A fake provider/browser signal cannot promote synthetic qualification. |
| Qualified synthetic observation → **Commerce verified payment + open durable consequence** | Synthetic producer exists in TEST only; real Commerce Ash qualification evaluates the supplied known bindings | **Same Commerce transaction commits exactly one verified payment effect and mandatory durable consequence** | No payment without consequence; before this commit both roll back together. A second equivalent apply or concurrent qualifying transaction yields no second financial effect or consequence. |
| Verified payment/consequence → downstream right outcome | Entitlements owns its own grant transition; Commerce's durable obligation survives process death | No direct cross-owner write. Obligation stays retrievable while right missing; completion evidence is owner-verifiable | The Commerce effect remains successful even if downstream grant fails; do not erase it or infer Entitlements success from a scheduler job. |

**Terminal in P1:** a *verified Commerce payment* is the completed financial effect for this bounded proof; the persisted entitlement consequence can remain **open** until applied. Refund, dispute, cancellation, provider settlement and payment reclassification are **not P1 transitions** and must not be invented here.

### 3.3 P1 observable lifecycle: purchased right (Entitlements)

| Condition / transition | Guard and actor | Side effect / visible result | Replay, terminal and exclusion |
|---|---|---|---|
| **No Plan right** before Commerce and before Entitlements commit | No authorised committed source/component grant exists | Recipient's right read denies/returns absent. Foreign Account cannot read it either. Delivered Plan content remains unavailable. | No phantom right based on browser return, evidence, pending attempt or payment projection. |
| Committed Commerce consequence → **`held_unconsumed` right** | Owning Entitlements Ash action rechecks current commercial source and current recipient/identity authority; use unique source + component identity | One durable Plan right bound to the original accepted purchase and Plan component, visible only to authorised recipient after Entitlements commit | Multiple jobs, replays, concurrent grant attempts, lost ack and fresh-process restart converge on the **same** right, not a replacement grant. |
| Right remains **held** | No governed successful Plan delivery exists in P1 | It is reserved, not consumed, delivered or silently converted; still private and current-policy checked | Do **not** expire just because information is incomplete/review pending; no content-access inference. |
| Future governed consumption / end / suspension | **Out of P1**: later Plans, Safety & Eligibility, Commerce reversal and Privacy semantics govern | Future slices must model all transition guards and compensation | P1 cannot fake delivery, consumption, refund, chargeback, final closeout, access restoration or deletion handling to satisfy its proof. |

**Terminal in P1:** `held_unconsumed` is the **intended final observation of P1**, not the global terminal entitlement state. The broader lifecycle contains consumed/ended/revoked states governed by Product §21R and DEC-299/300, but those transitions are excluded.

### 3.4 P1 observable lifecycle: durable grant consequence / recovery work

| Condition | Required durable/recovery meaning | Invalid interpretation |
|---|---|---|
| **Not committed** (failure before Commerce commit) | Zero verified payment and zero committed consequence; no right can appear | Treating transient job enqueue or callback memory as durable commitment |
| **Open consequence** (Commerce committed, Entitlements not yet committed) | Recoverable source fact survives process restart, is discoverable through the authorised durable mechanism, can be retried after failure and leads to one right | Marking the operation complete because a job was scheduled, or requiring same BEAM process to survive |
| **Right committed; acknowledgement lost** | Fresh execution finds already-created source/component right and resolves/acknowledges the original consequence without regrant | Creating a new source ID, second right or second payment |
| **Completed application** | Original obligation/right identifiers remain consistent under replay and after restart | Forgetting historical source or making reconciliation success dependent on volatile worker state |

**Guards:** Commerce source identity + immutable component, current Entitlements authorization, non-resurrection, single-writer ownership, PostgreSQL-level uniqueness/serialization sufficient for independent transactions. **Retry:** idempotent and bounded at the owning seam. **Recovery:** durable work does not disappear when executor retries are exhausted or killed. **JIT:** exact work-state enum, trigger, job queue and physical indexes remain undecided until implementation.

### 3.5 Identity reconciliation when registering Commerce and Entitlements

[Current Identity owner-review code](../../../../../lib/new_you/identity/reconciliation.ex#L541) uses an **exact registered-Domain set**; this will fail closed when the new Domains are added until Commerce and Entitlements reviews are wired in the same change. The P1 design mandates:

- **Review requested → owner-reviewed approved or conflict/unavailable:** only authorised current Identity context; each Domain returns its independent review with preserved canonical source identity, and no silent reassignment of payment/right. Unknown/missing review is denial, not implicit acceptance.
- **Approved → apply:** current owner results must still match approved snapshots. If a Domain review changes **between** approve and apply in an **independent transaction**, treat review as stale, deny transition and preserve original PMR, money and right truth.
- **Supported uncontested case → applied:** verify canonical Account, one surviving PMR, permanently retired losing PMR, preserved Communications/Audit history and commercial payer/source/right provenance. A supported non-empty case is permitted only if owner review actually authorises it; otherwise conflict/deny.
- **Conflict / stale / missing owner → no apply:** no PMR retirement, commercial reassignment, payment or entitlement effect; replay after fresh BEAM remains denied. **Applied → fresh BEAM replay:** same result, no repeated retirement/effect.

These are consequential Identity transition guards; **do not** remove the exact-Domain guard merely to make tests green. Source: [P1 design P1-07](../../../proof/fp-002/FP-002_TRACER_BULLET_DESIGN_CANDIDATE_v0.1.0.md), [existing negative regression](../../../../../test/new_you/identity/reconciliation_test.exs#L581).

### 3.6 Cross-owner sequence, cut points and invariants

1. **Identity** authenticates current synthetic payer/recipient; **Commerce** accepts a single Plan purchase, preserving immutable payer/recipient/amount/source binding.
2. **Commerce** records known pending attempt and receives *TEST-only* qualifying evidence at its actual owning interface. Rejected inputs produce no payment and no grant.
3. **Commerce atomic commit:** one qualified payment and one mandatory durable Entitlements consequence; **cut A** before commit must roll back both.
4. **Entitlements owning action:** independently reads/validates committed Commerce consequence and current policy, creates one `held_unconsumed` Plan right; **cut B** after Commerce commit/before grant leaves open durable work.
5. **Recovery:** fresh process / BEAM execution reloads persistent authority and applies right once; **cut C** after Entitlements commit/before acknowledgement must converge without duplicate effect.
6. **Recipient read:** right appears only after Entitlements commit and only to correct recipient; delivered content remains inaccessible. Every read is owner-authorised.

**Invariants across *all* cuts:** no shared-write Domain ownership; payment count ≤ 1; committed payment implies durable consequence; source/component right count ≤ 1; no delivery/consumption; no foreign read; no TEST capability in production; evidence remains distinguishable from authority. No provider-stage evidence is credited.

### 3.7 Future lifecycle concerns explicitly deferred

S1: offer version/repricing and Assessment unused-credit/annual interval/competing-admission lifecycle. E1a–c: provider attempt ambiguity, dispatched vs pending vs irreversibly nonpayable, signed ingress, single-reference repair, eventual whole-object completeness and terminal scan checkpoint. E2a–c: exact claimant/excess make-whole, refund/dispute states and guarded competing corrections; entitlement suspension/restore/end without resurrection. S2/S3: browser and Finance/Support status/role/notice decisions. These deserve their **own scope-specific lifecycle matrices** at their Ready gates. Do not pre-design future internals in P1.

**Pass-3 disposition:** Governing lifecycle semantics are complete enough for bounded P1. Missing physical state enums or database designs are JIT choices, not an upstream semantic contradiction. Add this as P1 execution/verification guidance without changing the approved P1 contract.