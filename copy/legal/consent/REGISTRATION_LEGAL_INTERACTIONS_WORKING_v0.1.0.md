# Registration legal interactions — WORKING v0.1.0

**Status:** WORKING CANDIDATE / NOT LEGALLY APPROVED<br>
**Source:** `NEWYOU_LEGAL_UX_COPY_PACK_WORKING_v0.1.0`<br>
**Source pack SHA-256:** `3db06cc3a9faa23f90cf8439afba6afcaaf5c75c65bb0590f96cd4d85d755dfb`<br>
**Terms source:** `NEWYOU_PLATFORM_DIGITAL_PRODUCTS_SUBSCRIPTION_TERMS_COUNSEL_REVIEW_CANDIDATE_v0.3.3.md` / `826546419cd055bcd4710bb9f4ebd5d738d89a50874bdcc013759335d69180f6`<br>
**Privacy source:** `NEWYOU_PRIVACY_NOTICE_COUNSEL_REVIEW_CANDIDATE_v0.3.2.md` / `29e834dcbd3b2208902698ab842e965c595e3e6063e26526d845d0af8d493baa`

**Source items:** `LUX-REG-001`, `LUX-REG-002`, `LUX-REG-003`

## Required separation

Registration composes three distinct participant interactions for the current candidate:

1. **Age confirmation** — separate affirmative control.
2. **Terms acceptance** — separate affirmative control linked to the exact selected English Terms version.
3. **Privacy Notice presentation / acknowledgement** — presented distinctly from Terms; any acknowledgement is evidence that the Notice was made available and is **not blanket consent**.

Purpose-specific consent and optional marketing permission are not inferred from any of the above.

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

## Privacy presentation / acknowledgement

See `../privacy/REGISTRATION_PRIVACY_PRESENTATION_WORKING_v0.1.0.md`.

## Superseded v0.2.0 design

The single combined Terms + Privacy checkbox is superseded. Do not compose `identity.registration.legal_acceptance` or `identity.registration.legal.required` into new registration pages.
