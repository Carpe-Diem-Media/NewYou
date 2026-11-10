# FP-001 Identity & Access JIT Domain Dossier

```text
PHASE 7B JIT DOMAIN DOSSIER
FEATURE PACK: FP-001
DOMAIN: IDENTITY & ACCESS
IMPLEMENTATION-GRADE PLANNING LAW
NON-EXECUTABLE
NOT PHASE 7C DEVELOPMENT-ENTRY AUTHORITY
DOES NOT OVERRIDE PRODUCT / ARCHITECTURE / DOMAIN / ROADMAP LAW
```

**Artifact version:** v0.3.0. This substantive successor adopts the accountable Identity & Access security owner's password-reset consequence policy in F.3a. All other inherited semantics remain unchanged. The unchanged v0.2.0 predecessor remains at `docs/delivery/jit/identity/FP-001_IDENTITY_ACCESS_JIT_DOMAIN_DOSSIER_WORKING_v0.2.0.md`; the exact PR #150 candidate remains at `docs/history/platform/archive/FP-001_IDENTITY_ACCESS_JIT_DOMAIN_DOSSIER_WORKING_v0.2.0.md`, and the promoted v0.1.4 predecessor remains at `docs/history/platform/archive/identity_promotions/FP-001_IDENTITY_ACCESS_JIT_DOMAIN_DOSSIER_WORKING_v0.1.4.md`.

**Status:** Owner-approved semantic successor, pending independent exact-head review and authorised integration. The branch router selects this candidate for verification; it becomes current on main only after that integration. No v0.3.0 certification, application proof, Ready transition, merge or production approval is claimed here. Historical v0.2.0 certification and implementation-entry records below remain predecessor evidence.

**Owner decision:** `WELL-13-IDENTITY-RESET-SECURITY-POLICY-APPROVAL-20261110`, approved without amendments by the requesting human acting as the self-attested Identity & Access security owner. [Plane WELL-13 decision, comment 8db3c363-0b8d-400f-bf7e-06010387dc8c](https://app.plane.so/symphony-development/browse/WELL-13). The connected comment author records the human decision; this is not a runtime IdentityGrant or independent certification. Applicability is bounded Phase-8 development, testing and proof only.

<!-- IDENTITY_V030_SEMANTIC_SUCCESSOR_START -->
The structured block describes this semantic successor only. The predecessor's certification records remain in the unchanged v0.2.0 file. Live work-item state remains in Plane.
```json
{
  "artifact_version": "v0.3.0",
  "predecessor_version": "v0.2.0",
  "semantic_change": "password_reset_account_wide_security_boundary",
  "owner_decision": "WELL-13-IDENTITY-RESET-SECURITY-POLICY-APPROVAL-20261110",
  "owner_approval_scope": "BOUNDED PHASE 8 DEVELOPMENT / TEST / PROOF ONLY",
  "certification_rule": "Independent exact-head review, authorised integration and resulting-main verification are required before application development starts",
  "execution_authority": "Live Plane Ready gate; this artifact alone does not authorize implementation",
  "production_authority": false
}
```
<!-- IDENTITY_V030_SEMANTIC_SUCCESSOR_END -->

### PR #150 certification and resulting-main evidence

| Evidence | Result |
|---|---|
| PR #150 | [Merged](https://github.com/JCSchoeman96/NewYou/pull/150) |
| Certified candidate head | `d43b6b32c2dec9cf54b5d4492d942a70984a8591` |
| Candidate base | `b899bb8ac6fcaff048d87f3a1f8d94f075797bc2` |
| Resulting main / merge commit | `2db8772153bb957140570a6606cda88c5e0b8853` |
| Candidate and resulting-main tree | `06d9c13adcbed956b2452e749bd23a0991851d35`; zero changed files |
| Exact-head CI | [Run 40299236086](https://github.com/JCSchoeman96/NewYou/actions/runs/40299236086): routing, Foundation Smoke, Foundation Integrity and Foundation Full passed; Application CI skipped by path routing |
| Resulting-main CI | [Run 40302375237](https://github.com/JCSchoeman96/NewYou/actions/runs/40302375237): routing, Foundation Smoke and Foundation Integrity passed; Foundation Full and Application CI skipped by main routing |
| Exact-head semantic certification | COMPLETE as confirmed by the owner handoff; PR #150 has no separate review record in GitHub's review/comment API |
| Current-status promotion | PR #151 status successor; this successor does not assert its own independent review or merge completion |


### Inherited v0.1.4 certification evidence

| Evidence | Result |
|---|---|
| PR #70 | [Merged](https://github.com/JCSchoeman96/NewYou/pull/70) |
| Certified candidate head | `613ea1d52f6ffdadb3910cee3c62ea5dbd88f583` |
| Candidate tree | `421b9c1670586699e12807bc28f01179ca755fa7` |
| Prior main / merge base | `d9174de272ac7b98c5a14f0d55c60c80e15759fb` |
| Resulting main / merge commit | `df6190a06bdc8aa4b99f6ed3a18cb9e3e12e22fb` |
| Resulting-main tree | `421b9c1670586699e12807bc28f01179ca755fa7` |
| Candidate-to-resulting-main comparison | Zero changed files |
| Exact-head Foundation Integrity | [Run 37198148095](https://github.com/JCSchoeman96/NewYou/actions/runs/37198148095), SUCCESS; 287 tests, 535 assertions, zero findings |
| Fresh independent exact-head review | PASS; [PR #70 attestation](https://github.com/JCSchoeman96/NewYou/pull/70#issuecomment-5980442552) |
| Resulting-main Foundation Integrity | [Run 37205571249](https://github.com/JCSchoeman96/NewYou/actions/runs/37205571249), SUCCESS on the resulting-main SHA; 287 tests, 535 assertions, zero findings |
| Fresh independent post-merge review | PASS on `df6190a06bdc8aa4b99f6ed3a18cb9e3e12e22fb` |
| Durable post-merge attestation | COMPLETE; current v0.1.3 and Open Work v1.2.56 preserve the supplied attestation |
| v0.1.2 archive SHA-256 | `28dfe34dce0e9c48c737f666b112aeb89ccf45c0dfa10d2cfb81877def2538db` |
| Exact v0.1.3 candidate archive SHA-256 | `52fe67fcf6335bc0f2675c772a15a5ccdf75150f2ac4d92c98d61a9c48369285` |

| PR #76 candidate head | b349202f79825b641bf73ffe943da497a247e120 |
| PR #76 candidate base | 3f06eafe58c2cc441a090e804b4169c1c3c4ca2b |
| Resulting main | 90f96ba3452c95112bf6ec4ce5bb897676adbed4 |
| Candidate/resulting-main tree | 44ad689e46e823e4f453b32edd39306d99c62015; zero changed files |
| Exact-head Foundation Integrity | 37419452502 PASS; 291 tests, 541 assertions, zero findings |
| Resulting-main Foundation Integrity | 37425057900 PASS; 291 tests, 541 assertions, zero findings |
| Fresh independent exact-head and post-merge review | PASS; ChatGPT / GPT-5.6 Sol, distinct from poster JCSchoeman96; reviewer did not author/modify candidate |
| Pre-merge attestation | https://github.com/JCSchoeman96/NewYou/pull/76#issuecomment-6010805470 |
| Post-merge attestation | https://github.com/JCSchoeman96/NewYou/pull/76#issuecomment-6011044499 |
| Exact PR #76 candidate archive SHA-256 | 1557a4bded20b94fc363d96dd5a601213de105e0daccfa1970b869a0e38f362f |

The v0.1.3 and PR #76/PR #77 evidence above belongs to the unchanged v0.1.4 predecessor. It does not certify this v0.2.0 candidate.

PR #70 closed the durable-delivery contradiction for email verification, password reset, recovery and new-address primary-email-change confirmation. Provider acceptance or delivery grants Communications no Identity authority. The approved bounded protected-delivery retention remains limited to the crash-safe delivery purpose. Optional magic-link authentication and session bearer tokens remain outside this exception.

This successor records no Product, Architecture, Domain or Roadmap amendment and changes no PMR semantics. It adds the Identity-owned RegistrationOperation Resource because registration idempotency requires independent durable request binding, terminal outcome, concurrency, security, retention and restart/recovery state. It selects no notification provider, email vendor, encryption product, KMS/vendor, queue or worker configuration, retry policy or OQ-036 resolution. MessageIntent and DeliveryAttempt remain the only required durable FP-001 Communications business concepts. Phase 7C status remains as recorded by current Open Work; this dossier is not Phase 7C or implementation authority.

```text
Phase 7A Skeleton (complete)
→ Phase 7B Identity & Access JIT Domain Dossier (this contract)
→ Phase 7C Final Feature Pack Contract (complete/current)
→ bounded Phase 8 architectural proof under its separate authorisation
```

## A. Baseline and scope

The original dossier baseline was certified `main` at `38022caea64cb2522ab8fc4db730099a94cd6600` and the reconciled Phase 7A skeleton candidate. The v0.1.3 durable-delivery correction is certified/current. The v0.1.4 predecessor remains preserved as historical certification evidence. This v0.2.0 status successor is based on resulting main `2db8772153bb957140570a6606cda88c5e0b8853` and current Product, Architecture, Domain and Roadmap authority. It covers Identity & Access only for the FP-001 outcome: a public visitor can become a verified individual 18+ account holder, receive exactly one canonical active PMR after successful Account creation, authenticate, recover access and traverse a controlled support/admin boundary without exposing unfinished product spaces.

In scope are the minimum account, email verification, password/magic-link authentication, session, device assurance, recovery, primary-email change, identity-side grant, compromise, duplicate-reconciliation and Platform Member Reference contracts needed for that outcome. Social login, passkeys, native clients, generic tenancy, participant MFA user experience/configuration, full deletion orchestration, relationship permissions, Commerce and Communications implementation remain outside this dossier.

This remains a planning contract, not a Phase 8 proof claim. `OQ-034` architecture selection is resolved; its executable proof remains a Phase 8 obligation. Exact threshold values remain `OQ-035`; notification provider/channel policy remains `OQ-036`.

## B. Authority review

The governing sequence is Product Law → Architecture Law → Domain Law → Roadmap → approved Phase 7A Skeleton → this dossier. Relevant current anchors are `01_DECISIONS_v1.8.0.md` DEC-017–028, DEC-244–267, DEC-297–298 and OQ-034–036, `00_PLATFORM_v1.8.0.md` §§15, 16, 21J.1–21J.24 and 21P, `03_ARCHITECTURE_v1.1.1.md` §§4–16 including §6.6 and §10.4, `04_DOMAIN_MAP_v1.2.0.md` §§3–6.15, `05_ROADMAP_v1.2.3.md` FP-001, the reconciled Phase 7A skeleton §§5–17, and current FLOW-01 evidence in `docs/governance/architecture/references/REFERENCE_FLOW_PRESSURE_TESTS_WORKING_v0.3.0.md`.

The v0.1.3 predecessor corrected the durable-delivery contradiction between must-not-lose verification/recovery delivery and an absolute presented-bearer retention prohibition. That protected-delivery seam remains unchanged in J.1. This v0.2.0 successor resolves the Identity JIT conflict between registration-operation durability and the prior seven-Resource physical set. The accepted request-binding invariant needs its own Identity-owned Ash Resource because it has a durable lifecycle, concurrency boundary, security boundary and restart/recovery obligation. The accepted Resource remains within Identity's registration-operation ownership in the P8-05 spec and follows the Architecture Ash write boundary. It does not amend Product, Architecture, Domain or Roadmap law. The v0.1.4 content-ownership and scanner-safe proof-consumption corrections remain unchanged.

Account, credential, Token, Session, PMR, Audit and Communications meanings remain unchanged. RegistrationOperation is owned by Identity & Access and records registration-idempotency machinery only. It creates no Domain, generic operation ledger, duplicate Audit authority or cross-Domain write path. This dossier does not resolve `OQ-035` or `OQ-036`, amend `01_DECISIONS`, change Phase 7C, or select a proof classification. `OQ-034` architecture selection is resolved; its executable proof remains a Phase 8 obligation.

## C. Outcome and design test

Every proposed concept was tested against the outcome. It is accepted only if it owns an independently durable invariant, lifecycle, concurrency boundary, security boundary or recovery/reconciliation obligation. A browser, LiveView process, cache, queue and audit record are not identity authority.

The minimum path is:

```text
anonymous request
→ Account.register with 18+/terms/privacy gates
→ Security Challenge(verify_email) + durable communication intent
→ participant explicitly confirms a current proof-consuming action
→ Challenge.consume proves email; Account becomes verified
→ authenticate password or optional magic link
→ Session issued with current assurance
→ current Account/Grant/Consent/relationship authority checked at each protected action
→ recovery, email change, revocation and support actions revalidate current authority
```

## D. Resource map first

### D.1 Domain concepts and physical Ash representations

The following mapping separates business concepts from physical Resources. The physical Resource set is an outcome, not a target:

| Domain concept | Physical Ash representation | Durable authority/invariant |
|---|---|---|
| Account / canonical identity | `NewYou.Identity.Account`, the authenticated AshAuthentication subject | One canonical email/identity; orthogonal account, verification and security dimensions |
| Registration operation | `NewYou.Identity.RegistrationOperation`, a private Identity Ash Resource | One opaque operation ID binds one immutable registration request to at most one terminal outcome; PostgreSQL/Ash actions own live binding and permanent anti-rebinding tombstone; not authentication or credential authority |
| Platform Member Reference | Identity & Access Account truth; exact physical field/resource representation remains deferred under `ARQ-IAM-013` | Exactly one canonical active PMR is assigned only as part of successful individual Account creation; active uniqueness, ordinary immutability, legitimate-reactivation continuity and permanent non-reuse are preserved |
| Authentication credential | Account authentication fields/actions, including the sensitive `hashed_password` field expected by stable AshAuthentication v4; no separate credential Resource | One password authority on Account; hash replacement/revocation and credential version are authoritative |
| Verification, reset, magic-link and recovery proof | Identity-owned PostgreSQL-backed Token Resource using the `AshAuthentication.TokenResource` Resource extension, with purpose/JTI, token metadata/presence, expiry and revocation; no parallel SecurityChallenge Resource | One deterministic presented-proof decision; the framework extension configures the token Resource, which stores token information/revocation state, not raw presented secrets, and a token proves only its configured purpose |
| Browser/API authentication token | Identity-owned Token Resource using the `AshAuthentication.TokenResource` extension; first-party browser transport is a secure cookie | Token presence/revocation and expiry; no public/external bearer client in FP-001 |
| Application session | `NewYou.Identity.Session` | User-visible session identity, inactivity/absolute expiry and individual/global revocation; validity also requires its linked token to pass |
| Trusted device / device assurance | `NewYou.Identity.DeviceAssurance` | Consent, server-side fingerprint, expiry and revocation; never high-risk step-up authority |
| MFA factor | Account-protected MFA fields/actions using the selected stable TOTP primitive | Enrollment confirmation, protected secret, last-use replay boundary, disable/revoke and recovery/reset policy; no separate MFA Resource is required for FP-001 |
| Identity-side role/grant | `NewYou.Identity.IdentityGrant` | Scoped, approved, expiring/revocable role authority; no relationship permission |
| Graduated recovery | `NewYou.Identity.RecoveryCase` | Durable assurance, hold/manual review, completion and replay/concurrency state |
| Duplicate reconciliation | `NewYou.Identity.ReconciliationCase` | Review, conflict, applied decision and immutable provenance |
| Primary email change | Durable pending-change fields/state on Account plus purpose-bound proof in the Identity-owned Token Resource | One active operation per Account; target email, operation/version, delay/review and supersession survive restart; historical requested/applied/cancelled/superseded evidence belongs to Audit & Evidence |

Eight-resource physical Ash implementation set: `Account`, Identity-owned `Token`, `Session`, `DeviceAssurance`, `IdentityGrant`, `RecoveryCase`, `ReconciliationCase`, and `RegistrationOperation`. The first seven Resource meanings and ownership remain unchanged. The Token Resource is PostgreSQL-backed and configured using the `AshAuthentication.TokenResource` Resource extension. `Platform Member Reference`, `Credential` and `SecurityChallenge` remain Account or Token concepts; this candidate adds no PMR Resource and does not choose a PMR field, schema or index representation. Email change remains Account state because FP-001 permits one pending primary-email operation per Account. RegistrationOperation is the eighth Resource because its accepted invariant has an independent durable lifecycle, concurrency and security boundary, and restart/recovery obligation. The final Token Resource module name follows the established Identity Domain implementation convention.

#### 1. Account

* **Purpose/owner/authority:** Canonical human identity and individual account; owned by Identity & Access; PostgreSQL is durable authority. Account is the authenticated AshAuthentication Resource.
* **Identifier and key categories:** UUIDv7 opaque primary identifier; canonicalised email identity key; immutable creation/provenance metadata; no identifier is a bearer secret.
* **Attributes:** required first name, surname, canonical email, preferred language, 18+ confirmation, terms/privacy acceptance references, email verification timestamp/state, account lifecycle state, security posture, password hash and credential version, `mfa_enrollment_state`, encrypted TOTP secret, `mfa_confirmed_at`, last accepted TOTP period/time, MFA revoked/disabled/reset metadata, and optimistic version. Phone and city are optional. Full DOB, health and medical data are absent. Email-change fields are `pending_new_canonical_email`, `email_change_operation_id`, requested/reauthenticated/confirmed/delay/review/applied/cancelled/expired timestamps, superseded-by reference and operation version.
* **Relationships:** Sessions, Device Assurances, Identity Grants, Recovery Cases and Reconciliation Cases; the Identity-owned Token Resource records reference the Account. The PMR belongs to the Account and is not a second identity, credential or authority record. Credentials and Challenges are logical concepts, not child Resources. External references to communications intent, Privacy consent and owning business-domain records are identifiers/provenance only.
* **Sensitive/immutability:** email, security state, closure state and acceptance references are restricted; name/language are personal; provenance, creation and closure facts are append-only or superseding. Current fields may change only through named actions.
* **Retention/closure:** account closure is not full deletion. Identity retains only what approved retention/deletion contracts permit; full deletion orchestration belongs to Privacy & Consent.
* **Authoritative actions:** `register`, `mark_email_verified`, `change_primary_email`, `place_security_hold`, `release_security_hold`, `close`, and `restore_after_recovery`.
* **Policy/audit/integration:** self-service field policy plus current session/assurance; staff actions require scoped grant and reason. Audit material lifecycle transitions. Communications receives intent, never verification truth; Privacy is checked, not written by Identity.
* **Persistence:** independent persistence is required because identity, verification gate, closure and security state must survive restart and be queried by every protected Domain.

#### 2. Authentication Credential (domain concept; no separate Ash Resource)

* **Purpose/owner/authority:** Password credential and authentication-method status for one Account; Identity & Access/PostgreSQL, implemented by Account's stable AshAuthentication fields/actions.
* **Attributes:** account reference, method (`password` or optional `magic_link` capability), password hash metadata, credential status, created/changed/revoked timestamps, and version. Raw passwords and magic-link authentication tokens are never persisted. Verification, password-reset, recovery and primary-email-change confirmation delivery material may be retained only as the protected delivery capability in J.1, never as an ordinary credential field.
* **Relationships:** belongs to Account; invalidates linked Sessions and Device Assurances when a security-changing action requires it.
* **Sensitive/immutability:** hash and security metadata are highly restricted; hashes are replaceable, raw passwords never recoverable. Only the bounded delivery executor may recover protected verification, password-reset, recovery and primary-email-change confirmation material under J.1. History is retained only as minimal security evidence.
* **Lifecycle/actions:** password credential `absent → active → replaced/revoked`; `set_password`, `authenticate_password`, `reset_password`, `revoke_credential`. Magic link is an authentication strategy, not a second identity.
* **Policy/audit/integration:** password fields are sensitive and write-only; authentication returns a generic failure. Password hashing is delegated to the selected maintained provider. Credential changes emit revocation/security consequences and audit evidence.
* **Persistence:** no independent persistence; Account is the single password authority. A separate Credential Resource would duplicate the stable framework's `hashed_password` expectation and create contradictory credential lifecycle state.

#### 3. Security Challenge (domain concept; Identity Token Resource representation)

* **Purpose/owner/authority:** One-purpose, bounded proof capability for email verification, password reset, recovery proof or email-change confirmation; represented by the Identity-owned PostgreSQL-backed Token Resource configured with the `AshAuthentication.TokenResource` extension.
* **Attributes:** UUIDv7 id, account reference where known, purpose, secret fingerprint/hash, issued/expiry/consumed/revoked timestamps, supersession reference, attempt/usage metadata, and correlation/provenance. The Identity Token Resource does not store the presented bearer token. Only the protected delivery capability in J.1 may retain verification, password-reset, recovery and primary-email-change confirmation material for crash-safe Communications retry.
* **Relationships:** belongs to Account or a Recovery Case; may be linked to an Email Change attempt by purpose/reference. Communications receives a separate intent id.
* **Lifecycle/actions:** `issued → valid → consumed`; `issued → expired`, `revoked` or `superseded`; replay is a terminal rejected observation, not a second transition.
* **Policy/audit/integration:** purpose-specific action only; no generic “verify anything” endpoint. Non-mutating retrieval may validate enough context to present a safe confirmation surface, but authoritative consumption requires the explicit participant action and current checks in J.1a. Confirmation establishes Identity truth only after server-side fingerprint, purpose, expiry and account-state checks.
* **Persistence:** Identity Token Resource persistence is required for single-use replay control, expiry, replacement and crash-safe proof consumption; no parallel challenge store is permitted.

#### 4. Session

* **Purpose/owner/authority:** Individually identifiable browser authentication session; Identity & Access/PostgreSQL linked to the selected stable Identity Token Resource configured with the AshAuthentication.TokenResource extension.
* **Attributes:** UUIDv7 id, account, credential/method, `framework_token_jti` or equivalent Identity Token Resource reference, user-agent/device summary, created/last-seen timestamps, inactivity/absolute expiry, revoked timestamp/reason, `assurance_level`, `step_up_purpose`, `step_up_verified_at`, `step_up_expires_at`, and version.
* **Relationships:** belongs to Account and may reference Device Assurance; never embeds relationship authority or consent.
* **Sensitive/immutability:** framework token references and network/device security evidence are highly restricted; raw token secret is never stored in Session. Creation and revocation facts are append-only; last-seen and current step-up assurance are mutable bounded security state.
* **Lifecycle/actions:** `active → expired`, `revoked` or `logged_out`; session-specific and global revocation are distinct actions. A Session is valid only when its own state/expiry, linked Identity Token Resource acceptance, Account current permission and security posture all pass. Elevated assurance is separately bounded by the current step-up fields and is cleared or downgraded by each defined invalidator.
* **Policy/audit/integration:** secure HttpOnly cookie transport; every protected Ash action rechecks current session/revocation and required assurance. LiveView only reconstructs current actor context. Audit creation for privileged/high-risk sessions and revocation, not raw tokens.
* **Persistence:** independent persistence is required for multi-node reconstruction, visible session listing, revocation and the current durable step-up assurance boundary. Session does not calculate or store a second token fingerprint authority.

#### 5. Device Assurance

* **Purpose/owner/authority:** Limited, participant-consented trust associated with a device/session family; Identity & Access/PostgreSQL.
* **Attributes:** UUIDv7 id, account, device-token fingerprint, name, assurance level, created/last-used, expiry, revoked timestamp/reason and version. No raw fingerprinting payload or invasive device profile is required.
* **Relationships:** belongs to Account; can authorise session convenience but not high-risk step-up.
* **Lifecycle/actions:** `pending → trusted → expired/revoked`; suspicious activity and credential/security changes revoke it. The browser artifact is only a random opaque cookie value; server-side fingerprint and state are authoritative.
* **Policy/audit/integration:** explicit consent, stricter staff policy, no bypass of email change, export, deletion, MFA or other high-risk step-up. Audit grant/revoke and suspicious invalidation.
* **Persistence:** independent persistence is required by locked trusted-device policy and user-visible revocation. DeviceAssurance is not session or step-up authority.

#### 6. Identity Grant

* **Purpose/owner/authority:** Identity-side role/privilege assignment, including named staff/practitioner roles and exceptional break-glass records; Identity & Access/PostgreSQL.
* **Attributes:** subject, role/capability, scope, reason, approver, start, expiry/review date, source relationship reference, state and revocation metadata. It does not contain relationship-owned permission.
* **Relationships:** belongs to Account; may reference an organisation/practitioner relationship owned elsewhere.
* **Sensitive/immutability:** grants, approvals, reasons and revocations are highly restricted; history is append-only; current state is superseding projection over history.
* **Lifecycle/actions:** `requested → approved/assigned → active → expired/revoked`; break-glass is `requested → active → expired/revoked → reviewed` and is never an ordinary role.
* **Policy/audit/integration:** no self-approval; MFA and named actor required; least privilege, narrow scope, expiry and review. Business Domains re-evaluate their own relationship/purpose/consent authority.
* **Persistence:** independent persistence is required for scoped policy, revocation, review and audit.

#### 7. Recovery Case (physical Ash Resource)

* **Purpose/owner/authority:** Graduated automated/manual recovery coordination and assurance state; Identity & Access/PostgreSQL.
* **Attributes:** UUIDv7 id, claimant/account reference where known, requested method, assurance level, state, hold/review requirements, reviewer/approver references, expiry, completion/cancellation/failure timestamps, operation identity and version. It stores references to evidence, not raw identity documents or secrets.
* **Relationships:** belongs to Account where safely known; has Security Challenges and may cause Account/Credential/Session/Device changes.
* **Sensitive/immutability:** recovery evidence references, reviewer identity, reasons and security state are highly restricted; case history is append-only/superseding.
* **Lifecycle/actions:** `requested`, `proof_pending`, `additional_assurance`, `held_manual_review`, `completed`, `failed`, `expired` and `cancelled`; `start_recovery`, `submit_proof`, `approve_manual_recovery`, `complete_recovery`, `cancel_recovery`.
* **Policy/audit/integration:** non-enumerating claimant boundary; stronger assurance and second-person approval for privileged users; all completion effects remain Identity-only. Communications receives notice intent, not proof authority.
* **Persistence:** independent persistence is required for graduated assurance, manual review, duplicate/replay control, crash recovery and support audit.

#### 8. Reconciliation Case (physical Ash Resource)

* **Purpose/owner/authority:** Safe duplicate-identity detection, review and merge provenance; Identity & Access/PostgreSQL.
* **Attributes:** candidate accounts, detection basis, verification evidence references, reviewer/approver, conflict set, selected canonical account, status, timestamps, and reversal/correction references. No demographic-only automatic merge.
* **Relationships:** references Accounts and domain-owned records without directly rewriting them.
* **Sensitive/immutability:** matching evidence and reviewer notes are restricted; original identity and provenance are immutable; current reconciliation status is mutable through actions.
* **Lifecycle/actions:** `detected → candidate → review → approved/rejected/conflict → applied`; correction can create a compensating case, never erase history.
* **Policy/audit/integration:** high-risk review and verified control of both identities where practical; each affected Domain confirms its own record/provenance consequence. Audit the case and all source-domain commands.
* **Persistence:** independent persistence is required for human review, conflict, retry, provenance and reversal.

#### 9. Registration Operation (private Identity Ash Resource)

* **Purpose/owner/authority:** Registration idempotency only; owned by Identity & Access, with PostgreSQL as durable authority through the owning Ash Resource/actions. Its invariant is `one registration operation ID → one immutable request → at most one terminal outcome`. It does not own authentication, Account, credential, email-verification, Token, Session, Audit or Communications truth. It never authenticates a participant or creates or validates a Session.
* **Resource admission:** It qualifies as a Resource because it owns an independently durable invariant, lifecycle, concurrency boundary, security boundary and restart/recovery obligation. It is not a UI form, cache, worker record, audit row, generic request ledger, event store, idempotency service or cross-Domain operation Resource. The seven existing Identity Resources keep their current meanings.
* **Bound-state data:** Opaque operation ID, non-password request fingerprint and fingerprint format/key versions, slow password verifier and the provider/version metadata required to validate it, neutral terminal-result classification, nullable created-Account reference only for the new-Account path, authoritative commit and expiry timestamps, and minimum bounded invalidation metadata. Do not retain source form fields, plaintext or recoverable passwords, message bodies, or email solely for convenience.
* **Lifecycle:** `absent → bound → tombstone`. A terminal outcome creates a bound record. It expires 24 hours after the committed outcome, without retry extension, or earlier when a password change/reset, linked Account closure/deletion, or explicit Security action invalidates credential-derived replay material. Unrelated changes to the pre-existing Account in the duplicate-email path do not invalidate the operation because that Account is not linked to it. Expiry uses authoritative database/server commit time, not browser time.
* **Tombstone:** Expiry or earlier invalidation clears the non-password fingerprint, fingerprint key version, password verifier, verifier/provider metadata, terminal replay result and Account association. The terminal row retains only the opaque operation ID and minimum tombstone state required by the unique allocation invariant. It has no participant lookup surface and no email or Account association. The ID can never be rebound; every future use fails closed.
* **New-Account terminal path:** RegistrationOperation commits in the same authoritative PostgreSQL acceptance transaction as the required P8-05 consequences. A committed accepted Account without its required binding is invalid. The exact cross-Domain orchestration remains WELL-51 scope. This Resource creates no public partial-registration path.
* **Duplicate-email terminal path:** A valid distinct attempt for an existing canonical email commits its own operation binding and neutral terminal result, without an Account, PMR, Token, EvidenceObligation, MessageIntent, protected-delivery envelope, Communications schedule or Audit schedule. Generate an operation-only slow password verifier from the submitted password. Never compare the submitted password with, or copy, the existing Account credential.
* **Non-password request fingerprint:** Use HMAC-SHA-256 over only the canonical non-password request. Domain-separate with `registration-binding:v1`; encode fixed field order, explicit types and length framing. Include the operation ID, validated first name and surname, canonical email, preferred language, acceptance locale, 18+ confirmation, exact Terms and Privacy version references, and any further field current authority explicitly adds to this registration request, including optional fields only if this request accepts them. Use exact validated values Identity persists. Distinguish absent, empty, boolean, string and identifier values. Add no Unicode normalization. Exclude password, PMR, Token IDs, timestamps and server-generated consequences.
* **Key boundary:** Use a dedicated deployment-environment-specific Identity registration-binding key, purpose-separated from every other platform key and distinct from the WELL-46 delivery-encryption key. Keep it outside PostgreSQL, source control, committed configuration and built artifacts; supply it through the existing platform runtime secret-injection boundary. Persist only the non-secret key version on a live binding. New bindings use the active key. Old keys remain verification-only only while live bindings reference them, ordinarily no longer than the 24-hour binding horizon. Missing, invalid, unknown or unavailable key material fails closed. Never fall back to an unkeyed digest, plain SHA-256, plaintext, a default/regenerated key, WELL-46 key material or current Account password state. No KMS/vendor is selected.
* **Password-verifier boundary:** Use the approved Identity slow password-hash provider semantics. On a new-Account path, retain the exact freshly generated Account password-hash bytes rather than hashing a second time. On duplicate email, hash the submitted password with the same approved slow provider, without consulting the existing Account credential. Compare the exact credential input semantics chosen for registration; do not normalize the password. Persist required provider/version metadata. The verifier is used only to compare a retry for this registration operation; it never authenticates, resets, recovers or proves identity and is never exposed by generic reads. Account remains the sole authentication credential authority.
* **Comparison and concurrency:** The same live ID plus the same immutable request replays the stored neutral result without repeating consequences. The same ID with changed input rejects without mutation. A pre-commit failure leaves no binding; unchanged input may retry that ID, while corrected input requires a new ID. Compare recomputed HMAC values with a constant-time equality primitive supported by the selected runtime/crypto API; verify the exact API during implementation JIT. This does not guarantee identical overall request timing. A unique PostgreSQL operation-ID invariant arbitrates concurrent submissions: one binding wins, an identical loser resolves to replay, and a changed-request loser rejects. Expired, invalidated or tombstoned IDs fail closed. Correctness comes from PostgreSQL constraints and transactions, not process-local locks or check-then-insert.
* **Exposure and evidence:** No generic public CRUD or ordinary read interface. Only purpose-specific Identity actions/interfaces may create, compare, replay, invalidate or tombstone the binding. Controllers, LiveViews and workers call the owning Identity interface and do not mutate this Resource directly. Protect sensitive fields through applicable Ash policies, field policies and minimum loading. Do not copy fingerprints, verifiers, key data or source payload into Audit. Audit & Evidence remains the sole central accountability authority.

### D.2 Rejected separate resources

* **Generic idempotency or operation ledger:** rejected. RegistrationOperation is limited to Identity registration replay and anti-rebinding; it does not serve other Domains or become a generic event/request history.
* **Registration data on Account:** rejected as the sole representation. A valid duplicate-email terminal operation creates no Account, and a successful operation must retain its binding after its Account association is cleared. Account fields cannot provide the permanent operation-ID anti-rebinding lifecycle for both paths.
* **Registration data on Token:** rejected. RegistrationOperation is not proof, bearer, token-presence or verification state. Putting it on Token would mix replay comparison with the Token Resource purpose boundary and still would not represent the duplicate-email path correctly.
* **Private non-Ash persistence:** direct Repo, Ecto or raw-SQL writes for this durable truth are rejected by the current Ash write boundary. The PostgreSQL table, if used as storage, backs the RegistrationOperation Ash Resource and its owner actions; it is not a parallel persistence API.
* **Email Change:** not a separate durable Resource for FP-001. It is an Account action plus a purpose-specific Security Challenge and durable consequences. A separate resource would duplicate account/email truth; the action still has its own explicit lifecycle and operation identity.
* **Verification Challenge, Recovery Challenge and Reset Token:** one Security Challenge with a closed purpose enum is safer and smaller than one table/resource per token flow. Purpose, fingerprint, expiry and single-use guards prevent cross-use.
* **Security Hold/Compromise:** authoritative state on Account plus revocation actions; a separate incident resource would overlap Audit/Operations. A later incident system may reference identity state.
* **Support Case:** no generic operator-work resource. Support invokes source-owned recovery/hold/release actions with named grants, reason and audit.
* **Role and Privilege Grant:** one Identity Grant resource with typed capabilities; separate role/privilege resources would flatten or duplicate the same identity-side authority.
* **Audit Event:** owned by Audit & Evidence, not identity truth. Identity emits minimum evidence.
* **Communication Message/Delivery:** owned by Communications; Identity emits intent containing only the necessary destination/reference and causal identity event.

## E. Relationships and ownership

These invariants are non-negotiable:

```text
identity role/grant       != relationship-owned business authority
canonical account email   != Communications subscriber/contact state
identity verification     != communication delivery evidence
account closure           != full privacy deletion orchestration
audit evidence            != identity business truth
authentication            != role/grant != consent/purpose != entitlement
```

Identity provides a current actor reference and identity-side grants. Privacy & Consent supplies current consent/purpose decisions. Practitioner, household, programme, community, event, entitlement, professional and other relationship owners retain their authority. Content is consumed from Content & Media. Audit records what Identity did without authorising it.

## F. Lifecycle state machines

### F.1 Orthogonal Account / identity dimensions

Recovery does not create a synthetic Account super-state. The authoritative dimensions are evaluated independently:

**Account lifecycle:** states `open`, `closed_recoverable`, `closed_terminal`. Registration creates `open` only after minimum-field, 18+, terms/privacy and canonical-email checks. `open → closed_recoverable` is an authorised closure action; reopening requires the applicable current actor and recovery/closure guard but does not alter verification or security posture. `closed_recoverable → closed_terminal` is terminal identity closure only when retention/deletion authority permits it. Terminal closure is never reopened by login or recovery.

**Platform Member Reference:** states `unassigned`, `active`, `retired`. A successful individual Account creation commits exactly one canonical active PMR as part of the authoritative Account transition; failed, partial or ambiguous creation does not expose one. `active → retired` occurs on approved retirement, final deletion or the non-surviving side of a governed duplicate reconciliation, and a retired value is never reassigned. Legitimate reactivation retains the correct existing reference. Exceptional replacement requires an already-approved security, privacy, integrity, reconciliation or equivalent operational-correctness reason. PMR allocation/merge is collision-safe, concurrency-correct and retry/idempotency-safe; this is independent of Account, verification, Session, authentication, authorisation, Membership, subscription, entitlement, payment and recovery states.

**Email verification:** states `unverified`, `verified`. `unverified → verified` is initiated only by consuming a valid proof from the Identity Token Resource whose purpose is email verification. Automated retrieval, `HEAD`, `GET`, prefetch, scanner or preview activity cannot itself consume the proof. No Account reopening, recovery completion or hold release can perform this transition. Verification is not reversed by an email-change delay; a new email requires its own proof and the applied change establishes the new address's verification state. Correction is a new purpose-bound proof and audit evidence.

**Security posture:** states `normal`, `held`. `normal → held` is authorised compromise containment; it revokes required sessions/devices and freezes sensitive actions. `held → normal` requires verified recovery/security review and is initiated by an authorised release action. Hold release does not modify email verification. A mistaken hold is corrected by release; a terminal closure cannot be reversed. Both transitions are conditional on Account version, idempotent by operation identity, serialized against sensitive Account changes, and audited.

Explicit composition invariant: `recovery completion != email verification`; `security-hold release != email verification`; `account reopening != email verification`.

Guards and side effects remain dimension-specific: canonical email/registration gates apply to creation; proof purpose/expiry/presence applies to verification; current security authority applies to hold/release; closure and restoration use closure policy. Current effective protected access is composed from `Account lifecycle = open`, `Email verification = verified` where the capability requires it, `Security posture = normal`, valid Session/Token, assurance, Identity Grant, owning-Domain relationship and Privacy purpose/consent. It is never encoded as one Account enum.

### F.2 Email verification (Identity Token Resource proof lifecycle)

States: `issued`, `valid`, `consumed`, `expired`, `superseded`, `revoked`. Issuance follows account creation or an allowed resend. Resend atomically supersedes the prior active challenge for the same account/purpose and creates one durable communication intent. Retrieval is non-consuming. Consumption occurs only through the explicit participant confirmation action in J.1a, which locks or conditionally updates the challenge and Account in one short transaction; exactly one authorised participant action can establish verification. Expiry is time-derived and cleanup is non-authoritative. Replayed, expired or superseded secrets return a safe generic result and create bounded audit/telemetry. Delivery or provider status never changes `verified`; only proof consumption does. Correction is a new challenge, never mutation of consumed history; a mistaken revocation is handled by a new issuance.

### F.3 Credential (Account authentication fields/actions)

States: `absent`, `active`, `replaced`, `revoked`. Password authentication validates a hash with bounded cost and generic failure. Reset replaces the credential only after a valid reset/recovery proof, invalidates affected sessions/devices and records a security event. A replacement is atomic with its credential version and revocation consequence. Old credentials cannot authenticate; retries with the same operation identity return the committed result. Credential revocation is not undone; correction requires a new authenticated credential and evidence.

### F.3a Password-reset security boundary

For bounded P8-12 Phase-8 development, testing and proof, a successful explicit password reset establishes an Account-wide credential-security boundary. This section selects the password-reset meaning of "affected sessions/devices" in F.3 and "relevant session set" in F.4. It does not change other credential, recovery or email-change policies.

At the protected Identity-owned boundary, recheck the proof's identity, password-reset purpose, currentness, expiry, revocation, supersession and consumption, and current Account/security/hold authority. Consume exactly one valid, current, purpose-bound, single-use password-reset proof, replace the Account password credential and advance authoritative credential/security version. Commit proof consumption, credential replacement, version advancement and the required revocation consequences atomically. A duplicate, racing or replayed attempt cannot produce a second successful reset consequence. Retries with the same committed operation identity recover the authoritative outcome without a second mutation.

Revoke every active `NewYou.Identity.Session` established for the Account before the committed boundary, including both password and magic-login Sessions. Invalidate the corresponding linked authentication-token authority and clear all elevated assurance attached to those Sessions. No pre-boundary bearer retains access solely because its signature remains valid. Terminate every current trusted DeviceAssurance for the Account. Preserve historical revocation and reset evidence; revocation cannot be undone by replay or restart.

Serialize racing reset, login and Session issuance against current Identity/PostgreSQL security authority. A Session established before the committed reset boundary is subject to its revocation. Later issuance must independently recheck current Account/security state and fresh valid authentication; a stale old-password check cannot establish a valid post-reset Session. Durable PostgreSQL authority is the final contention boundary.

Reset completion creates no replacement Session and does not sign the participant in. Require fresh authentication with the new credential. Preserve unrelated purpose-specific verification, recovery, email-change and other proofs unless their respective owning contracts already require revocation. Invalidating linked authentication tokens is not permission for blanket revocation of independent proof purposes.

Preserve only necessary immutable, minimized security and Audit outcome/provenance evidence. Passwords, password hashes, presented bearer tokens and unnecessary secrets must not enter ordinary evidence, logs, job arguments or telemetry. Retain protected delivery material only within the already-approved bounded protected-delivery capability. Expiry, revocation, supersession, wrong purpose, replay, concurrency, crash and restart fail closed. No partial successful commit may leave a replaced credential with continuing pre-boundary Session authority. Communications and Audit cannot infer, replay or repair credential success.

This policy supplies no production, real-participant, public-release, paid-pilot, provider, Phase-9 or merge authority. It approves no new PasswordReset Resource or parallel credential/proof/Session authority. Ash actions, transaction composition, version representation, constraints and the smallest compliant device-assurance mechanism remain implementation JIT choices. The predecessor's package-selection narrative is historical implementation context, not a replacement for the live approved dependency baseline. At approval recording, main pins AshAuthentication `5.0.0-rc.17`, Ash `3.37.2` and Assent `0.3.2`; verify actual locks and current primary APIs when implementing.

### F.4 Session

States: `active`, `expired`, `revoked`, `logged_out`. Creation occurs after successful authentication and current account/hold/verification/assurance checks. Elevated assurance is a mutable Session dimension, not a separate state machine: `assurance_level`, `step_up_purpose`, `step_up_verified_at` and `step_up_expires_at` are populated only after the required proof and cleared/downgraded on expiry, logout, security hold, recovery, credential change, compromise or other defined invalidator. High-risk authority is never inferred from a browser claim. Logout revokes one session; sign-out-all revokes all active sessions for the account. Recovery, credential change, email change where risk requires, compromise and grant/security changes revoke the relevant session set. Expiry is both inactivity and absolute; validation rejects either. Browser reconnect and LiveView remount reconstruct from the secure cookie and durable current state; a connection process never grants authority. Revocation racing login is resolved by transaction/version ordering: a session created before a committed global-revocation boundary is revoked, and a login after it rechecks current security state. Revocation is not reversed; correction requires a new session after reauthentication. Step-up invalidation is audited as part of the Session/security transition.

### F.5 Device assurance

States: `pending`, `trusted`, `expired`, `revoked`. Trust requires explicit consent and an authenticated session; use requires a current unrevoked fingerprint, expiry and account security state. Suspicious activity, credential changes, recovery, global logout or explicit user revocation terminates trust. It is never accepted for high-risk step-up. Duplicate trust requests converge on one active device assurance by account/fingerprint purpose key. Revocation is not reversed; correction requires fresh consent and a new device assurance.

### F.6 Recovery

Recovery is a lifecycle on Account plus `RecoveryCase` semantics and Security Challenges: `requested → proof_pending → additional_assurance → held/manual_review → completed`, with `failed`, `expired` and `cancelled` terminal outcomes. Normal recovery uses a verified channel and single-use proof; automated retrieval cannot consume that proof or complete recovery. Missing ordinary assurance enters a temporary hold and manual review. Privileged recovery requires stronger assurance and second-person approval. Completion changes only Identity authority, rotates/revokes credentials as applicable, removes stale sessions/devices, and sends security notices. It never creates consent, entitlement, relationship or professional authority. Duplicate requests are safe, simultaneous attempts cannot lower assurance, replay is rejected, and an incomplete/crashed transition is resumed from durable state. Recovery completion is not reversible by replay; correction requires a new reviewed case.

### F.7 Primary-email change

The action lifecycle is `requested → reauthenticated → new_address_pending → confirmed → delayed/reviewed → applied`, with `cancelled`, `expired`, `rejected`, `superseded` and `held` terminals. The authoritative current operation lives on Account: target new canonical email, operation identity, all material timestamps, delay/review state, supersession/cancellation/expiry markers, provenance and optimistic version. Account does not retain unlimited operation history; Audit & Evidence records the historical requested/applied/cancelled/superseded events and preserves old canonical-email provenance only as required by Identity/Audit/Privacy authority. Reauthentication proves control of the current session; a challenge in the Identity Token Resource whose purpose is `email_change_confirmation` proves the new address only after the explicit participant action in J.1a; automated retrieval cannot confirm it. Proof consumption alone never applies the change. Old-address notification is a Communications consequence, not proof. The current canonical email remains unchanged until the authoritative Account apply transaction succeeds. Concurrent changes serialize on Account version and active-change purpose; the newest explicitly accepted operation supersedes older pending challenges. Loss of old address uses graduated recovery, never informal support override. Applying the change rotates relevant session/device assurance according to risk policy, preserves required old-address provenance and audits the consequence. A pending operation survives restart and is resumed, cancelled or expired from durable Account state; correction creates a new operation rather than rewriting history.

### F.8 Identity grants

Ordinary states are `requested`, `assigned`, `active`, `expired`, `revoked`; break-glass adds `reviewed`. Assignment requires an authorised approver distinct from the subject where required, valid scope/reason, start and expiry/review. Current policy reads active grants and rejects expired/revoked grants. Revoke wins over concurrent use once committed; assignment and revoke use grant version/conditional update. Break-glass is named, MFA-protected, narrow, short-lived, alerted and post-reviewed; it never grants clinical or relationship authority. Expiry is a guard at read/action time even if cleanup has not run. Revocation is corrected only by a new separately approved grant, never by reopening history.

### F.9 Duplicate identity reconciliation

States: `detected`, `candidate`, `review`, `approved`, `rejected`, `conflict`, `applied`, `corrected`. Detection may use canonical email or strong verified evidence; name/demographics alone cannot merge. Review confirms control and asks each affected Domain to resolve purchases, entitlements, assessments, health, plans, journals, community and professional provenance. Apply creates one canonical identity and durable references while preserving original account ids/history; it does not directly merge other Domain truth. Conflicts block apply. Duplicate apply returns the prior committed case; a wrong decision is corrected with compensating provenance, not destructive deletion.

### F.10 Platform Member Reference reconciliation

<!-- NEWYOU:FP001-PMR-RECONCILIATION-CONTRACT:START -->

The Platform Member Reference is Identity & Access Account truth. The authoritative Account-creation transition assigns exactly one canonical active PMR only after successful individual Account creation. A failed, partial or ambiguous Account creation does not assign an externally usable PMR, and retries converge on the one committed Account/reference result.

The PMR is stable and human-facing. It is not database identity; it is not authentication; it is not authorisation; it is not verification assurance; it is not paid Membership; it is not subscription state; it is not entitlement; it is not payment authority; it is not a voucher/coupon/discount authority; and it is not a bearer credential. It is non-secret but private-by-default. Possession of a PMR proves none of those authority concepts and confers no rights belonging to the referenced Account.

The active PMR invariant is one canonical active PMR per canonical individual Account. Ordinary PMR values are immutable. Legitimate reactivation retains the correct reference. Retirement and genuine final deletion permanently retire the value and never reassign or reuse it. Duplicate-account reconciliation leaves one canonical active Account/reference and permanently retires the non-surviving reference. Exceptional retirement or replacement requires an already-approved security, privacy, integrity, reconciliation or equivalent operational-correctness reason.

Allocation, duplicate merge and retry handling are collision-safe, concurrency-correct and idempotent. PMR lookup and Account/beneficiary association use the PMR only as the approved beneficiary key for that purpose, remain purpose-scoped, minimum-disclosure and non-authoritative. They cannot establish purchaser control, beneficiary consent, subscription, discount, entitlement, payment authority, authentication, authorisation or verification assurance.

Phase 7A originally left the exact PMR representation unresolved under `ARQ-IAM-013`. The subsequent WELL-48 Identity owner decision selects `PMR-<16 Base36 data characters><1 ISO/IEC 7064 MOD 37,2 check character>` as the logical representation, recorded in the current P8-05 specification. Physical allocation-history, field, constraint/index and generator implementation remain JIT.

<!-- NEWYOU:FP001-PMR-RECONCILIATION-CONTRACT:END -->

## G. Action model

All actions run through Ash/application interfaces, use the smallest transaction that establishes the source truth, and return authoritative state. External I/O is post-commit. Inputs are untrusted intent; actors are current server actors.

| Action | Actor/guard and validation | Transaction, retry and concurrency | Consequences/evidence |
|---|---|---|---|
| `register` | Anonymous; required minimum fields, canonical email, 18+, terms/privacy, language and opaque operation ID; non-enumerating public result | RegistrationOperation binds the immutable request and terminal result; Account and required P8-05 consequences commit with the binding; canonical-email uniqueness arbitrates distinct IDs | Same-ID replay has no duplicate consequence; changed input rejects; no account existence leak |
| `resolve_registration_operation` | Registration orchestration through Identity; private purpose-specific actions only | Unique operation ID; compare non-password HMAC fingerprint and slow verifier; replay, reject, or tombstone under current binding state | Neutral public result; no duplicate business consequences or central Audit ledger |
| `assign/reconcile_pmr` | Identity & Access only; PMR is assigned within the successful individual Account-creation transition, or reconciled by an already-approved duplicate/retirement path; no other Domain may assign it | One canonical active PMR per canonical Account; active uniqueness, collision safety, concurrency correctness and operation-id retry convergence are required; failed/partial/ambiguous creation has no externally usable PMR | PMR assignment/retirement evidence is emitted after the authoritative Account/reference result; lookup is purpose-scoped, minimum-disclosure and non-authoritative |
| `issue/resend_verification` | Account owner with allowed unverified state; purpose and resend admission boundary | Replace active challenge conditionally; one active purpose challenge; duplicate request id returns result | Durable Communications intent; requested/superseded audit; delivery cannot verify |
| `consume_verification` | Presenter of a current purpose-bound proof after explicit participant confirmation; fingerprint/purpose/expiry/Account checks | Atomic challenge-consume + Account verify; replay safe; retrieval alone cannot reach this mutation | Verification evidence and optional session consequence; no raw token |
| `authenticate_password` | Anonymous; email/password; current Account state, hold and verification capability checks | Hash outside DB lock where possible; create Session only after re-read; generic failure | Login success/failure class, risk signal; no enumeration |
| `authenticate_magic_link` | Presenter of one-purpose challenge; optional launch method; current state | Same single-use challenge transaction and Session creation | Login/verification result; challenge replay evidence |
| `logout` / `revoke_session` | Current account or scoped support/admin actor | Conditional session revoke; duplicate is success if already revoked | Session event and audit where material |
| `revoke_all_sessions` | Current actor with step-up for sensitive contexts or scoped support action | Account/session-set revocation boundary; concurrent login rechecks boundary | Security event, audit and optional notice |
| `start/complete_recovery` | Account claimant; recovery proof or scoped manual reviewer; stronger rules for privileged accounts | Recovery case and challenge idempotency; completion serializes with email/credential changes; automated retrieval cannot complete proof consumption | Credential/session/device changes, security notice intent, audit |
| `request/apply_email_change` | Current actor; reauthentication, explicit new-address proof confirmation, current Account version | Pending challenge then atomic canonical-email uniqueness apply; old email remains until commit; automated retrieval cannot confirm the challenge | Old-address notice intent, session review, audit |
| `place/release_security_hold` | Security-authorised staff/system; reason, scope, current grant; release requires verified recovery/review | Account state conditional transition; hold wins over stale actions | Session/device revocation, security audit, alert/notice intent |
| `assign/revoke_grant` | Named approver with MFA; no self-approval; scope/reason/expiry | Unique active assignment key and grant version; revoke is idempotent and wins after commit | Audit, privilege-change notice/telemetry |
| `open/approve/apply_reconciliation` | Scoped staff; verified control and affected-domain review | Case state/version; apply is one identity transaction plus durable domain commands, not cross-domain direct writes; one canonical active Account/reference remains and the non-survivor PMR is permanently retired | Provenance and conflict evidence; reconciliation audit |

Error categories are stable and safe: `invalid_input`, `invalid_or_expired_proof`, `authentication_failed`, `verification_pending`, `restricted`, `requires_step_up`, `requires_manual_review`, `conflict`, `already_completed`, `temporarily_unavailable`, and `internal_failure`. Public surfaces collapse existence-sensitive categories; internal audit preserves precise classes without secrets.

## H. Policy / permission model

Policy composition is:

```text
current actor identity
→ current session and assurance
→ Identity-side grant/scope/expiry
→ owning Domain relationship authority
→ Privacy purpose/consent where applicable
→ action-specific invariant and risk guard
```

Authentication proves an actor; it does not authorise a role. Identity grants do not authorise practitioner relationships, household membership, entitlements, consent, health access or purpose. Protected actions re-read current actor, session revocation, Account security state, active grant and all owning-Domain authority at the action boundary. Long-lived LiveViews must not rely on stale assigns for protected actions.

Field policy is deny-by-default: raw password, challenge secret, session token, device fingerprint, RegistrationOperation fingerprint, password verifier and key metadata are never returned. RegistrationOperation has no generic public CRUD or read interface; only purpose-specific Identity actions may load the minimum required fields. Names/email/language are projected only to the minimum actor/context; support sees minimum necessary identity and security status. There is no universal `Super Admin`. Break-glass is a distinct exceptional path with named identity, MFA, reason, scope, expiry, alert, audit and review.

## I. Cross-domain seams

* **Communications:** Identity emits verification, recovery, email-change and security-notice intent after authoritative transitions. Communications owns subscriber/contact relationship, communication/message intent, exact governed content/locale binding and delivery provenance, delivery execution/status, provider attempts and provider/delivery evidence. Content & Media owns the governed message/template content versions that Communications binds and delivers. `delivered != verified`; provider outage leaves Identity truth unchanged and creates pending/retry/terminal visibility.
* **Privacy & Consent:** Identity reads/checks current purpose/consent for applicable actions and supplies identity/closure references. Privacy owns consent, withdrawal, retention and full deletion orchestration. Identity does not infer consent from login, language or support.
* **Audit & Evidence:** Identity emits minimum material security, recovery, grant, support, reconciliation and revocation evidence. Audit owns restricted append-only evidence; evidence cannot authorize or rewrite identity state.
* **Content & Media:** Content & Media owns governed message/template content versions and their publication/eligibility lifecycle. Identity/public surfaces consume approved bilingual governed content. Communications consumes the exact eligible content/locale version for delivery and owns the corresponding delivery binding/provenance; Identity owns no content lifecycle.
* **Future relationship Domains:** Identity supplies actor id and identity-side grants. Practitioner, household, programme, community, event, entitlement and other business relationships remain with their owners.

## J. Durable consequence / async boundary

The Account transition and its identity invariant are Class A synchronous work. A verification/recovery/email-change/security notice intent is a must-not-lose Class B consequence: establish a minimal durable intent atomically with the source transition, commit, execute through the Communications-owned durable path, retry with business idempotency and re-read current preconditions. Oban is the default executor under Architecture Law, but no worker name/queue is frozen here.

Session/device revocation required to prevent access is atomic Identity work. LiveView refresh, PubSub freshness and analytics are Class C observations and may be lost, delayed, duplicated or reordered. They never establish verification, revocation, recovery or grant truth. Provider outage yields retry/terminal failure and support-visible reconciliation; it never causes a guessed success. No generic event bus or durable PubSub delivery is introduced.

### J.1 Narrow Identity/Communications durable-delivery correction

This correction changes no Product Law, Architecture Law, Domain ownership, Roadmap outcome, authentication authority, verification/recovery semantics or provider selection. It resolves only durable delivery of one-purpose verification, password-reset, recovery and primary-email-change confirmation bearer material required by FP-001 Communications. It does not extend retention to optional magic-link authentication or session bearer tokens.

Identity & Access remains the sole authority for the Security Challenge, its purpose, validity, expiry, supersession, revocation and consumption. The Identity Token Resource stores information about tokens, not the presented tokens themselves. A protected delivery capability is sensitive delivery machinery, never a second Security Challenge authority.

Plaintext verification, password-reset, recovery or primary-email-change confirmation bearer material must never be persisted in ordinary Identity fields, ordinary Communications fields, Oban job arguments, logs, telemetry, audit evidence, analytics, provider metadata beyond the minimum unavoidable provider request, or browser/client state beyond the bounded participant-facing link itself.

Where crash-safe durable retry requires generated bearer material after the AshAuthentication sender invocation returns, Communications may retain a short-lived protected delivery capability under the platform's approved protected-secret mechanism. That capability:

1. Exists only to reproduce the already-authorised communication for durable delivery/retry.
2. Is encrypted/protected at rest and inaccessible through ordinary Resource reads. Only the purpose-scoped delivery executor may recover it for an authorised provider attempt.
3. Is bound to one Communications message intent and the corresponding Identity-owned purpose/challenge.
4. Remains recoverable while a permitted bounded retry obligation requires it, and expires no later than the underlying Identity proof capability. Early loss of required material is a delivery failure requiring reconciliation, never a silent discharge of the must-not-lose obligation.
5. Is unusable as Identity authority by Communications.
6. Cannot mark an Account verified, complete recovery or mutate Identity truth.
7. Is cleared or rendered irrecoverable when its delivery obligation no longer requires retry, and in all cases no later than the proof's terminal expiry/revocation/supersession boundary. Consumption invalidates further delivery and ends any remaining retry obligation.
8. Is excluded from logs, audit payloads, telemetry, Analytics and ordinary operational displays.

The must-not-lose boundary is:

```text
authoritative Identity transition / challenge issuance
→ Communications-owned durable Message Intent established
→ protected delivery capability established where required
→ commit
→ durable Communications execution
→ bounded provider attempt
→ retry / terminal failure / delivery evidence
```

External provider I/O does not execute inside the authoritative Identity transaction. Durable executor/job arguments contain only non-secret identifiers and bounded routing metadata, never the bearer token or rendered secret-bearing URL.

Source issuance, durable intent and the required protected capability must commit atomically or leave no committed issuance that has lost its delivery obligation. A callback return cannot prove that handoff because the maintained Sender contract ignores results and failures. Future integration must prove transaction-aware handoff and fail-closed behaviour when durable intent or capability establishment fails, without assuming a callback error rolls back Identity issuance. This does not select an adapter, hook or custom token system.

Before a retry that could deliver stale material, Communications uses the non-secret source reference/current-validity contract supplied by Identity to establish that delivery remains permitted. Expired, superseded, revoked, consumed or otherwise invalid challenges cannot be revived by retry. Future proof must cover invalidation racing with delivery authorisation and capability cleanup; exact coordination remains an implementation detail.

Provider acceptance or delivery does not consume the proof, establish verification/recovery success or confirm a primary-email change:

```text
provider accepted != provider delivered
provider delivered != proof consumed
proof consumed != provider delivery evidence
```

Only Identity & Access establishes email verified, recovery completed, email change confirmed or security proof consumed. Communications owns message intent, delivery execution, attempt/retry state, provider evidence and terminal delivery failure.

For the later FP-001 Communications dossier, `MessageIntent` and `DeliveryAttempt` are the two required durable business concepts. Protected capability storage is sensitive delivery machinery. `SubscriberContact`, `NotificationPreference`, `CommunicationJourney` and `InAppNotification` are not required FP-001 Resources merely because broader Domain Law contains them. Destination handling and privacy minimisation remain required without speculative Resource expansion.

Future executable proof must cover each permitted purpose: verification, password reset, recovery and new-address primary-email-change confirmation. It must demonstrate:

- No bearer token or rendered secret-bearing URL in Oban arguments, application logs, telemetry or audit evidence.
- Durable retry survives application restart for every permitted purpose, including primary-email-change confirmation, after Sender invocation and before the first provider attempt or after provider failure.
- Ordinary application/domain access cannot recover protected delivery material.
- Expiry, revocation, supersession and consumption prevent stale delivery for every permitted purpose, including an expired, cancelled or superseded primary-email-change operation and races between retry and Identity invalidation.
- Duplicate executor runs do not multiply the logical message outside approved retry policy.
- Provider timeout/unknown status cannot fabricate success.
- Provider delivery cannot establish Identity verification/recovery or confirm/apply a primary-email change.
- Protected material is cleared or irrecoverable at the required terminal boundary.
- Failure to establish durable intent or required capability cannot leave a committed must-not-lose issuance without durable delivery state.

This correction selects no notification provider, email vendor, encryption package, key-management product, exact encrypted field/resource representation, queue/worker name, retry count/backoff, OQ-036 resolution, Phase 7C proof classification or Phase 8 implementation. Existing platform secret-mechanism approval remains required; this candidate does not approve a new mechanism.

### J.1a Automated retrieval / scanner-safe proof consumption

For email verification, password reset, recovery and new-address primary-email-change confirmation, automated retrieval is never sufficient authority to consume the Identity proof or complete the protected transition. Link scanners, security gateways, browser previews, unfurlers, speculative prefetch, `HEAD`, `GET`, or equivalent automated fetches may inspect or retrieve a participant-facing URL, but that retrieval by itself must be non-consuming and non-mutating.

The authoritative boundary is:

```text
automated retrieval / HEAD / GET / preview / prefetch
≠ proof consumption
≠ verification / reset / recovery / email-change confirmation

non-mutating retrieval
→ explicit participant confirmation/action
→ Identity re-reads current proof + current source state
→ guarded state-changing Identity action
→ proof consumed exactly once with the authoritative transition
```

The explicit participant action must be distinct from passive retrieval and must invoke a state-changing Identity action using the platform's normal request-integrity protections for that surface. This freezes semantics, not route syntax, framework callback shape or exact UI. A browser navigation, provider delivery receipt, scanner hit or successful token parse is not by itself the consuming action.

At the consuming action Identity must re-check the presented proof's purpose, current validity, expiry, supersession/revocation/consumption state and the current Account/RecoveryCase/email-change operation state. If any check fails, the action fails closed and does not infer success from prior retrieval, provider evidence or a stale UI. Concurrency uses the existing single-use/conditional-update boundary so exactly one valid consuming action can commit.

Automated retrieval must not be able to win a race by becoming the consumer. A scanner or prefetch occurring before, during or after participant navigation leaves proof authority unchanged. If the participant later confirms, Identity decides from current durable state at that moment. If another authorised consuming action has already completed or invalidated the proof, the later action returns the safe already-completed/invalid result; no replay, guessed success or second transition is permitted.

This rule does not grant Communications, a provider, browser, gateway or scanner any Identity authority. It changes no provider selection, no token format, no protected-delivery retention rule and no OQ-036 decision. Future executable proof must include automated `HEAD`/`GET`/prefetch/scanner scenarios for all four protected purposes and prove that those requests alone cannot mutate Identity truth or consume the proof.

### J.2 Technical evidence and certification boundary

Official sources checked on 2026-10-04:

- [Hex package listing](https://hex.pm/packages/ash_authentication) lists stable 4.15.0. The predecessor's 4.14.2 record is a historical research snapshot, not a current-version claim or package pin.
- [AshAuthentication.Sender](https://ash-authentication.hexdocs.pm/AshAuthentication.Sender.html) documents `send(user, token, opts)`, ignores results/failures and delegates retries to the sending system.
- [AshAuthentication.TokenResource](https://ash-authentication.hexdocs.pm/AshAuthentication.TokenResource.html) documents storage of token information without the tokens themselves.
- [AshAuthentication confirmation tutorial v4.15.0](https://ash-authentication.hexdocs.pm/confirmation.html) configures new-address email-change confirmation and passes its generated confirmation token to `send(user, token, opts)`. This has the same durable-delivery requirement as verification/reset/recovery.
- Current Domain Law §6.1 in `04_DOMAIN_MAP_v1.2.0.md` permits one-purpose secrets through approved protected secret/token mechanisms.

The contradiction follows from these contracts: token metadata cannot reproduce the authorised bearer link after volatile material is lost, including the new-address primary-email-change confirmation link. Bounded protected delivery retention corrects the dossier restriction without changing Identity authority.

The PR #70 certification lifecycle is complete for v0.1.3. Its exact-head and resulting-main CI, unchanged merge, independent reviews and durable post-merge attestation are recorded above and in current Open Work v1.2.56. The predecessor is preserved byte-identically in archive. PR #76 certified the v0.1.4 candidate and supplied completed post-merge certification evidence; it did not make v0.1.4 current. This separate PR #77 status successor records v0.1.4 as CERTIFIED / CURRENT. Communications finalisation remains blocked pending the Communications dossier and applicable gates.

## K. OQ-034 Architecture Evaluation

### K.1 Recommended smallest path

The primary hypothesis is maintained stable Ash Authentication v4 plus stable Ash Authentication Phoenix v2, configured for the existing Ash 3.x application. Current review snapshots are `ash_authentication 4.14.2` and `ash_authentication_phoenix 2.17.3` (accessed 2026-09-01); these are evidence snapshots, not future pins:

* email/password as the required strategy and optional email magic-link strategy around the same Account;
* Argon2id through the maintained Ash Authentication hash-provider boundary, with cost benchmarked and bounded for the deployment budget;
* confirmation add-on for new-account email proof and monitored primary-email changes, with scanner-safe non-mutating retrieval followed by explicit participant confirmation; no verification/reset/recovery/email-change proof-consuming Identity transition may be completed by passive `GET`, `HEAD`, preview, prefetch or scanner retrieval alone;
* password reset/recovery strategy for ordinary recovery, extended by Identity-owned graduated/manual Recovery Case and security-hold actions;
* Token Resource with stored token presence enabled for durable revocation semantics where needed, secret material hashed/fingerprinted, one-purpose challenges, bounded expiry and no plaintext token persistence; protected verification, password-reset, recovery and primary-email-change confirmation delivery material is governed exclusively by J.1;
* secure HttpOnly, Secure, appropriate SameSite browser cookie transport; session identity is server-governed and linked to a durable Session record and framework token reference. `PUBLIC / EXTERNAL API BEARER AUTHENTICATION = NONE FOR FP-001`; internal first-party authentication token mechanisms remain permitted where required by the selected Ash Authentication browser/session architecture;
* Phoenix/Plug browser CSRF protection on cookie-authenticated state-changing requests, with LiveView event handling remaining server-authorised and current-state checked;
* Ash Authentication Phoenix LiveSession/on-mount integration to reconstruct authenticated subjects on LiveView mount/reconnect, followed by Identity policy checks for current session, grant and hold state. A LiveView process is never session authority;
* participant MFA remains optional; privileged staff/practitioner MFA and high-risk step-up use the stable `NimbleTOTP 1.0.0` primitive behind Identity-owned enrollment/verification state. Ash Authentication v5 TOTP is not adopted because it is release-candidate functionality;
* trusted device is an Identity-owned persisted Device Assurance record and is not silently delegated to browser local storage or a library convenience flag;
* secrets/keys are supplied by deployment secret management, rotated with overlapping verification and explicit revocation/recovery testing; no signing secret is committed.

### K.2 Physical framework mapping and deterministic proof decision

Ash Authentication provides the maintained strategy, password hashing boundary, token/challenge plumbing, confirmation/reset flow, authentication plugs and Phoenix LiveView subject propagation. The physical Identity Token Resource is an Identity & Access-owned Ash Resource configured with the `AshAuthentication.TokenResource` Resource extension; the extension is framework configuration, not the application Resource module and not a new Domain authority. The Token Resource stores token metadata/JTI/presence and revocation representation—not raw presented tokens—for confirmation, reset, magic-link and sign-in tokens, with purpose and expiry checked by the strategy. It is the only physical proof-token store.

The deterministic proof rule is: a presented token is acceptable only if its signature/format is valid, its purpose matches the requested action, its expiry is current, its JTI/token presence is acceptable under the configured token policy, it has not been revoked or consumed, and the linked Account/RecoveryCase/email-change operation is still in the required state. Failure of any check is fail-closed. Non-mutating retrieval may perform bounded validation needed to render the participant confirmation surface, but it does not consume the proof. Acceptance at the explicit consuming action proves only the configured proof; it does not by itself apply a separate downstream state transition whose own guards have not passed.

The logical `Security Challenge` concept is therefore represented through the Identity Token Resource. No parallel `SecurityChallenge` Resource or token table is allowed. Account authentication fields are the sole credential authority; the Identity Token Resource is token/proof authority; Session is application session authority; these do not duplicate one another.

### K.3 What the framework handles and what Identity owns

Identity still owns Account lifecycle dimensions, verified-capability gates, graduated/manual recovery, holds, session/device policy, email-change durable fields/delay/risk consequences, identity-side grants, duplicate reconciliation, non-enumerating public result mapping, domain seams, audit minimisation and all current-authority rechecks. Communications owns communication intent, exact content/locale delivery binding/provenance, delivery execution/status and provider/delivery evidence; Content & Media owns governed message/template content versions. The library is not permitted to become provider, content or verification authority.

`Session` is retained as a physical NewYou Resource because the Identity Token Resource does not own user-visible inactivity/absolute session policy, device/session metadata, durable step-up assurance or product-level individual session listing. A session is valid only when Session is open/within both expiry rules, Account is open and permitted, security posture is `normal`, and its linked Identity Token Resource token is accepted and not revoked. Thus `Token active + Session revoked` is always invalid, and `Token revoked + Session active` is always invalid; the stricter result fails closed. Logout-everywhere revokes all applicable Sessions and their linked tokens using the selected maintained framework add-on/Token Resource path plus the Identity session boundary.

### K.4 MFA, trusted device and high-risk step-up selection

**Participant MFA:** optional enrollment is `not_enrolled → pending → active → revoked`; MFA factor persistence is Account-owned protected fields, with enrollment state, encrypted TOTP secret, confirmation time, last accepted TOTP period/time and revoked/disabled/reset metadata guarded by Account optimistic concurrency. The AshCloak security floor is `v0.4.0`: select `v0.4.0` or a later explicitly reviewed, compatible stable release; the exact dependency version/constraint is selected and pinned during implementation preparation and proof. A Cloak-compatible vault receives a versioned key from runtime secret management; the secret is never logged or returned after setup. It activates only after a valid TOTP confirmation, and last-use state prevents same-period replay. Disable/revoke requires current authentication plus step-up; reset uses graduated recovery and audit. OQ-035 governs brute-force thresholds. Participant MFA does not become mandatory except where a high-risk action requires step-up. A separate MFA Resource is not used for FP-001.

**Privileged MFA:** staff/practitioner access requires an active MFA factor and a current privileged Identity Grant. Enrollment, reset and disable are named, audited and cannot be self-approved; privileged reset requires second-person approval. Break-glass requires stronger assurance, named reason/scope, short expiry, alert and review. A credential/recovery compromise revokes the factor's usable assurance and requires re-enrollment or governed reset.

**TOTP primitive and storage boundary:** stable `NimbleTOTP 1.0.0` is the selected small primitive for code generation/validation and replay-window support. It does not own Account, MFA enrollment or authorization. Ash Authentication v5 RC's TOTP strategy is explicitly rejected for this dossier; v5 RC documentation is not treated as stable v4 behavior. The TOTP secret is recoverable by the application and therefore requires authenticated encryption at rest; it is not a password hash. Passwords remain one-way hashed by the selected authentication provider. **AshCloak security floor: `v0.4.0`; selection rule: `v0.4.0` or a later explicitly reviewed, compatible stable release; exact dependency version/constraint: selected and pinned during implementation preparation and proof.** A Cloak-compatible vault with a versioned runtime-injected key is required; known-vulnerable AshCloak releases below `v0.4.0` must not be selected. The selected primitive still requires Identity-owned brute-force admission, last-use replay control, audit and recovery integration.

**Trusted device:** browser receives only a random opaque device artifact in a Secure, HttpOnly, appropriate-SameSite cookie. Identity stores a server-side hash/fingerprint, Account, consent, name, assurance class, created/last-used, expiry, rotation and revocation reason in `DeviceAssurance`. No invasive fingerprinting or localStorage authority is used. Device loss is explicit revocation followed by fresh enrollment. Credential change, recovery, suspicious activity, global logout and compromise invalidate it. Each node reconstructs it from PostgreSQL; no local process is authoritative.

**High-risk step-up:** triggers include primary-email change, disabling MFA, sensitive export/deletion, unusually sensitive professional-record access, sign-out-all-devices and suspicious-security changes. The proof is current password reauthentication plus active MFA/TOTP where enrolled/required, or the separately governed stronger privileged recovery proof. Elevated assurance lives only in the current durable Session state: `assurance_level`, `step_up_purpose`, `step_up_verified_at` and `step_up_expires_at`. High-risk step-up authority equals current durable Session assurance state plus current Account/security/MFA state plus purpose plus expiry. A browser or LiveView claim is never independent authority. It is single-purpose, replay-controlled, expires on logout/security change/recovery and is reconstructed fail-closed from PostgreSQL after reconnect/restart. Trusted device never satisfies it by itself.

Recovery interacts with MFA by preferring an existing verified factor, otherwise verified email plus graduated assurance; unavailable MFA enters hold/manual review, and privileged recovery requires second-person approval. Recovery completion revokes sessions/devices and does not activate MFA, verify email or apply an email change without those independent proofs.

### K.5 Extension and risk boundary

The main lifecycle mismatch is that a turn-key authentication package does not by itself encode NewYou's graduated manual recovery, domain-aware merge, scoped staff/break-glass grants, relationship/consent composition or exact session/device invalidation policy. Those are application/domain actions around the framework boundary. The framework's token-presence and stored-token options must be proven for the required revocation model; a self-contained token accepted without presence would be unsafe for global revocation.

Custom authentication is rejected unless proof shows a frozen requirement cannot be met safely by the maintained path. A custom password, token, cookie or cryptographic implementation would increase attack surface, maintenance and rotation risk without an identified requirement benefit. A separate identity provider is also rejected for FP-001 because it adds a new operational/provider boundary while the required local email/password flow is available. Adopting Ash Authentication v5 RC solely for TOTP is rejected because the selected stable v4 + small maintained primitive path satisfies the frozen MFA boundary without RC adoption.

### K.6 Evidence required before implementation acceptance

The later tracer-bullet/proof boundary must verify pinned compatible versions, Argon2id cost/resource envelope, confirmation and reset replay/expiry, scanner/prefetch-safe non-mutating retrieval and explicit consumption across verification/reset/recovery/email-change, token hashing/presence/revocation, cookie/session fixation behaviour, CSRF, LiveView disconnected/connected reconstruction, multi-node shared PostgreSQL behaviour, restart/reconnect, global/session-specific revocation, manual recovery/hold races, privileged MFA/step-up and secret rotation. It must include failure injection and no-enumeration tests. This is evidence still required, not a final proof classification.

### K.7 Current technical source record

Research was limited to OQ-034 and used current official primary documentation accessed 2026-09-01:

* [Ash Authentication v4.14.2 — Get started](https://ash-authentication.hexdocs.pm/get-started.html): current password/magic-link installation path, authenticated-resource password fields, Token Resource, secret handling and Plug/session/bearer integration.
* [Ash Authentication v4.14.2 — Tokens](https://ash-authentication.hexdocs.pm/tokens.html): token presence storage, `store_all_tokens?`, sign-in tokens and LiveView exchange use.
* [Ash Authentication v4.14.2 — Confirmation](https://ash-authentication.hexdocs.pm/dsl-ashauthentication-addon-confirmation.html): confirmation for account/email changes, token lifetime, interaction and hijacking protections.
* [Ash Authentication v4.14.2 — API reference](https://ash-authentication.hexdocs.pm/api-reference.html): the `AshAuthentication.TokenResource` Resource extension, logout-everywhere, `AshAuthentication.Supervisor`, token expunger and Argon2 provider boundaries.
* [Ash Authentication Phoenix v2.17.3 — Router](https://ash-authentication-phoenix.hexdocs.pm/AshAuthentication.Phoenix.Router.html): stable Phoenix routes and CSRF-aware sign-out integration.
* [Ash Authentication Phoenix v2.17.3 — LiveSession](https://ash-authentication-phoenix.hexdocs.pm/AshAuthentication.Phoenix.LiveSession.html): copying authenticated subjects into LiveView session/assigns and token-expiry/presence behaviour.
* [Plug v1.20.3 — Plug.Session](https://plug.hexdocs.pm/Plug.Session.html): cookie/session options and CSRF consideration.
* [Phoenix LiveView v1.2.11 — LiveView](https://phoenix-liveview.hexdocs.pm/Phoenix.LiveView.html): LiveView process and `on_mount` authentication boundary.
* [NimbleTOTP v1.0.0](https://hexdocs.pm/nimble_totp/): small TOTP primitive, secret generation, time-window validation and same-period replay protection.
* [Ash Authentication v5.0.0-rc.1 change log](https://ash-authentication.hexdocs.pm/5.0.0-rc.1/changelog.html): evidence that TOTP is RC-only in the reviewed v5 line; not selected as stable v4 architecture.
* [AshCloak v0.4.0 release](https://github.com/ash-project/ash_cloak/releases): current stable release snapshot accessed 2026-09-01; includes fixes for the 2026-08-30 plaintext-sensitivity and unsafe-deserialization advisories. [AshCloak security advisories](https://github.com/ash-project/ash_cloak/security/advisories): advisory scope and fixed-release evidence.

Versions are evidence snapshots, not package pins or authority amendments.

## L. OQ-034 Resolved architecture boundary

**ARCHITECTURE SELECTION RESOLVED / PHASE 8 PROOF REQUIRED**

The current Decision Register records the selected stable Ash Authentication v4 plus stable Ash Authentication Phoenix v2 path for FP-001 email/password plus optional magic-link authentication, Argon2id, confirmation/reset facilities, the Identity-owned Token Resource configured with the `AshAuthentication.TokenResource` extension, secure first-party browser cookies, Phoenix CSRF and LiveView integration, and the Identity-owned Account/Session/Device Assurance/Recovery Case/Grant lifecycles. `PUBLIC / EXTERNAL API BEARER AUTHENTICATION = NONE FOR FP-001`; internal first-party authentication token mechanisms remain permitted where required by the selected browser/session architecture. The recorded selection includes stable `NimbleTOTP 1.0.0` as the MFA primitive and the AshCloak security floor `v0.4.0`, with exact compatible dependency/version constraints and cost values deferred to implementation preparation and executable proof. The selected architecture is not proof-complete here.

This satisfies Product and Architecture law because it keeps one canonical identity, uses maintained security primitives, preserves PostgreSQL durable authority, supports revocation/reconstruction across nodes, treats email proof as server-authoritative, composes authentication with current grants/relationships/consent, and avoids a universal privileged bypass. Alternatives rejected are custom authentication, external identity-provider infrastructure, browser-local session authority, Ash Authentication v5 RC adoption, and a Redis/ETS/GenServer identity store.

Residual risks are package/configuration drift, hash-cost overload, token-presence misconfiguration, incomplete MFA integration, recovery abuse and provider outage. Required evidence is listed in K.6 and remains a later executable proof obligation. This reconciliation does not amend the current Decision Register or claim that executable proof has passed.

Selection rationale retained for provenance only:

> The current Decision Register resolves OQ-034 for FP-001 with stable Ash Authentication v4 and stable Ash Authentication Phoenix v2 at then-current compatible versions, email/password plus optional magic-link authentication, Argon2id password hashing, confirmation/reset, the Identity-owned Token Resource configured with the `AshAuthentication.TokenResource` extension, secure first-party browser sessions, CSRF protection and LiveView actor reconstruction. It records stable NimbleTOTP for participant-optional MFA, high-risk step-up and mandatory privileged MFA, with Account-owned encrypted secrets protected above the AshCloak `v0.4.0` security floor. It does not make exact package pins, cost values or executable proof complete; those remain implementation/proof obligations. Identity & Access remains authoritative for Account, verification gates, Session/Device Assurance, MFA lifecycle, graduated recovery, revocation, scoped grants, compromise, duplicate reconciliation and all current-policy checks. Public/external API bearer authentication is not required for FP-001; internal first-party authentication token mechanisms remain permitted.

## M. OQ-035 boundary

OQ-035 is **not resolved**. Admission attaches in layers: Cloudflare edge → application action boundary → shared distributed velocity/risk mechanism where required → account/device/network signals → temporary challenge or recoverable hold. Required dimensions must support canonical action/purpose, account when known, network/edge identity, device signal and deployment-wide time window without revealing account existence. Public failure is non-enumerating; internal telemetry/audit remains precise. Cross-node correctness is required for any control relied on under multi-node traffic. PostgreSQL is not the immediate high-velocity counter store. Hammer/shared semantics remain an evidence candidate only. Final thresholds, escalation levels and false-positive recovery require OQ-035 owner approval and proof.

## N. Data integrity and indexes

PostgreSQL is the default durable authority. Every persistent resource requires UUIDv7 opaque ids, foreign keys, not-null/check constraints for closed enums and timestamps, immutable provenance/created fields, optimistic version where concurrent mutation exists, and bounded cleanup of expired challenges/sessions/devices.

Required constraint/query decisions are:

| Resource | Integrity and critical indexes |
|---|---|
| Account | unique canonical email; indexes on canonical email lookup, state+verification, security hold, and closure review; FK-safe references from all child resources |
| Platform Member Reference | active uniqueness per canonical Account and permanent non-reuse after retirement; exact constraint/index representation remains deferred under `ARQ-IAM-013` and is not selected here |
| Identity Token Resource | JTI/presence identity and purpose-aware token lookup; configured with the `AshAuthentication.TokenResource` extension; extension-defined token/revocation indexes and expiry cleanup index; FK/reference to Account where supported; it stores metadata/revocation state, not raw tokens |
| Session | unique Account + Identity Token Resource JTI/reference; indexes account+active, account+last-seen, expiry, revocation and step-up expiry/purpose where queried; FK to Account; no raw cookie/token or independently calculated fingerprint column |
| Device Assurance | unique account+device-fingerprint/purpose while active; index account+active and expiry; FK to Account |
| Identity Grant | index subject+active+expiry, role/scope review and revocation; conditional uniqueness only for the exact grant identity key; FK to Account; immutable approver/reason history |
| Recovery Case | unique active case/operation identity as applicable; index account+state+expiry, reviewer queue status+updated, and claimant-safe lookup; FK to Account where known; no raw recovery evidence |
| RegistrationOperation | unique opaque operation ID across bound and tombstone states; bounded expiry cleanup index; nullable Account reference only for an Account created by this operation; never retain an Account/email association after tombstoning |
| Reconciliation Case | indexes each candidate account, status+updated, selected canonical account and conflict review; FKs preserve source accounts; no cascade that destroys provenance |
| Account email change | Account's pending-operation fields indexed by account+pending state and operation identity; unique canonical email remains the authoritative conflict guard |

Query paths must be bounded: login by canonical email, session validation by Identity Token Resource JTI/reference plus Session state, protected action by session/account/grant state, challenge by Identity Token Resource purpose/JTI, and support lists by bounded status/time pages. No login/session validation scans, load-all session/grant history or unbounded reconciliation query is permitted. Exact SQL/migrations are deferred to implementation and proof.

## O. Concurrency and idempotency

| Race | Authority → invariant → strategy → recovery/evidence |
|---|---|
| Registration replay by operation ID | RegistrationOperation → one ID binds one immutable request and at most one terminal result → unique PostgreSQL operation-ID constraint and transaction arbitration → same request replays, changed input rejects, and tombstoned IDs fail closed |
| Distinct operation IDs for one canonical email | Account → one canonical email → unique PostgreSQL email constraint is the final guard → one Account path wins; the valid duplicate-email loser commits its own neutral RegistrationOperation binding and creates no other registration consequences |
| Resend/verification replay | Challenge+Account → one active challenge and one verify transition → conditional update/version → passive retrieval is non-consuming; expired/replay is terminal; evidence records safe result |
| Verification vs email change | Account → verified proof cannot apply to wrong purpose/email → purpose-bound challenge and Account version → one wins in transaction; later request reissued |
| Scanner/prefetch vs participant proof consumption | Identity Challenge + source state → automated retrieval cannot consume; exactly one explicit authorised consuming action may commit → passive retrieval is non-mutating, consuming action re-reads current proof/source and uses conditional single-use transition → scanner traffic leaves authority unchanged; stale/later participant action fails closed or returns safe already-completed result |
| Login vs revocation/compromise | Session/Account → no session survives committed revocation/hold → transaction boundary/revocation epoch and re-read → stale session rejected; multi-node test |
| Recovery vs login/email change | Account/Recovery Case → recovery cannot lower assurance or overwrite newer email → Account version, hold and serialized sensitive transitions → pending case resumes/cancels safely |
| Simultaneous recovery/support recovery | Recovery Case → one assurance path completes; privileged second-person review → unique active case/conditional state transition → duplicate returns prior result; audit reviewers |
| Grant assign/revoke | Grant → revoke wins after commit and expired grant cannot authorize → version/conditional update → action rechecks current grant; audit both operations |
| Duplicate reconciliation | Reconciliation Case → one applied canonical decision with history → case version/idempotency and source-domain review → conflict blocks; compensating correction |
| PMR allocation/merge/reactivation | Identity Account/PMR truth → one canonical active reference, permanent non-reuse and correct reactivation reference → transaction/version/operation identity with collision-safe concurrent allocation and merge → retry returns the committed result; ambiguous failure enters reconciliation rather than allocating a second active PMR |
| Crash during authoritative transition | PostgreSQL → no half-transition → short atomic transaction and durable intent → retry/reconcile by operation id; crash-window test |
| Duplicate/reordered async consequence | source transition + intent → one logical notice/consequence → durable intent key and idempotent consumer → retry/terminal failure reconciliation; provider evidence separate |

Distributed locks are not required by the model. PostgreSQL uniqueness, conditional updates, row/version coordination and durable operation identity are the default; stronger coordination requires proof of a specific invariant.

## P. Hot / warm / cold data

* **HOT:** canonical-email login lookup, active Session/Identity Token Resource validation, active proof acceptance, active hold/grant checks, and OQ-035 velocity state. PostgreSQL indexed authority for Account/Identity Token Resource/Session/Grant; velocity mechanism remains OQ-035 shared and non-authoritative. No cache may bypass revocation. Proof: p90 ≤100ms for suitable hot interactions excluding password hashing/provider latency, no scans, burst and multi-node tests.
* **WARM:** bounded active-session/device lists, recent recovery/support/reconciliation status and current grant review projections. PostgreSQL first; safe rebuildable read acceleration only after evidence. Pagination required. Empty-cache and revocation tests required.
* **COLD:** credential history metadata, consumed/expired challenge history, reconciliation provenance and security evidence. PostgreSQL/Audit authority, append-only or superseding records, retention-controlled bounded queries. No participant load-all.

## Q. Mechanism decisions

| Mechanism | Status | Decision |
|---|---|---|
| PostgreSQL | REQUIRED | Durable structured authority for all accepted Identity resources, constraints, current state and operation evidence. |
| Redis | POTENTIALLY_APPLICABLE | Only for OQ-035 distributed velocity/risk state if proof selects it; never identity/session/grant authority and exact keys/TTL/failure mode remain unresolved. |
| ETS | NONE initially | No identity authority or required cache is demonstrated; reconsider only for reconstructible safe lookup acceleration. |
| Cachex | NONE initially | No cache abstraction is justified before measured lookup pressure and invalidation proof. |
| GenServer | APPLICABLE — FRAMEWORK INTERNAL MAINTENANCE | AshAuthentication supervision and Identity Token Resource expiry/revocation cleanup may run supervised periodic processes; they are not Identity business authority, durable session authority or distributed coordination authority. No custom Identity GenServer is proposed. |
| Oban | APPLICABLE | Default durable executor for post-commit Communications/security consequences when the affected contract is ready; no generic event bus. |
| PubSub | APPLICABLE | Best-effort revocation/freshness observation only; never durable delivery or authorization. |
| Browser-local storage | NONE for authority | May hold safe UI convenience only; no session, challenge, credential, grant or authoritative security secret. |
| CDN | NONE for Identity authority | Public governed content may use approved content policy; authenticated identity/session responses are not CDN authority. |
| Public/external API bearer authentication | NONE FOR FP-001 | No approved native or public bearer client requires it. Internal first-party authentication token mechanisms remain permitted where required by the selected AshAuthentication browser/session architecture. |
| Trusted-device library state | NONE | Device Assurance is persisted Identity state with explicit expiry/revocation. |

## R. Security review

Argon2id hashes passwords with benchmarked bounded cost; raw passwords never enter storage or logs, and plaintext bearer tokens never enter durable storage or logs. Section J.1 permits only protected verification, password-reset, recovery and primary-email-change confirmation delivery material for bounded retry. Section J.1a requires passive retrieval, `HEAD`, `GET`, preview, prefetch and scanner traffic to remain non-consuming; proof consumption occurs only through the explicit guarded participant action. Challenge secrets are random, purpose-bound, fingerprinted, single-use, expiring and superseded/revoked. Cookies are Secure, HttpOnly and appropriate SameSite; session id is rotated on authentication and sensitive transitions to prevent fixation. Plug/Phoenix CSRF protects cookie-authenticated mutations; LiveView assigns and params remain untrusted.

Public registration/login/recovery responses do not reveal account existence or challenge validity beyond safe categories. Cloudflare/application/shared velocity controls address stuffing/brute force; OQ-035 retains thresholds. Recovery and email change require verified proof, reauthentication, holds/delay where risk demands and old-address/security notices. Current grant/session/relationship/consent checks prevent stale authorization and privilege escalation. Compromise revokes sessions/devices, freezes sensitive actions and requires verified recovery. Staff recovery is named, scoped, MFA-protected and second-person controlled for privileged accounts. Break-glass is exceptional, expiring, alerted and reviewed.

Key rotation uses overlapping verification/controlled retirement and tests old-session/token treatment. Logs and audit redact raw email where unnecessary, raw tokens, hashes, passwords and recovery evidence. Timing and error mapping are deliberately generic on public sensitive paths. Concurrent compromise response is fail-closed for sensitive actions. Product rules prevent unfinished spaces and relationship misuse; Domain invariants enforce state/ownership; Architecture supplies secure transport, current server authority, durable storage and async semantics; OQ-034 selects the maintained auth path; OQ-035 later selects thresholds; executable proof validates the whole chain.

RegistrationOperation retains a slow password verifier only for the 24-hour registration replay horizon. The new-Account path reuses the exact Account hash; the duplicate-email path stores an operation-only verifier and never checks the existing Account credential. This verifier cannot authenticate or reset an Account. A database-only breach exposes the verifier for offline guessing at the selected password KDF cost. The non-password HMAC key remains outside the database. A database-plus-key breach does not turn the fingerprint into a password oracle because the password is never HMAC input; the retained slow verifier still carries the stated KDF-cost guessing risk. The key alone does not provide a verifier or operation binding. Never log the fingerprint, password verifier, key material, or source request.

The Identity registration-binding key is environment-specific and purpose-separated from the WELL-46 delivery-encryption key. Missing or unknown key versions fail closed. Old fingerprint keys are verification-only while a live binding references them; the non-renewable 24-hour lifetime bounds that need. Credential-provider/version metadata is likewise required for verifier comparison; if the provider semantics are unavailable, fail closed rather than compare against current Account state or select a fallback.

The RegistrationOperation ID is not a credential, proof token or authentication factor. Public registration categories remain neutral for duplicate email, changed-ID reuse, expiry and invalidation. Do not claim mathematically identical timing; apply the current deliberate timing treatment and never disclose whether the existing Account credential matched.

## S. Privacy review

Registration collects only first name, surname, canonical email, credential, preferred language, 18+ confirmation and terms/privacy acceptance; phone and city are optional. It does not collect health, medical or full DOB data. Email is personal identity data; credential hashes, challenge fingerprints, session/device security data, IP/network/device signals and recovery evidence are sensitive security data and are restricted/minimised. Support receives minimum necessary context.

Identity keeps canonical email distinct from Communications contact state, security evidence distinct from analytics, and closure distinct from full deletion. Account closure prevents ordinary access according to Identity policy; Privacy & Consent owns full deletion orchestration, retention categories, legal holds, export and non-resurrection replay. No FP-006 deletion design is created here.

RegistrationOperation is operational Identity idempotency state, not participant business history or central Audit evidence. Keep the full request binding only until 24 hours after the committed terminal outcome or earlier applicable invalidation. A retry does not renew that period. After expiry/invalidation clear the fingerprint, key version, slow verifier, verifier metadata, terminal replay result and Account association. Retain only the opaque operation ID and minimum tombstone state so the ID cannot be rebound. The tombstone has no email or Account linkage and no participant lookup surface. Do not retain the source form or recoverable credential. A duplicate-email operation has no linked Account; unrelated changes to the pre-existing Account do not invalidate its binding.

## T. Frontend contract

The frontend submits untrusted intent and renders authoritative categories only. It may rely on:

| Operation | Authoritative categories |
|---|---|
| Registration | accepted/verification pending; invalid input; duplicate or ambiguous safe response; temporarily unavailable |
| Verification | pending; confirmation required; complete; invalid/expired/replayed proof; restricted |
| Resend | accepted/pending; rate-limited or temporarily unavailable without enumeration |
| Login | authenticated; invalid credentials; unverified/restricted; requires step-up; temporarily unavailable |
| Recovery | started; confirmation/proof action required; completed; pending/manual review; expired/failed/cancelled; restricted |
| Session | active; revoked; expired; requires reauthentication |
| Email change | pending new-address confirmation; confirmation action required; applied; cancelled/expired/conflict/held |
| Support recovery | accepted for review; requires second approval; completed; rejected; audited |

No pages, routes, components or screen state are designed here. Protected spaces must remain inaccessible until current verified identity, session, grant, relationship, consent and entitlement checks succeed.

Before the first logical registration submission, the browser creates one opaque operation ID. It reuses that ID only for an unchanged request. Corrected input starts a new operation ID. The ID is not a credential or proof of identity. The browser does not set or extend the server expiry. A replay returns the same neutral result without rerunning consequences. Changed-input reuse and expired/tombstoned IDs fail closed through the ordinary neutral registration response mapping.

## U. Observability and audit

Operational telemetry uses bounded-cardinality metrics for registration attempts/success, verification requested/consumed/expired/replayed, login result classes, recovery started/completed/rejected, session revocation, grant changes, support/reconciliation actions, suspected abuse, hash latency/resource use, challenge/session query latency, DB locks/pool pressure, queue age/retries and provider failure.

Security audit is separate and restricted: account lifecycle, verification proof, credential/security changes, recovery/hold/release, session/device revocation, grant/break-glass, support-assisted action, reconciliation/conflict and material policy denials. It records actor, target, reason/scope, correlation, result and causal references, never credentials, raw secrets or unnecessary personal payloads. Analytics receives only approved derived facts. Telemetry failure reduces visibility, not identity correctness.

RegistrationOperation telemetry may count bounded result classes and expiry/invalidation outcomes only. Never log the operation ID, request fingerprint, password verifier, key version, raw request or credential input. No fingerprint, verifier, key metadata or duplicate registration history is copied into central Audit. The Resource row exists for Identity idempotency correctness, not Audit evidence.

## V. Test contract

Future executable work must include resource/action, policy, field-policy, state-transition and invalid-transition tests; property tests for one canonical email, one-use proof, no authority from delivery and no grant beyond current scope; idempotency/retry/concurrency tests for every table in section O; token replay/expiry, scanner/gateway/browser-preview/prefetch `HEAD`/`GET` non-consumption across verification/password-reset/recovery/new-address email-change confirmation, explicit participant-confirmation consumption, scanner-vs-participant races, session fixation, CSRF, cookie flags, enumeration, stuffing/rate boundary and logging-redaction tests; Account-owned MFA enrollment/disable/reset, encrypted-secret access, TOTP same-period replay and factor-revocation tests; durable Session step-up purpose/expiry, trusted-device non-bypass and clearing on hold/logout/recovery/credential change; recovery/manual-review/hold and email-change races; session/device/global revocation and restart/reconnect/multi-node reconstruction; grant self-approval/break-glass expiry; duplicate reconciliation/provenance/conflict/correction; audit completeness/minimisation; provider outage and durable consequence tests for verification, password reset, recovery and primary-email-change confirmation, including crash/restart retry and stale-proof rejection; hash-cost and bounded-resource tests; and failure/degradation tests proving no guessed identity, verification or access.

The proof must test empty-cache/restart behaviour for any later acceleration, queue duplicate/reorder semantics, current-policy re-read on long-lived LiveView actions, secret rotation, and representative burst/contention. It must not be replaced by a clean happy-path test or final proof label at dossier time.

RegistrationOperation tests must prove one PostgreSQL-unique operation ID across live and tombstone states; exact same-request replay after process restart; changed non-password or password input rejection without mutation; simultaneous identical and changed-payload submissions; valid duplicate-email binding with no Account/PMR/Token/EvidenceObligation/MessageIntent/envelope/schedule and no comparison against the existing Account credential; the new-Account binding in the same acceptance transaction; unchanged retry after pre-commit failure; corrected input requiring a new ID; non-renewing 24-hour expiry from authoritative commit time; early invalidation only for applicable linked-Account/security events; duplicate-path independence from unrelated Account changes; clearing all sensitive fields and associations at tombstoning; permanent ID non-reuse after Account closure/deletion; missing/unknown/unavailable HMAC key or verifier provider fails closed; policy/read-interface isolation; and log/Audit redaction. These are later deterministic WELL-48 implementation proofs, not tests added by this candidate.

## W. Recommended future folder/module structure

No source directories are created. If implementation is authorised, follow the existing Ash/Phoenix convention if one is established; otherwise use the smallest domain-oriented structure:

* `NewYou.Identity` (or the repository's established Identity & Access Domain context) for Ash code interfaces and boundary orchestration;
* `NewYou.Identity.Account`, the Identity-owned `Token` Resource configured with the `AshAuthentication.TokenResource` extension, `Session`, `DeviceAssurance`, `IdentityGrant`, `RecoveryCase`, `ReconciliationCase`, and the private `RegistrationOperation` Resource as NewYou Ash Resources;
* an application-owned recovery/email-change boundary module only if the action orchestration cannot remain on the relevant resource; no generic `Services` or `Utils` dump;
* an Ash Authentication adapter/configuration boundary for maintained strategies, hash provider, token resource and Phoenix plugs;
* a Communications intent adapter boundary, not provider calls inside identity transactions;
* policy modules only for genuinely shared, independently testable current-session/assurance or staff/break-glass composition;
* tests mirroring each resource/action and cross-domain seam.

Resource names represent business concepts, not database tables, screens or workflow buttons.

## X. Open questions / remaining gates

### `PHASE8_PROOF_DOWNSTREAM`

* The maintained authentication architecture is already selected in current authority. Implementation/proof must verify compatible versions, token-presence revocation, Argon2id cost, MFA/step-up integration, key rotation, scanner-safe proof consumption and multi-node/restart semantics before development-entry acceptance.

### `CURRENT_PHASE_AND_IMPLEMENTATION_STATUS`

This current-status routing reconciliation changes no Identity v0.2.0 semantic version or owner decision.

* Identity v0.1.4 is the archived predecessor; v0.2.0 is CERTIFIED / CURRENT under PR #151.
* Phase 7C and Final Feature Pack Contract v0.1.0 are COMPLETE / CERTIFIED / CURRENT under current Open Work. This dossier changes neither status nor proof classification.
* TB-001 bounded Phase 8 proof execution is authorised and started; its current proof result remains INCOMPLETE / COVERAGE-INCOMPLETE and Phase 8 is not certified.
* P8-05 registration implementation is AUTHORISED — BOUNDED PHASE 8 ARCHITECTURAL PROOF ONLY. WELL-45 remains a legal/privacy release gate; development baselines are NOT LEGALLY APPROVED. After this authorization is current and resulting-main verification succeeds, WELL-48, WELL-49 and WELL-50 may begin in parallel where dependencies permit; none is complete. WELL-50 depends on the agreed WELL-48 Account/PMR contract, not implementation completion. WELL-51 follows the required WELL-48–50 seams and owns the first integrated acceptance boundary; WELL-52 follows WELL-51; WELL-53 follows WELL-48–52 and closes the proof outcome.
* Phase 9 / Vertical Slices remain NOT STARTED / NOT AUTHORISED.

### `BLOCKS_RELEASE_ONLY`

* `OQ-035` thresholds/escalation/false-positive recovery.
* `OQ-036` notification provider/channel policy.

### `JIT_IMPLEMENTATION_DETAIL`

* Exact compatible package pins, Ash action syntax, migration shape, RegistrationOperation field/action names, savepoint/conflict/retry mechanics for Ash/AshPostgres, TOTP period/grace values, queue/worker names, cookie key, Cloak vault/key-manager configuration, runtime secret-injection implementation and provider details, pool/concurrency values, exact proof-confirmation route/event shape and exact audit/metric schemas. No KMS/vendor or new package is selected here.

### `FUTURE_ONLY`

* Social login, passkeys, public/external bearer clients, native clients, generic tenancy, full deletion orchestration, operator-work capability, men’s/specialist spaces and future relationship Domains.

No item is classified as a blocker merely because implementation detail is not yet selected.

## Y. Decision register

| ID | Decision | Authority basis | Alternatives considered | Why selected | Evidence required | Revisit trigger |
|---|---|---|---|---|---|---|
| IAM-01 | Eight-resource Identity Ash set: the seven existing Resources retain their meaning; RegistrationOperation is the private eighth Resource for registration idempotency; Token remains Identity-owned and uses the AshAuthentication.TokenResource extension | Domain Map §6.1; Phase 7A §9; accepted WELL-48 owner resolution recorded by this status successor | generic operation ledger; private non-Ash persistence; expanding unrelated workflows into Resources | RegistrationOperation has its own durable invariant, lifecycle, concurrency/security boundary and restart/recovery obligation; Credential and SecurityChallenge remain Account/Token concepts | Resource/action/policy, concurrency, replay, retention and restart tests | A later authority change moves operation ownership or changes the accepted request contract |
| IAM-02 | PostgreSQL identity authority | Architecture §§7–8 | Redis/ETS/cache/process authority | durable, reconstructible, constraint-capable | restart/multi-node proof | measured bottleneck with preserved authority |
| IAM-03 | Maintained stable Ash Authentication primary hypothesis | OQ-034; Ash official docs | custom auth; external IdP; v5 RC | maintained primitives fit Ash/Phoenix and reduce crypto risk | K.6 proof set | material unmet frozen requirement |
| IAM-04 | Argon2id with benchmarked bounded cost | Architecture §6.1; DEC-244 | unbounded/high-cost hash; weaker fallback | preferred frozen direction with resource governance | hash benchmark/burst proof | unacceptable resource envelope |
| IAM-05 | Secure browser session; public/external bearer none | Architecture §6.1; FP-001 scope | public/external bearer API; browser-local token | smallest approved web boundary | fixation/CSRF/revocation proof | approved client scope |
| IAM-06 | Persist Device Assurance | DEC-249; 21J.6 | browser-only trust; no trust | locked revocable/expiring trust needs authority | revocation/step-up proof | Product scope removes trusted devices |
| IAM-07 | Account action, not Email Change resource | ownership/minimum model | separate change resource | avoids duplicate email truth while preserving lifecycle | race/rollback tests | independent retention/review needed |
| IAM-08 | Generic Security Challenge by purpose | replay/control invariant | separate token resources | fewer resources with closed purpose guard | cross-purpose/replay proof | purpose-specific independent retention emerges |
| IAM-09 | Recovery Case and reconciliation remain durable concepts | DEC-250/252 | ephemeral support workflow | manual review, provenance and crash recovery require state | duplicate/manual/recovery proof | authority moves upstream |
| IAM-10 | Oban for durable consequences; PubSub observation only | Architecture §§8–9; DEC-267 | generic event bus; PubSub delivery | preserves must-not-lose boundary and small scope | crash/duplicate/reorder proof | Communications contract selects another lawful executor |
| IAM-11 | Redis/ETS/Cachex not identity authority; framework GenServer only for maintenance | Architecture §7.3; OQ-035 | multilayer auth stack; custom process | no evidence requires acceleration; framework cleanup is not business authority | empty-cache/failure proof; supervisor/restart proof | measured need or framework change |
| IAM-12 | OQ-034 architecture selection remains resolved; proof is downstream | Decision Register OQ-034 | silently claim proof complete; reopen resolved selection | primary auth, Identity Token Resource, Session/revocation, MFA, trusted device, step-up and recovery interaction remain traceable while executable proof stays open | K.6 proof set | owner finds an authority contradiction |
| IAM-13 | Elevated step-up assurance is Session-owned | Product Law high-risk assurance; OQ-034 | browser/LiveView claim; separate StepUp Resource; ambiguous server record | current durable Session fields compose assurance with current Account/security/MFA state, purpose and expiry and reconstruct fail-closed across nodes | replay, invalidation, reconnect/restart and concurrency proof | a frozen requirement demands an independent lifecycle |
| IAM-14 | MFA state is Account-owned and TOTP secrets remain above the AshCloak `v0.4.0` security floor with a Cloak-compatible vault | Product Law MFA; official AshCloak release/advisory evidence; OQ-034 | separate MFA Resource; plaintext; vulnerable AshCloak line; custom encryption | one MFA authority on Account; recoverable TOTP secret needs authenticated encryption and v0.4.0 contains the reviewed fixes | secret-rotation, access-control, replay and failure proof | official security evidence changes or Account invariant fails |

## Z. STOP review

The v0.1.3 durable-delivery correction and v0.1.4 content-ownership/scanner-safe proof corrections remain certified and unchanged. PR #76 certified v0.1.4; separate PR #77 made it current. PR #150 certified the v0.2.0 candidate, and PR #151 records the narrowly scoped RegistrationOperation resolution as current Identity JIT planning. This successor changes no Product, Architecture, Domain or Roadmap authority, creates no Domain or generic ledger, and authorises no P8-05 implementation. Current Phase 7C and bounded Phase 8 proof status remain as recorded by Open Work. No source code, migration, package, database runtime, browser test, Plane update or Atlas expansion is part of this successor.

## AA. Final state

```text
PHASE 7A: COMPLETE
IDENTITY v0.1.4: HISTORICAL / BYTE-IDENTICAL PREDECESSOR
IDENTITY v0.2.0: CERTIFIED / CURRENT UNDER PR #151 STATUS SUCCESSOR
REGISTRATION OPERATION: IDENTITY-OWNED EIGHTH ASH RESOURCE; ACCEPTED REQUEST-BINDING CONTRACT CANONICALLY RECORDED
COMM-UPD-001 CONTENT OWNERSHIP CORRECTION: CERTIFIED / CURRENT
COMM-UPD-002 SCANNER/PREFETCH-SAFE PROOF CONSUMPTION: CERTIFIED / CURRENT
COMMUNICATIONS FINALISATION: BLOCKED / STOP
OQ-034 AUTHORITY STATUS: RESOLVED / ARCHITECTURE SELECTION; PHASE 8 PROOF REQUIRED
OQ-034 EXECUTABLE PROOF: INCOMPLETE / NOT CERTIFIED
OQ-035 RESOLVED: NO
OQ-036 RESOLVED: NO
PHASE 7C: COMPLETE / CERTIFIED / CURRENT UNDER CURRENT OPEN WORK
PHASE 8: AUTHORISED FOR BOUNDED ARCHITECTURAL PROOF ONLY; CURRENT PROOF INCOMPLETE
P8-05 REGISTRATION IMPLEMENTATION: AUTHORISED — BOUNDED PHASE 8 ARCHITECTURAL PROOF ONLY
PHASE 9 / VERTICAL SLICES: NOT STARTED / NOT AUTHORISED
IMPLEMENTATION STARTED BY THIS SUCCESSOR: NO
MIGRATIONS CREATED: NO
PACKAGES ADDED: NO
PLANE MUTATED: NO
ATLAS EXPANDED: NO
PR #70 v0.1.3 CERTIFICATION: COMPLETE / PASS; PRIOR CANDIDATE/CURRENT SNAPSHOT PRESERVED SEPARATELY
PR #76 v0.1.4 CANDIDATE CERTIFICATION: COMPLETE / PASS; POST-MERGE EVIDENCE COMPLETE; DID NOT PROMOTE CURRENT STATUS
CURRENT-STATUS PROMOTION: PR #77 STATUS SUCCESSOR
```

The v0.1.3 promoted/current snapshot, PR #70 candidate, PR #76 candidate, PR #150 candidate, and prior promoted/current v0.1.4 snapshot remain separately archived. This current-status successor preserves their historical bytes and records v0.2.0 as the current route.
