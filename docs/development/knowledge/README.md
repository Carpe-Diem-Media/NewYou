# Capability knowledge and automatic change capture

Start with [identity.registration.json](identity.registration.json), the canonical registration map. Follow its source locators, then inspect current code, tests, governing authority and live Plane before reuse. The implementation revision identifies inspected source; per-file SHA-256 values bind bytes. This is descriptive knowledge, not governing authority or delivery status.

## Three kinds of evidence

- The JSON records under `history/`, named by PR number, record the exact PR change range, file status/modes/blob IDs/hashes, parseable Elixir declarations, changed tests and migrations. Each record describes historical changes, including removed source. GitHub supplies actual review, CI and merge status.
- `<capability_id>.json` describes source-verified ownership, public Ash interfaces, flow, lifecycle, invariants, failure/recovery, proof limits and extension points. Maintain one map per meaningful capability. Use [capability.schema.json](capability.schema.json). The agent contributes semantic facts with source locators, without manually enumerating every changed file or function.
- Interface entries require argument descriptions exactly when `arity` is nonzero. The JSON Schema expresses that relationship, and the repository's bounded validator enforces the declared schema subset.
- The `index` and `query` commands compute a lookup view from the requested Git tree. They do not create a database or commit another index. Historical references do not certify that a past symbol still exists.

## CI snapshots and historical records

Foundation Integrity generates an informational, nonmutating snapshot for each PR run. Open the workflow run in GitHub Actions to find its summary and the `pr-knowledge-<PR>-<run>-<attempt>` artifact. Artifacts expire after 14 days and are not authority. Snapshot failure is visible but does not block the required gate. A push, rebase or merge-based branch update produces a new run; advancing main alone does not guarantee one.

Existing `history/pr-*.json` records remain searchable with the commands below. New PRs do not require local history generation, checks or a committed record. Use GitHub PRs and commits for newer historical changes. A changed base does not require a knowledge-record commit; current-candidate CI and independent review remain required.

## Semantic maps and mechanical refresh

Create or maintain one map for meaningful capability or material Domain/interface/lifecycle/schema changes. Reuse existing interfaces and semantic copy identities. Explain non-applicable dimensions. An ordinary internal/cosmetic change needs a useful PR description, with a brief reason that no semantic map changed. Do not duplicate a JSON map in a long Markdown handoff.

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
