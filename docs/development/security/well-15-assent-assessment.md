# WELL-15 Assent and privileged-security assessment

## Status after pre-binding hardening

This assessment is historical evidence for `341f0e8fa762405bfd5750d48f21818996f53137`. Later WELL-15 production corrections change its covered inputs. Its digest is unapproved and cannot be rebound for the hardened implementation. A fresh independent HIGH assessment of frozen source and explicit accountable-owner acceptance are still required. No exception is approved by this document.

## Scope and disposition

This independent HIGH / privileged_security assessment reviews source commit `341f0e8fa762405bfd5750d48f21818996f53137` against base `75185b44b535d0f6513dcab1922e06c35a48029a`, on 2026-11-08. The reviewer inspected the complete committed diff, including migrations, generated schema snapshots and tests, and the uncommitted [P8-14 handoff](../p8-14-reconciliation-handoff.md). The reviewer worked only in the existing WELL-15 worktree and wrote only this assessment.

A temporary Assent technical non-reachability disposition is supportable for accountable owner JC's explicit consideration of the exact digest below. Assent remains vulnerable. This assessment does not accept that risk for JC, authorize exception rebinding, certify the entire implementation, or grant Master Gate, merge, production, release or real-participant authority. The concurrency proof finding below remains separate delivery work.

The reviewer read live [WELL-15](https://app.plane.so/symphony-development/browse/WELL-15), including readiness comment `5c43ee9d-a15d-43a4-9add-89fae2e4a2eb` and implementation comment `b1d5e705-45dd-4bfc-84d8-8fe1d67b4a56`, and live [WELL-91](https://app.plane.so/symphony-development/browse/WELL-91). Current documentation routers supersede obsolete paths in the ticket. Identity dossier E.8/F.9, permanent PMR law and Audit's E1/E2 selection remain controlling. No durable governance changed in the reviewed diff.

## Exact inputs and existing approval

The reviewer independently imported [tools/hex_security_audit.py](../../../tools/hex_security_audit.py) with Python bytecode writes disabled and called `input_digest(Path.cwd())`. Its 96 canonical inputs are `mix.exs`, `mix.lock`, `.tool-versions`, the authentication reachability test, and every file under `lib/` and `config/`. The result matches the parent's observation:

`b0d5d125a42c0ea556631f609e42ac605537d463b9c0423defa21361124d4e64`

The unchanged scanner and [exception metadata](../../../tools/hex_audit/assent_exception.json) still bind `63a6baf0a290195303bd3357f496b1dbcbe5ee3ce6057cd0a524085fbfef5005` and WELL-91 owner approval `db89b442-f288-4f94-9fef-c89512544e74`. That live approval expressly covers the previous WELL-14 inputs only. It cannot authorize WELL-15. The [previous assessment](well-14-assent-assessment.md) includes superseded conclusions and subsequent corrections; none supplies portable correctness certification.

The reviewer inspected the existing fresh wrapper log `/tmp/well15-hex-audit.log`. Its Hex 2.6.0 SARIF contains one unsuppressed Assent 0.2.13 advisory, followed by `HEX SECURITY AUDIT FAILURE: Exception invalidated by changed dependency/source/config inputs`. This is an expected rejection of stale approval, not a clean or passing audit. The reviewer did not launch another audit. The committed diff changes none of the three approval-binding files, scanner logic, dependency lock or configuration. No approval constant, metadata or expiry was edited by this review.

The digest selector does not include migrations or this document. Their review remains bound to the recorded source SHA and inspected worktree. A matching digest alone cannot certify a later changed diff.

## Advisory and current stable compatibility

The [maintainer advisory](https://github.com/pow-auth/assent/security/advisories/GHSA-9fr5-g44g-9526) affects versions from 0.1.25 through 0.3.1 and identifies 0.3.2 as patched. The Apple callback can let unsigned browser data replace verified identity claims and cause impersonation in applications that trust those results. The [EEF record published through OSV](https://osv.dev/vulnerability/EEF-CVE-2026-117656) confirms aliases `EEF-CVE-2026-117656`, `CVE-2026-117656` and `GHSA-9fr5-g44g-9526`. Upstream reports critical CVSS 9.3; the inspected pinned Hex evidence reports severity metadata 9.5. The scanner's evidence expectations remain unchanged.

On 2026-11-08 the reviewer fetched official Hex pages and independently queried its package/release APIs. [Assent](https://hex.pm/packages/assent) has stable 0.4.0, with 0.3.2 also published. [AshAuthentication](https://hex.pm/packages/ash_authentication) still has stable 4.15.1; 5.0.0-rc.17 is a prerelease. The [4.15.1 dependency requirement](https://hex.pm/packages/ash_authentication/4.15.1/dependencies), also verified in the installed package and lock, is `> 0.2.0 and < 0.3.0`. It excludes both patched versions. The current stable compatible Assent release remains vulnerable 0.2.13. No broad upgrade, unsupported override, downgrade or prerelease adoption is proposed.

## Authentication reachability

[Account](../../../lib/new_you/identity/account.ex) declares only the password strategy. Generated registration, sign-in and sign-in-token routes are disabled; no OAuth strategy or authentication add-on is declared. Its explicit magic-login action uses Identity proof/Session mechanisms. Privileged reconciliation adds purpose-bound password/TOTP assurance, not provider authentication.

The reviewer searched production source and configuration for Assent, Apple, OAuth, strategy routes, callback dispatch and identity/account linking, then inspected [the router](../../../lib/new_you_web/router.ex), Account authentication configuration and [the reachability regression](../../../test/new_you_web/security/authentication_reachability_test.exs). There is no application caller of Assent, Apple/OAuth callback route, provider identity field or provider-account linking implementation in the inspected code. Reconciliation links existing internal Account references after current control checks; it never consumes Apple/OAuth claims. The vulnerable Apple implementation is nevertheless present in the installed Assent dependency.

The regression enumerates the sole authentication Resource, exact password configuration, empty generated strategy routes, complete Account action inventory and all 12 HTTP routes. The WELL-15 delta adds two private Account-action expectations. The existing routes cover the root page, registration, email verification, explicit magic-login confirmation and legal pages. No reconciliation HTTP route was added. These are source and regression-design observations; this reviewer did not independently execute the runtime guard or test a deployed environment.

## Reconciliation correctness and security

[Reconciliation](../../../lib/new_you/identity/reconciliation.ex) locks involved Accounts in UUID order before private privileged authorization, then locks the case. It includes the recorded reviewer Account when present. [PrivilegedAccess](../../../lib/new_you/identity/privileged_access.ex) reconstructs current actor, bearer, stored token, Session, role/scope grant and purpose/version-bound MFA assurance. The actor cannot be either candidate. No production grant-provisioning path was added.

Approval requires exactly two authenticated control credentials resolving to the two candidates. Stored review evidence contains references, timestamps and versions. Apply rechecks Account eligibility, reviewer/grant versions, each control Session's state and expiries, stored user-token presence/expiry and revocation, and the five-minute control window. It repeats checks after independently committed case-bound E1 admission. Same-operation replay binds the case, actor, grant/version, Session and original request version to the committed decision and still requires current privileged authority.

Candidate Account locks and reconciliation versions protect overlapping cases in the source design. Source commit closes the losing Account terminally, revokes its active Sessions, permanently retires its PMR, advances the survivor's version and establishes linked E2 work atomically. Existing PMR reservations prevent reuse. Database guards preserve original case fields and history, reject terminal-record updates/deletion/TRUNCATE, and prohibit retired-PMR resurrection. Linked compensation requires a new reviewed case and a currently eligible canonical Account; it preserves original decisions and retired values. It does not restore a terminal losing Account or transfer foreign records.

Caught source failure leaves E1 and attempts a separately committed failed E2 outcome. An existing failed operation cannot later apply successfully. If failure evidence cannot commit, E1 has an unresolved outcome; it does not prove source success. Process death before source commit leaves reconstructible unapplied work. Death after commit leaves the applied case and E2 obligation. Audit materialisation recovers evidence without replaying Identity effects.

Communications and Audit each return their own bounded owner review preserving original Account associations. Their implemented consequences require no foreign-record remap or owner job. An unrecognized configured Ash Domain blocks approval/apply. This is supportable for the existing bounded owner inventory, not proof for future commerce, health or professional records.

### Separate correctness/proof finding

**P2 / medium: the overlapping-case regression does not isolate candidate contention from shared privileged authority.** In [reconciliation_test.exs](../../../test/new_you/identity/reconciliation_test.exs), lines 296-341, the reverse case retains `f.actor` and its credentials. Both workers therefore share the same privileged Account and Session. The PostgreSQL blocking assertion proves separate connections contend, but can pass because of that common authority even if candidate serialization regresses. It cannot independently establish the claimed overlapping-Account lock boundary. Add a focused race with distinct privileged actors, Sessions, grants and reviewer authority, sharing only the overlapping candidates, and verify one applied decision plus stale/conflicting rejection. Preserve reversed candidates and observed database contention. No runtime corruption was reproduced; the inspected source currently locks candidates. The root must reconcile this proof gap before claiming that boundary fully verified. This reviewer did not edit tests or post tracker updates.

## Observed verification limits

`git diff --check` passed for the specified base/source pair. The reviewer inspected `/tmp/well15-deep-final.log`, which ends with zero Dialyzer errors and successful completion. `/tmp/well15-check-final.log` reports 563/564 tests passing, with the stale expiry-helper failure described by the parent. The frozen source contains the corrected direct expiry-negative request. At final inspection, `/tmp/well15-check-frozen.log` ends with `Result: 564 passed` after 244.7 seconds. Its observed fast checks included the architecture boundary, Credo without findings and completed Sobelow scanning. The reviewer observed these log results, without running either gate or independently observing its process exit status.

No database tests, application commands or DevCore state changes were run by this reviewer. Supplied logs are implementer runtime evidence, not independently rerun or cryptographically bound exact-head certification. Hosted CI, final serial checks, code-generation verification, clean final worktree and independent Master Gate remain the root's responsibility. The handoff generally matches the inspected lifecycle and failure semantics, subject to the concurrency proof limitation above. This review does not certify merge readiness.

## Owner decision, residual risk and invalidation

Residual risk is the retained critical vulnerable dependency and future authentication/configuration drift. The proposed disposition is restricted to bounded development/test Phase-8 work. It grants no production, real-participant or paid-pilot use. Keep WELL-91 open, its internal review target of 2026-11-16, and the unchanged exclusive expiry `2026-11-18T00:00:00Z`. At or after that instant the exception is invalid. No extension is proposed.

Obtain a fresh affirmative JC decision accepting the exact `b0d5d125a42c0ea556631f609e42ac605537d463b9c0423defa21361124d4e64` digest and these bounded conditions before any rebinding. Record that new decision in WELL-91. Only a subsequently authorized change may update the existing approval pointer/digest and matching positive and negative expectations in the three binding files. Preserve superseded approvals/digests as rejection cases, the unsuppressed finding, pinned isolated scanner, expiry and every rejection control. Required fresh audit, Smoke regressions, engineering gates, exact-head CI and independent review must follow any authorized binding change.

Invalidate this technical disposition immediately for any covered source/configuration/toolchain/dependency/reachability-test change; any Apple/OAuth strategy, callback, direct Assent caller or provider-linking change; new advisory evidence or additional findings; a new compatible stable remediation or changed stable compatibility evidence; scope/exposure expansion; or expiry. A later source or migration change also requires review of the changed exact head before reuse. Reassess changed inputs independently and obtain a new owner decision where the accepted inputs or risk change. This document itself neither changes the binding nor closes WELL-91.

## Author follow-up on the P2 proof finding

The author corrected the test at `7911ef675f1d4577cc55603567ad1c4a3e4e4e07`. The reversed case now uses the fixture's other privileged actor with a separate Session, target-scoped grant and recorded reviewer. Explicit assertions reject shared actor, Session, grant and reviewer identities. The two cases share candidate Accounts and their control evidence; the common synthetic grant approver is not part of either lock set. The test still observes distinct backend/transaction identities and PostgreSQL blocking, then proves one applied decision and one denial.

The author's focused run of all three contention modes passed after this correction. This is author verification of a test-only fix, not a new independent reviewer certification. No application, configuration, dependency, toolchain, authentication-reachability test or migration changed after the reviewed source. The canonical input digest remains `b0d5d125a42c0ea556631f609e42ac605537d463b9c0423defa21361124d4e64`. Final whole-suite and hosted evidence belongs in the PR and Plane, and independent Master Gate must review the final exact head. The owner-decision boundary and expiry above remain unchanged.
