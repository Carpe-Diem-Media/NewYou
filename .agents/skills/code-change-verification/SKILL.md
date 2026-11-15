---
name: code-change-verification
description: Use before handoff or any merge recommendation for a NewYou change. Covers exact diff/head, Mise-pinned local checks, pre-handoff independent OCR evidence for material engineering changes, architecture invariants, Plane reconciliation, exact-head CI and a clean worktree.
---

# NewYou Change Verification

Do not claim success without evidence from this exact head.

1. **Review the exact diff.** Run `git diff --stat origin/main...HEAD` and read the full diff. Confirm every changed path is in ticket scope.
2. **Record the exact head SHA** with `git rev-parse HEAD`. All evidence below must refer to this SHA.
3. **Record the local toolchain.** Capture `mise current` and `mise exec -- elixir --version` so the resolved Erlang/OTP and Elixir versions are tied to the repository pin.
4. **Apply the canonical scope policy.** Follow `AGENTS.md` "Verification stages and failure diagnosis". For a stable application or executable engineering candidate, run `mise exec -- devcore-project run test -- mix check`. It must pass. For proven non-executable documentation, inspect actual consumers and the complete diff, run applicable instruction/document/router/knowledge/provenance checks, and record why the application suite is not applicable. Markdown alone is insufficient justification. Diagnose broad failures before another broad run.
5. **Run applicable targeted tests** for the changed behaviour with `mise exec -- devcore-project run test -- mix test <target>`.
6. **Run the deep gate where required:** `mise exec -- devcore-project run test -- mix check.deep`. Required for changes touching application code, dependencies or the architecture rules.
7. **Confirm architecture and lifecycle invariants.** A passing complete `mix check` on the same applicable inputs satisfies the included architecture obligation. Retain `mise exec -- devcore-project run test -- mix check.architecture` for focused development or independent diagnostics; do not demand a duplicate final invocation. Confirm no new Repo, raw-SQL or Multi business writes; no Redis, extra Repo or speculative infrastructure; Tidewave remains DEV-only.
8. **Confirm the CI-sensitive scope.** Foundation Full runs only through nightly hardening and is not selected by PR paths. Every PR runs Foundation Smoke; classified application/engineering changes also run their routed Application CI and Hex audit lanes. Unknown or unreadable ranges fail routing. Explain any routing-sensitive changes against the ticket.
9. **Reconcile Plane.** Confirm the issue state, blockers, dependency relations and follow-ups. Nothing delivery-affecting may remain only in chat, PR comments or TODOs.
10. **Bind the local candidate and run OCR.** Commit the locally verified implementation and confirm a clean worktree. Run the local checkpoint below before the first PR push wherever practical. Neither a PR nor successful CI is a prerequisite for OCR. Any applicable local failure stops OCR and handoff.
11. **Preserve PR/history and require final hosted CI.** After OCR, follow authenticated Draft PR creation/update and generated history in `ticket-implement`. Required `Foundation Integrity`, `Foundation Smoke` and every applicable routed Application CI/Hex lane must succeed for the exact final head and current base. Pending, fail, cancel, skipped, missing, stale or ambiguous required evidence stops final handoff. The gate reuses read-only `tools.ci_attestation.collect` to verify the latest run, candidate parents, job checkouts and live protection. It does not request approval or change the ruleset.
12. **Finish the evidence.** Verify knowledge/history, valid OCR reuse if applicable, and a clean final worktree. Report exact local commands/outcomes, resolved Elixir/OTP versions, Plane state, OCR-scanned implementation SHA, final base/head, CI run/checks, findings/dispositions, exclusions and risks. Only then may the PR become ready for independent Master Gate. Do not self-approve, merge or mark Done.

## Independent OCR checkpoint (material engineering PRs)

The mandatory order is local verification → local OCR → exact-head hosted CI → independent Master Gate. Use the actual worktree and committed local HEAD, with a clean `git status --short`. Refresh `origin/main` before local proof. The gate verifies that remote main still matches the comparison base. Base drift invalidates affected evidence. Normal pre-push scanning needs neither a branch name nor a PR number, including detached HEAD and unpushed commits.

```bash
git fetch origin main
mise current
mise exec -- elixir --version
python3 .agents/skills/code-change-verification/scripts/handoff.py discover
python3 .agents/skills/code-change-verification/scripts/handoff.py local --focused 'python3 -m unittest tests.test_agent_handoff -v'
python3 .agents/skills/code-change-verification/scripts/handoff.py preview --budget 100000
python3 .agents/skills/code-change-verification/scripts/handoff.py ocr
```

Replace the focused test with the actual ticket-scoped tests. This helper implements the material engineering path. Proven non-executable documentation may use its applicable instruction/router/knowledge checks and reasoned OCR exemption under `AGENTS.md`; do not invent a full application gate solely for Markdown.

The `local` command runs focused argv without a shell and then `mise exec -- devcore-project run test -- mix check`. It adds `mise exec -- devcore-project run test -- mix check.deep` for application/dependency changes selected by the current router, or when `--deep` is supplied for other applicable scope. Apply `AGENTS.md` DevCore doctor/recovery first. Every local failure invalidates the old receipt. Diagnose it before retrying. Receipts/logs are private to this worktree's Git directory and must not be uploaded wholesale.

Inspect the zero-token preview before running `ocr`. Discovery and selection never spend subscription tokens. `preview` and `ocr` check local proof and comparison-base freshness; they do not query a PR or wait for CI. The paid command uses frozen merge-base and local implementation SHAs, equivalent to `ocr review --from origin/main --to HEAD` on the verified range, with explicit `--provider chatgpt --effort low --concurrency 1 --max-tokens-budget 100000 --format json --audience agent`. It runs only on the local developer machine using the developer's protected ChatGPT plan store. No subscription credentials or requests may enter GitHub Actions/shared CI. An unavailable plan blocks the run; no API-key fallback.

The positive configurable budget is a **soft** aggregate input/output limit. OCR checks it between requests, so an in-flight request or grace round can exceed it. Never treat it as a billing cap. Do not automatically increase it, retry/resume paid runs or exclude source to hide a failure. Each paid attempt keeps separate private result/log files. A repeat on the same local receipt requires `ocr --retry-reason TEXT`; document the cause, changed inputs or budget decision. The helper never retries or resumes a paid run automatically. Use `preview --budget N --exclude 'pattern'` only with a specific recorded reason and manual review obligation. Generated `docs/development/knowledge/history/pr-*.json` records are explicitly excluded from OCR and validated by knowledge capture and full-diff review. Every changed path must appear in preview and result coverage. No eligible files means blocked/manual exemption, never a clean OCR pass.

The gate parses JSON, not just the exit code. It requires `status=complete`, `ocr.run-manifest/v1`, exact resolved head/merge-base/range, a fresh session, preview/result selection equality and completed coverage for every selected file. Failed, waived, reused, missing or unknown selected coverage, warnings, unresolved tool/request failures and exhausted or unknown budget block the OCR checkpoint. A zero-exit partial result still fails. Supported OCR schema was checked against v1.13.10 commit `7e5ce06`; unknown versions fail closed until validated.

Investigate every finding. Do not automatically accept suggestions, silently fix or dismiss them, or self-certify their disposition. Deliberately repair genuine defects with permanent regression proof, then rerun affected local checks and OCR on the new committed implementation before the next push wherever practical. Preserve unresolved findings and proposed assessments for independent review. Credible urgent security/privacy/data-integrity exposure requires prompt escalation with the PR Draft/Blocked, plus only necessary immediate containment. Incomplete OCR or unresolved material findings cannot support a green review-ready claim.

After OCR, continue authenticated PR creation/update and generated PR history. Push the final candidate and wait for required exact-head hosted CI. A genuinely mechanical PR-history-only commit may reuse application/OCR evidence only if every intervening commit changes only this PR's generated history, the complete tree comparison proves all implementation bytes/modes unchanged, comparison base is identical, a fresh zero-token preview proves unchanged material selection/exclusions, and canonical history validation passes. Any changed source, base, newly eligible file, stale coverage or new warning requires fresh affected local/OCR proof. Record scanned implementation SHA and final PR head separately. Every changed final head requires fresh CI/review.

```bash
python3 .agents/skills/code-change-verification/scripts/handoff.py discover-pr
python3 .agents/skills/code-change-verification/scripts/handoff.py finish --ticket WELL-N
```

`discover-pr` prefers branch-associated `gh pr view` and then exact local-SHA/remote-head association, including detached or mismatched contexts. It rejects absent, closed, ambiguous and stale associations without spending subscription tokens. Optional `--pr NUMBER` resolves an investigated ambiguity but never bypasses SHA checks. T3Code UI-attached metadata is never used. A remote mismatch blocks final PR evidence, not a clearly labelled locally verified candidate scan.

Preserve an `OCR Review Findings` section in the PR with the command, scanned implementation SHA/range, final base/head, model, effort/concurrency, budget/usage, manifest/session, all findings with severity/path/line, every excluded path/reason, errors, limitations and proposed assessments. Redact sensitive material before publishing. Excluded files and generated history remain subject to independent full-diff review. `finish` produces an evidence summary labelled "awaiting independent Master Gate"; it never creates approval, merges or changes Plane state.

Unresolved material findings keep the PR Draft for independent triage. `finish --disposition-review ID` may read an existing authenticated JCSchoeman96 review for this final PR/head. Each accepted disposition line has the form `OCR SESSION finding N: NON-BLOCKING. Reason` or `OCR SESSION finding N: FALSE POSITIVE. Reason`. Finding numbers are one-based result order. Author waivers, dismissed/stale reviews, `CONFIRMED BLOCKER` and unresolved `NEEDS EVIDENCE` cannot pass. This uses existing review evidence, not a duplicate approval record. Master Gate independently reviews the actual final diff, authority, lifecycles, local/OCR evidence and exact-head CI and decides finding dispositions. Final certification remains independent.

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

At the review checkpoint, compare PR history using `mise exec -- python3 -m tools.knowledge_capture check --metadata-json /tmp/PR-metadata.json`. Check uses the stable ticket identifiers in the committed record; if `--ticket` is supplied, it must agree. Foundation Integrity runs the same check against the exact event head/base. Verify generated history, semantic maps and current-tree index serve distinct purposes. Do not regenerate for prose, author or Plane-state changes, and do not commit generated changes after final approval.

A mechanical history-only commit does not invalidate passing application evidence when the complete diff confirms identical verified application inputs. Record the tested implementation SHA and final PR head separately. Put this commit after local OCR and before final history validation and exact-head hosted CI. Reuse OCR only after independently proving unchanged scanned inputs, base and selection. Source/base changes require regeneration and refreshed affected proof. OCR remains advisory evidence and never replaces CI or independent Master Gate.

Before a routine PR update, follow the actual `JC-Agents` authentication and existing-author preflight in `AGENTS.md` and `ticket-implement`. A founder-authored PR is ineligible for the routine agent/founder approval route.
