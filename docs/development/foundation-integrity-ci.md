# Foundation Integrity CI

This document describes the Foundation Integrity lanes introduced for WELL-38.
The lanes preserve governance certification while separating current routing
checks from the complete historical suite.

## Canonical commands

Run the always-on Smoke lane from the repository root:

```bash
python -m unittest discover -s tests -p 'test_foundation_lane_routing.py' -v
python -m unittest discover -s tests -p 'test_foundation_smoke.py' -v
python -m unittest discover -s tests -p 'test_foundation_merge_gate.py' -v
python -m tools.foundation_integrity_smoke --governance-router docs/governance/CURRENT_GOVERNANCE_ROUTER.json --delivery-router docs/delivery/CURRENT_DELIVERY_ROUTER.json --json
```

Run the complete governance and historical certification lane for an exact
checkout:

```bash
python tools/run_foundation_full_tests.py
python tools/foundation_integrity_audit.py --manifest docs/history/CURRENT_AUTHORITY_MANIFEST_v1.0.0.json --json
```

Foundation Full runs all discovered tests. No historical test is excluded from
the full command. The manifest-backed full audit checks the pinned pre-migration
document tree, historical hashes, archive provenance and transition rules.
Foundation Smoke checks the current governance and delivery routers against the
semantic roots.

The test runner temporarily exposes the pinned pre-migration tree at its old
paths while the frozen suite runs. The audit builds the same pinned view and
overlays `docs/history/` evidence so later provenance changes remain visible.
Temporary links are removed when the suite exits; the repository and both
current routers use only the semantic roots.

For historical certification of an exact commit on GitHub Actions, run **Foundation Full** with the
`workflow_dispatch` input `sha` set to the full 40-character commit SHA and use
a workflow ref where Foundation Full is available. The workflow verifies that
checked-out `HEAD` equals the input SHA.

## CI routing

Every pull request runs Foundation Smoke; ordinary pushes to `main` do not. The workflow
does not use path filters, so the required status check cannot disappear when
files change.

The route job compares the pull request base to its head. `docs/governance/**`, `docs/history/**` and explicit Foundation
Full/provenance machinery select Full. `docs/delivery/**`,
`docs/development/**`, `.agents/**`, application source and tests select
Application CI as appropriate. Unknown paths and unresolvable pull-request
diffs fail closed to Full. Python language and the generic `tests/**` root do
not select Full by themselves. Git rename detection is disabled for path
classification, so both source and destination are considered.

Foundation Smoke runs on each PR. The required **Foundation Integrity** aggregate
waits for Smoke, routed Application CI and the routed Hex security audit,
but not for Full.

Routed application and engineering changes run the canonical `mix check` gate.
The slower `mix check.deep` lane runs when application source, migrations or
dependency/toolchain inputs change. Documentation-only delivery/development
changes, agent guidance and test-only changes skip that lane. Application-only
changes do not run the complete historical governance suite.

## Lane responsibilities

**Foundation Smoke** checks both current routers and their semantic boundaries,
route hashes and targets, required governance inventories, the root README,
history file presence and merge-gate topology. A governance route into delivery
or history, a delivery route into governance or history, a missing file or an
archive route fails this lane.

**Foundation Full** runs the complete unit suite and full audit. It retains
historical certification, immutable hash, archive provenance, lifecycle,
transition and fail-closed mutation checks. The frozen manifest is located at
`docs/history/CURRENT_AUTHORITY_MANIFEST_v1.0.0.json`. The audit builds a
temporary legacy-path view so its historical checks can continue without
restoring a mixed current documentation root.

## Baseline evidence

The required baseline was checked before restructuring, on exact main SHA
`4234965c8da20dbb4ef0a7128614a5070244619a`:

```text
python3 -m unittest discover -s tests -v
Ran 508 tests in 883.353s
OK

python3 tools/foundation_integrity_audit.py --manifest docs/history/CURRENT_AUTHORITY_MANIFEST_v1.0.0.json --json
PASS — 900 assertions, 0 findings
```

The baseline working tree was clean. The baseline SHA was confirmed against
local `main`, `origin/main`, and live `main` before changes.

## Candidate verification

Candidate verification ran from the WELL-38 branch based on the same SHA:

```text
python3 -m compileall -q tools tests
PASS

python3 -m unittest discover -s tests -v
Ran 534 tests in 867.562s
OK

python3 -m unittest discover -s tests -p 'test_foundation_smoke.py' -v
Ran 22 tests
OK

python3 tools/foundation_integrity_audit.py --manifest docs/history/CURRENT_AUTHORITY_MANIFEST_v1.0.0.json --json
PASS — 900 assertions, 0 findings

python3 -m tools.foundation_integrity_smoke --governance-router docs/governance/CURRENT_GOVERNANCE_ROUTER.json --delivery-router docs/delivery/CURRENT_DELIVERY_ROUTER.json --json
PASS — 47 assertions, 0 findings

git diff --check 4234965c8da20dbb4ef0a7128614a5070244619a
PASS
```

The read-only successor check used PR #133 at head
`4b920180bca39ffa369579776335a6fd61885efd` as the current tree:

```text
python3 tools/foundation_integrity_audit.py --root <PR #133 checkout> --manifest docs/history/CURRENT_AUTHORITY_MANIFEST_v1.0.0.json --json
PASS — 928 assertions, 0 findings

python3 -m tools.foundation_integrity_smoke --root <PR #133 checkout> --governance-router docs/governance/CURRENT_GOVERNANCE_ROUTER.json --delivery-router docs/delivery/CURRENT_DELIVERY_ROUTER.json --json
PASS — 47 assertions, 0 findings
```

Mutation checks confirmed the lane boundary remains fail-closed. Changing the
archived Skeleton v0.1.21 bytes in a disposable copy of that tree made Full
fail with 12 findings. Routing manifest Open Work v1.2.78 into `archive/` made
Smoke fail with three findings. The exact predecessor audit passes only the
pinned main SHA `4234965c8da20dbb4ef0a7128614a5070244619a`.

## Reclassification of PR #133 legacy failures

PR #133's Foundation Integrity run `39547940310` reported 43 failing test
methods and three class setup errors after its legitimate status successor
archived or superseded earlier current files. Those failures fall into the
following preserved categories:

| Previous assertion group | Formerly failing tests | WELL-38 classification |
| --- | --- | --- |
| Read current paths and README routes | `test_explicit_current_routes_in_roadmap_atlas_and_harden_resolve_relationally`; `test_current_routes_are_current_and_old_paths_remain_archived`; `test_current_derived_routes_keep_programme_router_open`; `test_current_derived_routes_reject_open_tracker_projection`; setup in `test_platform_readme_router_consistency`, `test_product_law_hardening`, and `test_roadmap_routing_resilience` | These remain current-state assertions. They now resolve the live path from the manifest or working navigation routes, then test that current file and its relationship to current README/authority routes. A broken current route still fails. |
| Assert PR #126's promoted status at a predecessor's old current path | All methods in `test_fp001_development_entry_hard_stop_promotion` that read Open Work v1.2.77, Atlas v0.4.19, Skeleton v0.1.21, or HARDEN-02 v0.5.21; `test_lifecycle_manifest_and_scope_are_current_and_unchanged`; `test_open_work_routes_to_review_without_advancing_proof_or_phase9` | These assertions certify a completed historical transition. They now read the archived snapshot when present, retain the same status and content checks, and compare the Open Work v1.2.77 bytes with the certified baseline. They no longer assert that the predecessor remains current. |
| Derive fixture paths from the former current version | All failing methods in `test_foundation_integrity_audit`; `test_fail_closed_mutations_use_production_run_audit`; `test_scope_and_candidate_lifecycle_preserve_the_existing_gates`; `test_current_readme_and_open_work_route_tracker_124_as_closed` | Current mutation fixtures now start from manifest-resolved current documents. Assertions aimed at named predecessor provenance use archive snapshots. Mutation rejection, audit failure, and hash checks remain in Foundation Full. |

The 43 formerly failing test methods, grouped by module, were:

- `test_dol_01_marketing_unsubscribe_authority.py`: `test_current_routes_are_current_and_old_paths_remain_archived`, `test_downstream_gate_lines_match_the_preserved_open_work_predecessor`.
- `test_engineering_standards_promotion.py`: `test_fail_closed_mutations_use_production_run_audit`.
- `test_foundation_integrity_audit.py`: `test_explicit_current_routes_in_roadmap_atlas_and_harden_resolve_relationally`, `test_fp001_audit_current_promotion_rejects_misattributed_successor_provenance`, `test_fp001_audit_work_start_predecessors_fail_in_unqualified_active_routes`, `test_fp001_communications_v010_promotion_coherence_guards_fail_closed`, `test_fp001_durable_delivery_attestation_requires_bound_post_merge_comment`, `test_fp001_identity_v014_open_work_separates_pr76_certification_from_pr77_promotion`, `test_fp001_identity_v014_promotion_rejects_lineage_route_and_gate_mutations`, `test_fp001_identity_v014_promotion_rejects_non_immediate_atlas_predecessor`, `test_fp001_phase8_rejects_unreviewed_current_route_text`, `test_fp001_pmr_current_status_successor_artifacts_are_byte_pinned`, `test_fp001_pmr_mutation_matrix_fails_closed`, `test_fp001_pmr_rejects_atlas_metadata_declarations_outside_header`, `test_fp001_pmr_rejects_harden_metadata_declarations_outside_header`, `test_fp001_pmr_rejects_multiple_active_skeleton_versions`, `test_fp001_pmr_rejects_stale_candidate_path_alongside_certified_successor`, `test_fp001_pmr_rejects_unarchived_predecessor_route_in_current_atlas`, `test_fp001_pmr_rejects_unqualified_current_harden_section_20_stop`, `test_fp001_pmr_rejects_unreviewed_additions_to_current_route`, `test_fp001_pmr_validates_atlas_artifact_lineage_independently_of_open_work`, `test_fp001_pmr_validates_harden_v0520_successor_metadata`, `test_harden_execution_state_machine_fixtures`, `test_phase7c_foundation_integrity_rejects_candidate_mutations`, `test_roadmap_proof_classification_lifecycle_fails_closed_on_scope_regressions`.
- `test_fp001_development_entry_hard_stop_promotion.py`: `test_atlas_current_status_has_no_contradictory_authorisation`, `test_atlas_patch_scope_sections_restore_history`, `test_atlas_transition_v0_4_18_to_v0_4_19`, `test_foundation_integrity_rejects_reverted_hard_stop_state`, `test_foundation_integrity_rejects_stale_current_atlas_jit_boundary`, `test_hard_stop_pass_authorises_bounded_phase8_only`, `test_harden_current_predecessor_and_section_20_authority_are_unambiguous`, `test_harden_current_sections_do_not_project_pre_hard_stop_state`, `test_harden_historical_pre_classification_record_is_preserved`, `test_skeleton_current_status_is_pass_bounded_and_not_pre_hard_stop`, `test_skeleton_direct_predecessor_is_v0_1_20`, `test_skeleton_historical_sections_match_archived_v0_1_17`, `test_unauthorised_state_rejects_identical_synthetic_source`.
- `test_fp001_phase7b_reconciliation_candidate.py`: `test_scope_and_candidate_lifecycle_preserve_the_existing_gates`.
- `test_fp001_phase7c_final_contract_candidate.py`: `test_current_readme_and_open_work_route_tracker_124_as_closed`.
- `test_fp001_tracker_closure_sync.py`: `test_current_derived_routes_keep_programme_router_open`, `test_current_derived_routes_reject_open_tracker_projection`.

The three class setup errors were `setUpClass` in `test_platform_readme_router_consistency.py`, `test_product_law_hardening.py`, and `test_roadmap_routing_resilience.py`; each loaded an old current path directly and now obtains the current route from the manifest.

Additional nearby lifecycle assertions were made successor-safe even though
they were not among those 43 failures: the current README/manifest checks in
`test_fp001_phase7c_current_promotion.py` and
`test_fp001_audit_evidence_v010_promotion.py` now resolve current routes
dynamically; PR #121's Open Work v1.2.77 status check in
`test_fp001_phase7b_reconciliation_certification.py` is explicitly historical
and byte-pinned to baseline; and the Phase 8 proof-contract lifecycle test reads
the v1.2.77 status snapshot from its active or archived location.

Prior Architecture, Domain, Roadmap and HARDEN-02 certification tests also
pinned the old workflow bytes as a current artifact. They now verify that exact
workflow remains in the WELL-38 base commit history, while Foundation Smoke
tests the changed live workflow and routing. The earlier scope guard permits
only the WELL-38 CI files and test support in addition to its existing paths;
it still rejects application/bootstrap files and unrelated governance paths.

## Historical-only evidence retained

The following status assertions are intentionally historical-only: PR #126's
Open Work v1.2.77, Delivery Atlas v0.4.19, FP-001 Skeleton v0.1.21, and
HARDEN-02 v0.5.21 transition state. Their exact text, route history, gate
status, and byte provenance remain checked. Tests for earlier candidate
archives and lifecycle promotions remain part of the full suite and audit.
The reviewed TB-001 contract archive is accepted only when the Phase 8
manifest rule and historical manifest record pin the same immutable bytes;
other unregistered Tracer Bullet or architectural-proof artifacts still fail.
No Product, Architecture, Domain, Roadmap, TB-001, or Feature Pack semantics
were changed, and no historical evidence was deleted.
