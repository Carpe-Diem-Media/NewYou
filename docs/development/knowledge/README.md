# Capability knowledge and automatic change capture

Start with [identity.registration.json](identity.registration.json), the canonical registration map. Follow its source locators, then inspect current code, tests, governing authority and live Plane before reuse. The implementation revision identifies inspected source; per-file SHA-256 values bind bytes. This is descriptive knowledge, not governing authority or delivery status.

## Three kinds of evidence

- The JSON records under `history/`, named by PR number, record the exact PR change range, file status/modes/blob IDs/hashes, parseable Elixir declarations, changed tests and migrations. Each record describes historical changes, including removed source. GitHub supplies actual review, CI and merge status.
- `<capability_id>.json` describes source-verified ownership, public Ash interfaces, flow, lifecycle, invariants, failure/recovery, proof limits and extension points. Maintain one map per meaningful capability. Use [capability.schema.json](capability.schema.json). The agent contributes semantic facts with source locators, without manually enumerating every changed file or function.
- The `index` and `query` commands compute a lookup view from the requested Git tree. They do not create a database or commit another index. Historical references do not certify that a past symbol still exists.

## Agent capture before final review

The [ticket workflow](../../../.agents/skills/ticket-implement/SKILL.md) invokes these steps as normal agent work. The founder runs no commands.

1. Implement and test the ticket. Commit source changes. For a first PR, create it as a draft with its implementing WELL ticket in the title or description. Push the source checkpoint before fetching metadata, so GitHub's head matches the source revision.
2. Inspect the live Plane tickets and dependencies through the connected Plane integration. The agent exports those actual responses into a temporary receipt, using the format below. It is an attributed observation by the implementing agent, not independently verified CI evidence. No founder prepares this file. CI receives no Plane credentials and validates its structure and ticket linkage without claiming a live lookup.

   The receipt has `status: agent_verified`, `source: connected-plane`, the actual UTC `checked_at`, and an `items` array. Each item contains the actual `identifier`, `id`, `project_id`, integer `sequence_id`, `name`, `state` name and `description_sha256` of the connector's UTF-8 `description_stripped`. The WELL project ID is checked by the generator. Export this from the observed connector response without inventing missing values. If live verification is unavailable, use `--plane-unavailable REASON` instead of `--plane-context`; the record will explicitly remain unverified.
3. Save the live PR metadata and generate its record. Replace `NUMBER` with the actual PR number.

```sh
gh api repos/Carpe-Diem-Media/NewYou/pulls/NUMBER > /tmp/newyou-PR-metadata.json
mise exec -- python3 -m tools.knowledge_capture generate --metadata-json /tmp/newyou-PR-metadata.json --plane-context /tmp/newyou-plane-receipt.json
```

4. Commit `pr-NUMBER.json` under `history/` and push the final head before requesting review. Only that exact record is excluded from its own mechanical payload. Other history and capability changes remain visible. The committed record contains the exact base, merge base, source blobs and hashes, stable PR commit/check links, and the first Purpose/Summary section of the PR explanation as attributed intent. It never records its own final head SHA, an invented successful CI result or future merge status.
5. Foundation Smoke independently regenerates against the event's exact PR base/head and compares the committed record. It installs the parser only when changed Elixir source or extractor tooling needs it. Ordinary documentation changes still receive read-only record validation. Parsing never evaluates source. CI never commits changes or receives Plane write credentials. Changed source/base, tampering, invalid linkage or a missing record requires regeneration and fresh review/CI. No generated commit follows final approval.

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
