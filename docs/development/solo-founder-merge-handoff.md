# Founder-development merge handoff

This handoff records the routine merge procedure proposed by WELL-120 and WELL-121. It does not authorize PR #224 or claim that its proposed settings are active.

For eligible development, ChatGPT Master Gate completes the technical review and publishes one authenticated JCSchoeman96 APPROVED review for the exact final head. That review is both technical approval and standing merge authorization. The implementing agent must not use founder credentials. No second founder comment or base-SHA line is needed.

Before merge, independently verify the final PR head, required CI and current GitHub protections. From trusted integrated `main`, run `python3 -m tools.ci_attestation native-candidate --pr NUMBER --reviewed-head HEAD_SHA --run RUN_ID`. Merge with `gh pr merge --repo Carpe-Diem-Media/NewYou --merge --match-head-commit HEAD_SHA NUMBER`, then run `python3 -m tools.ci_attestation native-result --pr NUMBER --reviewed-head HEAD_SHA --run RUN_ID --candidate TESTED_CANDIDATE_SHA`. These checks are read-only and do not create persisted evidence or merge intent. If the merge response is uncertain, inspect the PR and `main` before acting again.

PR #224 remains governed by current `main`. Its exact merge transition requires fresh complete review, successful CI and explicit owner authorization. Comment 6821263762 records collection only. The PR cannot self-approve or self-merge. The base branch's CODEOWNERS cannot enforce review on this PR.

After PR #224 integrates under that authorization, any proposed settings or access change needs separate authorization. See [the settings proposal](founder-merge-admin-proposal.md) and verify the live configuration independently before relying on it.

The ticket workflow generates the mechanical PR history record at the review checkpoint and maintains the source-linked capability map when semantics change. Author and reviewer verify live Plane state separately. See [the implementation handoff standard](implementation-handoff-standard.md); do not create a duplicate PR dossier.
