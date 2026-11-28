---
name: repository-reconnaissance
description: Use when working in an existing repository where current documentation, governance, tickets, refs, dependencies, or implementation state may constrain planning, grilling, specification, implementation, or review.
---

# Repository Reconnaissance

Establish the current factual and authority baseline before design or implementation decisions are made.

**Reconnaissance discovers truth; it does not make design decisions.**

## Inspect

Inspect only what is relevant to the requested scope:

1. Current canonical repository, branch/ref, and exact SHA where material.
2. Effective `AGENTS.md`, `CLAUDE.md`, or equivalent scoped instructions.
3. Repository source-of-truth/navigation entrypoint.
4. Current authority manifest, authority hierarchy, or repository equivalent.
5. Applicable Product, Architecture, Domain, Roadmap, operating, frontend, engineering, security, or other governing documents.
6. Relevant ticket, Feature Pack/JIT contract, accepted spec, decision record, proof contract, PR, gate, blocker, or dependency.
7. Relevant current implementation, tests, migrations, configuration, and installed dependencies.
8. Current external package/API facts when materially required, using primary sources.

Follow references only as far as needed to resolve the current scope. Do not read the entire repository ceremonially.

## Rules

- Live canonical state wins over chat summaries, memory, uploads, stale branches, handoff summaries, and historical snapshots.
- Current authority wins over superseded or archived material.
- Do not assume documents have equal authority; discover and obey the repository's declared hierarchy.
- Treat already-settled decisions as constraints, not questions to reopen.
- Distinguish verified fact from user report, inference, and recommendation.
- Verify material completion/status claims against the live repository when access is available.
- Do not mutate repository, tickets, branches, PRs, or external state during reconnaissance unless explicitly requested.
- If applicable sources genuinely conflict and the hierarchy does not resolve them, classify `CONTRADICTION / NEEDS AUTHORITY`. Do not invent a resolution.
- If the exact relevant ref or state changes, prior reconnaissance is stale where that change could affect the conclusion.

## Required output

Produce a concise **Repository Baseline**:

```text
Canonical state
- repo/ref/SHA:
- effective instructions:

Applicable authority
- ...

LOCKED
- ...

OPEN
- ...

CONDITIONAL / BLOCKED
- ...

CONTRADICTIONS / NEEDS AUTHORITY
- ...

Relevant implementation baseline
- ...

External facts requiring current verification
- ...

Safe frontier
- decisions that may now be explored or grilled
```

Omit empty sections only when their absence is itself unambiguous.

The **Safe frontier** contains only decisions that are genuinely unresolved after applying current authority and repository evidence.

## Freshness

Refresh reconnaissance when any material input changes, including:

- repository/ref/SHA;
- governing authority;
- ticket, gate, or dependency state;
- accepted spec or decision;
- relevant implementation;
- material package/API version.

Refresh only the affected parts when the unchanged baseline remains valid.

## Completion gate

Reconnaissance is incomplete when:

- current canonical state is unknown where it matters;
- applicable authority has not been resolved;
- supersession/archive status could change the conclusion;
- a relevant blocker or dependency was ignored;
- material existing implementation was not inspected;
- a contradiction was silently resolved;
- a material factual claim relies only on memory when it can be verified;
- a status or completion claim is accepted from a handoff without checking the available primary source.

When used before `grilling`, hand the **Safe frontier** to the Grill. Locked decisions remain constraints; contradictions remain blocked.
