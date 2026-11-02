# Legal UX pack reconciliation — 2026-11-02

**Status:** COMPLETE RECONCILIATION OF WORKING COPY INPUT / NO PRODUCTION APPROVAL<br>
**Repository anchor checked:** `ec9deb9bc3f5e78b5041213c32698b226c6a6ceb`<br>
**Plane checked:** WELL-45 remains Planning; bounded-development copy evidence and release approvals remain distinct.

## Input integrity

- Source Markdown SHA-256: `3db06cc3a9faa23f90cf8439afba6afcaaf5c75c65bb0590f96cd4d85d755dfb`
- Source manifest SHA-256: `5bb3115c40793ab756dd28e10993eae539759afc3d3799479c28815aea56422a`
- Terms source SHA-256: `826546419cd055bcd4710bb9f4ebd5d738d89a50874bdcc013759335d69180f6` (`NEWYOU_PLATFORM_DIGITAL_PRODUCTS_SUBSCRIPTION_TERMS_COUNSEL_REVIEW_CANDIDATE_v0.3.3.md`)
- Privacy source SHA-256: `29e834dcbd3b2208902698ab842e965c595e3e6063e26526d845d0af8d493baa` (`NEWYOU_PRIVACY_NOTICE_COUNSEL_REVIEW_CANDIDATE_v0.3.2.md`)

The repository-local Terms and Privacy source files match these recorded hashes and remain unchanged. The source pack and its manifest are not present in this repository, so their recorded input hashes are retained as provenance without a local re-hash. These source candidates are pre-counsel inputs, not current authority.

## Disposition of all source copy items

| Source item | Disposition | Workspace destination |
|---|---|---|
| LUX-DIS-001 | integrated, adapted to `{{platform_name}}` | `legal/disclaimers/GENERAL_WELLNESS_DISCLAIMER_WORKING_v0.1.0.md` |
| LUX-DIS-002 | integrated | `legal/disclaimers/TEMPERAMENT_DISCLAIMER_WORKING_v0.1.0.md` |
| LUX-DIS-003 | integrated, dynamic platform name | `legal/disclaimers/FAITH_PROFESSIONAL_CARE_BOUNDARY_WORKING_v0.1.0.md` |
| LUX-DIS-004 | integrated, dynamic platform name | `legal/disclaimers/NO_GUARANTEED_OUTCOME_WORKING_v0.1.0.md` |
| LUX-REG-001 | retained; matches current age confirmation | `journeys/registration/P8_05_REGISTRATION_COPY.md` |
| LUX-REG-002 | **supersedes combined legal checkbox design** | registration journey + `legal/consent/REGISTRATION_LEGAL_INTERACTIONS_WORKING_v0.1.0.md` |
| LUX-REG-003 | presentation/disclosure wording adapted; current Product Law separately requires affirmative Privacy acceptance; AF terminology uses `Privaatheidsbeleid` | registration journey + `legal/privacy/REGISTRATION_PRIVACY_PRESENTATION_WORKING_v0.1.0.md` |
| LUX-MKT-001 | integrated as JIT candidate | `legal/consent/MARKETING_PERMISSION_WORKING_v0.1.0.md` |
| LUX-MKT-002 | integrated as JIT candidate | `communications/marketing/MARKETING_CHANNEL_PREFERENCES_WORKING_v0.1.0.md` |
| LUX-CK-001 | integrated; inventory-gated | `legal/cookies/COOKIE_BANNER_WORKING_v0.1.0.md` |
| LUX-CK-002 | integrated; AF `toegangsreëls` terminology | `legal/cookies/COOKIE_PREFERENCE_CENTRE_WORKING_v0.1.0.md` |
| LUX-CK-003 | integrated as **structure-only / hard blocked** | `legal/cookies/COOKIE_NOTICE_SHELL_WORKING_v0.1.0.md` |
| LUX-HLT-001 | integrated as JIT template; AF uses `Privaatheidsbeleid` | `legal/privacy/HEALTH_DATA_JIT_DISCLOSURE_TEMPLATE_WORKING_v0.1.0.md` |
| LUX-HLT-002 | integrated as **hard-blocked review shell** | `legal/consent/HEALTH_SPECIAL_PI_CONSENT_SHELL_BLOCKED_v0.1.0.md` |
| LUX-PRAC-001 | integrated as future/blocked shell | `legal/consent/PRACTITIONER_SHARING_PERMISSION_FUTURE_v0.1.0.md` |
| LUX-ECTA-001 | integrated as SKU/counsel-gated shell | `commerce/checkout/EARLY_PERFORMANCE_INSTRUCTION_SHELL_BLOCKED_v0.1.0.md` |
| LUX-VER-001 | evaluated; **not used to regress current reviewed copy** | existing `journeys/verification/P8_05_VERIFICATION_PENDING_COPY.md` retained |
| LUX-VER-002 | resend action already matches; supporting text not substituted | existing verification journey retained |

## Material correction to workspace v0.2.0

The v0.2.0 combined Terms + Privacy checkbox is superseded. Current Product v1.13.0, DEC-027 and P8-05 require separate Terms acceptance and Privacy acceptance before Account creation. The page also presents the Privacy Notice and its disclosure separately; presentation alone does not satisfy acceptance. Privacy acceptance is not consent to every processing purpose. The v0.3.0 registry/page composition therefore uses separate Terms acceptance, Privacy presentation and Privacy acceptance keys.

Terms v0.3.3 and Privacy v0.3.2 are pre-counsel source inputs that preserve stale Product v1.9.0 assumptions, including a bilingual governing-document requirement. Product v1.13.0 and DEC-316 instead require English-only governing Terms and Privacy bodies, with both Afrikaans and English experiences linking to the same English documents. Current Product Law overrides the stale source statements. Reconcile the source candidates against current authority before any later legal or counsel successor becomes production authority. The copy workspace does not amend or supersede Product semantics.

## Deliberate non-replacements

- The user-staged Terms v0.3.3 and Privacy v0.3.2 counsel-review documents remain separate and are not edited.
- The exact English-only development baseline legal artifacts remain separately referenced.
- Existing owner-reviewed P8-05 verification copy remains the current candidate because it is clearer while retaining the mandatory anti-enumeration boundary.
- The existing P8-05 launch safety candidate is not replaced by the generic LUX-DIS-001 disclaimer; they have different purposes and placement.
