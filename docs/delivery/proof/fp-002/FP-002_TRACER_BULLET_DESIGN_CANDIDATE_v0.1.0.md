# FP-002 bounded tracer bullet proof design

- **Document version:** v0.1.0
- **Status:** Candidate for accountable-human approval after classification. Execution and certification are pending.

## P1 claim and allowed execution

One synthetic verified Account is both payer and recipient. Accept one standalone Plan price version at `39900` ZAR minor units, persist one known attempt and pass one qualified synthetic observation through the real Commerce owning Ash interface. The evidence must traverse real qualification and application checks. Commerce performs one authoritative payment application. Entitlements recovers and applies one right for the original purchase and Plan component in `held_unconsumed`.

Demonstrate that the recipient can read the purchased right after the Entitlements commit. Before the commit and for a foreign Account, deny that right. The paid and granted case still has no successful Plan delivery, no consumption and no authority to view delivered Plan content. Assert those facts explicitly. Safety assessment, Plan generation and delivery are outside the proof. See Product §21R.1 and DEC-299 through the [7C contract](../../feature-contracts/fp-002/FP-002_FINAL_FEATURE_PACK_CONTRACT_WORKING_v0.1.0.md).

Use PostgreSQL, the real owning Ash actions and the existing supervision and durable execution facilities where needed. The synthetic evidence producer belongs in TEST-only source. Production builds exclude the producer and any fixture capability. No public endpoint, runtime switch, participant field, browser status, forged provider input or fixture header can qualify this evidence. Test ordinary input rejection and production compilation exclusion. P1 uses no Paystack network, SDK, credentials, hosted checkout or external effect. It does not depend on WELL-176.

## P1 cases and durable observations

| Case | Required observation |
| --- | --- |
| P1-01 Acceptance and evidence | Same accepted input replays the same purchase. Changed binding or unauthorised actor cannot accept again. Pending, unqualified or mismatched attempt, integration/environment, amount or currency produces no payment or right. |
| P1-02 Duplicate and concurrent application | Two independent PostgreSQL transactions applying equivalent qualified evidence converge on one payment, one consequence and one right. Direct unauthorised grant and foreign right reads fail. The right remains held and unconsumed on replay. |
| P1-03 Failure before Commerce commit | Observe zero payment application and zero durable payment consequence after rollback. No right or use of delivered Plan content is available. |
| P1-04 Failure after Commerce commit and before Entitlements apply | Fresh execution reloads the committed obligation. Access remains absent until the owning entitlement action applies the held right. Exactly one right exists afterward. |
| P1-05 Failure after Entitlements commit and before acknowledgement | Fresh retry observes the original held right and converges to a completed consequence. There is no new grant, delivery or consumption. |
| P1-06 Production exclusion | Build with production settings and verify the TEST evidence producer is unavailable. Browser/provider fixture data cannot satisfy qualification through ordinary inputs. |
| P1-07 Identity reconciliation | Pass all positive, negative and restart cases below in the change that first registers either Domain. |

## Identity registration and reconciliation

The current `owner_reviews/1` in `lib/new_you/identity/reconciliation.ex` checks the exact registered Domain set. Approval binds the review results, and apply compares the approved results to current owner results. Preserve the fail-closed guard. Register each new Domain only with its owning review in the same change.

- An authorised existing FP-001 empty-scope case still approves and applies after registration. Assert the surviving canonical Account, one active PMR, retirement of the losing PMR and preserved Communications and Audit provenance.
- Test a supported uncontested history-preservation case if covered by the approved owners' review scope. Preserve the original payer, accepted purchase and right source. Unsupported nonempty cases produce conflict. Identity does not write payment or access state or invent reassignment authority.
- For an unknown Domain, unavailable owner review, mismatched pair, owner conflict or owner change between approval and apply, deny the affected transition. Change owner state in a separate transaction to prove the stale case. Assert no PMR retirement or successful financial or access effect. Preserve and run the existing unreviewed-Domain regression in `test/new_you/identity/reconciliation_test.exs`.
- Fresh BEAM recovery of an applied case preserves provenance and replays the bound result without repeat retirement or effect. Fresh recovery of a conflict still denies apply.

## Certification and S1 entry

P1 certification covers the exact synthetic candidate, fixture isolation, recorded commit cuts, independent database transactions and Identity regression. It promotes zero Paystack manifest slots. It does not certify complete FP-002 Phase 8 or open ordinary vertical-slice development.

The requested approval for S1 is an **explicit bounded Phase 8 continuation** after independent P1 certification. It covers offer/admission and recipient/credit interlocks on NewYou with synthetic evidence. It does not include provider dispatch, public release, genuine bundle activation or downstream Assessment delivery. The continuation needs exact design approval, approved acceptance and a separately dependency-cleared Ready ticket. If the accountable approval does not include S1, keep S1 non-executable until the applicable ordinary-slice architectural proof gate is separately satisfied.

E1b independently schedules and recovers known pending references without browser, webhook or E1c. E1c verifies broader cross-object scan completeness. E1 and E2 provider tests must cite accepted exact-stage receipts and obtain separate scoped operational authorisation. The [implementation and publication plan](../../execution/fp-002/FP-002_IMPLEMENTATION_AND_TICKET_PLAN_CANDIDATE_v0.1.0.md) contains the dependency and evidence map.
