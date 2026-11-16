# FP-001 — Account Settings overview: exact owner-approved EN/AF copy v0.1.1

**Status:** Owner-approved NewYou platform copy; development eligibility after canonical integration only. No application implementation or production/public/pilot/real-participant release permission.
**Owner decision (16 November 2026):** Approved and authorised a PR, requesting quotation marks around the Afrikaans Help navigation label.
**Source candidate SHA-256:** `b3b9cc8adea982e8049d4c8be31e463fa345e61bd21fecc61e0fef51d72f3983`
**Approved JSON SHA-256:** `6d4778e028e6d4b1bed2d28e8b5d7669d170ac38660c25a4c182bef181334c35`
**Review baseline:** GitHub main `82136a38fa487bfa1eb8b3e8edfbae6c73fbe11a`.

## Exact requested change

- **Semantic key:** `participant.settings.support.body`
- **EN (unchanged):** For help with your account or access, visit Help.
- **AF (previous):** Gaan na Hulp as jy hulp met jou rekening of toegang nodig het.
- **AF (approved):** Gaan na "Hulp" as jy hulp met jou rekening of toegang nodig het.
- **Approved EN digest:** `ab28f9c4ef14e3aa9b8bfa266cbd64c6ad9047d186b218bcace1df02e49ee6d9`
- **Approved AF digest:** `3ee774807e587f0ebe4cb446925f324e273cb3536339bafdac5ea06800bc4ac2`

The navigation label is enclosed in straight double quotes, exactly as the owner proposed. No English text or other Afrikaans text changed.

## Full approved strings

| Semantic key | English | Afrikaans |
|---|---|---|
| `participant.settings.overview.title` | Your settings | Jou instellings |
| `participant.settings.overview.body` | Manage your account details, language and security in one place. | Bestuur jou rekeningbesonderhede, taal en sekuriteit op een plek. |
| `participant.settings.account.title` | Account details | Rekeningbesonderhede |
| `participant.settings.account.body` | View your personal details and email address. | Bekyk jou persoonlike besonderhede en e-posadres. |
| `participant.settings.account.action` | View account details | Bekyk rekeningbesonderhede |
| `participant.settings.language.body` | Choose the language you use for menus and account settings. | Kies die taal wat jy vir kieslyste en rekeninginstellings gebruik. |
| `participant.settings.language.action` | Open language preferences | Maak taalvoorkeure oop |
| `participant.settings.security.title` | Account security | Rekeningsekuriteit |
| `participant.settings.security.body` | Review how you sign in and manage access to your account. | Gaan jou aanmeldopsies en rekeningtoegang na. |
| `participant.settings.security.password.title` | Password and sign-in | Wagwoord en aanmelding |
| `participant.settings.security.password.body` | Find available ways to sign in or reset your password. | Vind beskikbare maniere om aan te meld of jou wagwoord te herstel. |
| `participant.settings.security.step_up.notice` | Some security changes require you to confirm your identity again. | Vir sekere sekuriteitsveranderinge moet jy weer jou identiteit bevestig. |
| `participant.settings.privacy.title` | Privacy and data | Privaatheid en data |
| `participant.settings.privacy.body` | Find information about privacy choices and requests involving your personal data. | Kry inligting oor privaatheidskeuses en versoeke wat jou persoonlike data raak. |
| `participant.settings.support.title` | Need help? | Het jy hulp nodig? |
| `participant.settings.support.body` | For help with your account or access, visit Help. | Gaan na "Hulp" as jy hulp met jou rekening of toegang nodig het. |
| `participant.settings.support.action` | Open Help | Maak Hulp oop |
| `participant.settings.load.processing` | Loading your settings… | Besig om jou instellings te laai… |
| `participant.settings.load.unavailable.title` | Settings unavailable | Instellings nie beskikbaar nie |
| `participant.settings.load.unavailable.body` | We can’t load your current settings. Please try again. | Ons kan nie jou huidige instellings laai nie. Probeer asseblief weer. |
| `participant.settings.load.uncertain` | We can’t confirm which settings are currently available. Refresh before making changes. | Ons kan nie bevestig watter instellings tans beskikbaar is nie. Herlaai voordat jy veranderinge maak. |
| `participant.settings.load.stale.title` | Your account settings have changed | Jou rekeninginstellings het verander |
| `participant.settings.load.stale.body` | Some details have changed since you opened this page. Refresh to see the latest information. | Sommige besonderhede het verander sedert jy hierdie bladsy oopgemaak het. Herlaai om die jongste inligting te sien. |
| `participant.settings.load.refresh.action` | Refresh settings | Herlaai instellings |
| `participant.settings.access.reauth.title` | Sign in again | Meld weer aan |
| `participant.settings.access.reauth.body` | Your sign-in is no longer valid. Sign in again to view these settings. | Jou aanmelding is nie meer geldig nie. Meld weer aan om hierdie instellings te sien. |
| `participant.settings.access.reauth.action` | Go to sign-in | Gaan na aanmelding |
| `participant.settings.access.restricted.title` | Some settings are unavailable | Sommige instellings is nie beskikbaar nie |
| `participant.settings.access.restricted.body` | Only settings currently available to your account are shown. | Net instellings wat tans vir jou rekening beskikbaar is, word gewys. |

## Existing keys reused without changing their source

- `shared.navigation.settings`
- `shared.navigation.profile`
- `shared.navigation.login`
- `shared.navigation.help`
- `shared.action.retry`
- `participant.profile.overview.title`
- `participant.profile.email_change.help`
- `participant.language.page.title`
- `participant.language.content.help`
- `identity.mfa.settings.title`
- `identity.mfa.settings.body`
- `identity.sessions.page.title`
- `identity.sessions.page.body`
- `identity.trusted_devices.page.title`
- `identity.trusted_devices.page.body`

## Semantic and lifecycle boundaries

- **Scope:** Participant Account Settings overview/navigation only. It composes current Account, Language, Profile, MFA, Session/Device and Privacy surface links without becoming those Domains' business authority.
- **Availability:** Only available, currently authorised features appear. No placeholder navigation that promises unimplemented password, Privacy, export or account operations.
- **Truth ownership:** Identity & Access owns Account, credential, Session, device, step-up and access checks. Privacy & Consent owns privacy choices and data rights. Content & Media owns the immutable wording and its version.
- **Presentation lifecycle:** `loading → ready / unavailable / reauth_required`, `ready → stale / restricted / unavailable / reauth_required`, `stale → ready` only after a fresh authorised read. Frontend state never authorises business writes.
- **Guards and failure/recovery:** A stale session requires new sign-in, an unavailable source requires truthful unavailable/retry copy, and changed authority requires a refresh before sensitive actions. Repeated reads create no business consequences.
- **Content lifecycle:** Draft → candidate → development-approved → production-approved → superseded/withdrawn, subject to applicable approvals. No changes to an immutable approved version in place; changed exact bytes require a successor. Superseded and withdrawn versions cannot be selected for new use; conflicting decisions require reconciliation, never last-write-wins.
- **Approval:** The one owner decision is recorded once. It does not imply independent specialist approvals or enable production/content-runtime eligibility.
- **No implementation:** No code, route, feature toggle, schema, migration, CI/governance law or Product semantics are changed by this copy approval.

## Version integrity

- 29 exact new semantic keys / 58 locale strings (29 EN + 29 AF).
- 57/58 locale strings unchanged; exactly 1 owner-edited Afrikaans body.
- 15 pre-existing semantic-key references preserved, without changing their approved/source status.
- Approved JSON SHA-256: `6d4778e028e6d4b1bed2d28e8b5d7669d170ac38660c25a4c182bef181334c35`.
