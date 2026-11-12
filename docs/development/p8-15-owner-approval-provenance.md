# Historical approval provenance

This records the PR #217-era observations below. Current authority is routed
Product/Decisions v1.16.0 and the WELL-110 development evidence packet promoted by
PR #226. WELL-111's bounded reconciliation is complete. See the current
[recovery capability map](knowledge/identity.recovery.json) and live Plane for
implementation scope and remaining operational limits. No historical approval
event or exact message bytes are rewritten here.

# WELL-16 recorded owner decisions and promotion boundary

This implementation addendum records independently retrieved Plane events. It is not a Product amendment, Content approval packet, runtime eligibility source or acceptance waiver. Reconnaissance used implementation head `cd70611e6d1d80474c6ca26db6fdee48e9d407e4` and main `98fbeb8766ff1d20efe4f4f10baa6fc3abcc62f6`. Both current routers still resolve Product and Decisions v1.15.0. No eligible recovery packet is routed.

## WELL-110 approval provenance

The authoritative [WELL-110 index](https://app.plane.so/symphony-development/browse/WELL-110) is comment `b2f7477e-d0db-4f46-bfe0-35bf75ba3656`. Role attestation `677c7f35-cd92-4723-afcf-ee71ffb7e446` identifies the same accountable owner in separate development-stage Product, Content & Media, English Language Reviewer and Afrikaans Language Reviewer capacities. Each event has actor and creator `2d75ac08-a11c-4fe1-9545-c1d885f83955`. This is attributable approval in those capacities, not independent-person language review.

Product event `e0df49d1-f343-4576-aabc-3a62bfb2aeaf` approves two dedicated types:

- `account_recovery_proof_message` for Communications role `account_recovery`.
- `account_recovery_completion_notice` for role `recovery_security_notice`.

Both are Class A / `identity_security`. `editorial_low_risk` describes wording risk only. Underlying Identity/security risk remains HIGH. The exact [classification proposal](../delivery/content-evidence/content_media/recovery_messages/PRODUCT_CLASSIFICATION_PROPOSALS_v0.1.0.md) SHA-256 is `04f41fe344428a9c7cb30398c599c341d6a416af79c51d8446215ef9075e1b64`.

Applicability is local development, automated tests, development environments and bounded WELL-16/P8-15 Phase-8 proof. Production, public release, publication, paid pilot, real-participant delivery and Phase 9 are prohibited. These events grant no runtime/provider permission.

## Exact immutable V1 bindings

The four original files and the [candidate packet](../delivery/content-evidence/content_media/recovery_messages/RECOVERY_MESSAGE_CANDIDATE_EVIDENCE_PACKET_v0.1.0.json) remain unchanged. Each event below matches the packet's ContentItem, ContentVersion, ContentTranslationVersion, locale, full-file bytes, subject/body digests and serialized typed token contract. Digests are SHA-256 of exact UTF-8 bytes, including terminal LF.

- [Proof EN V1](../delivery/content-evidence/content_media/recovery_messages/NEWYOU-ACCOUNT-RECOVERY-PROOF-MESSAGE-EMAIL-EN-V1.txt), 693 bytes. Content event `2b1f47a1-bfd5-4748-8aaa-e4e56e828bcd`, language event `54c57464-48c9-4c62-8eb3-8354f0bfd54b`. File digest `c1d761d829e7eb3e400b94d6c2be734ac33a0087a742c2b77818ff06a21d3cb7`.
- [Proof AF V1](../delivery/content-evidence/content_media/recovery_messages/NEWYOU-ACCOUNT-RECOVERY-PROOF-MESSAGE-EMAIL-AF-V1.txt), 826 bytes. Content event `07f86c5a-2021-410b-86ee-0153728e7d12`, language event `a3e9f721-0018-4b05-bafd-b9afc9c50708`. File digest `ae9b51d967c2be015b8f948bb05360027647767c1189e3df284afbb296295d90`.
- [Notice EN V1](../delivery/content-evidence/content_media/recovery_messages/NEWYOU-ACCOUNT-RECOVERY-COMPLETION-NOTICE-EMAIL-EN-V1.txt), 443 bytes. Content event `24c5d6e8-faa2-4cee-b35b-0ebfb7571d56`, language event `b1d4489f-40f7-4ff6-90bd-5d87801ea411`. File digest `7f57114273ec162a9a4dad9a5c260985ba9148f98d58917ac5e7fa95d95a2042`.
- [Notice AF V1](../delivery/content-evidence/content_media/recovery_messages/NEWYOU-ACCOUNT-RECOVERY-COMPLETION-NOTICE-EMAIL-AF-V1.txt), 469 bytes. Content event `7e2ef52f-910a-446b-8fae-58ed19126533`, language event `bfeb063b-f27e-4b5a-981d-a1fa04cec941`. File digest `2d55e469b1717a28af4b4ee3467fba2ecc5eca1df9083b23f233de60c158a337`.

Proof ContentItem is `NEWYOU-CONTENTITEM-ACCOUNT-RECOVERY-PROOF-MESSAGE-EMAIL`, ContentVersion `NEWYOU-CONTENTVERSION-ACCOUNT-RECOVERY-PROOF-MESSAGE-EMAIL-V1`. Typed token contract digest is `19862cc352eb8248f4511d9c84c7d4fad650a68a1885a7766b53ddf66cb80f6a`. Tokens are `{{platform_name}}` and protected `{{account_recovery_link}}`.

Notice ContentItem is `NEWYOU-CONTENTITEM-ACCOUNT-RECOVERY-COMPLETION-NOTICE-EMAIL`, ContentVersion `NEWYOU-CONTENTVERSION-ACCOUNT-RECOVERY-COMPLETION-NOTICE-EMAIL-V1`. Typed token contract digest is `172b65484ad8fd50e7626b5e8a00784309e5a0c9486a096647d7f30ad1457c7a`. Tokens are `{{platform_name}}` and literal `{{support_contact}}`. Exact translation identities remain in the packet and approval events; no identity is regenerated here.

Support event `b36e72fe-acbe-4925-8486-b2de93bde03f` selects the exact temporary non-secret development value `jc@carpediem.co.za`. It is not embedded into any immutable V1 artifact or activated runtime binding. Mailbox monitoring, operational availability and delivery have not been independently proven.

## Promotion and engineering work still required

The original packet still has status `CANDIDATE_NOT_APPROVED`, empty approval/language arrays and false eligibility flags. Its exact whole-file digest remains `be05db014e6a3beb947ef0394fd2e846d557d3367322e3308184eb099c327544`.

WELL-110 must promote Product/Decision authority, current routing and append-only exact-version Content evidence through its separate reviewed governance PR. This implementation worktree does not perform that promotion or ask for duplicate approvals. Before bounded activation, independently recheck current routed authority, all exact bindings, current eligibility, support operations and provider policy. Recovery intents remain held/content-unbound and Executor provider admission remains disabled.

Read-only Identity source guards prepare the owning integration point. They do not implement Content binding, protected rendering, provider execution/reconciliation or the rendered confirmation journey. Those engineering requirements remain open after promotion. A clean test suite cannot substitute for them.

## Manual-recovery scope decision

[WELL-111](https://app.plane.so/symphony-development/browse/WELL-111) owner event `9c0a8fd0-a7a6-4555-910f-ef261b71d73e` approves Option B, bounded proof-backed Phase-8 recovery with fail-closed zero-factor handling. Earlier readiness comment `6ccd7b22-1e20-4afd-851d-e0e7dbc6a07f` requested the necessary authority/acceptance reconciliation. Subsequent execution comment `be894945-8400-46fe-b74d-4c3698fe372b` records its resolution: WELL-16 now has an explicitly labelled supplementary bounded positive/negative proof acceptance, retaining all original criteria. The live issue was independently retrieved after that update. No acceptance rewrite was performed by this implementation worktree.

[WELL-115](https://app.plane.so/symphony-development/browse/WELL-115) owns the future ordinary-member lost-all-factor method before supported release. [WELL-65](https://app.plane.so/symphony-development/browse/WELL-65) owns privileged MFA/passkey hardening. Neither supplies a currently approved alternative claimant proof. Zero-assurance completion remains denied. MFA, held-Account, scoped staff, distinct-person, E1/E2 and independent hold-release requirements remain in force.

Product §21J.7, DEC-250 and Identity JIT §F.6 retain the wider supported-release recovery obligation. The bounded Phase-8 acceptance now explicitly requires denial when no approved factor exists, alongside proof-backed manual positive proof. Those executable checks require no new claimant method or Product amendment. There is no remaining manual-policy decision for this bounded proof. Future successful ordinary-member lost-all-factor recovery remains WELL-115 work; no supported release is authorized.

## Review disposition

WELL-16 remains Blocked and PR #217 remains Draft. Actual recovery delivery/provider ambiguity, rendered participant confirmation and full future WELL-17 owner-action integration remain unverified. Independent Master Gate must inspect the complete final source, current authority, current live acceptance and exact-head CI. This addendum supplies no Master Gate PASS, attestation or merge authorization.
