# WELL-10 Assent assessment

This is a HIGH / privileged_security assessment of implementation head `87f70c41589f50e775a0834544f02dcee548968b`, based on `0f42ff54b325b455b38171dd00269baf7fcc914f`. An independent read-only security reviewer inspected that exact head and its dependency graph, application reachability and new Communications boundaries. The reassessment is recorded in [WELL-91 comment c97d83ac-4d13-4c30-affc-a4dbec2bfc3a](https://app.plane.so/symphony-development/browse/WELL-91). This record supplies technical evidence for the accountable owner's decision. It does not grant authorization, activate a controlled disposition or certify merge readiness.

## Finding and dependency compatibility

The fresh isolated Hex 2.6.0 audit found Assent `0.2.13` affected by `EEF-CVE-2026-117656`, `CVE-2026-117656` and `GHSA-9fr5-g44g-9526`. The [upstream advisory](https://github.com/pow-auth/assent/security/advisories/GHSA-9fr5-g44g-9526) identifies the unverified Apple callback parameter that can override verified token claims. It lists affected versions `>= 0.1.25, < 0.3.2`. [Hex](https://hex.pm/packages/assent) lists patched stable `0.3.2`.

The [lock](../../../mix.lock) pins AshAuthentication `4.15.1` and Assent `0.2.13`. AshAuthentication's locked dependency constraint excludes Assent `0.3.x`. Installing `0.3.2` alone would not fit that graph. This PR introduces no dependency override or authentication package change. Supported remediation/version validation remains with [WELL-91](https://app.plane.so/symphony-development/browse/WELL-91); the dependency remains vulnerable and this audit is not clean.

## Independent reachability findings

The reviewer found no reachable Apple/OAuth strategy, direct Assent call or identity-linking implementation in current `lib/` or `config/`. [Account](../../../lib/new_you/identity/account.ex) configures password authentication only, with framework password sign-in and registration disabled. The [router](../../../lib/new_you_web/router.ex) has no Apple/OAuth callback or strategy route. [Authentication reachability guards](../../../test/new_you_web/security/authentication_reachability_test.exs) assert those limits. [PasswordSession](../../../lib/new_you/identity/password_session.ex) is the local password/Session implementation.

New Communications execution uses the [Identity verification eligibility guard](../../../lib/new_you/identity/delivery_eligibility.ex), not an Apple/OAuth callback or identity-linking path. [DeliveryProvider](../../../lib/new_you/communications/delivery_provider.ex) selects DisabledProvider outside TEST. Reconciliation has no HTTP route and its production authentication always rejects evidence. The [TEST adapter](../../../test/support/proof/delivery_adapter.ex) checks synthetic HMAC evidence against exact attempt/outcome/reference. The [privacy and authorization tests](../../../test/new_you/communications/delivery_evidence_test.exs) cover unauthenticated reconciliation, forbidden Resource actions, transient payload inspection, provider exceptions, telemetry and ordinary persistence.

The correction-specific independent reviewer compared this source with previously reviewed head `3a24ed17da851980886df766e94ec41f662845d8`. The only production source change is [Executor](../../../lib/new_you/communications/executor.ex). Recovery now closes the historical uninvoked admission and calls `reopen_guarded/1`, shared with safe provider outcomes. Under the existing intent/source locks, it rereads Identity eligibility, immutable content eligibility, render integrity, envelope/keyring capability and provider availability. Invalid source closes dispatch and clears capability; another unavailable prerequisite holds dispatch. Recovery invokes no provider and admits no new attempt. The change adds no authentication path, dependency, route or new persistence mechanism. The reviewer found no new reachability to the Apple callback claim merge described in the advisory. The reviewer ran no tests or database commands; execution evidence comes from the implementing agent. This assessment does not certify merge readiness.

## Input binding and required decision

The independent reviewer computed the candidate's canonical `input_digest` as:

`2c82e2c7608eaef0f4a6204041377b7a2300a23434eda8445307477bd147e9a0`

At the assessed source revision, before owner authorization, the [exception](../../../tools/hex_audit/assent_exception.json) and [audit constants](../../../tools/hex_security_audit.py) were bound to:

`bd4ddce56947edb853449b26793a974266e48e5762cf77d19dd1f2c24cba0d4d`

At that source revision, the prior owner approval, WELL-91 comment `41bbcf5f-6473-4065-a531-4a5fa7bdf834`, applies only to that earlier digest. It did not authorize this correction candidate. The fresh audit wrapper exited 1 with `Exception invalidated by changed dependency/source/config inputs`. That is the required fail-closed result. No approval reference, input binding, audit guard, regression expectation or expiry changed in this correction. The previous authorized binding-only commit remains in the PR; its authorization does not carry forward to these new source inputs.

The independent reviewer rejected reliance on the stale disposition and found that a new narrow temporary non-reachability disposition could be presented to accountable owner JC with the exact changed digest and evidence above. That assessment required explicit owner authorization before any new binding. Residual risk is the vulnerable transitive dependency, subject to the verified absence of an applicable route/caller; it is not remediation or a universal non-exploitability claim.

The exclusive deadline remains `2026-11-18T00:00:00Z`. Any new production source/config, lock/toolchain/mix or reachability-guard change invalidates this candidate assessment and requires reassessment before binding. New authentication/Apple/OAuth strategies, callbacks, direct Assent calls, identity linking, advisory evidence, supported remediation or changed stable parent releases also invalidate the previous compatibility/reachability decision. No expiry extension is authorized here. Plane and the PR must record the actual owner decision and exact-head CI before this work can be called review-ready.

## Final source freeze and owner authorization

A fresh full-PR review at `c50b74a2dc1e75dfb7a946b0d0eaee9d8daae958` found no concrete blocking correctness/security defect or necessary hardening change. Independent lifecycle/persistence and proof/handoff reviews reached the same bounded conclusion. They were read-only reviews, not Master Gate certification. A new local Communications run passed all 75 tests. The canonical scanner recomputation includes all 78 defined input files, including additions under `lib/` and `config/`, and matches `2c82e2c7608eaef0f4a6204041377b7a2300a23434eda8445307477bd147e9a0`. Every input is byte-identical to the owner-authorized candidate.

Explicit accountable-owner authorization is recorded in [WELL-91 comment 41c24934-21d0-4b29-a86f-56532b27e5c9](https://app.plane.so/symphony-development/browse/WELL-91), verified live before binding. It authorizes only the approval pointer, exact digest and corresponding regression expectations in the three existing binding files. The superseded approval/digest and every earlier rejection remain negative cases. The exclusive expiry and all scanner/invalidation controls remain unchanged. The binding follows this documentation commit as the final implementation change. Actual binding SHA, local results and hosted exact-head evidence belong in PR #201 and Plane, without rewriting the assessed source snapshot above. WELL-91 remains open for remediation.
