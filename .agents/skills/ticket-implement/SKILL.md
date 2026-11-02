---
name: ticket-implement
description: Use when implementing a specific NewYou Plane ticket that is Ready for fresh implementation, or when explicitly resuming the same ticket after implementation has already begun.
---

# NewYou Ticket Implementation

## Purpose

Turn one authorised Plane ticket into a verified, review-ready PR.

This is an **implementation workflow**, not a second planning/governance cycle. `AGENTS.md` is the repository contract and takes precedence over this skill if they ever diverge.

For fresh work, start only from a dependency-cleared Plane ticket in `Ready`. Normal unresolved engineering detail is JIT work to decide and implement, not a reason to reopen `/grilling`, `to-spec`, or `to-tickets`.

## Entry modes

### Fresh implementation

A specific Plane ticket must be identified and live state must show `Ready`.

Do not choose unrelated work or infer authorisation from `Backlog`, `Planning`, `Blocked`, `In Progress`, `In Review`, `Changes Requested`, `Ready to Merge`, or `Merging`.

### Explicit continuation

When explicitly asked to continue the **same** ticket after implementation has begun, `In Progress` or `Changes Requested` may be valid. Confirm the existing branch/PR belongs to that ticket before changing code. Do not use an in-flight state to pull unrelated scope.

If the ticket cannot be identified or live Plane state cannot be verified, do not start fresh implementation.

## 1. Reverify execution authority

Before repository mutation:

1. Fetch the live Plane ticket, acceptance criteria, relations, blockers, and dependencies.
2. Confirm the ticket state is valid for the entry mode.
3. Confirm every required dependency is actually resolved.
4. Resolve current `main` and inspect whether newer code invalidates, supersedes, or already satisfies the ticket.
5. Confirm the acceptance criteria remain coherent and executable.
6. Check that no already-known upstream contradiction prevents the work.

For a fresh ticket, if the gate passes, move `Ready → In Progress` immediately before implementation begins.

If the gate fails, do not modify application code. Record the exact blocker/evidence in Plane and report it.

## 2. Perform focused reconnaissance

Inspect only what is needed to implement the ticket correctly:

- `AGENTS.md`, then the current documentation entrypoint and routers it names;
- routed Product/Decision, Architecture, Domain, Roadmap, and supporting authority relevant to this ticket;
- relevant semantic Feature/JIT/proof contracts;
- the actual implementation seam in code;
- relevant tests, migrations, configuration, and dependency versions;
- relevant generated framework skills.

Follow the live router's deep-reference field only for exact source or identifier tracing. Do not load the historical archive by default. Do not hardcode a prior documentation layout or router field in this skill.

When Ash-backed behaviour or durable state is involved, **REQUIRED SUB-SKILL:** use `ash-framework` and relevant generated references. Verify material package/API facts from current official primary sources.

Use Igniter first where it safely supports structural or package changes.

## 3. Establish the implementation contract

Before coding, state a concise working plan containing:

- the acceptance criteria being implemented;
- locked ownership/invariants/lifecycle requirements;
- the existing code seam;
- material JIT decisions that must be made;
- the test strategy, including failure/concurrency/idempotency cases where applicable;
- the likely files/resources/migrations to touch.

Do not wait for human approval of ordinary compliant implementation choices. Continue unless an unresolved choice meets the escalation threshold in `AGENTS.md`.

## 4. Classify discoveries correctly

Apply the `AGENTS.md` decision model exactly:

- `LOCKED` → follow authority.
- `JIT IMPLEMENTATION CHOICE` → choose the simplest compliant option, prove it, continue.
- `UPSTREAM GOVERNANCE CONTRADICTION` → STOP only when the three-part contradiction test is satisfied.

### JIT is the default for implementation representation

Do **not** block merely because governance does not name the exact Resource, table, field, action, index, constraint, transaction composition, retention mechanism, helper module, migration shape, or framework mechanism.

When multiple compliant JIT options exist, choose using this order:

1. preserve the authoritative Domain owner and existing interfaces;
2. preserve locked business/lifecycle/security semantics;
3. prefer existing project/Ash patterns;
4. prefer database-enforced invariants over process-local authority;
5. minimise new dependencies, authorities, and moving parts;
6. prefer the design with the clearest failure/recovery and concurrency behaviour;
7. prefer the design that is easiest to prove with focused tests.

Do not ask the human to choose among ordinary compliant alternatives.

### Distinguish execution blockers from governance contradictions

A newly discovered concrete prerequisite may be an **execution blocker** without being a governance contradiction: for example, a required upstream interface is absent despite its dependency being marked complete.

For an execution blocker, record the missing prerequisite, evidence, affected acceptance criteria, and required owner/action in Plane. Do not invent a governance problem to explain it.

For an upstream governance contradiction, record all three required proofs:

1. exact governing statements that conflict or are insufficient;
2. why no reasonable compliant JIT implementation can satisfy them;
3. the material durable semantic that would otherwise be invented or changed.

Without all three, continue as JIT.

## 5. Model meaningful lifecycle behaviour

When the ticket creates or changes a meaningful lifecycle, explicitly establish in code/tests as applicable:

- states and terminal states;
- transitions;
- guards and invariants;
- side effects;
- authorization;
- concurrency/arbitration;
- idempotency and immutable request binding;
- retries and replay behaviour;
- failure rollback;
- restart/recovery/reconciliation.

Durable lifecycle truth belongs to the owning Domain and durable store, never process-local memory, cache, provider state, PubSub, or UI projection.

Do not create a separate governance document merely to record these implementation mechanics.

## 6. Implement test-first

For each material behaviour:

1. write the smallest focused test that expresses the required behaviour;
2. run it and confirm it fails for the expected reason;
3. implement the smallest compliant change that makes it pass;
4. rerun the test;
5. refactor while keeping it green;
6. repeat for the next behaviour.

Include negative/failure-path tests and, where material, concurrency, idempotency, retry, rollback, authorization, and recovery tests.

For defects/regressions, reproduce the failure first where technically possible.

Use owning Ash interfaces for business writes. Do not create parallel ordinary Repo/raw SQL/`Ecto.Multi` business-write paths.

Do not add infrastructure or dependencies merely because they are convenient. Apply the authority and Ash-first rules in `AGENTS.md`.

## 7. Control scope and discovered work

Implement the ticket acceptance contract only.

If you discover adjacent work that is material but not required to complete this ticket:

- record it in Plane;
- link dependencies where appropriate;
- do not silently absorb it into the current PR.

Do not mutate Product/Architecture/Domain/Roadmap or semantic contracts merely to memorialise JIT learning. Governance remains read-only unless a deliberate semantic change or proven upstream contradiction requires amendment.

## 8. Verify before handoff

**REQUIRED SUB-SKILL:** use `code-change-verification` before claiming the ticket is ready for review.

At minimum:

- run focused tests while iterating;
- run the repository-required engineering checks from `AGENTS.md` and the verification skill;
- inspect generated migrations/constraints and persistence semantics;
- run architecture/code-generation checks when applicable;
- run `git diff --check` or the repository equivalent;
- inspect the complete final diff;
- resolve the exact base and head SHAs;
- verify no secrets/sensitive payloads leaked into code, logs, fixtures, jobs, or evidence.

For DB-dependent commands, use the DevCore workflow in `AGENTS.md` when configured.

Do not claim a check passed unless you observed it pass. Separate unrelated pre-existing failures from PR-caused failures with evidence; do not hide either.

## 9. Open the PR and hand off exact evidence

When the implementation and required local verification are review-ready:

1. create or update the PR;
2. confirm the PR contains only authorised ticket scope;
3. move Plane `In Progress → In Review` (or return `Changes Requested → In Review` after corrections);
4. record material JIT choices and discovered work in Plane/PR evidence where useful;
5. hand off for independent Master Gate review.

Report:

- Plane ticket and final state;
- branch and PR;
- base SHA and exact head SHA;
- concise diff/scope summary;
- material JIT decisions and why they are compliant;
- migrations/constraints/lifecycle implications where relevant;
- tests/checks actually run and observed results;
- discovered/deferred Plane work;
- remaining review risks or known non-PR failures.

Do not self-certify merge authority and do not merge unless explicitly authorised.

Any head change after review begins invalidates prior exact-head certification.

## Stop outputs

### Execution blocker

Report:

- ticket/state and current `main` SHA;
- exact missing prerequisite or contradiction in live execution state;
- concrete code/Plane evidence;
- acceptance criteria that cannot currently be completed;
- required next owner/action.

Do not call it governance unless the governance contradiction test also passes.

### Upstream governance contradiction

Report:

- exact conflicting/insufficient governing statements;
- why every reasonable compliant JIT implementation fails;
- the durable semantic that would otherwise be invented or changed;
- smallest upstream authority that must be reconciled;
- affected ticket scope and Plane evidence.

## Non-negotiable anti-patterns

Do not:

- treat unspecified implementation detail as missing governance;
- ask the human to choose ordinary engineering representation;
- reopen `/grilling`, `to-spec`, or `to-tickets` by default;
- create governance successors to document implementation learning;
- broaden ticket scope because adjacent work looks convenient;
- use derived/process-local state as business authority;
- bypass owning Domain/Ash interfaces for business writes;
- wait for non-blocking Foundation Full for ordinary implementation;
- open a review-ready PR with known required verification left unrun or silently failing.
