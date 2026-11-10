# WELL-16 recovery approval and acceptance requests

This is a pending decision request for [WELL-16](https://app.plane.so/symphony-development/browse/WELL-16) and [draft PR #217](https://github.com/JCSchoeman96/NewYou/pull/217). It grants no approval and changes no governing contract or acceptance criterion. Source reconnaissance started at `417fa7afdc4981cfad59e78a03dec363ef82c32b`, with main `98fbeb8766ff1d20efe4f4f10baa6fc3abcc62f6`. Subsequent proof changes and exact-head checks belong in the PR and Plane ledger.

## Content decisions required before implementation activation

The four existing V1 files remain unchanged in [the candidate package](../delivery/content-evidence/content_media/recovery_messages/README.md). Each digest below is SHA-256 of the complete UTF-8 file bytes, including its terminal LF.

- Proof EN V1, `NEWYOU-ACCOUNT-RECOVERY-PROOF-MESSAGE-EMAIL-EN-V1.txt`: `c1d761d829e7eb3e400b94d6c2be734ac33a0087a742c2b77818ff06a21d3cb7`.
- Proof AF V1, `NEWYOU-ACCOUNT-RECOVERY-PROOF-MESSAGE-EMAIL-AF-V1.txt`: `ae9b51d967c2be015b8f948bb05360027647767c1189e3df284afbb296295d90`.
- Notice EN V1, `NEWYOU-ACCOUNT-RECOVERY-COMPLETION-NOTICE-EMAIL-EN-V1.txt`: `7f57114273ec162a9a4dad9a5c260985ba9148f98d58917ac5e7fa95d95a2042`.
- Notice AF V1, `NEWYOU-ACCOUNT-RECOVERY-COMPLETION-NOTICE-EMAIL-AF-V1.txt`: `2d55e469b1717a28af4b4ee3467fba2ecc5eca1df9083b23f233de60c158a337`.

The [candidate evidence packet](../delivery/content-evidence/content_media/recovery_messages/RECOVERY_MESSAGE_CANDIDATE_EVIDENCE_PACKET_v0.1.0.json) has whole-file SHA-256 `be05db014e6a3beb947ef0394fd2e846d557d3367322e3308184eb099c327544`. It pins subject/body digests, proposed immutable locale identities and exact typed token contracts. Proof tokens are `platform_name` and protected `account_recovery_link`. Notice tokens are `platform_name` and literal non-secret `support_contact`. No rendered bearer belongs in an approval record.

Request the following attributable decisions through the authorised Product and Content process:

1. Product approves the narrow `account_recovery_proof_message` classification, wording risk and bounded applicability in the [classification proposal](../delivery/content-evidence/content_media/recovery_messages/PRODUCT_CLASSIFICATION_PROPOSALS_v0.1.0.md). For the notice, choose `account_recovery_completion_notice` or an expressly bounded use of `safety_notice`. No existing verification or password-reset approval authorises either recovery role under Product §§21E.19 and 21E.23.
2. Content & Media establishes ownership, issues or ratifies the exact immutable identities, and approves these four byte versions and their token contracts. Proposed IDs are not issued authority until that decision exists.
3. Accountable English and Afrikaans reviewers record exact-version language decisions for both purposes. The independent candidate drafting review is useful evidence but supplies no owner approval.
4. The accountable owner supplies and approves the actual non-secret `support_contact` value and its binding. No contact is proposed here.
5. The decisions explicitly limit eligibility to local development, automated tests, development environments and bounded WELL-16 Phase-8 proof. They grant no production, public-release, paid-pilot, real-participant or Phase-9 permission.

Until those decisions are authentic, exact-bound and currently eligible, Communications roles `account_recovery` and `recovery_security_notice` remain held and content-unbound. Provider admission stays disabled. Activation still needs protected link rendering, current eligibility checks, exact locale selection and actual delivery/reconciliation tests. A GET currently returns an empty development response; it implements no participant confirmation form. The existing POST owner interfaces and scanner/CSRF proofs do not establish a complete rendered email-to-browser journey.

## Manual claimant verification and WELL-65

[Product §21J.7](../governance/product/00_PLATFORM_v1.15.0.md) requires governed manual verification when ordinary recovery is unavailable, a temporary hold, sensitive-action restrictions, second-person approval for privileged Accounts and full Audit. [DEC-250](../governance/product/01_DECISIONS_v1.15.0.md) requires graduated automated and manual recovery. [Identity JIT §F.6](../delivery/jit/identity/FP-001_IDENTITY_ACCESS_JIT_DOMAIN_DOSSIER_WORKING_v0.3.0.md) requires missing-assurance review, stronger privileged assurance and second-person approval.

Current implementation proves a manual path after accepted verified-email proof, with a governed hold, current scoped staff authority, TOTP-backed step-up, distinct reviewer and actor, E1 admission before each exceptional effect and linked source outcomes. Zero-assurance requests create only a case-level review pause. They cannot hold the Account or revoke valid access. The existing verification owner can restore an unverified channel, after which the same case may resume without reducing its requirement. This is not proof-independent recovery.

The live WELL-16 manual acceptance criterion requires the current support/E1 boundary. Its evidence criterion requires stronger privileged/second-person authority and E1 before protected completion. Neither names a new zero-factor evidence method. Those bounded controls are implemented and tested. Product's wider lost-factor requirement nevertheless remains unresolved when no approved claimant factor can be supplied.

The narrow three-part insufficiency is:

1. Product §21J.7 and Identity §F.6 require manual recovery but supply no claimant-verification method for loss of every approved factor. Identity separates authentication/assurance from staff role authorisation.
2. Staff permission, two-person approval and Audit E1 cannot establish claimant ownership. No internal representation can supply absent identity evidence. Existing verified-channel recovery cannot prove a channel the claimant no longer controls.
3. Permitting completion would invent the evidence threshold for replacing an Account credential. That is a durable security decision, not a JIT field or action choice.

Request Product/Identity to decide whether WELL-16's bounded acceptance may retain the demonstrated proof-backed manual path and fail closed for total factor loss while WELL-65 owns a future approved alternative. If this changes the intended requirement for delivery now, an explicit upstream Product/Identity scope decision and corresponding Plane clarification are required before acceptance. Moving future work to WELL-65 by comment alone cannot waive current law. This request neither approves an alternative method nor changes the zero-assurance guard. Existing MFA, privileged review and hold-release requirements remain mandatory.

## Primary-email boundary and WELL-17

The live WELL-16 non-goal explicitly excludes P8-16 primary-email implementation and requires only the serialization/current-authority boundary against competing email changes. [Identity JIT §F.7](../delivery/jit/identity/FP-001_IDENTITY_ACCESS_JIT_DOMAIN_DOSSIER_WORKING_v0.3.0.md) assigns the future change lifecycle to Account with current versions and serialized apply. WELL-17 remains unimplemented and is not a direct WELL-16 dependency.

The recovery-side proof uses separate PostgreSQL connections and observed lock contention. An earlier synthetic Account email commit invalidates the recovery binding; recovery then fails the case and revokes its proof without overwriting the newer email. Account exposes no update action accepting email. Existing credential/login races also use real owner actions. These establish a bounded current recovery-side contract, not integration with a future WELL-17 action or its stale-apply guard.

No new email policy is needed to implement this boundary. Actual two-sided WELL-17 integration remains unverified and must be exercised when its owner action exists. Independent Master Gate must assess whether the current bounded evidence satisfies the unchanged WELL-16 competing-operation criterion. If it requires evidence unavailable without WELL-17, record that precise execution dependency; do not invent a successful integration or silently weaken the criterion.

## Disposition

These are requests and evidence limits. WELL-16 remains Blocked and PR #217 remains Draft. No approval, provider success, Master Gate PASS, merge authority or Phase-8 certification is asserted. The [implementation handoff](p8-15-graduated-recovery-handoff.md) and live Plane ledger remain the places to record subsequent engineering results. Accountable decisions must remain distinguishable from this author's interpretation.
