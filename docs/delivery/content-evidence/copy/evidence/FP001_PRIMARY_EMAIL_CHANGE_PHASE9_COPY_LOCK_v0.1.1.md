# FP-001 primary-email-change — exact EN/AF browser copy approval lock v0.1.1

**Owner decision: APPROVED for future bounded non-production Phase-9 browser-copy use, subject to canonical integration and current Plane authorization.**

This file records copy approval, **not** Phase-9 email eligibility, a Ready ticket, implementation dispatch, release or provider authorization. No GitHub merge is claimed by this local artifact.

- **Exact approved JSON filename:** `FP001_PRIMARY_EMAIL_CHANGE_PHASE9_BROWSER_COPY_APPROVED_v0.1.1.json`
- **Exact approved JSON SHA-256:** `41d6ae138c541ea05e1efdcfec42865d3dc019a697aebc2d182333b18ed9edc4`
- **Earlier candidate JSON SHA-256:** `0d045639e5405791860f2bd19bf9d0b5945a0f7ee487ba2a6538e35434b39847`
- **Decision date:** 2026-11-16
- **Attribution:** One authorizing owner in conversation; no claim of five independent human reviewers or an implemented runtime Content role
- **Scope:** 24 stable semantic keys / 48 EN/AF text values; one Afrikaans string amended, other 47 texts unchanged

## Sole wording change from candidate v0.1

- **Key:** `identity.change_email.reauthentication.body`
- **Before:** Bevestig vir jou veiligheid jou identiteit voordat jy hierdie verandering versoek.
- **Final (approved):** **Vir jou veiligheid, bevestig jou identiteit voordat jy hierdie verandering versoek.**
- **English:** For your security, confirm your identity before requesting this change. (unchanged)

## Exact approved browser strings

| Semantic key | English | Afrikaans | Source |
|---|---|---|---|
| `identity.change_email.start.title` | Change your email address | Verander jou e-posadres | Owner-approved new browser string |
| `identity.change_email.start.body` | Your current email address stays active until the new address is confirmed and the change is applied. Additional security checks may be required. | Jou huidige e-posadres bly aktief totdat die nuwe adres bevestig en die verandering toegepas is. Bykomende sekuriteitskontroles kan nodig wees. | Owner-approved new browser string |
| `identity.change_email.current.label` | Current email address | Huidige e-posadres | Owner-approved new browser string |
| `identity.change_email.new.label` | New email address | Nuwe e-posadres | Owner-approved new browser string |
| `identity.change_email.reauthentication.body` | For your security, confirm your identity before requesting this change. | Vir jou veiligheid, bevestig jou identiteit voordat jy hierdie verandering versoek. | Owner-approved new browser string |
| `identity.change_email.request.action` | Request email change | Versoek e-posadresverandering | Owner-approved new browser string |
| `identity.change_email.request.neutral` | If the request can proceed, you will need to confirm your new email address. Your current email address has not changed. | As die versoek kan voortgaan, sal jy jou nuwe e-posadres moet bevestig. Jou huidige e-posadres het nie verander nie. | Owner-approved new browser string |
| `identity.change_email.pending.title` | Check your new email address | Gaan jou nuwe e-posadres na | Owner-approved new browser string |
| `identity.change_email.pending.body` | If a confirmation email is sent, use its link to confirm the new address. Confirmation alone does not change your account email. | As ’n bevestigings-e-pos gestuur word, gebruik die skakel daarin om die nuwe adres te bevestig. Bevestiging alleen verander nie jou rekening se e-posadres nie. | Owner-approved new browser string |
| `identity.change_email.confirm.title` | Confirm your new email address | Bevestig jou nuwe e-posadres | Existing Phase-8 browser string, unchanged |
| `identity.change_email.confirm.body` | Confirm that you can access this address. Your current email stays in place until the change is applied. | Bevestig dat jy toegang tot hierdie adres het. Jou huidige e-posadres bly aktief totdat die verandering toegepas word. | Existing Phase-8 browser string, unchanged |
| `identity.change_email.confirm.action` | Confirm new email | Bevestig nuwe e-posadres | Existing Phase-8 browser string, unchanged |
| `identity.change_email.confirmed.title` | New email address confirmed | Nuwe e-posadres bevestig | Existing Phase-8 browser string, unchanged |
| `identity.change_email.confirmed.body` | Your current email remains active until the account change is applied. | Jou huidige e-posadres bly aktief totdat die rekeningverandering toegepas word. | Existing Phase-8 browser string, unchanged |
| `identity.change_email.review.title` | Additional security checks are in progress | Bykomende sekuriteitskontroles is aan die gang | Owner-approved new browser string |
| `identity.change_email.review.body` | Your new address has been confirmed, but the change has not been applied. Keep using your current email address until the security checks are complete. | Jou nuwe adres is bevestig, maar die verandering is nog nie toegepas nie. Gebruik intussen jou huidige e-posadres totdat die sekuriteitskontroles afgehandel is. | Owner-approved new browser string |
| `identity.change_email.applied.title` | Email address changed | E-posadres verander | Owner-approved new browser string |
| `identity.change_email.applied.body` | Your new email address is now the primary address for your account. Sign in again if prompted. | Jou nuwe e-posadres is nou jou rekening se primêre e-posadres. Meld weer aan as jy gevra word. | Owner-approved new browser string |
| `identity.change_email.uncertain.title` | We could not confirm the current status | Ons kon nie die huidige status bevestig nie | Owner-approved new browser string |
| `identity.change_email.uncertain.body` | Sign in and check your account email address before you try again. | Meld aan en gaan jou rekening se e-posadres na voordat jy weer probeer. | Owner-approved new browser string |
| `identity.change_email.unavailable.title` | This confirmation is unavailable | Hierdie bevestiging is nie beskikbaar nie | Existing Phase-8 browser string, unchanged |
| `identity.change_email.unavailable.body` | The link may have expired or been replaced. Sign in to start a new email change. | Die skakel het dalk verval of is vervang. Meld aan om 'n nuwe e-posverandering te begin. | Existing Phase-8 browser string, unchanged |
| `identity.change_email.cancel.action` | Cancel email change | Kanselleer e-posadresverandering | Owner-approved new browser string |
| `identity.change_email.cancelled.title` | Email change cancelled | E-posadresverandering gekanselleer | Owner-approved new browser string |

## Source / owner boundaries

- Source candidate is immutable historical reference, not overwritten. All existing Phase-8 UI text remains verbatim.
- Product §21J.8 and DEC-251 still govern Identity's primary-email-change transitions and security consequences. Browser strings project owner state, not new business authority.
- Existing primary-email-change email evidence is limited by Product §21E.28 / DEC-324 to Phase-8 development; **Phase-9 email eligibility remains prohibited until a separately approved and integrated Product/Decision successor.**
- A future delivery ticket must independently pass Plane Ready and current-GitHub checks. Browser-copy approval does not preselect that ticket.
- Both locales must be checked at exact versions. Changed/withdrawn/superseded content fails closed; no silent EN/AF fallback.
- Approval is scoped to bounded non-production development and review only. No production/public/pilot/real-participant sending, provider, legal or runtime permission.

## Lock and validation notes

`copy_items` diff versus v0.1 has exactly one pair `(semantic_key, locale)` changed, namely the Afrikaans reauthentication body. Every other English/Afrikaans string is unchanged. Each locale string has its own SHA-256 in the exact approved JSON.

The JSON file hash above is over the complete UTF-8 file, including its final newline. Any later edits require a new immutable version, a new SHA-256, and reapproval as applicable. Canonical consumption requires separately verified GitHub integration; this stand-alone file is approval evidence, not automatic runtime eligibility.
