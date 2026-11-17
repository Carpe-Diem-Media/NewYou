# FP-001 — Public website header and footer: owner-approved EN/AF browser copy v0.1.1

**Status:** Exact owner-approved NewYou browser copy for bounded future non-production development after canonical integration. No implementation, runtime, public publication, release or merge authority.
**Owner approval:** 2026-11-17, explicit approval of all 27 proposed keys / 54 EN+AF strings and authorisation to open a content-only PR.
**Candidate SHA-256:** `1d32ed9ad2e2646160c186f99b51710a92b6af8f9b3924e40f482f51bf5d0e09`.
**Approved packet SHA-256:** `32dc444c5dcf2a6838b02ac62294453f853abc327262a42170b45256d718f6b4`.
**Source baseline:** `main` `b028ab729e84dc3dfdff31fe9fde208a971a999a`.

## Copy approval

- **27 semantic keys / 54 EN+AF strings:** exact candidate wording retained without change.
- **24 reusable shared/approved keys:** references retained unchanged; candidate-status registry keys are not silently promoted by this approval.
- **25 Class B keys; 2 Class A legal-status/notice keys** retain their applicability and safety/legal visibility guards.
- No actual links, routes, operating hours, contact details, copyright ownership, social accounts or unfinished features are approved or made available.

## Complete exact approved wording

| Semantic key | English | Afrikaans |
| --- | --- | --- |
| `public.shell.header.main_navigation.label` | Main navigation | Hoofnavigasie |
| `public.shell.header.brand.home.aria_label` | Go to the {{platform_name}} home page | Gaan na {{platform_name}} se tuisblad |
| `public.shell.header.menu.title` | Menu | Kieslys |
| `public.shell.header.account.title` | Your account | Jou rekening |
| `public.shell.header.account.checking` | Checking your sign-in status… | Besig om jou aanmeldstatus na te gaan… |
| `public.shell.header.account.unavailable` | We can’t confirm your sign-in status right now. You can still explore available public pages. | Ons kan nie tans jou aanmeldstatus bevestig nie. Jy kan steeds beskikbare openbare bladsye verken. |
| `public.shell.header.account.retry.action` | Check sign-in status again | Gaan aanmeldstatus weer na |
| `public.shell.header.language.label` | Website language | Webwerftaal |
| `public.shell.header.language.help` | Choose Afrikaans or English for this website. | Kies Afrikaans of Engels vir hierdie webwerf. |
| `public.shell.header.language.current.announcement` | Current language: {{language_name}} | Huidige taal: {{language_name}} |
| `public.shell.header.language.changing` | Changing language… | Besig om taal te verander… |
| `public.shell.header.language.failed` | Your language choice could not be applied. Try again. | Jou taalkeuse kon nie toegepas word nie. Probeer weer. |
| `public.shell.header.language.uncertain` | We can’t confirm whether your language choice was applied. Check the language shown before continuing. | Ons kan nie bevestig of jou taalkeuse toegepas is nie. Gaan die taal wat vertoon word na voordat jy voortgaan. |
| `public.shell.navigation.breadcrumb.label` | Breadcrumb navigation | Broodkrummelnavigasie |
| `public.shell.navigation.current_page.announcement` | Current page: {{page_title}} | Huidige bladsy: {{page_title}} |
| `public.shell.navigation.unavailable` | Navigation is temporarily unavailable. Refresh this page to try again. | Navigasie is tydelik nie beskikbaar nie. Herlaai hierdie bladsy om weer te probeer. |
| `public.shell.footer.tagline` | Understand yourself. Build habits that fit real life. | Verstaan jouself. Bou gewoontes wat by jou lewe pas. |
| `public.shell.footer.explore.title` | Explore | Ontdek |
| `public.shell.footer.account.title` | Account | Rekening |
| `public.shell.footer.help.title` | Help and support | Hulp en ondersteuning |
| `public.shell.footer.legal.title` | Legal information | Regsinligting |
| `public.shell.footer.terms.link` | Terms and Conditions | Bepalings en Voorwaardes |
| `public.shell.footer.privacy.link` | Privacy Notice | Privaatheidsbeleid |
| `public.shell.footer.legal.language_notice` | The governing Terms and Privacy Notice are available in English. | Die geldende Bepalings en Voorwaardes en Privaatheidsbeleid is in Engels beskikbaar. |
| `public.shell.footer.help.body` | Looking for help? See what guidance is available on the Help page. | Soek jy hulp? Kyk watter leiding op die Hulp-blad beskikbaar is. |
| `public.shell.footer.back_to_top.action` | Back to top | Terug na bo |
| `public.shell.footer.legal.unavailable` | {{document_name}} is not available right now. Try again later. | {{document_name}} is tans nie beskikbaar nie. Probeer later weer. |

## Existing keys referenced unchanged

- `shared.navigation.home` — source status: `candidate`
- `shared.navigation.content` — source status: `candidate`
- `shared.navigation.programmes` — source status: `candidate`
- `shared.navigation.products` — source status: `candidate`
- `shared.navigation.about` — source status: `candidate`
- `shared.navigation.help` — source status: `candidate`
- `shared.navigation.contact` — source status: `candidate`
- `shared.navigation.search` — source status: `candidate`
- `shared.navigation.create_account` — source status: `candidate`
- `shared.navigation.login` — source status: `candidate`
- `shared.navigation.logout` — source status: `candidate`
- `shared.navigation.profile` — source status: `candidate`
- `shared.navigation.settings` — source status: `candidate`
- `shared.language.afrikaans` — source status: `candidate`
- `shared.language.english` — source status: `candidate`
- `shared.language.change` — source status: `candidate`
- `shared.language.saved` — source status: `candidate`
- `shared.language.required_unavailable` — source status: `candidate`
- `shared.accessibility.skip` — source status: `candidate`
- `shared.accessibility.open_menu` — source status: `candidate`
- `shared.accessibility.close_menu` — source status: `candidate`
- `shared.action.contact_support` — source status: `candidate`
- `public.home.availability.section.title` — source status: `owner_approved`
- `public.home.availability.section.body` — source status: `owner_approved`

## Presentation guards

- The header/footer is a composition of available destinations, not permission to publish or surface unfinished products, programmes, paid services, assessment, health intake, plans or other gated areas.
- Only present a link when the corresponding target route actually exists and is approved/eligible for the current environment; never route to development-only legal baselines for public/production use.
- Registration, signed-in account, profile and settings links depend on current Identity state and actual allowed routes; a stale browser or unknown session state is not access authority.
- An unknown sign-in status never means signed out; public-safe navigation may remain visible but protected actions must fail closed until current authority is known.
- Required core bilingual/legal/safety presentation must not silently fall back to an unapproved locale; optional low-risk public content can offer an explicitly identified available language only where authorized.
- The English governing Terms and Privacy document bodies remain singular; Afrikaans UI uses the approved descriptor Privaatheidsbeleid, not a purported Afrikaans legal body.
- The legal-link unavailable state is a truthful UI projection, not a substitute for approved Terms/Privacy or consent and not permission to create an Account.
- The footer tagline is thematic, not a promise of active assessments, plans, memberships, support response times or clinical outcomes.
- Do not add brand-specific copyright ownership, dates, address, opening hours, social accounts, accessibility statement links or contact details until their factual provenance and launch eligibility are verified.
- Do not use Christian/Christelike in the prominent header/footer tagline; approved secondary faith content on homepage/About remains unchanged.
- This exact wording is a non-production review candidate, not a production, release, legal approval, or code change.

## Source authority

- docs/governance/CURRENT_GOVERNANCE_ROUTER.json (current Product, Architecture, Domain and Roadmap)
- docs/governance/product/00_PLATFORM_v1.18.0.md §§21E.1, 21E.7, 21E.18, 21L.2–21L.4
- docs/delivery/feature-contracts/fp-001/FP-001_FINAL_FEATURE_PACK_CONTRACT_WORKING_v0.1.0.md §§D–G
- docs/delivery/content-evidence/copy/GOVERNANCE.md, GLOSSARY.md, STYLE_GUIDE.md, COPY_INVENTORY.md
- docs/delivery/content-evidence/copy/pages/public/public-shell.yaml
- docs/delivery/content-evidence/copy/evidence/FP001_PUBLIC_HOMEPAGE_FIRST_VISIT_BROWSER_COPY_APPROVED_v0.1.1.json
- docs/delivery/content-evidence/copy/evidence/FP001_PUBLIC_ABOUT_AND_PHILOSOPHY_BROWSER_COPY_APPROVED_v0.1.1.json

**Scope:** Owner content approval is not Content publication, legal approval, participant consent, routing authority, or release permission. Only the separately authorised content-only PR may be opened; all review, CI and merge safeguards remain applicable.
