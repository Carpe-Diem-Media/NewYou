# FP-001 — Contact Support EN/AF exact owner-approved copy v0.1.1

**Status:** Owner-approved NewYou platform copy; bounded non-production development use after canonical integration only. No implementation or release authorisation.
**Decision:** On 2026-11-16 the owner wrote: `approved and authorized to open a PR`.
**Exact source candidate SHA-256:** `8fbcb8a0b9f23b47a52e3008f6f1e5c173194fbe11d169ddef6760ed6f423778`
**Exact owner-approved JSON SHA-256:** `d2851c4792ec99d646d058cfd169b8d228ee4d387ef3141a6473c629d51c1e8c`
**Review baseline `main`:** `2736a9c6925c8c126cbba007f404b2e38ec2080d`.
**Scope:** 29 new semantic keys / 58 exact EN+AF strings; 10 existing key references reused with no changes.
**Changes to approved words:** Zero. All 58 source candidate locale values are identical.

## All exact owner-approved wording

| Semantic key | English | Afrikaans |
|---|---|---|
| `support.contact.form.intro.body` | Tell us what you need help with so we can understand your question. | Vertel ons waarmee jy hulp nodig het sodat ons jou vraag kan verstaan. |
| `support.contact.form.topic.label` | Choose a topic | Kies ’n onderwerp |
| `support.contact.form.topic.help` | Choose the option that best describes what you need help with. | Kies die opsie wat die beste beskryf waarmee jy hulp nodig het. |
| `support.contact.form.topic.unavailable` | That topic is no longer available. Choose another available option. | Daardie onderwerp is nie meer beskikbaar nie. Kies ’n ander beskikbare opsie. |
| `support.contact.form.subject.label` | Subject (optional) | Onderwerp (opsioneel) |
| `support.contact.form.details.label` | Tell us what happened | Vertel ons wat gebeur het |
| `support.contact.form.details.help` | Explain what you were trying to do and what happened. Please leave out passwords and verification codes. | Verduidelik wat jy probeer doen het en wat gebeur het. Moenie wagwoorde of verifikasiekodes insluit nie. |
| `support.contact.form.reply_email.label` | Email address for a reply | E-posadres vir terugvoer |
| `support.contact.form.reply_email.help` | Use an email address you can access. | Gebruik ’n e-posadres waartoe jy toegang het. |
| `support.contact.form.attachments.label` | Attachments (optional) | Aanhangsels (opsioneel) |
| `support.contact.form.attachments.help` | Add a file only if this option is available and it helps explain the problem. | Voeg slegs ’n lêer by as dié opsie beskikbaar is en dit help om die probleem te verduidelik. |
| `support.contact.form.attachments.sensitive_warning` | Do not attach identity documents, medical records or other sensitive information unless a separately approved secure process specifically asks for them. | Moenie identiteitsdokumente, mediese rekords of ander sensitiewe inligting aanheg tensy ’n afsonderlik goedgekeurde, veilige proses dit uitdruklik vereis nie. |
| `support.contact.form.attachments.failed` | The file couldn't be added. Try another file or send your message without it. | Die lêer kon nie bygevoeg word nie. Probeer ’n ander lêer of stuur jou boodskap daarsonder. |
| `support.contact.form.attachments.unavailable` | Attachments aren't available right now. You can continue without one. | Aanhangsels is tans nie beskikbaar nie. Jy kan sonder ’n aanhangsel voortgaan. |
| `support.contact.form.identity_check.notice` | We may need to verify your identity before discussing private account details or making account changes. | Ons sal dalk eers jou identiteit moet bevestig voordat ons privaat rekeningbesonderhede bespreek of rekeningveranderinge aanbring. |
| `support.contact.form.submit.action` | Send message | Stuur boodskap |
| `support.contact.form.submit.processing` | Sending your message… | Besig om jou boodskap te stuur… |
| `support.contact.form.submit.confirmed` | We've received your message. | Ons het jou boodskap ontvang. |
| `support.contact.form.submit.reference` | Reference: {{reference}} | Verwysing: {{reference}} |
| `support.contact.form.submit.reference.help` | Keep this reference if you need to follow up. | Hou hierdie verwysing byderhand as jy moet opvolg. |
| `support.contact.form.submit.failed` | We couldn't send your message. Check the information and try again. | Ons kon nie jou boodskap stuur nie. Gaan die inligting na en probeer weer. |
| `support.contact.form.submit.uncertain` | We couldn't confirm whether your message was received. Avoid sending it again immediately; use an available status or support option to check first. | Ons kon nie bevestig of jou boodskap ontvang is nie. Moenie dit dadelik weer stuur nie; gebruik eers ’n beskikbare status- of ondersteuningsopsie om na te gaan. |
| `support.contact.form.submit.already_received` | We've already received this message. | Ons het reeds hierdie boodskap ontvang. |
| `support.contact.form.submit.validation_needed` | Check the highlighted information before sending your message. | Gaan die aangeduide inligting na voordat jy jou boodskap stuur. |
| `support.contact.form.submit.stale` | The available contact options have changed. Reload them before sending your message. | Die beskikbare kontakopsies het verander. Laai dit weer voordat jy jou boodskap stuur. |
| `support.contact.form.submit.unavailable` | Messages can't be sent this way right now. Try another available support option. | Boodskappe kan tans nie op hierdie manier gestuur word nie. Probeer ’n ander beskikbare ondersteuningsopsie. |
| `support.contact.form.unsent.title` | Leave without sending? | Gaan weg sonder om te stuur? |
| `support.contact.form.unsent.body` | Your message hasn't been sent. | Jou boodskap is nog nie gestuur nie. |
| `support.contact.form.unsent.discard.action` | Discard message | Gooi boodskap weg |

## Reused existing keys (not modified or silently re-approved)

| Semantic key | English | Afrikaans | Original source state |
|---|---|---|---|
| `shared.action.contact_support` | Contact support | Kontak ondersteuning | candidate |
| `shared.navigation.contact` | Contact | Kontak | candidate |
| `shared.navigation.help` | Help | Hulp | candidate |
| `shared.action.cancel` | Cancel | Kanselleer | candidate |
| `shared.action.retry` | Try again | Probeer weer | candidate |
| `shared.action.upload` | Upload | Laai op | candidate |
| `shared.action.remove` | Remove | Verwyder | candidate |
| `shared.validation.required` | This field is required. | Hierdie veld is verpligtend. | candidate |
| `support.account_help.contact.sensitive_warning` | Never share your password, verification codes, sign-in or recovery links, or your verification app's secret key with support. | Moet nooit jou wagwoord, verifikasiekodes, aanmeld- of herstelskakels of die geheime sleutel van jou verifikasie-app met ondersteuning deel nie. | owner_approved |
| `support.account_help.contact.authority_boundary` | Contacting support does not verify your identity or authorise account changes. | Kontak met ondersteuning bevestig nie jou identiteit nie en magtig nie rekeningveranderinge nie. | owner_approved |

## Governing safety and lifecycle boundaries

- **Only content** is approved. The packet does not establish a SupportCase Domain, support ticket backend, form endpoint, response SLA, public/production support channel, provider, deployment or implementation authority.
- **Verified receipt is distinct from clicking Send.** Show `We've received your message.` / `Ons het jou boodskap ontvang.` only after authoritative receipt confirmation from an actually implemented owning channel.
- **Uncertain submission** is not a failure or success claim. Avoid blind re-submission; confirm the current source operation or reconciled outcome, with idempotent request identity if supported.
- **Existing support/security warnings are reused by semantic key**, with no duplicate approved content or newly granted authentication/recovery/step-up authority.
- **Optional attachments** remain hidden until independently approved secure upload and privacy handling exist; sensitive identity or medical documents are not requested by ordinary support copy.
- `{{reference}}` is only a display placeholder for an actual authoritative receipt reference. Never fabricate a reference.
- **Presentation states:** `editing → submitting → received_confirmed / not_sent / outcome_uncertain / stale / unavailable`, and `editing → discarded` only after confirmed discard intent. Uncertain is nonterminal. Guarded reread/retry and stale resolution cannot invent a source outcome.
- **Business SupportCase lifecycle** (states, guards, effects, idempotency, terminal status) is explicitly outside this content packet, not approved by implication.
- **Content lifecycle:** `draft → candidate → development_approved → production_approved → superseded / withdrawn`; immutable exact bytes, owner approval, no silent EN/AF fallback, conflict reconciliation and separate production/release gate.
- **Founder-authored content-only PR:** owner explicitly authorised opening this copy-evidence PR, as a disclosed exception to routine agent authorship; it is not independent code-owner review, routine preflight satisfaction, merge authority or CI waiver.

## Exact version and content provenance

- Candidate `FP001_CONTACT_SUPPORT_EN_AF_COPY_CANDIDATE_v0.1.0.json` SHA-256 `8fbcb8a0b9f23b47a52e3008f6f1e5c173194fbe11d169ddef6760ed6f423778`.
- Approved `FP001_CONTACT_SUPPORT_BROWSER_COPY_APPROVED_v0.1.1.json` SHA-256 `d2851c4792ec99d646d058cfd169b8d228ee4d387ef3141a6473c629d51c1e8c`.
- All 29 semantic key identities, all 58 locale values and all 10 reuse references retained from the candidate without alteration.
