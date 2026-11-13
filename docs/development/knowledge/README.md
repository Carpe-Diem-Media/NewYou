# Capability knowledge and automatic change capture

Start with [identity.registration.json](identity.registration.json), the canonical registration map. Follow its source locators, then inspect current code, tests, governing authority and live Plane before reuse. The implementation revision identifies inspected source; per-file SHA-256 values bind bytes. This is descriptive knowledge, not governing authority or delivery status.

## Three kinds of evidence

- The JSON records under `history/`, named by PR number, record the exact PR change range, file status/modes/blob IDs/hashes, parseable Elixir declarations, changed tests and migrations. Each record describes historical changes, including removed source. GitHub supplies actual review, CI and merge status.
- `<capability_id>.json` describes source-verified ownership, public Ash interfaces, flow, lifecycle, invariants, failure/recovery, proof limits and extension points. Maintain one map per meaningful capability. Use [capability.schema.json](capability.schema.json). The agent contributes semantic facts with source locators, without manually enumerating every changed file or function.
- The `index` and `query` commands compute a lookup view from the requested Git tree. They do not create a database or commit another index. Historical references do not certify that a past symbol still exists.

## Agent capture before final review

The [ticket workflow](../../../.agents/skills/ticket-implement/SKILL.md) invokes these steps as normal agent work. The founder runs no commands. Generate once at the review checkpoint, then regenerate only when source or base changes. The check uses stable ticket identifiers in the committed record when `--ticket` is omitted; a supplied ticket must agree.

1. Implement and test the ticket. Commit source changes. For a first PR, create it as a draft with its implementing WELL ticket in the title or description. Push the source checkpoint before fetching metadata, so GitHub's head matches the source revision.
2. Verify the live Plane ticket and dependencies through the connected Plane integration as part of author and reviewer checks. Plane state is not copied into the historical record.
3. At the review checkpoint, save live PR metadata and generate the record with the explicit ticket from implementation context. Replace `NUMBER` and `WELL-N` with their actual values.

```sh
gh api repos/Carpe-Diem-Media/NewYou/pulls/NUMBER > /tmp/newyou-PR-metadata.json
mise exec -- python3 -m tools.knowledge_capture generate --metadata-json /tmp/newyou-PR-metadata.json --ticket WELL-N
```

4. Commit `pr-NUMBER.json` under `history/` and push it before requesting review. Only that record is excluded from its own mechanical payload; other history and capability changes remain visible. The record contains the exact base, merge base, source blobs and hashes, and stable PR commit/check links. It omits PR prose, author and Plane state, its own final head SHA, and CI or merge outcomes. Existing records keep their historical administrative fields and remain queryable without regeneration.
5. Foundation Smoke independently regenerates the source fields against the event's exact PR base/head using the committed stable ticket references. Independent review verifies those references against live Plane; CI does not authenticate ticket ownership or current Plane state. It installs the parser only when changed Elixir source or extractor tooling needs it. Ordinary documentation changes still receive read-only record validation. Parsing never evaluates source. CI does not commit changes. Changed source/base, tampering, invalid linkage or a missing record requires regeneration and fresh review/CI. No generated commit follows final approval.

After pushing the final history commit, refresh the metadata and run the same check locally:

```sh
gh api repos/Carpe-Diem-Media/NewYou/pulls/NUMBER > /tmp/newyou-PR-metadata.json
mise exec -- python3 -m tools.knowledge_capture check --metadata-json /tmp/newyou-PR-metadata.json
```

GitHub's merge record binds the final PR head and merge SHA. Post-merge reconciliation checks the resulting main; it does not push another generated commit to main.

## Semantic maps and mechanical refresh

Create or maintain one map for meaningful capability or material Domain/interface/lifecycle/schema changes. Reuse existing interfaces and semantic copy identities. Explain non-applicable dimensions. An ordinary internal/cosmetic change needs its PR description and automatic history record, with a brief reason that no semantic map changed. Do not duplicate a JSON map in a long Markdown handoff.

After reviewing the semantic claims and committing the referenced source, generate hashes and the implementation revision automatically:

```sh
python3 -m tools.capability_knowledge --refresh identity.registration
python3 -m tools.capability_knowledge
```

The refresh refuses uncommitted source, unsafe paths and missing symbols. It changes mechanical evidence only, so agents must maintain any semantic explanation of the snapshot. The validator rejects duplicate keys, unknown fields, broken references, changed bytes and invalid lifecycle references. Independent Master Gate verifies behavioural claims against real source/tests; neither parsing nor hashes prove semantics.

## Retrieval and extraction limits

Use `index` to list capability/source/history relationships and `query --query TEXT` to filter by ticket, file, module or capability. Resolve current main first, then pass `--revision origin/main` for the integrated view. Omit that option to inspect HEAD while developing. No stale worktree file can substitute for committed source at the reported revision.

```sh
python3 -m tools.knowledge_capture index --revision origin/main
python3 -m tools.knowledge_capture query --revision HEAD --query NewYou.Identity
python3 -m tools.knowledge_capture query --revision HEAD --query WELL-121
```

Elixir extraction uses `Code.string_to_quoted/2`, compares normalized declarations across revisions, preserves function-clause order and reports public/private visibility. The current index parses the selected Git tree in one batch and reconciles historical symbols against those declarations. A function removed from a still-existing file is not current simply because its path remains. It does not execute macros or infer Ash-generated functions, authorization, transactions or dependency effects. Unsupported/dynamic declarations and syntax ambiguity are explicitly unknown. A missing required parser fails capture. Source bytes and historical paths remain available even when symbols cannot be extracted.

Run `mise exec -- python3 -m unittest tests.test_knowledge_capture tests.test_capability_knowledge -v`. The registration example retains the previously inspected application snapshot at `09812d6bb245fe9360af813f7590c9313ff5a851`; this engineering change adds no application Resource, database or participant flow. Never include secrets, participant data or private proof payloads in records.
