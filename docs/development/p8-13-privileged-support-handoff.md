# P8-13 privileged support implementation handoff

## 1. Purpose, scope and version

Revision 1 describes [WELL-14](https://app.plane.so/symphony-development/browse/WELL-14), implemented at Git SHA `d924c170f5be2442a90cddd8085136ce58ed794a` on `feat/well-14-privileged-support`. The documentation commit is separate. Future readers must compare current source, dependency pins, routed authority and live Plane with that SHA before reusing this map. This is a HIGH change with the `privileged_security` consequence tag.

The capability is a bounded Phase-8 owner-interface proof of current scoped Support authority, Account MFA, Session step-up and security-hold placement, independent review and E1 release. There is no new UI, general grant-management endpoint, runtime bootstrap, recovery workflow or Phase-9 authorization. Production use remains subject to the governing authentication and release requirements. See [Identity JIT E/F/K](../delivery/jit/identity/FP-001_IDENTITY_ACCESS_JIT_DOMAIN_DOSSIER_WORKING_v0.2.0.md), [Audit JIT 5-8](../delivery/jit/audit-evidence/FP-001_AUDIT_EVIDENCE_JIT_DOMAIN_DOSSIER_WORKING_v0.1.0.md), [TB-001](../delivery/feature-contracts/fp-001/FP-001_TRACER_BULLET_CONTRACT_WORKING_v0.1.3.md) and the [governance router](../governance/CURRENT_GOVERNANCE_ROUTER.json). Plane holds execution state and review evidence.

## 2. Architecture, sequence and ownership

The supported entry points are [Identity](../../lib/new_you/identity.ex) functions `enroll_privileged_mfa/2`, `confirm_privileged_mfa/3`, `step_up_privileged/4`, `place_security_hold/1`, `review_security_hold/1` and `release_security_hold/1`. Existing password or magic-login credentials identify a durable Session; caller-supplied role or assurance claims grant nothing.

The release sequence in [SecurityHold](../../lib/new_you/identity/security_hold.ex) is:

1. `preflight/1` locks and checks current Identity authority and the held generation's independent review.
2. [Audit.admit_security_hold_release/1](../../lib/new_you/audit.ex) commits or replays a bound E1 admission in its own transaction. It refuses an existing outer transaction.
3. `attempt_release/2` opens a separate Identity transaction. `authority/2` and `held_and_reviewed/2` reread current Accounts, Session, Token, scoped grant, MFA versions and review authority. E1 never reserves permission.
4. The private Account release action changes posture and source operation result together with a linked Audit E2 obligation and its existing durable schedule.
5. The [existing Audit executor](../../lib/new_you/audit/actions/materialize_registration_evidence.ex) materialises that obligation independently. Its legacy registration name remains for worker/job compatibility. It never reads or mutates Identity.

Identity owns grants, MFA, Session assurance, review eligibility, hold posture and source operation outcomes. Audit owns admission and evidence assertions. The source transaction can roll back without erasing the earlier admission. No provider call, browser state, process-local authority or external I/O participates in these commits. [P8-13 proof](../../test/support/proof/p8_13.ex) exercises the separate boundaries.

## 3. Ash map

[Account](../../lib/new_you/identity/account.ex) adds restricted MFA fields, `security_version`, `hold_version`, `hold_review` and `hold_operations`. `update_privileged_mfa` is an internal write primitive. Private `place_security_hold`, `review_security_hold`, `release_security_hold` and `record_security_hold_attempt` actions apply conditional held-generation filters. Callers use the Identity owner functions, not these primitives directly.

[IdentityGrant](../../lib/new_you/identity/identity_grant.ex) is the only added business Resource. A Support grant names a subject, one capability, target Account, independent approver, bounded validity and revocation/version state. Its ordinary Ash policy denies direct callers. Private `provision` and `revoke` are internal primitives; synthetic test provisioning does not establish a production bootstrap or grant-approval workflow. [PrivilegedAccess](../../lib/new_you/identity/privileged_access.ex) consumes current grants through `authorize_locked/4`.

[Session](../../lib/new_you/identity/session.ex) stores purpose, verification/expiry time and bound MFA/security versions. `set_step_up` is private. Logout, revocation and Session expiry clear assurance fields. Token presence and revocation remain with the existing [Identity Token](../../lib/new_you/identity/token.ex) and AshAuthentication stack.

[EvidenceRecord](../../lib/new_you/audit/evidence_record.ex) distinguishes E1 admission from an E2 materialisation. Admission has an explicit action class and unique attempt identity; materialisation still has one record per obligation. [EvidenceObligation](../../lib/new_you/audit/evidence_obligation.ex) extends selected E2 work to security placement, review, MFA confirmation and linked release outcomes. The `identity_grant_revoked` envelope category is reserved for the eventual owning grant-revocation caller; no public grant-revocation workflow is added here. Its narrow AshOban policy allows only executor reads/materialisation. EvidenceRecord's ordinary policy denies direct access.

Ash actions, PostgreSQL row locks and constraints implement the required behavior. Signals were considered and not selected because authoritative admission/effect ordering is synchronous. Temporal Resources are not needed for this current-state and append-only-evidence contract. No StepUp/MFA/hold Resource or extra service is introduced.

## 4. Important interface contracts

`credentials` is the existing `%{session_id: uuid, token: bearer}` transport. Bearers, passwords and TOTP codes are transient and sensitive. MFA enrollment returns `{:ok, %{secret: binary}}` only after current Session and password reauthentication. Confirmation and step-up return `{:ok, :ok}` or `{:error, :privileged_access_unavailable}`. Enrollment remains pending until proof of possession; confirmation and its selected E2 obligation commit together. See [PrivilegedAccess](../../lib/new_you/identity/privileged_access.ex) and its [tests](../../test/new_you/identity/privileged_access_test.exs).

The step-up purpose is exactly one of `:place_security_hold`, `:review_security_hold` or `:release_security_hold`. The implementation uses a five-minute assurance lifetime and a private five-failure, fifteen-minute cooldown. These are bounded implementation controls, not a declaration that OQ-035's broader abuse/escalation policy is resolved. Every failure consumes current durable Account state. Expected denials commit counters; operational errors roll back security transitions and evidence obligations.

Each hold function accepts exactly `%{credentials: map, grant_id: uuid, target_id: uuid, expected_version: non_negative_integer, operation_id: uuid, reason_code: atom}`. Allowed reasons are `:suspected_compromise`, `:security_review`, `:verified_recovery` and `:mistaken_hold`. Success returns `{:ok, %{status: :held | :reviewed | :released, version: integer}}`; unavailability returns `{:error, :security_hold_unavailable}`. The operation binds kind, actor, grant/version, Session, expected generation and reason in Account-owned source state. Changing that binding cannot replay the prior result. See [SecurityHold.binding/3 and prior_result/3](../../lib/new_you/identity/security_hold.ex).

Audit's admission input accepts only attempt, actor, target, grant/version, Session, expected generation and bounded reason. Audit sets the action class and admission time. It returns a committed EvidenceRecord or `{:error, :evidence_admission_unavailable}`. The trusted source-only `establish_identity_security_obligation/1` requires an existing source transaction and returns the obligation or an error. It is not a public authority endpoint. See [PrivilegedEvidence](../../lib/new_you/audit/privileged_evidence.ex).

## 5. Lifecycle, failure and recovery

MFA progresses `disabled` to `pending` to `active`. Factor reset/disable and broad enrollment UX are not implemented. Account locks serialize validation and advancement of the accepted TOTP period; validation uses that same captured period. Active step-up also checks current Account eligibility, MFA/security versions, durable Session/Token state and exact purpose/expiry. Device or browser assertions cannot substitute. [MFA tests](../../test/new_you/identity/privileged_access_test.exs) cover replay, independent transactions, persisted cooldown and deterministic period boundaries.

Placement changes `normal` to `held`, increments hold/security versions, clears earlier review and revokes active target Sessions. Review records a current scoped reviewer distinct from the target. Release also requires that reviewer to differ from the releaser, and checks the reviewer's current grant and Account/MFA/security versions. Release changes only security posture; it does not verify email, reopen an Account or complete recovery. Review never releases a hold. [Hold tests](../../test/new_you/identity/security_hold_test.exs) cover these checks and invalidation after admission.

Account locks use stable ID order before Token/Session/grants. The lock set includes the current reviewer; a newly changed review requiring an unlocked Account fails closed. Conditional generation filters arbitrate source transitions. Successful same-operation retries return the stored result without a second transition. Distinct admitted attempts remain distinct evidence, including a losing contender. See [SecurityHold](../../lib/new_you/identity/security_hold.ex) and [race proof](../../test/support/proof/p8_13.ex).

Admission failure prevents release. A known source failure rolls back the effect, then records a source-owned failed result with a linked E2 obligation in a fresh transaction. If that recording boundary is also unavailable, the admission remains unresolved; no fabricated success/failure evidence is written. A retry reconstructs current authority and source result before proceeding. Audit cannot infer permission or replay the source. Hard termination after E1 leaves the admission and held posture; same-attempt retry can proceed through fresh authorization. Hard termination after source COMMIT leaves the source result and obligation; Audit can recover materialisation without changing source truth. The [P8-13 driver](../../test/support/proof/p8_13.ex) and [restart helper](../../test/proof/p8_13_restart.exs) exercise both cuts.

## 6. Persistence and consistency

[The schema migration](../../priv/repo/migrations/20261107184110_well14_privileged_support.exs) adds Account MFA/hold fields, Session assurance, scoped grants and minimal Audit envelope fields. Grant foreign keys, independent-approval and validity checks protect the source representation. Hold versions are nonnegative and source operation bindings are objects. Existing Account data receives disabled MFA, no assurance and an empty hold-operation map.

[The evidence guard migration](../../priv/repo/migrations/20261107184116_preserve_privileged_evidence_provenance.exs) retains the existing append-only record and obligation protections and extends immutable provenance comparison to all envelope fields. Release results must match their admission's attempt/actor/target/grant/Session/reason. [The final constraint migration](../../priv/repo/migrations/20261107185520_well14_evidence_class_and_grant_guards.exs) adds explicit action classification, strict admission/materialisation shapes and grant state/revocation consistency. Schema rollback refuses to discard new security or admission data without governed disposition. These are ordinary-write guards, not protection against a database owner disabling triggers.

TOTP secrets stay in encrypted Account attributes and are not decrypted by default. [MfaVault](../../lib/new_you/identity/mfa_vault.ex) implements AshCloak's callbacks using the existing Plug.Crypto 2.2.1 authenticated encryptor, with purpose/version AAD and bounded envelope parsing. It introduces no custom cipher or authority process. [Vault tests](../../test/new_you/identity/mfa_vault_test.exs) exercise randomised ciphertext, tamper rejection, retained-key rotation and unavailable-key failure.

Runtime key injection uses `NEWYOU_IDENTITY_MFA_ACTIVE_KEY_VERSION` and `NEWYOU_IDENTITY_MFA_KEYS_JSON` in [runtime configuration](../../config/runtime.exs). Keys are separate from database, token-signing and Communications keys. New writes use the active key; old ciphertext requires its explicitly retained key. Missing or invalid material fails closed. The random [test-only keyring](../../config/test.exs) is ephemeral and cannot serve as a persistent deployment key. No key value belongs in source, evidence or this map.

## 7. Tests, proof and evidence

Focused behavior tests are [privileged access](../../test/new_you/identity/privileged_access_test.exs), [hold lifecycle](../../test/new_you/identity/security_hold_test.exs), [vault](../../test/new_you/identity/mfa_vault_test.exs) and [E1 envelope](../../test/new_you/audit/privileged_evidence_test.exs). [P813Catalog](../../test/support/proof/p8_13_catalog.ex) adds a partial `audit_e1` family to the existing fixed P8-04 inventory. It does not mark other families complete or claim Phase-8 certification. [The ExUnit driver](../../test/new_you/proof/p8_13_test.exs) runs exact named assertions through the existing runner.

The proof includes genuine PostgreSQL contention with distinct connections/transaction IDs, same versus distinct attempts, injected admission/source failure, process termination at both committed boundaries, and independently booted current-authority/outcome checks. Fixture-only SQL seeds controlled invalidation and tears down synthetic records while restoring guards transactionally. [P813HoldFixture](../../test/support/proof/p8_13_hold_fixture.ex) resets TOTP replay state only while arranging separate fixture capabilities; the replay race itself does not reset it. Test-only seams are compiled out of production.

Observed interim runs passed the focused integration and existing Audit E2 suites. Final exact-head counts and CI belong in the PR and Plane, not in this descriptive map. Reproduce using the pinned toolchain and DevCore:

```sh
devcore-project doctor
devcore-project run test -- mise exec -- mix test test/new_you/identity/privileged_access_test.exs test/new_you/identity/security_hold_test.exs test/new_you/identity/mfa_vault_test.exs test/new_you/audit test/new_you/proof/p8_13_test.exs
devcore-project run test -- mise exec -- mix ash.codegen --check
devcore-project run test -- mise exec -- mix check
devcore-project run test -- mise exec -- mix check.deep
mise exec -- python3 tools/hex_security_audit.py
```

The new dependency set is NimbleTOTP 1.0.0 and AshCloak 0.4.0; existing Plug.Crypto supplies the vault implementation. The separate Cloak package was evaluated and removed because its published release adds an AES-CTR advisory. See the version-compatible [NimbleTOTP API](https://hexdocs.pm/nimble_totp/1.0.0/NimbleTOTP.html), [AshCloak security changelog](https://hexdocs.pm/ash_cloak/0.4.0/changelog.html) and [Plug.Crypto API](https://hexdocs.pm/plug_crypto/2.2.1/Plug.Crypto.MessageEncryptor.html). The retained Assent advisory remains unresolved in [WELL-91](https://app.plane.so/symphony-development/browse/WELL-91); production input changes invalidate the earlier exact-input exception. The [independent exact-input assessment](security/well-14-assent-assessment.md) supports an explicit owner decision before rebinding. No scanner approval or expiry changed in this implementation.

## 8. Future-agent extension guide

Start at the Identity owner functions, then follow `PrivilegedAccess.authorize_locked/4`, `SecurityHold.preflight/1`, Audit admission, the separate `source_transaction/3`, private Account action and E2 obligation/executor. Read the three migrations and the catalog's matching assertions. The map's source locators were checked against the implementation SHA above; final independent review must also inspect its documentation head.

Future grant provisioning must supply its governed approver/bootstrap and E1 activation semantics before exposing a runtime interface. Future revoke/reset/recovery work must preserve selected E2/E1 evidence and version invalidation. Reuse owner interfaces; do not promote the private primitives into routes, use DeviceAssurance for high-risk step-up, treat an admission as a bearer capability, or replay Identity from Audit jobs. WELL-15, WELL-16 and WELL-18 remain separately governed downstream work in Plane.

Cold-start walkthrough: the Domain functions resolve to the two internal Identity modules; the Account actions expose conditional generation filters; grant/MFA/Session checks remain in the current locked path; the admission has an independent commit; source result plus obligation share a later commit; the executor contains no Identity call; and the named tests/catalog cover those same boundaries. Source and tests remain the authority for what currently runs.
