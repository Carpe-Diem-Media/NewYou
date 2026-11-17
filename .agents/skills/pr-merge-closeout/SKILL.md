---
name: pr-merge-closeout
description: Use after a NewYou PR receives an authenticated independent exact-head APPROVED review, to verify the tested native merge candidate, perform the authorized protected merge, prove the resulting main tree, and close its Plane work item. Never use for unapproved or merely COMMENTED PRs.
---

# NewYou PR Merge and Closeout

## Purpose and authority

Finish an **already approved** NewYou implementation PR without adding an independent merge policy or rewriting application code. This skill is the *execution workflow* for the existing law and tools, not a replacement for them.

Read **live** before acting:

1. `AGENTS.md` — approval, identity, implementation and Plane closeout rules.
2. `docs/development/foundation-integrity-merge-gate.md` — **canonical** native founder-development merge procedure.
3. `.agents/skills/code-change-verification/SKILL.md` — exact-head evidence and review requirements.
4. Applicable `docs/governance/CURRENT_GOVERNANCE_ROUTER.json`, `docs/delivery/CURRENT_DELIVERY_ROUTER.json`, and the live Plane ticket where the merge could affect legal, release, Domain, security or lifecycle authority.
5. Actual `tools/ci_attestation.py` and `tools/newyou_attest.py` at trusted integrated `main`.

If these documents or tools disagree with this skill, **follow the higher authority and stop on material uncertainty**. Never infer release authorization from a development merge. The normal eligible founder-development path uses **one authenticated `JCSchoeman96` APPROVED review**, which is both technical approval and standing merge authorization. An ordinary PR comment, author self-assessment, or OCR pass is not approval. Apply stronger approval only if actual governing/external obligations require it.

## Entry conditions and inputs

Required live inputs (read them, do **not** hardcode a prior PR's values):

- `PR_NUMBER`: eligible PR authored by `JC-Agents` targeting `main`.
- `REVIEWED_HEAD_SHA`: complete 40-character commit approved by `JCSchoeman96`.
- `CI_RUN_ID`: latest qualifying successful exact-head Foundation Integrity workflow run.
- `PLANE_TICKET`: actual linked `WELL-N` work item, including live state, dependencies and acceptance criteria.
- `EXPECTED_BASE_SHA`: PR's currently approved/verified base commit at entry.

**Entry gate:** Verify the exact full PR diff and original independent Master Gate disposition have no unresolved material blockers; all applicable checks and OCR dispositions are complete; the PR is open, not Draft and not merged; latest decisive founder review is `APPROVED` for the exact current head; and the current base is the trusted `main` used for candidate verification. Do not reuse an earlier review after a head change. Do not treat Plane as an override of GitHub or durable governance.

The implementing agent must use its own `JC-Agents` GitHub credentials, **never founder credentials**, and must not bypass branch protection or approve its own work.

## State machine and stop conditions

| State | Transition guard | Action / side effects | Next state |
| --- | --- | --- | --- |
| `APPROVED` | Exact head/base/review/current CI/Plane scope revalidated | Run read-only native candidate verification | `CANDIDATE_VERIFIED` or `STOP` |
| `CANDIDATE_VERIFIED` | Candidate is uniquely identified and `main`/PR remain unchanged | Ordinary GitHub merge bound to the reviewed head, no bypass | `MERGE_REQUESTED` |
| `MERGE_REQUESTED` | GitHub merge outcome is definite | Inspect PR and resulting main; update trusted local main by fast-forward | `MERGED` or `STOP_UNCERTAIN` |
| `MERGED` | Read-only native-result confirms commit parents, tree and exact tested candidate | Record bounded evidence in Plane | `INTEGRATED` or `STOP` |
| `INTEGRATED` | Resulting-main SHA/tree and required proof are independently verified; all ticket obligations satisfied | Move only linked Plane work item to `Done`; release owned worktree/resources | `DONE` |

`DONE` is terminal for this ticket. `STOP` / `STOP_UNCERTAIN` are **not** success; preserve existing durable evidence and identify the exact unmet guard in Plane. A merge request timeout/error is **not** proof of failure or success: read GitHub PR and `main` before deciding any further action, and never blindly reissue a merge.

## Phase 1 — Read-only preflight and candidate verification

Use the existing **trusted integrated `main` worktree**, not an untrusted PR checkout. Verify it is clean; fast-forward it to the live `origin/main` if necessary. Re-fetch the PR, authenticated review, exact-head required CI, active branch rules/CODEOWNERS, and Plane. Confirm no new blocker or drift. These checks are not substitutes for the native tool's complete verification.

```bash
# Run from trusted integrated main. Set these values from fresh GitHub/Plane reads.
set -euo pipefail

REPO='Carpe-Diem-Media/NewYou'
PR_NUMBER='REPLACE_WITH_PR_NUMBER'
REVIEWED_HEAD_SHA='REPLACE_WITH_EXACT_40_CHARACTER_HEAD_SHA'
CI_RUN_ID='REPLACE_WITH_QUALIFYING_WORKFLOW_RUN_ID'

# Identity, worktree and trusted branch guards.
test "$(gh api user --jq .login)" = 'JC-Agents'
test -z "$(git status --porcelain)"
test "$(git branch --show-current)" = 'main'
git fetch origin main
git pull --ff-only origin main
test "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)"

# Confirm source PR identity and author, including normal repo preflight.
python3 -m tools.newyou_attest pr-preflight --pr "$PR_NUMBER"
test "$(gh pr view "$PR_NUMBER" --repo "$REPO" --json headRefOid --jq .headRefOid)" = "$REVIEWED_HEAD_SHA"

# The native candidate verifier checks review, run, current base/head,
# protected-main rules and the actual tested merge candidate, read-only.
CANDIDATE_JSON="$(python3 -m tools.ci_attestation native-candidate \
  --pr "$PR_NUMBER" \
  --reviewed-head "$REVIEWED_HEAD_SHA" \
  --run "$CI_RUN_ID")"

# Preserve this exact tested candidate SHA for the later native-result check.
CANDIDATE_SHA="$(printf '%s' "$CANDIDATE_JSON" | \
  python3 -c 'import json,sys; print(json.load(sys.stdin)["candidate"])')"
test "${#CANDIDATE_SHA}" -eq 40
printf 'Native candidate verified: %s\n' "$CANDIDATE_SHA"
```

**Stop** for missing credentials, wrong account, dirty or untrusted worktree, non-fast-forward main, unreviewed head, changed base, incomplete or failed exact-head CI, changed protection, unresolved material finding, inapplicable standing approval, or any native-candidate error. Do not fix these by changing permissions, lowering checks, silently refreshing source, creating new reviews or weakening governance.

## Phase 2 — Authorized merge

Only after native-candidate succeeds, and after an immediate live recheck that PR head/main/base remain unchanged:

```bash
# Requires the populated variables and successful candidate from Phase 1.
gh pr merge \
  --repo "$REPO" \
  --merge \
  --match-head-commit "$REVIEWED_HEAD_SHA" \
  "$PR_NUMBER"
```

Use **regular merge**, not squash/rebase, administrative bypass, auto-merge, force push or branch-protection changes. Do not alter the reviewed PR head after approval. On ambiguous outcome or timeout, **do not retry**: inspect PR state, merge SHA and current `main` and reconcile.

## Phase 3 — Resulting-main proof

After confirmed merge, fast-forward the trusted integrated `main` worktree and verify it matches the live remote. Then run:

```bash
# Requires original reviewed head, successful run and EXACT saved candidate.
python3 -m tools.ci_attestation native-result \
  --pr "$PR_NUMBER" \
  --reviewed-head "$REVIEWED_HEAD_SHA" \
  --run "$CI_RUN_ID" \
  --candidate "$CANDIDATE_SHA"
```

Require an exit code of zero and independently check that the native result binds the **actual** resulting `main` SHA to the merge commit, its **ordered parents** to reviewed base then approved head, and its **tree** to the tested candidate tree. This is not a new `main` CI run; do not mislabel reused PR-tested candidate evidence. If main drift or any proof mismatch occurs, stop and document the exact discrepancy instead of marking success.

## Phase 4 — Plane closeout and handback

Only after a successful native-result:

1. Record in the live linked Plane ticket: PR, authenticated approval URL/ID, reviewed head SHA, approved base SHA, CI run ID, tested candidate SHA/tree, actual merge SHA, resulting main SHA/tree, candidate/result commands and outputs or bounded evidence references, and any surviving risk/follow-up.
2. Preserve prior non-blocking OCR dispositions and historical unexplained failures accurately. Do not invent causes, retroactively reinterpret failed tests or start unrelated hardening.
3. Move the ticket to `Done` **only after** resulting-main verification and ticket acceptance criteria are satisfied. Use the actual configured Plane states; do not fabricate transitions. Keep related roadmap or dependent tickets in their actual states until independently eligible.
4. Verify clean worktree and correct local/main alignment; release any still-owned TEST/PLT/resource locks. Avoid automatic cleanup of retained business data.
5. Give the user a final handback: review ID, approved head/base, six/current applicable exact-head CI outcomes, candidate SHA/tree, merge SHA, resulting-main SHA/tree, native-result outcome, Plane state, surviving risks and any next dependency-cleared ticket.

**Prohibitions:** No production launch, public release, paid pilot, real-participant use, provider activation, security policy changes, new governance amendments, or broad next-ticket implementation is authorized by this skill. No second founder comment or repeated approval is required for an unchanged eligible head. If source/head/base changes, restart the **applicable** evidence and independent review process; never carry forward an invalidated approval.

## Integration with existing ticket workflow

After `.agents/skills/ticket-implement/SKILL.md` finishes implementation and authenticated approval has been submitted, invoke `pr-merge-closeout` for the merge/closeout continuation. The governing merge rules **remain** `docs/development/foundation-integrity-merge-gate.md`. Keep `AGENTS.md`, the canonical merge gate and the native attestation implementation authoritative; this skill is a thin procedural orchestrator.
