# FP-001 — Account-access Help EN/AF owner-approved copy v0.1.1

**Status:** Owner-approved platform wording for bounded non-production development only after canonical integration. Not production, pilot, implementation or real-participant permission.
**Exact JSON SHA-256:** `91eaddd8c2fa82cbdf415ea5a19da6f258fb4ef10371724c3563bd6e8b988d83`
**Source candidate SHA-256:** `231a67384ad9055d99e16ce4054f64f7a3561e5efda828d07aae3b1f1f2c785b`
**Authoritative base:** `d1d09031e6995952277d2bb1dcc49d555be21ad4`

## Owner correction: Afrikaans missing-verification-email guidance

- Key: `support.account_help.verification.missing.body`
- Earlier Afrikaans: Gaan jou inkassie en gemorspos na. As daar ’n opsie is om weer te stuur, vra nog ’n verifikasie-e-pos aan.
- **Approved rendered Afrikaans: Gaan jou e-posse na (kyk ook in jou *Spam*). As daar ’n opsie is om weer te stuur, vra nog ’n verifikasie-e-pos aan.**
- Canonical raw text (without formatting markers): `Gaan jou e-posse na (kyk ook in jou Spam). As daar ’n opsie is om weer te stuur, vra nog ’n verifikasie-e-pos aan.`
- **`Spam` must appear in italics.** JSON records a Unicode-code-point semantic emphasis span. The `*Spam*` Markdown here is for review display only, not literal UI text.
- English at the same key and the other 48 strings remain unchanged.

## Complete exact bilingual copy

| Semantic key | English | Afrikaans |
|---|---|---|
| `support.account_help.page.title` | Help with your account | Hulp met jou rekening |
| `support.account_help.page.body` | Find guidance for signing in, verifying your email address and keeping access to your account. | Kry hulp met aanmelding, e-posverifikasie en toegang tot jou rekening. |
| `support.account_help.options.title` | What do you need help with? | Waarmee het jy hulp nodig? |
| `support.account_help.signin.title` | Signing in | Aanmelding |
| `support.account_help.signin.body` | If you cannot sign in, check the email address and password you entered. You can use an available password-reset option if needed. | As jy nie kan aanmeld nie, gaan die e-posadres en wagwoord na wat jy ingevul het. Jy kan ook ’n beskikbare wagwoordherstelopsie gebruik. |
| `support.account_help.signin.action` | Open sign-in page | Maak die aanmeldbladsy oop |
| `support.account_help.verification.title` | Verify your email address | Verifieer jou e-posadres |
| `support.account_help.verification.body` | If you have a verification email, open its link and choose "Verify email". Opening the page alone does not verify your address. | As jy ’n verifikasie-e-pos het, maak die skakel daarin oop en kies "Verifieer e-posadres". Om net die bladsy oop te maak, verifieer nie jou adres nie. |
| `support.account_help.verification.missing.title` | Didn't receive a verification email? | Het jy nie ’n verifikasie-e-pos ontvang nie? |
| `support.account_help.verification.missing.body` | Check your inbox and junk folder. If a resend option is available, request another verification email. | Gaan jou e-posse na (kyk ook in jou *Spam*). As daar ’n opsie is om weer te stuur, vra nog ’n verifikasie-e-pos aan. |
| `support.account_help.password.title` | Reset your password | Herstel jou wagwoord |
| `support.account_help.password.body` | If you've forgotten your password, use the password-reset option on the sign-in page. Requesting a reset does not change your password. | As jy jou wagwoord vergeet het, gebruik die wagwoordherstelopsie op die aanmeldbladsy. Om wagwoordherstel aan te vra, verander nie jou wagwoord nie. |
| `support.account_help.password.action` | Open password reset | Maak wagwoordherstel oop |
| `support.account_help.mfa.body` | If you cannot use your verification app, use an available recovery option or contact support. This Help page cannot bypass a required security check. | As jy nie jou verifikasie-app kan gebruik nie, gebruik ’n beskikbare herstelopsie of kontak ondersteuning. Hierdie Hulp-bladsy kan nie ’n verpligte sekuriteitskontrole omseil nie. |
| `support.account_help.mfa.lost.title` | Lost access to all your verification methods? | Het jy toegang tot al jou verifikasiemetodes verloor? |
| `support.account_help.mfa.lost.body` | Contact support to find out which recovery steps are available. Contacting support does not by itself restore account access. | Kontak ondersteuning om uit te vind watter herstelstappe beskikbaar is. Deur ondersteuning te kontak, kry jy nie vanself weer toegang tot jou rekening nie. |
| `support.account_help.security.title` | Concerned about account security? | Bekommerd oor jou rekening se sekuriteit? |
| `support.account_help.security.body` | If you think someone else accessed your account, use any available security options and contact support. Account changes may require another identity check. | As jy vermoed dat iemand anders toegang tot jou rekening gehad het, gebruik enige beskikbare sekuriteitsopsies en kontak ondersteuning. Jy sal dalk weer jou identiteit moet bevestig voordat rekeningveranderinge aangebring kan word. |
| `support.account_help.contact.title` | Ask for account help | Vra hulp met jou rekening |
| `support.account_help.contact.body` | Use an available support channel if the account-help options do not solve your problem. | Gebruik ’n beskikbare ondersteuningskanaal as die opsies vir rekeninghulp nie jou probleem oplos nie. |
| `support.account_help.contact.sensitive_warning` | Never share your password, verification codes, sign-in or recovery links, or your verification app's secret key with support. | Moet nooit jou wagwoord, verifikasiekodes, aanmeld- of herstelskakels of die geheime sleutel van jou verifikasie-app met ondersteuning deel nie. |
| `support.account_help.contact.authority_boundary` | Contacting support does not verify your identity or authorise account changes. | Kontak met ondersteuning bevestig nie jou identiteit nie en magtig nie rekeningveranderinge nie. |
| `support.account_help.state.loading` | Loading account help… | Besig om rekeninghulp te laai… |
| `support.account_help.state.unavailable` | Account help is temporarily unavailable. Try again later or use another available help option. | Rekeninghulp is tydelik nie beskikbaar nie. Probeer later weer of gebruik ’n ander beskikbare hulpopsie. |
| `support.account_help.state.stale` | Available help options have changed. Refresh to see what's available now. | Die beskikbare hulpopsies het verander. Herlaai die bladsy om te sien wat nou beskikbaar is. |

## Existing semantic keys reused without changes

| Key | English | Afrikaans |
|---|---|---|
| `shared.navigation.help` | Help | Hulp |
| `shared.navigation.login` | Log in | Meld aan |
| `shared.navigation.settings` | Settings | Instellings |
| `shared.action.contact_support` | Contact support | Kontak ondersteuning |
| `shared.action.retry` | Try again | Probeer weer |
| `identity.mfa.settings.title` | Two-step verification | Tweestapverifikasie |
| `identity.verification.result.confirm.action` | Verify email | Verifieer e-posadres |

## Domain, lifecycle and rendering requirements

- Content & Media owns immutable bilingual versions and their approval. Identity & Access owns identity, proof, recovery and security mutations; Support provides no general identity override.
- Help presentation states remain `loading → ready / unavailable`, with `ready → stale` on changed route eligibility; navigation requires fresh availability. Retry and refresh are read-only.
- Viewing Help does not confirm an email, recover Account access, log in, establish a Session, create a support ticket or approve a protected action.
- No new SupportCase or ticket lifecycle is authorised. No response-time or support-availability claims are introduced.
- Do not display `*` delimiters. A UI may use structured inline text to set semantic italics for `Spam`; if unsupported, JIT implementation must add safe rendering instead of silently losing the owner-approved styling.
- Owner-approved exact wording is eligible for bounded non-production development after integration only. Actual product code, legal/specialist sign-off and production/real-participant rollout require their own gates.
- Existing candidate bytes remain immutable. Future corrections require a successor version, pinned locale digests and new owner approval. Conflicting approvals do not use last-write-wins.

## Change count and integrity

- 25 new keys; 50 EN/AF strings; 49/50 locale strings exactly preserved.
- 7 reused semantic-key references remain unchanged.
- One Afrikaans text/digest changed; one required italic presentation span added to the same key.
- Approved packet SHA-256: `91eaddd8c2fa82cbdf415ea5a19da6f258fb4ef10371724c3563bd6e8b988d83`.
