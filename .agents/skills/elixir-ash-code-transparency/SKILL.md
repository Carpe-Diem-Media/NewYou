---
name: elixir-ash-code-transparency
description: Use when auditing or changing Elixir, Ash, or Phoenix code where public API contracts, module documentation, typespecs, Ash DSL descriptions, lifecycle semantics, side effects, or agent discoverability may be incomplete, stale, duplicated, or misleading.
---

# Elixir Ash Code Transparency

## Overview

Make the code's real contract easy for humans and coding agents to discover without inventing certainty or duplicating executable framework semantics.

**Core principle:** establish the contract first; document the contract second.

Read `references/standards.md` before performing a focused audit or making transparency-related edits.

## When to Use

Use this skill for:

- `@moduledoc`, `@doc`, `@spec`, `@type`, `@typedoc`, `@opaque`, or `@impl` audits
- Ash Domain, Resource, Action, Policy, StateMachine, code-interface, or DSL-description reviews
- Phoenix controller, LiveView, component, channel, or boundary-documentation reviews
- lifecycle, transaction, side-effect, idempotency, error-contract, or API-discoverability work
- requests to make an Elixir/Ash/Phoenix codebase easier for agents to navigate

Do not invoke it merely because an unrelated `.ex` file changed.

## Required Workflow

1. **Discover authority.** Read repository instructions and declared architecture/domain sources of truth.
2. **Inspect before editing.** Read the relevant Ash DSL, all function clauses, behaviours, callers, tests, and existing types.
3. **Classify the surface.** Decide whether each target is public API, framework callback, internal implementation, or Phoenix delivery/UI code.
4. **Find discrepancies.** Treat disagreement between architecture, Ash DSL, specs, docs, tests, and implementation as a defect to investigate.
5. **Repair the strongest contract first.** Prefer executable/declarative contracts over prose. Do not duplicate Ash or Phoenix DSL facts unnecessarily.
6. **Document intent.** Add prose for responsibility, domain meaning, invariants, lifecycle semantics, side effects, and non-obvious constraints.
7. **Verify.** Run only checks supported by the repository. Never claim a check passed unless it was actually executed successfully.
8. **Report.** State inspected files, changed contracts, ambiguities, verification performed, and remaining risks.

## Non-Negotiable Rules

- Never invent a precise `@spec`, error union, lifecycle rule, or side-effect guarantee.
- Typespecs describe contracts; they do not runtime-enforce them.
- Use doctests only for deterministic, self-contained behaviour.
- Every meaningful domain lifecycle must explicitly expose states, transitions, guards, side effects, failure/compensation behaviour where relevant, and terminal states.
- Distinguish database transactions from external side effects.
- Phoenix must not become a second domain layer.
- Prefer current Ash semantics for the project's installed version; verify version-sensitive behaviour against authoritative docs or installed dependency source.

## Verification

Follow `AGENTS.md` and the existing
`code-change-verification` workflow.

During implementation, run only focused checks
needed to verify the current change.

Do not independently invoke broad engineering
gates such as `mix check`, `mix check.deep`,
the full test suite, OCR or CI merely because this
skill was loaded.

Reuse valid existing evidence where permitted.
The owning verification workflow runs all
applicable final gates on the stable candidate.

This skill does not waive any required check.
