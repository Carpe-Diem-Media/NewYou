# Proposed recovery-message classifications

Status: `PROPOSED_NON_AUTHORITATIVE`. These are review proposals under WELL-16, not amendments to Product Law or the Decision Register. No classification, wording, token binding or delivery eligibility is approved by this file. Existing Product v1.15.0 §§21E.19 and 21E.23 remain current and exclude these purposes from verification/password-reset approvals.

## Account recovery proof message

Propose the narrow Product content type `account_recovery_proof_message` for an email carrying current, Identity-issued, purpose-bound proof for an existing graduated RecoveryCase. It maps only to the existing Communications role `account_recovery`. The message invites the claimant to the explicit confirmation step. Opening, scanning, previewing or delivering it cannot consume proof, establish claimant assurance or complete recovery.

This type does not cover password reset, magic login, address verification, primary-email change, manual identity verification, hold placement/release, recovery completion notices or general transactional messages. It cannot approve an authentication method or a recovery exception.

## Account recovery completion notice

Propose the separate narrow Product content type `account_recovery_completion_notice` for the security notice established by Identity's committed successful recovery completion. It maps only to the existing Communications role `recovery_security_notice` for that completion. It describes the completed password change and Session/Device invalidation consequences. It must not imply that a separate security hold was released or that the claimant is now signed in.

This type does not cover requests, pending or failed recovery, cancellation, expiry, escalation, hold placement/release, ordinary password changes, password resets, reconciliation or unrelated security events. No new recovery effect can be inferred from notice delivery, failure or provider observations.

## Risk and ownership proposal

Both are Class A identity/security copy under the existing copy-governance rules, with `identity_security` content risk. Recommend `editorial_low_risk` for the bounded wording only, subject to an explicit Product decision. Identity security risk remains HIGH. The recommendation does not lower the assurance, privileged-access, current-authority, E1/E2, confidentiality or concurrency requirements.

Content & Media would own exact ContentItem/ContentVersion/ContentTranslationVersion identities and immutable EN/AF bytes. The IDs in the candidate packet are proposals, not issued Content authority. Identity continues to own Account, case, proof, credentials, Sessions and Devices. Communications continues to own intents, delivery attempts and current delivery eligibility. Audit continues to own selected evidence. No capability, consent, entitlement or other Domain authority is transferred or created.

## Proposed bounded development eligibility

Request accountable Product decisions for each exact type, wording risk and scope, followed by Content & Media decisions bound to each exact EN/AF version, format, byte length, SHA-256 digest and typed token contract. Request separate English and Afrikaans language reviews for each message. These review requirements are proposed for this extension; existing verification/reset decisions do not satisfy them.

Proposed applicability is limited to local development, automated tests, development environments and bounded P8-15 Phase-8 proof after approval. Candidate inspection and drafting are authorised now; sending or binding candidate content is not. Production, public release, paid pilots, real-participant delivery and Phase 9 remain prohibited. This proposal supplies no runtime role grant, sender/provider approval, publication or release authority.

The literal `{{account_recovery_link}}` may resolve only through current Identity proof authority and an approved protected confirmation route. No raw bearer or rendered link belongs in content evidence, ordinary fields, logs, telemetry, Audit, Analytics or job arguments. The non-secret `{{support_contact}}` requires an exact accountable-owner-approved support contact before any use; no address, endpoint or support availability is invented here.

Propose paired EN/AF eligibility for each purpose, exact IDs rather than `latest`, no silent locale fallback and current eligibility revalidation before new use. Decisions must be attributable and append-only. Identical exact-bound replay is idempotent; changed decision reuse or conflicting evidence stops use for reconciliation. Changed locale bytes require a successor locale version and fresh review. Superseded or withdrawn versions remain terminal for new use and retain their history. Content approval alone must not activate runtime delivery; implementation and security proof remain required.

Product and Content owners must resolve and record these proposals through their authorised upstream track. This implementation branch changes no governing document, current router or approval packet. The separate proof-independent claimant-verification decision is outside these message classifications.
