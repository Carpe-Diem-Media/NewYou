# WELL-16 recovery decisions and remaining promotion gates

This tracks decisions and evidence limits for [WELL-16](https://app.plane.so/symphony-development/browse/WELL-16) and [draft PR #217](https://github.com/JCSchoeman96/NewYou/pull/217). It grants no approval and changes no governing contract or acceptance criterion. Source reconnaissance started at `417fa7afdc4981cfad59e78a03dec363ef82c32b`, with main `98fbeb8766ff1d20efe4f4f10baa6fc3abcc62f6`. Subsequent proof changes and exact-head checks belong in the PR and Plane ledger.

## Recorded content decisions, pending governed eligibility

The four existing V1 files remain unchanged in [the candidate package](../delivery/content-evidence/content_media/recovery_messages/README.md). Each digest below is SHA-256 of the complete UTF-8 file bytes, including its terminal LF.

- Proof EN V1, `NEWYOU-ACCOUNT-RECOVERY-PROOF-MESSAGE-EMAIL-EN-V1.txt`: `c1d761d829e7eb3e400b94d6c2be734ac33a0087a742c2b77818ff06a21d3cb7`.
- Proof AF V1, `NEWYOU-ACCOUNT-RECOVERY-PROOF-MESSAGE-EMAIL-AF-V1.txt`: `ae9b51d967c2be015b8f948bb05360027647767c1189e3df284afbb296295d90`.
- Notice EN V1, `NEWYOU-ACCOUNT-RECOVERY-COMPLETION-NOTICE-EMAIL-EN-V1.txt`: `7f57114273ec162a9a4dad9a5c260985ba9148f98d58917ac5e7fa95d95a2042`.
- Notice AF V1, `NEWYOU-ACCOUNT-RECOVERY-COMPLETION-NOTICE-EMAIL-AF-V1.txt`: `2d55e469b1717a28af4b4ee3467fba2ecc5eca1df9083b23f233de60c158a337`.

The [candidate evidence packet](../delivery/content-evidence/content_media/recovery_messages/RECOVERY_MESSAGE_CANDIDATE_EVIDENCE_PACKET_v0.1.0.json) has whole-file SHA-256 `be05db014e6a3beb947ef0394fd2e846d557d3367322e3308184eb099c327544`. It pins subject/body digests, proposed immutable locale identities and exact typed token contracts. Proof tokens are `platform_name` and protected `account_recovery_link`. Notice tokens are `platform_name` and literal non-secret `support_contact`. No rendered bearer belongs in an approval record.

The requested decisions are now recorded in [WELL-110](https://app.plane.so/symphony-development/browse/WELL-110). The [approval provenance addendum](p8-15-owner-approval-provenance.md) lists the independently retrieved Product event, four Content events, four exact-version language events, role attestation and support-contact decision. Product selected the dedicated `account_recovery_proof_message` and `account_recovery_completion_notice` types. The approved temporary development support binding is `jc@carpediem.co.za`; mailbox operations remain unverified. Do not ask for duplicate decisions or modify the immutable V1 files.

These approvals do not yet establish active eligibility. Current Product/Decisions v1.15.0 and routing remain unchanged. WELL-110 must promote the selected classifications and append-only exact Content evidence through a separate reviewed governance PR. The original candidate packet retains empty histories and false eligibility flags. Communications roles `account_recovery` and `recovery_security_notice` remain held/content-unbound, with provider admission disabled.

Read-only source guards prepare future admission without granting Content or provider permission. Actual content binding, protected rendering, current-eligibility checks, exact locale selection and delivery/reconciliation tests remain open. A GET still returns an empty development response with no participant confirmation form. Existing POST owner interfaces and scanner/CSRF proofs do not establish a complete rendered email-to-browser journey.

## Manual claimant verification, WELL-111 and future ownership

[Product §21J.7](../governance/product/00_PLATFORM_v1.15.0.md) requires governed manual verification when ordinary recovery is unavailable, a temporary hold, sensitive-action restrictions, second-person approval for privileged Accounts and full Audit. [DEC-250](../governance/product/01_DECISIONS_v1.15.0.md) requires graduated automated and manual recovery. [Identity JIT §F.6](../delivery/jit/identity/FP-001_IDENTITY_ACCESS_JIT_DOMAIN_DOSSIER_WORKING_v0.3.0.md) requires missing-assurance review, stronger privileged assurance and second-person approval.

Current implementation proves a manual path after accepted verified-email proof, with a governed hold, current scoped staff authority, TOTP-backed step-up, distinct reviewer and actor, E1 admission before each exceptional effect and linked source outcomes. Zero-assurance requests create only a case-level review pause. They cannot hold the Account or revoke valid access. The existing verification owner can restore an unverified channel, after which the same case may resume without reducing its requirement. This is not proof-independent recovery.

The live WELL-16 manual acceptance criterion requires the current support/E1 boundary. Its evidence criterion requires stronger privileged/second-person authority and E1 before protected completion. Neither names a new zero-factor evidence method. Those bounded controls are implemented and tested. Product's wider lost-factor requirement nevertheless remains unresolved when no approved claimant factor can be supplied.

The former total-factor-loss insufficiency concerned the evidence threshold for replacing credentials without any accepted claimant factor. Staff role, second-person approval and E1 cannot supply that evidence. No such method is implemented or required by the newly clarified bounded negative proof.

The owner selected Option B in [WELL-111](https://app.plane.so/symphony-development/browse/WELL-111), event `9c0a8fd0-a7a6-4555-910f-ef261b71d73e`. Earlier readiness comment `6ccd7b22-1e20-4afd-851d-e0e7dbc6a07f` requested reconciliation. Subsequent execution comment `be894945-8400-46fe-b74d-4c3698fe372b` records its completion. Live WELL-16 now has a labelled supplementary acceptance requiring proof-backed manual positive proof and explicit zero-factor denial. Existing Communications, Identity, Audit, concurrency/restart and competing-operation criteria remain mandatory. Current Product/Identity law continues to govern future supported release; no Product amendment is needed merely to demonstrate this bounded negative proof. There is no further manual-policy decision blocking the bounded WELL-16 proof.

[WELL-115](https://app.plane.so/symphony-development/browse/WELL-115) owns future ordinary-member lost-all-factor recovery before supported release. [WELL-65](https://app.plane.so/symphony-development/browse/WELL-65) owns privileged MFA/passkey hardening. Neither supplies a currently approved zero-factor evidence method. Existing MFA, privileged review, second-person, E1/E2 and hold-release requirements remain mandatory. This implementation neither amends current Product/Identity law nor performs the upstream Plane clarification.

## Primary-email boundary and WELL-17

The live WELL-16 non-goal explicitly excludes P8-16 primary-email implementation and requires only the serialization/current-authority boundary against competing email changes. [Identity JIT §F.7](../delivery/jit/identity/FP-001_IDENTITY_ACCESS_JIT_DOMAIN_DOSSIER_WORKING_v0.3.0.md) assigns the future change lifecycle to Account with current versions and serialized apply. WELL-17 remains unimplemented and is not a direct WELL-16 dependency.

The recovery-side proof uses separate PostgreSQL connections and observed lock contention. An earlier synthetic Account email commit invalidates the recovery binding; recovery then fails the case and revokes its proof without overwriting the newer email. Account exposes no update action accepting email. Existing credential/login races also use real owner actions. These establish a bounded current recovery-side contract, not integration with a future WELL-17 action or its stale-apply guard.

No new email policy is needed to implement this boundary. Actual two-sided WELL-17 integration remains unverified and must be exercised when its owner action exists. Independent Master Gate must assess whether the current bounded evidence satisfies the unchanged WELL-16 competing-operation criterion. If it requires evidence unavailable without WELL-17, record that precise execution dependency; do not invent a successful integration or silently weaken the criterion.

## Disposition

These are recorded owner decisions, pending promotion gates and evidence limits. WELL-16 remains Blocked and PR #217 remains Draft. No approval, provider success, Master Gate PASS, merge authority or Phase-8 certification is asserted. The [implementation handoff](p8-15-graduated-recovery-handoff.md) and live Plane ledger remain the places to record subsequent engineering results. Accountable decisions must remain distinguishable from this author's interpretation.
