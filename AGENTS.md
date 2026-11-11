NewYou Engineering Contract

This file is manually owned by NewYou. Generated framework documentation never replaces it.

Development workflow

- Make all changes on a git branch.
- Use an isolated worktree where appropriate.
- Create a PR for implementation or repository changes so they can be reviewed.
- Do not merge unless explicitly authorised.
- After merge and local sync, leave the repository clean and ready for the next agent.

Authority and execution sources

GitHub is canonical for durable governance and implementation evidence.

Plane project "WELL" is canonical for live execution state beneath that law: work-item state, priority, blockers, dependencies, sequencing, acceptance criteria, discovered work and review/merge readiness.

For current durable routing start with:

1. "docs/README.md"
2. "docs/governance/CURRENT_GOVERNANCE_ROUTER.json"

Use the governance router's `architecture_references` only when exact source, identifier-level reasoning or deep Architecture tracing is required.

"docs/history/CURRENT_AUTHORITY_MANIFEST_v1.0.0.json" is frozen historical/provenance input for Foundation Full, not a current router.

"docs/history/02_OPEN_WORK_v1.2.90.md" is frozen legacy evidence, not live execution authority.

Durable authority order is:

Product Law → Architecture Law → Domain Law → governing Roadmap → applicable supporting authority → semantic Feature/JIT/proof contracts where required → implementation.

Plane never overrides durable GitHub law. If Plane and durable authority conflict, STOP only the affected work, record the evidence in Plane and reconcile the smallest correct upstream authority.

Working or derived artifacts such as Delivery Atlas, Skeleton, HARDEN, JIT dossiers and proof contracts change only when their semantic contract changes. Status-only changes belong in Plane.

Durable governance is read-only during ordinary implementation. Amend it only for a deliberate durable semantic change or a proven upstream governance contradiction.

Delivery modes

NewYou has two distinct delivery modes.

New vertical slice or substantial feature

Use proportional planning:

"reconnaissance → /grilling when materially needed → to-spec only when durable semantics are missing → to-tickets when decomposition helps → Plane"

Do not force every slice through every ceremony.

A "/grilling" may conclude that current authority is sufficient and the remaining decisions are JIT implementation choices.

Ready implementation ticket

Fresh implementation starts only from a dependency-cleared Plane ticket in "Ready".

"Ready" means there is sufficient durable direction and executable acceptance criteria to implement, while leaving normal engineering design to JIT development.

It does not mean every Resource, table, field, action, constraint, transaction mechanism or internal representation has already been designed.

Before implementing a Ready ticket use:

".agents/skills/ticket-implement/SKILL.md"

Do not routinely invoke "/grilling", "to-spec" or "to-tickets" again inside a Ready ticket.

A Ready ticket can still uncover genuinely new information. Discovery alone does not make the ticket blocked.

Plane execution boundary

Only "Ready" authorises a fresh implementation agent to begin a ticket.

- "Backlog", "Planning" and "Blocked" are not executable.
- "In Progress", "In Review", "Changes Requested", "Ready to Merge" and "Merging" describe work already in progress.
- "Done" is terminal only after required post-merge/resulting-main reconciliation.

Before dispatch or implementation, reverify:

- the ticket is still "Ready";
- blockers and dependencies are resolved;
- acceptance criteria remain coherent and executable;
- current "main" has not invalidated the ticket;
- no already-known upstream contradiction exists.

After the readiness gate passes and immediately before implementation begins, move the ticket:

"Ready → In Progress"

When the implementation PR is opened and ready for independent review, move it:

"In Progress → In Review"

Search Plane before creating work. Do not create duplicates.

All material delivery work belongs in Plane, including executable work, blockers/dependencies, defects, discovered work, security/privacy concerns and release/proof gaps.

Do not leave delivery-affecting work only in chat, PR comments, TODOs, handoff notes or memory.

Keep Plane focused on active delivery and near-term executable work. Do not pre-create speculative future tasks.

Reconnaissance

Before "/grilling", "to-spec", "to-tickets" or material implementation, inspect the relevant live state:

1. "docs/README.md", "docs/governance/CURRENT_GOVERNANCE_ROUTER.json" and, where relevant, "docs/delivery/CURRENT_DELIVERY_ROUTER.json";
2. applicable durable Product/Decision, Architecture, Domain, Roadmap and supporting authority;
3. relevant semantic Feature/JIT/proof contracts;
4. live Plane work, blockers, dependencies and acceptance criteria;
5. actual code, tests, migrations and dependency versions.

Participant-facing copy and localisation

When a task creates, changes or renders participant-visible copy, inspect `docs/delivery/content-evidence/copy/` during reconnaissance, including `COPY_REGISTRY.json` and the relevant journey/page/glossary/style files.

- Reuse existing semantic copy keys where the meaning is the same; do not create independent duplicate strings.
- `candidate` copy is not approved copy. If acceptance criteria require exact approved content, use only the eligible approved version or treat its absence as an execution blocker.
- Do not invent or casually rewrite Class A governed copy. Preserve exact approved bytes where required.
- Respect EN/AF requirements and any governed no-fallback rule.
- Ordinary low-risk copy remains a JIT implementation choice where authority does not require exact approved wording.
- The copy workspace defines semantic content identity; it does not by itself mandate a CMS, database Resource, translation mechanism or other runtime architecture.

Follow evidence only as far as the task requires. Do not load the entire historical archive by default.

Do not re-grill, re-spec or re-ticket settled decisions without new evidence, changed scope or a proven contradiction.

JIT implementation decision model

NewYou deliberately uses just-in-time implementation design.

Governance defines durable outcomes, ownership, invariants, externally meaningful lifecycle semantics, security/privacy/safety boundaries, cross-Domain rules and explicit prohibitions.

It is not expected to pre-specify every internal engineering mechanism.

Classify material questions as follows.

"LOCKED"

Current durable authority answers the material business or architectural question.

Follow it.

"JIT IMPLEMENTATION CHOICE"

This is the default classification for implementation detail not fixed by durable authority.

When authority defines the required outcome and boundaries but leaves the mechanism open, choose the simplest compliant implementation, test it and continue.

Examples include, where not otherwise locked:

- a private Domain-owned Resource or extension to an existing Resource;
- tables, fields and internal attributes;
- Ash actions, changes, validations and code interfaces;
- identities, indexes and database constraints;
- transaction composition;
- concurrency/arbitration mechanisms;
- idempotency implementation;
- retention or tombstone mechanisms required to satisfy an existing invariant;
- internal modules and helper boundaries;
- migration shape;
- internal result/error representation;
- selection among compliant framework mechanisms.

A private implementation Resource does not become new business authority merely because it is durable.

The absence of an implementation detail from governance does not mean governance is incomplete.

Material JIT choices become durable through code, migrations and constraints where applicable, tests, and Plane/PR evidence.

Do not amend Product, Architecture, Domain, Roadmap or semantic contracts merely to record an implementation choice.

"UPSTREAM GOVERNANCE CONTRADICTION"

This classification is exceptional.

Use it only when implementation cannot proceed correctly without changing or inventing a material durable semantic such as:

- Domain/business ownership;
- externally meaningful lifecycle behaviour;
- authorization or entitlement;
- security/privacy/safety requirements;
- legal, clinical or commercial policy;
- cross-Domain authority;
- another expensive-to-reverse invariant that belongs above implementation.

A missing Resource, table, field, action, index, retention mechanism, transaction strategy or framework choice is not by itself an upstream contradiction.

Before blocking for governance, demonstrate all three:

1. the exact governing statements that conflict or are insufficient;
2. why no reasonable compliant JIT implementation can satisfy them;
3. the material durable semantic that would otherwise have to be invented or changed.

If all three cannot be demonstrated, continue as a "JIT IMPLEMENTATION CHOICE".

When a genuine contradiction exists, STOP only the affected work, record exact evidence in Plane and escalate the smallest correct upstream authority.

Implementation presumption

For a dependency-cleared "Ready" ticket:

Prefer implementation over governance amendment.

Do not re-grill, re-spec, create governance successors, block a ticket or wait for Foundation Full merely because implementation revealed an unspecified engineering detail.

Do not ask the human to choose between ordinary compliant implementation alternatives. Evaluate the alternatives and select the simplest compliant design.

Ask or escalate only when the unresolved choice would materially change a durable or expensive-to-reverse semantic.

Implementation discipline

For a Ready ticket:

1. reverify Plane state and dependencies;
2. inspect relevant authority and actual code/tests/migrations/dependencies;
3. identify the existing implementation seam;
4. classify unresolved questions as "LOCKED", "JIT IMPLEMENTATION CHOICE" or "UPSTREAM GOVERNANCE CONTRADICTION";
5. make the necessary JIT engineering decisions;
6. create a focused implementation plan against actual code;
7. implement ticket scope using test-first development;
8. run applicable repository verification;
9. update Plane and open a PR with exact evidence.

Stay inside ticket scope. Do not opportunistically implement adjacent features or Domains.

Use Igniter first for supported structural or package changes. Hand-edit where Igniter does not safely support the change.

Use Tidewave/runtime evidence where it answers development questions better than static reading. Tidewave is diagnostic tooling, never business authority.

Implementation handoffs

For substantial new vertical slices and meaningful end-to-end Domain/cross-Domain capabilities, author a source-linked implementation handoff in the same implementation PR using "docs/development/implementation-handoff-standard.md". Record a brief documentation-impact determination in every implementation PR. Later material changes maintain the existing handoff; proof-only work updates its proof section or a focused addendum. Trivial helpers, cosmetic and editorial changes may be exempt with rationale.

Independent Master Gate verifies required handoff accuracy against the exact reviewed head. Missing or materially inaccurate required documentation means "CHANGES REQUIRED" for that PR. No routine after-merge documentation ticket or unrelated blocker is required. Apply prospectively after WELL-96 integration, without retroactively blocking completed work or already-active WELL-7.

Handoffs describe implementation at a recorded Git SHA. Future agents must verify current source before relying on them. They are not Product, Architecture, Domain or execution authority. Plane remains the live execution ledger; existing exact-head and resulting-main verification still apply.

Required skills

Before implementing a Ready ticket use:

".agents/skills/ticket-implement/SKILL.md"

Before implementation involving Ash-backed behaviour or durable state, load the relevant Ash skill/reference.

Before handoff or merge recommendation use:

".agents/skills/code-change-verification/SKILL.md"

Load other generated framework skills only when relevant.

The legacy ".agents/skills/project-implementation/SKILL.md" may remain only as a compatibility shim for existing references. It must delegate to "ticket-implement", not define a competing workflow.

Ash-first mechanism selection

Ash is the default application framework.

For implementation involving business behaviour, durable state, authorization, authentication, lifecycle, history, async work, audit/evidence, cross-Domain coordination or Ash-backed web flows:

1. load ".agents/skills/ash-framework/SKILL.md" and relevant generated references;
2. evaluate the Ash capabilities that materially match the requirement;
3. verify current APIs and compatibility against official primary sources;
4. prefer a fitting Ash mechanism over bespoke Elixir/Ecto/OTP plumbing when it satisfies the requirement without violating authority;
5. record material selections where useful as "USE", "NOT APPLICABLE", "DEFER" or "BLOCKED / NEEDS AUTHORITY".

Evaluate relevant core Resources/actions/interfaces, policies, identities/constraints and applicable extensions such as AshPostgres, AshAuthentication, AshPhoenix, AshOban, AshStateMachine, Signals, Temporal Resources, Cloak or history/archive tooling only when their capability materially matches the ticket.

For cross-Domain reactions or event-like coordination, explicitly consider Ash Signals.

For historical/as-of/effective-period requirements, explicitly consider Temporal Resources.

Neither Signals nor Temporal Resources becomes business authority merely because it is technically useful.

Evaluation is not installation authority. A new dependency requires a concrete need, compatibility with the current stack, current stable-version/API verification and any required Architecture/Security/Domain approval.

Re-evaluate material framework choices at implementation time when versions, capabilities, scope or authority have changed since planning.

Domain and persistence invariants

Every durable business truth has exactly one authoritative Domain owner.

Cross-Domain mutation goes through the owning Domain/Ash interface.

Derived state, caches, Analytics, search indexes, provider state, PubSub and UI projections never become business authority.

Business writes use owning Ash interfaces. Controllers, LiveViews and workers call the owning Domain/application interface.

Do not introduce parallel ordinary "NewYou.Repo", raw SQL or "Ecto.Multi" business-write APIs. "mix check.architecture" enforces these boundaries.

Do not introduce Redis, extra services, extra Repos, ETS/process authority, replicas, Rust/Rustler, microservices or speculative infrastructure without demonstrated need and authority.

Authorization and capability authority

Resolve authorization through governed roles, scopes and applicable relationships.

Capabilities belong to governed roles/scopes/relationships. Named people may receive explicit grants; they never define capability authority.

Do not attach a business capability directly to a named user as a shortcut. Treat that as an upstream governance contradiction.

Governed bootstrap may establish initial explicit role/scope grants, but bootstrap itself holds no business capability. After bootstrap, sensitive grants require the appropriate role-based independent approver, distinct from the subject.

Multiple valid roles on one identity are expected and supported.

Platform Administrator, developer or founder status does not imply expert Domain authority.

Super Admin is break-glass, not a universal bypass.

An unresolved required approver authority is a STOP condition.

Lifecycle requirements

Every meaningful lifecycle must explicitly cover, as applicable:

- states;
- transitions;
- guards and invariants;
- side effects;
- terminal states;
- authorization;
- concurrency;
- idempotency;
- retries;
- failure behaviour;
- restart/recovery/reconciliation.

Lifecycle correctness must be enforced by the owning durable authority, not process-local state.

Defects and regression proof

Every material bug, security issue or behavioural regression must leave permanent regression coverage.

Where technically possible:

1. reproduce it with a focused failing automated test;
2. implement the fix;
3. prove the regression test passes;
4. run applicable wider verification.

If deterministic automation is genuinely impossible, record the reason and strongest repeatable alternative proof in Plane.

A material defect fix without adequate regression proof is not complete.

Evidence

Do not guess material framework or package APIs.

Prefer evidence in this order:

1. current repository authority and implementation;
2. relevant generated framework skills;
3. runtime/Tidewave evidence;
4. version-matched official HexDocs/source;
5. model memory last.

Verify current stable package/API facts and distinguish stable releases from prerelease or main-branch documentation.

Verification, review and merge

"mix check" is the canonical fast engineering gate.

"mix check.deep" is the slower engineering gate.

Foundation Smoke runs on every PR and validates current routing and merge-gate topology.

Application CI runs for routed engineering changes.

Foundation Full is historical/provenance certification in the nightly hardening workflow only. Its schedule targets 02:00 Africa/Johannesburg; GitHub may delay or drop a scheduled start. It is not a pull request or manual-dispatch gate.

The operational CI topology is documented in:

"docs/development/foundation-integrity-merge-gate.md"

Do not wait for the nightly Foundation Full during routine implementation. The required PR gates are Foundation Smoke and routed Application CI/Hex security audit when applicable.

Ordinary JIT implementation choices do not justify governance amendments merely to obtain Foundation Full evidence.

Investigate material Foundation Full regressions reported by a nightly run against `main`, and use the recorded run SHA to identify affected changes.

Before handoff:

- verify the complete diff;
- verify the exact head SHA;
- run applicable tests/checks;
- verify current Plane state;
- create or update the PR;
- provide exact evidence for independent review.

The implementing agent does not self-certify merge authority and does not silently merge.

Master Gate independently verifies the exact PR head, complete diff, durable authority, live Plane acceptance contract, scope, ownership, lifecycle, persistence, concurrency/idempotency, retries/failure/recovery, security/privacy/safety, dependency/API correctness, tests and exact-head CI.

### Mandatory independent review and merge attestation

Every PR entering merge certification must follow `docs/development/foundation-integrity-merge-gate.md`. Independent Master Gate reviews the exact full diff and applicable law; the implementing agent must not invent or self-certify that review. The strict procedure requires an authentic, attributable independent review reference. The founder-development procedure below instead records the founder account's adoption of ChatGPT's independent technical review, without requiring a public ChatGPT conversation link.

Founder-development mode is limited to founder-stage development where no stricter control applies. An authenticated owner-account comment adopts the independent review and binds the PR, base, head, full binary diff and hosted CI evidence. The founder accepts that shared GitHub credentials authenticate the account, not an independently provable physical founder action: an implementation agent with those credentials can create the same comment. The implementation review and owner acceptance remain separate workflow steps, but this mode cannot technically enforce actor separation or prove ChatGPT authorship. It does not replace regulated release, production security, privileged two-person or other independently mandated controls. Neither adoption nor attestation authorizes a merge.

The founder-development operator uses `tools/newyou-attest prepare --pr N` and, immediately after a separately authorized merge, `tools/newyou-attest verify-after --pr N`. The procedure, trust assumptions, private custody and failure rules are specified in the merge-gate document. This mode becomes available only after the change establishing it is integrated into `main`; the PR introducing it must follow the previously applicable procedure or a separately authorized transition.

In the strict procedure, the trusted repository operator identifies and preserves the review evidence and completes the following as part of the normal handoff:

1. Materialize `review.json` from the independent review and verify its provenance, reviewer, full diff and digest.
2. Run `tools.ci_attestation before` against the exact reviewed head, review record and required successful hosted CI run. Preserve `review.json`, `before.json`, process exit status, stderr and SHA-256 digests in trusted private custody.
3. Recheck that the PR head, base, candidate, CI and review evidence remain valid. Merge only with separate explicit authorization.
4. Immediately after an authorized merge, run `tools.ci_attestation after` using the original trusted evidence. Verify resulting-main commit, parents, candidate tree and all collector assertions, and preserve the output and its evidence.
5. Do not mark the Plane ticket Done or unblock dependent implementation until independent resulting-main certification passes.

Do not commit attestation artifacts or manufacture them from untrusted PR content. A changed reviewed head invalidates certification; other changed inputs invalidate the applicable evidence as described in the procedure. If the collector cannot establish proof, follow its documented fail-closed fallback. A passing collector does not replace independent review. Neither review nor attestation authorizes a merge.

Master Gate reviews JIT implementation choices for correctness and compliance. It must not reject a compliant internal engineering choice merely because governance did not pre-specify it.

A reviewer claiming an upstream governance contradiction must satisfy the same three-part contradiction test before blocking integration.

Any reviewed-head change invalidates prior certification.

Merge alone does not complete delivery. Independently verify resulting-main SHA/tree, candidate integration/no drift and required resulting-main CI/proof before moving Plane to "Done" or opening dependent work. The PR-tested merge tree may supply that proof only when the pre-merge run, reviewed head, base, candidate, required checks and resulting merge commit are independently bound as described in "docs/development/foundation-integrity-merge-gate.md". Any missing or mismatched evidence requires explicit fresh exact-SHA verification; never describe reused PR evidence as a main-SHA check run.

Local DevCore credentials

DO NOT ASK THE USER FOR LOCAL DB PASSWORDS OR DEVCORE-MANAGED DB VARIABLES.

If ".devcore/project.conf" exists:

1. run "devcore-project doctor";
2. if state is missing or stale, run "devcore-project activate";
3. run DB-dependent commands with:
   - "devcore-project run dev -- <command>"
   - "devcore-project run test -- <command>"

Never request or print password values.

The repository must not start, stop, recreate or delete shared DevCore services or volumes.

Redis is not used by NewYou.

Both PostgreSQL roles must remain "NOCREATEDB".
