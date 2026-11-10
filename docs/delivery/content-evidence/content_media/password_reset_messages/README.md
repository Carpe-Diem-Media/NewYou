# Password-reset message development approval package

**Status:** `DEVELOPMENT_ONLY_APPROVED; RUNTIME_RELEASE_PROHIBITED` in this PR branch. The approval packet becomes current after independent Master Gate certification and authorised merge. It grants no password-reset implementation permission.

The PR base is `561835b8c099b632ef78684ff99d5d03e3a559aa`. That main still routes Product and Decisions v1.14.0. This branch promotes the exact approved WELL-98 Product proposals to v1.15.0 and adds a separate development evidence route. Do not use the v0.2 packet as current main authority before integration.

## Approved Product classification

Product §§21E.23–21E.24 and DEC-322 approve the narrow `password_reset_message` type for an email carrying Identity-issued, purpose-bound password-reset proof to an existing Account. The wording risk is `editorial_low_risk`; this classifies wording only. The message is Class A content with `identity_security` risk, and Identity security remains HIGH. It does not cover reset pages/forms, recovery-case notices, password-change notices, verification, magic login, primary-email change, marketing, safety, practitioner, entitlement or general transactional messages.

Content & Media owns the immutable content identities, exact locale bytes and bounded development eligibility. Identity & Access owns proof, Account and credential state, and Session consequences. Communications owns `MessageIntent`, delivery attempts and current delivery decisions. Audit & Evidence owns selected source-outcome evidence. No ownership is transferred.

The exact source proposals remain available under `../../../../governance/product/proposals/well-98/`. Their approved source digests are `a9ae584bccc984faca20aeed2428edc00a05ad54aead237a57a6d90388eedebb` (Product Law) and `b4374a82d605320fba01733176cc8a57346a97da1a0d03095d79b818926f2017` (Decision Register). The current v1.15.0 routes are recorded in `docs/governance/CURRENT_GOVERNANCE_ROUTER.json`.

## Exact approved locale versions

Both source artifacts use UTF-8, LF line endings, one blank line between subject and body, and one terminal LF. Their bytes are unchanged from the approved review subject.

| Locale | Immutable translation version | Bytes | SHA-256 | Language decision |
|---|---|---:|---|---|
| EN | `NEWYOU-CONTENTTRANSLATIONVERSION-PASSWORD-RESET-MESSAGE-EMAIL-EN-V1` | 369 | `71c213c2ae48edf499d7d6d4191d84076a366d6fbd59607c8b842c830d33928c` | English review approved |
| AF | `NEWYOU-CONTENTTRANSLATIONVERSION-PASSWORD-RESET-MESSAGE-EMAIL-AF-V2` | 401 | `ec1251d149b54692df2751760b72d1766d99537d4fa22b9b06da828bafe9ec93` | Afrikaans review approved; `wysig` accepted |

The token allowlist remains exactly `{{platform_name}}` and `{{password_reset_link}}`; the canonical token-contract SHA-256 is `cbf191e4408d4a7120e00e93d6978dff7364c3246932d34d1dc1b04e11f8dfa1`. Only literal tokens appear in source evidence. No rendered bearer URL, credential or participant identifier is included.

AF V1 is unchanged historical, unapproved content. Its SHA-256 remains `582fb5d79e8a03708491b1085432efc56de0b809c75e4a043b7cdb3ccd6fc303`. The v0.1.0 candidate packet is also retained byte-for-byte at its original path with all eligibility flags false and no approval events.

The semantic keys remain outside the P8-05 pinned runtime `COPY_REGISTRY.json`. This PR does not add a reset renderer or runtime registry integration.

## Five Plane decisions and provenance

Plane WELL-98 summary comment `510ff609-f47a-4f54-8e77-9d2ba6345276` indexes the five separate exact-bound decisions. `OWNER_APPROVALS_v1.json` preserves each comment's text, comment ID, Plane-recorded creation time, actor metadata and approved scope. All five Plane comments identify the same connected account (`2d75ac08-a11c-4fe1-9545-c1d885f83955`) and record the requester's self-attested roles. This is not independent review, an Identity Account/role/Grant, or proof of runtime capability. The original direct user-decision time is not represented; `recorded_at` is the Plane comment creation time.

| Decision | Plane comment | Recorded at (UTC) |
|---|---|---|
| `WELL-98-PRODUCT-APPROVAL-20261109` | `a6cedfea-2ee2-4c9b-97eb-a735793a4d92` | 2026-11-09 06:59:05.698111 |
| `WELL-98-CONTENT-EN-V1-APPROVAL-20261109` | `85949fee-f36c-4d6c-b54f-890ef4ad04eb` | 2026-11-09 06:59:14.529529 |
| `WELL-98-CONTENT-AF-V2-APPROVAL-20261109` | `56697c18-e585-403e-8b99-ef417d9acf6b` | 2026-11-09 06:59:21.569208 |
| `WELL-98-LANG-EN-V1-APPROVAL-20261109` | `b6c2dc5e-5622-49ac-8e12-a0f5855acce3` | 2026-11-09 06:59:27.114634 |
| `WELL-98-LANG-AF-V2-APPROVAL-20261109` | `3fd2448a-39f3-4c61-bbaf-85253e3d2c5f` | 2026-11-09 06:59:32.524540 |

The Product approval binds both exact proposal digests and classification. Content & Media separately approves exact EN V1 and AF V2 bytes, subject/body metadata, token digest and applicability. The two language reviews bind their exact locale bytes. Each is a separate event; a language review does not substitute for Product or Content approval.

## Lifecycle, authorization and fail-closed rules

The governed lifecycle is `candidate → development_approved → superseded | withdrawn`. This packet records `development_approved`; the predecessor v0.1 packet remains an unchanged candidate. Promotion requires the current approved Product route, all five attributable decisions, exact EN/AF identities and bytes, the token contract, exact scope, complete history and no unresolved conflict. The route and packet become current only after merge.

Approval events are append-only. Reapplying the same decision ID to the same identity, locale, format, bytes/digest, token contract and applicability is idempotent. Reuse of an ID with changed fields, or conflicting decisions for an immutable identity, stops new use for owner reconciliation; last-write-wins is prohibited. Changed bytes require a new locale-version identity and approval. Supersession requires an immutable successor. Superseded and withdrawn versions remain historical and are terminal for new use. Current eligibility must be revalidated before every new use; queued or cached content does not preserve eligibility after withdrawal.

Eligibility is limited to local development, automated tests, development environments and bounded P8-12 Phase-8 proof. Production, public release, paid pilots, real participants and Phase 9 remain prohibited. No runtime Content role, Identity grant, sender/provider approval, publication, release, password-reset implementation permission or security exception is granted. WELL-13 remains blocked by WELL-98.

## Engineering assessment

| Dimension | Assessment | Evidence or limit |
|---|---|---|
| Authorization | APPLICABLE | Product classification, C&M EN/AF exact-byte decisions and two exact locale reviews are separately recorded. Development eligibility is distinct from implementation and runtime permission. |
| Lifecycle and state machines | APPLICABLE | Packet binds states, transitions, approval guards, append-only history, terminal states, replay/conflict rules, withdrawal and current revalidation. |
| Database invariants | APPLICABLE | No database change. Checker proves fixed IDs and paths, locale order, source bytes, encoding, lengths, digests and closed token contract. Runtime PostgreSQL enforcement belongs to the implementation ticket. |
| Transactions | NOT APPLICABLE | No runtime transaction is added. The checker accepts eligibility only when every required decision and current Product route verify together. |
| Concurrency | APPLICABLE | Conflicting decision identities or bindings fail closed and require explicit owner reconciliation; no concurrency framework is added. |
| Idempotency | APPLICABLE | Exact replay of the same full decision binding is idempotent; changed reuse conflicts. |
| Multi-tenancy and scope isolation | NOT APPLICABLE | No tenant-specific content authority is introduced. Existing environment and P8-12 applicability bounds remain exact. |
| Cache consistency | APPLICABLE | No cache is added. Current eligibility must be rechecked; queued or cached content cannot survive withdrawal as eligible. |
| Multi-node behavior | NOT APPLICABLE | Evidence is deterministic file bytes, digests and decision IDs. No process-local approval state or node affinity is introduced. |
| Production boundaries | APPLICABLE | Production, public release, paid pilot, real-participant use and Phase 9 remain prohibited. Runtime and implementation permissions are false. |

## Verification and documentation impact

This PR changes Product/Decision authority, development-only content evidence and the existing `NewYou.Content.MagicLoginMessage` current-authority check. The latter continues to verify the historical v1.14 magic-login approval and separately validates the exact v1.15 current route, digest and predecessor lineage. It does not implement the password-reset runtime feature or change Identity, Communications or Audit business logic, authentication configuration, dependencies, release configuration or WELL-91's Assent disposition. The existing P8-09 implementation handoff is updated with this reader correction; no new vertical-slice handoff is needed.

Focused validation uses `python3 -m unittest tests.test_password_reset_message_content_evidence tests.test_password_reset_message_activation` and `python3 tools/check_password_reset_message_evidence.py`. Repository and hosted verification results are recorded in the activation PR and Plane review handoff.
