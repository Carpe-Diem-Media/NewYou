# WELL-14 privileged support implementation plan

> For agentic workers: use subagent-driven-development for bounded tasks, with independent specification and code review. Use test-first development and the repository's ticket-implement contract.

Goal: prove scoped privileged support, current Session step-up, Identity security holds and independently committed Audit E1 admission.

Architecture: Identity owns grants, Account MFA and hold state, and Session assurance. Audit owns immutable admission and linked outcomes. The release sequence is current authorization, Audit admission COMMIT, fresh current authorization, conditional Identity COMMIT with durable outcome obligation, then Audit materialisation. Admission is never a capability or a command to replay Identity.

Stack: current pinned Ash 3.37.2, AshPostgres 2.15.2, AshAuthentication 4.15.1, PostgreSQL and the P8-04 deterministic harness. Verify stable NimbleTOTP and AshCloak with an authenticated Cloak vault before adoption.

## Baseline and constraints

Base is main `453b1204e03d126b6ad43b257006d7a44a4f95dd`. WELL-14 was Ready and WELL-9/WELL-11 Done at dispatch. Follow AGENTS.md, current governance/delivery routers, Identity JIT sections E/F/K, Audit JIT sections 5-8 and TB-001. Earlier Plane paths are superseded by current routing. Governance remains read-only.

No frontend is required for this owner-interface proof. No new business Resources except the already governed IdentityGrant. No generic privilege, bootstrap endpoint, independent MFA/StepUp Resource, raw business writes, Signals choreography or temporal model. Production provisioning and broad privileged-role WebAuthn policy remain outside this bounded proof.

## Task 1. Scoped grant and MFA/Session authority

Files: Identity Account, Session, Domain, new IdentityGrant/PrivilegedAccess/Vault modules, application/runtime configuration, mix dependencies, focused identity tests. Use Igniter first for supported dependency/Resource generation. Root generates final migrations after integration.

- [ ] Verify package versions, authenticated AES-GCM support, secret injection and no vulnerable cipher use.
- [ ] Add failing tests for missing/incorrect grant, encrypted secret access and successful password plus TOTP step-up. Run through `devcore-project run test -- mise exec -- mix test test/new_you/identity/privileged_access_test.exs`.
- [ ] Implement private Ash-backed grants with subject, independent approver, Support role, explicit capability, target scope, start/expiry, revocation and version. Do not expose provisioning or infer authority from named people.
- [ ] Implement Account MFA enrollment/confirmation, encrypted restricted secret, durable same-period replay rejection and fail-closed bounded guessing. Enrollment and step-up require current bearer/Session and password reauthentication.
- [ ] Store purpose, verification/expiry, MFA/security version on Session. Invalidation clears assurance. Never trust caller actor maps or DeviceAssurance.
- [ ] Add negative matrices and a real independent-transaction same-code race. Observe failing tests before each material behavior, then passing tests.

Internal integration contract: `PrivilegedAccess.authorize_locked(credentials, grant_id, target_id, capability)` runs only within an Identity Ash transaction. It locks current actor/target Accounts in stable order, then Token/Session/IdentityGrant; rechecks JWT, expiry, actor/security/MFA, purpose-bound assurance and exact Support capability/target scope; returns `{:ok, %{actor: account, target: account, session: session, grant: grant}}` or a bounded error. Public wrappers on Identity establish enrollment and step-up. Supported scope/capability vocabulary is selected in code, not added to governance.

## Task 2. Audit admission and recoverable source outcomes

Files: Audit Domain, EvidenceRecord, EvidenceObligation and materializer, new Audit privileged-evidence helper, focused Audit tests.

- [ ] Add a failing test showing one immutable admission for the same attempt, a different assertion for a distinct attempt, and rejection of attempt-ID rebinding.
- [ ] Extend EvidenceRecord for a minimal E1 envelope with attempt, actor, target, grant/version, Session reference, expected hold version, bounded reason and admitted timestamp. Preserve the original registration representation.
- [ ] Add a synchronous owner interface that establishes/replays an admission in its own transaction and refuses execution inside an existing transaction.
- [ ] Extend existing E2 obligations/materializer for hold placement, grant revocation/MFA security events where selected, and linked release outcomes. Preserve current registration worker/scheduler compatibility. Outcomes remain recoverable from an open obligation without reading/mutating Identity.
- [ ] Verify append-only records, unique identities, foreign keys and minimisation. No free-form notes, bearer/password/TOTP material or Account snapshots.

## Task 3. Identity hold lifecycle

Files: Account actions/fields, Identity Domain and new SecurityHold module, focused hold tests.

- [ ] Add failing tests for current-authority placement/review/release and absent E1, post-admission source failure, stale target, missing independent review and replay.
- [ ] Implement conditional versioned placement, explicit independent security review bound to the held version, and release. Release changes only security posture and preserves verification/lifecycle.
- [ ] Keep minimal operation binding/results on Account, with E2 obligations committed in the same source transaction. A retry returns the source result and cannot repeat a hold transition. A different attempt remains separately admitted.
- [ ] Recheck every authority after E1 COMMIT under PostgreSQL locks before the effect. An expired/revoked grant, revoked MFA, expired Session step-up or changed review/target fails closed.
- [ ] Prove that E1 failure prevents release, later source failure preserves admission, and outcome materialisation cannot replay Identity.

## Task 4. Deterministic proof, handoff and exact-head verification

Files: existing P8-04 proof infrastructure with a bounded P8-13 catalog/driver, restart helper if needed, docs/development/p8-13-privileged-support-handoff.md and docs/README.md.

- [ ] Reuse Scenario/CutPoints/Concurrent machinery for TOTP contention, admission retry contention, two release contenders, grant-revocation/expiry after admission and source rollback.
- [ ] Prove independent connections/transactions and fresh-BEAM reconstruction of current grant/Session/step-up and pending outcome recovery. Keep hooks test-only.
- [ ] Generate and inspect Ash migrations/snapshots once resource changes settle. Run migration and codegen checks through DevCore.
- [ ] Create the required eight-section source-linked handoff and verify its cold-start walkthrough against source. Record implementation SHA separately from documentation SHA.
- [ ] Run focused tests, `mix check`, `mix check.deep`, `mix ash.codegen --check`, architecture checks and `git diff --check` with the pinned mise toolchain. Review the complete diff and obtain independent specification/security/code review.
- [ ] Run the fresh Hex audit. Changed production inputs invalidate the existing Assent disposition. If still needed, present final exact-input independent HIGH assessment and a concrete owner-approval request; do not self-authorize or weaken the gate.
- [ ] Push a reviewable PR, link it to this thread immediately, record exact SHAs/results and move Plane to In Review only when required verification is satisfied. Do not merge.
