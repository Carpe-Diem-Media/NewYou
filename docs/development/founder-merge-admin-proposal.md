# Owner-only GitHub settings proposal

This proposes settings and applies none. Verify `Carpe-Diem-Media/NewYou`, repository ID 1332946467, ruleset 24191860, protected main and no bypass before any separately authorized change.

Retain strict required Foundation Integrity from GitHub Actions (integration 15368), PR-only integration, deletion/non-fast-forward protection and no bypass. Require at least one genuine approval, `dismiss_stale_reviews_on_push=true`, `require_last_push_approval=true`, `required_review_thread_resolution=true` and `allowed_merge_methods=[merge]`. Preserve other applicable protections. The live guard additionally verifies the founder login/numeric ID and active organization-owner membership.

No new GitHub App, secret, environment, dedicated check or CODEOWNERS requirement is needed for this route. JC-Agents needs repository Write / organization Member access, without administrative bypass. Settings and role changes require separate owner approval; routine merge refuses until live guards pass.

PR #224 remains under current-main governance and requires a fresh exact owner-authorized transition after independent review and CI. Do not alter rules to let the establishing PR approve itself.
