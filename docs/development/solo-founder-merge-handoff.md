# Founder-development implementation handoff

Scope: WELL-120 + WELL-121, PR #224. The inherited WELL-120 commit `09812d6bb245fe9360af813f7590c9313ff5a851` remains intact. This update proposes the simpler routine development route; it cannot authorize this establishing PR's integration.

`tools/founder_gate.py` reads live GitHub facts from trusted integrated main, reuses `tools/ci_attestation.py` candidate/result checks and `tools/newyou_attest.py` organization identity and locked durable custody helpers. It accepts one current founder APPROVED technical review with eligible-scope/base declaration. No new service, GitHub App, workflow, manual evidence input or duplicate approval comment is introduced. Existing strict tools remain intact for higher-risk controls.

Follow [the merge procedure](foundation-integrity-merge-gate.md) for commands, lifecycle, refusal/recovery and bootstrap limits. [The settings proposal](founder-merge-admin-proposal.md) needs a separate owner decision and live verification; publication alone activates no GitHub protection.

Tests: `python3 -m unittest tests.test_founder_gate tests.test_ci_attestation tests.test_newyou_attest -v`. Tests substitute GitHub API/merge boundaries; they never merge a real PR. Observed results and final SHA/CI belong in PR #224 and WELL-120/WELL-121. This command list is not an assertion of hosted success.

The [capability convention](knowledge/README.md) and [registration map](knowledge/identity.registration.json) describe actual application behavior. This tooling/governance PR changes no application Resource, migration or participant flow. Verify current source and live Plane before extending the map.
