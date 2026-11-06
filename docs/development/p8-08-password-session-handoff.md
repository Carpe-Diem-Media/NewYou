# P8-08 password Session implementation handoff

## 1. Purpose, scope and version

This map describes WELL-9 implementation commit `f417e5ceda4f917a16e933ce5e205d7f6f730b4d`, proof extension `a3f703777803ff3be7ead730a497d8e31372b767`, and review corrections `ffe3b4f0c48c528984246c68aa7e59d3cd6598e4`. It is descriptive, not governing authority. Recheck current source and live Plane before reuse. The [Identity JIT](../delivery/jit/identity/FP-001_IDENTITY_ACCESS_JIT_DOMAIN_DOSSIER_WORKING_v0.2.0.md) and [FP-001 contract](../delivery/feature-contracts/fp-001/FP-001_TRACER_BULLET_CONTRACT_WORKING_v0.1.3.md) govern the Session outcome.

This slice implements password authentication, one Identity-owned Session model and a bounded browser proof. Magic links, reset, recovery, primary-email change and privileged step-up remain outside its scope. The browser route is compiled for development/test and requires `p8_08_browser_development_fixtures`; the login copy is not production-approved. Phase 8 and Phase 9 are not certified by this work.

## 2. Architecture, sequence and ownership

[RegistrationBoundary](../../lib/new_you_web/registration_boundary.ex) dispatches the login and protected proof routes without full-connection router telemetry. [PasswordSessionController](../../lib/new_you_web/controllers/password_session_controller.ex) calls [Identity](../../lib/new_you/identity.ex). Identity verifies the password through AshAuthentication's configured Argon2 provider, locks and rereads Account, then commits the stored framework Token and Session together. The browser receives an encrypted, authenticated, Secure, HttpOnly, SameSite=Lax cookie. [Endpoint](../../lib/new_you_web/endpoint.ex) configures it; [PrivacyTelemetry](../../lib/new_you_web/privacy_telemetry.ex) sanitizes the sensitive routes.

Every protected proof request calls `Identity.authorize_session/1`. That call checks the signed bearer and then rechecks current Account, stored Token and Session inside the Identity transaction. The cookie transports credentials; PostgreSQL and the owning Identity Resource actions govern their current validity. Email verification remains a separate action and does not issue a Session.

## 3. Ash map

[Account](../../lib/new_you/identity/account.ex) owns credential, verification, closure and security-posture state. [Token](../../lib/new_you/identity/token.ex) uses `AshAuthentication.TokenResource`. [Session](../../lib/new_you/identity/session.ex) uses AshPostgres, has private actions and a deny policy, and links to both. The supported owner entry points are on Identity; [PasswordSession](../../lib/new_you/identity/password_session.ex) is internal implementation. Its privileged Ash operations do not grant callers direct Resource access.

The implementation uses the pinned Ash, AshPostgres and AshAuthentication versions in [mix.lock](../../mix.lock), including the framework password provider, JWT and Token Resource. It adds no dependency. Signals and Temporal Resources are not used: this slice has neither a cross-Domain reaction nor an as-of query. Async expiry scheduling is not implemented here.

## 4. Interface contracts

`Identity.authenticate_password/2` takes email and password, returning transient credentials or `:authentication_unavailable`. The bearer must never be persisted in Session or logs. `Identity.authorize_session/1` accepts those credentials and returns only an Account ID after current checks; failures share the same error. `logout/1` and `revoke_session/1` require the linked signed credentials and are idempotent for their own terminal state. `expire_due_sessions/0` reconciles up to 100 due Sessions; it does not schedule itself. See [Identity](../../lib/new_you/identity.ex) and [PasswordSession](../../lib/new_you/identity/password_session.ex).

The development-only browser controller returns a protected empty response for proof, not a production participant destination. Its logout reports an error if the durable transition fails. The caller must not cache an earlier successful authorization as permission for a later protected action.

## 5. Lifecycle, failure and recovery

Session states are `active`, `expired`, `revoked` and `logged_out`; terminal changes filter for active state and record `ended_at`. Repeating the same logout or revoke does not rewrite the terminal timestamp. The current implementation uses a 30-minute sliding inactivity deadline and the framework token's 24-hour absolute expiry. The protected decision rejects either expired deadline, a revoked or missing Token, an invalid Session, unverified or closed Account, inactive credential, or security hold. `expire_due_sessions/0` can materialize due expiry in bounded batches, including after the bearer itself has expired; no scheduler is claimed.

Issuance verifies the password outside the Account lock, then locks and rechecks the submitted canonical email, current Account guards and verifier before the Token and Session writes. An email change committed while login waits for the lock denies that login without issuing either record. Authorization locks Account, Token and Session and repeats JWT validation before refreshing inactivity. Terminal writes use a conditional Session action. A failed Session write rolls back Token issuance; a new worker can retry after an interrupted transaction. These behaviors and the lock-contention case are exercised by [P809](../../test/support/proof/p8_09.ex). This slice does not implement global sign-out, privileged step-up, or other future invalidation workflows.

## 6. Persistence and consistency

The [Session migration](../../priv/repo/migrations/20261105193238_well9_session.exs) creates the state constraint. The [relationship migration](../../priv/repo/migrations/20261105193401_well9_session_relations.exs) initially adds Account and Token foreign keys and one Session per Token.

The [Token retention correction](../../priv/repo/migrations/20261106041805_well9_session_token_retention.exs) removes only the Token foreign key so framework expired-token cleanup can delete Tokens without deleting Session history. Session retains the non-null, unique original token JTI; its Account foreign key remains. Protected access requires a current linked Token row, so retained Sessions with deleted Tokens fail closed. Reapplying the Token foreign key on rollback fails if retained Sessions reference deleted Tokens; do not erase those Sessions to make rollback succeed.

[Idle fields](../../priv/repo/migrations/20261105194742_well9_idle.exs) and [timestamps](../../priv/repo/migrations/20261105201438_well9_session_timestamps.exs) are durable. Reversal that would erase Session state or timestamps is refused while Sessions remain. The Token JTI is sensitive and excluded from ordinary struct inspection; no raw bearer is a Session attribute.

The code uses owning Ash writes, not a separate Repo business-write API. Direct SQL in tests sets up and observes failure, revocation and contention cases. No Redis, process cache or browser state is Session authority.

## 7. Tests, proof and evidence

[Identity tests](../../test/new_you/identity/password_session_test.exs) exercise eligibility, independent Session/Token denial, expiry, idempotency, rollback and redaction.

Review regressions run the real expired-token cleanup twice with Sessions in all four states, verify retained history and denied old credentials, and verify fresh login still succeeds. A Scenario worker and PostgreSQL `pg_blocking_pids` prove login waits on the Account lock before a concurrent email change commits; the test requires denial without Token/Session writes and successful login with the current canonical email.

[Browser tests](../../test/new_you_web/controllers/password_session_controller_test.exs) cover CSRF, cookie properties, stale cookies, failure handling, sanitized telemetry and Chromium EN/AF. [P809 catalog](../../test/support/proof/p8_09_catalog.ex) registers partial-family browser, real database contention, worker termination/recovery, fresh-connection and separate-BEAM restart cases with the existing P8-04 runner. Restart processes receive synthetic signing material and bearer through stdin and emit bounded results only.

Commands for current-source verification, using the project toolchain and DevCore:

```sh
devcore-project doctor
devcore-project run test -- mise exec -- mix test test/new_you/identity/password_session_test.exs test/new_you_web/controllers/password_session_controller_test.exs
devcore-project run test -- mise exec -- mix ash.codegen --check
devcore-project run test -- mise exec -- mix check
devcore-project run test -- mise exec -- mix check.deep
```

The runner's Session family is partial and cannot certify TB-001. The restart case starts independent BEAM instances against the same database; it is not a database restore or deployment test. Current Assent 0.2.13 remains vulnerable under WELL-91's previous exact-input exception. This implementation changes its covered inputs; independent HIGH security reassessment and explicit owner acceptance, or supported remediation, remain required. No successor exception is asserted here. Exact-head check and CI observations belong in the PR and Plane.

## 8. Future-agent extension guide and cold-start audit

Start with the browser boundary and follow the controller to `Identity.authenticate_password/2` and `Identity.authorize_session/1`. Follow those into the Account/Token/Session transaction, then inspect the migrations, action filters, and the focused tests and P809 cases above. Do not use the cookie, a LiveView assign or a prior authorization result as current business authority. Any future protected mutation must recheck the relevant current authority at its own transaction boundary. Preserve the Account-before-Token-before-Session lock order where applicable.

The implementing agent followed this path from the source map, checked the named entry points, Resource actions, constraints and test registrations, and recorded the limits above. This is a self-audit, not independent Master Gate. Before extending the slice, reread current source, live Plane and current authority; review changed input security and the production copy gate independently.
