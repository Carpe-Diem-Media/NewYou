---
name: code-change-verification
description: Use before handoff or any merge recommendation for a NewYou change. Covers exact diff/head, Mise-pinned local checks, optional advisory OCR evidence, architecture invariants, Plane reconciliation, exact-head CI and a clean worktree.
---

# NewYou Change Verification

Do not claim success without evidence from this exact head.

## Verification ownership

This skill is the single owner of applicable final engineering verification and handoff under `AGENTS.md`. TDD owns focused RED/GREEN/REFACTOR technique; `ticket-implement` coordinates implementation and candidate preparation. The independent Master Gate independently certifies the complete final diff, authority, actual tests and exact-head CI.

Preserve local verification → optional OCR → required exact-head hosted CI → required independent Master Gate. Use the existing `.agents/skills/code-change-verification/scripts/handoff.py` executor where installed and applicable, following its current authorised procedure. Its material-engineering `local` stage executes focused proof and broad gates. Do not manually run broad gates before invoking that stage, and do not invoke its `local` stage twice for an unchanged candidate without a recorded diagnostic reason. If the helper is not installed, follow the existing `AGENTS.md` checks below; do not import a proposed helper from another branch. Proven non-executable documentation retains the scoped route and optional OCR procedure below.

Do not automatically rerun already-valid focused proof or broad gates merely because another skill was loaded. Evidence reuse requires unchanged relevant source, exact inputs, environment, scope and comparison base, and must satisfy the authorised executor's validation. Iterative development tests and final committed-candidate proof are different obligations; the helper's required focused run is not automatically redundant. Do not add receipt caching, arbitrary evidence adoption or a second runner. Changed inputs invalidate affected proof; changed final heads require fresh exact-head CI and independent review. Preserve every applicable final gate.

## Local command selection

Follow [the canonical managed-slots guide](../../../docs/development/managed-local-slots.md).
For opted-in worktrees, focused Mix tests and broad gates use
`mise exec -- tools/newyou-local test -- mix <task>`. Inside an existing managed
job, use `mise exec -- devcore-project run test -- mix <task>` so DevCore verifies
and reuses its assigned environment. Non-opt-in worktrees keep the legacy command
and shared TEST/PLT coordination. The examples below show that legacy syntax;
the helper normalizes either supported focused syntax to the selected mode.
Disabled admission or unverified managed context must stop without fallback.
Installation of 1.2.1 is recorded; operational activation remains pending.
The helper still owns focused proof and all applicable broad gates.

## Final candidate checks

1. **Review the exact diff.** Run `git diff --stat origin/main...HEAD` and read the full diff. Confirm every changed path is in ticket scope.
2. **Record the exact head SHA** with `git rev-parse HEAD`. All evidence below must refer to this SHA.
3. **Record the local toolchain.** Capture `mise current` and `mise exec -- elixir --version` so the resolved Erlang/OTP and Elixir versions are tied to the repository pin.
4. **Apply the canonical scope policy.** Follow `AGENTS.md` "Verification stages and failure diagnosis". For a stable application or executable engineering candidate, require a passing `mise exec -- devcore-project run test -- mix check` through the selected executor once. For proven non-executable documentation, inspect actual consumers and the complete diff, run applicable instruction/document/router/knowledge/provenance checks, and record why the application suite is not applicable. Markdown alone is insufficient justification. Diagnose broad failures before another broad run.
5. **Verify applicable focused evidence** for the changed behaviour, such as `mise exec -- devcore-project run test -- mix test <target>`, under the validity and executor rules above. Refresh invalidated proof without automatically repeating valid checks.
6. **Require the deep gate where applicable:** `mise exec -- devcore-project run test -- mix check.deep` through the same executor. Required for changes touching application code, dependencies or the architecture rules. Do not execute it separately when the helper owns that obligation.
7. **Confirm architecture and lifecycle invariants.** A passing complete `mix check` on the same applicable inputs satisfies the included architecture obligation. Retain `mise exec -- devcore-project run test -- mix check.architecture` for focused development or independent diagnostics; do not demand a duplicate final invocation. Confirm no new Repo, raw-SQL or Multi business writes; no Redis, extra Repo or speculative infrastructure; Tidewave remains DEV-only.
8. **Confirm the CI-sensitive scope.** Foundation Full runs only through nightly hardening and is not selected by PR paths. Every PR runs Foundation Smoke; classified application/engineering changes also run their routed Application CI and Hex audit lanes. Unknown or unreadable ranges fail routing. Explain any routing-sensitive changes against the ticket.
9. **Reconcile Plane.** Confirm the issue state, blockers, dependency relations and follow-ups. Nothing delivery-affecting may remain only in chat, PR comments or TODOs.
10. **Bind the local candidate.** Commit the implementation and verify a clean worktree. Local verification is mandatory. OCR may be selected after local proof, but is not required for review-ready handoff.
11. **Require final hosted CI.** Keep the PR Draft while mandatory checks are pending or blocked. Required `Foundation Integrity`, `Foundation Smoke` and every applicable routed Application CI/Hex lane must succeed for the exact final head and current base. Pending, failed, cancelled, skipped, missing, stale or ambiguous evidence blocks handoff. The gate reuses `tools.ci_attestation.collect` to check candidate parents, job checkouts and live protection.
12. **Finish the evidence.** Verify applicable semantic knowledge and a clean worktree. Report local commands, toolchain, Plane state, exact final base/head, CI, OCR status and limitations. The result awaits independent Master Gate. Do not self-approve, merge or mark Done.

## Independent implementation and proof assessment

Inspect the complete implementation diff and affected consumers against current authority, rather than accepting the implementation plan as proof. Evaluate material JIT fitness decisions, justified introductions/replacements, pinned framework return types and DSL compatibility, single Domain ownership and supported owning Ash interfaces. Check module cohesion and avoid forwarding abstractions without a distinct responsibility.

For meaningful lifecycles, inspect states, transitions, guards, terminal states and durable consequences. Review valid fixture prerequisites and permitted controls: negative tests must reject for the intended guard, not an unrelated invalid prerequisite. Assess selected isolated sensitivity proof, including restoration and focused rerun evidence, under the TDD skill. Evaluate applicable concurrency, idempotency, retry, failure, rollback and recovery proof using Engineering Standards' LOW / STANDARD / HIGH policy, without universal mutation testing or numeric coverage thresholds.

Inspect persistence, migrations, constraints, authorization and security/privacy boundaries where relevant. Identify affected contract tests, action allowlists, proof catalogs, security scans, consumer interfaces and capability knowledge maps. Verify browser/subprocess prerequisites exist in hosted CI. These focused consumer checks do not create another unconditional full-suite run. Record proof gaps and justified non-applicable obligations in the existing ticket/PR handoff.

## Optional OCR advisory review

OCR is optional and is not required for ordinary handoff. `NOT_RUN` means no scan, not `PASS`. Partial, failed, unavailable, timed-out or budget-limited attempts remain partial or failed; their absence or failure does not independently block the non-OCR gates. Full-diff independent Master Gate covers every changed file.

Use a clean committed candidate and refresh `origin/main`. The helper's `local` stage owns focused proof and the canonical broad gate. After local proof, an explicitly selected OCR run may use:

```bash
python3 .agents/skills/code-change-verification/scripts/handoff.py preview --budget 100000
python3 .agents/skills/code-change-verification/scripts/handoff.py ocr
```

The `local` command requires a repository test target through `python3 -m unittest tests.test_NAME` or `mise exec -- devcore-project run test -- mix test test/PATH_test.exs`. Focused Python commands allow explicit `tests.test_NAME` targets with optional `-v`/`--verbose` or `-q`/`--quiet`; discovery, filters and external targets are rejected. Focused Mix commands accept only existing files within this worktree's `test/` tree, with optional `:LINE` suffixes; external/symlink escapes and flags such as `--dry-run` are rejected. It rejects no-op/arbitrary commands and a zero-test report even when the process exits zero. `git diff --check` and `python3 -m tools.capability_knowledge` are supported supplemental checks and cannot replace focused tests. It runs argv without a shell, applies the command selection above, and then `mise exec -- devcore-project run test -- mix check`. It adds `mise exec -- devcore-project run test -- mix check.deep` for application/dependency changes selected by the current router, or when `--deep` is supplied for other applicable scope. Apply `AGENTS.md` DevCore doctor/recovery first. Every local failure invalidates the old receipt. Diagnose it before retrying. Receipts/logs are private to this worktree's Git directory and must not be uploaded wholesale.

Inspect the zero-token preview first. OCR reviews the resolved merge-base and head, equivalent to `ocr review --from origin/main --to HEAD`, and uses `--provider chatgpt --model gpt-6-luna --effort low --concurrency 1 --max-tokens-budget 100000`. Low is one review round; model reasoning effort is separately preferred at medium. Configure `providers.chatgpt.extra_body` locally with `{"reasoning":{"effort":"medium"}}`, preserving existing provider fields. Never put credentials in Git, logs or CI. Do not use API-key fallback or another provider when the model is unavailable. Do not automatically retry or increase a budget. A deliberate paid retry requires `ocr --retry-reason TEXT` and documented cause; inspect every selection and exclusion before spending tokens. The budget is soft and in-flight requests can exceed it.

A complete claim requires `ocr.run-manifest/v1`, exact head and merge-base, a fresh session, matching preview selection, complete selected coverage, no failed/waived/reused files, warnings or exhausted budget. Exit zero alone proves nothing. A partial or malformed result must not be called complete. Disclose the actual model, reasoning configuration where verifiable, budget, usage, findings, exclusions and limitations. No eligible files means no OCR pass. Investigate credible findings and require independent disposition of material findings, including findings in partial results; never silently waive them. OCR is advisory, not implementation authority.

`finish --ticket WELL-N` requires successful local proof, a clean exact candidate, current PR association and required exact-head/current-base hosted CI. It reports `NOT_RUN` when OCR was not selected and preserves the actual status of optional attempts. `finish --disposition-review ID` may read an existing authenticated exact-head independent review for reported findings. Each disposition line must use `OCR SESSION finding N: NON-BLOCKING. Reason` or `OCR SESSION finding N: FALSE POSITIVE. Reason`; author waivers, dismissed or stale reviews, `CONFIRMED BLOCKER` and `NEEDS EVIDENCE` cannot satisfy it. The result remains awaiting independent Master Gate. A changed head invalidates affected proof and approval; base drift invalidates current-candidate evidence. Local OCR subscription traffic never enters CI. Full diff review covers excluded paths.

Python focused proof must include at least one passing test after subtracting skipped tests and expected failures. Unknown or zero coverage blocks the local receipt. Changed paths use `--no-renames` to preserve both sides for routing and coverage. OCR previews with missing paths cannot be called complete.

The helper validates explicit repository test commands, observed execution and source freshness. It cannot establish semantic relevance to a Plane ticket from a test name. Before `local`, the author must map the selected tests to the live acceptance criteria and inspect their assertions; independent Master Gate verifies that mapping. An unrelated passing test does not satisfy the focused-test obligation. Execution receipts do not certify acceptance coverage or approval.

The evidence directory must already be private to its owner, or be newly created with mode `0700`. An unsafe existing directory blocks before any writes. Files are created with mode `0600` before writing; unsafe existing files, symlinks and multiply linked output files are rejected without truncation. Resolve a reported permission problem deliberately before retrying; the helper does not silently change existing permissions.

## Implementation handoff review

Apply `docs/development/implementation-handoff-standard.md` prospectively after WELL-96 integration. Review the PR's documentation-impact determination. A substantial new slice requires a full source-linked map in the same PR; later material changes update the existing map, and proof-only changes update its proof section or a focused addendum. Exempt trivial/cosmetic/editorial changes with a concrete rationale. Do not retroactively block completed work or already-active WELL-7.

Independent Master Gate verifies required documentation against the exact reviewed head, including owner interfaces, lifecycle/failure behaviour, persistence constraints, executable tests and proof limits. Check the implementation SHA, all material locators and claims, and the cold-start walkthrough for a new substantial slice. Missing or materially inaccurate required documentation means `CHANGES REQUIRED` for that PR. A changed head invalidates prior certification. No separate routine after-merge documentation ticket or unrelated blocker is required.

Handoffs remain descriptive implementation maps beneath routed authority. They do not replace source inspection, exact-head checks, resulting-main reconciliation or Plane's live execution state.

## Review and merge handoff

Follow `docs/development/foundation-integrity-merge-gate.md`. For eligible development work, ChatGPT Master Gate completes the technical review and publishes one authenticated JCSchoeman96 APPROVED review for the exact final head. That review is both technical approval and standing merge authorization. Do not add a second founder comment or a base-SHA line. The implementing agent must not use founder credentials.

Verify current required CI and live branch protection before merge. From trusted integrated `main`, run `python3 -m tools.ci_attestation native-candidate --pr NUMBER --reviewed-head HEAD_SHA --run RUN_ID`. When it passes, use `gh pr merge --repo Carpe-Diem-Media/NewYou --merge --match-head-commit HEAD_SHA NUMBER` without bypass. Then run `python3 -m tools.ci_attestation native-result --pr NUMBER --reviewed-head HEAD_SHA --run RUN_ID --candidate TESTED_CANDIDATE_SHA`. If GitHub returns an uncertain merge result, inspect the PR and `main` before taking further action. Never blindly repeat the merge.

Apply stronger approval only when a governing or external obligation requires it. File paths, CI changes, agent instructions and governance edits do not by themselves mandate a strict route. Settings mutations still require separate owner authorization. PR #224 needs explicit owner authorization for its exact current-main transition after fresh complete review and CI; comment 6821263762 is collection-only, and the PR cannot self-approve or self-merge.

Run `python3 -m tools.capability_knowledge` and its focused tests when maps/schema change. Independently compare the canonical map with source, resources/actions, constraints, lifecycle and tests. Hashes and shape alone are insufficient semantic proof. Maintain the same map for material capability changes.

After merge, verify resulting main SHA, ordered parents and tested tree before Plane Done. The native-result check is read-only and stores no intent or evidence file. If its result is uncertain, inspect GitHub state and resolve the discrepancy before updating Plane.

CI generates informational mechanical PR snapshots without modifying the branch. Existing committed history remains searchable, but new records are not required. Verify semantic maps against the source and retain exact-head and current-base evidence.

Before a routine PR update, follow the actual `JC-Agents` authentication and existing-author preflight in `AGENTS.md` and `ticket-implement`. A founder-authored PR is ineligible for the routine agent/founder approval route.
