# Live reconnaissance — 2026-11-02

**Purpose:** record the live sources used to design this review workspace. This file is evidence notes, not authority.

## Verified repository baseline

- Canonical repository: `JCSchoeman96/NewYou`
- Verified `main`: `ec9deb9bc3f5e78b5041213c32698b226c6a6ceb` (PR #179 / WELL-51 merge)
- Current routing: `docs/README.md` → `docs/governance/CURRENT_GOVERNANCE_ROUTER.json` and `docs/delivery/CURRENT_DELIVERY_ROUTER.json`
- Current durable versions observed through the router: Product Law `00_PLATFORM_v1.13.0.md`, Decisions `01_DECISIONS_v1.13.0.md`, Architecture `03_ARCHITECTURE_v1.1.1.md`, Domain Law `04_DOMAIN_MAP_v1.2.0.md`, Roadmap `05_ROADMAP_v1.2.5.md`, Platform Operating Model `v1.3.0`, Frontend Experience System `v1.0.1`.

## P8-05 facts that constrain copy

1. Required registration data: first name, surname, email, authentication credential/password, preferred language, 18+ confirmation, exact Terms and Privacy version evidence. The newer legal UX working pack requires Terms acceptance and Privacy Notice presentation/acknowledgement to remain separate participant interactions; Privacy acknowledgement is not blanket consent. Phone/city are optional under DEC-027 and **outside the P8-05 proof path**. Preferred name is not required.
2. Afrikaans/English locale becomes Account preferred language.
3. Account remains unverified; registration creates no Session and grants no protected access.
4. Duplicate email must receive the same neutral public response as a newly accepted registration; browser copy must not reveal account existence.
5. Verification-pending includes an explicit resend action.
6. Current P8-05 fixed design says **do not offer change-email/email correction in this slice**, even though the broader experience model permits it where later allowed.
7. Governing Terms and Privacy bodies are English-only. Interaction/preferred locale remains independently `af` or `en`.
8. Development legal baselines are pinned but not legally approved for production or real participants.
9. Do not add verification-expiry wording unless current authority requires it.
10. Do not add emergency/urgent-support wording to this path unless current authority defines an urgent-safety outcome.

## Existing content evidence preserved

- Legal development baselines: `LEGAL_BASELINE_CONTENT_MANIFEST_v0.1.0.json`
  - Terms ID `NEWYOU-TERMS-EN-DEV-2026-10-27-001`, SHA-256 `8d54af7ac0c2a68d3d100cca987551877f4f89ca231ae95254cd1903a2eca062`.
  - Privacy ID `NEWYOU-PRIVACY-EN-DEV-2026-10-27-001`, SHA-256 `21aecdf9fafe95f513de2ce04a266e8e7726efb406aabae0bbd4d0e19f6ba333`.
  - Both are development-only and not legally approved.
- Verification email: `VERIFICATION_MESSAGE_EVIDENCE_PACKET_v0.2.0.json`
  - EN exact artifact digest `a8ceecc466497bd3d79ae9255a7f004b18461a2d6a1791028a68bcb1efd2a072`.
  - AF exact artifact digest `c3212222fdcd878af6bdc2b17895d4d6cab44e162814e2a8deee10b7fd916494`.
  - Development-approved only for local/test/development/bounded P8-05 proof; runtime/release approvals remain pending.

## Live Plane state observed

- `WELL-45` — Planning: remaining bounded-development blocker is exact immutable bilingual browser copy evidence; release legal/privacy approvals are separate.
- `WELL-51` — Done: registration and resend orchestration merged in PR #179 at current `main`.
- `WELL-52` — Backlog: bilingual registration and verification-pending browser path.
- `WELL-53` — Backlog: P8-05 production-path proof.
- `WELL-6` — In Progress parent P8-05 outcome.

## Book foundation

`Verloor gewig op jou manier` was inspected as the content/voice foundation. Its useful language traits for product copy are direct second-person address, practical action, non-shaming recovery after setbacks, respect for the participant’s existing identity, and warmth without pretending health risk is trivial. The UI guide deliberately compresses that long-form voice into concise product language.

## Legal UX pack reconciliation input — 2026-11-02

- Legal UX pack Markdown SHA-256: `3db06cc3a9faa23f90cf8439afba6afcaaf5c75c65bb0590f96cd4d85d755dfb`.
- Legal UX manifest SHA-256: `5bb3115c40793ab756dd28e10993eae539759afc3d3799479c28815aea56422a`.
- Source Terms candidate: `NEWYOU_PLATFORM_DIGITAL_PRODUCTS_SUBSCRIPTION_TERMS_COUNSEL_REVIEW_CANDIDATE_v0.3.3.md` / `826546419cd055bcd4710bb9f4ebd5d738d89a50874bdcc013759335d69180f6`.
- Source Privacy candidate: `NEWYOU_PRIVACY_NOTICE_COUNSEL_REVIEW_CANDIDATE_v0.3.2.md` / `29e834dcbd3b2208902698ab842e965c595e3e6063e26526d845d0af8d493baa`.
- Live `main` rechecked at `ec9deb9bc3f5e78b5041213c32698b226c6a6ceb`.
- Plane WELL-45 rechecked in `Planning`; its bounded-development browser-copy evidence and release-only approvals remain separate.
- No GitHub or Plane state was mutated by this reconciliation.
