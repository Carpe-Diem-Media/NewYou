# FP-001 — Participant two-step verification and high-risk confirmation: approved EN/AF browser copy v0.1.1

**Status:** Exact NewYou platform copy owner-approved for bounded future development; **no runtime, implementation, real-participant or release grant**.
**Source:** `FP001_PARTICIPANT_MFA_AND_STEP_UP_EN_AF_COPY_CANDIDATE_v0.1.0.json`, prepared from live main `64d8113eb04647925d4fcd69b08f326d189f9a47`.
**Owner approval:** 2026-11-16 direct owner decision to approve all strings and authorise a copy PR, with the suggested specific Afrikaans correction accepted as the sole textual revision.
**Approved packet SHA-256:** `ab99de6d15cf0deaa11edd9a45643c7c44708138f8abd9f92ffa0b3bf280e966`
**Source candidate SHA-256:** `08b7e92f2c5b20cfc5f2b4e4f2a22266998dd5c13fda16adf48a31feaba528db`

## Only text correction

**Key:** `identity.mfa.settings.body` (Afrikaans).

- **Previously proposed:** Voeg ’n ekstra verifikasiestap by om jou rekening te help beskerm. Dit is jou keuse om dit op te stel.
- **Now approved:** Voeg ’n ekstra verifikasiestap by om jou rekening te help beskerm. Dit is nie verpligtend nie.
- **English unchanged:** Add an extra verification step to help protect your account. Setting it up is your choice.
- **Change:** One AF string changed; 89 of 90 EN/AF source locale strings remain byte-identical. Four shared semantic keys are reused unchanged.

## Exact approved NewYou browser copy

| Semantic key | English | Afrikaans |
|---|---|---|
| `identity.mfa.settings.title` | Two-step verification | Tweestapverifikasie |
| `identity.mfa.settings.body` | Add an extra verification step to help protect your account. Setting it up is your choice. | Voeg ’n ekstra verifikasiestap by om jou rekening te help beskerm. Dit is nie verpligtend nie. |
| `identity.mfa.status.not_enrolled` | Not set up | Nog nie opgestel nie |
| `identity.mfa.status.pending` | Setup not finished | Opstelling nog nie voltooi nie |
| `identity.mfa.status.active` | Turned on | Aangeskakel |
| `identity.mfa.status.revoked` | No longer active | Nie meer aktief nie |
| `identity.mfa.enroll.action` | Set up two-step verification | Stel tweestapverifikasie op |
| `identity.mfa.enroll.title` | Set up your verification app | Stel jou verifikasie-app op |
| `identity.mfa.enroll.body` | Scan the QR code with your verification app, or enter the setup key. Then enter the code from your app to finish. | Skandeer die QR-kode met jou verifikasie-app, of voer die opstellingsleutel in. Voer dan die kode uit jou app in om klaar te maak. |
| `identity.mfa.enroll.qr.alt` | QR code for setting up two-step verification | QR-kode om tweestapverifikasie op te stel |
| `identity.mfa.enroll.manual_key.label` | Setup key | Opstellingsleutel |
| `identity.mfa.enroll.manual_key.warning` | Keep this key private. Someone with this key may be able to generate verification codes. | Hou hierdie sleutel privaat. Iemand met hierdie sleutel kan moontlik verifikasiekodes genereer. |
| `identity.mfa.enroll.code.label` | Code from your verification app | Kode uit jou verifikasie-app |
| `identity.mfa.enroll.confirm.action` | Turn on verification | Skakel verifikasie aan |
| `identity.mfa.enroll.confirm.processing` | Checking your code… | Besig om jou kode na te gaan… |
| `identity.mfa.enroll.confirm.invalid` | We couldn’t confirm that code. Check your app and try the current code. | Ons kon nie daardie kode bevestig nie. Gaan jou app na en probeer die huidige kode. |
| `identity.mfa.enroll.confirm.success` | Two-step verification is on. | Tweestapverifikasie is aangeskakel. |
| `identity.mfa.enroll.confirm.failed` | We couldn’t complete setup. Please try again. | Ons kon nie die opstelling voltooi nie. Probeer asseblief weer. |
| `identity.mfa.enroll.confirm.uncertain` | We can’t confirm whether setup finished. Refresh your security settings before trying again. | Ons kan nie bevestig of die opstelling voltooi is nie. Herlaai jou sekuriteitsinstellings voordat jy weer probeer. |
| `identity.mfa.enroll.cancel.action` | Cancel setup | Kanselleer opstelling |
| `identity.mfa.enroll.cancel.body` | Two-step verification stays off until setup is confirmed. | Tweestapverifikasie bly af totdat die opstelling bevestig is. |
| `identity.mfa.disable.action` | Turn off two-step verification | Skakel tweestapverifikasie af |
| `identity.mfa.disable.confirm.title` | Turn off two-step verification? | Skakel tweestapverifikasie af? |
| `identity.mfa.disable.confirm.body` | Your account will have one less security check. First, you’ll need to confirm it’s you. | Jou rekening sal een minder sekuriteitskontrole hê. Jy moet eers bevestig dat dit jy is. |
| `identity.mfa.disable.confirm.action` | Turn off verification | Skakel verifikasie af |
| `identity.mfa.disable.processing` | Turning off verification… | Besig om verifikasie af te skakel… |
| `identity.mfa.disable.success` | Two-step verification is off. | Tweestapverifikasie is afgeskakel. |
| `identity.mfa.disable.failed` | The request could not be completed. Check your security settings before trying again. | Die versoek kon nie voltooi word nie. Gaan jou sekuriteitsinstellings na voordat jy weer probeer. |
| `identity.mfa.disable.uncertain` | We can’t confirm whether verification was turned off. Refresh your security settings before taking another action. | Ons kan nie bevestig of verifikasie afgeskakel is nie. Herlaai jou sekuriteitsinstellings voordat jy ’n volgende aksie uitvoer. |
| `identity.mfa.disable.requires_step_up` | Confirm it’s you before turning off verification. | Bevestig dat dit jy is voordat jy verifikasie afskakel. |
| `identity.mfa.disable.already_off` | Two-step verification is already off. | Tweestapverifikasie is reeds afgeskakel. |
| `identity.step_up.title` | Confirm it’s you | Bevestig dat dit jy is |
| `identity.step_up.body` | This sensitive action needs an additional identity check before you can continue. | Hierdie sensitiewe aksie vereis ’n ekstra identiteitskontrole voordat jy kan voortgaan. |
| `identity.step_up.password.help` | Enter your current password when asked to continue. | Voer jou huidige wagwoord in wanneer jy gevra word om voort te gaan. |
| `identity.step_up.code.help` | Enter the current code from your verification app when asked. | Voer die huidige kode uit jou verifikasie-app in wanneer jy daarvoor gevra word. |
| `identity.step_up.submit` | Verify identity | Verifieer identiteit |
| `identity.step_up.processing` | Verifying your identity… | Besig om jou identiteit te verifieer… |
| `identity.step_up.invalid` | We couldn’t verify those details. Check them and try again. | Ons kon nie daardie besonderhede verifieer nie. Gaan dit na en probeer weer. |
| `identity.step_up.expired` | This verification has expired. Verify your identity again to continue. | Hierdie verifikasie het verval. Verifieer weer jou identiteit om voort te gaan. |
| `identity.step_up.success` | Your identity is confirmed for this action. | Jou identiteit is vir hierdie aksie bevestig. |
| `identity.step_up.uncertain` | We can’t confirm this check yet. Refresh the page before trying again. | Ons kan hierdie kontrole nog nie bevestig nie. Herlaai die bladsy voordat jy weer probeer. |
| `identity.step_up.unavailable` | This check isn’t available right now. Your requested action has not been completed. | Hierdie kontrole is tans nie beskikbaar nie. Jou aangevraagde aksie is nie voltooi nie. |
| `identity.step_up.mfa_required` | A code from your verification app is required for this action. | ’n Kode uit jou verifikasie-app is nodig vir hierdie aksie. |
| `identity.step_up.signin_again` | Sign in again to continue. | Meld weer aan om voort te gaan. |
| `identity.step_up.security_changed` | Your account’s security status has changed. Start this verification again. | Jou rekening se sekuriteitstatus het verander. Begin weer met hierdie verifikasie. |

## Existing keys reused, unchanged

| Semantic key | English | Afrikaans |
|---|---|---|
| `shared.navigation.settings` | Settings | Instellings |
| `shared.action.cancel` | Cancel | Kanselleer |
| `shared.action.retry` | Try again | Probeer weer |
| `identity.registration.password.label` | Password | Wagwoord |

## Locked meaning and applicability

- Participant enrollment is **optional**; this does not waive purpose-specific extra verification when a sensitive action requires it. Staff/practitioner MFA is independently **mandatory**.
- No approved wording claims that setup starts automatically, codes can be bypassed, an unconfirmed setup is active, or a trusted device satisfies high-risk step-up.
- Source lifecycle projection is retained: `not_enrolled → pending → active → revoked`, with Identity-owned confirmation, replay control, audit and guarded revocation. The terminal history of a revoked factor is not reopened; new setup is a new factor lifecycle.
- Step-up is purpose-bound and time-limited; successful identity confirmation does not itself perform a sensitive action. Current session/Account authority is re-read on every applicable sensitive action.
- Unknown or uncertain outcomes do not claim security success; users check current settings or retry after safe reconciliation. Account and session changes remain entirely within Identity & Access.
- Class A content lifecycle: `draft → candidate → development_approved → production_approved → superseded | withdrawn`. Exact version/locale/digests are immutable; conflicting approvals require reconciliation, not last-write-wins.
- Owner approval covers exact NewYou platform **wording** and bounded future development content eligibility after integration; it does not authorise immediate implementation, production, release, provider/email, test failure bypass, pilot, or real-participant access.
- This content-only PR must add no application readers, actions, migrations, tests, new domain authority, infrastructure or alternate content registry truth.

## Authority and evidence

- Product v1.18.0 §§21J.3–21J.7; current FP-001 Identity JIT §K.4 and Final Feature Pack Contract §Q.2.
- `docs/delivery/content-evidence/copy/GOVERNANCE.md`, `STYLE_GUIDE.md`, and `GLOSSARY.md`.
- One owner decision: no invented independent English, Afrikaans, legal, security, or release sign-offs.
- Owner permission to open this **copy** PR is a bounded exception to the ordinary `JC-Agents` PR-author workflow; it does not waive any merge/CI/independent review gate.
