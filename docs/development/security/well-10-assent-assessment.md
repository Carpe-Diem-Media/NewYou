# WELL-10 Assent assessment

This is a HIGH / privileged_security assessment of implementation head `38934a265609283e63a9b54eefe85888ea82fae5`, based on `0f42ff54b325b455b38171dd00269baf7fcc914f`. An independent read-only security reviewer inspected that exact head and its dependency graph, application reachability and new Communications boundaries. This record supplies technical evidence for the accountable owner's decision. It does not grant authorization, activate a controlled disposition or certify merge readiness.

## Finding and dependency compatibility

The fresh isolated Hex 2.6.0 audit found Assent `0.2.13` affected by `EEF-CVE-2026-117656`, `CVE-2026-117656` and `GHSA-9fr5-g44g-9526`. The [upstream advisory](https://github.com/pow-auth/assent/security/advisories/GHSA-9fr5-g44g-9526) identifies the unverified Apple callback parameter that can override verified token claims. It lists affected versions `>= 0.1.25, < 0.3.2`. [Hex](https://hex.pm/packages/assent) lists patched stable `0.3.2`.

The [lock](../../../mix.lock) pins AshAuthentication `4.15.1` and Assent `0.2.13`. AshAuthentication's locked dependency constraint excludes Assent `0.3.x`. Installing `0.3.2` alone would not fit that graph. This PR introduces no dependency override or authentication package change. Supported remediation/version validation remains with [WELL-91](https://app.plane.so/symphony-development/browse/WELL-91); the dependency remains vulnerable and this audit is not clean.

## Independent reachability findings

The reviewer found no reachable Apple/OAuth strategy, direct Assent call or identity-linking implementation in current `lib/` or `config/`. [Account](../../../lib/new_you/identity/account.ex) configures password authentication only, with framework password sign-in and registration disabled. The [router](../../../lib/new_you_web/router.ex) has no Apple/OAuth callback or strategy route. [Authentication reachability guards](../../../test/new_you_web/security/authentication_reachability_test.exs) assert those limits. [PasswordSession](../../../lib/new_you/identity/password_session.ex) is the local password/Session implementation.

New Communications execution uses the [Identity verification eligibility guard](../../../lib/new_you/identity/delivery_eligibility.ex), not an Apple/OAuth callback or identity-linking path. [DeliveryProvider](../../../lib/new_you/communications/delivery_provider.ex) selects DisabledProvider outside TEST. Reconciliation has no HTTP route and its production authentication always rejects evidence. The [TEST adapter](../../../test/support/proof/delivery_adapter.ex) checks synthetic HMAC evidence against exact attempt/outcome/reference. The [privacy and authorization tests](../../../test/new_you/communications/delivery_evidence_test.exs) cover unauthenticated reconciliation, forbidden Resource actions, transient payload inspection, provider exceptions, telemetry and ordinary persistence.

The correction-specific independent security reviewer inspected the diff against previously approved head `34d85c048feb1183e8a52649d912a84e59cd4102`. AshStateMachine 0.3.0 adds no authentication path. Its [release metadata](https://hex.pm/api/packages/ash_state_machine/releases/0.3.0) declares Ash `>= 3.4.66 and < 4.0.0-0`, compatible with locked Ash 3.37.2, and lists no security advisories. No existing dependency version changed. The reviewer verified that explicit disposition actions reject arbitrary state inputs, historical inactive evidence cannot apply ordinary parent disposition effects, and exceptional conflict recovery requires a flagged attempt belonging to that same intent. The reviewer ran no database tests; local execution evidence comes from the implementing agent. This reassessment is not Master Gate certification.

## Input binding and required decision

The independent reviewer computed the candidate's canonical `input_digest` as:

`532a998b33c90ea736a045701624655b8313ec7239b81116fbfb06d6310c6699`

The existing [exception](../../../tools/hex_audit/assent_exception.json) and [audit constants](../../../tools/hex_security_audit.py) remain bound to:

`2c4e97e5ca481ed7f436a87d770f56b64162e82722bcffe990f355e023ec21c1`

The prior owner approval, WELL-91 comment `d9d80575-34d9-41cb-9879-5823873cb68a`, applies only to that earlier digest. It does not authorize this correction candidate. The fresh audit wrapper exited 1 with `Exception invalidated by changed dependency/source/config inputs`. That is the required fail-closed result. No approval reference, input binding, audit guard, regression expectation or expiry changed in this implementation.

The independent reviewer rejected reliance on the stale disposition and found that a new narrow temporary non-reachability disposition could be presented to accountable owner JC with the exact changed digest and evidence above. Explicit owner authorization is still required before any new binding. Residual risk is the vulnerable transitive dependency, subject to the verified absence of an applicable route/caller; it is not remediation or a universal non-exploitability claim.

The exclusive deadline remains `2026-11-18T00:00:00Z`. Any new production source/config, lock/toolchain/mix or reachability-guard change invalidates this candidate assessment and requires reassessment before binding. New authentication/Apple/OAuth strategies, callbacks, direct Assent calls, identity linking, advisory evidence, supported remediation or changed stable parent releases also invalidate the previous compatibility/reachability decision. No expiry extension is authorized here. Plane and the PR must record the actual owner decision and exact-head CI before this work can be called review-ready.
