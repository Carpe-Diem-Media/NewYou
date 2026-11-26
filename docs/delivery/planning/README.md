# Derived development planning references

These seven FP-002 references help readers navigate scoped requirements and proof guidance beneath current Product, Architecture, Domain, Roadmap and delivery contracts. Use them after independent approval and integration into `main`, as recorded in Git and PR history. Plane remains the authority for execution state.

## Select an explicit scoped record

1. Start with the live Plane ticket and the [governance](../../governance/CURRENT_GOVERNANCE_ROUTER.json) and [delivery](../CURRENT_DELIVERY_ROUTER.json) routers. Use only explicitly cited, applicable scoped IDs.
2. Parse [INDEX.json](INDEX.json) and the selected shard with duplicate-key detection. Require an exact key in `entries`. For example, `FP002-AC-016#E2a` selects `fp-002/e2a.json` at `/records/2`, and `FP002-AC-005#S1` selects `fp-002/s1.json` at `/records/2`.
3. Resolve the shard relative to this directory. Reject absolute paths, parent traversal and paths that resolve outside the directory. Require a valid `/records/N` pointer and confirm the selected record's `projection_id` matches the requested key exactly. Reject unknown or unqualified IDs, invalid pointers and mismatched IDs. `source_id_lookup` and related source IDs support navigation only.
4. Read the selected record, its exclusions and the necessary direct authority. Check its pinned Git blobs at the recorded snapshot and verify the governing versions against the current routers. Where relevant, map the scoped outcome to assertions in the existing Behaviour and Proof Matrix. Report stale, missing or conflicting references and resolve the affected scope under the existing authority and STOP rules. A missing reference alone does not block Ready intake.

## Scope and pricing

The E2a records are classified as `historical_synthetic_reuse` and refer to [WELL-192, PR #329](https://github.com/Carpe-Diem-Media/NewYou/pull/329). The S1 records are classified as `bounded_admission_guidance` and refer to [WELL-197, PR #330](https://github.com/Carpe-Diem-Media/NewYou/pull/330). Both are integrated implementation context. Use the records prospectively without imposing retroactive requirements or reopening integrated work. Each record covers the stated portion of its original acceptance case. The linked code, tests and review establish what was proven.

[DEC-328](../../governance/product/01_DECISIONS_v1.21.0.md#dec-328--founder-pricing-decision-mvp-launch-amounts-are-fixtures-and-launch-values-are-commerce-configuration) and [FP-002 Phase 7C v0.3.0](../feature-contracts/fp-002/FP-002_FINAL_FEATURE_PACK_CONTRACT_v0.3.0.md) govern pricing where older execution-plan or reconciliation wording differs. Development prices, savings and component splits are synthetic fixtures. Authorised Commerce operators approve launch configuration before real sale. Deterministic versioned allocations, pre-sale disclosure and immutable accepted snapshots still apply.

## Provenance

The publication inputs are these members of the external Master v0.13.0 archive, SHA-256 `acfd3f582aa24bca5f3f72e284c5f0ede1be116b358958c7c9700777b57c8e92`.

```text
STAGE_Q/PROPOSED_REPOSITORY_FILES/
STAGE_Q/WORKFLOW_INSERTIONS_PROPOSED.md
```

The records retain the candidate's original source metadata, including its Master v0.12.0 locator context. Each record identifies the external FP-002 v0.10.1 archive, member, pointer, heading and digests. The selected records are self-contained for ordinary use. External archive locators document provenance and are outside repository lookup. Broader original cases and other Feature Packs are outside Stage Q.
