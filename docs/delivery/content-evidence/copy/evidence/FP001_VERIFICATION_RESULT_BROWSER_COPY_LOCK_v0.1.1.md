# FP-001 — Email-verification result EN/AF platform copy approval lock v0.1.1

**Approval:** Direct owner decision on 2026-11-16: two exact quotation edits accepted; the other 12 EN/AF strings approved unchanged.
**Purpose:** Final intended NewYou platform wording; separate runtime and production eligibility.
**Status:** OWNER APPROVED, AWAITING CANONICAL INTEGRATION; NOT PRODUCTION/RELEASE AUTHORISATION.
**Exact approved JSON SHA-256:** `2c190d41d962b371807f1dfa31c3b60d5e18ba15f71a4356384897cf70f4a297`
**Source review JSON SHA-256:** `e097d093312aab7354efd4dc5ea08694413b220d512b82382a577d59444e8d94`
**Source development fixture:** `docs/development/fixtures/p8-07-copy-v1.json`, pinned SHA-256 `146eeb3399c96fd0bc995fc905161a4a70f90bbf21fa77f395b2e427e840b1fa`.
**Baseline main:** `58c642a211a07b90241c4822e04edfe4dd169403`.

## Exact change — two strings only

**Semantic key:** `identity.verification.result.confirm.body`

- **New English (owner approved):** Choose "Verify email" to confirm this address. Opening this page does not verify it.
- **New Afrikaans (owner approved):** Kies "Verifieer e-posadres" om hierdie adres te bevestig. As jy hierdie bladsy oopmaak, word dit nie geverifieer nie.
- **EN SHA-256:** `fa4d7d8fe4ed6c0b63738ff9f7add41101c041704e2a089f72ab7117d2efcd5b`
- **AF SHA-256:** `fd7a312378caaf7f56dc22a7701c9b58292f342c5819a9bf4b70d114599e9d07`

Only quotation marks around the existing button wording were added. All other text, keys and 12 remaining locale digests are unchanged.

## Full exact approved bilingual copy

| Semantic key | English | Afrikaans |
|---|---|---|
| `identity.verification.result.confirm.title` | Confirm your email | Bevestig jou e-posadres |
| `identity.verification.result.confirm.body` | Choose "Verify email" to confirm this address. Opening this page does not verify it. | Kies "Verifieer e-posadres" om hierdie adres te bevestig. As jy hierdie bladsy oopmaak, word dit nie geverifieer nie. |
| `identity.verification.result.confirm.action` | Verify email | Verifieer e-posadres |
| `identity.verification.result.verified.title` | Email verified | E-posadres geverifieer |
| `identity.verification.result.verified.body` | Your email address is verified. You have not been logged in. | Jou e-posadres is geverifieer. Jy is nie aangemeld nie. |
| `identity.verification.result.unavailable.title` | Verification unavailable | Verifikasie nie beskikbaar nie |
| `identity.verification.result.unavailable.body` | This link cannot verify your email. Request another verification email from the registration page. | Hierdie skakel kan nie jou e-posadres verifieer nie. Vra nog ’n verifikasie-e-pos op die registrasiebladsy aan. |

## What the approval does and does not mean

- **Platform content:** These are the owner-approved participant-facing strings intended for NewYou, not temporary placeholder wording.
- **Development:** After this packet and hash-pinned route are integrated, they may be consumed only in a separately authorised bounded development context. Owner text approval is distinct from an implementation Ready ticket.
- **Runtime migration remains future work:** Existing `NewYouWeb.VerificationCopy` reads the original temporary P8-07 fixture. This PR must not silently update that fixture, reader, controllers or tests. A later implementation ticket must adopt the new approved exact version and its allowed environment guard.
- **Production:** Public/pilot/real-participant release remains prohibited until all applicable Product, Content, language, security/privacy, runtime Content and release decisions are met. These are separate gates; approval of wording does not imply the underlying Identity flow is safe for production.
- **No second human approval invented:** One owner approved all exact strings. Historical scoped temporary approval stays historical; no claim of independent multiple approvers.
- **Security semantics:** Viewing a proof link does not verify it. Only explicit protected confirmation may consume the proof. Verified state requires authoritative Identity success. No Session is issued by verification. Non-success outcomes remain one non-enumerating unavailable result.
- **Content lifecycle:** Development-approved version may later transition under governed eligibility to production-approved, superseded or withdrawn. Changed bytes require a new immutable successor. New consumption of superseded/withdrawn versions fails closed. Retry and conflicting decisions require revalidation/reconciliation.
- **Protected boundaries:** No email sender/provider grant, no Account/Token state mutation, no release or publication grant. Existing Product and Domain authority remain unchanged.
