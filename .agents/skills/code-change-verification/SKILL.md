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

## Independent review and attestation handoff

After independent Master Gate approval, require the reviewer to supply `reviewed_head`, `reviewer`, `review_reference` and independently verified full-diff `diff_sha256` in machine-copyable form. Verify the authentic review reference, reviewer, exact head, full diff and digest independently before a trusted operator materializes `review.json`. Never substitute an author's self-certification or untrusted PR content.

Identify the trusted operator and follow the before/after collector and private evidence custody procedure in `docs/development/foundation-integrity-merge-gate.md` and `AGENTS.md`. Record collector output, exit status, stderr and digests. Separate merge authorization remains required. Resulting-main certification must pass before Plane Done or dependent implementation; use the documented fail-closed fallback when proof is unavailable.
