# WELL-157 bounded primary-email-change applicability proposal v0.1.0

Status: PROPOSED_NON_AUTHORITATIVE. No owner approval is recorded for this proposal. It changes no current law, Content eligibility, route or runtime behavior.

This proposal is the prerequisite for WELL-156, the ordinary bilingual primary-email-change journey. WELL-156 remains Blocked. WELL-157 is Planning and permits this proposal preparation only.

The inspected baseline is `8d96b16ca56296d03485fdb80ab93ac35edc63eb`. The current [Product](../../00_PLATFORM_v1.18.0.md) and [Decisions](../../01_DECISIONS_v1.18.0.md) remain authoritative. [Exact bindings](EXACT_BINDINGS_v0.1.0.json) identifies the four unchanged email versions and their existing historical evidence. That inventory is a decision target, not an eligibility packet or an approval record.

## Why an owner decision is required

Product §21E.28 says: "Production, publication, public release, paid pilot, real-participant delivery and Phase 9 are prohibited."

DEC-324 says: "No production, publication, real-participant, paid-pilot, provider, sender, runtime or Phase 9 authority is granted."

Product §21E.29 and DEC-325 make an exception exclusively for WELL-136 password reset. They do not cover primary-email changes. The integrated [browser-copy packet](../../../../delivery/content-evidence/copy/evidence/FP001_PRIMARY_EMAIL_CHANGE_PHASE9_BROWSER_COPY_APPROVED_v0.1.1.json) approves browser strings and expressly excludes Phase-9 email-message use.

No controller, Ash mechanism, context flag or unchanged message digest can enlarge an explicitly prohibited consumption context. The missing durable semantic is permission to consume these exact messages in the named WELL-156 non-production Phase-9 context. Account ownership, lifecycle mechanisms, schemas and ordinary UI composition need no new Product decision.

## Exact proposed Product addition

The following section is proposed for a current Product successor. Its number is §21E.30 at the inspected baseline. Preserve every existing section, including the historical scope of §§21E.27–21E.29. Reconcile numbering against current main before promotion without changing approved semantics.

### 21E.30 WELL-156 bounded Phase-9 primary-email-change message applicability

Notwithstanding the Phase-9 prohibition in §21E.28, the existing `primary_email_change_confirmation_message` and `primary_email_change_old_address_notice` versions listed below may become eligible for consumption exclusively within WELL-156's ordinary primary-email-change journey in local development, automated tests, development environments and bounded non-production FP-001 Phase-9 verification.

The confirmation message retains these immutable identities:

- ContentItem `NEWYOU-CONTENTITEM-PRIMARY-EMAIL-CHANGE-CONFIRMATION-MESSAGE-EMAIL`.
- ContentVersion `NEWYOU-CONTENTVERSION-PRIMARY-EMAIL-CHANGE-CONFIRMATION-MESSAGE-EMAIL-V1`.
- English ContentTranslationVersion `NEWYOU-CONTENTTRANSLATIONVERSION-PRIMARY-EMAIL-CHANGE-CONFIRMATION-MESSAGE-EMAIL-EN-V1`, 454 UTF-8 bytes, SHA-256 `225434e7cbdb52d7ea9a092927acbc8b9acde9a07b89f2572b633b3eb8b63ae5`.
- Afrikaans ContentTranslationVersion `NEWYOU-CONTENTTRANSLATIONVERSION-PRIMARY-EMAIL-CHANGE-CONFIRMATION-MESSAGE-EMAIL-AF-V1`, 498 UTF-8 bytes, SHA-256 `be8a5049931e2a942c88fa4159715e0c0c460b55879a3d6b7a780d4f7f26e204`.

The old-address notice retains these immutable identities:

- ContentItem `NEWYOU-CONTENTITEM-PRIMARY-EMAIL-CHANGE-OLD-ADDRESS-NOTICE-EMAIL`.
- ContentVersion `NEWYOU-CONTENTVERSION-PRIMARY-EMAIL-CHANGE-OLD-ADDRESS-NOTICE-EMAIL-V1`.
- English ContentTranslationVersion `NEWYOU-CONTENTTRANSLATIONVERSION-PRIMARY-EMAIL-CHANGE-OLD-ADDRESS-NOTICE-EMAIL-EN-V1`, 327 UTF-8 bytes, SHA-256 `937b7aa3fb0018f12157946c7ace16d30503ddba8ab52f2a446cff98a1505abc`.
- Afrikaans ContentTranslationVersion `NEWYOU-CONTENTTRANSLATIONVERSION-PRIMARY-EMAIL-CHANGE-OLD-ADDRESS-NOTICE-EMAIL-AF-V1`, 369 UTF-8 bytes, SHA-256 `6effc50c65c2e592ac237984b236f3d4aa1723f92378268d424fc05810571f3e`.

All four versions retain their exact approved subject/body bytes, `subject-body-utf8-lf-v1` format, typed literal token contracts, Communications roles and historical Product, Content and language approval records. Confirmation permits only `{{platform_name}}` and `{{email_change_confirmation_link}}`. The notice permits only `{{platform_name}}` and `{{support_contact}}`, with their existing types and field restrictions. No `latest` alias, locale fallback, replacement text or generic transactional-message classification is authorized.

This exception permits an applicability extension. It does not itself approve any version for the additional context. Before new consumption, an attributable Product-owner decision must approve the exact exception, and Content & Media must record separately attributable applicability decisions for confirmation EN V1, confirmation AF V1, old-address notice EN V1 and old-address notice AF V1. Each decision binds the immutable identities, locale, exact bytes and byte count, message digest, format, typed-token contract digest and the WELL-156 context. Both locales are required for each purpose.

Existing English and Afrikaans language reviews remain evidence for unchanged text. They do not constitute approval of an additional consumption context. Changed wording or token contracts require new immutable versions and fresh applicable owner and language decisions.

Record the applicability decisions append-only in a successor Content evidence packet. Preserve the existing P8-16 packet and approval history byte for byte. The lifecycle remains `candidate → development_approved → superseded | withdrawn`. Historical Phase-8 permission retains its original meaning.

Every new consumption and queued use must recheck current Product and Content applicability, exact context, version, locale, message and token-contract digests, and withdrawal/supersession status. Missing, stale, changed, withdrawn, superseded, mismatched or conflicting evidence fails closed. Identical exact-bound decisions may replay idempotently. Conflicting decisions require explicit owner reconciliation and never resolve by last-write-wins. Queued work retains no eligibility after withdrawal.

Account remains the sole owner of current primary-email-change truth under §21J.8 and DEC-251. Identity owns request, reauthentication, proof, guarded apply, cancellation and security consequences. Communications owns message intent, attempts and provider outcomes. Content owns exact message version and use eligibility. Audit owns evidence. Delivery, callbacks, Content approval and Audit cannot confirm or apply Identity truth. Confirmation alone never changes canonical email.

This exception permits only the named non-production development consumption. It does not authorize production builds or production eligibility, publication, public release, paid pilots, real participants, real-participant delivery, live email delivery, external senders/providers, general-purpose runtime Content-role activation, new authentication or support grants, new recovery methods, legal/privacy approval, or FP-001 completion.

The `{{support_contact}}` token remains unbound. Delivery remains disabled. Any future contact binding requires owner approval and operational verification and does not itself authorize external delivery. This exception grants neither permission.

WELL-156 may enter Ready only after approved Product/Decision integration and current routing, exact Content applicability evidence reconciliation, live dependency clearance and independent pre-dispatch review against current main. The exception is not implementation dispatch or merge authorization.

## Exact proposed Decision addition

The following is proposed for a current Decision successor as DEC-326 at the inspected baseline. It is not LOCKED or effective in this proposal.

### DEC-326 WELL-156 primary-email-change bounded Phase-9 development exception

For WELL-156 alone, permit the narrow non-production Phase-9 applicability exception described in Product §21E.30 for the existing confirmation and old-address-notice EN V1 and AF V1 versions. This supersedes the Phase-9 prohibitions in §21E.28 and DEC-324 only for that exact additional context. Those provisions remain operative in all other contexts.

An attributable Product-owner decision and four separately attributable Content & Media applicability decisions are required before consumption. Bind exact immutable identities, locale bytes/counts, message and typed-token digests, format, roles and context. Preserve prior approvals and unchanged language-review evidence without enlarging their historical meaning.

Use append-only successor eligibility evidence. Recheck current applicability and withdrawal/supersession at every new or queued use; missing, stale, mismatched or contradictory evidence fails closed. Identical decisions are idempotent; conflicts require explicit owner reconciliation. No locale fallback or `latest` resolution is permitted.

Identity, Content, Communications and Audit retain their current ownership. Confirmation does not apply the change. The notice does not approve, veto or undo it. Delivery remains disabled and `{{support_contact}}` unbound.

No production/build eligibility, publication, public release, paid pilot, real-participant use, live delivery, external sender/provider activation, general-purpose runtime Content-role grant, broader Phase-9 authority or release permission is granted.

WELL-156 remains non-executable until the integrated successor, reconciled exact Content evidence, resolved dependencies and independent current-main Ready gate are evidenced.

## Decisions requested and promotion

The Product owner is asked to approve the exact two proposed sections above for WELL-156. Content & Media is asked for four separate applicability decisions against [the exact binding inventory](EXACT_BINDINGS_v0.1.0.json), one for each message and locale. A person holding multiple capacities must identify each decision separately. No new wording or language-review approval is requested for the unchanged versions.

No decision is recorded by this document. Record actual owner decisions with attributable source events and exact proposal/binding digests. Do not fill a pending approval from an agent recommendation, prior Phase-8 decision, browser-copy approval or GitHub author identity.

After those decisions, a separate governance change must preserve predecessor bytes, add current-version Product/Decision successors, route their exact digests, and append the exact context-bound Content applicability evidence. Verify the current-law readers and positive/negative eligibility checks. Obtain independent governance Master Gate, exact-head hosted CI, authorized integration and resulting-main proof. Only then recheck WELL-156 for Ready. Do not promote this proposal by changing its status in place.

Documentation impact: this is a non-executable decision proposal. It introduces no capability, interface, schema, lifecycle implementation or runtime consumer, so the existing primary-email-change capability map is unchanged. Its update belongs with the later application slice.
