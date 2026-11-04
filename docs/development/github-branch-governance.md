# GitHub branch governance (Pass 1 — P1-GOV-003)

The repository’s exact-head certification model assumes **`main` cannot change without review and a passing Foundation Integrity check**. As of Pass 1 audit, GitHub reported `main` as **unprotected** with **no rulesets**.

## Required controls on `main`

Apply these on the hosting repository (Settings → Rules → Rulesets, or legacy branch protection):

| Control | Purpose |
|--------|---------|
| Block direct pushes | Prevent bypass of PR + CI attestation |
| Require pull request before merge | Enforce independent review path |
| Require status check **Foundation Integrity** | Gate every merge (see check name below) |
| Require branches to be up to date before merge | Stale-green protection |
| Block force pushes | Preserve linear provenance on `main` |
| Block branch deletion | Prevent accidental loss of trust anchor |

Solo-maintainer repos still benefit: mistakes, compromised tooling, and process drift are blocked at the platform layer.

## Foundation Integrity workflow and check name

- Workflow: `.github/workflows/foundation-integrity.yml`
- Trigger: every `pull_request`, without path filters. Ordinary pushes to `main` do not run this workflow. Nightly hardening and manual Foundation Full remain separate.
- Pull-request CI tests GitHub's merge candidate. Independent review binds the reviewed head and exact candidate to the required check and verifies the resulting main tree using the procedure in [Foundation Integrity merge gate](foundation-integrity-merge-gate.md).
- Aggregation job id: `foundation-integrity`
- **Required status check context:** **`Foundation Integrity`** — set explicitly via `jobs.foundation-integrity.name` in the workflow.

The `Foundation Integrity` job aggregates always-on **Foundation Smoke** with
routed **Application CI** and the Hex security audit when required. Foundation
Full provides separate, non-blocking evidence for applicable governance
changes. Keep this exact aggregation context required in the branch ruleset.

Do **not** require `foundation-integrity` (job id) unless the Check Runs API on the PR head proves that is the published context. After workflow changes, verify:

```bash
gh api repos/:owner/:repo/commits/:pr_head_sha/check-runs --jq '.check_runs[] | select(.name | test("Foundation"; "i")) | {name, conclusion, status}'
```

Configure branch protection / rulesets to match the **exact** `name` field returned there.

## Administrator bypass

If administrators can bypass rules, document that explicitly in Open Work or operating model and treat bypass events as governance incidents.

## Verification

```bash
gh api repos/:owner/:repo/branches/main/protection
gh api repos/:owner/:repo/rulesets
```

A protected `main` should not return HTTP 404 for branch protection or should show an active ruleset targeting `main`.

## Pass 1 merge sequence

1. PR head passes **Foundation Integrity** with the verified check context name.
2. Activate ruleset / branch protection on `main` **before** merging the Pass 1 closure PR.
3. Merge through the protection; confirm post-merge **Foundation Integrity** on resulting `main` SHA (the Pass 1 procedure).
