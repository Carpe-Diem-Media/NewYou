# GitHub branch governance

Canonical repository: `Carpe-Diem-Media/NewYou`, repository ID 1332946467. The organization transfer is intentional. Founder JCSchoeman96 is user ID 216185530. JC-Agents is implementation user ID 355419376.

Follow [the merge procedure](foundation-integrity-merge-gate.md). For eligible development, ChatGPT Master Gate completes the technical review and publishes one authenticated JCSchoeman96 APPROVED review for the exact final head. That review is both technical approval and standing merge authorization. Verify current required CI and live branch protection. Use the read-only `native-candidate` and `native-result` checks around a regular merge bound to the reviewed head. No second founder comment, base-SHA line, persisted merge intent or routine before/after attestation files are required.

Apply stronger approval only when a governing or external obligation requires it. A file path or a change to CI, agent instructions, approval tooling or governance does not by itself select a stricter route. Never bypass branch protections. If a merge response is uncertain, inspect the PR and `main` before any further action. Plane moves to Done only after resulting-main proof succeeds.

PR #224 remains subject to current-main requirements. It needs fresh complete review, successful CI and explicit owner authorization for its exact merge transition. Collection-only comment 6821263762 is not authorization. The PR cannot self-approve or self-merge, and CODEOWNERS read from the base cannot enforce its review. Any later settings change requires separate authorization and independent verification of the live configuration.
