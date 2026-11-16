# P8-12 password reset implementation handoff

## 1. Purpose, scope and version

WELL-13 adds a bounded development password-reset path through the existing Phoenix, Identity, Communications and Audit owners. This is a full implementation map under the [handoff standard](implementation-handoff-standard.md), revision 1. It is descriptive, not governing authority or a second execution ledger. Resolve current source and [live WELL-13](https://app.plane.so/symphony-development/browse/WELL-13) before reuse.

The base is `5f92759233c172f9b380a5d00b94c2c41b912f97`. The branch is `feat/well-13-password-reset`. The runtime implementation source revision, including MG-215-01, is `caeb2d387afc1dab91431ebcc6a5c8a0b44909a6`. The browser-proof asset preparation revision is `10e86ec83e683c9aedffd5c2b1509d593de709e8`. The documentation commit and PR head are separate revisions; final exact-head checks belong to the PR evidence. Documentation changes also add this map to [the documentation index](../README.md).

[Identity JIT v0.3.0 F.3/F.3a](../delivery/jit/identity/FP-001_IDENTITY_ACCESS_JIT_DOMAIN_DOSSIER_WORKING_v0.3.0.md) governs the Account-wide reset boundary. Current authority comes through the [governance](../governance/CURRENT_GOVERNANCE_ROUTER.json) and [delivery](../delivery/CURRENT_DELIVERY_ROUTER.json) routers. This HIGH-risk authentication change grants no production, provider, real-participant, Phase-9 or merge authority. Graduated recovery, primary-email change and WELL-106 are outside scope.

## 2. Architecture, sequence and ownership

1. [RegistrationBoundary](../../lib/new_you_web/registration_boundary.ex) dispatches `/password/reset` and `/password/reset/confirm` through the existing secure browser pipeline without full-connection router telemetry. [PrivacyTelemetry](../../lib/new_you_web/privacy_telemetry.ex) scrubs `/password` requests. [Router](../../lib/new_you_web/router.ex) declares the same four routes with logging disabled.
2. [PasswordResetController](../../lib/new_you_web/controllers/password_reset_controller.ex) renders the bilingual request form. Its POST calls `Identity.request_password_reset/3` and always renders the neutral result for a valid request shape. The controller requires the explicit `p8_12_browser_development_fixtures` runtime flag and a dev/test build with development fixtures enabled.
3. [PasswordReset.request/3](../../lib/new_you/identity/password_reset.ex) runs one bounded issuance attempt. It canonicalizes the email and locks the current Account. Eligible Accounts are verified, open, have an active credential and normal security posture. One transaction supersedes an earlier current reset Token, creates a new purpose-bound Token and calls `Communications.establish_password_reset/1`. It creates no Account or Session. Ordinary retries with an existing request ID do not issue another proof.
4. [Communications](../../lib/new_you/communications.ex) binds a durable MessageIntent to exact Content-owned locale/version/digest evidence. Its existing scheduler rediscovers open obligations. [Executor](../../lib/new_you/communications/executor.ex) locks the intent, rechecks current Identity and content eligibility, admits/fences a DeliveryAttempt, then invokes the provider outside transactions. Provider ambiguity remains reconciliation-required. Provider state cannot change credentials.
5. `Identity.password_reset_delivery/3` reconstructs only the transient signature of a current Token's fixed claims inside the delivery transaction. It never upserts or renews a proof and retains no bearer in Communications. The body uses the existing deterministic `proof.invalid` development link convention. No real sender is enabled.
6. Confirmation HEAD/GET only renders a password field, proof, fresh opaque confirmation operation ID and CSRF-protected POST. Explicit POST calls `Identity.reset_password/3`. [PasswordReset](../../lib/new_you/identity/password_reset.ex) locks the Account and Token, then commits proof consumption, credential replacement, version advancement, revocation, registration-binding invalidation and Audit E2 together. Success clears the browser session and requires fresh authentication. No Session is issued.

Identity owns proof, credential, Session and device security truth. Communications owns delivery and provider observations. [Audit](../../lib/new_you/audit.ex) owns the selected evidence obligation and materialisation. Audit never replays Identity mutations.

## 3. Ash map and mechanism choices

[Identity](../../lib/new_you/identity.ex) exposes `request_password_reset/3`, `password_reset_delivery/3` and `reset_password/3`. [Account](../../lib/new_you/identity/account.ex) adds private generic action `reset_password` and private update `replace_password`. [ResetPassword.run/3](../../lib/new_you/identity/actions/reset_password.ex) delegates to the locked lifecycle. Password and proof arguments are sensitive; credential input is write-only. `replace_password` uses the installed AshAuthentication password hashing change and advances `credential_version` and `security_version`.

[Token](../../lib/new_you/identity/token.ex) adds private issuance, supersession, consumption and linked-authentication revocation actions. It remains the only reset-proof authority. Policies and private actions expose no ordinary public write path. [DeviceAssurance](../../lib/new_you/identity/device_assurance.ex) implements the governed device concept's read/revoke portion only. It provides no trust-enrolment or authentication interface. Tests seed prior trusted state as synthetic fixtures. A future trust grant must enforce consent, current authentication, expiry and Account-lock ordering.

Ash actions, PostgreSQL row locks and database identities are used. AshOban and the existing MessageIntent/Audit schedulers are reused. Ash Signals was considered; these owner calls require synchronous success and same-transaction rollback, so explicit existing owner interfaces remain the simpler fit. Temporal Resources is not applicable because there is no as-of/effective-period query requirement. No dependency, additional Repo, Redis service, raw-SQL business-write path or Ecto.Multi was added. Ash codegen produced migrations/snapshots; the custom action and constraint contracts use explicit resource DSL.

Material APIs were checked against installed Ash 3.37.2, AshPostgres 2.15.2, AshAuthentication 5.0.0-rc.17 and Joken 2.7.0. Version-matched primary references include [Ash transactions](https://hexdocs.pm/ash/3.37.2/Ash.html#transact/3), [HashPasswordChange](https://hexdocs.pm/ash_authentication/5.0.0-rc.17/AshAuthentication.Strategy.Password.HashPasswordChange.html) and [Joken.verify/3](https://hexdocs.pm/joken/2.7.0/Joken.html#verify/3). No v4 reset strategy or generated reset route is enabled.

## 4. Important interface contracts

`request_password_reset(email, locale, request_id)` always returns `:ok`. A 250 ms work deadline bounds issuance; every outcome is padded to a 500 ms response floor outside locks. Admission failure, invalid input, unknown/ineligible Accounts and interrupted work remain neutral. This is deliberate bounded timing treatment, not a claim of identical network/scheduler timing or a production distributed abuse policy.

`password_reset_delivery(jti, destination, locale)` requires an existing transaction. It returns `{:ok, bearer}` transiently, or `{:error, :source_invalid | :capability_unavailable}`. Current Account, signing-key binding, purpose, original claims, destination, locale and expiry are rechecked. Missing signing material holds the delivery obligation rather than fabricating delivery.

`reset_password(proof, password, confirmation_id)` returns `{:ok, :reset}`, `{:ok, :already_reset}` or the neutral `{:error, :reset_unavailable}`. Fresh credential input is nonempty, bounded to 1024 bytes and must not verify as the current Account password. The confirmation ID belongs to one consumed Token through a unique database identity. A retry with the same signed proof and committed ID reports the previous result without applying newly supplied password bytes. Another confirmation ID is a replay and fails. Receipt lookup verifies the original signature and exact stored claims even after expiry; only a fresh mutation requires all JWT time/resource checks and current security eligibility. Loss or retirement of the signing key still fails closed.

[PasswordResetMessage](../../lib/new_you/content/password_reset_message.ex) revalidates the current route, exact immutable evidence and five approval events before each binding/render. It returns exact approved EN V1 or AF V2 bytes with no locale fallback. [PasswordResetCopy](../../lib/new_you_web/password_reset_copy.ex) contains low-risk browser copy, reuses existing field/navigation keys and the existing check-email heading. Governed email bytes are not rewritten or promoted into the P8-05 runtime registry.

## 5. Lifecycle, failure and recovery

A new request supersedes the Account's current `password_reset` Token. A fresh explicit confirmation consumes one current proof into `password_reset_consumed`. Revoked, superseded, expired, wrong-purpose, altered and replayed proof cannot authorize a new mutation. The active proof binds the original signing key and current Account email, credential/hash/version, verification, closure and security posture. Its lifetime is 15 minutes.

Before any fresh reset write, `PasswordReset.replace_current/4` resolves the Account password strategy through `AshAuthentication.Info.strategy/2` and requires its configured [HashProvider.valid?/2](https://hexdocs.pm/ash_authentication/5.0.0-rc.17/AshAuthentication.HashProvider.html#c:valid?/2) to return `false` against the locked current credential. A match or verification failure returns the existing neutral unavailable result. Rejection preserves the proof, versions, Sessions and elevated assurance, linked authentication tokens, trusted devices, registration bindings and Audit state. This enforces F.3 old-credential retirement. It does not compare salted password hashes for equality. Committed receipt recovery runs before the fresh-reset guard and does not reapply or validate a replacement password.

The reset transaction replaces the credential and advances both versions once. It revokes every active password or magic-login Session, converts its linked `user` Token to `revocation`, clears elevated Session assurance through the existing revoke action, terminates all trusted devices and tombstones linked credential-derived registration replay material. It preserves unrelated purpose proofs and MFA enrollment. Historical Session/device revocations cannot restore authority. Password and magic Session issuance already take the same Account lock; password issuance rechecks the previously verified hash under that lock. A stale old-password check cannot issue a valid post-reset Session.

A consumed Token is a durable outcome receipt, excluded from expired-token cleanup. Consumption clears its credential-derived binding while retaining only fixed non-bearer claims, opaque request/confirmation IDs and existing Token provenance. The receipt cannot deliver, consume again or authenticate. This preserves same-operation outcome recovery after expiry without a second proof store. A retention/disposition change must preserve that contract.

Any failed credential, revocation, Audit obligation or Audit job write rolls the source transaction back. A pre-commit process death leaves prior credential/Session authority and current proof intact. A post-commit lost reply recovers from the receipt. An already-committed MessageIntent remains discoverable independently of jobs. Executor death before invocation may safely reopen delivery; a durable invocation marker with uncertain provider outcome prevents blind retry. Audit materialisation retries the existing E2 obligation and never repeats reset. The existing E2 machinery records only the successful source operation, occurrence time, Account actor/target IDs and bounded result.

## 6. Persistence and consistency

The migrations are [reset authority](../../priv/repo/migrations/20261110112805_well13_password_reset.exs), [Communications role](../../priv/repo/migrations/20261110112902_well13_communications.exs) and [minimized receipts](../../priv/repo/migrations/20261110114443_well13_reset_receipts.exs).

They add `accounts.credential_version` with default 1; the governed `device_assurances` table and Account FK; reset metadata on `tokens`; partial unique `tokens_one_current_password_reset_index`; unique request and confirmation indexes; reset metadata/receipt checks; the selected `identity_password_reset` Audit type; and the exact password-reset message role/purpose/schema check. Existing Accounts require no credential rewrite. No existing proof is reclassified. Resource snapshots match the new Ash definitions.

Identity's reset `Ash.transact` includes Account, Token, Session, DeviceAssurance, RegistrationOperation and EvidenceObligation. The Audit owner schedules its existing id-only job in that same source transaction. Issuance commits the Token and MessageIntent together. Provider I/O happens after delivery admission commits. Jobs, provider observations and UI state remain non-authoritative.

Downward migration is not a security-history deletion procedure. The first migration explicitly refuses rollback when device records, reset metadata or reset evidence exist; later constraint reversals also fail closed for incompatible retained receipts/intents. Any populated-environment disposition requires an explicit owner decision.

## 7. Tests, proof and observed evidence

The focused suites are [reset outcome](../../test/new_you/identity/password_reset_test.exs), [lifecycle/failure/privacy](../../test/new_you/identity/password_reset_lifecycle_test.exs), [neutral request/deadline](../../test/new_you/identity/password_reset_request_test.exs), [content eligibility](../../test/new_you/content/password_reset_message_test.exs), and [controller/Chromium](../../test/new_you_web/controllers/password_reset_controller_test.exs). The browser test builds current assets before launch and verifies that the stylesheet loaded, so clean checkouts exercise the same focus and responsive CSS. It exercises real EN/AF submission, CSRF, no automatic login, replay rejection, keyboard focus, 375 px overflow and reduced motion through the existing [browser helper](../../test/support/proof/p8_05_browser.ex).

[P812](../../test/support/proof/p8_12.ex), its [partial catalog](../../test/support/proof/p8_12_catalog.ex), [restart helper](../../test/proof/p8_12_restart.exs) and [integration test](../../test/new_you/proof/p8_12_test.exs) reuse P805, Scenario, CutPoints and the existing runner. They prove independent PostgreSQL connections and observed blocking before release, one competing reset winner, stale-password login rejection, pre-commit rollback, independent-BEAM delivery/consume/retry, one Audit obligation and prior Session revocation. The family remains partial; this is not Foundation Full or Phase-8 certification.

Observed RED evidence included missing reset interfaces, missing controller routes, the registration-binding invalidation gap and the post-expiry committed-retry gap. The hosted focus-visibility failure was reproduced by removing compiled CSS; the corrected browser test builds current assets and passes from that same missing-CSS state without weakening the focus assertion. The focused integration run passed 31 tests; an additional lifecycle/proof run passed 12 tests including three provider crash cuts. Final gate outcomes and the exact reviewed candidate belong to the PR evidence. Expected CSRF failures and deliberate worker termination produce bounded test diagnostics; they are not hidden application failures.

MG-215-01 added the lifecycle regression `current password rejection preserves the full reset boundary for a later different password`. Against reviewed runtime head `034c961659e2f64a892216ae5dc43b91c45a71e4`, it failed with `{:ok, :reset}` and confirmed that the old password still authenticated. Account, Token, Session, DeviceAssurance, registration-binding, Audit obligation and Audit job state changed. After the guard, the same focused command passed: rejection preserves all eight observed tables, the same proof and confirmation ID then reset to a different password, the old password fails authentication, and a committed retry makes no further mutation. Snapshot diagnostics contain only fixed outcomes and per-table equality facts. The broader reset/browser/PostgreSQL concurrency/restart run passed 23 tests. Reproduce the focused regression with `devcore-project run test -- mise exec -- mix test test/new_you/identity/password_reset_lifecycle_test.exs:10`. Final-head gates and hosted CI are recorded in PR #215.

Reproduce using the committed mise toolchain and DevCore TEST environment:

```sh
devcore-project doctor
devcore-project run test -- mise exec -- mix test test/new_you/identity/password_reset_test.exs test/new_you/identity/password_reset_lifecycle_test.exs test/new_you/identity/password_reset_request_test.exs test/new_you/content/password_reset_message_test.exs test/new_you_web/controllers/password_reset_controller_test.exs test/new_you/proof/p8_12_test.exs
devcore-project run test -- mise exec -- mix check
devcore-project run test -- mise exec -- mix check.deep
devcore-project run test -- mise exec -- mix ash.codegen --check
mise exec -- python3 tools/hex_security_audit.py
python3 tools/check_password_reset_message_evidence.py
git diff --check
```

Hallmark v2.0.0 cannot parse `.heex` targets directly. Its supported render command was run against the four local EN/AF request/confirmation URLs with `--scope app --render --json`. It captured 20 views at desktop and mobile sizes, with zero FAILs and four gate 39b REFLEX findings. The findings are specifically waived because [DESIGN.md](../../DESIGN.md) locks `text-input.height` to 58 px and [design-tokens.css](../../assets/css/design-tokens.css) supplies that alias. Shrinking the input would violate the established design. No redesign, theme selection or governance change was performed. The command and final confirmation run are recorded in the PR evidence. Loading is ordinary form navigation; empty password input uses required-field validity, unavailable proof has an announced result and new-request action, and successful reset offers fresh sign-in.

## 8. Future-agent extension guide and review boundary

Start with the controller and Identity interfaces above, then inspect the Account/Token actions, reset transaction, constraints and executable tests. Follow Communications admission through its provider boundary separately from the Identity reset transaction. Follow the E2 obligation through Audit materialisation without treating evidence as source success authority. This cold-start walkthrough was checked against the linked source and tests; the expiry-retry and registration-binding discrepancies were corrected in this PR.

New callers must use the owning Identity interfaces, preserve purpose and Account-lock ordering, and never place passwords or bearer material in jobs, logs, telemetry or Audit payloads. Device enrollment and graduated recovery remain separate work. Production/provider activation needs its own authority; neither current fixtures nor approved development copy supply it.

The next required gate is independent Master Gate review of the exact PR head and complete diff, current Plane contract and exact-head hosted CI. The accountable repository operator must preserve the authentic review and full-diff digest, materialize `review.json`, run the documented pre-merge collector, obtain separate merge authorization, and run resulting-main certification afterward. The implementer supplies no Master Gate attestation and performs no merge. Plane Done and dependent work remain gated by resulting-main certification under [the merge-gate procedure](foundation-integrity-merge-gate.md).

## Complete changed-file inventory

- `docs/README.md`
- `docs/development/p8-12-password-reset-handoff.md`
- `lib/new_you/application.ex`
- `lib/new_you/audit/evidence_obligation.ex`
- `lib/new_you/audit/privileged_evidence.ex`
- `lib/new_you/communications.ex`
- `lib/new_you/communications/executor.ex`
- `lib/new_you/communications/message_intent.ex`
- `lib/new_you/content/password_reset_message.ex`
- `lib/new_you/identity.ex`
- `lib/new_you/identity/account.ex`
- `lib/new_you/identity/actions/reset_password.ex`
- `lib/new_you/identity/device_assurance.ex`
- `lib/new_you/identity/password_reset.ex`
- `lib/new_you/identity/token.ex`
- `lib/new_you_web/controllers/password_reset_controller.ex`
- `lib/new_you_web/controllers/password_reset_html.ex`
- `lib/new_you_web/controllers/password_reset_html/confirmation.html.heex`
- `lib/new_you_web/controllers/password_reset_html/confirmation_result.html.heex`
- `lib/new_you_web/controllers/password_reset_html/request.html.heex`
- `lib/new_you_web/controllers/password_reset_html/request_result.html.heex`
- `lib/new_you_web/password_reset_copy.ex`
- `lib/new_you_web/privacy_telemetry.ex`
- `lib/new_you_web/registration_boundary.ex`
- `lib/new_you_web/router.ex`
- `mix.exs`
- `priv/repo/migrations/20261110112805_well13_password_reset.exs`
- `priv/repo/migrations/20261110112902_well13_communications.exs`
- `priv/repo/migrations/20261110114443_well13_reset_receipts.exs`
- `priv/resource_snapshots/repo/accounts/20261110112806.json`
- `priv/resource_snapshots/repo/device_assurances/20261110112807.json`
- `priv/resource_snapshots/repo/evidence_obligations/20261110112808.json`
- `priv/resource_snapshots/repo/message_intents/20261110112903.json`
- `priv/resource_snapshots/repo/tokens/20261110114444.json`
- `test/new_you/content/password_reset_message_test.exs`
- `test/new_you/identity/email_verification_test.exs`
- `test/new_you/identity/magic_login_lifecycle_test.exs`
- `test/new_you/identity/password_reset_lifecycle_test.exs`
- `test/new_you/identity/password_reset_request_test.exs`
- `test/new_you/identity/password_reset_test.exs`
- `test/new_you/identity/registration_primitives_test.exs`
- `test/new_you/proof/p8_05_test.exs`
- `test/new_you/proof/p8_12_test.exs`
- `test/new_you_web/controllers/password_reset_controller_test.exs`
- `test/new_you_web/security/authentication_reachability_test.exs`
- `test/proof/p8_05_browser.mjs`
- `test/proof/p8_12_restart.exs`
- `test/support/proof/catalog.ex`
- `test/support/proof/p8_05.ex`
- `test/support/proof/p8_05_browser.ex`
- `test/support/proof/p8_12.ex`
- `test/support/proof/p8_12_catalog.ex`
- `tests/test_foundation_smoke.py`

## WELL-110 Product successor compatibility

At implementation source `c33ab1e00dc19e07003a0f1cae3481fb1e8e1737`, [PasswordResetMessage](../../lib/new_you/content/password_reset_message.ex) retains the exact WELL-98 historical packet, Product/Decision predecessor and proposal checks, and requires the named v1.16 successor routes, file digests, predecessor lineage and WELL-110 recovery classification proposal. The existing exact EN/AF content and no-fallback checks remain in force. A changed, duplicate or stale current route or altered source fails closed. This correction grants no production or provider authority.

The combined [password-reset](../../test/new_you/content/password_reset_message_test.exs) and [magic-login](../../test/new_you/content/magic_login_message_test.exs) reader suite passed 27 tests locally after the route change. The same suite failed on both readers before the compatibility correction. Hosted CI and independent review are tracked on the PR, not certified by this note.
