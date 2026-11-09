# AshAuthentication v5 compatibility addendum — WELL-100

## 1. Purpose, scope and version

This addendum records the compatibility evaluation for [WELL-100](https://app.plane.so/symphony-development/browse/WELL-100), implementation source SHA `33e821a572aeb3670299a3ea5ad6aad53d2c50ef`, in [draft PR #208](https://github.com/JCSchoeman96/NewYou/pull/208). The implementation source SHA is distinct from the later documentation and exact-review PR head. The change evaluates and pins AshAuthentication `5.0.0-rc.17`, resolves its declared Assent requirement, and updates only compatibility code and security-audit evidence. It changes no Product governance, Account policy, authentication route, application migration or participant copy.

The P8-07 verification, P8-08 password Session and P8-09 magic-login handoffs remain the detailed maps for those flows. This addendum describes the framework-version change across them. Recheck the current source, lock, governing references and live Plane state before using it.

## 2. Architecture, sequence and ownership

The upgrade leaves the established Identity boundaries intact:

- Password authentication still enters through the development/test browser boundary and calls the Identity-owned password Session flow. Identity remains authoritative for Account eligibility, framework Token issuance and Session authorization.
- Email verification still calls `Identity.verify_email/1`, then the private Account confirmation action. Identity owns the atomic Account and Token transition.
- Magic login still enters through Identity, binds a purpose-specific Token and Session, and asks Communications to deliver through its existing MessageIntent and executor. Content owns approved message binding. Audit remains evidence-only.

The application does not use the AshAuthentication MagicLink strategy or its Sender. No callback, provider receipt, browser state or communications record becomes authentication authority. See the [P8-07](p8-07-verification-handoff.md), [P8-08](p8-08-password-session-handoff.md) and [P8-09](p8-09-magic-login-handoff.md) maps for exact paths, ownership and lifecycle controls.

## 3. Ash map and v5 API compatibility

[`Account`](../../lib/new_you/identity/account.ex) keeps its current password strategy and actions; [`Token`](../../lib/new_you/identity/token.ex) keeps its generic private `:revoked?` action and `AshAuthentication.TokenResource` behavior. The v5 dependency adds optional TOTP and WebAuthn dependencies, but no strategy or add-on was enabled. Existing reachability assertions remain in [`authentication_reachability_test.exs`](../../test/new_you_web/security/authentication_reachability_test.exs).

AshAuthentication v5 changes `AshAuthentication.Strategy.action/3` to `action/4`, with an options keyword argument. The only direct application-repository invocation was the password revocation regression test; it now passes `[]`. No application runtime caller of that helper exists, so no production action or public interface needed migration. The version-matched [`Strategy` implementation](https://github.com/team-alembic/ash_authentication/blob/v5.0.0-rc.17/lib/ash_authentication/strategy.ex) and [dependency declaration](https://github.com/team-alembic/ash_authentication/blob/v5.0.0-rc.17/mix.exs) were checked against the installed release source.

The v5 Igniter task `mix ash_authentication.upgrade 4.15.1 5.0.0` was attempted and failed with `Could not find module Token`. Its module scanner matches a nested test fixture named `Token` and then cannot resolve it as a top-level module. Inspection found no further required source rewrite; this is a failed tooling command, not a successful migration result. The code-level v5 compatibility change is the test call arity above.

## 4. Important interface and flow consequences

The password verifier, eligibility checks, Account locking, Token/Session transaction, verification proof checks and magic-login public errors are unchanged. `Identity.verify_email/1` remains distinct from login and does not issue a Session. Magic-link retrieval remains passive until explicit participant confirmation; consuming a proof and issuing its Session remain within the Identity-owned lifecycle.

Communications delivery retains its existing idempotency, retry and ambiguous-provider behavior. The framework Sender is not configured or called. EN/AF message binding, privacy filters, replay handling and restart recovery use the existing Content, Communications and Identity code and tests. No alternate token issuer, sender, delivery worker or business-write API was added.

Framework sign-in actions remain disabled. The current custom browser password flow is development/test-only and does not call AshAuthentication's sign-in action. No framework brute-force add-on was added and no new brute-force protection is claimed. The route, action and deployment reachability assertions remain a Master Gate review point.

## 5. Lifecycle, failure and recovery

No business lifecycle changed. Account and Token ownership, password Session expiry/revocation, email-verification single-use consumption, magic-login purpose/replay rules, Account-before-Token lock order and Communications retry/reconciliation behavior are unchanged. Existing automated tests cover rollback, retries, scanner-safe passive retrieval, provider ambiguity, independent BEAM restart and recovery. This upgrade adds no process-local authority or restart-dependent state.

The failed Igniter task is the only upgrade-tool limitation found. It did not modify source. Normal Mix dependency resolution succeeded after unlocking only AshAuthentication and its incompatible Assent lock, then resolving the graph against the declared v5 constraint.

## 6. Persistence and dependency consistency

The dependency declaration is exact: `{:ash_authentication, "== 5.0.0-rc.17"}`. Ordinary Mix resolution changed exactly two `mix.lock` entries:

| Package | Previous | Resolved | Reason |
| --- | --- | --- | --- |
| `ash_authentication` | `4.15.1` | `5.0.0-rc.17` | WELL-100's required exact evaluation target |
| `assent` | `0.2.13` | `0.3.2` | RC17 declares `assent ~> 0.3.2`; 0.2.13 cannot satisfy that range |

No override or manual lock edit was used. The resolved Assent release is within the framework constraint. The [EEF CNA advisory](https://cna.erlef.org/cves/CVE-2026-117656.html) identifies Assent versions before `0.3.2` as affected and `0.3.2` as fixed. No application migration, schema change, backfill or rollback consequence resulted.

## 7. Tests, security evidence and limits

Observed local evidence for source SHA `33e821a572aeb3670299a3ea5ad6aad53d2c50ef`:

- Full `mix test`: 574 passed.
- Focused 12-file authentication, verification, magic-login, Communications, Content, privacy and route-reachability suite: 128 passed.
- `mix check`: passed with 574 tests; architecture, Credo, Sobelow, format, compilation, usage rules and design gates passed.
- `mix check.deep`: passed with zero Dialyzer errors.
- `mix usage_rules.sync --check`, `mix ash.codegen --check` and `mix deps.unlock --check-unused`: passed.
- `mix hex.audit`: passed with no retired or advisory packages.
- Fresh isolated `python3 tools/hex_security_audit.py`: passed with no findings. Its temporary project uses every locked Hex package as an exact root, fresh Hex/Mix homes, locked resolution, a byte-identical lock check and no exception handling.
- Security-audit unit tests: 13 passed. Foundation lane routing: 32; Foundation Smoke: 14; CI attestation: 21; merge-gate tests: 10; Foundation Integrity Smoke: 65 assertions and no findings.

Reproduce through DevCore from the project toolchain:

```sh
mise exec -- devcore-project run test -- mix test
mise exec -- devcore-project run test -- mix test test/new_you/identity/registration_orchestration_test.exs test/new_you/identity/email_verification_test.exs test/new_you/identity/password_session_test.exs test/new_you/identity/magic_login_test.exs test/new_you/identity/magic_login_lifecycle_test.exs test/new_you/identity/magic_login_privacy_test.exs test/new_you/identity/magic_login_request_timing_test.exs test/new_you/security/password_revocation_test.exs test/new_you/communications/magic_login_delivery_test.exs test/new_you/communications/delivery_evidence_test.exs test/new_you/content/magic_login_message_test.exs test/new_you_web/security/authentication_reachability_test.exs
mise exec -- devcore-project run test -- mix check
mise exec -- devcore-project run test -- mix check.deep
mise exec -- devcore-project run test -- mix hex.audit
python3 -m unittest discover -s tests -p 'test_hex_security_audit.py' -v
python3 tools/hex_security_audit.py
```

The initial full test run before changing the test helper call failed exactly at the removed `AshAuthentication.Strategy.action/3` API; after the `action/4` update, the complete suite passed. Hosted exact-head checks are recorded on PR #208. The current exact PR head must be checked independently; this addendum does not certify CI, production deployment or release.

## 8. Security decision and future-agent guide

The prior WELL-91 disposition was bound to a different lock/source digest and does not apply to this candidate. The isolated audit now fails on every finding, including suppressed findings; it cannot emit a controlled disposition. [`assent_exception.json`](../../tools/hex_audit/assent_exception.json) records `retirement_proposed` for the move from Assent `0.2.13` to `0.3.2`, but the audit does not read that file. This is an explicit retirement proposal for independent review, not an approved retirement, renewal, or extension. WELL-91 remains open with its previously recorded expiry unchanged.

Independent Master Gate must review the exact resolved graph, the current advisory evidence, the clean raw and isolated audits, authentication route/action reachability, the test-only password route and the absence of a new brute-force claim. It must decide whether to accept the narrow Assent-exception retirement proposal. No clean local audit makes that independent decision on its behalf.

For future work, start at the existing browser boundary and follow the three owner interfaces to Account/Token/Session or Communications. Read the linked handoff for the flow before changing lifecycle behavior. Preserve owning Ash writes, authorization checks, Account-before-Token locking, token purpose, explicit magic-login confirmation, current-state revalidation and Communications' ambiguity handling. Do not add an AshAuthentication strategy or add-on without a Ready ticket and current authority.

Cold-start audit at source SHA `33e821a572aeb3670299a3ea5ad6aad53d2c50ef`: I followed `RegistrationBoundary` into `PasswordSessionController` and `Identity.authenticate_password/2` / `authorize_session/1`; `EmailVerificationController.confirm/2` into `Identity.verify_email/1`; and the magic-login controller through Identity and Communications. I then checked the Account, Token and Session resources, the existing persistence constraints, route-reachability assertions, and the linked password, verification, magic-login and delivery tests. This is an implementation self-audit. Independent Master Gate must repeat it against the exact reviewed PR head.
