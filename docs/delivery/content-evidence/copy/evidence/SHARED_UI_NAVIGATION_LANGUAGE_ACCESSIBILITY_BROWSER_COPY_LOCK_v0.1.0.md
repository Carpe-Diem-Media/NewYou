# Shared UI Navigation, Language & Accessibility — owner-approved EN/AF v0.1.0

**Owner approval:** 2026-11-17, complete version v0.1.0 approved in conversation.
**Approved source candidate SHA-256:** `33b62f93cfae1a6ed7094c70f031a99ba05252692e4565b5d24d087c03362c38`.
**Derived owner-approved packet SHA-256:** `bfe81c50912a323f6ca1456b60d5cb76fff6969e6bccec592dc99cb320ce2f41`.
**Source registry blob:** `7a25a11bedccead4bc59abbbf9da9d5b35ef3c28`; source records remain candidates until a separate authorised registry integration.
**Reconnaissance baseline:** `main@5fe3455f00ead029b354c426359d9fae6abc59bf`; re-check main before branch/PR creation.
**PR status:** NOT OPENED. Authenticated connected GitHub actor was `JCSchoeman96`, not the repository-required `JC-Agents`.
**Scope:** 28 existing Class B semantic keys / 56 bilingual strings; 26 unchanged key pairs, 2 paired wording refinements; no new keys.

## Complete exact owner-approved copy

| Semantic key | English | Afrikaans | Registry comparison |
| --- | --- | --- | --- |
| `shared.language.afrikaans` | Afrikaans | Afrikaans | UNCHANGED |
| `shared.language.english` | English | Engels | UNCHANGED |
| `shared.language.change` | Change language | Verander taal | UNCHANGED |
| `shared.language.saved` | Language saved | Taal gestoor | UNCHANGED |
| `shared.language.unavailable.title` | Translation unavailable | Vertaling nie beskikbaar nie | UNCHANGED |
| `shared.language.unavailable.body` | This content isn't available in your selected language. | Hierdie inhoud is nie in jou gekose taal beskikbaar nie. | TWO_LOCALE_WORDING_REFINEMENT |
| `shared.language.unavailable.action` | Choose an available language | Kies ’n beskikbare taal | TWO_LOCALE_WORDING_REFINEMENT |
| `shared.language.required_unavailable` | Required content is unavailable in your selected language. Please try again later. | Vereiste inhoud is nie in jou gekose taal beskikbaar nie. Probeer asseblief later weer. | UNCHANGED |
| `shared.navigation.home` | Home | Tuis | UNCHANGED |
| `shared.navigation.content` | Content | Inhoud | UNCHANGED |
| `shared.navigation.programmes` | Programmes | Programme | UNCHANGED |
| `shared.navigation.products` | Products | Produkte | UNCHANGED |
| `shared.navigation.about` | About | Meer oor ons | UNCHANGED |
| `shared.navigation.help` | Help | Hulp | UNCHANGED |
| `shared.navigation.contact` | Contact | Kontak | UNCHANGED |
| `shared.navigation.search` | Search | Soek | UNCHANGED |
| `shared.navigation.create_account` | Create account | Skep rekening | UNCHANGED |
| `shared.navigation.login` | Log in | Meld aan | UNCHANGED |
| `shared.navigation.logout` | Log out | Meld af | UNCHANGED |
| `shared.navigation.plan` | Plan | Plan | UNCHANGED |
| `shared.navigation.progress` | Progress | Vordering | UNCHANGED |
| `shared.navigation.profile` | Profile | Profiel | UNCHANGED |
| `shared.navigation.settings` | Settings | Instellings | UNCHANGED |
| `shared.action.search` | Search | Soek | UNCHANGED |
| `shared.action.contact_support` | Contact support | Kontak ondersteuning | UNCHANGED |
| `shared.accessibility.skip` | Skip to main content | Slaan oor na hoofinhoud | UNCHANGED |
| `shared.accessibility.open_menu` | Open menu | Maak kieslys oop | UNCHANGED |
| `shared.accessibility.close_menu` | Close menu | Maak kieslys toe | UNCHANGED |

## Source-to-approved wording changes

### `shared.language.unavailable.body`
- Original EN: This content isn't available in your selected language yet.
- Owner-approved EN: This content isn't available in your selected language.
- Original AF: Hierdie inhoud is nog nie in jou gekose taal beskikbaar nie.
- Owner-approved AF: Hierdie inhoud is nie in jou gekose taal beskikbaar nie.
- Rationale: Avoid implying that a translation is guaranteed to arrive later.

### `shared.language.unavailable.action`
- Original EN: View available language
- Owner-approved EN: Choose an available language
- Original AF: Bekyk beskikbare taal
- Owner-approved AF: Kies ’n beskikbare taal
- Rationale: Describe the explicit user choice rather than a passive view; availability must be established by the Content owner.

## Governing display guards

- Labels are reusable presentation strings only: show a navigation destination only when the actual route, feature, environment, Identity state and authorization allow it. Programmes, Products, Plan, Progress and other future areas remain hidden or unavailable until independently approved.
- Account, Profile, Settings, Log out and other protected links require current Identity-owned access. Unknown/stale sign-in status must not be represented as signed-out or signed-in authority.
- Language saved may be announced only after the owning preference/presentation state has been confirmed. Failed, unknown and in-progress states use separately approved contextual wording; never display success optimistically.
- The optional-language-unavailable offer applies only to eligible low-risk public editorial versions where the Content owner confirms an approved published alternate locale and the visitor explicitly selects it.
- For required bilingual core, safety, consent, privacy or other governed content, a missing selected locale fails closed; do not show a language-switch option as a workaround and never silently substitute text or machine translate.
- Search action appears only if its actual search path is eligible and functioning. Contact support appears only when a supported and currently available contact route/channel exists.
- Skip to main content must target an actual main-content landmark. Open/close menu names must correspond to keyboard-operable controls and accurate expanded/collapsed state.
- These accessible action names do not by themselves prove accessibility conformance, and generic labels for dialogs, charts or tables are deliberately outside this scope.
- Do not hardcode the public brand, service uptime, available programmes/products, contact channels, support SLAs or unpublished content.

## Excluded scope

- Runtime registry mutation or approval of unselected shared candidate keys.
- New public page/route, content discovery backend, support ticket or contact provider, Account, entitlement, publication or locale authority.
- Full generic accessibility labels for dialog/table/chart, chart alt text or accessibility conformance certification.
- Class A legal/consent/safety/health/commercial wording and any change to already approved FP-001 registration/verification copy.
- Production publication, feature activation, release, implementation PR or merge authorization.

## Lifecycle and owner boundary

- Reversible language selection and optional published-editorial alternate-locale presentation remain exactly as specified in the source candidate `presentation_lifecycle` object.
- Approval is wording evidence only; it does not make a candidate runtime-eligible, publish a Content version, authorize new routes, grant access, certify accessibility, or permit a merge.
- Required bilingual and governed Content must fail closed if the required locale is missing. No silent fallback, no auto-translation.
- Separately verify CI and independent exact-head code-owner review before any authorised integration.
