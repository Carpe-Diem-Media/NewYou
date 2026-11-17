---
name: tdd
description: Elixir/ExUnit/Ash-first test-driven implementation for NewYou Ready tickets and material regression fixes. Use alongside repository ticket-implement and governing verification instructions, never instead of them.
---

# NewYou — Test-Driven Development (Elixir, ExUnit, Ash)

## Authority and entry

This skill is a focused **testing technique**, not an independent planning, authorization, governance or merge workflow.

1. Start with current repository `AGENTS.md`, `.agents/skills/ticket-implement/SKILL.md`, the live documentation routers and the specific Ready Plane ticket (or explicitly authorized continuation).
2. Read the actual source, relevant tests, `mix.exs`, `mix.lock`, `.tool-versions`, migrations, and generated `ash-framework` skill/references before assuming an API. Current checked-out source and authority override examples here.
3. Preserve the governing risk classes (`LOW`, `STANDARD`, `HIGH`), applicable lifecycle/ownership requirements, and the existing local-checks → OCR → exact-final-head CI → independent Master Gate sequence.
4. Never demand a fresh `/grilling`, a new user confirmation of an ordinary test seam, or a new document when the Ready ticket and current source already establish the necessary contract. Escalate only under the repository's existing rules.
5. Apply this Elixir technique when Elixir/Ash behaviour is under implementation; proven non-executable documentation changes still use their own applicable contract checks rather than forced database-backed ExUnit tests.

## 1. Choose a meaningful seam

Start from existing consumer-visible behaviour and owner interfaces. Prefer:

- **Domain:** a real `Ash.Domain` code interface or existing owner/application API, using actual Ash actions and authorization policies.
- **Delivery:** `NewYouWeb.ConnCase`, HTTP controller or LiveView tests when routing, sessions, CSRF, localization, public copy or browser behaviour matters.
- **Durability:** read-only observations of committed state, constraints, audit or queues, through appropriate test helpers, when success/error results alone cannot establish the invariant.
- **Pure logic:** focused internal/module tests for calculations, transformations or algorithms where these give stronger, cheaper signal than a full end-to-end path.
- **Failure boundary:** actual retry/recovery, time/clock, provider and restart seams when that failure mode is part of the contract.

Do **not** mandate tests only at public interfaces when this would miss a material invariant. Do not mock an owning Ash action merely to claim its behaviour was proved. Do not create service wrappers solely to produce an easier mock. See `tests.md` and `mocking.md`.

## 2. Define the proof before implementing the mechanism

Inside the ticket's **existing implementation plan**, derive a Behaviour and Proof Matrix from acceptance criteria, governed invariants and significant failure modes. Do not create a duplicate standalone dossier.

For each **material** behaviour record: intended outcome; test seam; valid fixture preconditions; permitted control; forbidden outcome; durable state/side-effect expectations; applicable lifecycle, authorization, concurrency, idempotency, retry and recovery cases; and the focused test command.

- `LOW`: proportionate testing; no ceremonial matrix for trivial helpers.
- `STANDARD`: meaningful successful behaviour, rejection and boundary cases.
- `HIGH`: evaluate the existing Engineering Standards proof menu. Record applicable items, justified omissions, and what would falsify each high-consequence guard; reviewer agreement is governed by the existing policy.

An error-only negative test is insufficient if it could fail for the **wrong reason**. Make all unrelated prerequisites valid, prove a permitted control can traverse the boundary, change only the target condition, and inspect relevant durable effects. Assert more than one property when multiple observations are necessary for one behaviour.

## 3. RED → GREEN → REFACTOR, one vertical behaviour at a time

1. **RED:** write a focused ExUnit test against the chosen existing seam. Run it using the pinned runtime and correct DevCore TEST profile. Confirm it fails for the **intended behavioural reason**, not setup, missing files, expired unrelated proof, or shared-fixture interference.
2. **GREEN:** implement the smallest compliant change through the owning Ash Domain/resource/action or appropriate boundary. Do not duplicate authority or speculate beyond the ticket.
3. **REFACTOR:** simplify the implementation and tests while keeping the relevant tests green. Refactor inside ticket scope; do not postpone essential maintainability work to a different review process.
4. Repeat for the next behaviour. Design a broad proof matrix up front, but **implement and exercise tests incrementally**, not as a large speculative batch.
5. For a defect, first prove the historical failure with a focused regression when technically possible. Keep the regression permanently.

Use the currently pinned form of commands, for example:

```bash
# A focused test; use a real path and line from the current checkout.
mise exec -- devcore-project run test -- mix test test/new_you/identity/password_session_test.exs:85

# Final broad engineering gates are owned by the existing implementation/
# verification workflow; do not invoke them from TDD iterations.
```

Do not run `mix check` after every edit or repeat an unchanged failed broad suite without diagnosis. The final applicable checks remain mandatory before handoff.

## 4. Make tests sensitive to real defects

- Assert the actual consumer outcome **and** consequences where material (state, authorization, no forbidden delivery, audit, replay, retry, privacy). An `{:ok, _}` or `{:error, _}` tuple alone may be too weak.
- Use independent expected values. Don't calculate expected results by repeating the production algorithm.
- Keep a coherent behaviour per test; multiple meaningful `assert`/`refute` statements are appropriate.
- Test the owner path with real Ash interfaces, policies, constraints and migrations. Read-only DB inspection is allowed for proof, not ordinary Repo/raw SQL/Ecto.Multi business writes.
- For selected high-consequence guards, use a **disposable isolated copy** to disable or invert a guard. Verify the targeted test fails for the intended violation, restore correct code and rerun. Do not mutate the shared worktree or shared infrastructure. Record a justified alternative when technically impractical; no universal mutation framework or coverage threshold.
- Prefer deterministic faults, clocks and provider seams; restore any process/application state. Keep global-state, fault-injection and restart tests synchronous where required.

## 5. Test isolation and evidence

NewYou has a shared DevCore TEST allocation. Respect current `NewYou.DataCase`, `NewYouWeb.ConnCase`, approved fixtures, sandbox process ownership, setup/cleanup and safety controls. Never reset/recreate DEV or TEST, provision roles, manually purge unrelated rows, disable triggers or globally force `async: true` to make tests pass. Diagnose contamination and runner assumptions rather than weakening proof.

Keep tests independent of a developer's already-built assets or local paths; verify relevant CI prerequisites. Record actual RED reason, GREEN result, focused commands, applicable proof menu omissions, sensitivity outcome/alternative and remaining risks in the existing ticket/PR evidence. Independent verification and exact-head CI remain the last word, not the author agent's self-assessment.

## References

- `tests.md`: NewYou-specific ExUnit examples, isolation and anti-patterns.
- `mocking.md`: external-boundary doubles and safe fault injection.
- Existing `.agents/skills/ash-framework/SKILL.md` and its `references/ash/testing.md` are the framework-focused reference; prefer installed/version-matched API evidence.
