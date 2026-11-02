# Legal UX lifecycle contracts, working v0.1.0

**Status:** WORKING CANDIDATE / NOT LEGALLY APPROVED<br>
**Source:** `NEWYOU_LEGAL_UX_COPY_PACK_WORKING_v0.1.0`, used as a wording input only<br>
**Terms source:** `NEWYOU_PLATFORM_DIGITAL_PRODUCTS_SUBSCRIPTION_TERMS_COUNSEL_REVIEW_CANDIDATE_v0.3.3.md` / `826546419cd055bcd4710bb9f4ebd5d738d89a50874bdcc013759335d69180f6`<br>
**Privacy source:** `NEWYOU_PRIVACY_NOTICE_COUNSEL_REVIEW_CANDIDATE_v0.3.2.md` / `29e834dcbd3b2208902698ab842e965c595e3e6063e26526d845d0af8d493baa`

The source candidates are pre-counsel inputs, not current authority. Current Product v1.13.0 and DEC-316 govern where their assumptions differ. This document states semantic lifecycle requirements. It does not prescribe Resources, tables, schemas, APIs or transaction mechanisms.

## 1. Terms acceptance

**States:** `not_presented → presented → accepted → historical_superseded` for one exact Terms version.

- **Transitions:** Present the exact applicable version, then record an explicit participant acceptance of that version. A later required version needs a new acceptance event. It does not change earlier evidence.
- **Guards and invariants:** The exact version must be eligible for the registration context. Show the selected English document and do not infer acceptance from display, navigation, a default selection or acceptance of Privacy.
- **Side effects and evidence:** Identity & Access owns registration acceptance truth. It records the exact Terms version, the required registration acceptance timestamp, participant identity and Account/registration association, and interaction/preferred locale. Content & Media owns the immutable legal content version and its publication state. The legal document locale is `en`.
- **Terminal state:** The accepted event is immutable. When a later version governs new interactions, the earlier version becomes historical and remains available as evidence.
- **Authorization:** The participant explicitly accepts during their own registration. Identity validates and records the action. Browser state, support action or document publication alone cannot establish acceptance. No proxy authority is assumed here.
- **Concurrency and idempotency:** Repeating the same logical action for the same exact version has one result and no contradictory duplicate. Concurrent actions for different versions do not overwrite one another. A changed selected version requires presentation and a new explicit acceptance. A stale or ineligible version fails closed.
- **Retry and failure:** If persistence fails, the acceptance is not confirmed and registration cannot pass this gate. If the outcome is uncertain, Identity checks its durable result before retrying the same logical action. A retry cannot silently accept a newly selected version.
- **Recovery and reconciliation:** After restart or restore, if Account state and Terms evidence disagree, Identity does not treat registration as accepted or infer evidence from the UI, logs or a later version. Identity reconciles the exact accepted version and registration state while preserving prior immutable events.

## 2. Privacy Notice presentation and acceptance

Presentation and acceptance are separate meanings. Privacy acceptance is a required registration fact under Product Law. It is not consent to every processing purpose. Product Law and P8-05 require acceptance evidence for both exact legal versions, but do not set the number of participant-facing controls. The v0.3.0 copy workspace uses separate Terms and Privacy controls as a UX candidate, subject to review.

- **States:** Presentation moves `not_presented → presented`. Acceptance moves `not_accepted → accepted → historical_superseded` for one exact Privacy version. Presentation alone never moves acceptance state.
- **Transitions:** Present the selected English Privacy Notice with the applicable bilingual disclosure. Record acceptance only after the participant explicitly accepts that exact version for registration. A later required version needs a new presentation and acceptance event.
- **Guards and invariants:** The exact version must be eligible in the current context. Do not use a `latest` lookup, fallback version or translation. Production-class and applicable real-participant flows fail closed without the required approval evidence. Acceptance does not grant purpose-specific consent.
- **Side effects and evidence:** Identity & Access owns registration acceptance truth. It records the exact Privacy version, the required registration acceptance timestamp, participant identity and Account/registration association, and interaction/preferred locale. Content & Media owns the immutable legal content version and its publication state. The legal document locale is `en`. A presentation record, if required by an applicable contract, remains distinct from acceptance evidence.
- **Terminal state:** The accepted event for an exact version is immutable. A later version does not rewrite or imply acceptance of the earlier or later version.
- **Authorization:** The participant explicitly accepts during their own registration. Identity validates and records the action. A browser display, Privacy Notice presentation, support action or purpose-specific consent cannot establish Privacy acceptance. Privacy & Consent owns purpose-specific permission, not this Identity registration fact.
- **Concurrency and idempotency:** Replaying the same logical acceptance for the same exact version has one result. Repeating presentation has no acceptance effect. A changed version requires presentation and fresh explicit acceptance. Conflicting or stale version actions fail closed and do not use last-write-wins behavior.
- **Retry and failure:** If the Notice cannot be presented, no acceptance can be recorded. If acceptance persistence fails, registration cannot pass this gate. For an uncertain outcome, Identity checks durable evidence before retrying the same exact action. A version that becomes ineligible before acceptance is rejected.
- **Recovery and reconciliation:** After restart or restore, Account state must agree with both exact acceptance references. If Privacy evidence is absent, mismatched or uncertain, Identity does not infer acceptance from presentation, browser state, logs or purpose consent. Registration remains unaccepted until Identity reconciles the durable evidence.

## 3. Purpose-specific consent

**States:** `not_granted → granted → withdrawn`. A later grant after withdrawal is a new event and version. Expiry or supersession applies only where the governing purpose contract defines it.

- **Transitions:** Grant or withdraw permission for one named processing purpose and scope. A new grant after withdrawal requires a new explicit participant action.
- **Guards and invariants:** When consent is the required mechanism, bind the action to the exact purpose, scope, approved wording/version and required information. Do not infer consent from Terms or Privacy acceptance, Account creation, payment or use of a feature. Do not preselect affirmative consent.
- **Side effects and evidence:** Privacy & Consent is the sole owner of purpose-specific grant and withdrawal truth. A dependent Domain checks current permission before processing and continues to own its underlying records. Record evidence required by the governed purpose contract.
- **Terminal state:** A withdrawn grant cannot authorize future consent-dependent processing. A new grant is a separate event; it does not erase the withdrawal history.
- **Authorization:** The participant must take the explicit action unless current law defines another valid actor. A staff or support action cannot create or restore permission without governed authority.
- **Concurrency and idempotency:** Replaying the same grant or withdrawal for the same scope is idempotent. The Privacy & Consent owner orders competing actions. If their order cannot be established, do not treat permission as current until reconciliation. A committed withdrawal blocks later dependent work at the governed boundary.
- **Retry and failure:** If grant persistence fails or is uncertain, do not begin consent-dependent processing. If withdrawal persistence is uncertain, hold dependent processing while the owner checks the result. A retry uses the same logical action; restoring permission requires a new explicit grant.
- **Recovery and reconciliation:** After restart or restore, Privacy & Consent re-establishes current grant/withdrawal state from its durable evidence before dependent Domains proceed. Missing, conflicting or stale evidence does not create a grant.

## 4. Marketing permission and channel preferences

Marketing-purpose permission and Communications channel/category preferences are separate durable truths with separate owners.

- **States:** Purpose permission moves `not_granted → granted → withdrawn`; a later grant is a new event. Each channel/category preference moves between its governed active, paused or changed states.
- **Transitions:** Privacy & Consent grants or withdraws purpose-level marketing permission. Communications changes only the selected channel/category preference. A channel opt-out does not withdraw purpose permission, and a preference change never creates or restores it.
- **Guards and invariants:** Require an explicit, scoped participant action. A broad purpose withdrawal suppresses optional marketing across channels. National suppression and opt-out obligations remain independently effective.
- **Side effects and evidence:** Privacy & Consent owns purpose permission and withdrawal. Communications owns subscriber contacts and channel/category preferences. Delivery checks both current truths. Record each action against its owner and scope.
- **Terminal state:** Withdrawal ends current purpose permission. A later grant needs a fresh participant action. A channel preference remains independently changeable and cannot bypass a purpose withdrawal.
- **Authorization:** The participant acts on the named permission or preference. Privacy & Consent and Communications accept commands only through their respective owner boundaries. A support or delivery action cannot grant permission.
- **Concurrency and idempotency:** Replaying an identical action is idempotent. A channel change concurrent with purpose withdrawal cannot restore purpose permission. Where action order is uncertain, optional marketing remains suppressed until both owners reconcile their state.
- **Retry and failure:** If a permission or preference update is not confirmed, do not send optional marketing while the relevant state is uncertain. Retry the same logical action through its owner. A preference retry cannot recreate withdrawn purpose permission.
- **Recovery and reconciliation:** After restart or restore, Privacy & Consent restores purpose permission state and Communications restores preference state. Before delivery resumes, reconcile both records. A withdrawal must remain effective across restore and cannot be overridden by a channel preference.

## 5. Cookie choices

**States:** `unresolved → necessary_only` or `unresolved → optional_configured`. A later change requires a new participant choice. Any expiry or renewed-choice rule must come from an approved policy.

- **Transitions:** Offer only categories in the verified deployed technology inventory. Apply the participant's choice to those categories; never treat a newly deployed provider or purpose as already covered by an older choice.
- **Guards and invariants:** Necessary technologies are not reclassified as optional for UI convenience. Optional technologies remain off until the applicable approved model permits them. If inventory, purpose or legal classification is unknown, do not enable the optional category.
- **Side effects and evidence:** The approved technology/purpose inventory identifies whether a category uses a participant preference or requires consent. Privacy & Consent owns consent truth where consent is the required basis. Current authority does not name a separate owner for cookie-category preference; an applicable approved contract must name that owner before the preference is persisted or applied. Technical configuration or browser state does not create consent evidence.
- **Terminal state:** A choice applies only to its governed inventory and version. A material purpose/provider/category change requires review and, where required, a new choice. Earlier evidence remains unchanged.
- **Authorization:** The participant makes the choice through the applicable approved flow. The named owner validates and records it. Deployment or support operators cannot manufacture participant choice. If the inventory, purpose or required owner is unresolved, optional technologies remain disabled.
- **Concurrency and idempotency:** Replaying the same choice for the same inventory version is idempotent. A new explicit choice supersedes the current preference without rewriting history. Stale controls cannot broaden a later choice. If order is uncertain, optional technologies stay off.
- **Retry and failure:** If saving the choice fails or its outcome is uncertain, do not enable optional technologies. Re-read the owner state before retrying the same choice. Missing inventory or approval evidence fails closed.
- **Recovery and reconciliation:** After restart or restore, compare the current choice with the approved inventory and current owner evidence before enabling optional technologies. Missing or mismatched evidence leaves optional technologies disabled until reconciled.

## 6. Practitioner sharing

**States:** `not_granted → active → revoked` or `active → expired` for one grant instance. A later relationship or renewed permission creates a new grant.

- **Transitions:** Activate sharing only for the exact practitioner/practice, information scope, purpose and duration. Revocation ends future sharing under that grant. Expiry applies only when its approved condition is met.
- **Guards and invariants:** Require current permission for the exact share scope and a valid target relationship. Revocation does not automatically erase records already lawfully created or records another Responsible Party must retain.
- **Side effects and evidence:** Privacy & Consent owns the purpose-specific share permission. The target business Domain owns its relationship and records. The receiving Domain checks current permission before each governed access or share.
- **Terminal state:** `revoked` and `expired` grants cannot authorize later sharing. A later relationship or new permission does not revive the old grant.
- **Authorization:** The participant with authority over the relevant information grants or revokes permission. No support, practitioner or operator action can manufacture participant consent.
- **Concurrency and idempotency:** Repeating the same grant or revocation is idempotent. A changed practitioner, scope, purpose or duration requires a new grant. Once revocation is durable, new sharing is denied. If grant/revocation order is uncertain, deny new access until Privacy & Consent reconciles it.
- **Retry and failure:** Do not share without confirmed active permission. If revocation persistence is uncertain, hold new access while the owner checks the durable result. Retrying an accepted revocation does not restore the grant.
- **Recovery and reconciliation:** After restart or restore, re-establish current Privacy & Consent permission and the target Domain's relationship state. Missing, expired, revoked or conflicting evidence fails closed. Do not revive a grant from a cached relationship or old UI state.

## 7. Early-performance instruction

**States:** `not_given → given → historical` for one exact order, SKU and instruction version.

- **Transitions:** Use only for a specific transaction after authorised counsel confirms the instruction is legally relevant. The participant gives the exact instruction before the applicable early performance begins. Preserve the order and instruction version it covers.
- **Guards and invariants:** Exact SKU classification and consequences follow legal/commercial authority. The instruction cannot be inferred from Terms acceptance, Privacy acceptance, payment, Account creation or opening content. It does not change cancellation rights beyond governing law.
- **Side effects and evidence:** Commerce owns the order-linked instruction evidence and checks it before early performance. The copy record alone does not authorize service start or decide cancellation consequences.
- **Terminal state:** The instruction remains immutable historical evidence for that order/SKU/version. A different order, SKU or instruction version needs a new applicable action.
- **Authorization:** The participant with authority over the order gives the explicit instruction. Counsel classification establishes whether the instruction is needed; it does not act for the participant.
- **Concurrency and idempotency:** Replaying the same logical instruction for the same order/SKU/version is idempotent. A changed SKU or instruction version requires fresh presentation and instruction. Conflicting versions do not overwrite one another or authorize performance by last-write-wins.
- **Retry and failure:** Do not begin early performance without confirmed instruction evidence where the approved classification requires it. If persistence is uncertain, Commerce checks the exact order/version before retrying. Missing or ineligible evidence leaves the default governed order treatment in place.
- **Recovery and reconciliation:** After restart or restore, Commerce reconciles the order, SKU and instruction evidence before early performance continues. Missing or mismatched evidence cannot be reconstructed from payment or content access; hold the early-performance path until resolved.
