# Legal UX copy index — WORKING v0.1.0 integration

**Workspace integration:** v0.3.0<br>
**Status:** WORKING / DEVELOPMENT-CANDIDATE / NOT LEGALLY APPROVED FOR PRODUCTION OR REAL-PARTICIPANT RELEASE<br>
**Verified repository anchor:** `ec9deb9bc3f5e78b5041213c32698b226c6a6ceb`

## Source provenance

This split workspace derives from `NEWYOU_LEGAL_UX_COPY_PACK_WORKING_v0.1.0.md` (SHA-256 `3db06cc3a9faa23f90cf8439afba6afcaaf5c75c65bb0590f96cd4d85d755dfb`) and its manifest (SHA-256 `5bb3115c40793ab756dd28e10993eae539759afc3d3799479c28815aea56422a`). The pack in turn identifies these pre-counsel source inputs:

- Terms: `NEWYOU_PLATFORM_DIGITAL_PRODUCTS_SUBSCRIPTION_TERMS_COUNSEL_REVIEW_CANDIDATE_v0.3.3.md` — SHA-256 `826546419cd055bcd4710bb9f4ebd5d738d89a50874bdcc013759335d69180f6` — **PRE-COUNSEL / NOT FOR PUBLICATION**.
- Privacy: `NEWYOU_PRIVACY_NOTICE_COUNSEL_REVIEW_CANDIDATE_v0.3.2.md` — SHA-256 `29e834dcbd3b2208902698ab842e965c595e3e6063e26526d845d0af8d493baa` — **PRE-COUNSEL / NOT FOR PUBLICATION**.

Those two pre-counsel documents are intentionally **not copied, rewritten or superseded by this integration**. They remain separate source artifacts in `copy/legal/terms/` and `copy/legal/privacy/`. They contain stale assumptions from Product v1.9.0, including that governing Terms and Privacy documents must be bilingual. Current Product v1.13.0 and DEC-316 require English-only governing documents and override those conflicting assumptions. Reconcile the candidates against current authority before using them in any legal or counsel successor.

## Authority boundary

GitHub Product/Decision/Architecture/Domain/Roadmap/supporting authority remains superior. This directory is copy-review material, not Product Law or legal advice. Governing Terms and Privacy bodies are English-only; both Afrikaans and English product experiences link to the same English documents. Participant-facing legal/privacy/consent UI remains bilingual where required.

## Core interaction rule

Keep the required Terms and Privacy acceptance facts and evidence distinct. Product Law and P8-05 do not prescribe the number of participant-facing controls; the v0.3.0 copy candidate uses separate controls. Privacy Notice presentation is a separate disclosure and does not establish acceptance. Privacy acceptance is not consent to every processing purpose. Age confirmation, purpose-specific consent, marketing permission, cookie choices, special-personal-information authorisation, practitioner sharing and early-performance instructions remain separate facts where applicable.

## Split files

- `consent/REGISTRATION_LEGAL_INTERACTIONS_WORKING_v0.1.0.md`
- `privacy/REGISTRATION_PRIVACY_PRESENTATION_WORKING_v0.1.0.md`
- `disclaimers/GENERAL_WELLNESS_DISCLAIMER_WORKING_v0.1.0.md`
- `disclaimers/TEMPERAMENT_DISCLAIMER_WORKING_v0.1.0.md`
- `disclaimers/FAITH_PROFESSIONAL_CARE_BOUNDARY_WORKING_v0.1.0.md`
- `disclaimers/NO_GUARANTEED_OUTCOME_WORKING_v0.1.0.md`
- `consent/MARKETING_PERMISSION_WORKING_v0.1.0.md`
- `../communications/marketing/MARKETING_CHANNEL_PREFERENCES_WORKING_v0.1.0.md`
- `cookies/COOKIE_BANNER_WORKING_v0.1.0.md`
- `cookies/COOKIE_PREFERENCE_CENTRE_WORKING_v0.1.0.md`
- `cookies/COOKIE_NOTICE_SHELL_WORKING_v0.1.0.md`
- `privacy/HEALTH_DATA_JIT_DISCLOSURE_TEMPLATE_WORKING_v0.1.0.md`
- `consent/HEALTH_SPECIAL_PI_CONSENT_SHELL_BLOCKED_v0.1.0.md`
- `consent/PRACTITIONER_SHARING_PERMISSION_FUTURE_v0.1.0.md`
- `../commerce/checkout/EARLY_PERFORMANCE_INSTRUCTION_SHELL_BLOCKED_v0.1.0.md`
- `LEGAL_UX_LIFECYCLE_CONTRACTS_WORKING_v0.1.0.md`
- `LEGAL_UX_RELEASE_GATES_WORKING_v0.1.0.md`

Verification-pending/resend source items `LUX-VER-001/002` were evaluated but **do not replace** the already owner-reviewed P8-05 verification copy. See `../journeys/verification/P8_05_VERIFICATION_PENDING_COPY.md` and the reconciliation report.
