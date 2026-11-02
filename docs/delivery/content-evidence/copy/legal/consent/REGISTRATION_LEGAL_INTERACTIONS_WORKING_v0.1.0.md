# Registration legal interactions — WORKING v0.1.0

**Status:** WORKING CANDIDATE / NOT LEGALLY APPROVED<br>
**Source:** `NEWYOU_LEGAL_UX_COPY_PACK_WORKING_v0.1.0`<br>
**Source pack SHA-256:** `3db06cc3a9faa23f90cf8439afba6afcaaf5c75c65bb0590f96cd4d85d755dfb`<br>
**Terms source:** `NEWYOU_PLATFORM_DIGITAL_PRODUCTS_SUBSCRIPTION_TERMS_COUNSEL_REVIEW_CANDIDATE_v0.3.3.md` / `826546419cd055bcd4710bb9f4ebd5d738d89a50874bdcc013759335d69180f6`<br>
**Privacy source:** `NEWYOU_PRIVACY_NOTICE_COUNSEL_REVIEW_CANDIDATE_v0.3.2.md` / `29e834dcbd3b2208902698ab842e965c595e3e6063e26526d845d0af8d493baa`

These are unchanged pre-counsel source inputs, not current authority. They contain stale Product v1.9.0 assumptions about bilingual governing legal documents. Product v1.13.0 and DEC-316 require English-only governing Terms and Privacy documents and override those source statements.

**Source items:** `LUX-REG-001`, `LUX-REG-002`, `LUX-REG-003`

## Required separation

Product Law and P8-05 require acceptance of both exact Terms and Privacy versions, with distinct evidence for each. They do not prescribe the number or visual arrangement of participant-facing controls. The v0.3.0 copy candidate uses separate Terms and Privacy acceptance controls as a UX/legal-review choice. Another composition would still need to preserve both acceptance facts and their exact evidence.

The current candidate presents these registration items in order:

1. **Age confirmation** — separate affirmative control.
2. **Terms acceptance** — separate affirmative control linked to the exact selected English Terms version.
3. **Privacy Notice presentation** — show the applicable Notice link and the separate disclosure copy. Presentation alone does not meet the required Privacy acceptance gate.
4. **Privacy acceptance** — separate affirmative control for the exact applicable Privacy version. This acceptance is required for registration and is **not consent to every processing purpose**.
5. **Purpose-specific consent** — request only where applicable, with its own purpose and evidence.

Purpose-specific consent and optional marketing permission are not inferred from Terms acceptance, Privacy presentation or Privacy acceptance.

## Age confirmation

EN: `I confirm that I am 18 years or older.`<br>
AF: `Ek bevestig dat ek 18 jaar of ouer is.`

## Terms acceptance

EN: `I accept the Terms and Conditions for {{platform_name}}.`<br>
AF: `Ek aanvaar die Bepalings en Voorwaardes vir {{platform_name}}.`

Adjacent link:

- EN: `Read the Terms and Conditions (English)`
- AF: `Lees die Bepalings en Voorwaardes (Engels)`

**Evidence boundary:** exact Terms version/reference, time, Account/registration association and participant interaction/preferred locale. Governing legal-document locale remains `en`.

## Privacy presentation and acceptance

See `../privacy/REGISTRATION_PRIVACY_PRESENTATION_WORKING_v0.1.0.md`.

**Evidence boundary:** exact Privacy version/reference, acceptance timestamp, Account/registration association and participant interaction/preferred locale. The governing Privacy document locale remains `en`.

## Superseded v0.2.0 design

The v0.2 combined-control layout is superseded as the current copy-workspace candidate. Do not compose `identity.registration.legal_acceptance` or `identity.registration.legal.required` into the v0.3 candidate page. The current candidate uses separate acceptance controls, while Product Law leaves control count open. A Privacy Notice presentation key is disclosure copy only and does not establish either acceptance fact.
