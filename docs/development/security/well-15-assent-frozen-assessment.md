# WELL-15 frozen-source privileged-security assessment

## Disposition

Fresh independent HIGH / `privileged_security` pre-binding assessment, 2026-11-08. No remaining blocking code defect was identified in the inspected frozen implementation. The pre-binding findings concerning approval recovery, pair-scoped authority, owner-record consequences, stale-case rejection and legacy E1 preservation are addressed by the source and regression coverage described below. Runtime results are implementer evidence inspected by this reviewer, not independently rerun tests.

A narrow temporary Assent technical non-reachability disposition is supportable for accountable owner JC's consideration of these exact inputs. Assent 0.2.13 remains vulnerable. Technical supportability does not accept that residual risk for JC. No current owner acceptance, exception rebinding, scanner relaxation, standing exception, green security gate, production or real-participant use, Phase-9 authority, independent Master Gate certification or merge permission follows from this assessment. WELL-15 must remain Blocked and PR #205 must remain draft.

## Repository baseline and authority

- Worktree: `/home/jcschoeman96/projects/current/NewYou/.worktrees/well-15`.
- Branch: `feat/well-15-identity-reconciliation`.
- Frozen implementation: `b79b255b15408c62111a1a050315059e87ee0354`.
- Base and current main: `75185b44b535d0f6513dcab1922e06c35a48029a`. Local main, origin/main and a fresh `git ls-remote origin refs/heads/main` agree.
- Frozen base-to-source diff: 39 paths, including seven migrations and eight Resource snapshots. SHA-256 of `git diff --binary 75185b44b535d0f6513dcab1922e06c35a48029a...b79b255b15408c62111a1a050315059e87ee0354` is `3e5f7c81b30a9c9805f6f13d5fcd1cc288b2b530d86855f075ca2cd18b96c56c`.

The review began at the frozen implementation with three existing uncommitted documentation updates. Another process committed those updates during review as `72f60d6d50731cf0a4b151a70ee34b8c6b8aca30`. Independent comparison confirms that this successor changes only the handoff, old assessment and implementation plan. The reviewed application, configuration, dependencies, migrations, snapshots and tests remain identical to the frozen implementation. This reviewer did not create that commit or edit those documents. This assessment remains bound to the specified frozen source; it does not certify a later final PR head.

The reviewer read repository `AGENTS.md`, unslop, repository-reconnaissance, ticket-implement, code-change-verification and relevant Ash/Elixir review guidance. Current [documentation routing](../../README.md), [governance router](../../governance/CURRENT_GOVERNANCE_ROUTER.json) and [delivery router](../../delivery/CURRENT_DELIVERY_ROUTER.json) control over obsolete paths in the ticket. Applicable law includes Product sections 15.1A, 15.1B, 21J.9, 21J.11 and 21P, corresponding Decision authority, Architecture sections 5 and 6, Domain Map section 6.1, and the FP-001 boundary. The [Identity dossier](../../delivery/jit/identity/FP-001_IDENTITY_ACCESS_JIT_DOMAIN_DOSSIER_WORKING_v0.2.0.md), Reconciliation Case and F.9/F.10, and [Audit dossier](../../delivery/jit/audit-evidence/FP-001_AUDIT_EVIDENCE_JIT_DOMAIN_DOSSIER_WORKING_v0.1.0.md), selection matrix and E1/E2 contracts, supply the relevant execution semantics.

LOCKED requirements are Identity ownership, role/scope authority, verified control, no demographic automatic merge, current conflict/version checks, independently committed E1 before apply, atomic source outcome/E2 obligation, permanent PMR retirement, immutable original provenance and owner-mediated foreign consequences. The private Resource, two targeted grants, sorted locking and versioned approval invalidation are compliant JIT implementation choices. No upstream governance contradiction was identified. Durable governance is unchanged.

Live [WELL-15](https://app.plane.so/symphony-development/browse/WELL-15) was Blocked and [WELL-91](https://app.plane.so/symphony-development/browse/WELL-91) was Planning. The reviewer read their current descriptions and relevant comments, including WELL-15 owner sequencing `53a1051d-8250-4609-9fda-9f8ea8f0cc1f`, freeze evidence `b35d188a-ddb1-4d33-9e0e-8e4ccc5a7ddd`, WELL-91 sequencing/proposed standing regime `fd6a7364-604f-450d-a295-a96cb74eab56`, and old exact-input acceptance `db89b442-f288-4f94-9fef-c89512544e74`. The latter accepts WELL-14 inputs only. The standing regime remains separate and unapproved. The present exact-input gate remains authoritative.

## Exact security inputs

The reviewer independently called [the unchanged scanner's `input_digest`](../../../tools/hex_security_audit.py) with Python bytecode writes disabled, then separately reproduced its SHA-256 calculation over sorted relative paths, NUL delimiters and file bytes. There are 96 inputs: `mix.exs`, `mix.lock`, `.tool-versions`, the authentication reachability test, and every file under `lib/` and `config/`. Every selected file matched the frozen source bytes.

Current independently verified digest:

`f76c43fa627e0fd11cd3e7c849144612433b0b7b552d2a577498670d110c0ebb`

The unchanged [exception metadata](../../../tools/hex_audit/assent_exception.json), scanner constants and approval regressions bind `63a6baf0a290195303bd3357f496b1dbcbe5ee3ce6057cd0a524085fbfef5005`. That old approval cannot authorize this digest. Former proposed digest `b0d5d125a42c0ea556631f609e42ac605537d463b9c0423defa21361124d4e64` was unapproved and also cannot authorize current inputs. The [old WELL-15 assessment](well-15-assent-assessment.md) is historical evidence for its recorded earlier source.

Migrations, ordinary tests, Resource snapshots and assessment documents are outside the scanner selector. Their security/correctness review is therefore tied to the recorded source and complete diff, independently of the input digest. Digest equality does not certify a later changed migration or final PR head.

## Advisory and stable compatibility

The reviewer freshly consulted the [maintainer advisory](https://github.com/pow-auth/assent/security/advisories/GHSA-9fr5-g44g-9526) and [EEF advisory through OSV](https://osv.dev/vulnerability/EEF-CVE-2026-117656). Assent versions at least 0.1.25 and below 0.3.2 are affected. Apple callback data can replace verified identity claims and permit impersonation when applications trust the returned identity. Version 0.3.2 is patched. The aliases are `EEF-CVE-2026-117656`, `CVE-2026-117656` and `GHSA-9fr5-g44g-9526`. Official upstream severity is critical, CVSS 9.3. The inspected pinned Hex SARIF reports 9.5 metadata; this review does not alter the scanner's evidence expectations.

Fresh queries to the official [AshAuthentication package API](https://hex.pm/api/packages/ash_authentication), [Assent package API](https://hex.pm/api/packages/assent) and [4.15.1 release API](https://hex.pm/api/packages/ash_authentication/releases/4.15.1) confirmed stable AshAuthentication 4.15.1, prerelease 5.0.0-rc.17, stable Assent 0.4.0 and latest supported 0.2-series Assent 0.2.13. The [published 4.15.1 dependency requirement](https://hex.pm/packages/ash_authentication/4.15.1/dependencies) is `> 0.2.0 and < 0.3.0`. Installed dependency source and the lock agree. It excludes patched Assent 0.3.2 and 0.4.0. No compatible stable remediation was established. A forced override or prerelease adoption is not authorized by this assessment.

Installed `deps/assent/lib/assent/strategies/apple.ex` contains the vulnerable callback and `Map.merge(user, user_info)` behavior. The dependency remains present and executable if future application code reaches it. Non-reachability is the sole technical basis for the bounded disposition.

## Authentication reachability

The reviewer inspected the full production source/configuration inventory, [Account authentication DSL](../../../lib/new_you/identity/account.ex), [router](../../../lib/new_you_web/router.ex), explicit Identity authentication paths and [reachability regression](../../../test/new_you_web/security/authentication_reachability_test.exs). Only the password strategy is configured. Generated registration, password sign-in and sign-in-token routes are disabled; authentication add-ons are absent. The explicit magic-login implementation does not use Assent.

Source searches found no application Assent caller, Apple/OAuth strategy or callback route, provider identity mapping or provider-account linking implementation. Generic callback variables are local function callbacks. Reconciliation connects existing internal Accounts only after Identity authority/control checks; it consumes no provider claims. No reconciliation HTTP route was added. The guard enumerates the sole authentication Resource, complete Account action inventory and all 12 existing routes, and checks that both new Account actions are private. No deployed-environment or independently rerun runtime-reachability certification is claimed.

## Pre-binding code findings

### Approval expiry and stale-case closure

[Reconciliation](../../../lib/new_you/identity/reconciliation.ex) permits an approved case to return to review or become rejected under current authority for both Accounts. Both transitions clear the current approval and append its full restricted `superseded_review` to history. The [approval-recovery migration](../../../priv/repo/migrations/20261108170000_well15_approval_recovery.exs) requires that preservation and the next version. Re-review requires fresh controls and owner checks. Old expected versions cannot apply or reopen the discarded decision. Applied and rejected records remain terminal.

Rejection deliberately bypasses candidate eligibility, allowing an overlapping losing case to close after another decision has retired one candidate. It still requires current privileged pair authority and case version. This changes case provenance only. It does not apply the stale reconciliation. Current control freshness uses `DateTime.diff/3` in microseconds with the inclusive interval `0..300_000_000`; evidence older by one microsecond fails closed.

[Focused regressions](../../../test/new_you/identity/reconciliation_test.exs) cover stale retries without E1, fresh-BEAM re-review recovery, fresh approval/apply, stale-version denial, superseded evidence, terminal rejection, exact freshness boundaries and rejection after the reversed overlapping case loses. These address the original recovery finding and subsequent stale-case correction. No unresolved lifecycle blocker was identified in this scope.

### Both Account grants, reviewer authority and replay

Opening, reviewing and applying require `grant_id` and `canonical_grant_id`. `authority/3` validates each through the existing [PrivilegedAccess](../../../lib/new_you/identity/privileged_access.ex) boundary against its respective Account. Both must be active, unrevoked, within time bounds, independently approved, assigned to the current actor and permit the governed Support capability. Purpose-bound MFA, current bearer/token/Session and eligible actor checks remain required. The actor cannot be either candidate.

Approval records both grant IDs/versions and reviewer security/MFA versions. `current_reviewer/2` rechecks the recorded reviewer's current Account/security/MFA state and both recorded grants against their subject, target, version, time and review capability. Candidate Account security/reconciliation versions and current control Sessions/token presence/revocation also gate apply. These are current checks, not permission inferred from a case record.

Preflight commits before [Audit admission](../../../lib/new_you/audit/privileged_evidence.ex). E1 binds case, attempt, actor, candidate, both grants/versions, Session, expected version and reason. The source transaction reconstructs current authority and compares that binding again. An applied same-operation replay must match the stored binding and current privileged authority. It returns existing truth without rerunning retired-account controls or effects. A different actor, Session, grant/version, case, expected version or operation cannot borrow that result through this interface.

Regressions reject missing/wrong/single-target grants before admission, verify both fields in E1, and revoke either grant between E1 and source apply. The latter leaves E1 plus a failed linked outcome and no retirement. Source review found no remaining single-target or stale recorded-reviewer authority bypass. There is no new production grant-issuance path; synthetic provisioning remains limited to development/test compilation.

### Lock order and overlapping decisions

The Account union includes actor, both candidates and recorded reviewer, deduplicated and ordered by UUID before dependent locks. Requested grants lock in sorted ID order. The inherited authorization helper re-locks Accounts already held, then checks token, Session and grant. Case and recorded-reviewer/control checks follow. [Grant revocation](../../../lib/new_you/identity/changes/invalidate_grant_assurance.ex) takes its subject Account before Session/grant mutation, so it cannot reverse the protected Account boundary. Account version changes invalidate stale overlapping reviews.

The reversed-case test now has distinct privileged actors, Sessions, pair grants and recorded reviewers. Shared grant approver identity is not in either lock set. It proves separate backend/transaction identities, observes PostgreSQL blocking, then checks one apply, one denial and successful stale-case rejection. This resolves the old shared-actor proof weakness. Same-attempt replay, distinct attempts and PMR allocation during retirement have separate tests. Static review found no new lock-order inversion in these paths; supplied execution logs are the runtime evidence.

### Immutable legacy E1 and migrations

The reviewer inspected all seven migration up/down bodies and all eight generated snapshots against the Resource changes. The [pair-scope migration](../../../priv/repo/migrations/20261108170100_well15_pair_scope.exs) adds canonical grant ID/version and replaces the assertion-shape check with `validate: false`. It neither rewrites nor deletes existing E1. Installed Ecto SQL emits `NOT VALID` for this option. [PostgreSQL documents](https://www.postgresql.org/docs/current/sql-altertable.html) that this skips validation of existing rows while enforcing subsequent inserts/updates. The full new reconciliation pair is mandatory; non-reconciliation assertions must not carry those fields.

Immutable legacy admissions remain historical evidence. Their missing pair fields cannot equal the new complete admission or replay binding. The focused regression reads the installed constraint, confirms its unvalidated state, retains a legacy-shaped row in an isolated temporary table and rejects a new incomplete insert using the same expression. It proves the constraint semantics, not an independently executed populated production migration. The implementer separately reports guarded local rollback/reapply. Rollback refuses to discard populated pair-scope evidence; approval-recovery rollback deliberately requires governed disposition.

The other migrations preserve candidate/canonical/provenance references, operation uniqueness, legal versioned transitions, terminal and append-only history, DELETE/TRUNCATE protection, permanent retired-PMR state and E1/result linkage. No legacy-row preservation or strict-new-write blocker remains in the inspected design. Database-owner trigger disabling remains outside those ordinary-write guarantees.

### Owner records, PMR and failure recovery

[Communications](../../../lib/new_you/communications.ex) and [Audit](../../../lib/new_you/audit.ex) expose fixed preservation policies. Their documentation now explicitly says they do not inspect individual records. This is supportable for the current implemented verification/magic-login intents and append-only Audit histories. The owner-record regression creates real intents for both Accounts and real materialized registration evidence, preserves original source/destination/provenance associations, and exercises retired-source closure/retry without a provider attempt. It first proves the losing magic-login source eligible before apply. Pending verification records on already verified candidates can already be ineligible; that part proves preservation and fail-closed execution, not eligibility caused solely by retirement.

The existing [Communications executor](../../../lib/new_you/communications/executor.ex), [verification eligibility](../../../lib/new_you/identity/delivery_eligibility.ex) and magic-login eligibility ask Identity for current source authority. Identity does not rewrite foreign records. A changed configured Domain inventory blocks approval/apply. These policies provide no review for future commerce, health, professional or other unimplemented records, and no claim that provider work already admitted before retirement can be recalled.

Source apply atomically revokes active losing Sessions, closes that Account terminally, revokes its credential status, retires its unchanged PMR, advances canonical reconciliation version, records the case/binding and establishes linked E2 work. Existing permanent PMR reservations prevent reassignment. Retained user-token rows cannot bypass current Session/Account guards. DeviceAssurance and trusted-device authentication are absent from the implemented runtime, so no device-revocation implementation is claimed. Compensation links a new reviewed decision and preserves old Accounts, retired values and foreign provenance; it does not restore a terminal Account.

E1 is independently durable before source mutation. Caught source failure rolls back Identity and attempts a separately committed failed E2 result; that operation cannot later become a success. If failure evidence also cannot commit, the admission has an unresolved outcome and proves no apply. Process-death and fresh-BEAM tests exercise recovery around E1/source commit and subsequent evidence materialization. Audit recovery never replays Identity. Review/history fields are private and sensitive; envelopes retain bounded references and outcomes, without bearer credentials, passwords, TOTP secrets or foreign payloads.

## Verification evidence and limits

This reviewer ran source/ref/diff inspections, independent digest calculations, frozen-byte comparisons, fresh official-source queries and read-only GitHub/Plane checks. The unchanged scanner's disposition function was independently executed against the saved Hex SARIF and current metadata; it rejected the stale binding with the expected changed-input error. This re-evaluates saved evidence and does not constitute a fresh audit. `git diff --check` passed for the frozen base/source diff and the then-current working changes. The reviewer did not run application commands, database tests, migrations, DevCore activation or a new audit. No concurrent DB test run occurred in this review.

The following existing implementer logs were independently opened and inspected. Their contents were observed; their process exit status and exact-source provenance were reported by the parent and are not independently attested by these files alone.

- `/tmp/well15-frozen-check.log` ends with `Result: 574 passed`. It also reports the architecture boundary passing and Credo without findings, and contains the Sobelow run.
- `/tmp/well15-frozen-deep.log` ends with zero errors and successful completion.
- `/tmp/well15-frozen-codegen.log` records the codegen check invocation output without an error. Its successful exit is parent-reported.
- `/tmp/well15-final-focused.log` ends with 31 passing tests.
- `/tmp/well15-hardening-smoke.json` has status PASS, 64 assertions and no findings. This current-router result does not make the complete Foundation Smoke lane green.
- `/tmp/well15-frozen-hex-audit.log` contains pinned Hex 2.6.0 SARIF with exactly one unsuppressed Assent 0.2.13 finding, followed by changed-input exception invalidation. It is a failing security gate.
- `/tmp/well15-frozen-hex-regressions.log` reports 28 tests, 11 failures and four errors at the stale digest. These are failures, not waived or passing regressions.

The 75 supporting Python checks and guarded migration rollback/reapply are parent-reported. This reviewer did not independently execute them or inspect a dedicated complete log for them. Earlier development failures are not overwritten by later reported passing runs.

Read-only `gh pr view 205` showed [PR #205](https://github.com/JCSchoeman96/NewYou/pull/205) OPEN and draft, hosted head `ae7484e90286062475657e9b9010b449b84fcec4`, against the specified main. [Run 42496019448](https://github.com/JCSchoeman96/NewYou/actions/runs/42496019448) has successful application fast/deep lanes but failed Foundation Smoke, Hex audit and Foundation Integrity, with Full skipped. Those hosted results cover the older PR head, not frozen hardening source `b79b255` or the later documentation head. Exact-final-head hosted certification remains outstanding.

The handoff updates were checked against source as descriptive evidence. This assessment is not full Master Gate certification or a merge recommendation. A later head change requires exact-head reconciliation even if the canonical digest remains unchanged.

## Residual risk, blockers and decision needed

The retained critical dependency and future authentication/configuration drift remain the principal advisory risk. This disposition is limited to bounded Phase-8 development/test. Production, real-participant, public-release and paid-pilot use remain prohibited. WELL-91 stays open, with its existing revalidation target of 2026-11-16 and unchanged exclusive expiry `2026-11-18T00:00:00Z`. At or after that instant the disposition is invalid. No extension is proposed.

No additional blocking code defect was identified in the reviewed scope. Delivery remains blocked by missing accountable-owner acceptance of the current exact digest, stale approval binding and failing security gates, absent exact-final-head CI, and outstanding independent Master Gate. These are execution/security decision boundaries, not a demonstrated upstream governance contradiction.

The next accountable decision belongs to JC through WELL-91: whether to accept this exact digest and bounded residual risk, or require remediation instead. This review records no such acceptance and requests no approval. Only a separately authorized binding change may follow an affirmative exact-input decision. It must preserve unsuppressed scanning, pinned isolation, all rejection controls, superseded-input rejection, current expiry and remediation tracking. Required audit/regression/Smoke/engineering checks and exact-final-head independent Master Gate must then assess the actual candidate before any separate merge decision.

Immediately invalidate this technical assessment for changed covered inputs; Apple/OAuth strategies, callbacks, direct Assent use or provider linking; changed advisory evidence or additional findings; a new stable compatible remediation or changed compatibility facts; exposure/scope expansion; or expiry. Source, migration or proof changes outside the selector still require review before this assessment can support a later candidate. The proposed WELL-91 standing-risk redesign cannot replace the current exact-input control without its own separately approved and reviewed security-control change.

This reviewer wrote only this new assessment. No source, tests, old assessment, bindings, scanner, metadata, expiry, governance, Plane, PR, branch or commit was changed by the reviewer. No push, merge, watch or delegated agent was used.
