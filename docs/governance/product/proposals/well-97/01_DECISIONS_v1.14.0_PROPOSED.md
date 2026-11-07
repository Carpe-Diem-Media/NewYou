# 01_DECISIONS v1.14.0 proposed successor

- **Document status:** PROPOSED / NON-AUTHORITATIVE
- **Document version:** v1.14.0
- **Predecessor:** `docs/governance/product/01_DECISIONS_v1.13.0.md`
- **Predecessor SHA-256:** `fbe84ea762b1ff298080d3938307938b69c85f85284d6b6104a8da1bf093aa9d`
- **SemVer transition:** v1.13.0 to v1.14.0, proposed only
- **Form:** Incremental amendment successor. Read with the complete pinned predecessor; all predecessor text remains unchanged except the explicit additions below if approved.
- **Approval:** Pending accountable Product-owner decision. No current authority or merge approval.

The current governance router continues to select v1.13.0. This proposal does not supersede it. After explicit owner decisions, a reviewed promotion in this PR must select the approved successor and preserve its predecessor before authorised integration. Any changed head requires fresh independent Master Gate review and exact-head verification. Until then, this PR remains a candidate and must not merge. Neither this candidate nor its presence in a proposal index activates law.

## Proposed DEC-321 Magic-login message classification and bounded development eligibility

**Status:** PROPOSED / OWNER DECISION PENDING

Subject to explicit Product-owner acceptance of proposed Product §§21E.21–21E.22, add the narrow `magic_login_message` content type for optional existing-Account email sign-in. Recommend `editorial_low_risk` for wording only; Identity authentication/security remains HIGH. Preserve DEC-319 and verification_message exclusion, DEC-317/318 role boundaries and DEC-320 development/runtime separation.

Content & Media owns exact immutable EN/AF versions and development eligibility. Product classification approval and exact-byte Content & Media approval are separate accountable decisions. Until both exist, the versions remain candidate and ineligible. The lifecycle, exact binding, idempotency, conflict reconciliation, historical immutability and fail-closed rules are proposed Product §21E.22.

Applicability is local development, automated tests, development environments and bounded P8-09 Phase-8 proof only. Production, public release, paid pilot and real-participant delivery are prohibited. This decision grants no runtime Content role, publication, sender/provider approval, authentication implementation or protected bearer retention. WELL-91's Assent disposition and exclusive `2026-11-18T00:00:00Z` expiry remain unchanged. No authentication-input rebinding is authorised.
