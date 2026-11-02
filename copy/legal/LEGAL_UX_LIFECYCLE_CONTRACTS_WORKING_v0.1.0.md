# Legal UX lifecycle contracts — WORKING v0.1.0

**Status:** WORKING CANDIDATE / NOT LEGALLY APPROVED<br>
**Source:** `NEWYOU_LEGAL_UX_COPY_PACK_WORKING_v0.1.0`<br>
**Source pack SHA-256:** `3db06cc3a9faa23f90cf8439afba6afcaaf5c75c65bb0590f96cd4d85d755dfb`<br>
**Terms source:** `NEWYOU_PLATFORM_DIGITAL_PRODUCTS_SUBSCRIPTION_TERMS_COUNSEL_REVIEW_CANDIDATE_v0.3.3.md` / `826546419cd055bcd4710bb9f4ebd5d738d89a50874bdcc013759335d69180f6`<br>
**Privacy source:** `NEWYOU_PRIVACY_NOTICE_COUNSEL_REVIEW_CANDIDATE_v0.3.2.md` / `29e834dcbd3b2208902698ab842e965c595e3e6063e26526d845d0af8d493baa`


These are semantic lifecycle requirements, not Ash Resource/table/schema prescriptions.

## 1. Terms acceptance

**States:** `not_presented → presented → accepted → historical_superseded` for one exact Terms version.

- **Transitions:** present exact context-eligible version; accept that presented version; later mark historical when a successor governs future interactions.
- **Guards:** exact eligible Terms version and correct interaction context.
- **Side effects/evidence:** preserve exact version reference, time, actor/Account association and interaction locale.
- **Terminal:** `historical_superseded` for that accepted version; history remains immutable.
- **Concurrency/idempotency:** replay of the same registration must not create contradictory duplicate acceptance; changed version/input requires a new valid action.
- **Recovery:** a later Terms version never rewrites prior acceptance evidence.

## 2. Privacy Notice presentation / acknowledgement

**States:** `not_presented → presented → acknowledged` where acknowledgement is selected. A later Notice version creates separate presentation evidence.

- **Guard:** acknowledgement is not purpose-specific consent.
- **Side effects/evidence:** retain exact Notice version and applicable presentation/acknowledgement evidence.
- **Terminal:** historical evidence for the exact version; a new Notice does not rewrite it.
- **Recovery:** missing evidence is not reconstructed by assuming the participant must have seen a later/current Notice.

## 3. Purpose-specific consent

**Current-state model:** `not_granted → granted → withdrawn`; any later grant after withdrawal is a new grant event/version, not mutation of the old evidence.

- **Guards:** exact purpose, approved wording/version, eligible actor, required information shown, no implicit/pre-ticked inference where affirmative consent is required.
- **Side effects:** dependent processing starts only after valid grant where consent is the required mechanism; withdrawal stops affected future processing unless an independent lawful basis applies.
- **Terminal for one grant:** `withdrawn`, `expired`, or `superseded` as applicable.
- **Authorization:** only the owning Privacy & Consent interface can establish current permission truth; browser state/support roles cannot manufacture it.
- **Concurrency/idempotency:** repeated identical actions do not create contradictory current state.
- **Retry/recovery:** support may not reactivate withdrawn permission; a new valid participant action is required where a new grant is needed.

## 4. Marketing permission and channel preferences

Purpose-level marketing permission and channel/category preferences are separate authorities.

- Withdraw all marketing permission → suppress dependent optional marketing across channels to the extent governed by that permission.
- Channel/category preference changes → change only those preferences; they never create or restore purpose-level permission.
- National suppression/opt-out obligations, when applicable, remain independently non-bypassable.

## 5. Cookie choices

**States:** `unresolved → necessary_only` or `unresolved → optional_configured`; later movement between `necessary_only` and `optional_configured` follows a new participant choice.

- Necessary technologies are not reclassified as optional for UI convenience.
- Optional technologies remain off until the applicable choice where the approved model requires prior choice.
- Material provider/purpose/category change requires version/review handling; old choice is not silently broadened.
- Recovery after lost optional-preference evidence is conservative: do not infer an unprovable optional grant.

## 6. Practitioner sharing

**States:** `not_granted → active → revoked` or `active → expired`.

- **Guards:** exact practitioner/practice, scope, purpose and duration.
- **Terminal:** `revoked` and `expired` for that grant instance.
- **Recovery:** a later relationship creates a new grant/version, never revival of old evidence.

## 7. Early-performance instruction

**States:** `not_given → given → historical` for the exact order/SKU/instruction version.

- Cannot be inferred from Terms acceptance, Privacy acknowledgement, payment, Account creation or opening content.
- Immutable once relied upon for that order/SKU.
- Legal/commercial authority determines cancellation consequences; the UX record alone does not.
