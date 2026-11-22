# WELL-175 bounded Recovery message applicability

Status: PROPOSED_NON_AUTHORITATIVE. The Plane scope receipt `fea6120c-e8ff-4476-b5a8-a018441cb021` authorizes preparation of this candidate. The routed Product and Decision v1.19.0 remain current. Apply the two clauses below as append-only v1.20.0 successors after exact Product approval. Preserve v1.19.0 and the Phase-8 Content packet.

## Proposed Product successor clause

### 21E.31 Bounded Phase-9 verified-factor Recovery message applicability

Subject to the requirements below, the exception to §21E.26 covers only the existing EN V1 and AF V1 `account_recovery_proof_message` and `account_recovery_completion_notice` in the ordinary, verified-factor Recovery journey under §21J.7 and DEC-250. The context is synthetic accounts in local development, automated tests, development environments and bounded non-production FP-001 Phase-9 verification. §21E.26 remains in force in every other context.

The exception binds the four immutable ContentItem, ContentVersion and ContentTranslationVersion combinations in [the exact bindings](EXACT_BINDINGS_v0.1.0.json). Preserve their exact subject and body bytes, byte counts, SHA-256 digests, `recovery-message-subject-body-text-v1` format, typed literal token contracts, Communications roles and earlier approval history. The proof role `account_recovery` permits only `{{platform_name}}` and `{{account_recovery_link}}`. The completion role `recovery_security_notice` permits only `{{platform_name}}` and `{{support_contact}}`. Existing token types and field restrictions apply. Resolve the exact version and locale. Both EN and AF are required per purpose. Locale fallback and `latest` resolution are prohibited.

Before consumption, require current, integrated Product authority with an attributable Product-owner decision on this exact exception, plus four separately attributable Content & Media applicability decisions. Each Content decision must bind one exact purpose and locale to the immutable identities, format, byte count, message digest, typed-token contract and this context. Preserve existing English and Afrikaans reviews as evidence of unchanged wording. Changed wording or token contracts require new immutable versions and fresh applicable approvals.

Record the applicability decisions append-only. The Content lifecycle remains `candidate → development_approved → superseded | withdrawn`. Recheck exact context, both locale bindings, current approval evidence and terminal status before new consumption and queued use. Missing, stale, unsupported, mismatched, superseded, withdrawn or conflicting evidence denies use. Identical exact-bound decisions may replay idempotently. Conflicts, including a reused decision ID with changed bindings, require explicit owner reconciliation. Queued work retains no eligibility after withdrawal or supersession.

The existing temporary `{{support_contact}}` value is permitted only in the body of the completion notice for controlled development rendering after the applicable Content gates pass. The binding is non-secret configuration. Operational mailbox verification and provider admission remain false. Proof material stays within approved protected handling and out of ordinary logs and evidence. No external sender or provider may be used.

Identity owns verified proof and commits Recovery. Communications owns intents and delivery, Content & Media owns exact version eligibility, and Audit & Evidence owns evidence. Retrieval, delivery and Content approval confer no assurance. A completion notice follows committed Recovery and grants neither hold release nor sign-in. The existing lost-all-factor and privileged Recovery boundaries continue to apply.

Production and production-build eligibility, publication, public release, paid pilots, real participants, real-participant delivery, live delivery, external providers, general runtime Content-role grants and new Recovery or Support authority remain prohibited. Separate browser-copy eligibility, dependency clearance and independent current-main readiness are required before dispatch of normal-entry implementation. This amendment does not close FP-001.

## Proposed Decision successor clause

### DEC-327 Bounded Phase-9 verified-factor Recovery message exception

Permit the exact EN V1 and AF V1 proof and completion notice versions to become eligible solely for the synthetic, non-production FP-001 Phase-9 verified-factor Recovery context in Product §21E.31. This exception supersedes DEC-323's Phase-9 restriction only for that context. Existing Phase-8 approval and historical evidence retain their scope.

Require exact, attributable Product approval and four separate Content & Media applicability decisions before consumption. Preserve immutable identities, exact bytes, typed token contracts and historical language evidence. Apply the paired-locale and fail-closed rechecks in §21E.31 to new and queued use. The temporary support contact is for controlled development rendering only. Mailbox verification and external delivery remain disabled. §21J.7 and DEC-250 continue to govern Recovery. This decision creates no normal-entry runtime, production, pilot, participant or release permission.
