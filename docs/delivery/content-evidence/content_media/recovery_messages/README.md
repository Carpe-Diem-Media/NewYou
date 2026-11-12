# Recovery messages

## Current status

The Product and Decision successors v1.16.0 add two narrow message classifications under DEC-323:

- `account_recovery_proof_message`, for Identity-issued recovery proof carried through the Communications `account_recovery` role.
- `account_recovery_completion_notice`, for the notice after committed recovery completion, carried through `recovery_security_notice`.

Both are Class A `identity_security` content. `editorial_low_risk` applies to wording only; Identity security risk remains HIGH. The exact scope, role ownership and exclusions are in Product §§21E.25–21E.26 and DEC-323.

`RECOVERY_MESSAGE_CANDIDATE_EVIDENCE_PACKET_v0.1.0.json` remains the unchanged historical candidate record. It retains empty approval arrays and false eligibility flags. Its four EN/AF source files are byte-identical to the exact versions approved for bounded development in `RECOVERY_MESSAGE_DEVELOPMENT_EVIDENCE_PACKET_v0.2.0.json`.

The v0.2.0 packet binds those exact message bytes, immutable content identities, locale decisions and typed-token digests. `OWNER_APPROVALS_v1.json` records nine separate Plane decisions: Product classification, four Content & Media version approvals and four exact-language approvals. The decisions are owner-attested in distinct capacities for bounded development. They do not establish an independent security review or a runtime role grant.

## Exact content and tokens

The four linked EN/AF files use UTF-8 without a BOM, LF line endings, one `subject: ` line, a blank line before the body and one terminal LF. Their full-file, subject, body and token-contract digests are bound in the development packet. Do not edit the files in place. Any byte or token-contract change requires a new immutable version and fresh decisions.

The recovery link remains Identity-issued, purpose-bound bearer material. Its rendered value must not appear in the evidence packet, application logs or examples. The approved literal token contract remains in the packet. The temporary support-contact value is for development only. Its mailbox reachability and monitoring are unverified, and no message may be sent on this evidence alone.

The existing `COPY_REGISTRY.json` family stubs remain unchanged. These email versions use the Content evidence identities in the packet; this change adds no UI copy keys or duplicate translations.

## Scope limits

The development packet permits local development, automated tests, development environments and bounded P8-15 Phase-8 proof only. It does not authorize production, publication, public release, paid pilot, real-participant delivery, Phase 9, provider admission or a recovery method. Existing magic-login and password-reset approval packets and their historical authority lineage remain unchanged. Their readers require the exact current v1.16.0 Product and Decision routes and verified successor lineage.

## Verification

Run the two existing evidence auditors and focused regressions from the repository root:

```sh
python3 -m tools.check_magic_login_evidence
python3 -m tools.check_password_reset_message_evidence
python3 -m unittest tests.test_well110_recovery_evidence tests.test_magic_login_development_approval tests.test_magic_login_content_evidence tests.test_password_reset_message_activation tests.test_password_reset_message_content_evidence -v
```

The auditors verify exact hashes, immutable identities, approval history, typed tokens, current authority and fail-closed eligibility. The tests also reject altered routes, duplicate authority, changed proposal bytes, unsupported locales, fallback and ineligible states. Passing these checks proves evidence integrity and bounded development eligibility; it does not prove mailbox operation, provider authority or delivery.
