# P8-15 graduated recovery implementation handoff

## 1. Purpose, scope and version

WELL-16 adds the bounded Identity-owned graduated-recovery lifecycle. This revision describes implementation commit `57245ae0db9c341d32131506f5f98c7da79da762`, based on main `98fbeb8766ff1d20efe4f4f10baa6fc3abcc62f6`. The documentation head is separate. Verify current source, routers and [live WELL-16](https://app.plane.so/symphony-development/browse/WELL-16) before reuse. This is a full handoff under the [implementation-handoff standard](implementation-handoff-standard.md), not semantic or execution authority.

The delivery contract is incomplete. Product [§21E.19 and §21E.23](../governance/product/00_PLATFORM_v1.15.0.md) excludes recovery communications from verification and password-reset content classifications. No eligible recovery EN/AF packet is routed. Communications therefore records held, unbound obligations and admits no provider attempt. This PR grants no content approval, production/provider enablement, Phase-8 certification, Phase-9 authority or merge permission.

Current governing direction comes through the [Governance router](../governance/CURRENT_GOVERNANCE_ROUTER.json), [Delivery router](../delivery/CURRENT_DELIVERY_ROUTER.json), Product §21J.7/DEC-250 and [Identity JIT §F.6](../delivery/jit/identity/FP-001_IDENTITY_ACCESS_JIT_DOMAIN_DOSSIER_WORKING_v0.3.0.md). No durable governance changed.

## 2. Architecture, sequence and ownership

1. [RegistrationBoundary](../../lib/new_you_web/registration_boundary.ex) dispatches the five recovery routes through the existing browser/CSRF pipeline without full-connection router telemetry. [PrivacyTelemetry](../../lib/new_you_web/privacy_telemetry.ex) scrubs recovery metadata. [RecoveryController](../../lib/new_you_web/controllers/recovery_controller.ex) requires a dev/test fixture build and `p8_15_browser_development_fixtures`. GET/HEAD returns an empty, non-consuming response. POST responses are uniformly empty. No participant wording or visual composition was added.
2. [Identity](../../lib/new_you/identity.ex) exposes the supported recovery interfaces. [Recovery.request/3](../../lib/new_you/identity/recovery.ex) canonicalizes email, applies a 250 ms database-transaction timeout and a common 500 ms response floor, and returns `:ok` for known, unknown and malformed requests. This is not a guarantee against arbitrary scheduler or host delays.
3. The request locks Account before case/proof authority. It reuses the active case or creates a [RecoveryCase](../../lib/new_you/identity/recovery_case.ex) and an existing Identity [Token](../../lib/new_you/identity/token.ex). A verified channel gets a purpose-bound proof and a durable held Communications obligation in the same transaction. An unverified Account enters held manual review without acquiring verification or proof assurance.
4. Explicit proof submission validates the current Token and Account binding, consumes the proof and advances durable case assurance atomically. Delivery and passive retrieval cannot advance it.
5. Ordinary completion calls `Recovery.finish/6` under the Account lock. Credential replacement, Session/Device revocation, registration-binding invalidation, E2 obligation plus initial Audit scheduling, required notice obligation and completed case share one transaction. No Session is created.
6. [ManualRecovery](../../lib/new_you/identity/manual_recovery.ex) adds current scoped staff authorization, an independent approver and independently committed Audit E1 before the exceptional completion. Communications owns delivery obligations; Audit owns evidence. Neither owns recovery truth.

## 3. Ash map

[RecoveryCase](../../lib/new_you/identity/recovery_case.ex) uses AshPostgres, AshStateMachine, private actions and deny-by-default policies. Its generic actions delegate to [Actions.Recovery](../../lib/new_you/identity/actions/recovery.ex). The Identity wrapper invokes the owning action and normalizes errors. Private resource actions are not caller authorization substitutes.

[Account](../../lib/new_you/identity/account.ex) owns the assurance floor, security hold and existing credential/security versions. Token uses the pinned AshAuthentication `StoreTokenChange`, with fixed claims rather than a signed bearer. `recovery_case_id` has a FK and unique proof identity. Existing [Session](../../lib/new_you/identity/session.ex), [DeviceAssurance](../../lib/new_you/identity/device_assurance.ex), [IdentityGrant](../../lib/new_you/identity/identity_grant.ex) and [PrivilegedAccess](../../lib/new_you/identity/privileged_access.ex) remain authoritative for their existing security facts.

[Ash Signals](../../.agents/skills/ash-framework/references/ash/signals.md) were considered and are not used for required Communications/E2 acceptance because their results are required before source commit. Temporal Resources are not needed for current case state plus append-only provenance. Existing AshOban owner schedules remain in use. No dependency, Repo, token store, generic workflow engine, Redis or process-local business authority was added.

## 4. Interface contracts

- `Identity.request_recovery(email, locale, operation_id)` returns only `:ok`. It creates no login or email verification. A duplicate request never reduces assurance. An elapsed active case becomes expired before a fresh operation creates a successor.
- `submit_recovery_proof(proof, operation_id)` returns `{:ok, :accepted}`, a terminal `:failed`/`:expired` outcome, or the common recovery error. The same committed acceptance operation is replay-safe. Different proof purposes and revoked proof fail closed.
- `complete_recovery(proof, password, operation_id)` returns `:completed` once and `:already_completed` for its committed operation receipt. Changed password input on that retry is ignored. A different completion operation cannot replay the effect. The current password is rejected without consequences.
- `approve_manual_recovery(request)` takes current credentials, scoped grant, case/version, operation ID and `:verified_recovery` reason. It returns an approved case version. Approval replays only its bound operation and authority. `complete_manual_recovery/1` additionally takes the replacement password, requires a distinct current actor and returns the completed receipt.
- `cancel_recovery/2` terminates a current claimant-bound case. Completed, failed, expired and cancelled cases cannot reopen.
- `recovery_delivery/3` is a trusted transaction-only serialization seam. It returns a transient bearer only for the current proof/destination/locale. It supplies no content or provider permission.

See the actual typespecs in [Identity](../../lib/new_you/identity.ex) and action guards for complete return/input details.

## 5. Lifecycle, failure and recovery

The state enum is `requested`, `proof_pending`, `additional_assurance`, `held_manual_review`, `completed`, `failed`, `expired`, `cancelled`. State is separate from required and satisfied assurance. The selected ordinary representative uses a verified-channel proof. MFA-enabled, privileged, held or unverified Accounts require the stronger floor. The current implementation preserves the raised Account floor across later cases. It implements no general risk scoring or new recovery factors.

A case lives for one hour; initial proof consumption requires the original 15-minute validity. Once consumed, assurance is durable. Manual completion checks the consumed proof/case linkage and current case deadline, not the expired delivery-link lifetime. Staff review expires no later than its case, grant and five-minute step-up. Staff Accounts lock in sorted order before Token/Session/grant/case locks. Final completion rechecks both people, grants, MFA/security generations, Session/step-up, case version, hold version, Account binding and E1 envelope.

An unavailable ordinary channel creates a hold with zero satisfied assurance; this bounded implementation supplies no document-based or operator-discretion substitute. Manual completion requires an already accepted verified-channel proof plus two current scoped staff actors. It leaves the security hold in place. P8-13 separately governs release. Sensitive email change is blocked by the database while held; implemented MFA/login/reset paths also reject held authority.

Failure before source commit rolls back the complete acceptance. E1 remains an admitted attempt after source failure. A caught failed source attempt records a linked failed E2; that failed operation cannot later become success. Process death after E1 can leave no outcome yet. The pending case and admission survive, and retry of that operation revalidates current authority and completes once. A changed or unavailable current authority never permits replay of the protected effect.

Cases bind the original Account email, credential/security/hold/MFA generations and signing configuration through a keyed digest. A later competing Account change invalidates the old binding. Real PostgreSQL tests prove completion races with password login and password reset. The P8-16 primary-email owner API is not implemented here. Its future mutations must preserve the same Account lock and current-version contract; the email-change test is a fixture representation of an earlier owner commit, not proof of the future complete P8-16 workflow.

## 6. Persistence and consistency

The [generated lifecycle migration](../../priv/repo/migrations/20261110154314_graduated_recovery.exs), [proof constraints](../../priv/repo/migrations/20261110154755_recovery_constraints.exs), [database guards](../../priv/repo/migrations/20261110160000_recovery_guards.exs) and [proof-shape constraints](../../priv/repo/migrations/20261110160037_recovery_proof_shape.exs) enforce unique active case per Account, immutable request/completion identities, purpose/case proof shape, terminal timestamps, assurance bounds and append-only transition history. Triggers reject assurance reduction, history rewrite, terminal reopening/deletion and held email changes. Source writes use owning Ash actions, not Repo or SQL business-write APIs.

The [legacy-admission preservation migration](../../priv/repo/migrations/20261110161000_preserve_legacy_admissions.exs) retains WELL-15's `NOT VALID` historical-row compatibility while enforcing the complete Audit shape on every new write. It neither rewrites legacy evidence nor validates it silently. Populated recovery history requires a forward migration; the generated down refuses to discard cases or notices.

[Communications.establish_recovery/1 and establish_recovery_notice/1](../../lib/new_you/communications.ex) create distinct causal roles on the existing [MessageIntent](../../lib/new_you/communications/message_intent.ex). Their content binding is absent, disposition held and reason `content_ineligible`. Existing message roles still require every content binding field. The [executor](../../lib/new_you/communications/executor.ex) rejects provider admission for recovery roles. No bearer, rendered URL/body or submitted password is stored in an intent, case, Audit payload or job argument. Recovery Token metadata survives framework expiry cleanup so it cannot erase a pending case's accepted assurance or completed receipt. This is not a new Privacy retention policy.

## 7. Tests, proof and observed evidence

[Recovery lifecycle tests](../../test/new_you/identity/recovery_test.exs), [manual tests](../../test/new_you/identity/manual_recovery_test.exs), [PostgreSQL concurrency/restart tests](../../test/new_you/identity/recovery_concurrency_test.exs), [browser transport tests](../../test/new_you_web/controllers/recovery_controller_test.exs), [Communications obligations](../../test/new_you/communications/recovery_obligation_test.exs) and [Audit tests](../../test/new_you/audit/recovery_evidence_test.exs) exercise real owners. [P815](../../test/support/proof/p8_15.ex) reuses P8-04 Scenario, CutPoints and RegistrationSeam. [Fresh BEAM proof](../../test/proof/p8_15_restart.exs) transfers test inputs through stdin and emits fixed result markers. It stores no secret artifact.

Observed before the documentation head: 36 ticket-focused tests passed, including four existing reachability checks. Deep passed with zero errors. Formatting, warnings-as-errors compilation, design-system checks, architecture, generated usage rules, strict Credo, Sobelow and Ash codegen checks passed. RED evidence exists for missing lifecycle behavior, scanner dispatch, terminal reopening, telemetry leakage, expired-case replacement and bounded request contention. Some delegated initial RED attempts stopped at toolchain or concurrent compile errors; those are not claimed as behavior-level RED proof. The pinned toolchain is Elixir 1.20.5 / OTP 29.1.2; package locks remain Ash 3.37.2, AshAuthentication 5.0.0-rc.17, AshPostgres 2.15.2 and AshOban 0.10.2.

The first local `mix check` ran 639 tests and failed 118. It exposed corrected route/action inventories, fixture cleanup/count expectations and preservation of the legacy admission constraint. It also encountered two pre-existing shared TEST Accounts created before this task, plus existing global-empty-table assumptions. The unchanged main `98fbeb8` reproduces the registration primitive failure with three Accounts observed instead of one. The later focused run including the P8-05 aggregate passed 46/47, with the aggregate still failing on its global-empty evidence assumption. No shared database reset or pre-existing row deletion was performed. Only this task's 20 orphaned synthetic recovery intents were removed after scoped teardown was corrected.

DevCore's alternate project-config allocation was tested, but NewYou LocalConfig rejects a different TEST database name. The empty temporary database was removed and standard ignored environment files restored. No allocation guard was weakened. Hosted clean-environment CI remains required. Actual recovery delivery and provider ambiguity for recovery remain blocked by content authority. The official TB-001 coverage inventory stays partial; these tests do not certify Phase 8.

Reproduce with the canonical DevCore profile and pinned toolchain:

```sh
devcore-project doctor
mise exec -- devcore-project run test -- mix test test/new_you/identity/recovery_test.exs test/new_you/identity/manual_recovery_test.exs test/new_you/identity/recovery_concurrency_test.exs test/new_you_web/security/authentication_reachability_test.exs test/new_you/communications/recovery_obligation_test.exs test/new_you/audit/recovery_evidence_test.exs test/new_you_web/controllers/recovery_controller_test.exs
mise exec -- devcore-project run test -- mix check
mise exec -- devcore-project run test -- mix check.deep
mise exec -- devcore-project run test -- mix ash.codegen --check
git diff --check
```

Local outputs and failed attempts are retained in `/tmp/newyou-well16-evidence`. Exact documentation-head check and hosted CI results belong in the PR/Plane evidence. No visual template or style changed, so no Hallmark render verification is claimed.

## 8. Future-agent extension and review boundary

Cold-start walkthrough checked the Identity interfaces, RecoveryCase actions and constraints, Account-first locks, Token consumption, manual E1/source/E2 sequence, held Communications roles and the linked tests against the recorded implementation. The consumed-proof expiry error and untracked recovery fixture cleanup were corrected before this map. Source remains controlling.

Resolve the recovery Product classification and exact eligible EN/AF Content decisions through their owners before adding content binding/provider execution. Do not reuse password-reset approval or turn a held obligation into recovery success. Extend primary-email behavior under WELL-17 through the Account serialization contract. Do not add a second proof store, raw recovery-evidence fields, generic workflow or new authority from jobs, Audit, provider observations or browser state.

The PR remains draft while delivery authority and full verification are incomplete. Independent ChatGPT Master Gate must review the final exact head, complete diff, current Plane contract, this handoff and required CI. Its authentic review must supply `reviewed_head`, `reviewer`, `review_reference` and `diff_sha256`. The accountable repository operator must preserve that review in trusted private custody, materialize `review.json` and run the documented pre-merge collector. Separate owner merge authorization is still required. After an authorized merge, read-only resulting-main parent/tree certification must pass before Plane Done or dependent implementation. The author supplies no independent attestation and performs no merge.
