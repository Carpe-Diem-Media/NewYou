# WELL-10 Assent assessment

This is a HIGH / privileged_security assessment of implementation head `7f466d4d5fd3404eefea9a8ca04112660e5991fc`, based on `0f42ff54b325b455b38171dd00269baf7fcc914f`. An independent read-only security reviewer inspected that exact head and its dependency graph, application reachability and new Communications boundaries. This record supplies technical evidence for the accountable owner's decision. It does not grant authorization, activate a controlled disposition or certify merge readiness.

## Finding and dependency compatibility

The fresh isolated Hex 2.6.0 audit found Assent `0.2.13` affected by `EEF-CVE-2026-117656`, `CVE-2026-117656` and `GHSA-9fr5-g44g-9526`. The [upstream advisory](https://github.com/pow-auth/assent/security/advisories/GHSA-9fr5-g44g-9526) identifies the unverified Apple callback parameter that can override verified token claims. It lists affected versions `>= 0.1.25, < 0.3.2`. [Hex](https://hex.pm/packages/assent) lists patched stable `0.3.2`.

The unchanged [lock](../../../mix.lock) pins AshAuthentication `4.15.1` and Assent `0.2.13`. AshAuthentication's locked dependency constraint excludes Assent `0.3.x`. Installing `0.3.2` alone would not fit that graph. This PR introduces no dependency override or authentication package change. Supported remediation/version validation remains with [WELL-91](https://app.plane.so/symphony-development/browse/WELL-91); the dependency remains vulnerable and this audit is not clean.

## Independent reachability findings

The reviewer found no reachable Apple/OAuth strategy, direct Assent call or identity-linking implementation in current `lib/` or `config/`. [Account](../../../lib/new_you/identity/account.ex) configures password authentication only, with framework password sign-in and registration disabled. The [router](../../../lib/new_you_web/router.ex) has no Apple/OAuth callback or strategy route. [Authentication reachability guards](../../../test/new_you_web/security/authentication_reachability_test.exs) assert those limits. [PasswordSession](../../../lib/new_you/identity/password_session.ex) is the local password/Session implementation.

New Communications execution uses the [Identity verification eligibility guard](../../../lib/new_you/identity/delivery_eligibility.ex), not an Apple/OAuth callback or identity-linking path. [DeliveryProvider](../../../lib/new_you/communications/delivery_provider.ex) selects DisabledProvider outside TEST. Reconciliation has no HTTP route and its production authentication always rejects evidence. The [TEST adapter](../../../test/support/proof/delivery_adapter.ex) checks synthetic HMAC evidence against exact attempt/outcome/reference. The [privacy and authorization tests](../../../test/new_you/communications/delivery_evidence_test.exs) cover unauthenticated reconciliation, forbidden Resource actions, transient payload inspection, provider exceptions, telemetry and ordinary persistence.

The independent engineering reviewer separately reported no concrete correctness/security/scope defect in the exact implementation diff. Neither reviewer ran database tests during review; observed local test/check results come from the implementing agent's runs. Their reviews are not Master Gate certification.

## Input binding and required decision

The independent reviewer computed the candidate's canonical `input_digest` as:

`2c4e97e5ca481ed7f436a87d770f56b64162e82722bcffe990f355e023ec21c1`

The existing [exception](../../../tools/hex_audit/assent_exception.json) and [audit constants](../../../tools/hex_security_audit.py) remain bound to:

`9054cd23327eb3ac64f5cbaf1c7672c33e1497cb09d4214c63cbd2e87ad54545`

The fresh audit wrapper exited 1 with `Exception invalidated by changed dependency/source/config inputs`. That is the required fail-closed result. No approval reference, input binding, audit guard, regression expectation or expiry changed in this implementation.

The independent reviewer rejected reliance on the stale disposition and found that a new narrow temporary non-reachability disposition could be presented to accountable owner JC with the exact changed digest and evidence above. Explicit owner authorization is still required before any new binding. Residual risk is the vulnerable transitive dependency, subject to the verified absence of an applicable route/caller; it is not remediation or a universal non-exploitability claim.

The exclusive deadline remains `2026-11-18T00:00:00Z`. Any new production source/config, lock/toolchain/mix or reachability-guard change invalidates this candidate assessment and requires reassessment before binding. New authentication/Apple/OAuth strategies, callbacks, direct Assent calls, identity linking, advisory evidence, supported remediation or changed stable parent releases also invalidate the previous compatibility/reachability decision. No expiry extension is authorized here. Plane and the PR must record the actual owner decision and exact-head CI before this work can be called review-ready.
