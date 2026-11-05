# P8-07 explicit email verification implementation handoff

## 1. Purpose, scope and version

Revision 1 maps WELL-8 / FP-001 P8-07 at implementation SHA `1cc2bdbd00e2e748d868e015e7ff742a6cc06206`.
The later documentation/PR head is separate. Verify current source before reuse.
This map describes implementation; it is neither governance nor Plane authority.
Live execution remains [WELL-8](https://app.plane.so/symphony-development/browse/WELL-8).
Start with [the current routers](../README.md), the
[Identity dossier](../delivery/jit/identity/FP-001_IDENTITY_ACCESS_JIT_DOMAIN_DOSSIER_WORKING_v0.2.0.md)
and [TB-001](../delivery/feature-contracts/fp-001/FP-001_TRACER_BULLET_CONTRACT_WORKING_v0.1.3.md).

This slice consumes an existing email-verification Token and changes Account
verification atomically. It adds passive retrieval and an explicit CSRF-protected
confirmation form. It does not implement Session/login, magic login, provider
execution, reset, recovery or primary-email change. Those downstream lifecycles
remain outside this PR. No merge, Done, downstream unlock or Master Gate
certification follows from this map.

Temporary EN/AF wording is pinned in the
[development fixture](fixtures/p8-07-copy-v1.json), version
`p8-07-temporary-v1`, SHA-256
`146eeb3399c96fd0bc995fc905161a4a70f90bbf21fa77f395b2e427e840b1fa`.
The fixture records the owner's authorization to author/use temporary text and
each resulting locale digest. The owner did not review these exact bytes before
authorship. This creates no production approval, Content-role grant, legal review
or release authority. Existing registry and P8-05 copy remain unchanged.

## 2. Architecture, sequence and ownership

1. [Endpoint](../../lib/new_you_web/endpoint.ex) sanitizes endpoint telemetry and
   normalizes HEAD through `Plug.Head`. The
   [RegistrationBoundary](../../lib/new_you_web/registration_boundary.ex) dispatches
   `/verification/confirm` without full-connection router telemetry.
2. GET/HEAD call `EmailVerificationController.show/2`. The
   [controller](../../lib/new_you_web/controllers/email_verification_controller.ex)
   renders the form without calling Identity or reading proof state. Scanners and
   prefetch use the same passive path.
3. A distinct POST passes the real `Plug.CSRFProtection` pipeline and calls
   `EmailVerificationController.confirm/2`, then
   [`Identity.verify_email/1`](../../lib/new_you/identity.ex).
4. The private Account `:confirm_email` action calls
   [`ConfirmEmail.run/3`](../../lib/new_you/identity/actions/confirm_email.ex).
   Initial signed claims select an Account lock. `confirmation_transaction/4`
   opens `Ash.transact([Account, Token], ...)`, locks Account then Token, rechecks
   current eligibility and signed claims after both locks, revokes once, and
   calls Account `:mark_email_verified`.
5. Commit makes both changes durable. Rendering returns either verified or one
   unavailable result. Neither result authenticates the participant.

Identity owns both durable truths. PostgreSQL arbitrates contention. Browser
state, Communications and provider callbacks supply no verification authority.
There is no provider I/O or async consumption inside the transaction.

## 3. Ash Domain, Resource and policy map

The [Identity Domain](../../lib/new_you/identity.ex) owns
[Account](../../lib/new_you/identity/account.ex) and
[Token](../../lib/new_you/identity/token.ex), both using AshPostgres and the same
Repo. Account uses AshAuthentication; Token uses `AshAuthentication.TokenResource`.

`Identity.verify_email/1` is the supported capability-consuming interface.
Account `:confirm_email` is a private generic action with sensitive required
`:proof`. `:mark_email_verified` is a private update accepting no caller-set
attributes. The existing authentication-interaction policy is unchanged. An
ordinary provider actor cannot authorize either private action. The action uses
trusted internal Ash writes after its purpose-specific capability checks;
`authorize?: false` is not a public provider privilege.

Token's framework `:revoke_token` change now also uses the existing
`SetTokenAccount` change. `TokenResource.Actions.revoke/3` with `single_use?: true`
conditionally updates purpose to `revocation` and preserves the stored expiry.
This avoids `revoke_jti/4`'s long-lived revocation default for consumption.
Resend's existing behavior is preserved.

Mechanism choices use the installed Ash 3.37.2, AshPostgres 2.15.2 and
AshAuthentication 4.15.1 in [mix.lock](../../mix.lock). Vendor source inspected
includes `Ash.transact/3`, `Jwt.verify/4`, `Jwt.Config.validate_jti/4`,
`TokenResource.Actions.revoke/3`, `RevokeTokenChange` and Confirmation's actions
and changes. The framework Confirmation add-on expects its own `act` claim,
stored confirmation changes and confirmed-at field. The existing P8-05 proof
has the `email_verification` purpose. A custom Identity action over the same
approved Token mechanism preserves that issuance contract and adds current-state
locking without a second challenge store or new dependency.

Ash Signals and Temporal Resources are not applicable to this synchronous
authoritative transition. There is no cross-Domain reaction or as-of query.
Oban, Reactor and a new state-machine extension are unnecessary here.

## 4. Interface contracts

`Identity.verify_email(proof)` accepts a transient binary of 1 through 8192 bytes.
It returns `{:ok, :verified}` or `{:error, :verification_unavailable}`. Unsupported
input, invalid proof, ineligible Account, replay and internal failure share the
public error. Exceptions do not expose proof-bearing error terms. It emits no
Session, login token, provider request, job or new Communications consequence.

`ConfirmEmail.run/3` is internal to the Account action. It verifies the signature,
framework claims and purpose before selecting the lock. After Account and Token
locks it verifies them again, matches current subject/JTI, checks stored purpose,
presence, Account association and expiry, then performs both owner writes.

Browser routes require `locale=en` or `locale=af`; no locale fallback exists.
`VerificationCopy.enabled?/0` requires a DEV/TEST compile, the existing
`verification_development_fixtures` flag and the exact
`p8_07_browser_development_fixtures = "p8-07-temporary-v1"` flag. Missing/unknown
eligibility returns an empty 404 before the Identity action. Production builds
cannot enable the temporary page with runtime flags.

The [template](../../lib/new_you_web/controllers/email_verification_html/confirmation.html.heex)
uses current `DESIGN.md` tokens and the canonical `primary_button` component.
It has no analytics or third-party requests. CSP permits local styles and same-origin
form submission, with no scripts. `no-store` and `no-referrer` protect capability
navigation. Result responses contain no bearer field. The
[privacy plug](../../lib/new_you_web/privacy_telemetry.ex) strips all verification
connection payloads; [Phoenix filters](../../config/config.exs) also cover proof,
token, confirm, password and secret parameters.

## 5. Lifecycle, concurrency, failure and recovery

An eligible Account is open, security-normal, credential-active and unverified.
The proof must still be stored for the same Account/subject with purpose
`email_verification`, unexpired and accepted by AshAuthentication. Missing,
wrong-purpose, expired, revoked or superseded proof cannot proceed. Resend already
supersedes old active proofs. Consumed proof has terminal framework purpose
`revocation`, paired with verified Account truth. Replay is a rejected observation.
It never recreates proof or repeats verification.

Both consumption and existing resend lock Account first. Two confirmations
therefore serialize before the protected state check. Token locking also orders
against direct framework revocation. Signature/claim validation and wall-clock
expiry run after the locks, so waiting does not preserve stale eligibility.
The single-use conditional revocation supplies an additional durable guard.

An owner-write error rolls back proof revocation and Account verification together.
Killing a worker at the existing TEST-only `RegistrationSeam` checkpoint before
commit has the same rollback result. A fresh connection can retry and complete
the original proof. After commit, a reconnect reads verification from PostgreSQL
and rejects proof replay. No cache, process lock or retained page state is needed.

Account closure and security posture are orthogonal current guards. This slice
adds their representation/defaults and reads them; it does not implement closure,
hold/release, recovery, credential replacement or Session lifecycle actions.
Those future owner writes must preserve the Account locking order. Verification
never reopens an Account or releases a hold.

## 6. Persistence, constraints and transactions

[Migration 20261105172856](../../priv/repo/migrations/20261105172856_well8_verification_eligibility.exs)
adds non-null `accounts.account_status`, default `open`, and
`accounts.security_posture`, default `normal`. Existing rows receive those
defaults. Constraints `accounts_account_status` and `accounts_security_posture`
restrict values to the governed states. The matching
[Ash snapshot](https://github.com/JCSchoeman96/NewYou/blob/1cc2bdbd00e2e748d868e015e7ff742a6cc06206/priv/resource_snapshots/repo/accounts/20261105172857.json)
records the generated schema. Down refuses to erase a non-default denial state;
reconcile such rows through authorized owner work before rollback.

Existing `tokens.jti` primary-key uniqueness, Account FK and stored token
purpose/expiry remain authoritative. There is no new proof table, Repo, Redis,
infrastructure or dependency. `ConfirmEmail.confirmation_transaction/4` joins the
same Repo for Token revocation and Account verification. No business SQL or
`Ecto.Multi` path exists. SQL in tests is limited to fixtures, observation,
fault injection and cleanup. No plaintext bearer is stored in ordinary rows,
jobs, Audit or diagnostics. The existing protected Communications envelope
exception remains separate and unchanged.

## 7. Executable tests, evidence and limits

- [Identity tests](../../test/new_you/identity/email_verification_test.exs) cover
  success/replay, preserved token expiry, invalid input, wrong purpose, missing
  presence, stored/JWT expiry, revocation, genuine resend supersession, closure,
  hold, credential invalidation, provider authorization and Account-write rollback.
- [Controller tests](../../test/new_you_web/controllers/email_verification_controller_test.exs)
  cover GET/HEAD/scanner/prefetch, real CSRF rejection/acceptance, stale-page current
  guards, locale/fixture denial, provider routes, no login, ordinary persistence,
  jobs, logs and sanitized endpoint telemetry.
- [P807](../../test/support/proof/p8_07.ex) and its
  [catalog](../../test/support/proof/p8_07_catalog.ex) add four partial-family cases
  to the existing P8-04 runner. `consume_race` observes independent PostgreSQL
  backends, distinct live virtual transactions and `pg_blocking_pids` before
  releasing the winner. `interrupted_consume` consumes the registered cut and
  proves rollback/fresh-connection recovery. `browser_en` and `browser_af` reuse
  [P805Browser](../../test/support/proof/p8_05_browser.ex) and the existing
  [Chromium driver](../../test/proof/p8_05_browser.mjs), including actual form
  submission and safe replay. Only bounded booleans leave the browser; bearer
  input travels through stdin, never argv or result artifacts.

Run with the pinned [.tool-versions](../../.tool-versions) and DevCore:

```sh
devcore-project doctor
devcore-project run test -- mise exec -- mix ash.codegen --check
devcore-project run test -- mise exec -- mix test test/new_you/identity/email_verification_test.exs test/new_you_web/controllers/email_verification_controller_test.exs
devcore-project run test -- mise exec -- mix check
devcore-project run test -- mise exec -- mix check.deep
devcore-project run test -- mise exec -- mix run test/proof/run.exs --mode tb001 --output /tmp/p807-fresh-proof.json
```

Use a fresh output filename. Exact-head observed commands, CI and artifact summary
are recorded in the PR and WELL-8. The 27 registered cases do not complete the ten
TB-001 families. Four families have partial mappings; six have no mapping. An
overall TB-001 failure for incomplete coverage is expected, even when all owned
cases pass. No Phase-8 certification or Phase-9 authorization is claimed.
The restart evidence is bounded worker loss and connection reconstruction, not a
whole-BEAM crash, restore exercise or complete downstream lifecycle proof.

Hallmark confirmation rendering was checked in EN/AF at mobile and desktop
viewports. The additional visual audit is an implementing-agent self-audit,
not independent design review. Required independent Master Gate remains pending.

## 8. Future-agent extension guide and cold-start audit

Start at `RegistrationBoundary.call/2`, follow the controller's `confirm/2` to
`Identity.verify_email/1`, then Account `:confirm_email` and
`ConfirmEmail.consume/4`. Check the migration and snapshot before relying on
Account state fields. Follow the linked Identity/controller tests and the four
P807 registrations for repeatable evidence.

Reuse the Identity interface and approved Token mechanism for later authorized
proof work. Do not route consumption through GET, LiveView mount, provider
callbacks, jobs, Signals or a parallel proof store. Do not turn verification into
login. Preserve Account-before-Token locking, post-lock claim/expiry checks and
atomic rollback. Exact temporary copy is a development fixture, not a production
translation source. New purpose lifecycles and production content eligibility
require their own live authorized tickets.

Cold-start audit record: the implementing agent re-read this map separately
from authoring, resolved every repository-relative link, and checked its named
entry points, actions, policies, locks, constraints, fixture guards and test cases
against the recorded implementation SHA. The audit confirmed current action arities
and distinguished virtual-transaction contention evidence from physical XIDs.
That audit is a self-audit because
the task explicitly prohibits spawning reviewers. It cannot certify merge
authority or substitute for independent Master Gate.
