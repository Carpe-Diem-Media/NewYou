# Proposed Product Law amendment v1.15.0

**Status:** PROPOSED / NON-AUTHORITATIVE / OWNER DECISION PENDING

The current governance router continues to select Product Law v1.14.0. This proposal is not current law. Its predecessor is `docs/governance/product/00_PLATFORM_v1.14.0.md`, SHA-256 `bcec310103319441d12c6efae1c7c779a013a503b3831da630abb4a55187314b`.

## Proposed §21E.23 Password-reset message classification

Add `password_reset_message` to the controlled catalogue in §21E.3. It covers only the participant-facing email that carries Identity-issued, purpose-bound proof for resetting an existing Account password. It does not classify password-reset pages or forms, recovery-case communications, password-change notices, address verification, magic-link sign-in, primary-email changes, marketing, safety, practitioner or entitlement messages. It is not a general transactional-message type.

Recommend `editorial_low_risk` for wording only, subject to an explicit Product-owner decision. The wording gives a participant a route to an Identity-owned password-reset action. It does not establish identity, issue or consume proof, change credentials or Sessions, or decide whether a reset succeeds. Identity authentication and security risk remains HIGH. This candidate proposes Class A with `identity_security` content risk; that copy classification does not replace the proposed Product wording classification. The exact message keys remain outside the P8-05 pinned runtime copy registry until separately approved and integrated.

Content & Media owns the `ContentItem → ContentVersion → ContentTranslationVersion` identities, exact locale bytes and development-eligibility decisions. Identity & Access owns password-reset proof, Account and credential state, and Session consequences. Communications owns the `MessageIntent`, delivery attempts and current delivery decisions. Audit & Evidence owns selected evidence of source outcomes. This classification transfers none of those boundaries.

## Proposed §21E.24 Bounded P8-12 development content eligibility

Eligibility is limited to local development, automated tests, development environments and bounded P8-12 Phase-8 proof. Production, public release, paid pilots, real-participant delivery and Phase 9 are prohibited. This proposal grants no runtime Content role, publication, sender/provider permission, password-reset implementation permission or release authority.

Use `candidate → development_approved → superseded | withdrawn`. Candidate content is ineligible. `candidate → development_approved` requires the approved Product extension to be current, an attributable Product-owner decision for the exact type, wording risk and scope, and a separate Content & Media owner decision for each exact EN and AF locale version, including its immutable identities, bytes, digest, token contract and applicability. Required review evidence must be complete, current and conflict-free. WELL-98 status, repository authorship, implementation permission, GitHub merge and approval of another message type do not satisfy these decisions.

Bind each decision to exact `ContentItem`, `ContentVersion` and `ContentTranslationVersion` identities, locale, format ID, byte count, SHA-256 digest, typed literal token allowlist and applicability. Both locales are required for the paired message. Use no `latest` alias or silent locale fallback. A missing, stale, contradictory, withdrawn, superseded or mismatched decision fails closed. Re-read current eligibility before new use; a queued message or cached artifact does not preserve eligibility after withdrawal.

Record decisions and lifecycle events append-only. Reapplying the same decision to the same immutable version, locale, digest, token contract and scope is idempotent. Reusing a decision ID with a different binding, or conflicting decisions for one immutable identity, stops new use pending an explicit owner reconciliation event that refers to every conflicting event. Never use last-write-wins. Changed bytes require a new locale-version identity and fresh approval; a changed shared structure requires a successor `ContentVersion`. Supersession requires an immutable successor. `superseded` and `withdrawn` are terminal for new use and preserve historical bytes and evidence.

Any runtime, release or production use requires separate applicable Product and Content & Media governance, actual role/scope decisions, release evidence and the owning Domains' authorization. This proposal grants none of them.
