# Vertical-slice implementation handoffs

This is the repository's development standard and reusable template for descriptive implementation maps. [AGENTS.md](../../AGENTS.md) establishes its workflow requirement. It creates no Product, Architecture, Domain, release or execution authority. Follow the hierarchy in [docs/README.md](../README.md); Plane remains the live delivery ledger. Source and tests establish what the implementation does. A discrepancy with governing law requires investigation, never silently treating a narrative as permission.

## Applicability and review

Apply prospectively after WELL-96's approved integration. Do not retroactively block completed slices or already-active WELL-7 proof work.

Every implementation PR records a short documentation-impact determination:

- A substantial new vertical slice or meaningful end-to-end Domain/cross-Domain capability requires a full handoff using the eight sections below, authored in that same PR.
- A material change to an existing flow, public owner interface, lifecycle, schema/invariant or recovery behaviour updates its existing handoff in that PR. Do not create another map of the same capability.
- Proof-only work updates the relevant proof section or adds a focused, linked addendum with scope, commands, observed evidence and limitations.
- A cosmetic change, trivial local helper or editorial correction may be exempt. State why it changes no meaningful system contract. Page count and number of changed files do not determine applicability.

Independent Master Gate must compare required documentation with the complete diff and source at the exact reviewed head. Missing or materially inaccurate required documentation means `CHANGES REQUIRED` for that PR. Documentation does not substitute for source review, tests or exact-head CI. A changed head invalidates prior certification. Preserve existing resulting-main reconciliation before Plane Done. No routine after-merge documentation ticket, unrelated blocker or second status ledger is required.

Keep handoffs under `docs/development/` and link them from [the documentation index](../README.md). Use a focused addendum beside the map when that improves readability. Do not add descriptive handoffs to governance/delivery routers, which route authority and semantic contracts.

## Authoring and maintenance

Record the exact implementation SHA and distinguish it from the documentation PR head. Link repository-relative source paths with exact module/function/action/constraint names. Use pinned GitHub links when discussing historical source or evidence. Every material technical claim must have a nearby source, migration, test or governing-contract link. Explain consequences and important boundaries rather than translating every source line into prose.

Before relying on a handoff, a future agent must resolve current source, migrations, tests, dependency versions, routed authority and live Plane. Compare them with the recorded SHA. Historical explanations and observed runs do not certify a later revision. Subsequent material changes must maintain the map in the same PR.

Never include credentials, key values, passwords/hashes, bearer tokens, capability URLs, envelope contents, participant data, privileged diagnostics or restricted proof payloads. Reference safe evidence locations and bounded results instead. Record genuine unresolved delivery work in Plane, after checking for duplicates.

For each section below, explain any non-applicable dimension rather than inventing machinery. This template is a checklist of questions, not a requirement to create Resources, workflows or infrastructure.

## Reusable template

### 1. Purpose, scope and version

Record the outcome, boundaries/non-goals, document revision, implementing ticket and PR, documentation PR, implementation Git SHA, relevant changed paths and downstream consumers. Link current governing references and relevant semantic contracts. Distinguish historical contract status prose from live execution state. Require current-source verification before reuse.

### 2. Architecture, sequence and ownership

Give an ordered request/event path with source links from the real entry point through owner interfaces to persistence and external boundaries. Name the authoritative Domain for each durable truth. Explain transaction versus external-I/O boundaries and why consumers must preserve them.

### 3. Ash map

Link the actual Domains and Resources, supported caller interfaces, private actions, arguments, policies, validations, changes, preparations and relationships. Explain relevant AshPostgres, AshAuthentication, AshOban or other extension use. Distinguish a callable Elixir function from a supported public business interface. Do not repeat the entire DSL.

### 4. Important interface contracts

For meaningful functions/actions, name parameters, normal and error returns, callers/callees, side effects and trust/authorization assumptions. Include exceptional failures when material. Link exact symbols. Do not invent stronger guarantees than the implementation provides or catalogue trivial helpers.

### 5. Lifecycle, failure and recovery

Describe states, transitions, guards, terminal outcomes, authorization, concurrency arbitration, immutable operation binding, idempotency, retry/exhaustion, rollback and restart/recovery/reconciliation. Separate implemented controls from later obligations. Explain who can reconstruct durable work after failure.

### 6. Persistence and consistency

Link tables, migrations, unique/check/FK constraints, correctness indexes, ownership, transaction participants and async schedules. Separate authoritative rows from projections and job state. Note data migration/backfill and reversal hazards. Explain what commits or rolls back together.

### 7. Tests, proof and evidence

Link executable tests, cases/catalogs, reproducible commands, toolchain/dependency assumptions and exact-SHA CI evidence. Label observed runs, historical evidence and unexecuted commands separately. State coverage limits and outstanding risks. Never describe partial proof as full certification.

### 8. Future-agent extension guide

Explain where to build next, which owner interfaces callers should use, internal implementation boundaries, compatibility constraints and prohibited shortcuts. Link live Plane work for outstanding obligations. Include a cold-start walkthrough record: follow the map alone to the entry point, public Ash interfaces, constraints, lifecycle/failure controls and tests, then verify each against source. Record and fix discrepancies before review.

## Concrete review examples

A new registration capability requires the full [P8-05 map](p8-05-registration-handoff.md). A reviewer follows the entry point, `Identity.register/1`, acceptance transaction, migrations and proof tests at the recorded SHA. An inaccurate claim that an open MessageIntent means email delivery succeeded requires correction in the same PR.

A future proof-only PR extending registration contention evidence updates section 7 of that map or adds a linked proof addendum. It records the new test identifiers, exact reviewed SHA, commands/results and remaining obligations. It does not restate the entire registration flow. WELL-7 is an illustrative proof scope, not retroactively subject to this adoption gate.

A private formatting helper that changes neither an owner interface nor behaviour can record: "Handoff exempt: local formatting helper only; no flow, lifecycle, persistence or recovery contract changes." A material change to replay expiry instead updates the existing lifecycle and proof sections, even if its code diff is small.
