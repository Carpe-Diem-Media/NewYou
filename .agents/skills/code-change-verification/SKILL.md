---
name: code-change-verification
description: Use before handoff or any merge recommendation for a NewYou change. Covers exact diff review, exact head SHA, mix check, mix check.deep, architecture invariants, no accidental governance edits, Plane reconciliation, required CI state and a clean worktree.
---

# NewYou Change Verification

Do not claim success without evidence from this exact head.

1. **Review the exact diff.** Run `git diff --stat origin/main...HEAD` and read the full diff. Confirm every changed path is in ticket scope.
2. **Record the exact head SHA** with `git rev-parse HEAD`. All evidence below must refer to this SHA.
3. **Run the fast gate:** `devcore-project run test -- mix check`. It must pass.
4. **Run applicable targeted tests** for the changed behaviour.
5. **Run the deep gate where required:** `devcore-project run test -- mix check.deep`. Required for changes touching application code, dependencies or the architecture rules.
6. **Confirm architecture and lifecycle invariants:** `mix check.architecture` passes; no new Repo, raw-SQL or Multi business writes; no Redis, extra Repo or speculative infrastructure; Tidewave remains DEV-only.
7. **Confirm the CI-sensitive scope.** Foundation Full runs only through nightly hardening and is not selected by PR paths. Every PR runs Foundation Smoke; classified application/engineering changes also run their routed Application CI and Hex audit lanes. Unknown or unreadable ranges fail routing. Explain any routing-sensitive changes against the ticket.
8. **Reconcile Plane.** Confirm the issue state, blockers, dependency relations and follow-ups. Nothing delivery-affecting may remain only in chat, PR comments or TODOs.
9. **Confirm required CI state** on the PR head SHA: required `Foundation Integrity` and any routed Application CI lanes are green for this SHA. Follow `docs/development/foundation-integrity-merge-gate.md`. Foundation Full is deferred to nightly hardening and is not part of PR certification.
10. **Confirm a clean worktree** with `git status --short` empty, then report the SHA, checks run, Plane state and remaining risks.

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
