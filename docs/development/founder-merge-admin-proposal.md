# Owner-authorized GitHub settings proposal

This proposal changes no settings. It applies only after PR #224 integrates through its separately authorized exact-head transition. Any settings or access change requires its own explicit authorization.

Verify the target is `Carpe-Diem-Media/NewYou`, repository ID 1332946467, and ruleset 24191860. Preserve the existing Foundation Integrity status-check requirement, PR-only integration, no bypass, force-push protection, deletion protection and regular merge-only behavior. Add one required approval, required code-owner approval, stale-review dismissal, approval of the latest push and resolved review threads. The committed `.github/CODEOWNERS` entry must be exactly:

```text
* @JCSchoeman96
```

The intended ruleset values are:

```json
{
  "repository": "Carpe-Diem-Media/NewYou",
  "repository_id": 1332946467,
  "ruleset_id": 24191860,
  "target_branch": "refs/heads/main",
  "bypass_actors": [],
  "pull_request": {
    "parameters": {
      "required_approving_review_count": 1,
      "require_code_owner_review": true,
      "dismiss_stale_reviews_on_push": true,
      "require_last_push_approval": true,
      "required_review_thread_resolution": true,
      "allowed_merge_methods": ["merge"]
    }
  },
  "preserve": {
    "required_status_check": "Foundation Integrity",
    "pull_request_only": true,
    "force_push_protection": true,
    "deletion_protection": true,
    "other_existing_rules_and_parameters": true
  },
  "agent_access_after": {
    "repository_role": "Write",
    "organization_role": "Member",
    "admin_or_bypass": false
  }
}
```

This is the target for the ruleset's pull-request parameters, not a complete replacement payload. Read the live ruleset, preserve every existing required rule and unknown parameter, and apply only the authorized changes. Preserve the existing Foundation Integrity check binding as returned by GitHub. The current ruleset API response does not expose an `integration_id` for that check, so do not claim or write an integration binding based on a presumed value.

Change and verify the rules before setting JC-Agents to repository Write and organization Member, with no admin or bypass access. Preserve JCSchoeman96's existing organization-owner/repository-admin access. Keep the change limited to the stated settings and access; preserve other applicable protections.

After an authorized change, independently inspect the effective ruleset and branch protection, CODEOWNERS parsing/errors, founder and JC-Agents access, and bypass status. A proposal or configured value alone does not prove active enforcement. Do not claim the route is active until live verification confirms each setting.

PR #224 remains subject to current-main requirements and cannot activate settings to approve or merge itself. It needs fresh complete review, successful current CI and explicit owner authorization for its exact merge transition. Collection-only comment 6821263762 is not authorization.

GitHub documents [code-owner review](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners) and [ruleset enforcement](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets).
