# GitHub branch governance

The public `JCSchoeman96/NewYou` repository protects `main` with the active
ruleset `24191860` (`Protect main`). The ruleset strictly requires the
`Foundation Integrity` status check and a pull request before changes can
enter `main`.
The repository owner directed this configuration. Verify the live ruleset
before relying on it because repository settings can change.
The ruleset has no bypass actors and requires zero GitHub approvals. Independent
Master Gate review remains mandatory under this procedure. The collector checks
the configured and effective rules, including pull-request, non-fast-forward,
deletion and strict status-check protections, and fails closed on missing data.
The current ruleset names the check context without binding an app. The collector
independently verifies that the observed check belongs to GitHub Actions; the
ruleset alone does not enforce that producer identity.
The separately implemented `private-procedural` mode describes the superseded
private-Free configuration only; it is not applicable to the current repository.

The required check is produced by hosted pull request CI. Foundation Integrity
always runs routing and Foundation Smoke, then includes Application CI and the
Hex security audit when the changed paths require them. Foundation Full remains
in its scheduled nightly lane and is not a pull request requirement. The
application dependency cache warmer is separate from Foundation Integrity:
trusted pushes to `main` may populate dependency caches, while pull requests
may restore a matching cache but cannot write one. Cache contents are never
test results or application build output.

Before a regular merge, an independent reviewer must inspect the complete diff
at the exact PR head, verify the current base, confirm the exact hosted PR run
and tested merge candidate, and record attributable review evidence. The merge
operator must confirm that the PR head, base, candidate, run attempt and review
record have not changed. A changed input requires fresh review or CI evidence as
applicable. Do not bypass the ruleset or merge without the required status.

After merge, the independent reviewer performs read-only reconciliation of the
resulting `main` commit, its parents, tree and relationship to the reviewed PR
and tested candidate. Reconciliation does not rerun tests. If the merge result
does not match the reviewed and tested evidence, stop delivery and resolve the
discrepancy before marking the work complete or unblocking dependent work.
The detailed evidence procedure is in [Foundation Integrity merge
gate](foundation-integrity-merge-gate.md).
