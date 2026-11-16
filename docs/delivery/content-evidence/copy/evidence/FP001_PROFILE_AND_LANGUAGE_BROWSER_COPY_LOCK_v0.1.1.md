# FP-001 — Profile and language preferences: exact owner-approved EN/AF copy v0.1.1

**Decision:** Owner approved the proposed Profile and Language text, with one specific correction: use **“Naam”** for the Afrikaans Profile first-name field. The rest is unchanged.
**Status:** Owner-approved NewYou platform wording, pending canonical integration; production/release and implementation permission are separate.
**Exact approved JSON SHA-256:** `271b6374820b7864adb682b11a4935fad7974fb0222089c00c671f789ee2fbc6`
**Original candidate SHA-256:** `d6baa99e2668692aed6d60a4d54eb653117251924d31ec0b4cb79881bce8f345`
**Baseline main:** `72f7ab0a30228f46e63b33dedc7323c5e7d1655e`
**Decision evidence:** Owner's 2026-11-16 message: `First name can stay "Naam". I approve and authorize the text and opening of a PR`.

## Owner correction and boundary

| Scope | Semantic key | English | Afrikaans |
|---|---|---|---|
| **Profile (new approved key)** | `participant.profile.details.first_name.label` | First name | **Naam** |
| Registration (existing, not modified) | `identity.registration.first_name.label` | First name | Voornaam |

This version adds a **Profile-specific field label**. It does **not** silently rewrite the separately approved registration wording or the current `COPY_REGISTRY.json`. Any later harmonisation of registration and Profile requires a separate exact decision.

## A. Exact approved Profile strings (16 semantic keys)

| Semantic key | English | Afrikaans |
|---|---|---|
| `participant.profile.overview.title` | Your profile | Jou profiel |
| `participant.profile.overview.body` | Keep your personal details and language preference up to date. | Hou jou persoonlike besonderhede en taalvoorkeur op datum. |
| `participant.profile.details.title` | Personal details | Persoonlike besonderhede |
| `participant.profile.details.first_name.label` | First name | Naam |
| `participant.profile.details.edit.action` | Edit details | Wysig besonderhede |
| `participant.profile.details.save.processing` | Saving your details… | Besig om jou besonderhede te stoor… |
| `participant.profile.details.save.confirmed` | Your details have been saved. | Jou besonderhede is gestoor. |
| `participant.profile.details.save.failed` | We couldn't save your details. Check them and try again. | Ons kon nie jou besonderhede stoor nie. Gaan dit na en probeer weer. |
| `participant.profile.details.save.uncertain` | We couldn't confirm whether your changes were saved. Check your current details before trying again. | Ons kon nie bevestig of jou veranderinge gestoor is nie. Gaan jou huidige besonderhede na voordat jy weer probeer. |
| `participant.profile.details.save.stale` | Your details have changed. Reload them before saving again. | Jou besonderhede het verander. Laai dit weer voordat jy weer stoor. |
| `participant.profile.email_change.help` | To change your email address, complete the separate security checks. | Om jou e-posadres te verander, voltooi die afsonderlike sekuriteitskontroles. |
| `participant.profile.email_status.unverified` | Email address not yet verified | E-posadres nog nie geverifieer nie |
| `participant.profile.email_status.unavailable` | We can't confirm your email verification status right now. | Ons kan nie tans die verifikasiestatus van jou e-posadres bevestig nie. |
| `participant.profile.unsaved.title` | Leave without saving? | Gaan weg sonder om te stoor? |
| `participant.profile.unsaved.body` | Your latest changes haven't been saved. | Jou jongste veranderinge is nog nie gestoor nie. |
| `participant.profile.unsaved.discard.action` | Discard changes | Gooi veranderinge weg |

## B. Exact approved Language strings (8 semantic keys)

| Semantic key | English | Afrikaans |
|---|---|---|
| `participant.language.page.title` | Language preferences | Taalvoorkeure |
| `participant.language.page.body` | Choose the language you want to use for NewYou's menus and account screens. | Kies die taal waarin jy NewYou se kieslyste en rekeningskerms wil gebruik. |
| `participant.language.content.help` | You can still open content in another language where it is available. | Jy kan steeds inhoud in ’n ander taal oopmaak waar dit beskikbaar is. |
| `participant.language.before_sign_in.help` | Before you sign in, your language choice is stored in this browser. After you register or sign in, it is saved to your profile. | Voordat jy aanmeld, word jou taalkeuse in hierdie blaaier gestoor. Nadat jy registreer of aanmeld, word dit in jou profiel gestoor. |
| `participant.language.save.processing` | Saving your language choice… | Besig om jou taalkeuse te stoor… |
| `participant.language.save.failed` | We couldn't save your language choice. Try again. | Ons kon nie jou taalkeuse stoor nie. Probeer weer. |
| `participant.language.save.uncertain` | We couldn't confirm whether your language choice was saved. Check your preference before trying again. | Ons kon nie bevestig of jou taalkeuse gestoor is nie. Gaan jou voorkeur na voordat jy weer probeer. |
| `participant.language.save.stale` | Your language preference has changed. Reload it before saving again. | Jou taalvoorkeur het verander. Laai dit weer voordat jy weer stoor. |

## C. Existing semantic keys to reuse (15, without changing approval status)

| Semantic key | English | Afrikaans |
|---|---|---|
| `shared.navigation.profile` | Profile | Profiel |
| `shared.navigation.settings` | Settings | Instellings |
| `identity.registration.surname.label` | Surname | Van |
| `identity.registration.email.label` | Email address | E-posadres |
| `identity.registration.preferred_language.label` | Preferred language | Voorkeurtaal |
| `shared.language.afrikaans` | Afrikaans | Afrikaans |
| `shared.language.english` | English | Engels |
| `shared.language.change` | Change language | Verander taal |
| `shared.language.saved` | Language saved | Taal gestoor |
| `shared.language.required_unavailable` | Required content is unavailable in your selected language. Please try again later. | Vereiste inhoud is nie in jou gekose taal beskikbaar nie. Probeer asseblief later weer. |
| `shared.action.save_changes` | Save changes | Stoor veranderinge |
| `shared.action.cancel` | Cancel | Kanselleer |
| `shared.action.retry` | Try again | Probeer weer |
| `identity.verification.result.verified.title` | Email verified | E-posadres geverifieer |
| `identity.change_email.start.title` | Change your email address | Verander jou e-posadres |

## Lifecycle and safety boundaries

- Product §7.3 and DEC-028 mandate Afrikaans/English, local language choice before authentication, a saved Account preference after registration/sign-in, and an accessible header language switch.
- Identity remains the only owner of Account fields, verification and guarded email changes; owner approval of UI words does not implement an edit action, session, access or mutation.
- Profile save: view → edit → save requested → confirmed / validation failure / operation failure / uncertain / stale. Only confirmed authoritative Identity success may show a saved claim; retry/conflicts must re-read current source.
- Language save: local selection before sign-in; authenticated preference change persists only through an authorised Identity action. A visible menu change alone is not proof of persistence.
- Content language may differ from interface language; missing required EN/AF wording fails visibly, never silently switches locales.
- Canonical email remains read-only in ordinary profile-edit; the separate primary-email-change security lifecycle continues to govern changes.
- Copy version lifecycle: draft → candidate → development_approved → production_approved → superseded/withdrawn; never mutate prior approved bytes. New consumption of superseded/withdrawn versions is prohibited. Repeated same version/hash decisions are idempotent; conflicts require reconciliation, not last-write-wins.
- No new implementation ticket, feature deployment, public release, pilot, runtime role or production permission is created by this PR.
- The founder's one-off authorisation to open this **content-evidence PR** does not waive exact-head CI, independent review or merge restrictions.

## Exact version lock

- Approved packet: `FP001_PROFILE_AND_LANGUAGE_BROWSER_COPY_APPROVED_v0.1.1.json`
- Approved packet complete-file SHA-256: `271b6374820b7864adb682b11a4935fad7974fb0222089c00c671f789ee2fbc6` (UTF-8; LF; one final LF)
- Source candidate complete-file SHA-256: `d6baa99e2668692aed6d60a4d54eb653117251924d31ec0b4cb79881bce8f345`
- 24 new approved semantic keys; 48 locale strings; all 46 previously proposed locale values unchanged; two additional first-name label strings added.
- 15 existing source keys reused without changing their statuses or bytes.
