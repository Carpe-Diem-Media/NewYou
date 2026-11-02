# Wellness Platform Bilingual Copy System — review workspace v0.3.0

**Status:** REVIEW WORKSPACE / NON-AUTHORITATIVE<br>
**Verified against live repository main:** `ec9deb9bc3f5e78b5041213c32698b226c6a6ceb` on 2026-11-02<br>
**Purpose:** give product, design, frontend, Content & Media, translators, reviewers and implementation agents one systematic EN/AF copy workspace before wording becomes authoritative. The public brand is intentionally unresolved; participant-facing strings use `{{platform_name}}` rather than hardcoding the repository/project name.

## Executive architecture

The system has one semantic source of copy truth: `COPY_REGISTRY.json`. Every logical string has one stable key and one English/Afrikaans relationship. Shared strings live once, journey files review the copy needed by that journey, and page manifests only compose semantic keys. Page files therefore never become a second translation source.

The registry distinguishes **Class A governed exact copy**, **Class B shared product/UX copy**, and **Class C ordinary implementation/internal copy**. It separately records **NOW**, **SHARED_BASELINE**, **JIT** and **RELEASE** readiness so the full product can be inventoried without pretending future wording is ready.

Class A is intentionally narrow: legal/privacy/consent, safety/clinical/commercially meaningful wording, identity/security wording where exact semantics matter, and exact participant-facing content current authority explicitly requires to be approved/immutable. Class B covers the reusable UI language implementation should not casually reinvent. Class C remains ordinary JIT implementation text.

For future features, first add an inventory/family stub. When the feature becomes executable, replace/add exact semantic copy items with EN/AF variants, scoped reviews and version identities. Do not amend durable Product/Architecture/Domain/Roadmap law merely to record a normal UX wording choice.

## Important current boundary

This workspace **does not approve** the new P8-05 browser strings. Newly drafted browser copy is `candidate` and several high-impact items are marked `OWNER REVIEW REQUIRED`. Existing legal development baselines and the existing verification-email packet are referenced/preserved with their current evidence status; they are not silently promoted to production approval.

## What WELL-52 can eventually consume

Once the exact NOW browser items receive the required scoped development approval/evidence, WELL-52 can bind to the stable semantic keys for:

- language/header account access;
- pre-registration launch/safety framing;
- required DEC-027 registration fields and gates;
- separate Terms acceptance and Privacy Notice presentation/acknowledgement, exact versioned legal evidence, links and legal-language disclosure;
- neutral accepted/failure responses;
- localized verification-pending and explicit resend states;
- public-safe next actions.

Current P8-05 excludes change-email from this slice and does not justify verification-expiry or emergency copy.

## Main files

- `COPY_REGISTRY.json` — machine-readable semantic registry.
- `COPY_INVENTORY.md` — comprehensive platform copy-family inventory.
- `GLOSSARY.md` — EN ↔ AF terminology decisions and review flags.
- `STYLE_GUIDE.md` — English/Afrikaans voice, mechanics and safety rules.
- `GOVERNANCE.md` — ownership, class/status lifecycle, approvals, versioning and no-fallback policy.
- `STATUS.md` — current readiness and approval snapshot.
- `REVIEW_REPORT.md` — decisions for owner review, reused evidence, new candidates, JIT deferrals and release-only blockers.
- `journeys/registration/P8_05_REGISTRATION_COPY.md` — immediate registration copy pack.
- `journeys/verification/P8_05_VERIFICATION_PENDING_COPY.md` — immediate pending/resend copy pack.
- `shared-ui/SHARED_UI_BASELINE.md` — reusable EN/AF baseline.
- `pages/` — composition manifests only.

## Editing rule

Edit candidate wording in the registry/source review files, then create a new immutable version/digest when exact approved content is cut. **Never edit a `development_approved`, `production_approved`, `superseded` or `withdrawn` exact version in place.** Existing repository evidence marked `do_not_edit_here` must be changed only through its owning governed process.

## v0.3.0 legal UX integration

The uploaded `NEWYOU_LEGAL_UX_COPY_PACK_WORKING_v0.1.0` has been reconciled and split into scoped Markdown files. Its source Terms `NEWYOU_PLATFORM_DIGITAL_PRODUCTS_SUBSCRIPTION_TERMS_COUNSEL_REVIEW_CANDIDATE_v0.3.3.md` and Privacy `NEWYOU_PRIVACY_NOTICE_COUNSEL_REVIEW_CANDIDATE_v0.3.2.md` remain untouched pre-counsel artifacts in the user repository. The v0.2.0 combined Terms + Privacy checkbox is superseded; Terms acceptance and Privacy presentation/acknowledgement are now separate candidate interactions. Privacy acknowledgement is not blanket consent.

See `legal/LEGAL_UX_COPY_INDEX_WORKING_v0.1.0.md` and `evidence/LEGAL_UX_PACK_RECONCILIATION_v0.1.0.md`.
