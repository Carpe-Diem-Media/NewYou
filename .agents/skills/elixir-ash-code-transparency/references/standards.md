# Elixir + Ash + Phoenix code transparency reference

This is a subordinate technical reference for the `elixir-ash-code-transparency` skill, not a canonical NewYou Engineering Standard or a source of Product, Architecture, Domain, security or lifecycle authority. NewYou's authority hierarchy, `AGENTS.md`, routed Engineering Standards, installed Ash dependencies and actual code take precedence over guidance and examples here. Actual code establishes implemented behaviour; it does not override approved business authority.

All Elixir, Phoenix and Ash examples below are illustrative excerpts. `MyApp`, Orders, payment and ticket concepts describe hypothetical interfaces, not actual NewYou business interfaces or approved business rules. Snippets omit surrounding setup and enforcement; verify the real code, dependencies and authority before adapting them.

Its purpose is not "maximum documentation." Its purpose is **accurate, discoverable, non-duplicative contracts**.

A codebase is agent-friendly when a capable engineer or coding agent can answer these questions without reverse-engineering hundreds of lines of implementation:

- What does this module/resource own?
- What does it explicitly not own?
- What is the supported public entry point?
- What input and output shapes are valid?
- What errors can callers intentionally handle?
- What state transitions are legal?
- What guards those transitions?
- What side effects occur?
- What is transactional and what is not?
- What is idempotent?
- What happens after partial failure?
- Which layer is allowed to make the decision?
- Which source is authoritative if descriptions disagree?

---

## 1. Authority and Conflict Resolution

Follow the repository's instruction hierarchy and current authority routers. This reference introduces no alternative authority order.

Establish the implemented contract by inspecting Ash Domains, Resources, actions, validations, changes, policies, state machines, identities and code interfaces alongside behaviour callbacks, public interfaces, all implementation clauses, callers and tests. Compare typespecs, documentation and comments with that evidence; their existence does not make them authoritative over actual behaviour.

This is **not** permission to blindly rewrite implementation to match an old document.

If two authorities disagree:

1. identify the discrepancy;
2. determine whether one source is stale;
3. inspect callers, tests, migration history, ADRs/contracts, and framework definitions as relevant;
4. correct stale representations within the task's authority and scope; escalate any business-authority conflict under `AGENTS.md` rather than inventing a rule or amending governance during an ordinary audit;
5. report the conflict.

Never silently choose the easiest interpretation.

---

## 2. Prefer Structured Contracts Over Prose

When a framework can express the rule directly, express it there.

Prefer:

```elixir
argument :quantity, :integer do
  allow_nil? false
  constraints min: 1
end
```

over relying only on:

```elixir
@doc "Quantity must be a positive integer."
```

Prefer Phoenix component declarations:

```elixir
attr :status, :atom, required: true
slot :inner_block, required: true
```

over comments that merely restate the same requirement.

Prose is for information the executable/declarative contract does not communicate well:

- domain meaning
- ownership
- non-responsibilities
- rationale
- invariants spanning multiple resources
- lifecycle meaning
- idempotency expectations
- transaction boundaries
- external side effects
- failure and compensation behaviour
- security-sensitive assumptions
- intentionally surprising behaviour

Do not create two independently maintained descriptions of the same fact.

---

# Part I — Elixir

## 3. Module Classification

Before deciding what documentation is required, classify the module.

### A. Supported application/public API

Examples:

- domain-facing service module
- application facade
- reusable library module
- module intentionally called by other bounded contexts

Expected:

- useful `@moduledoc`
- precise public contracts
- `@spec` for supported public functions where a meaningful type can be established
- domain types where they improve precision
- public function docs for non-obvious behaviour

### B. Internal implementation module

Examples:

- internal helper
- plumbing module
- generated adapter support
- implementation detail not intended as a supported entry point

Expected:

```elixir
@moduledoc false
```

Use internal documentation/comments only where they explain non-obvious reasoning or invariants.

`@moduledoc false` means "not part of the supported documented module surface." It does **not** mean "unimportant" or "safe for agents to ignore."

### C. Behaviour/callback implementation

Expected:

```elixir
@impl true
```

or the appropriate behaviour module form.

Do not duplicate the behaviour's documentation mechanically. Add local documentation only when the implementation adds important semantics that callers/maintainers must know.

### D. Generated code

Do not manually improve generated source unless the project's generation model explicitly permits it. Fix the generator/template/source definition.

---

## 4. `@moduledoc`

A useful public `@moduledoc` answers some combination of:

- What responsibility does this module own?
- What is its supported entry point?
- What layer/domain does it belong to?
- What important responsibility does it **not** own?
- What lifecycle or side-effect boundary matters?
- Which adjacent modules should a maintainer use instead?

Good:

```elixir
defmodule MyApp.Orders do
  @moduledoc """
  Public application interface for the Orders domain.

  Owns order creation, confirmation and cancellation entry points.

  Payment settlement and ticket issuance are owned by their respective
  domains; callers must not mutate order state directly to emulate those
  workflows.
  """
end
```

Weak:

```elixir
@moduledoc "Functions for orders."
```

Do not turn module docs into a duplicate implementation walkthrough.

---

## 5. `@doc`

Document supported public functions when the contract is not obvious from the name, types, framework definition, or behaviour.

Useful function documentation may include:

- purpose
- caller-visible invariants
- meaningful side effects
- authorization/actor expectations
- tenant expectations
- idempotency
- intentional error cases
- ordering requirements
- transaction semantics
- important preconditions

Avoid documentation that simply translates the function body into English.

### Private functions

Do not attach `@doc` to `defp`.

Use a short inline comment only when the implementation has non-obvious reasoning that would otherwise be lost.

---

## 6. Typespecs

Typespecs are machine-readable/descriptive contracts used by documentation and static-analysis tooling. They are not runtime or compiler-enforced guarantees.

### Public functions

Prefer a precise `@spec` when the contract can be established from evidence.

Good:

```elixir
@spec fetch_order(order_id(), keyword()) ::
        {:ok, Order.t()} | {:error, :not_found | Ash.Error.t()}
```

Bad when a stronger type exists:

```elixir
@spec fetch_order(term(), list()) :: term()
```

But **false precision is worse than honest breadth**.

If the implementation, callers, tests, and framework definitions do not establish the full return contract, do not invent:

```elixir
{:error, :foo | :bar | :baz}
```

merely because those cases seem plausible.

Report the ambiguity.

### All clauses matter

Before writing or changing a spec, inspect:

- every function clause
- guards
- rescue/catch/throw behaviour if present
- delegated functions
- behaviour callbacks
- callers
- tests
- Ash code interfaces/actions involved
- protocol implementation requirements where relevant

### Domain types

Prefer meaningful types:

```elixir
@type order_id :: Ecto.UUID.t()
@type status :: :draft | :confirmed | :cancelled
```

instead of generic primitives when the narrower type communicates a real domain contract.

Do not create aliases/types merely for cosmetic verbosity.

### Structs

Custom structs intended to cross module boundaries should normally expose a `t()` type.

Example:

```elixir
@type t :: %__MODULE__{
        id: Ecto.UUID.t(),
        status: status()
      }
```

Use `@opaque` only when callers should not depend on the internal representation.

Use `@typep` for useful private type decomposition that should not become API.

Use `@typedoc` when the type's domain meaning is not self-evident.

---

## 7. Error Contracts

Do not collapse errors into `atom()` if callers depend on specific error classes and the actual contract can be established.

Do not create enormous speculative unions just to appear precise.

Distinguish where relevant:

- expected domain errors
- validation errors
- authorization/forbidden outcomes
- not-found outcomes
- framework errors such as `Ash.Error.t()`
- external-provider failures
- exceptional failures that are intentionally not returned

Document only caller-relevant distinctions.

If callers should not pattern-match on framework internals, expose a stable application error boundary instead of teaching callers to depend on unstable detail.

---

## 8. Doctests

Use doctests when all of the following are true:

- deterministic
- self-contained
- fast
- understandable without fixture machinery
- primarily useful as executable documentation

Excellent targets:

- pure transformations
- parsers
- formatters
- value objects
- deterministic calculations
- small public helpers

Usually poor targets:

- database writes
- Ash actions requiring actors/tenants
- authorization-sensitive workflows
- payment operations
- time-dependent workflows
- asynchronous jobs
- PubSub
- external APIs
- lifecycle transitions requiring fixtures
- generated identifiers unless normalized

Use normal ExUnit tests for stateful workflows.

Doctests supplement tests; they do not replace focused behavioural tests.

---

# Part II — Ash

## 9. Ash Is a First-Class Contract Surface

For an Ash application, do not treat resources as persistence structs with business logic living elsewhere by default.

Inspect the relevant:

- `Ash.Domain`
- `Ash.Resource`
- resource extensions
- attributes
- relationships
- actions
- arguments
- validations
- changes
- preparations
- calculations
- aggregates
- identities
- policies
- state machines
- notifiers/signals if used
- code interfaces
- multitenancy configuration
- data layer where it affects semantics

The Ash DSL should express rules Ash can enforce or introspect.

Do not duplicate those rules into prose unless the prose adds domain meaning.

---

## 10. Ash Domains

A Domain should make the bounded application surface understandable.

Its documentation should make clear:

- what domain it represents
- which resources/interfaces are intended for callers
- important cross-domain ownership boundaries
- whether callers are expected to use domain code interfaces rather than direct resource operations

Do not create a "god domain" description that claims ownership of behaviour implemented elsewhere.

---

## 11. Ash Resources

A Resource description should explain **what the resource represents in the domain**, not merely its table-like shape.

Good concept:

> Represents a customer's commercial order and owns the order lifecycle.

Weak concept:

> Stores order records.

For complex resources, document critical ownership boundaries.

Example:

> The Order owns commercial commitment state. It does not own payment settlement state, seat inventory state, or ticket admission state.

That single distinction can prevent an agent from placing future logic in the wrong resource.

---

## 12. Ash Actions

Action definitions are API contracts.

Inspect:

- action type
- public/private status
- accepted attributes
- arguments
- argument constraints
- validations
- changes
- preparations
- transactional behaviour where relevant
- authorization implications
- return shape/interface wrapper
- side effects/hooks/notifiers/signals

Action descriptions should explain the **domain operation** and non-obvious semantics.

Do not write prose that merely repeats:

> This is an update action that accepts `reason`.

The DSL already says that.

Prefer:

> Cancels an order before fulfilment becomes irreversible. Cancellation records the business reason and initiates downstream release/compensation through the configured workflow.

Only say that if it is true.

---

## 13. Ash Code Interfaces

When code interfaces define the supported application boundary, treat them as first-class public API.

Agents should prefer supported domain/code-interface entry points over constructing ad-hoc `Ash.Query` or `Ash.Changeset` calls throughout Phoenix/UI code unless the project intentionally uses another pattern.

When auditing an interface:

- verify the interface maps to the intended action
- verify argument names/order/defaults
- verify actor/tenant propagation expectations
- verify return/error semantics
- verify its spec/docs do not contradict the underlying action

Do not create wrapper functions that add no stable boundary or semantics merely to satisfy a documentation rule.

---

## 14. Ash Policies and Authorization

Authorization rules belong in the authorization model, not in controller/LiveView conditionals masquerading as domain security.

Documentation should explain policy **intent** when the DSL is not self-explanatory.

Do not copy every policy clause into `@doc`.

For security-sensitive changes, inspect both:

- whether the action is authorized correctly
- whether callers consistently pass required actor/scope/tenant context

Never document "admins only" if that rule is not enforced by the actual authorization contract.

---

## 15. Ash State Machines and Lifecycles

Every meaningful lifecycle must explicitly model:

1. states
2. allowed transitions
3. transition guards/preconditions
4. transition side effects
5. failure and compensation behaviour where applicable
6. idempotency/replay behaviour where applicable
7. terminal states

Prefer an explicit state-machine model when the resource genuinely has a state machine.

Do not scatter lifecycle transitions across:

- arbitrary changes
- controllers
- LiveViews
- background workers
- direct attribute writes

without a clear central contract.

### Lifecycle audit table

For a lifecycle-bearing concept, an auditor should be able to construct:

| From | Event/action | Guard | To | Side effects | Failure/compensation | Terminal? |
|---|---|---|---|---|---|---|

If this cannot be constructed from the code and approved architecture, the lifecycle is insufficiently explicit or the documentation is stale.

### Terminal states

Terminal means no ordinary forward transition is permitted.

Do not call a state terminal if retry, reopen, reverse, or compensation transitions remain intentionally legal.

---

## 16. Transactions and External Side Effects

This is a critical correctness rule.

A database transaction does not make an external API call atomic.

For workflows involving payments, email, third-party APIs, object storage, webhooks, queues, or other external systems, establish:

- what database changes are atomic together
- when the external call occurs
- stable idempotency key strategy
- retry semantics
- duplicate-delivery handling
- timeout/unknown-outcome handling
- reconciliation
- compensation
- persistence of external operation identifiers/results

Never document:

> payment capture and order confirmation are atomic

merely because both are initiated from a transaction.

The provider is not participating in the database transaction.

---

## 17. Ash Signals / Notifications / Async Effects

If the installed Ash/project stack uses Signals, notifications, notifiers, Oban, PubSub, or similar mechanisms, document caller-relevant asynchronous semantics:

- what event/signal is emitted
- when emission occurs relative to persistence
- whether delivery is at-most-once, at-least-once, or otherwise
- listener idempotency expectations
- retry behaviour
- ordering assumptions
- whether failure affects the initiating action

If current Ash Signals are used and the installed version provides it, `mix ash.signals` can help inspect action emission/listener mappings.

Do not assume asynchronous side effects are synchronous just because tests run quickly.

---

## 18. Multitenancy and Scope

When a Resource/action is tenant- or scope-sensitive, the contract must make it hard to call incorrectly.

Inspect:

- tenancy strategy
- tenant propagation
- actor/scope propagation
- cross-tenant query protections
- background-job context restoration
- Phoenix request-to-domain context transfer

Do not "document away" a missing tenant boundary.

If correctness depends on tenant context, enforce it in the strongest appropriate layer.

---

## 19. Ash Manifest and Introspection

When the installed Ash version supports it, `mix ash.manifest.dump` can provide a machine-readable view of the application's public Ash surface.

Use it as **supporting introspection**, not a replacement for source inspection.

It can help an agent discover:

- public resources
- public types
- action entry points

A generated manifest is downstream of the real DSL. If it disagrees with source, investigate generation/version/configuration rather than treating the manifest as independent authority.

Do not commit generated artifacts unless the repository's policy requires them.

---

# Part III — Phoenix

## 20. Phoenix Is the Delivery/UI Layer

Phoenix may coordinate request/UI concerns but should not become a second business-domain implementation.

Controllers, LiveViews, Channels, GraphQL/JSON endpoints, and components should generally delegate business state changes to the application/Ash boundary.

Warning signs:

- state-transition logic duplicated in LiveView events
- authorization recreated with `if current_user...`
- pricing logic in controllers
- direct DB updates bypassing Ash actions
- lifecycle guards in templates
- cross-resource transactions built ad hoc in web modules

When those are found, do not merely document them. Report the architectural leak and fix it if the task's authority/scope permits.

---

## 21. Controllers

Controller documentation should focus on interface-level responsibility when useful:

- HTTP boundary
- authentication/session expectations
- parameter adaptation
- response/error mapping
- delegation target

Do not duplicate route definitions in prose.

Do not document domain validation rules as though the controller owns them.

---

## 22. LiveView

A LiveView `@moduledoc` is valuable when it clarifies:

- what UI workflow it coordinates
- which application interface it calls
- what state is presentation state versus domain state
- what it must not decide

Example:

```elixir
defmodule MyAppWeb.OrderLive.Show do
  use MyAppWeb, :live_view

  @moduledoc """
  Presents an order and coordinates user-initiated order operations.

  Domain transitions and authorization remain owned by the Orders domain.
  This LiveView adapts user events and renders domain outcomes; it must not
  reproduce order-state or pricing rules.
  """
end
```

Do not annotate every `handle_event/3` with repetitive prose unless the event has non-obvious semantics.

---

## 23. Phoenix Components

Prefer the component contract:

```elixir
attr :status, :atom, required: true
attr :size, :atom, default: :medium
slot :inner_block
```

Add `@doc` when the component's semantic purpose, accessibility behaviour, or use constraints are not obvious.

Do not duplicate every `attr` declaration in prose.

If a component accepts a domain struct, prefer the strongest supported attribute declaration/pattern available in the project's Phoenix version and validate assumptions against that installed version.

---

## 24. Routes and APIs

Routes are framework-declarative contracts.

Do not maintain a prose list of routes that will drift from the router.

For API endpoints, document semantics that the router cannot express:

- authentication/authorization model
- idempotency
- stable error contract
- pagination semantics
- concurrency/version preconditions
- externally supported compatibility guarantees

---

# Part IV — Cross-Cutting Audit Rules

## 25. Side-Effect Vocabulary

Use precise language.

### Pure

No externally observable state change for the operation's intended abstraction.

### Database side effect

Persists data through the configured data layer.

### External side effect

Communicates with or changes state in a system outside the local database transaction, such as:

- payment provider
- email/SMS
- external HTTP API
- object storage
- external queue/broker

### Async side effect

Schedules or emits work whose completion occurs outside the initiating call's direct success path.

### Compensation

A deliberate follow-up operation intended to counteract a previously successful side effect after a later failure.

Do not call compensation "rollback" unless the original operation is actually transactionally reversible.

---

## 26. Idempotency

Document idempotency when retries or duplicate invocation are realistic.

Establish:

- idempotency scope
- key source
- persistence
- duplicate-call response
- concurrent duplicate behaviour
- expiry/retention if relevant
- relationship to external-provider idempotency keys

Do not label an operation idempotent merely because "calling it twice usually works."

---

## 27. Concurrency

When correctness depends on concurrency, inspect and document the actual mechanism:

- optimistic locking
- database constraint
- row/advisory lock
- atomic Ash action
- unique identity
- compare-and-set semantics
- serialized worker
- provider idempotency

Prose such as "this should only happen once" is not a concurrency guarantee.

---

## 28. Comments

Comments should explain **why**, not narrate **what**.

Useful:

```elixir
# Provider can return a timeout after accepting the capture. Persist the
# attempt before retrying so reconciliation can distinguish unknown outcome
# from a definite failure.
```

Weak:

```elixir
# Set status to paid
```

Never use comments as a substitute for a missing domain invariant.

---

# Part V — Audit Procedure

## 29. Phase A — Discover

Before editing:

1. read `AGENTS.md` and more-specific instruction files;
2. identify architecture/contract docs relevant to the target;
3. inspect `mix.exs` and `mix.lock` when framework/version behaviour matters;
4. locate the target Domain/Resource/interface/module;
5. locate tests and direct callers.

For Ash-version-sensitive behaviour, use the **installed dependency/source or version-matched official Ash documentation**. Do not assume an old Ash 2.x/early-3.x pattern or the latest online documentation matches the pinned version.

---

## 30. Phase B — Build the Contract Map

For each target, record internally:

- classification: public/internal/callback/web
- owner/domain
- supported entry point
- inputs
- outputs
- errors
- actor/scope/tenant requirements
- state transitions
- side effects
- transaction boundary
- async behaviour
- idempotency
- callers
- tests
- current docs/specs
- contradictions

Do not start "improving prose" until this map is coherent enough to avoid documenting fiction.

---

## 31. Phase C — Repair in Authority Order

Prefer this order:

1. incorrect architecture/domain contract, if the task authorizes that change
2. incorrect Ash/framework declarative contract
3. incorrect supported application interface
4. incorrect types/specs
5. incorrect/stale docs
6. comments

If the stronger contract is correct and prose is stale, update prose.

If prose exposes a real requirement that is not enforced anywhere, do **not** simply keep the prose. Escalate or implement the enforcement when authorized.

---

## 32. Phase D — Verify

1. Identify the changed contract and actual executable consumers. Determine which focused instruction, documentation, type, DSL or behavioural checks can detect a discrepancy in that contract. Non-executable documentation does not acquire a database-test requirement merely because it contains code examples.
2. During the transparency audit, run only necessary focused checks using the repository's pinned runtime and execution profiles. Report exact commands and observed outcomes. An unavailable check is a verification gap, never a passing result.
3. Delegate applicable canonical broad gates, OCR, exact-head CI and handoff requirements to `AGENTS.md`, the existing `code-change-verification` workflow and any verification helper actually authorised by that workflow. Do not assume a helper proposed on another branch is available. Loading this skill must not independently trigger `mix check`, `mix check.deep`, a full test suite, OCR or CI, or create a second CI or TDD pipeline.
4. Reuse existing evidence only while its relevant source, scope, environment and inputs remain unchanged and the owning workflow permits reuse. When an input changes, invalidate and refresh the affected proof. A changed PR head still requires exact-head hosted CI and independent review under the existing workflow.
5. Before using version-sensitive Ash tasks or flags, verify them against `mix.exs`, `mix.lock` and installed dependency source or version-matched official documentation. Introspection is optional supporting evidence when relevant, not another unconditional verification gate.
6. Never install tools or run destructive code generation merely to satisfy these examples. Inspect a task's behaviour and repository policy before invoking it; use a supported non-writing check mode only when it is needed and authorised.
7. Preserve every applicable final check. Avoid duplicate execution by sharing valid evidence through the owning workflow, never by weakening its obligations.

---

## 33. Audit findings in the existing handoff

Record the following findings proportionately in the existing ticket/PR handoff. Do not create a duplicate audit dossier or a competing handoff format:

### Scope

Files/modules/resources inspected.

### Corrections

Contracts, docs, types, DSL descriptions, or boundaries changed.

### Discrepancies

Any disagreement found between architecture, DSL, types, docs, tests, callers, and implementation.

### Ambiguities

Anything that could not be proven without inventing behaviour.

### Verification

Exact commands executed and their outcomes.

### Remaining risk

Known limitations, unverified paths, or follow-up work.

Do not use "all good" if significant surfaces were not inspected.

---

# Part VI — Quick Reference

## 34. Decision Table

| Situation | Preferred action |
|---|---|
| Ash DSL already expresses a constraint | Do not duplicate it in prose |
| Rule exists only in prose but must be enforced | Move/enforce it in the appropriate contract layer |
| Public module responsibility unclear | Improve `@moduledoc` |
| Internal module appears as public API | Clarify boundary; consider `@moduledoc false` |
| Behaviour callback | Use `@impl`; avoid redundant docs |
| Spec can be proven | Add/correct precise `@spec` |
| Spec cannot be proven | Report ambiguity; do not guess |
| Pure deterministic example | Doctest may be appropriate |
| Stateful/external workflow | Use normal tests, not forced doctest |
| Lifecycle exists | Model states/transitions/guards/side effects/terminal states |
| Phoenix contains domain decisions | Treat as architectural leak |
| External call occurs in DB transaction | Document non-atomic boundary and failure handling |
| Framework behaviour may have changed | Check installed/current authoritative docs |
| Generated file looks wrong | Fix source/generator, not generated output |

---

## 35. Red Flags

Stop and investigate when you see:

- `@spec ... :: term()` on an important domain boundary without evidence it must be broad
- a precise spec unsupported by all implementation clauses
- `@doc` claiming authorization not enforced in Ash policies
- a LiveView deciding whether a domain transition is legal
- direct state writes bypassing lifecycle actions
- payment/API calls described as "transactional" with database work
- `@moduledoc false` used to hide a module that is actually the supported API
- doctests that require fixtures, current time, random IDs, network, or DB state
- duplicated action descriptions that can drift from the Ash DSL
- actors/tenants silently omitted from background workflows
- comments describing invariants with no enforcement
- terminal states that still have undocumented outgoing transitions
- idempotency asserted without a stable mechanism
- an agent changing a spec based only on a function name
- an agent changing public API documentation without inspecting callers/tests
- stale Ash patterns copied from memory despite a newer installed dependency

---

## 36. Illustrative contract excerpts

The following excerpts demonstrate separation of contracts, not a complete application. The cancellation validation, authorization, state change and side effects are deliberately omitted. The descriptions are illustrative and do not prove enforcement.

```elixir
defmodule MyApp.Orders.Order do
  use Ash.Resource,
    domain: MyApp.Orders

  resource do
    description """
    Represents a customer's commercial order.

    The order owns commercial commitment state. Payment settlement and
    ticket admission state are owned by their respective domains.
    """
  end

  attributes do
    uuid_primary_key :id

    attribute :status, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:draft, :confirmed, :cancelled]
    end
  end

  actions do
    update :cancel do
      description "Cancels an eligible order before fulfilment is irreversible."

      argument :reason, :string do
        allow_nil? false
        description "Business reason recorded for the cancellation."
      end

      # Real project-specific validations/changes belong here.
    end
  end
end
```

The surrounding application/domain module can then explain ownership rather than restating the action DSL:

```elixir
defmodule MyApp.Orders do
  use Ash.Domain

  @moduledoc """
  Public interface to the Orders domain.

  Order lifecycle changes must go through supported Orders actions/interfaces.
  Web modules may adapt input and render outcomes, but must not reproduce
  transition or authorization rules.
  """

  resources do
    resource MyApp.Orders.Order do
      define :cancel, action: :cancel, args: [:reason]
    end
  end
end
```

The Phoenix layer stays thin:

```elixir
defmodule MyAppWeb.OrderLive.Show do
  use MyAppWeb, :live_view

  @moduledoc """
  Presents an order and adapts user events to the Orders application API.

  This LiveView owns presentation state, not order lifecycle rules.
  """
end
```

The important property is not the amount of prose. It is that each fact has **one strongest home**, and every layer tells the truth about its responsibility.
