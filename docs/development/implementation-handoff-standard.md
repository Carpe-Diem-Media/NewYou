# Implementation knowledge standard

[AGENTS.md](../../AGENTS.md) requires implementation evidence in the same PR. This standard describes that evidence. It creates no Product, Architecture, Domain or execution authority. Follow [the documentation router](../README.md) and live Plane before implementation.

## One record for each purpose

Every implementation PR includes one automatically generated historical change record under `docs/development/knowledge/history/`, named `pr-<number>.json`. The extractor collects files, renames, deletions, source hashes, parseable Elixir symbols, changed tests and migration paths. Generate it at the review checkpoint with live GitHub PR metadata and the explicit WELL ticket from implementation context. Metadata validates repository, PR, base, head and URL; it does not supply ticket identity or PR prose. New records omit author, intent and Plane snapshots. Legacy records remain readable; do not mass-regenerate them. GitHub supplies current review, CI and merged status. A committed record never claims a future CI result or contains its own final commit SHA.

A substantial capability or material Domain/interface/lifecycle/schema change also creates or maintains one canonical `<capability_id>.json` under [knowledge/](knowledge/README.md), using [the existing schema](knowledge/capability.schema.json). The agent supplies source-verified semantics that extraction cannot establish. Update only the affected sections on follow-up changes. Do not duplicate this map in an eight-section Markdown handoff. Existing Markdown handoffs remain historical references. Migrate an existing handoff only when material work on that capability warrants it.

An ordinary internal, cosmetic or editorial PR needs its PR description and generated change record. State why a semantic map update is unnecessary. Proof-only work updates the relevant map's proof limits or links a focused addendum when needed.

## Required semantic knowledge

Capture the applicable facts in the canonical capability map:

- Stable capability ID, purpose, WELL ticket, source revision and source locators.
- Authoritative and collaborating Domains, real Ash interfaces/Resources/actions, caller restrictions and private implementation boundaries.
- Ordered request/event flow and transaction versus external-I/O boundaries.
- States, transitions, guards, side effects, terminal outcomes, authorization, concurrency, idempotency, retries, rollback and restart/recovery/reconciliation.
- Persistence ownership, actual migrations/tables/constraints/indexes, and any migration or reversal hazards.
- Executable regression tests, observed proof limits, safe extension points, prohibited shortcuts and known Plane follow-ups.

Explain non-applicable dimensions. Do not invent Resources, functions or lifecycle rules. Reuse the [registration map](knowledge/identity.registration.json) as the source-linked example. Function extraction establishes names and syntax changes; it does not establish business meaning.

## Agent workflow and independent review

For ordinary development, follow the development-first procedure in the [ticket workflow](../../.agents/skills/ticket-implement/SKILL.md) and this standard. ChatGPT Master Gate uses the same source-linked record and live Plane evidence during independent review; it does not create a second PR dossier.

Follow the agent commands in [the knowledge guide](knowledge/README.md) before declaring a PR review-ready. Generate the PR record once at the review checkpoint with metadata and the explicit ticket, then commit it before final review. Regenerate only after a source or base change. CI checks the exact GitHub event binding and committed record. All generated changes precede final approval. No post-approval commit, post-merge main write or separate documentation task is required.

Independent Master Gate compares the complete diff, capability semantics and linked source/tests at the exact reviewed head. Missing or materially inaccurate required knowledge means `CHANGES REQUIRED`. Schema, hashes and locator validation establish mechanical consistency; they do not prove semantic claims. A changed head invalidates previous review and CI evidence. Resulting-main verification remains mandatory before Plane Done.

Apply prospectively after WELL-96. Do not retroactively block completed work or already-active WELL-7. No routine after-merge documentation ticket or second execution ledger is required.

## Reuse and confidentiality

The current index is computed from the requested Git tree, normally current `main`, rather than committed as another database. Historical records describe past changes. Capability maps describe inspected source bytes and must be checked for drift before reuse. Future agents resolve current code, tests, dependencies, routed authority and live Plane. GitHub's PR and merge records establish final head/merge identities.

Record an implementation revision that contains the inspected source bytes, which may precede the documentation commit. Never invent a future self-referential SHA. Keep credentials, participant data, private diagnostics and restricted proof payloads out of records and documentation. Record genuine delivery gaps in Plane after checking for duplicates.
