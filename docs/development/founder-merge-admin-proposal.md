# Owner-only GitHub settings proposal

This proposes settings and applies none. Verify `Carpe-Diem-Media/NewYou`, repository ID 1332946467, ruleset 24191860, protected main and no bypass before any separately authorized change.

Retain strict required Foundation Integrity from GitHub Actions (integration 15368), PR-only integration, deletion/non-fast-forward protection and no bypass. Require code-owner approval using the committed `.github/CODEOWNERS` containing `* @JCSchoeman96`, at least one genuine approval, `dismiss_stale_reviews_on_push=true`, `require_last_push_approval=true`, `required_review_thread_resolution=true` and `allowed_merge_methods=[merge]`. Preserve other applicable protections. The live guard additionally verifies the founder login/numeric ID and active organization-owner membership.

The existing Foundation Integrity workflow remains the required CI producer. No new GitHub App, secret, environment or dedicated approval check is required. CODEOWNERS becomes effective only after integration into the base branch and separately authorized native code-owner enforcement. JC-Agents needs repository Write / organization Member access, without administrative bypass. Settings and role changes require separate owner approval; routine merge refuses until live guards pass.

PR #224 remains under current-main governance and requires a fresh exact owner-authorized transition after independent review and CI. Do not alter rules to let the establishing PR approve itself.

Verify the effective branch rules, CODEOWNERS errors, founder access, JC-Agents Write/Member permissions and no bypass after any separately authorized administration change. Current settings are not proof of activation. GitHub documents [code-owner review](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners) and [ruleset enforcement](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets).
