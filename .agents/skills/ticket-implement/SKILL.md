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
- the likely files/resources/migrations to touch;
- documentation impact under `docs/development/implementation-handoff-standard.md`: canonical capability map update, proof update/addendum, or justified semantic-map exemption.

Create or maintain the required canonical capability JSON in the same implementation PR. Do not author a duplicate Markdown handoff. Record the implementation SHA, link real source symbols and tests, and distinguish observed evidence from future obligations. Material follow-up changes maintain the existing map. Apply prospectively after WELL-96 integration; do not retroactively block completed work or already-active WELL-7. These maps are descriptive, never governing or live execution authority.

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

Follow `AGENTS.md` "Verification stages and failure diagnosis" throughout implementation. Use focused checks while developing. Diagnose a failed broad command before another broad run; record command/SHA, classify the cause, reproduce narrowly, correct and prove the correction before returning to the stable-candidate gate. Do not repeat expensive gates on unchanged inputs without a recorded diagnostic reason.

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

### Public interface documentation and typespecs

For every new or materially changed public Domain or application interface:

- Use `@moduledoc` to explain a public module's responsibility, authoritative ownership, and primary integration boundary.
- Use `@doc` to describe externally meaningful functions, including authorization assumptions, side effects, failure results, and idempotency/retry semantics where relevant.
- Use `@spec` to describe public function inputs and success/error results. Prefer meaningful types over broad `term()` annotations where practical.
- Use `@type` or `@typep` when shared domain data, lifecycle states, or return contracts benefit from named types.
- Use `@impl true` for behaviour callbacks where applicable.

Internal implementation modules may use `@moduledoc false` and `@doc false`. Do not require documentation or typespecs for every private helper, trivial function, or Ash DSL declaration.
Cross-Domain interfaces must make the owning Domain and authorization boundary understandable without introducing competing business authority.
These annotations complement the existing source-linked capability maps; they do not replace them or require duplicate documentation.
Apply prospectively to code created or materially changed within the ticket. Do not perform unrelated documentation cleanups.


## 7. Control scope and discovered work

Implement the ticket acceptance contract only.

If you discover adjacent work that is material but not required to complete this ticket:

- record it in Plane;
- link dependencies where appropriate;
- do not silently absorb it into the current PR.

Do not mutate Product/Architecture/Domain/Roadmap or semantic contracts merely to memorialise JIT learning. Governance remains read-only unless a deliberate semantic change or proven upstream contradiction requires amendment.

## 8. Automatic knowledge capture before review

After applicable local checks, commit the stable source and run the existing OCR checkpoint against that committed SHA. If needed, open a Draft PR after the identity preflight below and push the source checkpoint. At the review checkpoint, generate the PR history record from live PR metadata and the WELL ticket already identified in implementation context. Export metadata with `gh api repos/Carpe-Diem-Media/NewYou/pulls/NUMBER` and run `mise exec -- python3 -m tools.knowledge_capture generate --metadata-json /tmp/pr.json --ticket WELL-N`. The ticket argument is explicit; the tool does not infer it from the PR title or body. GitHub metadata validates repository, PR, base, head and URL. The record does not copy PR prose, author details or Plane state. Do not add a manual receipt or Plane-unavailable explanation.

Commit `docs/development/knowledge/history/pr-NUMBER.json` before final review. Regenerate it if source or base changes, then request fresh review and CI. Do not regenerate for prose, author or Plane-state changes. Foundation Integrity checks the exact event binding and record with `mise exec -- python3 -m tools.knowledge_capture check --metadata-json "$GITHUB_EVENT_PATH"`; when `--ticket` is omitted, check uses stable tickets in the committed record. If supplied, the ticket must agree. Keep the mechanical record and canonical capability map; do not create a duplicate PR dossier. A final approval must never be followed by a generated commit.

## 9. Verify before handoff

**REQUIRED SUB-SKILL:** use `code-change-verification` before claiming the ticket is ready for review.

At minimum:

- run focused tests while iterating;
- run the repository-required engineering checks from `AGENTS.md` and the verification skill;
- inspect generated migrations/constraints and persistence semantics;
- run architecture/code-generation checks when applicable;
- run `git diff --check` or the repository equivalent;
- inspect the complete final diff;
- verify required handoff source links and material claims, including a cold-start walkthrough for a new substantial slice, against the exact head;
- resolve the exact base and head SHAs;
- verify no secrets/sensitive payloads leaked into code, logs, fixtures, jobs, or evidence;
- **after applicable local checks pass**, complete the independent OCR checkpoint in `code-change-verification` for material engineering changes, preserving findings and coverage exclusions without automatically editing code. Document a reasoned exemption for trivial/cosmetic or documentation-only changes.

For DB-dependent commands, use the DevCore workflow in `AGENTS.md` when configured.

Do not claim a check passed unless you observed it pass. Separate unrelated pre-existing failures from PR-caused failures with evidence; do not hide either.

Check new or materially changed public Domain/application interfaces for appropriate @moduledoc, @doc and @spec coverage. Correct meaningful omissions before handoff, or record a narrowly justified exemption. Do not block compliant Ash DSL or private implementation code merely for missing annotations.

## 10. Open the PR and hand off exact evidence

Before creating or updating a routine PR, run `gh api user --jq .login`. It must return `JC-Agents`. Run `python3 -m tools.newyou_attest pr-preflight`, or add `--pr NUMBER` for an existing PR to verify its author too. Stop on wrong/missing authentication or a founder-authored PR. Do not request founder credentials. `JCSchoeman96` independently reviews the exact final head; the agent cannot approve its own work.

When the implementation and required local verification are review-ready:

1. create or update the PR;
2. confirm the PR contains only authorised ticket scope;
3. include an `OCR Review Findings` section containing the scanned implementation SHA, all advisory findings/exclusions and preliminary assessments (or an explicit exemption), as required by `code-change-verification`; do not auto-fix OCR findings;
4. move Plane `In Progress → In Review` (or return `Changes Requested → In Review` after corrections);
5. record material JIT choices and discovered work in Plane/PR evidence where useful;
6. hand off for independent Master Gate review, including OCR adjudication, the documentation-impact determination and handoff audit. Missing or materially inaccurate required documentation means `CHANGES REQUIRED` for this PR. Do not create a routine after-merge documentation ticket or unrelated blocker.
7. follow the eligible founder-development route in the merge-gate procedure. ChatGPT Master Gate completes the technical review and publishes one authenticated JCSchoeman96 APPROVED review for the final head. That review is both technical approval and standing merge authorization. Do not add a second comment or a base-SHA line. Keep any stronger approval that an actual governing or external obligation requires.

Report:

- Plane ticket and final state;
- branch and PR;
- base SHA and exact head SHA;
- concise diff/scope summary;
- material JIT decisions and why they are compliant;
- migrations/constraints/lifecycle implications where relevant;
- tests/checks actually run and observed results;
- OCR command, scanned implementation SHA, findings/coverage and Master Gate handoff (or documented exemption);
- discovered/deferred Plane work;
- remaining review risks or known non-PR failures.

Do not self-certify merge authority. For eligible work, use the read-only native-candidate check, normal exact-head merge, and read-only native-result check documented in the merge-gate procedure. Verify current branch protection and CI before merging. If the merge response is uncertain, inspect the PR and `main` before any further action. Move Plane to Done and take the next dependency-cleared Ready ticket only after resulting-main verification succeeds. Stronger governing approvals remain mandatory where required.

PR #224 remains under current-main requirements. It needs explicit owner authorization for the exact merge transition after fresh complete review and CI. Collection-only comment 6821263762 is not authorization. Do not self-approve or self-merge it. CODEOWNERS read from the base cannot enforce review on this PR.

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
- wait for the nightly Foundation Full for ordinary implementation; PR delivery uses Foundation Smoke and applicable Application CI/Hex lanes;
- open a review-ready PR with known required verification left unrun or silently failing.
