# Password-reset message candidate

**Status:** CANDIDATE_NOT_APPROVED. These files are a review package. They do not make an approved or eligible content version.

Base main was `022a0eb1bb93b5b84a722d132e0ee1d084fc3a67`. WELL-98 is the source of the live delivery state. The current governance router still selects Product and Decision v1.14.0.

## Candidate classification and authority

Propose the narrow Product type `password_reset_message` for the email that carries Identity-issued, purpose-bound password-reset proof to an existing Account. Recommend `editorial_low_risk` for wording only. The message does not issue or consume proof or change credentials. Identity security risk remains HIGH. The candidate proposes Class A content with `identity_security` risk; these classifications are separate. Proposed semantic keys are recorded in this packet and are not added to the P8-05 pinned runtime registry.

Content & Media owns the exact immutable message versions and development-eligibility decisions. After Product approves the type, its separate EN and AF decisions can grant only bounded development eligibility to those exact content versions. Identity & Access owns proof, Account and credential state, and Session consequences. Communications owns each MessageIntent, DeliveryAttempt and current delivery decision. Audit & Evidence owns selected evidence of Identity outcomes. None of the candidate content grants authority to those Domains.

The Product-owner decision for the exact proposed classification and scope is pending. Content & Media owner decisions for the exact EN and AF version bytes, digests, token contract and scope are also pending. English and Afrikaans language review evidence is pending. A future dependency-cleared Ready implementation ticket separately authorizes its implementation work; none of these content decisions grants that permission. Runtime, sender/provider, publication, release and production grants remain separate and are not granted here. No decision IDs, actors, approval evidence or timestamps have been invented.

## Immutable candidate identities

The JSON packet binds the exact subject/body artifacts, UTF-8/LF serialization, byte counts, SHA-256 digests, locale identities, proposed semantic copy keys and typed literal token allowlist. The only proposed tokens are `{{platform_name}}` and `{{password_reset_link}}`. No rendered URL, bearer value, account identifier, email address or secret appears in the source files.

`{{password_reset_link}}` is a content-contract proposal only. The current P8-05 `CopyRegistry` supports `platform_name`; this ticket adds no reset renderer, token provider or password-reset application path.

The packet requires an approved Product extension to be selected by current governance before any future `development_approved` state. A complete Product decision and separate Content & Media EN and AF decisions are all required. A partial locale approval does not make the paired message eligible. The current packet remains `candidate`; development, test, runtime, production, public-release, paid-pilot and real-participant eligibility are all false.

## Lifecycle and authorization contract

The proposed lifecycle is `candidate → development_approved → superseded | withdrawn`. Promotion requires the exact Product classification and current approved extension, the exact immutable parent and locale identities, exact bytes and digests, the token contract, allowed applicability, complete owner evidence and a conflict-free append-only history. `development_approved` makes only these exact EN/AF versions eligible for local development, tests, development environments and bounded P8-12 proof. It does not authorize implementing password reset; a separate Ready implementation ticket is required. Runtime grants and release authorization remain separate.

Repeated application of the same decision ID with the same complete version, locale, digest, token and scope binding is idempotent. Reusing the ID with changed data conflicts. Conflicting decisions for one immutable identity stop new use until accountable owners reconcile them. Superseded and withdrawn versions stay available as history but are terminal for new use. Changed bytes need a new locale-version identity and fresh approval.

## Ten-dimension engineering assessment

| Dimension | Assessment | Evidence or reason |
|---|---|---|
| Authorization | APPLICABLE | Product-owner classification, Content & Media EN/AF content-eligibility decisions and English/Afrikaans language reviews are separate pending records. Content eligibility does not authorize reset implementation; the future implementation ticket must independently be Ready. None grants runtime, sender, publication, release or production authority. |
| Lifecycle and state machines | APPLICABLE | The candidate packet records the required states, transitions, guards, terminal-use rules, exact bindings and append-only history. It remains at `candidate`. |
| Database invariants | APPLICABLE | No Resource, table or migration is proposed. The checker proves unique identities, exact locale-to-file binding, UTF-8/LF serialization, byte counts, digests and the closed token allowlist from actual files. PostgreSQL enforcement belongs to WELL-13. |
| Transactions | NOT APPLICABLE | This ticket records no runtime state changes. Future eligibility requires the complete Product decision and both exact locale decisions together; a partial set cannot claim eligibility. File creation and owner approval are not publication. |
| Concurrency | APPLICABLE | Conflicting decisions for the same immutable identity require owner reconciliation. The contract rejects last-write-wins. It adds no runtime concurrency mechanism. |
| Idempotency | APPLICABLE | Exact decision replay on the same identity, locale, bytes, digest, token contract and scope is idempotent. Reuse of an ID with changed binding fails closed. |
| Multi-tenancy and scope isolation | NOT APPLICABLE | Product Law and DEC-268 define one operating platform with controlled product spaces, not generic tenant isolation. This candidate has no tenant-specific content authority; it retains the stated P8-12 and environment scope. |
| Cache consistency | APPLICABLE | No cache is added. Future delivery must revalidate current eligibility; a queued message or cached copy does not preserve eligibility after withdrawal. |
| Multi-node behavior | NOT APPLICABLE | This candidate introduces no process-local approval state or node affinity. The files, byte counts, digests and decision bindings are deterministic. Delivery behavior belongs to WELL-13. |
| Production boundaries | APPLICABLE | The candidate is ineligible everywhere. Any future development approval is limited to local development, tests, development environments and bounded P8-12 proof. Production, public release, paid pilots, real participants and Phase 9 remain excluded. |

## Source baseline

- Product Law §21E.3 requires an approved extension for new content types. §21E.19 excludes password recovery from `verification_message`. §21E.21 excludes password reset from `magic_login_message`. §21E.4 separates content wording risk from Identity security.
- Product §21E.22 and DEC-321 establish the bounded magic-login approval pattern but apply only to that purpose and P8-09.
- Domain Law §§6.1, 6.7, 6.15 and 6.18 keep Identity, Content & Media, Communications and Audit ownership separate.
- Architecture Law §§6.4, 10.1 and 10.4 require purpose-bounded recovery, immutable locale content and exact message provenance.
- Identity JIT §§J.1 and J.1a keep bearer material out of ordinary evidence and make passive scanner retrieval non-consuming.
- Communications JIT §5 assigns MessageIntent and delivery lifecycle to Communications. The Audit JIT selection matrix assigns the source reset result to Identity and does not create a duplicate central delivery ledger.
- Roadmap FP-001 and live WELL-13 define the Phase-8 password-reset outcome. WELL-13 remains blocked by this prerequisite and other existing dependencies.
- `COPY_INVENTORY.md` keeps `identity.recovery.family` as JIT UI/journey copy and records separate proposed Class A keys for this email. Those keys are absent from the pinned `COPY_REGISTRY.json` until owner decisions and a separately reviewed registry integration.

## Assessment limits

This is a Product/Content candidate and evidence checker. It adds no Ash Resource, database table, migration, transaction, cache, service, runtime approval path or password-reset application code. It changes no Assent exception, authentication configuration, security guard or release configuration. WELL-91's existing Assent disposition remains unchanged and expires at `2026-11-18T00:00:00Z`.

Documentation-impact determination: this candidate package is its own source-linked Product and Content review record. It does not create an implemented vertical slice, so a runtime implementation handoff is not applicable.
