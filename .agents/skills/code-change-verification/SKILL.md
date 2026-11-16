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
10. **Run and record the independent OCR checkpoint before review handoff.** After applicable local gates pass, run `ocr review --from origin/main --to HEAD` for material engineering changes and capture all findings, exclusions, the scanned implementation SHA and tool outcome using the procedure below. For trivial/cosmetic or documentation-only changes, record a justified exemption.
11. **Confirm required CI state** on the final PR head SHA: required `Foundation Integrity` and any routed Application CI lanes are green for this SHA. Follow `docs/development/foundation-integrity-merge-gate.md`. Foundation Full is deferred to nightly hardening and is not part of PR certification.
12. **Confirm a clean worktree** with `git status --short` empty, then report the exact head SHA, every exact command and observed result, resolved Elixir/Erlang/OTP versions, Plane state, OCR disposition/evidence and remaining risks.

## Independent OCR checkpoint (material engineering PRs)

Run this **after applicable local checks pass** and before declaring the implementation ready for Master Gate. The PR may subsequently gain the required generated PR-history commit; record both the OCR-scanned implementation SHA and final PR head. Refresh `origin/main` and verify the intended comparison base before running:

```bash
git rev-parse HEAD
git merge-base origin/main HEAD
ocr review --from origin/main --to HEAD
```

Preserve an **OCR Review Findings** section in the PR description with: exact command and observed result; scanned implementation SHA and comparison base; file counts and every excluded/unreadable path or unsupported extension (for example `.heex`); all findings with reported severity, path/line and a concise accurate summary; the agent's preliminary assessment (not a ruling); and tool errors, blind spots, or the explicit exemption rationale. A zero-finding result must still state coverage/exclusions. Redact secrets and sensitive material; do not paste credentials or raw sensitive logs.

**Do not silently fix, suppress or disregard OCR findings.** Do not automatically implement OCR suggestions. Credible urgent security, privacy or data-integrity exposure must be reported immediately, with the PR left Draft/Blocked for independent review; necessary immediate containment is allowed. If OCR cannot run for a material change, report the exact blocker rather than claiming the scan passed or an exemption. Material excluded paths remain subject to normal manual diff review.

Master Gate, not the author agent or OCR, independently evaluates each finding against code, execution context, durable authority and tests and records one disposition: `CONFIRMED BLOCKER`, `NON-BLOCKING`, `FALSE POSITIVE` or `NEEDS EVIDENCE`, with a reason. Only confirmed blockers are automatic merge blockers; unresolved material evidence can prevent certification until resolved. Author agents correct confirmed blockers or explicitly directed non-blocking items only. If implementation/source files change, rerun applicable local checks and OCR; any head change requires fresh exact-head CI and independent certification. Do not make OCR a CI failure based on advisory finding count.

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

A mechanical history-only commit does not invalidate passing application evidence when the complete diff confirms identical verified application inputs. Record the tested implementation SHA and final PR head separately. Run final history validation and exact-head hosted CI; source/base changes require regeneration and refreshed affected proof. OCR remains separate advisory evidence, never a substitute for CI or independent Master Gate.

Before a routine PR update, follow the actual `JC-Agents` authentication and existing-author preflight in `AGENTS.md` and `ticket-implement`. A founder-authored PR is ineligible for the routine agent/founder approval route.
