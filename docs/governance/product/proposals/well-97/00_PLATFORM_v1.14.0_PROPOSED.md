# 00_PLATFORM v1.14.0 proposed successor

- **Document status:** PROPOSED / NON-AUTHORITATIVE
- **Document version:** v1.14.0
- **Predecessor:** `docs/governance/product/00_PLATFORM_v1.13.0.md`
- **Predecessor SHA-256:** `eac45fab280eaa157bb3e3268463f879c1c09648566c5c84a900bcbc25215413`
- **SemVer transition:** v1.13.0 to v1.14.0, proposed only
- **Form:** Incremental amendment successor. Read with the complete pinned predecessor; all predecessor text remains unchanged except the explicit additions below if approved.
- **Approval:** Pending accountable Product-owner decision. No current authority or merge approval.

The current governance router continues to select v1.13.0. This proposal does not supersede it. After explicit owner decisions, a reviewed promotion in this PR must select the approved successor and preserve its predecessor before authorised integration. Any changed head requires fresh independent Master Gate review and exact-head verification. Until then, this PR remains a candidate and must not merge. Neither this candidate nor its presence in a proposal index activates law.

## Proposed §21E.21 Magic-login message classification

Add `magic_login_message` to the controlled catalogue in §21E.3. It covers only optional email-based sign-in for an existing Account. §21E.19 continues to exclude magic-login authentication from `verification_message`. No other existing type establishes this purpose-specific content contract. This type excludes address verification, password reset, recovery, primary-email change, billing, marketing, safety, practitioner and entitlement messages. It is not a general transactional-message class.

The proposed wording risk is `editorial_low_risk` under §21E.4, subject to an explicit Product-owner decision. This is a classification of message wording only. Identity authentication/security risk remains HIGH. Copy classification cannot approve an authentication mechanism or weaken security review.

Content & Media owns the existing `ContentItem → ContentVersion → ContentTranslationVersion` identities and immutable EN/AF subject/body bytes. Identity owns authentication proof, current Account/security checks and Session truth. Communications owns MessageIntent, DeliveryAttempt and current delivery decisions. A content decision cannot authenticate, issue a Session, approve a sender/provider or extend bearer retention. Identity JIT §J.1 remains unchanged, including its exclusion of optional magic login from protected-delivery retention authority.

## Proposed §21E.22 Bounded P8-09 development content eligibility

Eligibility is limited to local development, automated tests, development environments and bounded P8-09 Phase-8 proof. Production, public release, paid pilot and real-participant delivery are prohibited by this extension. There is no runtime Content role, publication or release approval in this package. Any later release requires separate applicable governance, actual role/scope approvals and release evidence. OQ-013 and OQ-016 remain open.

Use `candidate → development_approved → superseded | withdrawn`. Candidate artifacts are ineligible. Promotion requires an explicit accountable Product-owner decision for the exact classification and wording risk, plus an accountable Content & Media owner decision for each exact locale version, bytes, digest, token contract and bounded applicability. Repository authorship, Plane ownership, implementation permission and approval of verification-message content do not satisfy either decision. Development-only decisions do not require a materialised runtime Account or role grant under DEC-320, but do require verifiable accountable owner provenance.

Bind approvals to exact decision identity, immutable ContentItem/ContentVersion/ContentTranslationVersion identities, locale, format ID, byte counts, SHA-256 digests, typed token allowlist and applicability. Use no `latest` alias or silent locale fallback. Missing, conflicting, unverifiable, stale or mismatched evidence fails closed. Re-read current eligibility before new use; a queued job never preserves it. Only literal tokens belong in source evidence, never rendered bearer values.

Record decisions append-only. The same exact decision, subject versions, digests and scope replay idempotently. Reusing a decision ID with changed binding, or conflicting decisions for the same immutable version, stops new use pending an explicit owner reconciliation event referencing all conflicting events. No last-write-wins. Changed bytes require a new immutable locale version and fresh approval; changed shared structure requires a successor ContentVersion. Withdrawal or supersession is terminal for new use and preserves historical bytes, approvals and existing bindings. A reconciled replacement never rewrites old evidence. Recovery reconstructs eligibility from the complete reviewed event history; incomplete history fails closed.

This extension does not authorise WELL-12 implementation or Phase 9. WELL-91's Assent disposition and exclusive `2026-11-18T00:00:00Z` expiry remain unchanged. No authentication-input rebinding is authorised.
