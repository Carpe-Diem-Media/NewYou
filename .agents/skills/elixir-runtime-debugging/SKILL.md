---
name: elixir-runtime-debugging
description: Diagnose unexplained Elixir/OTP, Ash, Ecto/PostgreSQL and ExUnit behavior in NewYou using focused source inspection, IEx, DEV Tidewave, selective BEAM tracing, and version-matched telemetry. Use for intermittent failures, transaction/lifecycle errors, process races, and CI-only regressions before speculative fixes; not a separate implementation or review gate.
---

# NewYou — Elixir Runtime Debugging

## Purpose and boundaries

Find **the first operation whose observed outcome differs from the required outcome**, explain why it differs, and provide the smallest reproducible correction or discriminating next experiment. This is a *diagnostic technique*, not a second planning, TDD, verification, or merge workflow.

Follow `AGENTS.md` and current repository/document routers. For an authorized Ready-ticket implementation or explicitly authorized continuation, use `ticket-implement`; for regression tests use `tdd`; for final checks use `code-change-verification`; for Ash work load `ash-framework` and its relevant references. Read actual source, `mix.lock`, `.tool-versions`, migrations, fixtures and test configuration. Verify version-sensitive APIs against installed dependencies or matching official documentation. **Do not create a new ticket, governance document, CI gate, or dependency merely to run this skill.**

A read-only investigation may inspect evidence without an implementation ticket. Mutating application code, tests, PRs or Plane still requires the repository's execution authority. Temporary experiments may use an **isolated scratch worktree and isolated disposable TEST environment** where authorized; never mutate a shared resource.

## Fast path: symptom → tool → discriminating observation

Start with the narrowest relevant path. Do not run every tool by default.

| Observed problem | First tool or source | Evidence that can discriminate causes |
| --- | --- | --- |
| Unexpected Ash action/state result | Actual Resource/Domain interface and `Ash.Resource.Info`, version-matched Ash source, optionally IEx | Action/guard inputs, typed result or failure classification, persisted state |
| `with` chain returns generic error | Read every branch and error normalization; focused TEST-only observation before masking | **First failed operation**, returned error vs exception, not just outer sentinel |
| Process exit, race, mailbox or supervision | `Process.info/2`, monitors and supervision tree; selective `:sys`/BEAM tracing | Correct PID/node, message order, exit reason, ownership, scheduling |
| Transaction/connection problem | Ecto Repo query telemetry, DBConnection docs/events, PostgreSQL transaction/lock evidence | Queue/query time, transaction duration, exact failing child/connection, commit/rollback |
| CI-only/intermittent test | Exact SHA, runner, seed, ExUnit scheduling, fixture scope and other live processes | One controlled difference between focused and suite-context runs |
| DEV application runtime question | Existing Tidewave `project_eval`, `get_docs`, `get_source_location`, `get_logs` **if available** | Observed running DEV behavior; never assume this proves TEST behavior |
| Generated or macro-dependent behavior | Ash DSL introspection first; `quote`/AST expansion only when needed | Actual compiled action/transition and return shape, not a guessed generated path |
| Harness/output protocol | Child/parent stage markers, Port buffers, checkpoint handshake, independent durable read | Marker emitted vs recognized; genuine cut vs normal exit; cleanup confirmed |

### Triage (one short pass)

1. Record exact Git SHA/branch, source path + line, reproduction command, output, runtime versions, environment and observed durable state. If it is a PR, record its **actual** head and base; do not infer from `HEAD~1`.
2. Draw only the relevant boundary chain: caller → owner interface → Ash action/transaction → database or external worker → observer/assertion. Identify which process/BEAM owns each step.
3. State **two or three competing hypotheses** and the single smallest observation that separates them. Mark `OBSERVED`, `INFERRED` or `UNKNOWN`; do not promote a neighboring log line into causal proof.
4. Run a **bounded** focused experiment in the correct environment. Stop after a decisive observation. If none appears, report the missing evidence and the next smallest experiment instead of blindly rerunning the full suite.
5. Only after attribution: apply TDD's focused RED → GREEN → REFACTOR (if implementation is authorized), then hand off to the existing final verification workflow. One passing rerun is not proof of historical root cause.

## Elixir runtime commands and safe scope

NewYou requires `mise exec --` for **all local** `mix`, `elixir` and `iex` commands. Record `mise current` and `mise exec -- elixir --version` for the current worktree.

```bash
# Inspect the resolved pinned toolchain. This does not touch the database.
mise current
mise exec -- elixir --version

# Candidate interactive shell for the existing DEV profile only.
# Verify the installed DevCore wrapper supports interactive IEx first;
# this invocation has not been executed as part of the skill authoring.
# This is NOT a connection to an independent TEST subprocess.
mise exec -- devcore-project run dev -- iex -S mix

# Normal focused ExUnit execution uses the repository-managed TEST profile.
# DO NOT run this against the shared TEST allocation for destructive,
# subprocess, concurrency, fault-injection, mutation or timing experiments.
# Use it only where the test and environment are explicitly approved.
mise exec -- devcore-project run test -- mix test test/PATH_test.exs:LINE
```

Use `h Module` / `h Module.function/arity`, `i value`, module exports, and carefully selected `Process.info(pid, [...])` to understand real runtime shapes. Prefer read-only observation. `:sys.get_state/1` can expose sensitive state and should only be used on confirmed, eligible processes; never dump state into a shared log. Avoid evaluating business writes through Tidewave/IEx merely to inspect their behavior.

### Tidewave boundary

NewYou's `tidewave` dependency is **DEV-only** and `NewYouWeb.Endpoint` mounts its plug only in `Mix.env() == :dev`. Use its existing capabilities if the current agent/session is connected; do not assume a Tidewave MCP session exists. A DEV `project_eval` runs in the DEV application; it **does not trace a separate OS/BEAM TEST child or a CI process**. Never enable Tidewave in TEST/production, expose new runtime endpoints, or weaken the existing boundary for debugging. If Tidewave is unavailable, use source inspection and isolated IEx/telemetry; do not block the investigation on it.

### Process and BEAM boundary

Verify the exact PID **and node**. Parent-process tracing does not automatically follow a separate BEAM started via `Port` or an OS process group. For a timing-sensitive TEST child, attach only scoped instrumentation **inside that child** or use an explicitly controlled runtime channel. Prefer targeted monitors and process-local data to global `:erlang.trace`/`:dbg` tracing. Unregister handlers, stop tracers and clear process-local state in `after` blocks. Do not pause a 250 ms transaction with `IEx.pry`, breakpoints or an interactive receive; that changes the measured behavior. Do not assume `async: false` means eight unrelated ExUnit modules run simultaneously merely because `--max-cases 8` was supplied; inspect actual ExUnit semantics and surviving workers.

### Ash, transaction and PostgreSQL boundary

Identify the precise transition order: trace marker **before** an action is not proof that the action succeeded, and a successful in-transaction write is not proof of commit. Check the existing owning Ash Domain interface, state, guards, actor/authorization context, identities, constraints, version and idempotency. Inspect actual `Ash.update` / `Ash.transact` return forms for the **pinned** version. A catchall `else _` or transaction wrapper may turn distinct errors into the same neutral response; preserve the public contract while capturing safe TEST-only categories at the first loss of information.

For Ecto query timing, use the **actual Repo `:telemetry_prefix`** plus `[:query]`; matching Ecto versions document `:queue_time`, `:query_time`, `:decode_time`, `:total_time` measurements in native time units. Metadata can include SQL, parameters and raw result/errors: **reduce to fixed categories before emitting any diagnostic output**. `[:db_connection, :connection_error]` reports checkout errors; it is not a complete account of transaction disconnects. Connected/disconnected events require compatible listener setup; absence of the checkout-error event does **not** disprove a connection loss after checkout. Correlate a database failure to the *same* child, attempt and transaction; logs from neighboring timeout-control tests are not causal evidence. For a connection timeout hypothesis, distinguish queue wait, checked-out lease duration, row-lock wait, and transaction rollback/commit.

Keep TEST instrumentation exception-safe, bounded and minimal. When attempting to classify an error, do not `inspect` full `%Ash.Error{}`, `%Postgrex.Error{}`, query metadata or user data into shared logs. Retain only explicitly approved class/category and measured duration. Correlation IDs are diagnostics, never an authorization mechanism or account identity.

## Test-design validity checks

- Separate **valid-request precondition** from the behavior the negative test intends to reject. An error alone may reflect unrelated fixture or database failure.
- Verify persisted consequences via an independent, correctly owned read after the relevant transaction or worker ends. Observing an uncommitted write does not establish durable state.
- For restart proofs, distinguish checkpoint **emitted**, checkpoint **recognized**, worker **actually terminated**, database **rolled back**, and retry **committed once**. A missing checkpoint cannot count as an interruption proof.
- Where the test intentionally has a 250 ms production timeout, do not broaden it or accept a different outcome merely to make CI green. A valid request that cannot reach a pre-commit checkpoint may indicate an availability issue, fixture issue or test scheduling issue; determine which.
- Use targeted, isolated test sensitivity checks (e.g. deliberately invalid expected state) only when they answer an important invariant, following the `tdd` skill. No universal mutation requirement and no new CI lane by default.

## Report (short, evidence-first)

Return the following in the existing ticket/PR handoff rather than another duplicate dossier:

1. **Observed facts:** exact source SHA, environment and first failed operation; cite source lines and diagnostic event owner.
2. **Competing explanations:** confirmed / supported / contradicted / unknown and the specific observation behind each.
3. **Experiment:** exact command, database isolation, attempt limit, instrumented processes, results and known observer overhead.
4. **Decision:** confirmed minimal fix, compliant TEST correction, or smallest remaining discriminating experiment. Explicitly distinguish unresolved historical cause from proven diagnostic improvement.
5. **Regression/impact:** what test would fail for the intended incorrect behavior, which obligations remain, and how work proceeds under the existing Plane/ticket review rules.

**Prohibited shortcuts:** speculative timeout increases, arbitrary retries until green, invented framework APIs, globally enabled tracing, unscoped dumps of request/connection data, shared TEST allocation experiments, replacing real rollback evidence with a marker, or treating a green CI check as proof of root-cause attribution.

## Primary documentation (use versions pinned by the current checkout)

- Elixir IEx/debugging: <https://hexdocs.pm/iex/IEx.html> and <https://hexdocs.pm/elixir/debugging.html>
- Ash Resource introspection (repository currently pins Ash 3.37.2): <https://ash.hexdocs.pm/3.37.2/Ash.Resource.Info.html>
- Ecto Repo telemetry (Ecto 3.14.3 reference): <https://ecto.hexdocs.pm/3.14.3/Ecto.Repo.html>
- DBConnection telemetry/transaction (2.10.2 reference): <https://db-connection.hexdocs.pm/2.10.2/DBConnection.html>
- Tidewave (repository currently pins 0.9.2): <https://hex.pm/packages/tidewave/0.9.2/files/README.md>

These URLs are lookup aids, not permission to upgrade dependencies or treat newer API behavior as already installed.
