# Delivery Atlas working v0.4.31

- **Artifact:** `ATLAS_RECONCILIATION` (derived navigation successor; **not** `ATLAS-12`)
- **Document status:** **DERIVED DELIVERY PLANNING ARTIFACT**
- **Working state:** **WORKING / NON-AUTHORITATIVE**
- **Authority boundary:** **DOES NOT MODIFY PRODUCT / ARCHITECTURE / DOMAIN / ROADMAP LAW**
- **Implementation boundary:** **DOES NOT AUTHORISE IMPLEMENTATION**
- **Purpose:** Keep medium-resolution delivery navigation aligned with current Product, Architecture, Domain and Roadmap authority after the completed targeted amendment programme, and preserve the just-in-time routing required to prepare an active outcome safely.
- **Scope:** Feature Pack relationships, shared capability movement, lifecycle coverage, journeys, cross-domain interaction, integrations, measurement, risk, proof, hardening and future-extension visibility.
- **Predecessor:** `docs/history/platform/archive/DELIVERY_ATLAS_WORKING_v0.4.30.md` (direct routing predecessor; preserved byte-identically). Earlier predecessors remain at their archive paths.
- **SemVer transition:** `v0.4.30 → v0.4.31` (PATCH current routing).
- **Current content state:** ATLAS-01 through ATLAS-11 remain complete at their recorded scope as derived navigation. Current Product, Decision, Architecture, Domain, Roadmap and supporting authority resolve through `docs/governance/CURRENT_GOVERNANCE_ROUTER.json`; current Feature, JIT, proof and execution contracts resolve through `docs/delivery/CURRENT_DELIVERY_ROUTER.json`. Open Work v1.2.90 is retained at `docs/history/02_OPEN_WORK_v1.2.90.md` as a frozen snapshot; Plane project `WELL` remains the live execution authority. This derived route changes no authority, Model B semantics or implementation state.
- **Freeze state:** Not frozen. A later freeze requires a separate governance decision.
- **Patch scope:** Status and routing successor only. Records the separately reviewed TB-001 v0.1.3 promotion evidence and directs current navigation to v0.1.3. No Atlas authority, Feature Pack content, Domain ownership, delivery semantics or implementation boundary changes.


## v0.4.21 Routing Patch Scope

This routing-only successor archives v0.4.20 byte-identically and refreshes the current Product, Decision, Roadmap and Open Work paths. It does not change Feature Pack relationships, Domain participation, gates, proof status or implementation boundaries.

## v0.4.16 Patch Scope (historical predecessor)

This status-only predecessor archived v0.4.15 byte-identically and recorded the FP-001 Development Entry Hard Stop PASS / ALL 10 CONDITIONS SATISFIED. At that predecessor point it routed bounded Phase 8 Architectural Proof, recorded no Tracer Bullet ID and sent the next governance action to task definition. This changes no Atlas authority, Domain participation or capability relationship.

## v0.4.9 Patch Scope

This status-only successor archives v0.4.14 byte-identically. It records Phase 7B reconciliation, Phase 7C and Final Feature Pack Contract v0.1.0 as COMPLETE / CERTIFIED / CURRENT. The separate post-Phase-7C classification is COMPLETE / FINALISED as NEW_TRACER_BULLET; proof execution has not started. The next governance action is Development Entry Hard Stop evaluation. Phase 8 and application implementation remain UNAUTHORISED until every other applicable condition is independently evaluated and satisfied. This changes no Atlas authority, Domain participation or capability relationship.

## v0.4.8 Patch Scope (historical predecessor record)

This successor archives v0.4.7 byte-identically. It routes the Phase 7B reconciliation candidate and aligns the FP-001 high-level Domain involvement with current approved scope: Content & Media is Supporting because governed public and message content is materially exercised. The six affected Domains and seven material capability relationships are unchanged. This derived correction creates no new authority or implementation permission.

## v0.4.7 Patch Scope

This v0.4.7 predecessor updated current-source routes from Open Work v1.2.65 and recorded the completed Audit & Evidence v0.1.0 current-status promotion. It changed no Feature Pack outcome, capability relationship, Domain participation, authority, gate, delivery stage or implementation boundary.

## v0.4.6 Patch Scope (historical predecessor record)

This predecessor updated current-source routes and candidate-existence status navigation from Open Work v1.2.64. Candidate v0.1.0 was authored and review-ready in PR #118, but remained NOT CERTIFIED / NOT CURRENT. No Feature Pack outcome, capability relationship, Domain participation, authority, gate, delivery stage or implementation boundary changed.


## v0.4.4 Patch Scope

This successor updates current-source routes and FP-001 status navigation from Open Work v1.2.62. It does not change any Feature Pack outcome, capability relationship, Domain participation, authority, gate, delivery stage or implementation boundary.


## v0.4.3 Patch Scope

This routing-only predecessor pointed current-source tables and current planning references to Product v1.8.0, Decisions v1.8.0, Roadmap v1.2.2 and archived Open Work `docs/history/platform/archive/02_OPEN_WORK_v1.2.61.md` after the OPS-UPD-002 authority candidate. It did not change any Feature Pack, capability, Domain, gate, stage or delivery-content meaning.

## v0.4.2 Patch Scope

This routing-only successor points current-source tables and current planning references to Product v1.7.0, Decisions v1.7.0, Roadmap v1.2.1 and Open Work v1.2.60. It does not change any Feature Pack, capability, Domain, gate, stage or delivery-content meaning.

## v0.4.1 Patch Scope

This routing-only successor follows Open Work v1.2.59 and Identity dossier v0.1.4. PR #76 candidate and post-merge certification evidence remain distinct from the separate PR #77 current-status successor. The Communications dossier v0.1.0 is now COMPLETE / CERTIFIED / CURRENT under the separate PR #81 status successor; its finalisation remains BLOCKED / STOP. The v0.3.9 predecessor and both distinct Identity v0.1.3 predecessor artifacts remain preserved in their manifest-pinned archive paths.

This routing-only successor updates the current Open Work, Identity dossier and Communications task-status routes. It does not change any derived capability, Domain, Feature Pack, gate or later programme-stage meaning.

This document is the current Delivery Atlas working artifact. It summarizes derived views and labels that may help navigate an approved roadmap outcome through canonical Phase 7, proof, execution and readiness. It leaves implementation-grade design to the affected Feature Pack and just-in-time (JIT) Domain Dossiers. Atlas guidance does not independently create a gate, prerequisite, handoff or lower-level contract.

The working artifact remains outside authority-document records in `docs/history/CURRENT_AUTHORITY_MANIFEST_v1.0.0.json`; its path is listed only under graph/navigation paths. The v0.2.1 working file remains byte-identical at its prior path because existing FP-001 and HARDEN-02 artifacts pin that source-at-freeze route; an identical archival copy is retained. ATLAS-01 through ATLAS-11 and this reconciliation successor do not add Atlas as authority.

---

# 1. Authority, purpose and boundaries

## 1.1 Authority hierarchy

The Delivery Atlas is subordinate to every upstream authority. The authority hierarchy is:

```text
Product Law
    → Architecture Law
    → Domain Law
    → Roadmap
```

When useful, the Atlas can provide derived navigation from an approved Roadmap outcome toward the canonical delivery path:

```text
approved Roadmap outcome + applicable current authority
    → optional Delivery Atlas navigation
    → canonical Phase 7
```

The Atlas may point to the next source-owned planning boundary. Its navigation is not an authority tier, gate or prerequisite by itself.

The current sources that establish this chain are:

| Authority level | Current source | Atlas relationship |
|---|---|---|
| Product Law | `docs/governance/product/PROJECT_NORTH_STAR_AND_MVP_v1.3.0.md`; `docs/governance/product/00_PLATFORM_v1.15.0.md`; `docs/governance/product/01_DECISIONS_v1.15.0.md` | Defines product purpose, approved outcomes, policy, MVP boundaries, non-negotiables and formal gates. |
| Architecture Law | `docs/governance/architecture/03_ARCHITECTURE_v1.1.1.md` and the accepted Architecture Law represented by it (`docs/governance/architecture/references/ARCHITECTURE_LAW_WORKING_v0.36.0.md`) | Defines architectural authority, state authority, interaction rules, failure behaviour, performance doctrine and deferred mechanisms. |
| Domain Law | `docs/governance/domain/04_DOMAIN_MAP_v1.2.0.md` | Defines who owns durable business truth and the domain-level dependency direction (20 Domains). |
| Roadmap | `docs/governance/roadmap/05_ROADMAP_v1.2.5.md` | Defines approved delivery phases, Feature Pack outcomes, dependencies, gates and sequencing (17 Feature Packs). |
| Frozen planning snapshot | `docs/history/02_OPEN_WORK_v1.2.90.md` | Preserves pre-Plane planning evidence. Plane project `WELL` owns live execution state. |
| Supporting cross-cutting contract | `docs/governance/supporting/PLATFORM_OPERATING_MODEL_v1.3.0.md` | Supplies stable operating workflow guidance beneath the four upstream law levels. |
| Supporting cross-cutting contract | `docs/governance/supporting/FRONTEND_EXPERIENCE_SYSTEM_v1.0.1.md` | Supplies frontend, interaction, accessibility, public-experience and measurement guidance beneath the four upstream law levels. |
| Frozen provenance manifest | `docs/history/CURRENT_AUTHORITY_MANIFEST_v1.0.0.json` | Preserves freeze-time routes and integrity expectations. Current routing lives in the governance and delivery routers. |

Historical source-at-freeze filenames cited inside earlier ATLAS-01…ATLAS-11 population notes remain provenance for those views. Current navigation must resolve against the current sources above.

`PLATFORM_OPERATING_MODEL` and `FRONTEND_EXPERIENCE_SYSTEM` support Atlas work when their concerns are in scope. Neither may override Product Law, Architecture Law, Domain Law or the Roadmap.

## 1.2 Purpose

The Atlas exists to keep the mature platform and the approved delivery route visible at the same time. It may show:

- what a Feature Pack introduces, reuses, extends or composes;
- which domains participate in a delivery outcome;
- where a lifecycle first appears and where its full specification becomes mandatory;
- how participant, staff and frontend journeys progress;
- how authority and derived projections move across boundaries;
- which integrations, measurement concerns, safety controls, proof obligations and hardening categories become relevant;
- which future extensions have a legitimate approved seam;
- which dependencies and risks cross Feature Pack boundaries; and
- what JIT planning a later Feature Pack will need.

The Atlas is a delivery map, not a second Product, Architecture, Domain or Roadmap document. It may point to those sources and derive relationships from them. It may not create a new rule by implication.

## 1.3 Scope boundary

ATLAS-01 defined the views, labels, entry rules and STOP rules for the complete approved roadmap. ATLAS-02 populated the Feature Pack Portfolio Register. ATLAS-03 populated the Platform Capability Inventory within the Capability Introduction / Reuse area. ATLAS-04 connected that vocabulary to the approved Feature Pack sequence. ATLAS-05 now defines how Domain participation is derived for an active Feature Pack and records only non-obvious relationship exceptions. ATLAS-06 defines how lifecycle obligations are derived and projected for an active Feature Pack without maintaining a permanent platform-wide lifecycle concept table. Later Atlas work may populate another view only from current upstream authority, approved evidence and the relevant governance decision.

The Atlas must preserve these boundaries:

1. Product Law defines what NewYou is allowed and expected to do.
2. Architecture Law defines how the platform may make those outcomes true.
3. Domain Law defines which domain owns each durable business truth.
4. The Roadmap defines when an approved outcome is sequenced and what it unlocks.
5. The Atlas makes delivery relationships visible without changing any of the above.
6. JIT planning fixes implementation semantics only for an approved, affected Feature Pack.

## 1.4 Explicit non-authority

> No Atlas-derived fact may authorise implementation unless it resolves to stronger upstream authority or an approved downstream JIT / Final Feature Pack Contract.

The Atlas must not:

- amend, reinterpret or silently repair Product, Architecture, Domain or Roadmap authority;
- turn a supporting operating or frontend rule into a higher authority;
- choose a Feature Pack outcome, scope or gate that is not already approved upstream;
- create a new business domain, shared-write owner or authoritative dependency;
- authorise Phase 7, FP-001 preparation, Architectural Proof, Vertical Slices, Horizontal Hardening or release work;
- create a JIT Domain Dossier, TB, VS, HH or TOON;
- treat a delivery seam as an implementation design; or
- use completeness of the Atlas as a reason to pull future capability into the current delivery stage.

## 1.5 Architectural or delivery seam versus implementation design

An **architectural or delivery seam** is a visible relationship that later work must respect. Examples include a domain-owned fact read by another domain, a capability reused by more than one Feature Pack, a lifecycle that needs a later full specification, or a proof boundary that must be exercised under an approved task.

An **implementation design** chooses the concrete mechanism that realizes that relationship. It includes exact Ash Resource or action names, schemas, tables, columns, indexes, keys, TTLs, queues, topics, modules, routes, components, packages, versions, deployment sizing and source code.

```text
architectural / delivery seam != implementation design
```

The Atlas may record the first. It must defer the second unless an upstream source has already frozen the exact detail.

---

# Delivery Lifecycle Governance

## Lifecycle purpose and operating flow

The Atlas summarizes or navigates the governed delivery path. It does not independently create gates, handoffs, review prerequisites, implementation permission or lower-level contracts.

The canonical delivery sequence is:

```text
Roadmap approved outcome
    → Phase 7A Feature Pack Skeleton + preliminary Gate Manifest
    → Phase 7B required JIT Domain Dossiers
    → Phase 7C Final Feature Pack Contract (proof requirement and obligations frozen)
    → separate post-Phase-7C / pre-Phase-8 architectural proof classification gate
    → Phase 8 executable architectural proof, only after Development Entry Hard Stops pass
    → Vertical Slices
    → Horizontal Hardening
    → Release / Readiness
```

The Roadmap supplies the approved outcome, scope, sequencing, dependencies and gates. Phase 7A creates the Feature Pack Skeleton and preliminary Gate Manifest. Phase 7B creates only the JIT Domain Dossiers required by the active outcome and its source-owned gates. Phase 7C resolves blocking gates and produces the Final Feature Pack Contract, which owns development-entry scope and freezes the architectural proof requirement and applicable proof obligations. After Phase 7C and before Phase 8 executable proof, the separate architectural proof classification gate selects `REUSE_EXISTING_PROOF` or `NEW_TRACER_BULLET`. This classification is a Development Entry Hard Stop requirement and does not itself prove the architecture. Phase 8 remains the first executable architectural-proof stage. No ceremonial proof task is created. Required proof, execution, evidence and readiness remain governed by their owning contracts and authorities. Atlas navigation may help locate these requirements, but it is not an additional authority stage.

Grill-Me prompts, handoff summaries and continuation/revalidation checks can be useful. They are recommended Atlas practices unless a current upstream source or approved contract explicitly requires a review, handoff, evidence item or revalidation. A positive Atlas review cannot grant permission, and omission of an Atlas-only item cannot bypass an upstream gate.

This governance section is derived guidance beneath the authority hierarchy in Section 1.1. It does not modify Product Law, Architecture Law, Domain Law or the Roadmap. It does not authorise implementation, freeze an implementation mechanism or replace a Feature Pack Contract, JIT Domain Dossier, proof, Vertical Slice, Horizontal Hardening artifact, release decision or readiness decision.

## Feature Pack lifecycle

### Purpose

The Feature Pack lifecycle summarizes how an approved Roadmap outcome enters its governed implementation boundary. Atlas navigation may help find applicable views when relevant; it is not an extra lifecycle stage or entry condition.

### Stages

The canonical sequence and its required gates come from the Roadmap, Platform Operating Model and approved Feature Pack / JIT contracts:

1. **Selection.** Select an approved Roadmap outcome. Do not create a new outcome or expand the approved scope inside the Atlas.
2. **Phase 7A — Feature Pack Skeleton + preliminary Gate Manifest.** Record the approved outcome, validation objective, type, boundaries, dependencies, affected Domains, known decisions, blocking questions and preliminary gates. This Atlas does not create the Skeleton or Manifest.
3. **Phase 7B — required JIT Domain Dossiers.** Create only the implementation-grade Domain dossiers required by the approved outcome and its source-owned gates. Preserve ownership and stop on unresolved authority.
4. **Phase 7C — Final Feature Pack Contract.** Resolve or explicitly exclude blocking gates, finalize the boundary and acceptance criteria, and approve the development-entry contract. This Atlas does not create the contract.
5. **Architectural proof classification.** After Phase 7C and before Phase 8, the separate classification gate selects `REUSE_EXISTING_PROOF` or `NEW_TRACER_BULLET` against the frozen proof requirement and obligations. This is a Development Entry Hard Stop requirement, not executable proof or an Architecture proof result.
6. **Phase 8 — executable architectural proof / Tracer Bullet, when required.** Phase 8 is the first executable architectural-proof stage. Execute only after the classification and all Development Entry Hard Stop conditions pass; create a Tracer Bullet only when `NEW_TRACER_BULLET` was selected.
7. **Vertical Slices.** Deliver complete production-quality behaviours within the approved boundary.
8. **Horizontal Hardening.** Apply evidence-led hardening after the behaviour is correct and its failure or pressure is understood.
9. **Release / Readiness.** Review the acceptance criteria and evidence required by the approved contract and applicable security, privacy, performance, operational and recovery authorities, then record the owning release/readiness decision.

If current authority, ownership, policy, required evidence or scope is unresolved, follow the controlling source's gate or STOP. Atlas wording does not add a separate blocker.

## Tracer Bullet lifecycle

### Purpose

The Tracer Bullet lifecycle proves an architectural assumption or unknown path with the smallest realistic proof. A TB is a proof boundary, not a partial feature and not evidence that the complete product behaviour is ready.

### Required questions

Before a TB is selected, its contract must answer:

- What assumption is being proven?
- Why does existing evidence not prove it?
- What is the smallest realistic proof?
- What architecture layers are involved?
- What evidence determines success?
- What happens if proof fails?

The TB lifecycle frames the assumption, identifies the missing evidence, bounds the path, names the involved layers at the level required for the proof, runs the smallest realistic proof and records the result. A successful proof records what it proves and the boundary of that result. A failed proof records the failed assumption, the evidence, the affected authority or Feature Pack and the required rework, clarification or alternative. A failed TB never becomes an implicit approval to continue.

ATLAS-01 defines the TB lifecycle and selection questions only. It does not create a TB contract, proof task, `TB-nnn` identifier or executable proof.

## Vertical Slice lifecycle

### Purpose

The Vertical Slice lifecycle delivers one complete production-quality behaviour across every layer needed to make the stated user outcome true.

### Required considerations

Each VS contract must consider the following, marking an item as not applicable only with a reason:

- user outcome;
- domain ownership;
- policies;
- lifecycle changes;
- durable state;
- side effects;
- async behaviour;
- realtime behaviour;
- audit;
- tests; and
- operational evidence.

The VS lifecycle starts with a bounded behaviour and acceptance criteria, confirms its domain and policy boundaries, implements the complete path, exercises relevant failure and recovery behaviour, collects test and operational evidence, and ends with review against the stated outcome. A UI path, endpoint, projection or provider response alone is not a complete VS when the behaviour also requires authoritative state, side effects, audit, asynchronous work or operational controls.

ATLAS-01 defines these VS boundaries only. It does not create a VS contract, implementation task or `VS-nnn` identifier.

## Horizontal Hardening lifecycle

### Purpose

The Horizontal Hardening lifecycle strengthens already-correct functionality based on evidence. It does not replace missing implementation or hide an unproven behaviour behind a hardening label.

### Required evidence

Every HH contract must require:

- a measured reason;
- an identified failure mode;
- an improvement objective;
- before/after evidence; and
- regression validation.

The HH lifecycle identifies the measured pressure or failure, states the improvement objective, applies the smallest justified change, measures the before and after behaviour, validates regression risk and records the remaining safe boundary. If the underlying functionality is not correct or the failure is not understood, the work returns to implementation, proof or upstream clarification rather than being labelled hardening.

ATLAS-01 defines these HH boundaries only. It does not create an HH contract, hardening task or `HH-nnn` identifier.

## Grill-Me review prompts

Grill-Me is a useful adversarial review aid. It is advisory unless a current upstream source or approved Feature Pack/JIT contract explicitly requires a review; in that case the review is mandatory because that source owns the requirement. A positive review cannot grant permission, and skipping an Atlas-only Grill-Me does not bypass an upstream gate.

### Feature Pack Grill-Me prompts

Consider asking:

- What assumptions exist?
- What dependencies exist?
- What could invalidate the approach?
- What future capability could be blocked?
- What domains are affected?
- What policies/lifecycles are involved?

Answers can record missing evidence, source-owned gates and questions for the proper authority. Any decision to proceed, revise or stop remains with its owning contract or authority.

### TB/VS/HH review prompts

When useful, ask:

- Is this the correct implementation boundary?
- Are acceptance criteria clear?
- Are failure modes understood?
- Are security/privacy/performance requirements identified?
- Is the task small enough?
- Does it require upstream clarification?

These prompts can help surface scope, evidence and dependencies. The applicable contract defines any required review or acceptance boundary. If an upstream rule is unclear, route the question rather than deciding it locally.

## Implementation handoff

An Implementation Handoff can be a useful durable summary connecting an approved implementation boundary to repository state, collected evidence and follow-on decisions. Atlas recommends the summary; it does not require an artifact with this literal name unless an applicable upstream source or approved contract explicitly requires one. Any mandatory handoff is required because that source owns it.

A useful summary can capture:

- what was implemented;
- final architecture impact;
- domain impact;
- lifecycle changes;
- state machine changes;
- database changes;
- performance characteristics;
- security/privacy changes;
- tests/evidence;
- operational requirements;
- known limitations; and
- unlocked future work.

Where a handoff is required, the owning source determines its required form and contents. These fields can help distinguish measured results from assumptions, link evidence to acceptance criteria or invariants, and identify work that remains gated, deferred or unsafe to continue.

## Continuation review

When work resumes after a gap, revalidating current authority and repository context is recommended where relevant to the planned work. This can be done without producing a named Continuation Review artifact unless an applicable upstream source or approved contract requires one.

Useful revalidation questions include:

- What does previous handoff documentation say, if available?
- What is the current repository state?
- What do current tests show?
- What do current authority documents require?
- Does implementation match the intended outcome?
- Did undocumented scope expansion occur?
- Do assumptions remain valid?
- Was upstream authority respected?
- Does the next work remain correctly scoped?

Record discrepancies when useful. If current authority has changed or conflicts materially with the planned work, stop because that controlling authority governs. If authority is unchanged, missing a named Atlas-only Continuation Review artifact is not a blocker.

## Evidence and closure requirements

Evidence must support the claim it is used to close. Applicable evidence may include source references, approved decisions, domain and architecture checks, required proof results, acceptance tests, failure and recovery tests, security or privacy checks, performance measurements, audit records and operational observations. Its scope, revision and limitations should be clear where relevant.

Closure follows current authority, the approved Feature Pack/JIT contract, applicable acceptance criteria and the proof, security, privacy, performance, operational and recovery evidence those sources require. A named Grill-Me record, Implementation Handoff, Continuation Review or Atlas checklist item is not an additional closure prerequisite unless an applicable stronger source explicitly requires it; any item required by a stronger source is mandatory because that source owns the requirement.

Atlas checklists and summary formats may help collect or navigate the evidence. They do not create extra closure gates. Missing evidence required by an owning authority or approved contract keeps the work open or blocked; contradictory evidence follows that source's gate or STOP. Code completion alone does not satisfy source-owned acceptance criteria. Closure does not promote the Atlas or any handoff into Product Law, Architecture Law, Domain Law or Roadmap authority.

## Decision Escalation Matrix

Every planning or implementation discovery must be routed to the lowest correct authority that owns the decision. "Lowest correct" means the most specific authority that can decide the question without changing a higher-level rule. The Atlas may record the route and its downstream effect, but it must not decide for that authority.

The authority hierarchy remains the one in Section 1.1. Atlas navigation may help locate source-owned delivery requirements after an approved Roadmap outcome, but it is not a required stage. The canonical Phase 7, proof, execution and readiness sequence is governed by the Roadmap, Platform Operating Model and approved Feature Pack/JIT contracts. The Final Feature Pack Contract remains the development-entry authority.

| Discovery Type | Example Question | Escalation Authority |
|---|---|---|
| Product truth | What should the platform/business do? | Product Law / Decision Register |
| Commercial model | Pricing, packaging, business rules | Product Law / Commercial decisions |
| Legal requirement | Compliance, contracts, obligations | Legal/Product authority |
| Clinical/safety rule | Health, safety, professional judgement | Clinical/Safety authority |
| Domain ownership | Who owns this durable truth? | Domain Map / Domain Law |
| Lifecycle semantics | What states, transitions, guards exist? | Owning Domain |
| Architecture mechanism | How should the platform support this? | Architecture Law |
| Cross-domain interaction | How should domains communicate? | Architecture + affected Domains |
| Delivery sequencing | What comes first? | Roadmap |
| Feature Pack scope | Included/excluded work | Feature Pack Contract |
| Implementation semantics | How exactly should code implement it? | JIT Domain Dossier / TB / VS / HH |
| Execution ambiguity | Coding task unclear | TB / VS / HH contract |
| Evidence problem | Cannot prove completion | Validation/evidence review |
| Operational concern | Monitoring, support, ownership | Operating Model |

### Lower-level artifacts do not resolve higher-level uncertainty

Lower-level artifacts must not resolve higher-level uncertainty. In particular:

- A TOON must not invent missing Product decisions.
- A Vertical Slice must not redefine Domain ownership.
- A JIT Dossier must not override Architecture Law.
- Implementation code must not become the source of business truth.

When a lower-level artifact discovers a question outside its authority, it records the question, the evidence, the affected work and the escalation route. It does not turn a plausible answer into a local rule.

### Escalation response

When uncertainty is discovered, the correct response is:

```text
identify owner
    → escalate
    → update correct authority artifact
    → continue only after resolution
```

The receiving authority updates its own artifact. Recheck affected Atlas navigation when useful before relying on it. If the authority declines to decide, the discovery remains open or stopped under the owning authority, and the next delivery decision records that state.

### Assumption prohibition

Plausible assumptions are not acceptable when:

- financial truth is affected;
- health/safety truth is affected;
- privacy/security boundaries are affected;
- durable ownership is unclear;
- lifecycle semantics are unclear; or
- architecture constraints are violated.

The absence of an immediate failure is not evidence that one of these assumptions is safe. Route the question to its owner and wait for the required resolution or authority decision.

### Escalation STOP conditions

A planner or coding agent must STOP when:

- the required decision belongs to a higher authority layer;
- two authority documents conflict;
- ownership of durable truth is unclear;
- a lifecycle cannot be correctly modelled;
- implementation would require inventing business rules; or
- acceptance criteria depend on unresolved policy.

When escalation requires STOP, report the discovery, evidence, current authority boundary, escalation authority, affected work and condition required before continuation. No lower-level artifact may silently absorb the unresolved decision.

## Future template registry

Future authorized work will provide templates in `docs/templates/`. The templates will standardize the contracts and records described by this governance model:

| Future template | Purpose |
|---|---|
| `FEATURE_PACK_TEMPLATE.md` | Define the approved outcome, implementation boundary, dependencies, gates, acceptance criteria and required lower-level preparation for a Feature Pack. |
| `TB_TEMPLATE.md` | Define an architectural assumption, the smallest proof, involved layers, success evidence and the failure route for a Tracer Bullet. |
| `VS_TEMPLATE.md` | Define one complete production-quality behaviour, its domain and policy boundaries, acceptance criteria and implementation evidence for a Vertical Slice. |
| `HH_TEMPLATE.md` | Define the measured failure or pressure, improvement objective, before/after evidence and regression validation for Horizontal Hardening. |
| `IMPLEMENTATION_HANDOFF_TEMPLATE.md` | Optional format for summarizing implementation impact, tests, evidence, operational requirements, limitations and unlocked future work. |
| `CONTINUATION_REVIEW_TEMPLATE.md` | Optional format for rechecking prior handoff context, repository, tests and current authority, then recording relevant discrepancies and the next delivery decision. |

This registry is conceptual. A template name does not create a required artifact. Only an applicable stronger source or approved contract can require one. ATLAS-01 does not create these files, populate them or create any Feature Pack Contract, JIT Domain Dossier, TB, VS, HH or TOON prompt.

# 2. Atlas terminology and classification system

All Atlas labels describe planning relationships. They are not product state values, database values or implementation interfaces.

## 2.1 Core terms

| Term | Atlas meaning |
|---|---|
| Atlas entry | A derived planning statement with an exact source reference, an owner of the source truth and a stated confidence or gate status. |
| Capability | An outcome-level ability approved by Product Law or the Roadmap. It is not a module, screen, table or provider. |
| Delivery seam | A relationship, boundary or pressure point that later delivery must preserve or prove. |
| Feature Pack | A Roadmap delivery container organized around an outcome and validation objective. The Atlas does not redefine it. |
| Introduction | The first approved delivery use of a capability or cross-cutting concern. |
| Reuse | Use of an already-proven or already-governed capability in another outcome without creating a parallel authority. |
| Extension | An approved additional outcome or lifecycle branch that builds on an existing capability while preserving its authority and invariants. |
| Composition | An outcome assembled from multiple existing capabilities or domains, such as a configured product experience. |
| Projection | A derived, rebuildable or presentation-oriented view of authoritative facts. It never becomes source authority. |
| Lifecycle coverage | The Atlas record of whether a lifecycle exists, who owns it, what upstream semantics are known and where a full implementation-grade specification is required. |
| JIT boundary | The point at which the affected Feature Pack must create or update implementation-grade planning rather than rely on the Atlas. |
| Stop | A controlled halt because the current evidence is missing, contradictory or requires an authority decision not available at the Atlas level. |

## 2.2 Classification axes

Each populated Atlas entry uses only the labels needed for its view. Multiple relationship and pressure labels may apply.

| Axis | Permitted labels | Use |
|---|---|---|
| Authority basis | `PRODUCT`, `ARCHITECTURE`, `DOMAIN`, `ROADMAP`, `SUPPORTING`, `ATLAS_DERIVED`, `JIT`, `EVIDENCE`, `STOP` | Identifies where the statement comes from or where an unresolved matter must be routed. |
| Delivery Character | `FOUNDATIONAL`, `SHARED_REUSE`, `LATER_SPECIALISED` | For the capability inventory, records how the capability participates in the platform's delivery evolution. |
| Authority Scope | `DOMAIN_OWNED`, `CROSS_DOMAIN`, `PLATFORM_CONTROL` | For the capability inventory, records whether authority is held by one Domain, coordinated across Domain-owned truths or primarily a platform/operational control boundary. |
| Delivery relationship | `INTRODUCE`, `REUSE`, `EXTEND`, `COMPOSE`, `PROJECT`, `GATED`, `FUTURE_SEAM` | Describes how a capability or boundary relates to delivery. |
| Readiness | `VISIBLE`, `DEPENDENT`, `GATED`, `JIT_REQUIRED`, `PROVEN`, `STOPPED` | Shows whether a relationship is visible, blocked by a gate, ready for JIT specification, supported by executable evidence or stopped. |
| Lifecycle coverage | `NONE`, `EXISTENCE_ONLY`, `UPSTREAM_SEMANTICS`, `FULL_SPEC_REQUIRED`, `PROOF_REQUIRED`, `STOPPED` | Separates lifecycle visibility from implementation-grade lifecycle design and records when authority is insufficient. |
| Temperature | `HOT`, `WARM`, `COLD`, `UNCLASSIFIED` | Records broad expected use character only. It does not set infrastructure. |
| Pressure | `CONCURRENCY`, `BURST`, `DATABASE`, `ASYNC`, `PROVIDER`, `REALTIME`, `PROJECTION_FRESHNESS`, `EXPORT`, `NONE` | Records a broad pressure that may require later evidence. |
| Risk | `PRODUCT_POLICY`, `OWNERSHIP`, `SAFETY`, `PRIVACY`, `SECURITY`, `LEGAL`, `CLINICAL`, `PROFESSIONAL`, `PROVIDER`, `FAILURE_RECOVERY`, `PERFORMANCE`, `SCOPE` | Identifies why a relationship or gate matters. |

## 2.3 Evidence rule

Every populated entry must include:

- the exact current source path and section, decision, requirement, flow or gate;
- the authority level of that source;
- the Atlas relationship being derived;
- the confidence or readiness label;
- any blocking or future-only gate;
- the next lower-level artifact required, if any; and
- a note when the entry is intentionally broad because exact semantics are JIT.

If an entry cannot meet this evidence rule, the Atlas records `STOPPED` and routes the issue under Section 24 rather than filling the gap with a plausible assumption.

---

# 3. Mature-platform delivery view

## 3.1 View purpose

This view keeps the approved mature-platform outcome in frame while delivery proceeds through smaller outcomes. It must show how a later capability relates to the whole ecosystem without requiring every future capability to be implemented or specified now.

The view may later answer:

- what mature outcome or capability family an entry supports;
- which approved delivery container introduces it;
- which shared capabilities it depends on or reuses;
- which domains and actors participate;
- what lifecycle, journey, integration, measurement, safety, proof and hardening concerns are exposed;
- what remains gated or future-only; and
- which future seam must not be closed by a local implementation choice.

## 3.2 Population structure

The following is an empty planning view. ATLAS-01 does not populate its rows.

| Mature capability or outcome family | Upstream anchor | Delivery relationship | First relevant Feature Pack | Reused or extended by | Domain participation | Lifecycle coverage | Gate / proof / hardening hooks | Future seam | Readiness |
|---|---|---|---|---|---|---|---|---|---|
| _Populate in a later Atlas task._ |  |  |  |  |  |  |  |  |  |

The view must not become a duplicate of the North Star, Platform, Domain Map or Roadmap. It records relationships between those sources and later delivery work.

---

# 4. Feature Pack portfolio map

## 4.1 Portfolio rule

The portfolio map must eventually cover the complete approved Feature Pack portfolio exactly as defined by `docs/history/platform/archive/05_ROADMAP_v1.0.0.md`. The Roadmap remains the authority for Feature Pack identity, outcome, scope, sequencing, dependencies, gates and release effect.

ATLAS-01 defined the map. ATLAS-02 populates only the Feature Pack Portfolio Register from the frozen Roadmap. It does not select FP-001, prepare a Feature Pack or begin Phase 7.

## Feature Pack Portfolio Register

This register is derived from the frozen Roadmap and does not change its Feature Pack identities, sequence, dependencies, gates or release effects. It covers all 17 approved Feature Packs in Roadmap order.

The domain classifications use only the frozen Domain Map names and ownership boundaries:

- **Primary** means the Feature Pack introduces or materially establishes capability whose durable truth belongs to that domain.
- **Supporting** means the Feature Pack interacts with the domain's existing authority.
- **Consumer** means the Feature Pack uses an existing capability from that domain.

These labels describe delivery involvement. They do not move ownership. Gate statuses are recorded as stated by the Roadmap and current Open Work tracker. They are not resolved by this register.

### Portfolio summary

| Feature Pack | Purpose | Delivery Position | Primary Outcome |
|---|---|---|---|
| FP-001 | Establish a trusted bilingual boundary from public entry to verified identity. | Phase 1, position 1, foundational | Verified individual account entry. |
| FP-002 | Convert an approved offer into verified payment and valid access. | Phase 1, position 2, foundational | One reconciled payment and entitlement outcome. |
| FP-003 | Make temperament assessment and report provenance part of the paid core. | Phase 2, position 3, foundational | Bilingual immutable assessment report. |
| FP-004 | Gate personalised guidance through safe intake and eligibility. | Phase 2, position 4, foundational | Current eligibility or governed fallback outcome. |
| FP-005 | Deliver the first safe paid plan, purchased library and feedback value. | Phase 2, position 5, foundational | Seven-day plan or approved General Wellness pathway. |
| FP-006 | Make the core journey operable and ready for staged paid release. | Phase 3, position 6, foundational | Controlled pilot and release decisions. |
| FP-007 | Prove governed live-session and replay value. | Phase 4, position 7, expansion | Protected live and replay experience. |
| FP-008 | Prove the first native Nuwe Jy flagship edition. | Phase 4, position 8, expansion | Operable 60-day Nuwe Jy cohort. |
| FP-009 | Validate genuine recurring value before Basic Membership sale. | Phase 4, position 9, expansion | Operational Basic Membership. |
| FP-010 | Add governed recurring review and plan adjustment. | Phase 4, position 10, expansion | Safe monthly review or adjusted plan. |
| FP-011 | Package proven recurring capabilities as Premium. | Phase 4, position 11, expansion | Versioned Premium bundle. |
| FP-012 | Test a limited professional review service with controlled capacity. | Phase 5, position 12, maturity | Controlled practitioner-review pilot. |
| FP-013 | Use external/community evidence to justify first-party community and challenges. | Phase 5, position 13, maturity | Moderated community and governed challenges. |
| FP-014 | Extend programme evidence into broader habits, journals and progress. | Phase 5, position 14, maturity | Foundation programme and reflective progress capability. |
| FP-015 | Add payment and capacity truth for scarce paid events. | Phase 6, position 15, maturity | Capacity-controlled event commerce. |
| FP-016 | Add governed first-party experimentation when a real decision surface exists. | Phase 6, position 16, maturity | Auditable product learning. |
| FP-017 | Activate a separately approved future product space or market. | Phase 6, position 17, later capability | Controlled future expansion. |

## FP-001 — Trusted bilingual entry and verified identity

### Purpose

This Feature Pack establishes the trusted boundary between a public visitor and every protected NewYou journey. It solves the need for one canonical identity, bilingual launch-facing entry, verified access, required human-facing Platform Member Reference (PMR) assignment under Identity & Access ownership, and controlled account support before purchase, assessment, health, plan or deletion actions can be used safely.

### Intended Outcome

A public visitor can choose Afrikaans or English, understand the launch-facing product and safety boundaries, create an individual 18+ account, receive that Account's required Platform Member Reference, verify email, recover access and use a controlled support/admin path without seeing unfinished product spaces.

### Roadmap Position

- Phase 1, Trusted entry and commercial truth.
- Relative position: 1 of 17 and the first node on the approved core path.
- Delivery character: foundational.
- Platform Member Reference is **REQUIRED** inside this outcome (`RQ-1` / current Roadmap). FP-001 PMR reconciliation is COMPLETE / CERTIFIED under current Open Work. Identity dossier v0.2.0 is CERTIFIED / CURRENT under the separate PR #151 status successor; the promoted/current v0.1.4 snapshot and exact PR #150 candidate remain separately archived. Communications JIT Domain Dossier v0.1.0 is COMPLETE / CERTIFIED / CURRENT; Communications finalisation remains BLOCKED / STOP. This Atlas view does not create the Phase 7C Final Feature Pack Contract or classify proof.
This current routing view records P8-05 / WELL-6 IMPLEMENTATION: AUTHORISED — BOUNDED PHASE 8 ARCHITECTURAL PROOF ONLY. WELL-48: COMPLETE / MERGED VIA PR #156; WELL-49: BLOCKED / WAITING ON WELL-61; WELL-50: BACKLOG / NOT STARTED. WELL-50's agreed WELL-48 Account/PMR contract is complete; its own gates remain. WELL-51 follows the required WELL-48–50 seams and owns the first integrated acceptance boundary; WELL-52 follows WELL-51, and WELL-53 follows WELL-48–52 and closes the P8-05 proof outcome. TB-001 remains INCOMPLETE / COVERAGE-INCOMPLETE; Phase 8 remains NOT CERTIFIED; Phase 9 remains NOT STARTED / NOT AUTHORISED. WELL-45 remains a legal/privacy release gate and the development baselines are NOT LEGALLY APPROVED. This derived view confers no authority independently of Open Work.

### Approved Dependencies

- Frozen Product Law, Architecture Law and Domain Law only.
- No future product Feature Pack is a prerequisite.
- No separate PMR Feature Pack exists or is required.

### Known Unlocks

- `FP-002` purchase, verified payment and entitlement.
- The protected identity boundary required by every later core journey and the staged paid-release path in `FP-006`.
- Later Commerce/Entitlements/Events may use PMR lookup as candidate identity only; possession never proves Account control, authentication, authorisation, Membership, subscription or entitlement.

### High-Level Domain Involvement

- **Primary:** Identity & Access (including Platform Member Reference Account truth; PMR is not its own Domain).
- **Supporting:** Privacy & Consent; Content & Media; Communications; Audit & Evidence.
- **Consumer:** Analytics.

### Known Gates

- `OQ-034 — RESOLVED / ARCHITECTURE SELECTION; PHASE 8 PROOF REQUIRED`: use the approved authentication architecture; executable proof remains incomplete and is not a current FP-001 blocker.
- `OQ-035 — BLOCKS_RELEASE_ONLY`: abuse-control thresholds and recovery behaviour are required before protected public or pilot release.
- `OQ-036 — BLOCKS_RELEASE_ONLY`: email verification and mandatory notices require an approved launch channel policy.
- `OQ-038 — FUTURE_ONLY`: named incident ownership is a paid-pilot and release condition owned by `FP-006`, not a reason to delay safe internal identity work.
- Exact Platform Member Reference encoding/prefix/alphabet/grouping/length/checksum/generator/schema remains downstream and is not frozen here.

### Release Significance

This provides the trusted entry capability that every protected core journey and the first paid pilot depends on. It is foundational, but it is not the participant-ready MVP by itself.

### Authority Anchors

`05_ROADMAP_v1.2.4.md §6 FP-001`, with dependency and phase context in §§3.2, 5 and 14; `04_DOMAIN_MAP_v1.2.0.md §§3–5 and §6.1`; Product PMR law in `00_PLATFORM_v1.12.0.md §21P` / `DEC-297`; current gate and planning routing in `02_OPEN_WORK_v1.2.85.md`.

## FP-002 — Purchase to verified payment and entitlement

### Purpose

This Feature Pack establishes the commercial truth needed for a paid product. It solves the risk that a browser return, provider callback or retry could grant access before payment is verified or multiply a purchase outcome.

### Intended Outcome

A participant can purchase one of the three approved South African/ZAR launch products through the launch payment gateway and receive exactly one valid component entitlement only after payment is verified and reconciled.

### Roadmap Position

- Phase 1, Trusted entry and commercial truth.
- Relative position: 2 of 17, immediately after `FP-001` on the approved core path.
- Delivery character: foundational.

### Approved Dependencies

- `FP-001`.
- The approved initial product catalogue and versioned prices.

### Known Unlocks

- `FP-003` and the paid core capabilities that consume assessment, plan and library access.
- The payment and entitlement relationship later reused by `FP-009`, `FP-011` and `FP-015` where their approved commercial outcomes apply.

### High-Level Domain Involvement

- **Primary:** Commerce; Entitlements.
- **Supporting:** Identity & Access; Privacy & Consent; Audit & Evidence.
- **Consumer:** Analytics.

### Known Gates

- `OQ-004 — BLOCKS_THIS_FP`: provider webhook, retry, refund, dispute and ambiguity behaviour is material to verified payment.
- `OQ-035 — BLOCKS_RELEASE_ONLY`: payment and checkout abuse thresholds and recovery are required before paid public or pilot release.
- `OQ-001 — BLOCKS_RELEASE_ONLY`: operating authority is required before production subscriptions, payment and sensitive processing are activated.
- `OQ-002 — NON_BLOCKING_FOR_THIS_FP`: the three MVP prices are locked; future Basic Membership pricing is not needed here.
- `OQ-036 — NON_BLOCKING_FOR_THIS_FP`: ordinary payment truth does not require a future reminder/channel decision beyond mandatory launch communication.

### Release Significance

This creates the commercial prerequisite for assessment, plan and purchased-library access. It is necessary for the paid core, but it is not by itself a participant-ready MVP.

### Authority Anchors

`docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-002`, with dependency and phase context in §§3.2, 5, 7 and 14; `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §§3–5`; gate context in `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §14` and current unresolved-work context in `docs/history/platform/archive/02_OPEN_WORK_v1.2.28.md §5`.

## FP-003 — Temperament provenance, assessment and immutable report

### Purpose

This Feature Pack makes temperament a trustworthy input to the core proposition. It solves the need to distinguish self-reported, book-derived and digitally assessed temperament, preserve the approved assessment history and deliver a report that can be reproduced and understood in both launch languages.

### Intended Outcome

A purchaser can use a self-reported, book-derived or digitally assessed temperament path, complete the approved assessment when entitled, receive a bilingual report with primary and secondary result and provenance, and retain immutable assessment/report history under deletion law.

### Roadmap Position

- Phase 2, Core participant value loop.
- Relative position: 3 of 17 and the first assessment node after commercial access.
- Delivery character: foundational.

### Approved Dependencies

- `FP-001` and `FP-002`.
- Approved initial methodology and assessment content.

### Known Unlocks

- `FP-004` safety and eligibility work where approved temperament context is requested.
- `FP-005` personalised-plan delivery, which requires the approved temperament input and report path.

### High-Level Domain Involvement

- **Primary:** Temperament.
- **Supporting:** Content & Media; Privacy & Consent; Audit & Evidence.
- **Consumer:** Entitlements; Identity & Access; Analytics.

### Known Gates

- `OQ-013 — BLOCKS_RELEASE_ONLY`: the bilingual report needs the approved governed translation and version path before release.
- `OQ-006 — FUTURE_ONLY`: optional score-distance labels are not required for core launch scoring unless that scope is activated.
- `OQ-009` and `OQ-029 — BLOCKS_RELEASE_ONLY`: retention and deletion categories must be sufficiently approved before paid pilot release.
- Methodology, content and rights approval — `BLOCKS_THIS_FP` for the released assessment version.

### Release Significance

This is the assessment product capability and a required input to personalised plan delivery. It gives the paid core an authoritative, provenance-labelled temperament result rather than an unqualified personalisation claim.

### Authority Anchors

`docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-003`, with dependency and phase context in §§3.2, 5 and 14; `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §§3–5`; current gate definitions in `docs/history/platform/archive/02_OPEN_WORK_v1.2.28.md §5`.

## FP-004 — Safe health onboarding and deterministic eligibility

### Purpose

This Feature Pack establishes the safety boundary before plan generation. It solves the risk that incomplete, high-risk or purpose-mismatched health information could be treated as permission for an automated personalised plan.

### Intended Outcome

A participant completes progressive, purpose-specific health and lifestyle onboarding and receives exactly one current eligibility outcome: `eligible_automated`, `general_wellness_only`, `professional_review_required` or `insufficient_information`.

### Roadmap Position

- Phase 2, Core participant value loop.
- Relative position: 4 of 17, immediately before plan delivery on the approved core path.
- Delivery character: foundational.

### Approved Dependencies

- `FP-001`.
- `FP-003` where temperament context is requested.
- Approved clinical eligibility and urgent-help content.

### Known Unlocks

- `FP-005` safe plan generation for eligible participants and the approved General Wellness fallback.
- The safety boundary reused by the later controlled practitioner path in `FP-012`.

### High-Level Domain Involvement

- **Primary:** Health Records; Safety & Eligibility.
- **Supporting:** Privacy & Consent; Audit & Evidence.
- **Consumer:** Identity & Access; Content & Media; Analytics.

### Known Gates

- `OQ-005 — BLOCKS_THIS_FP`: the clinical eligibility matrix cannot be invented locally.
- `OQ-008 — BLOCKS_THIS_FP`: urgent-safety wording and boundaries need approval before participant release.
- `OQ-007 — FUTURE_ONLY`: laboratory validity belongs to a later laboratory-enabled path, not the initial intake unless that scope changes through authority.
- `OQ-009` and `OQ-029 — BLOCKS_RELEASE_ONLY`: health and professional retention categories are required for pilot release.
- `OQ-033 — NON_BLOCKING_FOR_THIS_FP`: a professional-review outcome can be recorded or routed without activating the practitioner service.

### Release Significance

This unlocks safe plan generation and a lawful General Wellness fallback. It keeps professional review downstream and does not activate a practitioner service.

### Authority Anchors

`docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-004`, with dependency and phase context in §§3.2, 5 and 14; `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §§3–5`; current gate definitions in `docs/history/platform/archive/02_OPEN_WORK_v1.2.28.md §5`.

## FP-005 — Safe seven-day plan, purchased library and basic feedback

### Purpose

This Feature Pack delivers the first promised paid value. It solves the need for a safe, temperament-guided plan and purchased content experience that remains explainable, bilingual and useful without turning participant feedback into clinical authority.

### Intended Outcome

An eligible participant receives an immutable, explainable, bilingual seven-day plan or approved General Wellness Starter Pathway, can access purchased report and plan content, switch approved language and energy-unit presentation, and record lightweight daily or weekly progress and feedback.

### Roadmap Position

- Phase 2, Core participant value loop.
- Relative position: 5 of 17 and the final participant-value node on the initial core path.
- Delivery character: foundational.

### Approved Dependencies

- `FP-001` through `FP-004`.
- Approved calculation, content, recipe/substitution, safety and bilingual versions.

### Known Unlocks

- `FP-006` controlled operations and staged paid release.
- `FP-008` Nuwe Jy, `FP-010` recurring adjustment, `FP-012` practitioner review and `FP-014` foundation-programme work, each of which depends on the proven core plan path.

### High-Level Domain Involvement

- **Primary:** Plans & Nutrition; Habits, Journals & Progress.
- **Supporting:** Content & Media; Safety & Eligibility; Temperament; Privacy & Consent; Audit & Evidence.
- **Consumer:** Entitlements; Identity & Access; Analytics.

### Known Gates

- `OQ-010 — BLOCKS_THIS_FP`: calculation values and bounded weight-reduction rules are part of safe plan truth.
- `OQ-013 — BLOCKS_THIS_FP`: the paid and safety-critical bilingual plan path needs approved locale and version semantics.
- `OQ-016 — BLOCKS_RELEASE_ONLY`: publication, stale-approval and correction/withdrawal operations must be ready before pilot release.
- `OQ-014 — NON_BLOCKING_FOR_THIS_FP`: advanced shared edge delivery is not required to prove plan correctness.
- `OQ-011` and `OQ-012 — FUTURE_ONLY`: automatic monthly adjustment is excluded from this once-off MVP path and belongs to `FP-010`.

### Release Significance

This completes the participant-facing paid core journey. `FP-006` remains necessary before real paid pilot release because participant value alone does not establish operational readiness.

### Authority Anchors

`docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-005`, with dependency and phase context in §§3.2, 5 and 14; `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §§3–5`; current gate definitions in `docs/history/platform/archive/02_OPEN_WORK_v1.2.28.md §5`.

## FP-006 — Controlled core operations and staged paid release

### Purpose

This Feature Pack turns a technically complete core journey into a service that named people can operate. It solves the release gap between working participant behaviour and a paid pilot that can be supported, observed, corrected, withdrawn and stopped safely.

### Intended Outcome

Named operators can run, support, observe, correct, withdraw, reconcile and safely stop the approved core journey through internal validation, the first 10 paid participants, review, expansion toward 25, a maximum of 50 in the first paid pilot, limited public release and general public release decisions.

### Roadmap Position

- Phase 3, Controlled paid evidence and pilot progression.
- Relative position: 6 of 17 and the release/evidence boundary for the foundational core.
- Delivery character: foundational.

### Approved Dependencies

- `FP-001` through `FP-005`.
- Named product, clinical, content, commerce, legal/privacy, security and operations owners.

### Known Unlocks

- The Phase 4 branches: `FP-007`, `FP-008`, `FP-009`, `FP-010` and `FP-011`.
- The Phase 5 and Phase 6 branches: `FP-012`, `FP-013`, `FP-014`, `FP-015`, `FP-016` and `FP-017`, subject to their own gates and evidence.

### High-Level Domain Involvement

- **Primary:** Audit & Evidence.
- **Supporting:** Analytics; Identity & Access; Privacy & Consent; Commerce; Entitlements; Temperament; Health Records; Safety & Eligibility; Plans & Nutrition; Content & Media; Communications.

### Known Gates

- `OQ-001 — BLOCKS_RELEASE_ONLY`: operating authority must support production subscriptions and sensitive health processing.
- `OQ-009` and `OQ-029 — BLOCKS_THIS_FP`: pilot operation needs approved enough retention categories for the records it handles.
- `OQ-030`, `OQ-031` and `OQ-032 — BLOCKS_THIS_FP`: external processor deletion/export, deletion-safe restore and operational deletion/export behaviour must protect the pilot.
- `OQ-035`, `OQ-036`, `OQ-037` and `OQ-038 — BLOCKS_RELEASE_ONLY`: abuse, communications, continuity and incident ownership are release-readiness conditions.
- `OQ-039 — NON_BLOCKING_FOR_THIS_FP`: implementation-grade mapping remains scoped to later affected delivery work.
- The Product Law cross-functional paid-pilot readiness gate remains required.

### Release Significance

This is the operational boundary for internal validation, the first 10 paid participants, expansion toward 25, the first pilot maximum of 50 and later limited or general public release decisions. It is the release backbone of the foundational journey.

### Authority Anchors

`docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-006`, with dependency and phase context in §§3.2, 5, 7, 8 and 14; `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §§3–5`; current gate definitions in `docs/history/platform/archive/02_OPEN_WORK_v1.2.28.md §§5 and 7`.

## FP-007 — Governed live sessions and replay

### Purpose

This Feature Pack proves live value as a governed participant experience before scarce event commerce is considered. It solves the need for protected live access, recording and replay with clear provider, consent and recovery boundaries.

### Intended Outcome

A participant can discover and register for an approved live session, pass current entitlement and access checks, join protected playback and receive a governed replay where recording and consent rules allow. Operators can see provider or delivery failure without changing platform truth.

### Roadmap Position

- Phase 4, First recurring and flagship pathways.
- Relative position: 7 of 17 and the first later branch after the controlled core release boundary.
- Delivery character: expansion.

### Approved Dependencies

- `FP-006`.
- An approved session owner and live/replay content and policy.

### Known Unlocks

- `FP-008` Nuwe Jy live integration.
- `FP-009` recurring live value.
- `FP-015` event commerce, together with the approved `FP-002` payment path and `FP-006` operational evidence.

### High-Level Domain Involvement

- **Primary:** Events & Live.
- **Supporting:** Entitlements; Content & Media; Communications; Privacy & Consent; Audit & Evidence.
- **Consumer:** Identity & Access; Analytics.

### Known Gates

- `OQ-020 — BLOCKS_THIS_FP`: the provider path and failure behaviour are part of the live/replay outcome.
- `OQ-021 — BLOCKS_THIS_FP`: recording, attendee, replay and withdrawal rules require approval.
- `OQ-036 — BLOCKS_THIS_FP` for a promised live notification journey.
- `OQ-017 — NON_BLOCKING_FOR_THIS_FP`: reminders are optional until a governed reminder promise is added.
- `OQ-022 — FUTURE_ONLY`: scarce reservations and flash-sale mechanics belong to `FP-015`.

### Release Significance

This unlocks governed live and replay value for Nuwe Jy and early Membership. It does not activate paid event commerce or scarce-capacity ticketing.

### Authority Anchors

`docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-007`, with dependency and phase context in §§3.2, 5, 12 and 14; `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §§3–5`; current gate definitions in `docs/history/platform/archive/02_OPEN_WORK_v1.2.28.md §5`.

## FP-008 — Native Nuwe Jy flagship edition

### Purpose

This Feature Pack makes Nuwe Jy the first concrete test of native programme delivery. It solves the need to turn the approved flagship experience into an operable scheduled cohort without building a generic programme platform before evidence requires one.

### Intended Outcome

The first native Nuwe Jy edition can operate as an approved 60-calendar-day scheduled cohort with a Today experience, daily releases, habits, check-ins, progress and recovery, temperament-aware delivery, central safety and plan integration, governed cohort community, live/replay, support, communications and compassionate completion evidence.

### Roadmap Position

- Phase 4, First recurring and flagship pathways.
- Relative position: 8 of 17, a sibling branch with `FP-009` after the shared live and operational foundation.
- Delivery character: expansion.
- `FP-009` is not a hard prerequisite for this pack.

### Approved Dependencies

- `FP-005`, `FP-006` and `FP-007`.
- Approved Nuwe Jy content/source inventory and edition owners.

### Known Unlocks

- `FP-013` first-party community and governed challenges, where the required evidence is present.
- `FP-014` broader foundation-programme capability, using Nuwe Jy as the concrete programme acceptance path.

### High-Level Domain Involvement

- **Primary:** Programmes & Challenges.
- **Supporting:** Habits, Journals & Progress; Community; Events & Live; Content & Media; Entitlements; Temperament; Safety & Eligibility; Plans & Nutrition; Communications; Privacy & Consent; Audit & Evidence.
- **Consumer:** Identity & Access; Analytics.

### Known Gates

- `OQ-024 — BLOCKS_THIS_FP`: source content, media, rights and translation inventory must be approved.
- `OQ-025 — BLOCKS_THIS_FP`: Nuwe Jy safety, milestone and completion rules must be approved.
- `OQ-026 — BLOCKS_THIS_FP`: cohort, facilitator, moderator, support, live ownership and saleable capacity must be clear.
- `OQ-027 — BLOCKS_THIS_FP`: scheduled communication channels, deduplication, caps and failure ownership are required.
- `OQ-019 — BLOCKS_THIS_FP`: edition completion metrics are part of the product outcome.
- `OQ-020`, `OQ-021`, `OQ-017` and `OQ-036 — BLOCKS_RELEASE_ONLY`: applicable live, recording, reminder and notification paths must be resolved before activation.
- `OQ-023` and `OQ-028 — BLOCKS_RELEASE_ONLY`: governed external community operation and legacy cutover obligations must be clear before activation.
- Inherited clinical, translation and retention gates remain applicable.

### Release Significance

This is the first native flagship edition and the concrete acceptance path for reusable programme, edition and cohort capability. It is an expansion outcome after the paid core has been proven and operated.

### Authority Anchors

`docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-008`, with dependency and phase context in §§3.2, 5, 9, 12 and 14; `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §§3–5`; current gate definitions in `docs/history/platform/archive/02_OPEN_WORK_v1.2.28.md §5`.

## FP-009 — Basic Membership recurring value

### Purpose

This Feature Pack tests whether NewYou can sell recurring value honestly. It solves the need for an operational Membership contract with real content, live, community and Q&A value before recurring revenue is promised.

### Intended Outcome

A participant can buy and maintain Basic Monthly or Annual Membership and receive genuinely operational moderated community access, at least one approved member-content release per month, at least one live session per month, group Q&A submission and correct entitlement and cancellation behaviour.

### Roadmap Position

- Phase 4, First recurring and flagship pathways.
- Relative position: 9 of 17, a sibling branch with `FP-008`; the Roadmap does not require `FP-008` to come first.
- Delivery character: expansion.

### Approved Dependencies

- `FP-002`, `FP-006` and `FP-007`.
- A governed community operating path and approved monthly value owners.
- `FP-008` is useful evidence but is not a circular hard dependency.

### Known Unlocks

- `FP-011` Premium bundle, where the approved packaging uses the Membership contract.
- Evidence for `FP-013` first-party community and governed challenges.

### High-Level Domain Involvement

- **Primary:** Commerce; Entitlements.
- **Supporting:** Community; Content & Media; Events & Live; Communications; Identity & Access; Privacy & Consent; Audit & Evidence.
- **Consumer:** Analytics.

### Known Gates

- `OQ-004 — BLOCKS_THIS_FP`: recurring billing, failed-payment, cancellation, refund and provider-delivery behaviour is the commercial contract.
- `OQ-016 — BLOCKS_THIS_FP`: monthly approved content needs reliable publication and stale-approval recovery.
- `OQ-023 — BLOCKS_THIS_FP`: the governed community path needs moderation, privacy, disclosure and escalation policy.
- `OQ-020` and `OQ-021 — BLOCKS_RELEASE_ONLY`: any Membership-specific live promise must pass its operational gate.
- `OQ-001` and `OQ-002 — BLOCKS_RELEASE_ONLY`: operating authority and evidence-based public pricing are required before sale.
- `OQ-017` and `OQ-036 — BLOCKS_RELEASE_ONLY`: recurring reminders and notifications cannot be promised before channel, consent, quiet-hour and retry policy is approved.

### Release Significance

This enables Basic Membership only after its promised recurring value is operational through a complete billing period. It does not justify Premium, first-party community or event commerce by itself.

### Authority Anchors

`docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-009`, with dependency and phase context in §§3.2, 5, 10, 12 and 14; `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §§3–5`; gate context in `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §14` and current unresolved-work context in `docs/history/platform/archive/02_OPEN_WORK_v1.2.28.md §5`.

## FP-010 — Recurring plan review and governed adjustment

### Purpose

This Feature Pack establishes a safe recurring review boundary after once-off plan delivery is useful. It solves the need for governed plan adjustment based on approved check-ins and trends without allowing progress data to become Safety authority.

### Intended Outcome

An entitled participant with sufficient approved check-ins can receive a monthly trend-based review and, where allowed, an immutable governed plan adjustment with explicit grace or incomplete-check-in behaviour and renewed safety evaluation.

### Roadmap Position

- Phase 4, First recurring and flagship pathways.
- Relative position: 10 of 17, after stable once-off plan delivery and useful check-ins.
- Delivery character: expansion.
- `FP-009` is not required unless the adjustment is packaged through Membership.

### Approved Dependencies

- `FP-005` and `FP-006`.
- Approved trend and check-in evidence and clinical/product review rules.
- `FP-009` only when the adjustment is packaged through Membership.

### Known Unlocks

- The recurring adjustment capability used by `FP-011` Premium packaging.
- A governed adjustment add-on where that commercial outcome is approved.

### High-Level Domain Involvement

- **Primary:** Plans & Nutrition.
- **Supporting:** Habits, Journals & Progress; Health Records; Safety & Eligibility; Entitlements; Temperament; Content & Media; Privacy & Consent; Audit & Evidence; Commerce where an add-on is sold.
- **Consumer:** Identity & Access; Analytics.

### Known Gates

- `OQ-003`, `OQ-011` and `OQ-012 — BLOCKS_THIS_FP`: monthly review contract, adjustment thresholds and review timing define the outcome.
- `OQ-010 — BLOCKS_RELEASE_ONLY`: calculation approval is required if an adjustment changes approved calculation values.
- `OQ-005 — BLOCKS_RELEASE_ONLY`: current eligibility and safety rules must still be applied before an adjusted plan is activated.
- `OQ-018 — NON_BLOCKING_FOR_THIS_FP`: basic check-ins need not become private journals.
- `OQ-004 — FUTURE_ONLY` unless a new recurring payment contract is included; packaged billing belongs to `FP-011`.

### Release Significance

This unlocks the plan-adjustment add-on and provides the capability prerequisite for Premium. It is deliberately later than the once-off MVP because recurring adjustment carries additional safety and review obligations.

### Authority Anchors

`docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-010`, with dependency and phase context in §§3.2, 5, 10 and 14; `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §§3–5`; current gate definitions in `docs/history/platform/archive/02_OPEN_WORK_v1.2.28.md §5`.

## FP-011 — Premium bundle around proven capability

### Purpose

This Feature Pack turns already-proven recurring capabilities into a commercial Premium offer. It solves the risk that Premium becomes a promise for unresolved clinical, billing or operational work or creates a second access model.

### Intended Outcome

Premium is sold as a versioned bundle of working recurring review and adjustment and approved benefits through the existing Commerce and Entitlements model, including governed reassessment rules where applicable, without promising unlimited practitioner access.

### Roadmap Position

- Phase 4, First recurring and flagship pathways.
- Relative position: 11 of 17, after the applicable Membership and adjustment capabilities are proven.
- Delivery character: expansion.

### Approved Dependencies

- `FP-010`.
- `FP-009` when Premium uses the Membership contract.
- `FP-002`, `FP-005` and `FP-006`.
- Approved benefits and pricing.

### Known Unlocks

- The validated higher-value Premium commercial tier and its approved component benefits.
- No later Feature Pack is an explicit prerequisite of this pack's outcome.

### High-Level Domain Involvement

- **Primary:** Commerce.
- **Supporting:** Entitlements; Plans & Nutrition; Habits, Journals & Progress; Health Records; Safety & Eligibility; Content & Media; Communications; Privacy & Consent; Audit & Evidence.
- **Consumer:** Identity & Access; Analytics.

### Known Gates

- `OQ-003`, `OQ-011` and `OQ-012 — BLOCKS_THIS_FP`: Premium cannot promise monthly review or adjustment before those rules operate.
- `OQ-004 — BLOCKS_THIS_FP`: billing, failed-payment, cancellation, reassessment and refund consequences need validated provider behaviour.
- `OQ-001` and `OQ-002 — BLOCKS_RELEASE_ONLY`: operating authority and evidence-based Premium pricing are required before public sale.
- `OQ-036 — BLOCKS_RELEASE_ONLY`: recurring benefit communications need approved channel, consent and retry behaviour.
- Existing Commerce and Entitlements ownership — `NON_BLOCKING_FOR_THIS_FP`: Product and Domain Law require reuse of the existing owners.

### Release Significance

This enables a validated higher-value commercial tier only after its component capabilities pass their own gates. It preserves one commercial and access model and does not create an unlimited practitioner expectation.

### Authority Anchors

`docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-011`, with dependency and phase context in §§3.2, 5, 10 and 14; `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §§3–5`; gate context in `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §14` and current unresolved-work context in `docs/history/platform/archive/02_OPEN_WORK_v1.2.28.md §5`.

## FP-012 — Controlled practitioner review pilot

### Purpose

This Feature Pack tests whether limited professional review is safe, useful and operable after automated plan delivery is stable. It solves the need for a capacity-controlled service without turning NewYou into an open practitioner marketplace.

### Intended Outcome

An eligible participant can purchase a limited practitioner-review service, provide explicit consent, receive a scoped active relationship and structured review outcome, and receive an approved modification, restriction, follow-up or referral with capacity and turnaround visible to operators and participants.

### Roadmap Position

- Phase 5, Professional care and evidence-led community/behaviour change.
- Relative position: 12 of 17 and the first professional-care branch.
- Delivery character: maturity.

### Approved Dependencies

- `FP-004`, `FP-005` and `FP-006`.
- Authorised practitioner(s), explicit service price and approved turnaround and capacity.

### Known Unlocks

- A limited priced practitioner-review service with evidence about demand, safety, capacity and economics.
- A governed professional-care pathway, without opening a practitioner marketplace.

### High-Level Domain Involvement

- **Primary:** Professional Care.
- **Supporting:** Identity & Access; Privacy & Consent; Health Records; Safety & Eligibility; Plans & Nutrition; Commerce; Entitlements; Communications; Audit & Evidence.
- **Consumer:** Analytics.

### Known Gates

- `OQ-033 — BLOCKS_THIS_FP`: professional record authority, participant access, addendum and disposition rules are necessary.
- `OQ-001 — BLOCKS_THIS_FP`: practitioner contracting and sensitive professional processing require operating authority.
- `OQ-009` and `OQ-029 — BLOCKS_THIS_FP`: professional and health retention categories must be approved before cases are sold.
- Practitioner agreements and saleable-capacity approval — `BLOCKS_THIS_FP`.
- `OQ-004 — BLOCKS_RELEASE_ONLY` if the service introduces a new recurring billing contract; a once-off review may reuse the approved payment path.

### Release Significance

This enables a limited, priced and capacity-controlled practitioner-review pilot. It validates professional care as a scarce service while preserving the automated MVP boundary.

### Authority Anchors

`docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-012`, with dependency and phase context in §§3.2, 5, 11 and 14; `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §§3–5`; current gate definitions in `docs/history/platform/archive/02_OPEN_WORK_v1.2.28.md §5`.

## FP-013 — First-party community and governed challenges

### Purpose

This Feature Pack moves first-party community work behind evidence from Nuwe Jy, Membership and governed external participation. It solves the need for NewYou-specific community and challenge value without building a generic social network or skipping moderation and privacy policy.

### Intended Outcome

Participants can join a first-party moderated community and safe governed challenges with current entitlement checks, privacy-aware profiles, private progress and recognition, reporting, moderation, sanctions, appeals and deletion or anonymisation behaviour.

### Roadmap Position

- Phase 5, Professional care and evidence-led community/behaviour change.
- Relative position: 13 of 17, after the required Nuwe Jy or Membership evidence.
- Delivery character: maturity.

### Approved Dependencies

- `FP-006`.
- Evidence from `FP-008` and/or `FP-009`.
- `FP-007` if live or challenge sessions are included.

### Known Unlocks

- A first-party community pilot and governed challenges where evidence supports them.
- A NewYou-owned participation path beyond the governed external validation channel.

### High-Level Domain Involvement

- **Primary:** Community; Programmes & Challenges.
- **Supporting:** Habits, Journals & Progress; Entitlements; Privacy & Consent; Content & Media; Communications; Safety & Eligibility; Audit & Evidence.
- **Consumer:** Identity & Access; Analytics.

### Known Gates

- `OQ-023 — BLOCKS_THIS_FP`: first-party community needs operating, privacy, moderation and evidence policy.
- `OQ-019 — BLOCKS_THIS_FP`: challenge completion and recognition rules must be approved before a challenge is published.
- `OQ-018 — BLOCKS_RELEASE_ONLY` when private journals or attachments enter scope.
- `OQ-017` and `OQ-036 — BLOCKS_RELEASE_ONLY`: reminders and notifications are conditional surfaces.
- `OQ-035 — BLOCKS_RELEASE_ONLY`: distributed abuse thresholds are required before high-volume public community release.
- Moderation staffing and safety escalation remain known operational gates.

### Release Significance

This enables first-party community and governed challenges only when external and flagship evidence justifies them. It is a maturity outcome, not an MVP prerequisite.

### Authority Anchors

`docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-013`, with dependency and phase context in §§3.2, 5, 12 and 14; `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §§3–5`; current gate definitions in `docs/history/platform/archive/02_OPEN_WORK_v1.2.28.md §5`.

## FP-014 — Foundation programme, habits and reflective progress

### Purpose

This Feature Pack extends the concrete Nuwe Jy programme evidence into a broader behaviour-change capability. It solves the need for structured programmes, habits, private reflections and compassionate progress without making a generic LMS an early prerequisite.

### Intended Outcome

Participants can enrol in a broader approved foundation programme, receive structured lessons and activities and habits, record private reflections and progress, recover after missed days and receive compassionate versioned completion or continuation outcomes.

### Roadmap Position

- Phase 5, Professional care and evidence-led community/behaviour change.
- Relative position: 14 of 17, after Nuwe Jy or equivalent approved programme proof.
- Delivery character: maturity.

### Approved Dependencies

- `FP-005` and `FP-006`.
- `FP-008` or equivalent approved programme proof.
- Approved programme content, translations, completion and communication rules.

### Known Unlocks

- A longer foundation programme and durable habit, journal and reflective-progress capability.
- Broader programme delivery only after the concrete programme evidence supports generalisation.

### High-Level Domain Involvement

- **Primary:** Programmes & Challenges; Habits, Journals & Progress.
- **Supporting:** Content & Media; Entitlements; Plans & Nutrition; Safety & Eligibility; Communications; Community; Privacy & Consent; Audit & Evidence.
- **Consumer:** Identity & Access; Analytics.

### Known Gates

- `OQ-018 — BLOCKS_THIS_FP` for journal or attachment scope: private journal protection and deletion/export cannot be guessed.
- `OQ-019 — BLOCKS_THIS_FP`: programme completion and participation rules need approval before publication.
- `OQ-017` and `OQ-016 — BLOCKS_RELEASE_ONLY`: reminders and publication operations must be resolved for the promised delivery mode.
- `OQ-013 — BLOCKS_RELEASE_ONLY`: required bilingual programme content needs the approved translation path.
- `OQ-009` and `OQ-029 — BLOCKS_RELEASE_ONLY`: retention categories are required before a broader record set enters pilot or release.

### Release Significance

This enables the longer foundation programme and durable habit and reflective-progress capability. It keeps journals private and separate from clinical and community authority.

### Authority Anchors

`docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-014`, with dependency and phase context in §§3.2, 5, 12 and 14; `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §§3–5`; current gate definitions in `docs/history/platform/archive/02_OPEN_WORK_v1.2.28.md §5`.

## FP-015 — Event commerce and scarce capacity

### Purpose

This Feature Pack introduces scarce-capacity commerce only after ordinary live access and core operations are proven. It solves the need to sell paid events without treating checkout UI as proof that capacity, payment, ticket issuance and failure handling are correct.

### Intended Outcome

A participant can browse an approved paid event, obtain an expiring capacity hold, pay, receive a ticket, transfer, check in, cancel, refund or receive credit under the accepted event policy, with zero confirmed oversell under concurrency and failure.

### Roadmap Position

- Phase 6, Scarce commerce, experimentation and approved future expansion.
- Relative position: 15 of 17 and the first scarce-capacity commerce path.
- Delivery character: maturity.

### Approved Dependencies

- `FP-002`, `FP-006` and `FP-007`.
- Approved event policy, provider path and event operator.

### Known Unlocks

- A paid event catalogue and capacity-controlled ticket commerce.

### High-Level Domain Involvement

- **Primary:** Events & Live.
- **Supporting:** Commerce; Entitlements; Privacy & Consent; Communications; Content & Media; Audit & Evidence.
- **Consumer:** Identity & Access; Analytics.

### Known Gates

- `OQ-022 — BLOCKS_THIS_FP`: reservation, expiry, waitlist and scarce-capacity protection are the core outcome.
- `OQ-004 — BLOCKS_THIS_FP`: event payment and ticket issuance must reconcile with the provider path.
- `OQ-035 — BLOCKS_THIS_FP`: admission, rate and abuse behaviour is part of safe scarce-capacity operation.
- `OQ-020` and `OQ-021 — BLOCKS_RELEASE_ONLY` for live or recorded event variants.
- `OQ-036` is a conditional release gate for event communications: it applies before an event communication promise is released. Roadmap §14 schedules it at the affected notification boundary; ordinary ticket commerce does not add that dependency.
- `OQ-014 — NON_BLOCKING_FOR_THIS_FP`: ordinary event information delivery is not the capacity authority.

### Release Significance

This enables paid events with capacity and ticket truth. It is intentionally later than governed live sessions and is not part of the core MVP.

### Authority Anchors

`docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-015`, with dependency and phase context in §§3.2, 5, 12 and 14; `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §§3–5`; current gate definitions in `docs/history/platform/archive/02_OPEN_WORK_v1.2.28.md §5`.

## FP-016 — First-party experimentation and learning

### Purpose

This Feature Pack creates a governed way to learn from real product decisions after pilot measurement is already available. It solves the need for evidence-backed comparison without allowing experimentation to alter payment, entitlement, safety, consent, accessibility, security, accounting or clinical truth.

### Intended Outcome

Operators can run approved first-party A/B/n experiments on governed web/page and eligible message experiences with stable assignment, exposure evidence, protected-invariant exclusions, authoritative conversion and income reconciliation, privacy/deletion handling and durable auditable learning.

### Roadmap Position

- Phase 6, Scarce commerce, experimentation and approved future expansion.
- Relative position: 16 of 17, after `FP-006` has established a real measurable decision surface.
- Delivery character: maturity.

### Approved Dependencies

- `FP-006`.
- A concrete approved experiment hypothesis and measurable governed surface.
- `FP-002` and/or `FP-009` only when a commerce outcome is the readout.

### Known Unlocks

- Evidence-backed product, content and commerce learning.
- Governed optimisation of public or eligible message surfaces where the approved decision warrants it.

### High-Level Domain Involvement

- **Primary:** Experimentation; Analytics.
- **Supporting:** Content & Media; Communications; Commerce when the experiment readout is commercial; Privacy & Consent; Audit & Evidence.
- **Consumer:** Identity & Access.

### Known Gates

- `OQ-040 — BLOCKS_THIS_FP`: assignment, exposure, measurement, statistical validity, privacy/deletion and failure/recovery proof are the pack outcome.
- `OQ-014 — BLOCKS_RELEASE_ONLY` if experiment-sensitive shared edge delivery is proposed.
- `OQ-013`, `OQ-015`, `OQ-016` and `OQ-036 — NON_BLOCKING_FOR_THIS_FP` until the selected experiment surface uses the corresponding content, search, publication or message mechanism.
- `OQ-030` and `OQ-032 — BLOCKS_RELEASE_ONLY` for participant-facing experiments using external measurement processors.

### Release Significance

This enables auditable product learning after a real decision surface exists. It is not a generic feature-flag replacement and does not become a prerequisite for the first pilot's basic measurement.

### Authority Anchors

`docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-016`, with dependency and phase context in §§3.2, 5, 13 and 14; `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §§3–5`; current gate definitions in `docs/history/platform/archive/02_OPEN_WORK_v1.2.28.md §5`.

## FP-017 — Approved product-space or market expansion

### Purpose

This conditional Feature Pack protects the approved future direction without inventing a second product or market now. It solves the need to activate a concrete future expansion through shared platform boundaries only after Product, commercial, legal, clinical and market authority approves it.

### Intended Outcome

A concrete, separately approved future product space or market can activate through the shared identity, commerce, entitlement, content, safety, privacy, analytics and operational boundaries without exposing unfinished products or creating unrestricted generic tenancy.

### Roadmap Position

- Phase 6, Scarce commerce, experimentation and approved future expansion.
- Relative position: 17 of 17, last in the current approved sequence and trigger-based.
- Delivery character: later capability.

### Approved Dependencies

- `FP-006`.
- The relevant proven shared capabilities.
- A new explicit Product Law, commercial, legal and clinical direction identifying the product space or market.
- No generic-tenancy assumption.

### Known Unlocks

- A deliberately approved future product-space or market activation.
- Controlled reuse of shared platform capabilities after the concrete expansion receives its own authority and evidence.

### High-Level Domain Involvement

- **Conditional impact set from the Domain Map:** Identity & Access; Privacy & Consent; Temperament; Health Records; Safety & Eligibility; Plans & Nutrition; Content & Media; Programmes & Challenges; Habits, Journals & Progress; Commerce; Entitlements; Community; Events & Live; Professional Care; Communications; Experimentation; Analytics; Audit & Evidence.
- **Primary:** Not assigned at Atlas level. The domain or domains owning the approved expansion outcome must be named by the new Product Law direction.
- **Supporting:** Not assigned before that direction defines the concrete product or market scope.
- **Consumer:** Not assigned before that direction defines the concrete product or market scope. No domain role is inferred merely because the shared platform can be reused.

### Known Gates

- Concrete product or market approval — `BLOCKS_THIS_FP`.
- Market legal, payment, privacy and safety review — `BLOCKS_THIS_FP`.
- Existing core gates — `NON_BLOCKING_FOR_THIS_FP` only where the shared mechanism and protected invariant remain unchanged; affected gates reopen at the relevant release boundary.
- Generic multi-tenant or corporate platform work — `FUTURE_ONLY` and not an approved expansion path by itself.

### Release Significance

This is the controlled path for a future product-space or market activation. It is not a launch dependency and must remain invisible until a concrete approved direction exists.

### Authority Anchors

`docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-017`, with dependency and phase context in §§3.2, 5, 13, 14 and 16; `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §§3–5`; current gate definitions in `docs/history/platform/archive/02_OPEN_WORK_v1.2.28.md §5`.

---

# 5. Capability introduction/reuse register

## 5.1 Register rule

This area establishes the canonical medium-resolution platform capability vocabulary. It prevents parallel authority, duplicated semantics and accidental reimplementation of a capability that the Roadmap intends to share. ATLAS-03 establishes capability identity and two orthogonal classifications only. ATLAS-04 owns the complete capability-to-Feature-Pack introduction, reuse, extension and specialisation matrix.

The inventory may describe broad future reuse or extension context. It does not classify every Feature Pack relationship. `REUSE` means the same authority and invariant may be used again; it does not mean that later work may copy or fork the authority.

### ATLAS-03 classification definitions

The inventory separates delivery evolution from authority shape. `Delivery Character` does not describe ownership, and `Authority Scope` does not replace `Authoritative Domain`.

| Axis | Label | Definition |
|---|---|---|
| Delivery Character | `FOUNDATIONAL` | Required early enough to become a reusable platform foundation for approved downstream outcomes. |
| Delivery Character | `SHARED_REUSE` | A reusable capability that participates across multiple approved outcomes but is not best described primarily as a later specialised branch. |
| Delivery Character | `LATER_SPECIALISED` | A capability intentionally activated or materially specialised only at a later approved maturity or Feature Pack stage. |
| Authority Scope | `DOMAIN_OWNED` | One frozen Domain clearly owns the principal durable business truth even if many Feature Packs reuse the capability. |
| Authority Scope | `CROSS_DOMAIN` | The capability coordinates, projects or composes multiple Domain-owned truths without becoming a second authoritative owner. |
| Authority Scope | `PLATFORM_CONTROL` | The capability is primarily a platform or operational control boundary rather than a durable business-truth Domain, while affected Domains retain their business authority. |

Every capability continues to name its actual `Authoritative Domain`, or explicitly records the no-single-Domain/platform-control boundary. No classification creates shared authoritative writes.

## 5.2 Platform capability inventory

The entries below are the canonical working vocabulary for reusable NewYou platform abilities. Their order follows the broad trusted-entry, paid-core, mature-platform and cross-cutting dependency logic in current authority. The order is not an implementation sequence and does not authorise delivery work.

### Summary register

| Capability ID | Capability | Delivery Character | Authority Scope | Authoritative Domain | Lifecycle | Security/Safety | Performance |
|---|---|---|---|---|---|---|---|
| CAP-001 | Canonical identity and authentication | FOUNDATIONAL | DOMAIN_OWNED | Identity & Access | YES | HIGH | BURST_SENSITIVE |
| CAP-002 | Scoped authorisation and relationship access | FOUNDATIONAL | CROSS_DOMAIN | Identity & Access plus relationship owners | YES | HIGH | HIGH |
| CAP-003 | Consent and purpose control | FOUNDATIONAL | DOMAIN_OWNED | Privacy & Consent | YES | HIGH | HIGH |
| CAP-004 | Data rights, retention and deletion orchestration | FOUNDATIONAL | CROSS_DOMAIN | Privacy & Consent | YES | HIGH | HIGH |
| CAP-005 | Public discovery and acquisition | FOUNDATIONAL | CROSS_DOMAIN | No single Domain; underlying owners retain truth | CONDITIONAL | MODERATE | MODERATE |
| CAP-006 | Governed content, translation and publication | FOUNDATIONAL | DOMAIN_OWNED | Content & Media | YES | HIGH | HIGH |
| CAP-007 | Explainable content discovery and relevance | SHARED_REUSE | CROSS_DOMAIN | Content & Media for source content; no separate relevance authority | NO | HIGH | HIGH |
| CAP-008 | Protected media and content delivery | SHARED_REUSE | CROSS_DOMAIN | Content & Media | YES | HIGH | HIGH |
| CAP-009 | Commercial catalogue and offer management | FOUNDATIONAL | DOMAIN_OWNED | Commerce | YES | MODERATE | MODERATE |
| CAP-010 | Payment and commercial reconciliation | FOUNDATIONAL | DOMAIN_OWNED | Commerce | YES | HIGH | BURST_SENSITIVE |
| CAP-011 | Entitlement and access-rights management | FOUNDATIONAL | DOMAIN_OWNED | Entitlements | YES | HIGH | HIGH |
| CAP-012 | Temperament assessment and profile | FOUNDATIONAL | DOMAIN_OWNED | Temperament | YES | HIGH | MODERATE |
| CAP-013 | Health and lifestyle records | FOUNDATIONAL | DOMAIN_OWNED | Health Records | YES | HIGH | MODERATE |
| CAP-014 | Safety and eligibility routing | FOUNDATIONAL | DOMAIN_OWNED | Safety & Eligibility | YES | SAFETY_CRITICAL | HIGH |
| CAP-015 | Deterministic plan generation and versioning | FOUNDATIONAL | DOMAIN_OWNED | Plans & Nutrition | YES | SAFETY_CRITICAL | MODERATE |
| CAP-016 | Governed plan review and adjustment | LATER_SPECIALISED | DOMAIN_OWNED | Plans & Nutrition | YES | SAFETY_CRITICAL | MODERATE |
| CAP-017 | Communications and notification delivery | FOUNDATIONAL | DOMAIN_OWNED | Communications | YES | HIGH | BURST_SENSITIVE |
| CAP-018 | Programme and cohort delivery | LATER_SPECIALISED | DOMAIN_OWNED | Programmes & Challenges | YES | HIGH | BURST_SENSITIVE |
| CAP-019 | Participant progress and feedback | SHARED_REUSE | DOMAIN_OWNED | Habits, Journals & Progress | YES | MODERATE | HIGH |
| CAP-020 | Habits and private reflective practice | LATER_SPECIALISED | DOMAIN_OWNED | Habits, Journals & Progress | YES | HIGH | HIGH |
| CAP-021 | Live-session and replay delivery | SHARED_REUSE | DOMAIN_OWNED | Events & Live | YES | HIGH | BURST_SENSITIVE |
| CAP-022 | Recurring commercial access | LATER_SPECIALISED | CROSS_DOMAIN | Commerce, with Entitlements for access rights | YES | HIGH | BURST_SENSITIVE |
| CAP-023 | Professional review and scoped care | LATER_SPECIALISED | DOMAIN_OWNED | Professional Care | YES | SAFETY_CRITICAL | MODERATE |
| CAP-024 | Community participation and moderation | LATER_SPECIALISED | DOMAIN_OWNED | Community | YES | HIGH | BURST_SENSITIVE |
| CAP-025 | Scarce event capacity and ticketing | LATER_SPECIALISED | CROSS_DOMAIN | Events & Live | YES | HIGH | BURST_SENSITIVE |
| CAP-026 | Governed experimentation and learning | LATER_SPECIALISED | CROSS_DOMAIN | Experimentation | YES | HIGH | BURST_SENSITIVE |
| CAP-027 | Analytics and measurement | FOUNDATIONAL | CROSS_DOMAIN | Analytics | YES | HIGH | HIGH |
| CAP-028 | Audit and security evidence | FOUNDATIONAL | DOMAIN_OWNED | Audit & Evidence | YES | HIGH | HIGH |
| CAP-029 | Operator work and support | FOUNDATIONAL | PLATFORM_CONTROL | No single Domain; source owners retain truth | YES | HIGH | MODERATE |
| CAP-030 | Release, incident and recovery control | FOUNDATIONAL | PLATFORM_CONTROL | No single Domain; Architecture/Operations governs control and Audit & Evidence retains central evidence | YES | HIGH | BURST_SENSITIVE |
| CAP-031 | Controlled product-space and market activation | LATER_SPECIALISED | PLATFORM_CONTROL | No single Domain; Product/Architecture direction and affected owners govern | CONDITIONAL | HIGH | HIGH |
| CAP-032 | Research & Feedback | LATER_SPECIALISED | DOMAIN_OWNED | Research & Feedback | YES | HIGH | MODERATE |
| CAP-033 | Voting & Balloting | LATER_SPECIALISED | DOMAIN_OWNED | Voting & Balloting | YES | HIGH | BURST_SENSITIVE |

Interactive Tools / calculators / decision aids are **not** allocated a CAP ID: they have no Domain, no Feature Pack and no generic activation point. Purpose-distributed delivery remains owner/outcome-specific (`calculation != authority`). Public transient tools remain non-authoritative by default.

### CAP-001 — Canonical identity and authentication

**Capability ID:** `CAP-001`

**Canonical Name:** Canonical identity and authentication

**Delivery Character:** `FOUNDATIONAL`

**Authority Scope:** `DOMAIN_OWNED` — `Identity & Access` owns the principal durable identity truth; supporting Domains do not gain ownership.

**Purpose:** Give every protected journey one reconcilable human or system identity, verified account boundary, required human-facing Platform Member Reference (PMR) as Identity & Access Account truth, and recoverable authentication context. Account creation, PMR assignment, verification, session control and recovery remain one identity capability rather than separate login, reset, verification or PMR capabilities. PMR is not authentication, authorisation, Membership, subscription or entitlement authority.

**Authoritative Domain:** `Identity & Access` owns canonical identity, credentials, sessions, trusted devices, recovery, account closure state and Platform Member Reference Account truth. PMR is not its own Domain and not its own Feature Pack.

**Supporting Domains:** `Privacy & Consent`; `Communications`; `Audit & Evidence`; all protected business Domains consume current actor context. Later Commerce/Entitlements/Events may consume minimum-disclosure PMR lookup as candidate identity only.

**Authority Anchors:** `04_DOMAIN_MAP_v1.2.0.md §6.1`; `03_ARCHITECTURE_v1.1.1.md §§6 and 6.6`; `docs/history/platform/archive/05_ROADMAP_v1.1.0.md §6 FP-001`; `docs/history/platform/archive/00_PLATFORM_v1.3.0.md §21P`; `ARC-330`; `DEC-297`. Source-at-freeze ATLAS-03 provenance also referenced `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §6.1` / `docs/history/platform/archive/03_ARCHITECTURE_v1.0.0.md §6.1` / `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-001`.

**Lifecycle Relevance:** `YES` — protected identity lifecycle including PMR assignment at successful individual Account creation; `Identity & Access`; earliest full specification point is `FP-001`. Exact PMR encoding remains unfrozen.

**Security / Privacy / Safety Significance:** `HIGH` — credentials, recovery, session authority and private-by-default PMR control every protected operation and must not expose health or privileged data. Possession of a PMR never proves Account control, authentication, authorisation, verification, Membership, subscription or entitlement.

**Performance / Concurrency Significance:** `BURST_SENSITIVE` — registration, login, verification and recovery can create authentication and abuse-control bursts.

**External Dependency Relevance:** Approved email delivery category through `Communications`; authentication implementation remains `JIT / GATED`.

**Approved Future Reuse / Extension Context:** Reused by every protected participant, operator, practitioner and future product-space journey without creating parallel identities or a separate PMR Feature Pack.

**JIT Boundary:** Credential and session Resource/action contracts, recovery assurance, field policies, abuse-control implementation and exact PMR encoding/prefix/alphabet/grouping/length/checksum/generator/schema (`ARQ-IAM-013`) remain downstream. FP-001 PMR reconciliation is COMPLETE / CERTIFIED. Identity dossier v0.1.4 and Communications JIT Domain Dossier v0.1.0 are COMPLETE / CERTIFIED / CURRENT. At the Open Work v1.2.75 status point, Audit & Evidence dossier v0.1.0 was REQUIRED / COMPLETE / CERTIFIED / CURRENT under the separate current-status promotion. PR #118 candidate certification and post-merge evidence are COMPLETE. Phase 7B reconciliation is COMPLETE / CERTIFIED / CURRENT under completed tracker #120 (CLOSED / COMPLETED). The exact candidate remains in the immutable archive. Phase 7C and Final Feature Pack Contract v0.1.0 are COMPLETE / CERTIFIED / CURRENT. Issue #124 is CLOSED / COMPLETED after PR #126 resulting-main verification. Architectural Proof Classification is COMPLETE / FINALISED as NEW_TRACER_BULLET. TB-001 contract/design review is COMPLETE / PASS; the v0.1.2 contract is CURRENT / APPROVED FOR BOUNDED PHASE 8 PROOF EXECUTION. Proof design remains frozen to the accepted Q1–Q90 decisions, while the current TB-001 result is INCOMPLETE / COVERAGE-INCOMPLETE and proof certification is NOT CERTIFIED. Development Entry Hard Stop is PASS / ALL 10 CONDITIONS SATISFIED. WELL-5 / P8-04 is COMPLETE; Phase 8 remains NOT CERTIFIED. P8-05 / WELL-6 planning, decomposition and independent review are complete; implementation is authorised only for bounded Phase 8 proof. Phase 9 is NOT STARTED / NOT AUTHORISED. This Atlas remains derived, non-authoritative navigation and DOES NOT AUTHORISE IMPLEMENTATION.

### CAP-002 — Scoped authorisation and relationship access

**Capability ID:** `CAP-002`

**Canonical Name:** Scoped authorisation and relationship access

**Delivery Character:** `FOUNDATIONAL`

**Authority Scope:** `CROSS_DOMAIN` — coordinates identity grants and relationship-owned truth; each source Domain retains its authority and no shared writes are introduced.

**Purpose:** Resolve whether an actor may perform a particular operation or read a particular field using role, relationship, purpose, scope, expiry and current authority. It keeps a practitioner role, purchaser identity, participant relationship and operator privilege distinct.

**Authoritative Domain:** `Identity & Access` owns identity-side role and privilege grants. Each business Domain owns its own relationship or assignment truth; this capability has no shared business-truth owner.

**Supporting Domains:** `Privacy & Consent`; `Professional Care`; `Commerce`; `Entitlements`; `Programmes & Challenges`; `Community`; `Events & Live`; `Audit & Evidence`.

**Authority Anchors:** `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §§3–5, 6.1 and 4.1`; `docs/history/platform/archive/03_ARCHITECTURE_v1.0.0.md §6.2`; `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §1.1`.

**Lifecycle Relevance:** `YES` — scoped-access lifecycle; `Identity & Access` governs identity-side grants and relationship-owning Domains govern their relationship truth; earliest full specification point is `FP-001`.

**Security / Privacy / Safety Significance:** `HIGH` — current scope and purpose checks prevent role leakage, payer access to recipient data and unauthorised professional or health access.

**Performance / Concurrency Significance:** `HIGH` — protected actions need current, bounded authorisation decisions and safe revocation behaviour under concurrent requests.

**External Dependency Relevance:** `NONE` as a business authority; external providers receive only bounded capability/data through owning Domains.

**Approved Future Reuse / Extension Context:** Reused wherever a product, operator, practitioner, cohort, community or event relationship grants scoped access.

**JIT Boundary:** Exact policy composition, field projections, relationship Resources and revocation propagation remain JIT.

### CAP-003 — Consent and purpose control

**Capability ID:** `CAP-003`

**Canonical Name:** Consent and purpose control

**Delivery Character:** `FOUNDATIONAL`

**Authority Scope:** `DOMAIN_OWNED` — `Privacy & Consent` owns the principal durable consent truth; supporting Domains do not gain ownership.

**Purpose:** Record and evaluate purpose-specific consent and lawful-basis permissions so participant, marketing, professional, analytics and other processing decisions use current permission rather than a blanket account flag.

**Authoritative Domain:** `Privacy & Consent` owns consent grants, withdrawals, current consent state and purpose boundaries.

**Supporting Domains:** `Identity & Access`; `Health Records`; `Safety & Eligibility`; `Professional Care`; `Communications`; `Analytics`; `Audit & Evidence`.

**Authority Anchors:** `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §6.2 and §4`; `docs/history/platform/archive/03_ARCHITECTURE_v1.0.0.md §6.3`; `docs/history/platform/archive/00_PLATFORM_v1.2.1.md §§21C.19 and 21I.13`; `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-001`.

**Lifecycle Relevance:** `YES` — consent lifecycle; `Privacy & Consent`; earliest full specification point is `FP-001`.

**Security / Privacy / Safety Significance:** `HIGH` — processing purpose, participant control and professional sharing depend on current consent and lawful-basis checks.

**Performance / Concurrency Significance:** `HIGH` — current consent must be checked reliably while withdrawal and access decisions race with delivery or processing requests.

**External Dependency Relevance:** `NONE`; legal, clinical and channel policy remains `JIT / GATED` where current authority has not frozen it.

**Approved Future Reuse / Extension Context:** Reused by health, professional, communications, analytics, community, media and future market activation without copying consent authority.

**JIT Boundary:** Consent record semantics, wording, purpose catalogue, revocation propagation and legal-basis evidence remain downstream where not frozen.

### CAP-004 — Data rights, retention and deletion orchestration

**Capability ID:** `CAP-004`

**Canonical Name:** Data rights, retention and deletion orchestration

**Delivery Character:** `FOUNDATIONAL`

**Authority Scope:** `CROSS_DOMAIN` — coordinates rights requests across Domain-owned records; each data-owning Domain retains its authority and no shared writes are introduced.

**Purpose:** Coordinate account closure, deletion, suppression, retention, legal holds and participant export across the Domains that own the underlying records. It verifies completion without becoming a shared-write replacement for those owners.

**Authoritative Domain:** `Privacy & Consent` owns the request, policy and orchestration truth. Each data-owning Domain owns its record-level deletion, correction or export contract.

**Supporting Domains:** `Identity & Access`; `Temperament`; `Health Records`; `Plans & Nutrition`; `Commerce`; `Entitlements`; `Professional Care`; `Analytics`; `Audit & Evidence`.

**Authority Anchors:** `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §6.2, §4 and §5`; `docs/history/platform/archive/03_ARCHITECTURE_v1.0.0.md §11`; `docs/history/platform/archive/00_PLATFORM_v1.2.1.md §21I`; `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-006`.

**Lifecycle Relevance:** `YES` — data-rights request lifecycle; `Privacy & Consent` coordinates and data-owning Domains fulfil their contracts; earliest full specification point is `FP-006`.

**Security / Privacy / Safety Significance:** `HIGH` — deletion must not resurrect access or sensitive records, and exports must expose only authorised data.

**Performance / Concurrency Significance:** `HIGH` — large histories, exports, restore replay and cross-Domain completion checks can create long-running or bursty work.

**External Dependency Relevance:** `JIT / GATED` — any external processor deletion/export path remains subject to approved policy and provider scope.

**Approved Future Reuse / Extension Context:** Reused by every sensitive release tier, professional record, journal, community, analytics and future market path.

**JIT Boundary:** Retention categories, legal holds, deletion/export action contracts, restore suppression and processor inventories remain downstream.

### CAP-005 — Public discovery and acquisition

**Capability ID:** `CAP-005`

**Canonical Name:** Public discovery and acquisition

**Delivery Character:** `FOUNDATIONAL`

**Authority Scope:** `CROSS_DOMAIN` — composes public content, commercial, contact and measurement truths; each source Domain retains its authority and no shared writes are introduced.

**Purpose:** Let a public visitor find useful bilingual content, understand the approved product or event, choose a relevant next step and form a permissioned mailing-list, account or purchase relationship without exposing unfinished product spaces. This is retained as a reusable cross-cutting acquisition boundary because the public-to-protected handoff recurs across approved content, product, event and future-market outcomes while the underlying authorities remain separate.

**Authoritative Domain:** No single Domain owns this composite capability. `Content & Media` owns public content, `Commerce` owns product information, `Communications` owns subscriber contact state and `Analytics` owns acquisition evidence. None becomes a shared public-funnel authority.

**Supporting Domains:** `Content & Media`; `Commerce`; `Communications`; `Analytics`; `Privacy & Consent`; `Identity & Access`.

**Authority Anchors:** `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §§2, 6 FP-001 and 13`; `docs/history/platform/archive/PLATFORM_OPERATING_MODEL_v1.0.1.md §15`; `FRONTEND_EXPERIENCE_SYSTEM_v1.0.1.md §§3.1 and 5.1`; `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §7`.

**Lifecycle Relevance:** `CONDITIONAL` — subscriber-contact lifecycle only where this acquisition boundary includes a governed mailing-list relationship; `Communications`; earliest full specification point is `FP-001`.

**Security / Privacy / Safety Significance:** `MODERATE` — public discovery stays open, but consent, account boundaries, protected product visibility and health-safe messaging still apply.

**Performance / Concurrency Significance:** `MODERATE` — public reads and campaign traffic may be broad or bursty, while source authority and protected paths must remain isolated.

**External Dependency Relevance:** `JIT / GATED` — email, referral and external analytics providers remain bounded supporting systems, not acquisition authority.

**Approved Future Reuse / Extension Context:** Reused by approved content, programme, event and future product-space discovery while preserving separate contact, account, purchaser and participant concepts.

**JIT Boundary:** Exact acquisition surfaces, copy, attribution contract and provider configuration remain downstream.

### CAP-006 — Governed content, translation and publication

**Capability ID:** `CAP-006`

**Canonical Name:** Governed content, translation and publication

**Delivery Character:** `FOUNDATIONAL`

**Authority Scope:** `DOMAIN_OWNED` — `Content & Media` owns the principal durable content truth; supporting Domains do not gain ownership.

**Purpose:** Produce, review, translate, approve, publish, correct and withdraw versioned content that can safely support public discovery, assessments, reports, plans, programmes, communications and events.

**Authoritative Domain:** `Content & Media` owns conceptual content identity, immutable content versions, translation relationships, publication state, editorial media metadata and correction/withdrawal authority.

**Supporting Domains:** `Privacy & Consent`; `Health Records`; `Safety & Eligibility`; `Plans & Nutrition`; `Programmes & Challenges`; `Communications`; `Events & Live`; `Audit & Evidence`.

**Authority Anchors:** `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §6.7`; `docs/history/platform/archive/00_PLATFORM_v1.2.1.md §§21E.1–21E.10`; `docs/history/platform/archive/PLATFORM_OPERATING_MODEL_v1.0.1.md §§9–13`; `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §§2 and 6 FP-005`.

**Lifecycle Relevance:** `YES` — governed-content lifecycle; `Content & Media`; earliest full specification point is `FP-001`.

**Security / Privacy / Safety Significance:** `HIGH` — approved bilingual, paid, clinical, safety and consent content must not be delivered after withdrawal or without its required review.

**Performance / Concurrency Significance:** `HIGH` — scheduled publication, corrections, withdrawals and downstream delivery can fan out across many surfaces.

**External Dependency Relevance:** `NONE` for content authority; external media delivery and notification providers remain behind their own capabilities.

**Approved Future Reuse / Extension Context:** Reused by all product, programme, plan, community, event and future market content without parallel editorial authority.

**JIT Boundary:** Content and translation Resources, approval actions, scheduling, invalidation and publication implementation remain downstream.

### CAP-007 — Explainable content discovery and relevance

**Capability ID:** `CAP-007`

**Canonical Name:** Explainable content discovery and relevance

**Delivery Character:** `SHARED_REUSE`

**Authority Scope:** `CROSS_DOMAIN` — projects content and permitted signals from multiple Domains; each source Domain retains its authority and no shared writes are introduced.

**Purpose:** Help people discover approved content through deterministic search, taxonomy, freshness, entitlement and permitted relevance signals while showing why content is prioritised and preserving broader browsing.

**Authoritative Domain:** `Content & Media` owns the content and taxonomy source. The relevance projection has no independent business truth; `Temperament`, `Health Records`, `Safety & Eligibility`, `Plans & Nutrition`, `Entitlements`, `Experimentation` and `Analytics` retain their own signals and decisions.

**Supporting Domains:** `Temperament`; `Health Records`; `Safety & Eligibility`; `Plans & Nutrition`; `Entitlements`; `Experimentation`; `Analytics`; `Privacy & Consent`.

**Authority Anchors:** `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §§6.7 and 9`; `docs/history/platform/archive/00_PLATFORM_v1.2.1.md §§21E.5–21E.7 and 21E.12`; `docs/history/platform/archive/03_ARCHITECTURE_v1.0.0.md §§10.2 and 10.5`; `FRONTEND_EXPERIENCE_SYSTEM_v1.0.1.md §§5.1 and 12`.

**Lifecycle Relevance:** `NO` — no independent lifecycle is asserted; source content and relevance-signal lifecycles remain with their owning Domains.

**Security / Privacy / Safety Significance:** `HIGH` — health-derived relevance must be minimised and explainable, and safety-required content cannot be hidden by ordinary ranking.

**Performance / Concurrency Significance:** `HIGH` — public search, feed reads, large taxonomies and concurrent discovery traffic need bounded reads and safe degradation.

**External Dependency Relevance:** `JIT / GATED` — search and relevance implementation remains first-party and evidence-gated; semantic or external ranking is not assumed.

**Approved Future Reuse / Extension Context:** Reused by public content, participant discovery, programmes, events and approved future product spaces.

**JIT Boundary:** Ranking signals, query/resource design, projection freshness, caching and experiment integration remain JIT.

### CAP-008 — Protected media and content delivery

**Capability ID:** `CAP-008`

**Canonical Name:** Protected media and content delivery

**Delivery Character:** `SHARED_REUSE`

**Authority Scope:** `CROSS_DOMAIN` — coordinates media truth with access, consent and rights truths; each source Domain retains its authority and no shared writes are introduced.

**Purpose:** Deliver public, purchased, member-only, practitioner-shared and replay media under current access, consent, rights and withdrawal policy. Media delivery is a capability, not a second content or entitlement authority.

**Authoritative Domain:** `Content & Media` owns media identity, rights, derivatives, publication metadata and protected-delivery classification. `Entitlements` and source Domains own access and sharing truth.

**Supporting Domains:** `Entitlements`; `Privacy & Consent`; `Events & Live`; `Commerce`; `Professional Care`; `Audit & Evidence`.

**Authority Anchors:** `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §6.7`; `docs/history/platform/archive/03_ARCHITECTURE_v1.0.0.md §§7.4 and 10.3`; `docs/history/platform/archive/00_PLATFORM_v1.2.1.md §21E.15`; `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §§6 FP-003 and FP-007`.

**Lifecycle Relevance:** `YES` — protected-media lifecycle; `Content & Media`; earliest full specification point is `FP-003`.

**Security / Privacy / Safety Significance:** `HIGH` — protected reports, plans, recordings and practitioner-shared assets must respect current scope, consent, entitlement and withdrawal.

**Performance / Concurrency Significance:** `HIGH` — media and replay delivery can fan out heavily, while access checks and withdrawal must remain current.

**External Dependency Relevance:** Approved object-storage/CDN/media-delivery categories; live-video provider details belong to `CAP-021` and remain `JIT / GATED`.

**Approved Future Reuse / Extension Context:** Reused by reports, plan libraries, programme media, live replay, events, community assets and future product spaces.

**JIT Boundary:** Media Resource/derivative model, signed delivery mechanism, provider adapter, rights evidence and retention remain downstream.

### CAP-009 — Commercial catalogue and offer management

**Capability ID:** `CAP-009`

**Canonical Name:** Commercial catalogue and offer management

**Delivery Character:** `FOUNDATIONAL`

**Authority Scope:** `DOMAIN_OWNED` — `Commerce` owns the principal durable catalogue and offer truth; supporting Domains do not gain ownership.

**Purpose:** Define which approved products, bundles, memberships, add-ons, gifts or events may be offered with versioned prices, discounts and commercial boundaries. Catalogue truth remains separate from payment and access truth.

**Authoritative Domain:** `Commerce` owns commercial products, offers, price versions, discounts and purchaser/recipient commercial relationships.

**Supporting Domains:** `Entitlements`; `Identity & Access`; `Content & Media`; `Events & Live`; `Privacy & Consent`; `Analytics`.

**Authority Anchors:** `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §6.10`; `docs/history/platform/archive/00_PLATFORM_v1.2.1.md §§21A.1, 21A.5, 21A.9 and 21A.13`; `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §§3.2 and 6 FP-002`.

**Lifecycle Relevance:** `YES` — commercial-offer lifecycle; `Commerce`; earliest full specification point is `FP-002`.

**Security / Privacy / Safety Significance:** `MODERATE` — catalogue visibility must not expose unfinished products, misrepresent approved health scope or let an offer bypass consent and access rules.

**Performance / Concurrency Significance:** `MODERATE` — current catalogue and price reads may be broad, but price/version authority must remain consistent under checkout load.

**External Dependency Relevance:** `NONE` as commercial authority; provider payment evidence enters through `CAP-010`.

**Approved Future Reuse / Extension Context:** Reused by once-off products, memberships, Premium, gifts, event commerce and approved future market offers.

**JIT Boundary:** Catalogue Resources, price-version actions, discount rules, purchaser/recipient handling and approval workflow remain downstream.

### CAP-010 — Payment and commercial reconciliation

**Capability ID:** `CAP-010`

**Canonical Name:** Payment and commercial reconciliation

**Delivery Character:** `FOUNDATIONAL`

**Authority Scope:** `DOMAIN_OWNED` — `Commerce` owns the principal durable payment and reconciliation truth; supporting Domains do not gain ownership.

**Purpose:** Turn a purchase intent and provider evidence into one authoritative payment, refund or dispute outcome without granting access from an unverified browser return or duplicating effects under retries and ambiguity.

**Authoritative Domain:** `Commerce` owns purchase, payment, refund, dispute, settlement and provider-independent reconciliation truth.

**Supporting Domains:** `Identity & Access`; `Privacy & Consent`; `Entitlements`; `Events & Live`; `Audit & Evidence`; `Analytics`.

**Authority Anchors:** `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §6.10`; `docs/history/platform/archive/03_ARCHITECTURE_v1.0.0.md §§8.1–8.3`; `docs/history/platform/archive/00_PLATFORM_v1.2.1.md §§21A.6, 21A.8, 21A.10 and 21A.12`; `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-002`.

**Lifecycle Relevance:** `YES` — payment-reconciliation lifecycle; `Commerce`; earliest full specification point is `FP-002`.

**Security / Privacy / Safety Significance:** `HIGH` — financial integrity, provider minimisation and purchaser/recipient separation protect both money and private participant data.

**Performance / Concurrency Significance:** `BURST_SENSITIVE` — checkout contention, provider callback bursts, retries and reconciliation backlog can arrive together.

**External Dependency Relevance:** `Paystack` launch gateway; future providers remain behind approved adapters and `JIT / GATED` behaviour.

**Approved Future Reuse / Extension Context:** Reused by once-off plans, memberships, Premium, practitioner review and scarce-capacity event commerce without parallel payment truth.

**JIT Boundary:** Provider adapter, retry/idempotency, ambiguity, refund/dispute reconciliation and commercial action contracts remain downstream.

### CAP-011 — Entitlement and access-rights management

**Capability ID:** `CAP-011`

**Canonical Name:** Entitlement and access-rights management

**Delivery Character:** `FOUNDATIONAL`

**Authority Scope:** `DOMAIN_OWNED` — `Entitlements` owns the principal durable access-rights truth; supporting Domains do not gain ownership.

**Purpose:** Grant, redeem, consume, expire and revoke durable rights to reports, plans, programmes, memberships, add-ons, community, sessions or events while keeping access truth separate from payment and protected content.

**Authoritative Domain:** `Entitlements` owns entitlement identity, scope, source, validity, expiry, revocation, redemption and consumption history.

**Supporting Domains:** `Commerce`; `Identity & Access`; `Privacy & Consent`; `Temperament`; `Plans & Nutrition`; `Programmes & Challenges`; `Community`; `Events & Live`; `Audit & Evidence`.

**Authority Anchors:** `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §6.11`; `docs/history/platform/archive/00_PLATFORM_v1.2.1.md §§21A.5, 21A.9 and 21A.13`; `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §§3.2 and 6 FP-002`.

**Lifecycle Relevance:** `YES` — entitlement lifecycle; `Entitlements`; earliest full specification point is `FP-002`.

**Security / Privacy / Safety Significance:** `HIGH` — current access checks must prevent stale grants, duplicate access and payer access to recipient health or plan data.

**Performance / Concurrency Significance:** `HIGH` — protected journeys create frequent current-access reads and grant/redeem/revoke races.

**External Dependency Relevance:** `NONE` as authority; payment and provider evidence arrive through `Commerce`.

**Approved Future Reuse / Extension Context:** Reused by assessment credits, paid plans, memberships, programme access, community, live replay, event tickets and future product spaces.

**JIT Boundary:** Entitlement identity, grant/revoke actions, consumption rules, access projection and invalidation remain downstream.

### CAP-012 — Temperament assessment and profile

**Capability ID:** `CAP-012`

**Canonical Name:** Temperament assessment and profile

**Delivery Character:** `FOUNDATIONAL`

**Authority Scope:** `DOMAIN_OWNED` — `Temperament` owns the principal durable assessment and profile truth; supporting Domains do not gain ownership.

**Purpose:** Accept approved self-reported, book-derived or digital temperament inputs, score and interpret them reproducibly, preserve provenance and provide an immutable bilingual report and current profile for approved product use.

**Authoritative Domain:** `Temperament` owns methodology versions, assessment configuration, attempts, answers, raw scores, reviewed interpretation, current profile and report provenance.

**Supporting Domains:** `Content & Media`; `Entitlements`; `Privacy & Consent`; `Plans & Nutrition`; `Programmes & Challenges`; `Analytics`; `Audit & Evidence`.

**Authority Anchors:** `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §6.3`; `docs/history/platform/archive/00_PLATFORM_v1.2.1.md §§21B.1–21B.15`; `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-003`.

**Lifecycle Relevance:** `YES` — temperament-assessment lifecycle; `Temperament`; earliest full specification point is `FP-003`.

**Security / Privacy / Safety Significance:** `HIGH` — answers and results are personal, immutable under policy and must never be treated as medical authority.

**Performance / Concurrency Significance:** `MODERATE` — assessment completion bursts and report reads need bounded scoring and history access.

**External Dependency Relevance:** `NONE`; methodology, content, rights and translation approvals are authority gates rather than provider dependencies.

**Approved Future Reuse / Extension Context:** Reused by safe plans, programmes, content relevance, professional review and approved future product families.

**JIT Boundary:** Assessment Resources/actions, scoring implementation, provenance fields and report rendering remain downstream.

### CAP-013 — Health and lifestyle records

**Capability ID:** `CAP-013`

**Canonical Name:** Health and lifestyle records

**Delivery Character:** `FOUNDATIONAL`

**Authority Scope:** `DOMAIN_OWNED` — `Health Records` owns the principal durable health and lifestyle truth; supporting Domains do not gain ownership.

**Purpose:** Collect, correct and expose only the progressive health, lifestyle, measurement and laboratory facts needed for an approved purpose, with provenance and current minimum-data views.

**Authoritative Domain:** `Health Records` owns participant health/lifestyle intake facts, provenance, verification status, measurements, laboratory records and record corrections.

**Supporting Domains:** `Privacy & Consent`; `Safety & Eligibility`; `Plans & Nutrition`; `Professional Care`; `Analytics`; `Audit & Evidence`.

**Authority Anchors:** `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §6.4`; `docs/history/platform/archive/00_PLATFORM_v1.2.1.md §§21C.1–21C.4 and 21C.13–21C.14`; `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-004`.

**Lifecycle Relevance:** `YES` — health-record lifecycle; `Health Records`; earliest full specification point is `FP-004`.

**Security / Privacy / Safety Significance:** `HIGH` — health information is purpose-bound, minimum-access and safety-sensitive; unverified facts cannot silently become treatment authority.

**Performance / Concurrency Significance:** `MODERATE` — onboarding and correction traffic is bounded, but historical access and current minimum-data reads must remain controlled.

**External Dependency Relevance:** `JIT / GATED` for laboratory or measurement inputs; no external source is assumed for the initial intake path.

**Approved Future Reuse / Extension Context:** Reused by eligibility, plans, professional review and approved future health or market paths without copying a health record into derived systems.

**JIT Boundary:** Health Resources, provenance and correction semantics, access projections and laboratory integration remain downstream.

### CAP-014 — Safety and eligibility routing

**Capability ID:** `CAP-014`

**Canonical Name:** Safety and eligibility routing

**Delivery Character:** `FOUNDATIONAL`

**Authority Scope:** `DOMAIN_OWNED` — `Safety & Eligibility` owns the principal durable evaluation and restriction truth; supporting Domains do not gain ownership.

**Purpose:** Apply approved safety and eligibility rules to current scoped facts and route a participant to automated guidance, General Wellness, professional review or insufficient-information handling without turning temperament or stale data into clinical authority.

**Authoritative Domain:** `Safety & Eligibility` owns evaluations, outcomes, restrictions, safety cases, pauses, overrides and re-evaluation authority.

**Supporting Domains:** `Health Records`; `Plans & Nutrition`; `Professional Care`; `Temperament`; `Privacy & Consent`; `Content & Media`; `Audit & Evidence`.

**Authority Anchors:** `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §6.5`; `docs/history/platform/archive/00_PLATFORM_v1.2.1.md §§21C.5–21C.20`; `docs/history/platform/archive/03_ARCHITECTURE_v1.0.0.md §§5, 6 and 14`; `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-004`.

**Lifecycle Relevance:** `YES` — safety-evaluation lifecycle; `Safety & Eligibility`; earliest full specification point is `FP-004`.

**Security / Privacy / Safety Significance:** `SAFETY_CRITICAL` — high-risk or incomplete cases must fail closed, urgent guidance must be correct and safety can override personalisation.

**Performance / Concurrency Significance:** `HIGH` — current safety decisions and re-evaluations must remain bounded and correct under onboarding or material-change bursts.

**External Dependency Relevance:** `JIT / GATED` — clinical matrices, urgent wording, retention and any laboratory rules require the approved authority before affected release.

**Approved Future Reuse / Extension Context:** Reused by plans, programmes, adjusted plans, practitioner review and future approved health outcomes.

**JIT Boundary:** Clinical rule matrix, safety wording, override actions, case resources and re-evaluation mechanics remain downstream.

### CAP-015 — Deterministic plan generation and versioning

**Capability ID:** `CAP-015`

**Canonical Name:** Deterministic plan generation and versioning

**Delivery Character:** `FOUNDATIONAL`

**Authority Scope:** `DOMAIN_OWNED` — `Plans & Nutrition` owns the principal durable plan truth; supporting Domains do not gain ownership.

**Purpose:** Generate an explainable, bilingual plan or approved General Wellness pathway from current approved inputs, calculations, content and safety authority, then preserve the delivered version and its provenance.

**Authoritative Domain:** `Plans & Nutrition` owns plan generation requests and outcomes, immutable delivered snapshots, explanations, activation, correction and withdrawal.

**Supporting Domains:** `Safety & Eligibility`; `Health Records`; `Temperament`; `Content & Media`; `Entitlements`; `Habits, Journals & Progress`; `Privacy & Consent`; `Audit & Evidence`.

**Authority Anchors:** `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §6.6`; `docs/history/platform/archive/00_PLATFORM_v1.2.1.md §§21D.1–21D.8 and 21D.12–21D.13`; `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-005`.

**Lifecycle Relevance:** `YES` — plan-version lifecycle; `Plans & Nutrition`; earliest full specification point is `FP-005`.

**Security / Privacy / Safety Significance:** `SAFETY_CRITICAL` — plan output must use current safety authority, approved calculation/content rules and explainable personalisation without making unsupported clinical claims.

**Performance / Concurrency Significance:** `MODERATE` — generation must stay bounded during completion bursts and preserve immutable history without loading unnecessary records.

**External Dependency Relevance:** `NONE` as authority; approved content, calculation and translation inputs are governed internal dependencies.

**Approved Future Reuse / Extension Context:** Reused by once-off plans, programmes, recurring adjustment, practitioner-derived plans and approved future product spaces.

**JIT Boundary:** Calculation implementation, generation orchestration, content linkage, plan Resources/actions and delivery mechanics remain downstream.

### CAP-016 — Governed plan review and adjustment

**Capability ID:** `CAP-016`

**Canonical Name:** Governed plan review and adjustment

**Delivery Character:** `LATER_SPECIALISED`

**Authority Scope:** `DOMAIN_OWNED` — `Plans & Nutrition` owns the principal durable plan-adjustment truth; supporting Domains do not gain ownership.

**Purpose:** Review approved check-ins and trends at the permitted cadence, apply renewed safety evaluation and create a governed immutable plan adjustment only where the approved rules allow it.

**Authoritative Domain:** `Plans & Nutrition` owns review and adjustment outcomes. `Safety & Eligibility` remains the authority for current safety clearance, and `Habits, Journals & Progress` owns input facts.

**Supporting Domains:** `Habits, Journals & Progress`; `Safety & Eligibility`; `Health Records`; `Temperament`; `Entitlements`; `Commerce`; `Privacy & Consent`; `Audit & Evidence`.

**Authority Anchors:** `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §§6.6 and 5`; `docs/history/platform/archive/00_PLATFORM_v1.2.1.md §§21D.9–21D.11`; `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-010`.

**Lifecycle Relevance:** `YES` — governed-plan-adjustment lifecycle; `Plans & Nutrition`; earliest full specification point is `FP-010`.

**Security / Privacy / Safety Significance:** `SAFETY_CRITICAL` — a trend or practitioner input cannot bypass current eligibility, approved thresholds or plan authority.

**Performance / Concurrency Significance:** `MODERATE` — periodic reviews and bounded trend reads may batch, but adjustments must remain idempotent and current.

**External Dependency Relevance:** `JIT / GATED` for approved clinical/product review rules; recurring billing uses `CAP-010` only when the commercial scope includes it.

**Approved Future Reuse / Extension Context:** Reused by adjustment add-ons and Premium packaging after once-off plan delivery is proven.

**JIT Boundary:** Review windows, thresholds, trend calculations, adjustment actions and safety re-evaluation mechanics remain downstream.

### CAP-017 — Communications and notification delivery

**Capability ID:** `CAP-017`

**Canonical Name:** Communications and notification delivery

**Delivery Character:** `FOUNDATIONAL`

**Authority Scope:** `DOMAIN_OWNED` — `Communications` owns the principal durable communication and delivery truth; supporting Domains do not gain ownership.

**Purpose:** Create, select, deliver, retry and evidence communication intent across mailing-list, email and in-app channels while respecting consent, preferences, quiet hours, caps and the originating Domain's business truth.

**Authoritative Domain:** `Communications` owns subscriber contact state, notification preferences, message intent, delivery attempts and provider evidence. It does not own templates, consent or originating business facts.

**Supporting Domains:** `Content & Media`; `Privacy & Consent`; `Identity & Access`; `Commerce`; `Programmes & Challenges`; `Events & Live`; `Analytics`; `Audit & Evidence`.

**Authority Anchors:** `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §6.15`; `docs/history/platform/archive/03_ARCHITECTURE_v1.0.0.md §10.4`; `docs/history/platform/archive/PLATFORM_OPERATING_MODEL_v1.0.1.md §§7, 12 and 21`; `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §§6 FP-001 and FP-007`.

**Lifecycle Relevance:** `YES` — communication-delivery lifecycle; `Communications`; earliest full specification point is `FP-001`.

**Security / Privacy / Safety Significance:** `HIGH` — messages can carry sensitive context, and consent/preferences must be rechecked without weakening mandatory safety or account notices.

**Performance / Concurrency Significance:** `BURST_SENSITIVE` — programme, event and campaign fan-out can collide with provider rate limits, retries and backlog recovery.

**External Dependency Relevance:** Email provider initially; future SMS/WhatsApp channels remain approved-category and `JIT / GATED`.

**Approved Future Reuse / Extension Context:** Reused by identity, payment, programmes, membership, live, events, community, professional review and future product spaces.

**JIT Boundary:** Message Resources, provider adapters, retry/quiet-hour scheduling, channel policy and in-app presentation remain downstream.

### CAP-018 — Programme and cohort delivery

**Capability ID:** `CAP-018`

**Canonical Name:** Programme and cohort delivery

**Delivery Character:** `LATER_SPECIALISED`

**Authority Scope:** `DOMAIN_OWNED` — `Programmes & Challenges` owns the principal durable programme and cohort truth; supporting Domains do not gain ownership.

**Purpose:** Define approved programmes and challenges, configure editions and cohorts, enrol participants, release scheduled material, measure participation and completion, and support catch-up or recovery without creating a generic LMS.

**Authoritative Domain:** `Programmes & Challenges` owns programme/challenge definitions, versions, editions, cohorts, enrolment, participation and completion truth.

**Supporting Domains:** `Content & Media`; `Entitlements`; `Habits, Journals & Progress`; `Temperament`; `Safety & Eligibility`; `Plans & Nutrition`; `Community`; `Events & Live`; `Communications`; `Privacy & Consent`; `Audit & Evidence`.

**Authority Anchors:** `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §6.8`; `docs/history/platform/archive/00_PLATFORM_v1.2.1.md §§21F.1–21F.10 and 21H.2–21H.5`; `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-008`.

**Lifecycle Relevance:** `YES` — programme-delivery lifecycle; `Programmes & Challenges`; earliest full specification point is `FP-008`.

**Security / Privacy / Safety Significance:** `HIGH` — cohort access, participant/purchaser separation, safety routing, private progress and facilitator/moderator scope must remain controlled.

**Performance / Concurrency Significance:** `BURST_SENSITIVE` — scheduled release, cohort fan-out, progress writes and communication catch-up can create concentrated load.

**External Dependency Relevance:** `NONE` as programme authority; live, communications and media providers are separate gated capabilities.

**Approved Future Reuse / Extension Context:** Nuwe Jy is the concrete acceptance path; later foundation programmes and governed challenges may extend the vocabulary after evidence.

**JIT Boundary:** Programme Resources, edition/cohort contracts, schedule/recovery semantics, completion rules and delivery implementation remain downstream.

### CAP-019 — Participant progress and feedback

**Capability ID:** `CAP-019`

**Canonical Name:** Participant progress and feedback

**Delivery Character:** `SHARED_REUSE`

**Authority Scope:** `DOMAIN_OWNED` — `Habits, Journals & Progress` owns the principal durable progress and feedback truth; supporting Domains do not gain ownership.

**Purpose:** Record lightweight daily or weekly progress, adherence and feedback so participants can see useful continuity and approved product teams can learn without turning basic feedback into clinical or journal authority. This capability is **not** Domain 19 Research & Feedback. FP-005 “basic feedback” remains Habits/progress self-tracking under this CAP and does not activate Research campaigns, instruments or Research responses.

**Authoritative Domain:** `Habits, Journals & Progress` owns participant progress, adherence and feedback entries within the approved lightweight scope.

**Supporting Domains:** `Plans & Nutrition`; `Programmes & Challenges`; `Safety & Eligibility`; `Analytics`; `Privacy & Consent`; `Audit & Evidence`.

**Authority Anchors:** `04_DOMAIN_MAP_v1.2.0.md §6.9 and §4`; `docs/history/platform/archive/PROJECT_NORTH_STAR_AND_MVP_v1.2.1.md §§5.3–5.4`; `docs/history/platform/archive/05_ROADMAP_v1.1.0.md §§6 FP-005 and FP-010` (including the Research classification guardrail). Source-at-freeze ATLAS-03 provenance also referenced `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md` / `docs/history/platform/archive/05_ROADMAP_v1.0.0.md`.

**Lifecycle Relevance:** `YES` — participant-progress lifecycle; `Habits, Journals & Progress`; earliest full specification point is `FP-005`.

**Security / Privacy / Safety Significance:** `MODERATE` — participant data is personal and must remain separate from clinical authority, public rankings and private journal content.

**Performance / Concurrency Significance:** `HIGH` — repeated participant writes, programme bursts and progress-history reads can become material at scale.

**External Dependency Relevance:** `NONE`; approved product analytics may consume minimum facts through `CAP-027`.

**Approved Future Reuse / Extension Context:** Reused by plans, programmes, habits, adjustment review, community recognition and long-term progress views.

**JIT Boundary:** Progress/feedback record shapes, aggregation, correction rules and participant presentation remain downstream.

### CAP-020 — Habits and private reflective practice

**Capability ID:** `CAP-020`

**Canonical Name:** Habits and private reflective practice

**Delivery Character:** `LATER_SPECIALISED`

**Authority Scope:** `DOMAIN_OWNED` — `Habits, Journals & Progress` owns the principal durable habit and reflective-practice truth; supporting Domains do not gain ownership.

**Purpose:** Support approved habit schedules, private journals, reflections, accountability and compassionate consistency without exposing private entries to community or allowing them to become clinical records by default.

**Authoritative Domain:** `Habits, Journals & Progress` owns habit definitions, schedules, occurrences, private journal/reflection state, sharing state and progress indicators.

**Supporting Domains:** `Programmes & Challenges`; `Plans & Nutrition`; `Professional Care` only for explicitly shared information; `Privacy & Consent`; `Communications`; `Analytics`; `Audit & Evidence`.

**Authority Anchors:** `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §6.9`; `docs/history/platform/archive/00_PLATFORM_v1.2.1.md §§21F.12–21F.22`; `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-014`.

**Lifecycle Relevance:** `YES` — private-reflection lifecycle; `Habits, Journals & Progress`; earliest full specification point is `FP-014`.

**Security / Privacy / Safety Significance:** `HIGH` — journals and reflections are private by default, sharing is scoped and deletion/export must cover sensitive material and attachments.

**Performance / Concurrency Significance:** `HIGH` — repeated occurrences, journal history and reminder/progress reads may create large histories and fan-out.

**External Dependency Relevance:** `NONE`; reminder delivery uses `CAP-017` when separately approved.

**Approved Future Reuse / Extension Context:** Reused by foundation programmes, Nuwe Jy, recurring review and approved community/accountability paths without making journals public.

**JIT Boundary:** Habit/journal Resources, sharing rules, reminder mechanics, attachment handling and retention remain downstream.

### CAP-021 — Live-session and replay delivery

**Capability ID:** `CAP-021`

**Canonical Name:** Live-session and replay delivery

**Delivery Character:** `SHARED_REUSE`

**Authority Scope:** `DOMAIN_OWNED` — `Events & Live` owns the principal durable session and replay truth; supporting Domains do not gain ownership.

**Purpose:** Publish governed live sessions, register entitled participants, protect playback, associate approved recordings/replays and expose provider failure without changing platform attendance or access truth.

**Authoritative Domain:** `Events & Live` owns session definitions, occurrences, registration and live/replay participation truth. `Content & Media` owns media publication; `Entitlements` owns general access rights.

**Supporting Domains:** `Entitlements`; `Identity & Access`; `Content & Media`; `Communications`; `Privacy & Consent`; `Programmes & Challenges`; `Audit & Evidence`; `Analytics`.

**Authority Anchors:** `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §6.13`; `docs/history/platform/archive/00_PLATFORM_v1.2.1.md §§21G.14–21G.16`; `docs/history/platform/archive/03_ARCHITECTURE_v1.0.0.md §10.3`; `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-007`.

**Lifecycle Relevance:** `YES` — live-session lifecycle; `Events & Live`; earliest full specification point is `FP-007`.

**Security / Privacy / Safety Significance:** `HIGH` — entitlement, recording notice, consent, playback scope and participant privacy must remain current.

**Performance / Concurrency Significance:** `BURST_SENSITIVE` — registration bursts, live connection fan-out, provider recovery and replay demand are concentrated.

**External Dependency Relevance:** Approved `Restream`/`Cloudflare Stream` provider path; operational and recording semantics remain `JIT / GATED`.

**Approved Future Reuse / Extension Context:** Reused by Nuwe Jy, Membership and approved event variants; it does not include scarce ticket commerce.

**JIT Boundary:** Provider integration, playback authorisation, recording/replay Resources, consent and recovery implementation remain downstream.

### CAP-022 — Recurring commercial access

**Capability ID:** `CAP-022`

**Canonical Name:** Recurring commercial access

**Delivery Character:** `LATER_SPECIALISED`

**Authority Scope:** `CROSS_DOMAIN` — coordinates Commerce contract truth with Entitlements access truth; each source Domain retains its authority and no shared writes are introduced.

**Purpose:** Sell and maintain a recurring membership or add-on contract whose promised value, billing state, cancellation consequence and access rights remain coherent across Commerce and Entitlements.

**Authoritative Domain:** `Commerce` owns the recurring commercial contract, billing periods and cancellation state. `Entitlements` owns the resulting access rights; there is no combined billing/access authority.

**Supporting Domains:** `Content & Media`; `Community`; `Events & Live`; `Communications`; `Plans & Nutrition`; `Privacy & Consent`; `Audit & Evidence`; `Analytics`.

**Authority Anchors:** `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §§6.10–6.11`; `docs/history/platform/archive/00_PLATFORM_v1.2.1.md §§21A.5–21A.8 and 21A.11`; `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-009`.

**Lifecycle Relevance:** `YES` — recurring-access lifecycle; `Commerce` and `Entitlements`; earliest full specification point is `FP-009`.

**Security / Privacy / Safety Significance:** `HIGH` — recurring access, cancellation and failed payment must not expose private content or create unlimited practitioner expectations.

**Performance / Concurrency Significance:** `BURST_SENSITIVE` — billing waves, failed-payment retries, access fan-out and monthly content/live value can cluster.

**External Dependency Relevance:** `Paystack` through `CAP-010`; recurring billing, proration and retry behaviour remain `JIT / GATED`.

**Approved Future Reuse / Extension Context:** Basic Membership and Premium may reuse the same recurring contract and entitlement boundary; later add-ons remain explicit.

**JIT Boundary:** Subscription contract, provider semantics, cancellation/refund consequences, entitlement consequences and recurring-value operations remain downstream.

### CAP-023 — Professional review and scoped care

**Capability ID:** `CAP-023`

**Canonical Name:** Professional review and scoped care

**Delivery Character:** `LATER_SPECIALISED`

**Authority Scope:** `DOMAIN_OWNED` — `Professional Care` owns the principal durable professional-review truth; supporting Domains do not gain ownership.

**Purpose:** Provide a limited, capacity-controlled practitioner review with explicit consent, active scoped relationship, professional outcome, follow-up or referral while preserving the separate Safety and Plans authorities.

**Authoritative Domain:** `Professional Care` owns practitioner relationship metadata, review cases, professional outcomes, platform-held record provenance, referral state and saleable capacity. `OQ-033` governs unresolved final professional-record authority.

**Supporting Domains:** `Identity & Access`; `Privacy & Consent`; `Health Records`; `Safety & Eligibility`; `Plans & Nutrition`; `Commerce`; `Entitlements`; `Communications`; `Audit & Evidence`.

**Authority Anchors:** `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §6.14`; `docs/history/platform/archive/00_PLATFORM_v1.2.1.md §§21C.17–21C.18`; `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-012`.

**Lifecycle Relevance:** `YES` — professional-review lifecycle; `Professional Care`; earliest full specification point is `FP-012`.

**Security / Privacy / Safety Significance:** `SAFETY_CRITICAL` — professional access, records and outcomes are highly sensitive and must not silently change Safety or Plan truth.

**Performance / Concurrency Significance:** `MODERATE` — scarce reviewer capacity and case queues matter more than raw throughput; histories remain bounded.

**External Dependency Relevance:** Authorised practitioners and referral partners; contracting and professional-record rules remain `JIT / GATED`.

**Approved Future Reuse / Extension Context:** Supports a limited practitioner pilot and later approved professional pathways without becoming an open marketplace.

**JIT Boundary:** Professional record authority, relationship/case Resources, capacity allocation, contracts, referral semantics and downstream Safety/Plan commands remain unresolved.

### CAP-024 — Community participation and moderation

**Capability ID:** `CAP-024`

**Canonical Name:** Community participation and moderation

**Delivery Character:** `LATER_SPECIALISED`

**Authority Scope:** `DOMAIN_OWNED` — `Community` owns the principal durable participation and moderation truth; supporting Domains do not gain ownership.

**Purpose:** Let entitled participants join governed first-party groups and challenges while supporting reporting, moderation, sanctions, appeals, privacy boundaries and deletion/anonymisation without becoming a generic social network.

**Authoritative Domain:** `Community` owns first-party groups, participation, community content, moderation cases, sanctions, appeals and community deletion/anonymisation behaviour.

**Supporting Domains:** `Programmes & Challenges`; `Entitlements`; `Identity & Access`; `Privacy & Consent`; `Content & Media`; `Communications`; `Safety & Eligibility`; `Audit & Evidence`; `Analytics`.

**Authority Anchors:** `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §6.12`; `docs/history/platform/archive/00_PLATFORM_v1.2.1.md §§21G.1–21G.13`; `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-013`.

**Lifecycle Relevance:** `YES` — community-participation lifecycle; `Community`; earliest full specification point is `FP-013`.

**Security / Privacy / Safety Significance:** `HIGH` — private health information must stay out of community spaces, abuse must be moderated and participant identity/visibility must follow policy.

**Performance / Concurrency Significance:** `BURST_SENSITIVE` — feed, discussion, moderation and challenge activity can create read, write and fan-out bursts.

**External Dependency Relevance:** `NONE` for first-party authority; governed external community channels are evidence inputs, not a substitute for this capability.

**Approved Future Reuse / Extension Context:** Extends Nuwe Jy, Membership and governed challenge evidence into a first-party participation path.

**JIT Boundary:** Community Resources, moderation workflow, sanctions/appeals, privacy controls and deletion/anonymisation implementation remain downstream.

### CAP-025 — Scarce event capacity and ticketing

**Capability ID:** `CAP-025`

**Canonical Name:** Scarce event capacity and ticketing

**Delivery Character:** `LATER_SPECIALISED`

**Authority Scope:** `CROSS_DOMAIN` — coordinates Events & Live capacity truth with Commerce payment truth; each source Domain retains its authority and no shared writes are introduced.

**Purpose:** Protect scarce event inventory through capacity holds, expiry, payment reconciliation, ticket issuance, transfer, check-in, cancellation, refund or credit under an approved event policy with zero confirmed oversell.

**Authoritative Domain:** `Events & Live` owns event capacity, reservation/hold, ticket, attendee, check-in and event-policy truth. `Commerce` owns payment and refund truth.

**Supporting Domains:** `Commerce`; `Entitlements`; `Identity & Access`; `Privacy & Consent`; `Communications`; `Content & Media`; `Audit & Evidence`; `Analytics`.

**Authority Anchors:** `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §6.13`; `docs/history/platform/archive/00_PLATFORM_v1.2.1.md §§21G.17–21G.21`; `docs/history/platform/archive/03_ARCHITECTURE_v1.0.0.md §10.3`; `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-015`.

**Lifecycle Relevance:** `YES` — event-capacity lifecycle; `Events & Live`; earliest full specification point is `FP-015`.

**Security / Privacy / Safety Significance:** `HIGH` — capacity/ticket authority, purchaser/holder/attendee separation and event policy must survive retries, abuse and provider ambiguity.

**Performance / Concurrency Significance:** `BURST_SENSITIVE` — scarce-inventory contention, flash-sale admission, hold expiry and check-in bursts are correctness-sensitive.

**External Dependency Relevance:** `Paystack` through `CAP-010`; live/replay providers only for affected variants; reservation semantics remain `JIT / GATED`.

**Approved Future Reuse / Extension Context:** Reused by approved paid event catalogues and capacity-controlled participation; ordinary live access remains `CAP-021`.

**JIT Boundary:** Hold/locking/expiry protocol, ticket Resources, concurrency proof, provider reconciliation and failure recovery remain downstream.

### CAP-026 — Governed experimentation and learning

**Capability ID:** `CAP-026`

**Canonical Name:** Governed experimentation and learning

**Delivery Character:** `LATER_SPECIALISED`

**Authority Scope:** `CROSS_DOMAIN` — coordinates Experimentation assignment/exposure truth with source outcome and analytics truths; each source Domain retains its authority and no shared writes are introduced.

**Purpose:** Configure approved experiments, assign eligible subjects, record exposure, compare authoritative outcomes and preserve auditable learning without changing safety, payment, entitlement, consent, accessibility, security or accounting truth.

**Authoritative Domain:** `Experimentation` owns experiment configuration/version, variants, eligibility exclusions, assignment, exposure definition and governed decision/learning record. `Analytics` owns measurement facts and aggregates.

**Supporting Domains:** `Analytics`; `Content & Media`; `Communications`; `Commerce`; `Identity & Access`; `Privacy & Consent`; `Audit & Evidence`.

**Authority Anchors:** `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §6.16`; `docs/history/platform/archive/03_ARCHITECTURE_v1.0.0.md §§10.4–10.5`; `docs/history/platform/archive/00_PLATFORM_v1.2.1.md §§21K.6A, 21L.13 and 21L.23`; `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-016`.

**Lifecycle Relevance:** `YES` — experiment lifecycle; `Experimentation`; earliest full specification point is `FP-016`.

**Security / Privacy / Safety Significance:** `HIGH` — variants cannot weaken protected invariants, assignment must minimise identity/health detail and deletion must remove or suppress identifiable evidence where required.

**Performance / Concurrency Significance:** `BURST_SENSITIVE` — assignment and exposure volume, concurrent variants, analytics lag and cache separation can create broad load.

**External Dependency Relevance:** `JIT / GATED` — statistical and implementation tooling remains proof-gated; external processors are conditional.

**Approved Future Reuse / Extension Context:** Reused for approved product, content, acquisition and commerce learning after a real measurable decision surface exists.

**JIT Boundary:** Assignment algorithm, exposure contract, statistical method, cache isolation, anonymous-known continuity and analysis implementation remain downstream.

### CAP-027 — Analytics and measurement

**Capability ID:** `CAP-027`

**Canonical Name:** Analytics and measurement

**Delivery Character:** `FOUNDATIONAL`

**Authority Scope:** `CROSS_DOMAIN` — projects and measures facts from multiple Domain-owned sources; each source Domain retains business authority and no shared writes are introduced.

**Purpose:** Collect governed minimum analytical facts, derive rebuildable projections and aggregates, serve trustworthy dashboards/reports and measure product, behaviour, operational and experiment outcomes without becoming source-domain business truth.

**Authoritative Domain:** `Analytics` owns analytical event facts, projections, aggregates, dashboards, attribution interpretations and experiment measurement evidence. Source Domains retain payment, entitlement, safety, plan, consent and other business truth.

**Supporting Domains:** All authoritative Domains contribute approved minimum facts; `Privacy & Consent`; `Experimentation`; `Audit & Evidence`; `Communications`.

**Authority Anchors:** `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §6.17 and §5`; `docs/history/platform/archive/PLATFORM_OPERATING_MODEL_v1.0.1.md §§17–20`; `docs/history/platform/archive/03_ARCHITECTURE_v1.0.0.md §§8.4, 10.4 and 13`; `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §§6 FP-006 and FP-016`.

**Lifecycle Relevance:** `YES` — analytics-evidence lifecycle; `Analytics`; earliest full specification point is `FP-006`.

**Security / Privacy / Safety Significance:** `HIGH` — linked behavioural or health-derived data must be minimised, access-controlled and deleted or suppressed under privacy rules.

**Performance / Concurrency Significance:** `HIGH` — event volume, dashboard concurrency, large exports and rebuilds must not starve critical transactional work.

**External Dependency Relevance:** External analytics/reporting systems are complementary evidence only; processor use remains `JIT / GATED`.

**Approved Future Reuse / Extension Context:** Reused by every pilot, product, programme, event, community, professional and experimentation outcome as governed evidence.

**JIT Boundary:** Event contracts, analytical storage/read models, metric definitions, dashboard/report shapes and processor deletion remain downstream.

### CAP-028 — Audit and security evidence

**Capability ID:** `CAP-028`

**Canonical Name:** Audit and security evidence

**Delivery Character:** `FOUNDATIONAL`

**Authority Scope:** `DOMAIN_OWNED` — `Audit & Evidence` owns the principal durable evidence truth; audited source Domains retain business truth and do not become shared-write owners.

**Purpose:** Preserve restricted, minimum-necessary evidence of sensitive actions, privileged access, security events, incidents and release decisions so the platform can be reviewed without replacing the business facts being audited.

**Authoritative Domain:** `Audit & Evidence` owns central append-only audit/security evidence, evidence links, incident/release evidence and evidence access/retention metadata. Source Domains own the underlying business transitions.

**Supporting Domains:** `Identity & Access`; `Privacy & Consent`; `Commerce`; `Entitlements`; `Safety & Eligibility`; `Professional Care`; `Community`; `Analytics`; all sensitive Domains.

**Authority Anchors:** `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §6.18`; `docs/history/platform/archive/03_ARCHITECTURE_v1.0.0.md §§12.3, 12.4 and 14`; `docs/history/platform/archive/PLATFORM_OPERATING_MODEL_v1.0.1.md §§22, 25 and 28`; `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-006`.

**Lifecycle Relevance:** `YES` — audit-evidence lifecycle; `Audit & Evidence`; earliest full specification point is `FP-001`.

**Security / Privacy / Safety Significance:** `HIGH` — evidence must prove privileged and safety-sensitive actions without duplicating raw health or professional payloads.

**Performance / Concurrency Significance:** `HIGH` — sensitive actions may generate high-cardinality evidence, security bursts, incident queries and large restricted exports.

**External Dependency Relevance:** `NONE` as evidence authority; external observability systems may receive minimised telemetry but do not replace it.

**Approved Future Reuse / Extension Context:** Reused across every protected Domain, release gate, incident review, professional case and future product-space activation.

**JIT Boundary:** Evidence Resources, retention classes, incident linkage, secure review/export and mandatory-write handling remain downstream.

### CAP-029 — Operator work and support

**Capability ID:** `CAP-029`

**Canonical Name:** Operator work and support

**Delivery Character:** `FOUNDATIONAL`

**Authority Scope:** `PLATFORM_CONTROL` — this is an operator/work presentation and control boundary, not a business-truth owner; source Domains retain business authority.

**Purpose:** Give named staff a workflow-first way to see assigned, overdue, blocked or exceptional work, resolve permitted participant issues and hand off evidence without creating a universal business-task authority or bypassing Domain ownership.

**Authoritative Domain:** No single Domain owns this composite capability. The Operating Model governs work presentation; source Domains own business actions and `Audit & Evidence` owns required central evidence.

**Supporting Domains:** `Identity & Access`; `Commerce`; `Entitlements`; `Content & Media`; `Communications`; `Professional Care`; `Community`; `Events & Live`; `Analytics`; `Audit & Evidence`.

**Authority Anchors:** `docs/history/platform/archive/PLATFORM_OPERATING_MODEL_v1.0.1.md §§5–8 and 22`; `FRONTEND_EXPERIENCE_SYSTEM_v1.0.1.md §6`; `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §4.1`; `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-006`.

**Lifecycle Relevance:** `YES` — operator-work lifecycle; source workflow owners govern the underlying work and the Operating Model supplies the presentation boundary; earliest full specification point is `FP-006`.

**Security / Privacy / Safety Significance:** `HIGH` — staff views and support actions require scoped authority, minimum data and safe handling of payment, health, professional and identity information.

**Performance / Concurrency Significance:** `MODERATE` — queues, filters, dashboards and support searches need bounded projections without peak-time source-table scans.

**External Dependency Relevance:** `NONE`; external provider dashboards are evidence/input surfaces and do not grant NewYou action authority.

**Approved Future Reuse / Extension Context:** Reused by content, payment, entitlement, safety, programme, community, event and professional operations.

**JIT Boundary:** Work projections, assignment/escalation semantics, role-specific actions, support privacy and operator UI composition remain downstream.

### CAP-030 — Release, incident and recovery control

**Capability ID:** `CAP-030`

**Canonical Name:** Release, incident and recovery control

**Delivery Character:** `FOUNDATIONAL`

**Authority Scope:** `PLATFORM_CONTROL` — this is a release, incident and recovery control boundary, not a business-truth owner; affected Domains retain business authority.

**Purpose:** Let accountable operators stage, observe, stop, roll back or recover a release and record the evidence needed to expand a paid or sensitive journey safely. This capability controls operation; it does not own the product facts it protects.

**Authoritative Domain:** No single Domain owns the control capability. Architecture and the Operating Model govern release/recovery doctrine, affected Domains retain business truth and `Audit & Evidence` retains central decision evidence.

**Supporting Domains:** `Identity & Access`; `Privacy & Consent`; `Commerce`; `Entitlements`; `Safety & Eligibility`; `Plans & Nutrition`; `Communications`; `Analytics`; `Audit & Evidence`.

**Authority Anchors:** `docs/history/platform/archive/03_ARCHITECTURE_v1.0.0.md §§12–14`; `docs/history/platform/archive/PLATFORM_OPERATING_MODEL_v1.0.1.md §§21–28`; `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §6.18`; `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §§6 FP-006 and 8`.

**Lifecycle Relevance:** `YES` — release-control lifecycle; Architecture/Operations governs control and `Audit & Evidence` records evidence; earliest full specification point is `FP-006`.

**Security / Privacy / Safety Significance:** `HIGH` — a stop, rollback, restore or incident action must not weaken safety, privacy, payment, entitlement or accounting invariants.

**Performance / Concurrency Significance:** `BURST_SENSITIVE` — failures, restore work, incident traffic and release transitions can create simultaneous operational pressure.

**External Dependency Relevance:** `JIT / GATED` — hosting, backup, restore, provider and RPO/RTO choices remain downstream.

**Approved Future Reuse / Extension Context:** Reused by every public, paid, professional, community, event and future market release tier.

**JIT Boundary:** Deployment/restore products, RPO/RTO targets, rollback/forward-recovery procedures, incident runbooks and operational evidence contracts remain downstream.

### CAP-031 — Controlled product-space and market activation

**Capability ID:** `CAP-031`

**Canonical Name:** Controlled product-space and market activation

**Delivery Character:** `LATER_SPECIALISED`

**Authority Scope:** `PLATFORM_CONTROL` — this is an activation and governance boundary, not a business-truth owner; the affected Domains named by Product and Architecture authority retain business truth.

**Purpose:** Activate a concrete, separately approved product space or market through shared platform boundaries without exposing unfinished products, inventing generic tenancy or duplicating identity, commerce, entitlement, content, safety or analytics truth.

**Authoritative Domain:** No single Domain owns this activation capability. Product Law and Architecture govern the activation boundary; the Domain or Domains named by the approved direction own the resulting business truth.

**Supporting Domains:** `Identity & Access`; `Privacy & Consent`; `Commerce`; `Entitlements`; `Content & Media`; `Safety & Eligibility`; `Plans & Nutrition`; `Communications`; `Analytics`; `Audit & Evidence`; any later affected Domain.

**Authority Anchors:** `docs/history/platform/archive/00_PLATFORM_v1.2.1.md §§21L.1–21L.3`; `docs/history/platform/archive/03_ARCHITECTURE_v1.0.0.md §§3.1–3.3 and 17`; `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §9`; `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-017`.

**Lifecycle Relevance:** `CONDITIONAL` — product-space activation lifecycle; Product Law/Architecture and affected Domain owners govern it; earliest full specification point is `FP-017` after a concrete approved direction exists.

**Security / Privacy / Safety Significance:** `HIGH` — unfinished products must remain invisible, market-specific safety/privacy/legal rules must be explicit and shared access must remain scoped.

**Performance / Concurrency Significance:** `HIGH` — an approved expansion must identify its workload, data, concurrency and shared-resource impact before activation.

**External Dependency Relevance:** `JIT / GATED` — market legal, payment, provider, privacy, clinical and operating approvals are required before activation.

**Approved Future Reuse / Extension Context:** Provides the controlled path for a future approved product space or market and nothing more. Generic tenancy, corporate dashboards and speculative future products are not included.

**JIT Boundary:** Product-space representation, market rules, activation/rollback contract, workload evidence and affected Domain/JIT detail remain unresolved until Product Law names the direction.

### CAP-032 — Research & Feedback

**Capability ID:** `CAP-032`

**Canonical Name:** Research & Feedback

**Delivery Character:** `LATER_SPECIALISED`

**Authority Scope:** `DOMAIN_OWNED` — `Research & Feedback` (Domain 19) owns the principal durable Research/feedback campaign, instrument/version, participant response, correction/withdrawal/de-link and staff-annotation truth; supporting Domains do not gain ownership.

**Purpose:** Navigate the Product-approved mature Research & Feedback capability owned by Domain 19. It is **not MVP**, is **not** FP-005 progress/feedback (`CAP-019`), is **not** automatically FP-006/008/009, and currently has **no activating Feature Pack**. Current Roadmap sequencing is `FUTURE-GATED / FEATURE-PACK-UNASSIGNED` until a later governed Roadmap decision assigns an activating outcome.

**Authoritative Domain:** `Research & Feedback`.

**Supporting Domains:** `Content & Media`; `Identity & Access`; `Communications`; `Privacy & Consent`; `Analytics`; `Audit & Evidence`; owner-mediated Safety/Professional Care/Commerce/Entitlements consequences where separately authorised.

**Authority Anchors:** `04_DOMAIN_MAP_v1.2.0.md §6.19`; `docs/history/platform/archive/05_ROADMAP_v1.1.0.md §§1.3, 3.4 and 6`; `docs/history/platform/archive/00_PLATFORM_v1.3.0.md §21M`; `DEC-294`.

**Lifecycle Relevance:** `YES` — Research campaign/instrument/response lifecycle; earliest full specification point is **FEATURE-PACK-UNASSIGNED** until Roadmap assigns an activating pack.

**Security / Privacy / Safety Significance:** `HIGH` — Research responses are not Health/Safety/Plan/Temperament truth; sensitive Research may later require stronger privacy/safety review when activated.

**Performance / Concurrency Significance:** `MODERATE` — campaign bursts and response writes become material only when an activating outcome exists.

**External Dependency Relevance:** `NONE` as business authority; later provider/instrument choices remain `JIT / GATED` when activated.

**Approved Future Reuse / Extension Context:** Available for a later governed Roadmap decision. Do not invent a Research Feature Pack or assign FP-017 ownership merely because the capability is future-gated.

**JIT Boundary:** Campaign/instrument Resources, response schemas, activation Feature Pack selection and any Research JIT Domain Dossier remain downstream of a governed Roadmap assignment. This Atlas row creates none of those artifacts.

### CAP-033 — Voting & Balloting

**Capability ID:** `CAP-033`

**Canonical Name:** Voting & Balloting

**Delivery Character:** `LATER_SPECIALISED`

**Authority Scope:** `DOMAIN_OWNED` — `Voting & Balloting` (Domain 20) owns the principal durable vote rules, submission/integrity evidence, accepted tally, finalisation, official result and adjudication truth; supporting Domains do not gain ownership.

**Purpose:** Navigate the Product-approved mature Voting & Balloting capability owned by Domain 20. It is **not MVP**, is **not** required by FP-008 or FP-013, and currently has **no Voting/Competitions Feature Pack**. Current Roadmap sequencing is `FUTURE-GATED / FEATURE-PACK-UNASSIGNED` until a later governed Roadmap decision assigns an activating outcome. Community/Programmes page location is not ownership or introduction evidence. Research polls remain Research by purpose (`CAP-032`).

**Authoritative Domain:** `Voting & Balloting`.

**Supporting Domains:** `Identity & Access`; `Entitlements`; `Programmes & Challenges`; `Community`; `Commerce`; `Analytics`; `Audit & Evidence`; `Communications` where separately authorised.

**Authority Anchors:** `04_DOMAIN_MAP_v1.2.0.md §6.20`; `docs/history/platform/archive/05_ROADMAP_v1.1.0.md §§1.3, 3.4, 6 FP-008 and FP-013`; `docs/history/platform/archive/00_PLATFORM_v1.3.0.md §21N`; `DEC-295`.

**Lifecycle Relevance:** `YES` — voting/balloting lifecycle; earliest full specification point is **FEATURE-PACK-UNASSIGNED** until Roadmap assigns an activating pack.

**Security / Privacy / Safety Significance:** `HIGH` — integrity assurance is not identity assurance; future public Voting may later require abuse/integrity evidence when activated.

**Performance / Concurrency Significance:** `BURST_SENSITIVE` — vote-open bursts become material only when an activating outcome exists.

**External Dependency Relevance:** `NONE` as business authority; later provider/surface choices remain `JIT / GATED` when activated.

**Approved Future Reuse / Extension Context:** Available for a later governed Roadmap decision. Do not invent a Voting or Competitions Feature Pack or assign FP-017 ownership merely because the capability is future-gated.

**JIT Boundary:** Vote-rule Resources, tally/finalisation semantics, activation Feature Pack selection and any Voting JIT Domain Dossier remain downstream of a governed Roadmap assignment. This Atlas row creates none of those artifacts.

## 5.3 ATLAS-03 coverage and quality audit

ATLAS-03 records capability identity, Delivery Character and Authority Scope. The complete capability-to-Feature-Pack relationship matrix is recorded separately in §5.4; this audit does not label every matrix cell.

### Feature Pack coverage

All 17 approved Feature Packs were read from the frozen Roadmap and the merged ATLAS-02 register. Each is explainable using the canonical vocabulary below or is an outcome composition that does not warrant a separate capability:

| Feature Pack | Coverage result | Review note |
|---|---|---|
| FP-001 | Covered | Trusted entry, scoped access, consent, public discovery, governed content, communications, audit and operator support are represented. |
| FP-002 | Covered | Catalogue, payment/reconciliation and entitlement authority are represented without merging money and access truth. |
| FP-003 | Covered | Temperament assessment/profile, protected report/content delivery, entitlement, consent and audit are represented. |
| FP-004 | Covered | Health records, safety/eligibility and scoped access are represented; professional review remains a later capability. |
| FP-005 | Covered | Deterministic plans, governed content, entitlement, protected delivery, progress/feedback and safety are represented. |
| FP-006 | Covered | Operator work, release/recovery control, analytics, audit and the foundational capabilities are represented. |
| FP-007 | Covered | Live/replay delivery, protected media, entitlement, communications and consent are represented. |
| FP-008 | Covered | Programme/cohort delivery, habits/progress, content, communications, live/replay and safety are represented. |
| FP-009 | Covered | Recurring commercial access, entitlement, community, content, live/replay and communications are represented. |
| FP-010 | Covered | Governed plan review/adjustment and progress inputs are represented; it does not create a second plan authority. |
| FP-011 | Covered | Premium is a commercial composition of recurring access, plans, content and entitlement capabilities. |
| FP-012 | Covered | Professional review/scoped care, safety, consent, plan, entitlement and operator evidence are represented. |
| FP-013 | Covered | Community participation/moderation, programme/challenge, progress, consent, communications and audit are represented. |
| FP-014 | Covered | Programme delivery, habits/private reflection, progress, content, communications and privacy are represented. |
| FP-015 | Covered | Scarce event capacity/ticketing, payment, entitlement, live/replay, communications and audit are represented. |
| FP-016 | Covered | Governed experimentation, analytics, content/communications, consent and audit are represented. |
| FP-017 | Covered conditionally | Controlled product-space/market activation is represented without inventing generic tenancy or a speculative product. |

This is a coverage audit, not the ATLAS-04 matrix. It does not label any capability as `introduced`, `reused`, `extended` or `specialised` for every Feature Pack.

### Domain coverage

All 20 approved Domain names were checked against the inventory. No capability grants shared authoritative writes between Domains. Interactive Tools remain purpose-distributed and are **not** a Domain. Platform Member Reference remains Identity & Access Account truth and is **not** a Domain.

| Domain | Coverage result |
|---|---|
| Identity & Access | Canonical identity, authentication, identity-side authorisation and Platform Member Reference Account truth are represented under CAP-001. |
| Privacy & Consent | Consent/purpose control and cross-Domain data-rights orchestration are represented. |
| Temperament | Assessment, profile, provenance and report capability is represented. |
| Health Records | Health/lifestyle facts, provenance and measurement capability is represented. |
| Safety & Eligibility | Safety evaluation, eligibility, restriction and re-evaluation capability is represented. |
| Plans & Nutrition | Deterministic plan delivery and governed adjustment are represented; plan calculations remain Plans-owned (`calculation != authority`). |
| Content & Media | Governed content, translation, publication, relevance and protected delivery are represented. |
| Programmes & Challenges | Programme, edition, cohort, challenge and completion capability is represented. |
| Habits, Journals & Progress | Progress/feedback (`CAP-019`) and private habit/journal capability are represented separately from Domain 19 Research. |
| Commerce | Catalogue, offers, payment/reconciliation and recurring commercial access are represented. |
| Entitlements | Access-rights, grant, redemption, consumption and revocation capability is represented. |
| Community | First-party participation and moderation capability is represented; Community surfaces do not own Voting. |
| Events & Live | Live/replay and scarce-capacity ticketing capability are represented separately. |
| Professional Care | Scoped professional review and care capability is represented. |
| Communications | Subscriber, preference, notification and delivery capability is represented. |
| Experimentation | Governed experiment configuration, assignment and learning capability is represented. |
| Analytics | Governed measurement, projection, dashboard and experiment-evidence capability is represented. |
| Audit & Evidence | Cross-cutting audit, security, incident and release evidence capability is represented. |
| Research & Feedback | Mature Research capability is represented by CAP-032 as `FUTURE-GATED / FEATURE-PACK-UNASSIGNED`; no activating FP is invented. |
| Voting & Balloting | Mature Voting capability is represented by CAP-033 as `FUTURE-GATED / FEATURE-PACK-UNASSIGNED`; no activating FP is invented. |

### Classification audit

Each of the 33 capabilities has exactly one Delivery Character and exactly one Authority Scope. The counts describe the inventory; they are not balancing targets.

| Axis | Counts |
|---|---|
| Delivery Character | `FOUNDATIONAL` 18; `SHARED_REUSE` 4; `LATER_SPECIALISED` 11 |
| Authority Scope | `DOMAIN_OWNED` 21; `CROSS_DOMAIN` 9; `PLATFORM_CONTROL` 3 |

`DOMAIN_OWNED` entries identify one frozen authoritative Domain. `CROSS_DOMAIN` entries state that source Domains retain authority and introduce no shared writes. `PLATFORM_CONTROL` entries state that the capability is a platform or operational boundary and does not own business truth.

### Lifecycle audit

All lifecycle flags were reviewed against the rule that `YES` requires an identifiable lifecycle-bearing domain or operational concept. CAP-007 changed from `CONDITIONAL` to `NO` because its relevance projection has no independent lifecycle; source content and relevance signals retain their existing Domain lifecycles. CAP-005 remains `CONDITIONAL` only for a governed subscriber-contact relationship. No other lifecycle flag changed, and no states, transitions, guards or side effects were added.

### Normalisation and rejection record

The extraction pass merged or rejected candidates as follows:

- Account registration, email verification, login, logout and reset were merged into `Canonical identity and authentication`; they are behaviours within one reusable identity capability.
- Role grants, purchaser/participant separation, practitioner scope and relationship checks were grouped under `Scoped authorisation and relationship access`; no separate universal access subsystem was created.
- Content identity, translation, publication, correction and withdrawal were grouped under `Governed content, translation and publication`; protected delivery was kept separate because access, rights and delivery failure have a distinct boundary.
- Plan generation/versioning was kept separate from recurring review/adjustment because the latter is a later governed capability with distinct safety and commercial gates.
- Lightweight progress/feedback was kept separate from habits and private reflective practice because journals, sharing and retention carry a different privacy and lifecycle boundary.
- Commerce and Entitlements were kept separate because payment/contract truth and access-rights truth are explicitly different authorities.
- `Command Centre`, `Checkout page`, `Participant Home`, `Send reset email`, `User`, `Payment` and `AssessmentResult` were rejected as UI surfaces, single actions or Resources/entities rather than capabilities.
- `PostgreSQL`, `Oban`, `PubSub`, `LiveView`, `Redis`, `Cachex`, `ETS`, queues, routes, API endpoints, schemas and modules were rejected as implementation mechanisms or artifacts.
- AI assistance, an AI recommendation engine, generic tenancy, generic LMS infrastructure and a generic feature-flag system were rejected as unsupported or explicitly deferred platform aspirations. Explainable content relevance remains a bounded approved capability over authoritative signals, not a new autonomous decision authority.

### ATLAS-03 boundary result

The inventory separates Delivery Character from Authority Scope. Domain-owned capabilities name one frozen Domain, cross-domain capabilities name the affected owners and preserve their authority, and platform-control capabilities do not become business-truth owners. No classification introduces shared writes. Lifecycle fields identify the meaningful concept, owner and earliest full-specification point only; no new states, transitions or implementation-grade lifecycle semantics are defined here. Performance fields record broad pressure only and do not select acceleration technology.

No unresolved Product, Architecture, Domain or Roadmap question was silently answered. The inventory follows current authority and leaves clinical, legal, commercial, methodology, provider, performance and implementation decisions at their existing gates or JIT boundary.

ATLAS-04 — Capability Introduction / Reuse Matrix is recorded in §5.4. ATLAS-05 — Domain Participation Derivation & Exception Review is recorded in §6. No downstream Feature Pack preparation is started by this artifact.

---

## 5.4 ATLAS-04 capability introduction / reuse matrix

ATLAS-04 connects the 33 canonical capabilities to the 17 frozen Feature Packs. It answers where a capability first becomes materially required and where a later Feature Pack materially reuses, extends or specialises it. The matrix is a derived delivery-planning view. It does not redesign a capability, transfer Domain ownership or authorise implementation.

### Source boundary and matrix rule

The matrix uses the Feature Pack identities, names and order in `docs/history/platform/archive/05_ROADMAP_v1.1.0.md §6` and the merged ATLAS-02 portfolio register above. Capability IDs, canonical names, classifications and ownership statements come from §5.2. Domain ownership remains governed by `04_DOMAIN_MAP_v1.2.0.md §§3–5` and the authoritative Domain named by each CAP entry. FUTURE-GATED / FEATURE-PACK-UNASSIGNED approved capabilities may appear in the inventory with zero material FP cells; that is intentional and must not be “fixed” by inventing an introduction Feature Pack.

Only one dominant relationship is recorded in a cell. `E` and `S` already imply reuse of the established capability. A dash is intentional where the capability may exist elsewhere in the platform but is not material to the Feature Pack outcome at Atlas resolution. No Resource, schema, action, API, component, technology or lifecycle state is defined here.

### Matrix relationship vocabulary

| Symbol | Relationship | Meaning |
|---|---|---|
| `I` | `INTRODUCE` | First approved Feature Pack where the canonical capability becomes materially required as a delivered platform capability. |
| `R` | `REUSE` | Feature Pack materially uses an established capability without changing its canonical authority or general semantics. |
| `E` | `EXTEND` | Feature Pack materially broadens the reusable capability while preserving its canonical identity and authority boundary. |
| `S` | `SPECIALISE` | Feature Pack applies an existing capability to a materially specialised approved context without creating a separate canonical capability. |
| `—` | No material relationship | The capability is not materially relevant to the Feature Pack outcome at Atlas resolution. |

### Main matrix

| CAP | Capability | FP-001 | FP-002 | FP-003 | FP-004 | FP-005 | FP-006 | FP-007 | FP-008 | FP-009 | FP-010 | FP-011 | FP-012 | FP-013 | FP-014 | FP-015 | FP-016 | FP-017 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| CAP-001 | Canonical identity and authentication | I | R | R | R | R | R | R | R | R | R | R | R | R | R | R | — | R |
| CAP-002 | Scoped authorisation and relationship access | I | R | R | R | R | R | R | R | R | R | R | R | R | R | R | — | R |
| CAP-003 | Consent and purpose control | I | — | R | R | R | R | R | R | R | — | — | R | R | R | R | R | R |
| CAP-004 | Data rights, retention and deletion orchestration | — | — | — | — | — | I | R | — | — | — | — | — | R | R | — | R | R |
| CAP-005 | Public discovery and acquisition | I | — | — | — | — | — | R | — | — | — | — | — | — | — | R | — | — |
| CAP-006 | Governed content, translation and publication | I | — | R | R | R | — | R | R | R | — | R | — | R | R | R | R | R |
| CAP-007 | Explainable content discovery and relevance | — | — | — | — | — | — | — | — | — | — | — | — | — | — | — | — | — |
| CAP-008 | Protected media and content delivery | — | — | I | — | R | — | R | R | R | — | R | — | — | — | — | — | — |
| CAP-009 | Commercial catalogue and offer management | — | I | — | — | — | — | — | — | R | — | R | R | — | — | R | — | R |
| CAP-010 | Payment and commercial reconciliation | — | I | — | — | — | R | — | — | R | — | R | R | — | — | R | — | — |
| CAP-011 | Entitlement and access-rights management | — | I | R | — | R | R | R | R | R | R | R | R | R | R | R | — | R |
| CAP-012 | Temperament assessment and profile | — | — | I | R | R | — | — | R | — | R | — | — | — | — | — | — | — |
| CAP-013 | Health and lifestyle records | — | — | — | I | R | — | — | R | — | R | — | R | — | — | — | — | — |
| CAP-014 | Safety and eligibility routing | — | — | — | I | R | — | — | R | — | R | — | R | R | R | — | — | R |
| CAP-015 | Deterministic plan generation and versioning | — | — | — | — | I | — | — | R | — | R | R | R | — | — | — | — | — |
| CAP-016 | Governed plan review and adjustment | — | — | — | — | — | — | — | — | — | I | R | — | — | — | — | — | — |
| CAP-017 | Communications and notification delivery | I | — | — | — | — | R | — | R | — | — | — | R | — | R | — | R | — |
| CAP-018 | Programme and cohort delivery | — | — | — | — | — | — | — | I | — | — | — | — | R | E | — | — | — |
| CAP-019 | Participant progress and feedback | — | — | — | — | I | — | — | R | — | R | — | — | R | R | — | — | — |
| CAP-020 | Habits and private reflective practice | — | — | — | — | — | — | — | — | — | — | — | — | — | I | — | — | — |
| CAP-021 | Live-session and replay delivery | — | — | — | — | — | — | I | R | R | — | — | — | — | — | — | — | — |
| CAP-022 | Recurring commercial access | — | — | — | — | — | — | — | — | I | — | R | — | — | — | — | — | — |
| CAP-023 | Professional review and scoped care | — | — | — | — | — | — | — | — | — | — | — | I | — | — | — | — | — |
| CAP-024 | Community participation and moderation | — | — | — | — | — | — | — | — | — | — | — | — | I | — | — | — | — |
| CAP-025 | Scarce event capacity and ticketing | — | — | — | — | — | — | — | — | — | — | — | — | — | — | I | — | — |
| CAP-026 | Governed experimentation and learning | — | — | — | — | — | — | — | — | — | — | — | — | — | — | — | I | — |
| CAP-027 | Analytics and measurement | — | — | — | — | — | I | — | R | R | — | — | — | R | R | — | R | R |
| CAP-028 | Audit and security evidence | I | R | R | R | R | R | R | R | R | R | R | R | R | R | R | R | R |
| CAP-029 | Operator work and support | — | — | — | — | — | I | R | R | R | — | — | R | R | — | R | R | R |
| CAP-030 | Release, incident and recovery control | — | — | — | — | — | I | — | — | — | — | — | — | — | — | R | R | R |
| CAP-031 | Controlled product-space and market activation | — | — | — | — | — | — | — | — | — | — | — | — | — | — | — | — | I |
| CAP-032 | Research & Feedback | — | — | — | — | — | — | — | — | — | — | — | — | — | — | — | — | — |
| CAP-033 | Voting & Balloting | — | — | — | — | — | — | — | — | — | — | — | — | — | — | — | — | — |

### Feature Pack capability summary

This reverse view contains CAP IDs only so a Feature Pack planning pass can retrieve one row without scanning the full matrix. A conditional `FP-017` row remains conditional on a separately approved product or market direction.

| Feature Pack | Introduces | Reuses | Extends | Specialises |
|---|---|---|---|---|
| FP-001 | CAP-001, CAP-002, CAP-003, CAP-005, CAP-006, CAP-017, CAP-028 | — | — | — |
| FP-002 | CAP-009, CAP-010, CAP-011 | CAP-001, CAP-002, CAP-028 | — | — |
| FP-003 | CAP-008, CAP-012 | CAP-001, CAP-002, CAP-003, CAP-006, CAP-011, CAP-028 | — | — |
| FP-004 | CAP-013, CAP-014 | CAP-001, CAP-002, CAP-003, CAP-006, CAP-012, CAP-028 | — | — |
| FP-005 | CAP-015, CAP-019 | CAP-001, CAP-002, CAP-003, CAP-006, CAP-008, CAP-011, CAP-012, CAP-013, CAP-014, CAP-028 | — | — |
| FP-006 | CAP-004, CAP-027, CAP-029, CAP-030 | CAP-001, CAP-002, CAP-003, CAP-010, CAP-011, CAP-017, CAP-028 | — | — |
| FP-007 | CAP-021 | CAP-001, CAP-002, CAP-003, CAP-004, CAP-005, CAP-006, CAP-008, CAP-011, CAP-028, CAP-029 | — | — |
| FP-008 | CAP-018 | CAP-001, CAP-002, CAP-003, CAP-006, CAP-008, CAP-011, CAP-012, CAP-013, CAP-014, CAP-015, CAP-017, CAP-019, CAP-021, CAP-027, CAP-028, CAP-029 | — | — |
| FP-009 | CAP-022 | CAP-001, CAP-002, CAP-003, CAP-006, CAP-008, CAP-009, CAP-010, CAP-011, CAP-021, CAP-027, CAP-028, CAP-029 | — | — |
| FP-010 | CAP-016 | CAP-001, CAP-002, CAP-011, CAP-012, CAP-013, CAP-014, CAP-015, CAP-019, CAP-028 | — | — |
| FP-011 | — | CAP-001, CAP-002, CAP-006, CAP-008, CAP-009, CAP-010, CAP-011, CAP-015, CAP-016, CAP-022, CAP-028 | — | — |
| FP-012 | CAP-023 | CAP-001, CAP-002, CAP-003, CAP-009, CAP-010, CAP-011, CAP-013, CAP-014, CAP-015, CAP-017, CAP-028, CAP-029 | — | — |
| FP-013 | CAP-024 | CAP-001, CAP-002, CAP-003, CAP-004, CAP-006, CAP-011, CAP-014, CAP-018, CAP-019, CAP-027, CAP-028, CAP-029 | — | — |
| FP-014 | CAP-020 | CAP-001, CAP-002, CAP-003, CAP-004, CAP-006, CAP-011, CAP-014, CAP-017, CAP-019, CAP-027, CAP-028 | CAP-018 | — |
| FP-015 | CAP-025 | CAP-001, CAP-002, CAP-003, CAP-005, CAP-006, CAP-009, CAP-010, CAP-011, CAP-028, CAP-029, CAP-030 | — | — |
| FP-016 | CAP-026 | CAP-003, CAP-004, CAP-006, CAP-017, CAP-027, CAP-028, CAP-029, CAP-030 | — | — |
| FP-017 | CAP-031 | CAP-001, CAP-002, CAP-003, CAP-004, CAP-006, CAP-009, CAP-011, CAP-014, CAP-027, CAP-028, CAP-029, CAP-030 | — | — |

### Capability lineage view

| Capability | Introduced | Later Reuse | Extensions | Specialisations |
|---|---|---|---|---|
| CAP-001 | FP-001 | FP-002, FP-003, FP-004, FP-005, FP-006, FP-007, FP-008, FP-009, FP-010, FP-011, FP-012, FP-013, FP-014, FP-015, FP-017 | — | — |
| CAP-002 | FP-001 | FP-002, FP-003, FP-004, FP-005, FP-006, FP-007, FP-008, FP-009, FP-010, FP-011, FP-012, FP-013, FP-014, FP-015, FP-017 | — | — |
| CAP-003 | FP-001 | FP-003, FP-004, FP-005, FP-006, FP-007, FP-008, FP-009, FP-012, FP-013, FP-014, FP-015, FP-016, FP-017 | — | — |
| CAP-004 | FP-006 | FP-007, FP-013, FP-014, FP-016, FP-017 | — | — |
| CAP-005 | FP-001 | FP-007, FP-015 | — | — |
| CAP-006 | FP-001 | FP-003, FP-004, FP-005, FP-007, FP-008, FP-009, FP-011, FP-013, FP-014, FP-015, FP-016, FP-017 | — | — |
| CAP-007 | — (Roadmap-deferred) | — | — | — |
| CAP-008 | FP-003 | FP-005, FP-007, FP-008, FP-009, FP-011 | — | — |
| CAP-009 | FP-002 | FP-009, FP-011, FP-012, FP-015, FP-017 | — | — |
| CAP-010 | FP-002 | FP-006, FP-009, FP-011, FP-012, FP-015 | — | — |
| CAP-011 | FP-002 | FP-003, FP-005, FP-006, FP-007, FP-008, FP-009, FP-010, FP-011, FP-012, FP-013, FP-014, FP-015, FP-017 | — | — |
| CAP-012 | FP-003 | FP-004, FP-005, FP-008, FP-010 | — | — |
| CAP-013 | FP-004 | FP-005, FP-008, FP-010, FP-012 | — | — |
| CAP-014 | FP-004 | FP-005, FP-008, FP-010, FP-012, FP-013, FP-014, FP-017 | — | — |
| CAP-015 | FP-005 | FP-008, FP-010, FP-011, FP-012 | — | — |
| CAP-016 | FP-010 | FP-011 | — | — |
| CAP-017 | FP-001 | FP-006, FP-008, FP-012, FP-014, FP-016 | — | — |
| CAP-018 | FP-008 | FP-013 | FP-014 | — |
| CAP-019 | FP-005 | FP-008, FP-010, FP-013, FP-014 | — | — |
| CAP-020 | FP-014 | — | — | — |
| CAP-021 | FP-007 | FP-008, FP-009 | — | — |
| CAP-022 | FP-009 | FP-011 | — | — |
| CAP-023 | FP-012 | — | — | — |
| CAP-024 | FP-013 | — | — | — |
| CAP-025 | FP-015 | — | — | — |
| CAP-026 | FP-016 | — | — | — |
| CAP-027 | FP-006 | FP-008, FP-009, FP-013, FP-014, FP-016, FP-017 | — | — |
| CAP-028 | FP-001 | FP-002, FP-003, FP-004, FP-005, FP-006, FP-007, FP-008, FP-009, FP-010, FP-011, FP-012, FP-013, FP-014, FP-015, FP-016, FP-017 | — | — |
| CAP-029 | FP-006 | FP-007, FP-008, FP-009, FP-012, FP-013, FP-015, FP-016, FP-017 | — | — |
| CAP-030 | FP-006 | FP-015, FP-016, FP-017 | — | — |
| CAP-031 | FP-017 | — | — | — |
| CAP-032 | — (FUTURE-GATED / FEATURE-PACK-UNASSIGNED) | — | — | — |
| CAP-033 | — (FUTURE-GATED / FEATURE-PACK-UNASSIGNED) | — | — | — |

### Exception / interpretation notes

Only non-routine decisions are noted below. Routine `R` cells remain intentionally unannotated. The notes preserve source-Domain authority and do not define implementation or lifecycle semantics.

| CAP | FP | Relationship | Why this classification matters | Authority Anchor |
|---|---|---|---|---|
| CAP-004 | FP-006 | `I` | FP-006 is the first outcome that explicitly requires pilot deletion/export, retention, restore and operational handling. Earlier privacy participation does not establish the complete orchestration capability. | `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-006`; `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §4` |
| CAP-005 | FP-001 | `I` | Public discovery is introduced by the public-to-account boundary. Later live and event discovery reuse it; it is not a universal acquisition dependency for every protected pack. | `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-001, §6 FP-007 and §6 FP-015`; `docs/history/platform/archive/DELIVERY_ATLAS_WORKING_v0.1.0.md §5.2 CAP-005` |
| CAP-008 | FP-003 | `I` | The protected bilingual assessment report is the first material protected-content delivery outcome. This does not make Content & Media an entitlement owner. | `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-003`; `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §4` |
| CAP-015 | FP-012 | `R` | A practitioner outcome may request an approved plan modification, but Plans & Nutrition owns any resulting plan version. Professional Care does not write plan truth. | `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-012`; `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §§4–5` |
| CAP-018 | FP-014 | `E` | FP-014 explicitly extends the concrete Nuwe Jy programme evidence into a broader foundation programme. Programmes & Challenges remains the sole programme/cohort authority. | `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-014`; `docs/history/platform/archive/DELIVERY_ATLAS_WORKING_v0.1.0.md §5.2 CAP-018`; `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §4` |
| CAP-020 | FP-014 | `I` | FP-008's habits/check-ins are represented by CAP-019 at Atlas resolution. FP-014 is the first outcome that explicitly requires private reflections and the broader habit/journal boundary. | `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-008 and §6 FP-014`; `docs/history/platform/archive/DELIVERY_ATLAS_WORKING_v0.1.0.md §5.2 CAP-019 and CAP-020` |
| CAP-022 | FP-009 | `I` | Basic Membership is the first approved recurring commercial outcome. FP-011 reuses the recurring contract boundary rather than creating a second Premium billing capability. | `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-009 and §6 FP-011`; `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §4` |
| CAP-023 | FP-012 | `I` | The practitioner-review service is intentionally introduced as a limited, capacity-controlled pilot. It does not take ownership of Health, Safety or Plans truth. | `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-012`; `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §§4–5` |
| CAP-024 | FP-013 | `I` | FP-009's governed community evidence may use the approved external path. First-party community participation and moderation begin only when FP-013 is approved, so no first-party authority is inferred earlier. | `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-009 and §6 FP-013`; `docs/history/platform/archive/DELIVERY_ATLAS_WORKING_v0.1.0.md §5.2 CAP-024` |
| CAP-025 | FP-015 | `I` | FP-015 is the first approved scarce-capacity outcome. FP-007 live registration does not introduce holds, tickets or capacity authority. | `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-007, §6 FP-015 and §12.3`; `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §4` |
| CAP-027 | FP-006 | `I` | FP-006 is the first outcome that requires controlled pilot observation and evidence. Earlier packs do not receive a generic analytics mark merely because their facts may later be measured. | `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-006 and §§7–8`; `docs/history/platform/archive/DELIVERY_ATLAS_WORKING_v0.1.0.md §5.2 CAP-027` |
| CAP-027 | FP-008, FP-013, FP-014 | `R` | These programme and challenge outcomes explicitly require approved completion or participation metrics through `OQ-019`; Analytics remains measurement authority and source Domains retain business truth. | `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-008, §6 FP-013 and §6 FP-014`; `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §6.17` |
| CAP-027 | FP-016 | `R` | Experiment exposure, conversion/income reconciliation and durable learning evidence make Analytics materially central to the approved experimentation outcome. | `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-016`; `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §§6.16–6.17`; `OQ-040` |
| CAP-028 | FP-001 | `I` | The protected identity boundary is the first material audit/security-evidence outcome. Later marks occur where payment, safety, release, moderation, professional or event evidence is part of the approved outcome. | `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-001 and §6 FP-006`; `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §4` |
| CAP-028 | FP-011, FP-014 | `R` | Premium's sensitive commercial/release boundary and the foundation programme's private-data, retention, completion and recovery obligations require the minimum audit/security evidence owned by Audit & Evidence. | `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-011 and §6 FP-014`; `docs/history/platform/archive/00_PLATFORM_v1.2.1.md §§21H, 21I`; `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §6.18` |
| CAP-029 | FP-006 | `I` | FP-001's controlled support path does not establish a reusable operator-work capability. FP-006 first requires named staff to run, correct, reconcile and support the core journey. | `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-001 and §6 FP-006`; `docs/history/platform/archive/DELIVERY_ATLAS_WORKING_v0.1.0.md §5.2 CAP-029` |
| CAP-030 | FP-006 | `I` | FP-006 is the first release, stop, rollback and recovery boundary. Later event, experiment and future-activation marks reuse that control without moving business truth into platform operations. | `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-006, §6 FP-015, §6 FP-016 and §6 FP-017`; `docs/history/platform/archive/DELIVERY_ATLAS_WORKING_v0.1.0.md §5.2 CAP-030` |
| CAP-031 | FP-017 | `I` | The capability remains conditional and is introduced only by a concrete separately approved product-space or market direction. No hypothetical market, tenancy or specialist product is mapped earlier. | `docs/history/platform/archive/05_ROADMAP_v1.1.0.md §6 FP-017 and §16`; `docs/history/platform/archive/DELIVERY_ATLAS_WORKING_v0.2.0.md §5.2 CAP-031` |
| CAP-032 | — | FUTURE-GATED / FEATURE-PACK-UNASSIGNED | Product-approved Domain 19 capability with zero current material FP cells. Not CAP-019, not FP-005, not automatically FP-006/008/009, and not assigned to FP-017. | `docs/history/platform/archive/05_ROADMAP_v1.1.0.md §§3.4 and 6`; `04_DOMAIN_MAP_v1.2.0.md §6.19` |
| CAP-033 | — | FUTURE-GATED / FEATURE-PACK-UNASSIGNED | Product-approved Domain 20 capability with zero current material FP cells. Not required by FP-008 or FP-013; no Voting/Competitions FP; not assigned to FP-017. | `docs/history/platform/archive/05_ROADMAP_v1.1.0.md §§3.4, 6 FP-008 and FP-013`; `04_DOMAIN_MAP_v1.2.0.md §6.20` |
| CAP-001 | FP-001 | `I` | FP-001 material identity includes the certified IAM-owned PMR reconciliation. Encoding remains unfrozen; Communications JIT Domain Dossier work is the current in-progress task. | `docs/history/platform/archive/05_ROADMAP_v1.1.0.md §6 FP-001`; `04_DOMAIN_MAP_v1.2.0.md §6.1` |
| — (no CAP) | — | purpose-distributed | Interactive Tools have no CAP, Domain or generic introduction FP. Calculation is not authority; delivery remains owner/outcome-specific. | `docs/history/platform/archive/05_ROADMAP_v1.1.0.md §§1.3 and 3.4`; `04_DOMAIN_MAP_v1.2.0.md` Interactive Tools doctrine |

### ATLAS-04 consistency and density audit

The matrix accounts for every CAP × FP position, including intentional dashes. Counts are descriptive results, not balancing targets.

| Audit | Result |
|---|---|
| Capability integrity | 33/33 CAP IDs and canonical names match §5.2 after reconciliation; CAP-032/CAP-033 are additive FUTURE-GATED rows; no existing CAP was renamed, merged or split; Interactive Tools remain without a CAP. |
| Feature Pack integrity | 17/17 FP IDs, names and order match the current Roadmap and ATLAS-02 register; no FP-018 / Research / Voting / Tools / Competitions / PMR Feature Pack exists. |
| Introduction integrity | 30 currently approved material introductions; every such CAP has exactly one `I`. CAP-007 remains Roadmap-deferred; CAP-032 and CAP-033 are `FUTURE-GATED / FEATURE-PACK-UNASSIGNED` with zero current material cells. No `R`, `E` or `S` occurs before an approved introduction. |
| Relationship integrity | One dominant symbol per cell; 156 `R`, 1 `E` and 0 `S` cells. Every `E` remains in the exception review. |
| Reverse lineage | Each CAP sequence reads left-to-right from an approved introduction into later reuse, extension or specialisation. Deferred/unassigned CAPs have no introduction lineage until a concrete approved introduction exists. |
| Feature Pack coverage | 17/17 Feature Packs have a summary row and are represented in the matrix; the conditional FP-017 boundary remains explicit and does not auto-own Research or Voting. |
| Domain ownership | 20/20 Domain names remain reviewed. Relationships do not transfer ownership or create shared authoritative writes; cross-Domain CAPs preserve source-Domain authority. |
| Lifecycle boundary | No state, transition, guard, side effect or terminal state was created. The matrix only points to capability introduction or later delivery use. |
| Scope boundary | No Resource/schema/action/API/component, technology, Domain × FP matrix, Feature Pack preparation, JIT dossier, TB, VS, HH, TOON or implementation code was added. |
| ATLAS-05 boundary | ATLAS-05 is recorded in §6 and intentionally maintains no permanent Domain × Feature Pack matrix. |

| Density measure | Count |
|---|---:|
| Total possible CAP × FP cells | 561 |
| Material relationships | 187 |
| `I` | 30 |
| `R` | 156 |
| `E` | 1 |
| `S` | 0 |
| `—` | 374 |
| Material relationship density | 33.3% |

The matrix remains intentionally selective: 374 of 561 positions are dashes, and the cross-cutting capabilities are marked only where the approved Feature Pack outcome makes their contribution material. CAP-007, CAP-032 and CAP-033 remain valid capabilities without current material introduction, reuse, extension or specialisation. No unresolved Product, Architecture, Domain or Roadmap question was solved inside ATLAS-04. Any future ambiguity belongs at the authority level named by the escalation matrix.

---

# 6. Domain participation derivation and exception review

## 6.1 Purpose and permanence rule

Domain × Feature Pack participation is a derived JIT view, not a permanently maintained Atlas matrix. ATLAS-05 intentionally does not populate a permanent Domain × Feature Pack matrix (historically planned as 18 × 17 = 306 cells; current Domain count is 20, which would be 340 cells if populated). Domains 19 and 20 currently have no activating Feature Pack, so manufacturing FP participation merely to display them would be false. A permanent matrix would repeat information already held in the Domain Map, ATLAS-02, ATLAS-03 and ATLAS-04 and would create a second representation of derived truth.

The permanent Atlas records the derivation rule, authority precedence, non-obvious exceptions, the JIT projection contract and a coverage audit. It does not precompute the interaction semantics of inactive Feature Packs.

### Canonical inputs

| Source | Planning use |
|---|---|
| Frozen Domain Map | Establishes the exact Domain names, durable-truth ownership and no-shared-write boundary. |
| ATLAS-02 Feature Pack Portfolio Register | Supplies each Feature Pack's high-level `Primary`, `Supporting` and `Consumer` involvement. |
| ATLAS-03 Platform Capability Inventory | Supplies each material CAP's authority scope, authoritative Domain, supporting Domains and lifecycle owner. |
| ATLAS-04 capability introduction / reuse matrix | Supplies the material CAPs introduced, reused, extended or specialised by each Feature Pack. |

The derivation chain is:

```text
Roadmap Feature Pack
    → ATLAS-04 material CAPs
    → ATLAS-03 CAP authority and support
    → ATLAS-02 high-level Domain involvement
    → Domain Map and authority-sensitive exceptions
    → temporary JIT Domain participation projection
```

## 6.2 Authority precedence

The following precedence applies whenever the sources appear to describe a relationship differently:

```text
Frozen Domain Map
    > CAP authoritative ownership and authority scope
    > Feature Pack participation view
    > derived JIT projection
```

The Domain Map controls Domain identity and ownership. ATLAS-03 preserves that ownership at capability level, including explicit cross-domain and platform-control boundaries. ATLAS-02 and ATLAS-04 provide delivery context. A JIT projection is temporary planning material and cannot move ownership, introduce shared authoritative writes or create a new Domain.

## 6.3 Derivation procedure

For any Feature Pack, the planner reconstructs the candidate Domain set as follows:

1. Read the Feature Pack row in the ATLAS-04 Feature Pack capability summary. Every `I`, `R`, `E` or `S` CAP in that row is a material capability relationship for this resolution.
2. Resolve each material CAP through the ATLAS-03 inventory. Use its authoritative Domain, supporting Domains, authority scope and lifecycle owner. Preserve explicit `CROSS_DOMAIN` and `PLATFORM_CONTROL` wording rather than converting it into a single business owner.
3. Compare the resulting candidate set with the ATLAS-02 `Primary`, `Supporting` and `Consumer` involvement. These labels provide delivery context. They do not override CAP authority or the Domain Map.
4. For the selected active Feature Pack, optional Grill-Me prompts may help identify which Domains actually require current JIT work. Generic supporting language is a signal to investigate, not an automatic request for a Domain Dossier; the approved outcome and source-owned gates determine requirements.
5. Produce the temporary projection described in §6.5. If a Domain, CAP authority or required relationship cannot be resolved from the four canonical inputs, record the exception and apply the STOP rule in §6.6.

Routine participation is therefore reconstructed when needed. It is not memorised as a second Atlas matrix.

## 6.4 Domain relationship exception register

The register keeps only relationship cases that need an explicit reminder because a simple participation label could hide an authority boundary, a conditional owner or a planning gate. It does not enumerate routine Domain participation.

| Exception | Feature Pack / CAP | Domain issue | Why it matters | JIT action | Status | Authority anchor |
|---|---|---|---|---|---|---|
| EX-001 | FP-001 through FP-015, FP-017 / CAP-002 | Cross-domain access relationship | Identity & Access owns identity-side grants. Each relationship-owning Domain keeps its own relationship or assignment truth. | Name the relationship owner for the active Feature Pack. Do not create a shared access owner. | REVIEWED / JIT_CONFIRM | §5.2 CAP-002; `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §§4–5` |
| EX-002 | FP-001, FP-007, FP-015 / CAP-005; CAP-007 deferred | Public discovery and relevance have no single funnel owner; relevance has no independent current lifecycle. | Content, Commerce, Communications, source Domains and Analytics retain their own authority. A projection must not become a new acquisition or ranking authority. CAP-007 is not permanently assigned to FP-007 or FP-015. | Confirm only the source facts and affected Domain work for the selected public or live outcome. Route richer search/relevance through a later concrete approved Feature Pack. | REVIEWED / JIT_CONFIRM | §5.2 CAP-005 and CAP-007; `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §§6 FP-001, FP-007 and FP-015` |
| EX-003 | FP-006, FP-007, FP-013, FP-014, FP-016, FP-017 / CAP-004 | Cross-domain privacy and deletion orchestration | Privacy & Consent owns the request and policy. Data-owning Domains fulfil record-level deletion, correction or export. | Map only the affected record owners for the active Feature Pack. Do not centralise their writes in the orchestration capability. | REVIEWED / JIT_CONFIRM | §5.2 CAP-004; `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §§4–5` |
| EX-004 | FP-003, FP-005, FP-007, FP-008, FP-009, FP-011 / CAP-008; FP-015 only if a live/recorded variant is approved | Protected media crosses content, access, consent and event boundaries. | Content & Media owns media truth. Entitlements and source Domains retain access and sharing truth. FP-015 scarce-capacity commerce does not intrinsically require protected media. | Confirm protected-delivery consequences only for the selected outcome and approved media variant, without transferring authority to Content & Media or Entitlements. | REVIEWED / JIT_CONFIRM | §5.2 CAP-008; `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §§4–5`; `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-015` |
| EX-005 | FP-009, FP-011 / CAP-022 | Recurring commercial access crosses Commerce and Entitlements. | Commerce owns the recurring contract and billing state. Entitlements owns the resulting access rights. | Keep contract, billing, cancellation and access-rights consequences separate in the active Feature Pack plan. | REVIEWED / JIT_CONFIRM | §5.2 CAP-022; `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §§6.10–6.11` |
| EX-006 | FP-012 / CAP-023 | Professional review has a platform case owner but unresolved final professional-record authority. | Professional Care must not silently become the legal or external professional record authority. | Apply `OQ-033` before the active Feature Pack fixes professional record, access, addendum or disposition semantics. STOP if that authority is required and unresolved. | GATED / OQ-033 | §5.2 CAP-023; `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-012`; `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §6.14` |
| EX-007 | FP-015 / CAP-025 | Scarce event capacity crosses Events & Live and Commerce. | Events & Live owns capacity, reservations, tickets and attendance. Commerce owns payment and refund truth. | Confirm capacity and payment consequences together while preserving separate authoritative owners. Apply `OQ-022` and `OQ-004` at the affected boundary. | GATED / OQ-022, OQ-004 | §5.2 CAP-025; `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §6 FP-015`; `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §6.13` |
| EX-008 | FP-006, FP-008, FP-009, FP-013, FP-014, FP-017 / CAP-027; FP-016 / CAP-026, CAP-027 | Analytics, experimentation and source outcomes have different authority. | Analytics owns measurement evidence, Experimentation owns assignment and learning decisions, and source Domains own business outcomes. `OQ-019` makes completion/participation metrics material for the named programme and challenge packs; `OQ-040` governs experimentation. | Identify the real decision surface and minimum source facts for the active Feature Pack. Do not treat measurement or assignment as source-domain authority. Apply the named OQ at the affected boundary. | GATED / OQ-019 or OQ-040 where applicable | §5.2 CAP-026 and CAP-027; `docs/history/platform/archive/05_ROADMAP_v1.0.0.md §§6 FP-008, FP-013, FP-014 and FP-016`; `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §§6.16–6.17` |
| EX-009 | FP-006, FP-007, FP-008, FP-009, FP-012, FP-013, FP-015, FP-016, FP-017 / CAP-029; FP-006, FP-015, FP-016, FP-017 / CAP-030 | Operator, release, incident and recovery controls have no single business-truth owner. | Platform control governs work and release decisions. Affected Domains retain business truth, and Audit & Evidence retains central evidence. | Keep operator and release actions owner-controlled and identify only the evidence and recovery work required by the active Feature Pack. | REVIEWED / JIT_CONFIRM | §5.2 CAP-029 and CAP-030; `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md §6.18` |
| EX-010 | FP-017 / CAP-031 | Conditional future ownership is not yet assigned. | No concrete product or market direction exists from which the affected Domain set can be determined. | STOP until Product Law names the approved direction and its affected Domain owners. Do not infer a market, tenancy or specialist product boundary. FP-017 does not automatically own Research or Voting. | CONDITIONAL / STOP | §5.2 CAP-031; `docs/history/platform/archive/05_ROADMAP_v1.1.0.md §6 FP-017`; `04_DOMAIN_MAP_v1.2.0.md §9` |
| EX-011 | CAP-032 / Domain 19 | Research & Feedback is Product-approved but Feature-Pack-unassigned. | Ownership is visible in Domain/capability navigation, but no current FP introduces Research. CAP-019 progress feedback is not Research. | Keep zero material matrix cells until a governed Roadmap decision assigns an activating outcome. Do not assign FP-005/006/008/009/017. | FUTURE-GATED / FEATURE-PACK-UNASSIGNED | §5.2 CAP-032; `docs/history/platform/archive/05_ROADMAP_v1.1.0.md §§3.4 and 6`; `04_DOMAIN_MAP_v1.2.0.md §6.19` |
| EX-012 | CAP-033 / Domain 20 | Voting & Balloting is Product-approved but Feature-Pack-unassigned. | Ownership is visible in Domain/capability navigation, but no current FP introduces Voting. FP-008 and FP-013 do not require it. | Keep zero material matrix cells until a governed Roadmap decision assigns an activating outcome. Do not invent a Voting/Competitions FP or assign FP-017. | FUTURE-GATED / FEATURE-PACK-UNASSIGNED | §5.2 CAP-033; `docs/history/platform/archive/05_ROADMAP_v1.1.0.md §§3.4, 6 FP-008 and FP-013`; `04_DOMAIN_MAP_v1.2.0.md §6.20` |
| EX-013 | Interactive Tools doctrine | Tools have no Domain, CAP or generic activation point. | A delivery mechanism must not become a hidden authority layer. | Sequence tools only inside the Feature Pack whose approved outcome requires them; retain owner Domain consequence authority; preserve `calculation != authority`. | REVIEWED / DOCTRINE | `docs/history/platform/archive/05_ROADMAP_v1.1.0.md §§1.3 and 3.4`; `04_DOMAIN_MAP_v1.2.0.md`; `docs/history/platform/archive/00_PLATFORM_v1.3.0.md §21O` |

The register is not a substitute for a dependency map or JIT Domain Dossier. It records why a future derivation needs care. It does not define reads, commands, consequences, projections, schemas or implementation behaviour.

## 6.5 JIT projection contract

ATLAS-05 creates no current-FP projection because no Feature Pack is selected by this pass. When a Feature Pack becomes active, its planner produces one temporary row for each Domain that actually requires JIT work. The projection uses these fields:

| Field | Required content |
|---|---|
| Domain | One exact Domain Map name. |
| Role in this FP | The evidence-backed role in the selected outcome, such as primary, supporting, consumer, platform control or gated participation. |
| Relevant CAPs | CAP IDs from the ATLAS-04 Feature Pack row that explain the Domain's involvement. |
| Existing authority | The Domain-owned truth, CAP authority scope and lifecycle owner already established upstream. |
| Lifecycle impact | Whether the selected outcome touches an existing lifecycle and where full specification becomes mandatory. No state or transition is invented here. |
| Durable consequence? | `YES`, `NO` or `CONFIRM` for whether the selected outcome may require an owner-controlled durable consequence. |
| JIT dossier required? | `YES`, `NO` or `CONDITIONAL`, with the reason for the decision. |
| Gate / STOP? | The named gate, unresolved authority or `NONE`. |

The `JIT dossier required?` value must resolve to the approved outcome, a controlling authority or a source-owned gate. This field records that requirement; it does not create one.

This projection is temporary/current-FP planning material. It must be rebuilt when the selected Feature Pack, material CAP row, upstream gate or ownership evidence changes. No projection can amend the Domain Map, CAP authority or Feature Pack outcome.

## 6.6 Coverage audit and STOP rule

The ATLAS-05 review confirms that the current Atlas can derive a coherent candidate Domain set for every approved Feature Pack without maintaining a permanent Domain × Feature Pack matrix.

| Audit | Result |
|---|---|
| Frozen Domain Map coverage | 20/20 approved Domain names and ownership boundaries are available to the derivation. Domains 19 and 20 are currently Feature-Pack-unassigned. |
| ATLAS-02 coverage | 17/17 approved Feature Packs have high-level Domain involvement. |
| ATLAS-04 coverage | 17/17 approved Feature Packs have a material CAP summary row. |
| ATLAS-03 CAP resolution | Every material CAP referenced by ATLAS-04 has a §5.2 entry with authority scope and ownership/support information; 30 CAPs have currently approved material introductions; CAP-007 is explicitly deferred; CAP-032 and CAP-033 are FUTURE-GATED / FEATURE-PACK-UNASSIGNED with zero current material cells. |
| Domain-set derivation | 17/17 Feature Packs can produce a candidate Domain set from the four canonical inputs. Research/Voting Domains are not manufactured into active-FP participation. |
| Cross-domain and platform-control review | CAPs with `CROSS_DOMAIN`, `PLATFORM_CONTROL`, conditional ownership, unresolved professional authority or FUTURE-GATED unassigned ownership are recorded in the exception register. |
| Conditional boundary | FP-017 remains conditional. Its affected Domain set is not assigned before a separately approved Product Law direction, and it does not auto-own Research or Voting. |
| Permanent matrix | 0 Domain × Feature Pack cells are maintained. No 20 × 17 permanent matrix is populated. |
| Ownership safety | No Domain ownership transfer or shared authoritative write is introduced by this pass. |
| Implementation boundary | No reads, commands, event flows, projections, schemas, Resources, APIs, PubSub, database consequences, JIT Dossiers or implementation tasks are created. |

ATLAS-05 reports `STOP` and routes the finding upstream if any of the following occurs:

- an approved Feature Pack has no ATLAS-04 summary row or a material CAP is missing from ATLAS-03;
- ATLAS-02, ATLAS-03 or ATLAS-04 conflicts with the frozen Domain Map;
- a CAP has contradictory authority, shared authoritative writes or no authority able to support its mapped Feature Pack use;
- the candidate Domain set cannot be resolved without inventing lifecycle semantics or implementation interactions;
- an active conditional Feature Pack lacks the Product, legal, clinical, commercial or market direction required to name its owners; or
- a mandatory governance rule would have to change outside this working Atlas.

For a STOP, record the exact source and section, the finding, the authority that must decide it, the affected Feature Pack/CAP relationship and the safe downstream action. Make no Atlas-level guess.

---

# 7. Lifecycle derivation & JIT projection contract

## 7.1 Purpose and permanent boundary

Section 7 is a permanent delivery contract for discovering lifecycle obligations when an approved Feature Pack becomes active. It is not a platform-wide lifecycle inventory and it does not define implementation-grade state machines.

No permanent platform-wide lifecycle concept table is maintained.

Permanent lifecycle rows: `0`.

The permanent Atlas keeps the derivation rule, authority boundary, temporary projection contract, review triggers, STOP rules and closure audit. It does not enumerate future lifecycle concepts merely to make the mature platform look complete.

Stable lifecycle metadata already exists through:

- ATLAS-03 capability lifecycle relevance, broad concept, ownership, authority scope and JIT boundary;
- ATLAS-04 Feature Pack capability materiality and sequencing;
- ATLAS-05 Domain participation derivation and exceptions; and
- frozen Product, Architecture, Domain and Roadmap authority.

Concept-level lifecycle decomposition is produced only when the active Feature Pack and current authority provide enough evidence to do so safely.

## 7.2 State-machine rule

Every Domain concept with a meaningful lifecycle must eventually define:

- states;
- transitions;
- transition guards;
- side effects;
- terminal states;
- correction semantics;
- reversal semantics;
- invalidation semantics where applicable;
- concurrency implications where applicable; and
- audit/evidence obligations where applicable.

These complete semantics belong in the relevant JIT Domain Dossier unless a higher authority has already frozen them. The Atlas records the obligation and timing. It never invents the state names, transitions, guards, side effects, terminal behaviour or exact implementation representation.

## 7.3 Canonical inputs and authority boundary

The derivation uses the following sources and does not create a second lifecycle authority:

| Source | Lifecycle use |
|---|---|
| ATLAS-04 | Material `CAP-*` relationships for the active Feature Pack, including `I`, `R`, `E` or `S`. |
| ATLAS-03 | Lifecycle relevance, broad concept, authoritative Domain, authority scope, performance/concurrency pressure and JIT boundary. |
| Frozen Domain Map | Durable-truth ownership, cross-domain rules and platform-control boundaries. |
| ATLAS-05 | Active-Feature-Pack Domain derivation, non-obvious exceptions and temporary projection handling. |
| Product / Architecture / Roadmap authority | Frozen semantics, state-authority rules, proof expectations, gates and sequencing constraints. |

The authority hierarchy remains:

~~~text
Product Law
    → Architecture Law
    → Domain Law
    → Roadmap
~~~

For lifecycle delivery navigation, the Atlas may help locate the Roadmap-to-Phase 7 path; it adds no authority stage or prerequisite.

The frozen Domain Map controls ownership. ATLAS-03 supplies capability-level lifecycle context. ATLAS-04 supplies delivery materiality. ATLAS-05 supplies active-FP Domain derivation. A temporary projection cannot move ownership, add a Domain or introduce shared authoritative writes.

## 7.4 Derivation path and procedure

The deterministic path for an active Feature Pack is:

~~~text
Active Feature Pack
    → ATLAS-04 material CAP relationships
    → ATLAS-03 lifecycle relevance / owner / JIT boundary
    → Frozen Domain ownership
    → ATLAS-05 Domain projection and exceptions
    → Product / Architecture / Roadmap gates
    → temporary active-FP lifecycle projection
    → Phase 7A Feature Pack Skeleton + preliminary Gate Manifest
    → Phase 7B required JIT Domain Dossiers
    → Phase 7C Final Feature Pack Contract
    → separate post-Phase-7C / pre-Phase-8 architectural proof classification gate
    → Phase 8 executable architectural proof / TB when required and after Development Entry Hard Stops pass
    → VS
    → HH
    → Release / Readiness
~~~

For each active Feature Pack:

1. Confirm the exact approved `FP-*` outcome and read its ATLAS-04 Feature Pack capability summary.
2. Collect every material `CAP-*` relationship marked `I`, `R`, `E` or `S`. A missing summary row or unresolved material CAP is a STOP.
3. Read the relevant ATLAS-03 entries for lifecycle relevance, broad concept, owner, authority scope, JIT boundary and broad pressure. A `NO` lifecycle entry creates no independent lifecycle obligation.
4. Resolve each durable truth through the frozen Domain Map. Preserve separate owners for `CROSS_DOMAIN` capabilities and preserve `PLATFORM_CONTROL` wording.
5. Apply the ATLAS-05 Domain projection and relevant exception handling. Generic participation is a review signal, not proof that a Domain Dossier is required.
6. Check Product, Architecture and Roadmap semantics, gates and proof expectations. Do not resolve an upstream question inside the Atlas.
7. Create the temporary lifecycle projection described in §7.6. Create one row for each lifecycle obligation supported by the active evidence, not one row for every CAP by default.
8. Optional Grill-Me prompts may pressure-test the projection. Create or update an affected JIT Domain Dossier before implementation only when the approved outcome, preliminary Gate Manifest or another controlling source requires those complete lifecycle semantics.

If any step requires an invented business concept, owner, state, transition, mechanism or policy decision, mark the projection `STOPPED` and route it.

## 7.5 Capability != lifecycle concept

A canonical capability may contain no independent lifecycle, one lifecycle-bearing concept or multiple lifecycle-bearing concepts. A lifecycle-bearing concept does not automatically become a new canonical capability.

Concept decomposition happens only when:

- the Feature Pack is active; and
- current Product, Architecture, Domain, Roadmap or approved Feature Pack evidence supports the decomposition.

If one CAP contains multiple durable truths, the temporary projection may contain separate obligation rows for the separate owners. Those rows are not permanent Section 7 entries. If the concepts cannot be separated safely at the current authority level, use `STOPPED` rather than filling the gap with a plausible decomposition.

## 7.6 Temporary lifecycle projection contract

The active Feature Pack planner creates a temporary, non-authoritative projection. It is rebuilt when the selected Feature Pack, material CAP relationships, upstream gates or ownership evidence change. It must not become a second platform authority.

| Field | Required meaning |
|---|---|
| Feature Pack | The exact active `FP-*`. |
| CAP relationship | The relevant `CAP-*` and its ATLAS-04 relationship, `I`, `R`, `E` or `S`. |
| Lifecycle concept | A medium-resolution concept supported by current authority and active-Feature-Pack evidence. |
| Owning Domain / authority | The exact durable-truth owner, separate owners for separate truths, or an explicit platform-control boundary. |
| Upstream semantics | Product, Architecture and Domain rules already frozen and the exact evidence references. |
| Lifecycle coverage | One status from §7.7. This answers how much lifecycle specification is required now. |
| Risk flags | Zero or more broad lifecycle correctness concerns from §7.8. These explain why the lifecycle may be difficult or dangerous. |
| Full-spec location | The relevant JIT Domain Dossier or an existing frozen authority that already contains the complete semantics. |
| Proof need | Whether a materially unproven architectural correctness claim requires explicit proof review. |
| Gate / STOP | The named gate, authority escalation or `NONE`. |

No temporary projection row is copied into a permanent lifecycle register. The projection may identify an obligation, timing, risk or gate. It may not define a Resource, action, schema, queue, cache, provider mechanism or exact state machine.

## 7.7 Lifecycle coverage vocabulary

Coverage status answers: "How much lifecycle specification is required now?" Use exactly one of the following values for each temporary lifecycle obligation.

### `NONE`

No independent lifecycle obligation exists for this active relationship.

### `EXISTENCE_ONLY`

A meaningful lifecycle is known to exist, but current Feature Pack work does not yet require complete semantics.

### `UPSTREAM_SEMANTICS`

Material lifecycle meaning is already frozen upstream and must be preserved, but implementation-grade specification is not yet required by this Feature Pack.

### `FULL_SPEC_REQUIRED`

The active Feature Pack cannot proceed safely without implementation-grade lifecycle specification.

Use this status only when current authority, the preliminary Gate Manifest or an approved Feature Pack contract requires full lifecycle specification for the active work. The Atlas records that source-owned requirement; it does not create one. Where required, the relevant JIT Domain Dossier defines states, transitions, guards, side effects, terminal states, correction, reversal, invalidation where applicable, concurrency implications and audit/evidence obligations.

### `PROOF_REQUIRED`

The lifecycle exposes a materially unproven architectural correctness claim requiring explicit proof planning.

`PROOF_REQUIRED` does not automatically mandate a Tracer Bullet. Phase 7C freezes the architectural proof requirement and applicable obligations; the separate post-7C, pre-Phase-8 classification gate selects `REUSE_EXISTING_PROOF` or `NEW_TRACER_BULLET`. This gate is a Development Entry Hard Stop and does not itself prove the architecture.

### `STOPPED`

Required lifecycle semantics cannot be determined safely from current authority. Route to the correct upstream authority and do not guess.

## 7.8 Coverage status versus risk flags

Coverage status and risk flags are separate dimensions.

Coverage status records the amount of lifecycle specification needed now. Risk flags record what makes the lifecycle potentially difficult or dangerous. A lifecycle may have `FULL_SPEC_REQUIRED` with `NONE` as its risk flag, or it may carry several risk flags without requiring full specification in the current Feature Pack.

Permit only these broad risk flags where relevant:

- `CORRECTION`
- `REVERSAL`
- `INVALIDATION`
- `TERMINALITY`
- `CONCURRENCY`
- `STALE_DECISION`
- `DUPLICATE_EXECUTION`
- `PROVIDER_AMBIGUITY`
- `ASYNC_DELAY`
- `REVOCATION`
- `DELETION_RESTORE`
- `SAFETY_REEVALUATION`
- `SCARCE_CAPACITY`
- `NONE`

Risk flags do not prescribe implementation. Section 7 may record `CONCURRENCY`, `DUPLICATE_EXECUTION`, provider ambiguity or delayed async consequences, but it must not select Redis, ETS, Cachex, GenServer, optimistic locking, row locks, indexes, queues, Oban, PubSub, TTLs, schemas or provider-specific retry mechanisms. Those decisions remain JIT and evidence-driven unless already frozen upstream.

Preserve `authority != acceleration` and NewYou's simplest-correct-path-first doctrine.

## 7.9 Cross-domain and platform-control lifecycle rules

A cross-domain capability does not create a shared lifecycle owner. Where an active Feature Pack touches multiple durable truths, the temporary projection creates separate lifecycle obligations for the separate owners where required.

Existing authority shapes include privacy orchestration versus data-owner record lifecycles, recurring Commerce contract versus Entitlement lifecycle, event capacity versus payment lifecycle, and platform-control release/recovery versus source-Domain business truth. Section 7 records these as ownership boundaries only. It does not define their states or transitions.

A platform-control lifecycle is operational control, not a hidden owner of payment, entitlement, health, safety, plan, professional, event or participant business state. Affected Domains retain business authority. Audit & Evidence may retain central evidence without acquiring the underlying truth.

If a projection would require shared authoritative writes or would make a coordinator the owner of another Domain's business state, mark it `STOPPED` and route the issue to Domain Law and Architecture Law.

## 7.10 JIT Domain Dossier gate and proof boundary

When current authority, a preliminary Gate Manifest or an approved Feature Pack contract makes complete lifecycle specification a prerequisite, the affected Domain's JIT Domain Dossier must contain those implementation-grade semantics before the governed work proceeds. The Atlas may identify a possible need but cannot independently impose this prerequisite. The Dossier must satisfy the state-machine rule in §7.2.

If the Dossier cannot define the lifecycle without resolving higher-level uncertainty, the projection remains `STOPPED`. No implementation agent may invent the missing state machine.

`PROOF_REQUIRED` is a planning signal for a materially unproven correctness claim. The Phase 7C contract freezes the proof requirement and applicable obligations; a separate post-7C, pre-Phase-8 classification gate selects `REUSE_EXISTING_PROOF` or `NEW_TRACER_BULLET`. Classification is a Development Entry Hard Stop requirement and does not itself prove the architecture. No ceremonial Tracer Bullet is created by Section 7.

## 7.11 Feature Pack Grill-Me role

Optional Feature Pack Grill-Me prompts can pressure-test each material lifecycle projection. A review is mandatory only if its owning source says so. Useful questions include:

- What durable truth changes?
- Who owns it?
- Does a meaningful lifecycle exist?
- What lifecycle semantics are already frozen?
- Does this Feature Pack require complete specification now?
- Can failure be corrected?
- Can it be reversed?
- Is there a terminal state?
- Can the decision become stale?
- Can execution duplicate?
- Can external or provider state conflict?
- Is concurrency correctness material?
- Is safety re-evaluation involved?
- Is proof already available?
- Is a JIT Domain Dossier required?
- Is any higher authority unresolved?

Section 7 does not answer these questions globally. It records the temporary evidence-backed result and routes unresolved questions.

## 7.12 Projection review triggers

Do not create a large permanent lifecycle exception register. During active-Feature-Pack projection, trigger special review for:

- ambiguous lifecycle owner;
- multiple durable truths in one CAP;
- cross-domain orchestration;
- platform-control versus business-truth boundary;
- irreversible or terminal action;
- correction or reversal uncertainty;
- external-provider ambiguity;
- high-concurrency write path;
- safety-critical re-evaluation;
- deletion/restore interaction;
- scarce capacity; or
- unresolved Product, legal, clinical, commercial, provider or methodology gate.

These are advisory prompts for attention, not gates by themselves or permanent lifecycle rows.

## 7.13 Selective context rule

A fresh Feature Pack agent should retrieve only:

1. the active Feature Pack summary from ATLAS-04;
2. the relevant CAP entries from ATLAS-03;
3. relevant Domain participation and exceptions from ATLAS-05;
4. this Section 7 derivation contract; and
5. the exact upstream references required by those entries.

The agent must not need to read the whole Delivery Atlas or reconstruct a permanent lifecycle table. The projection is selective because ATLAS-04 identifies material CAPs and ATLAS-05 identifies non-obvious Domain relationships.

## 7.14 Lifecycle STOP and escalation rules

STOP the active projection and report the exact `CAP-*`, Domain and `FP-*` when:

- ATLAS-03 lifecycle ownership contradicts the frozen Domain Map;
- a CAP requires lifecycle ownership not supported by current authority;
- defining the lifecycle concept would require invention;
- the state-machine rule conflicts with Product or Domain authority;
- cross-domain handling would require shared authoritative writes;
- platform control appears to acquire business truth;
- a required Product, legal, clinical, commercial, provider or methodology decision is unresolved;
- an implementation mechanism is required to decide lifecycle scope;
- a mandatory governance rule outside the Atlas would need to change; or
- Foundation Integrity validation fails.

A STOP record names the exact source references, contradiction or missing decision, authority that must decide, affected CAP/Domain/Feature Pack relationship and minimum safe resolution. No Atlas-level guess is permitted.

Known gates remain unresolved and are not amended by this contract. These include professional-record authority, event reservation architecture, payment and recurring provider semantics, clinical and calculation decisions, and the conditional future Product direction for FP-017. An active projection marks the relevant gate or `STOPPED` status rather than solving it.

## 7.15 ATLAS-06 closure audit

| Audit | Result |
|---|---|
| Permanent lifecycle rows | `0` |
| ATLAS-03 lifecycle records | 31 CAP lifecycle records remain unchanged. |
| ATLAS-04 materiality and sequencing | Existing CAP-to-Feature-Pack relationships remain unchanged. |
| ATLAS-05 Domain derivation | Existing derivation, exceptions and ownership boundaries remain unchanged. |
| Lifecycle concept invention | None. Concepts are decomposed only in an active-FP projection when evidence supports it. |
| State-machine invention | None. No states, transitions, guards, side effects or terminal semantics are defined here. |
| Correction and recovery invention | None. Correction, reversal, invalidation, concurrency and audit obligations remain JIT unless already frozen upstream. |
| Authority boundary | No Product, Architecture, Domain, Roadmap or manifest authority changed. |
| Temporary projection boundary | The active-FP projection is explicitly non-authoritative and produces no permanent lifecycle rows. |
| JIT completeness | Complete state-machine specification is required in a JIT Domain Dossier when current authority or the approved Feature Pack gate requires it; the Atlas status alone does not create the gate. |
| Proof/TB boundary | `PROOF_REQUIRED` flags proof planning and does not automatically create a Tracer Bullet. |
| Selective derivation | An active Feature Pack can retrieve material CAPs, relevant Domain exceptions and required upstream references without reading the whole Atlas. |
| ATLAS-07 | Section 8 is a separate dependency derivation contract; ATLAS-06 does not define its content. |

---

# 8. Cross-Domain Dependency Derivation & JIT Projection Contract

ATLAS-07 defines how cross-domain dependency planning is derived when an approved Feature Pack becomes active. It is a delivery-navigation contract, not a second Domain or Architecture authority.

## 8.1 Permanence rule

No exhaustive global Domain → Domain dependency graph is permanently maintained.

Most dependency direction can already be derived from the frozen Domain Map, ATLAS-03 CAP authority and support, ATLAS-04 Feature Pack capability materiality, ATLAS-05 active-Feature-Pack Domain derivation, ATLAS-06 lifecycle derivation and Architecture state-authority rules. A permanent full graph would duplicate stronger sources, drift as those sources change and encourage premature interaction design.

Permanent Section 8 content contains only information whose absence would make future JIT dependency planning materially unsafe or expensive. The permanent view records dependency invariants and a small reference-oriented exception register. It does not precompute all Domain → Domain relationships.

Permanent global dependency-graph rows: `0`.

A relationship qualifies for permanent exception visibility when it is stable across multiple approved Feature Packs, or is a single approved high-risk or architecture-sensitive seam whose omission would make future planning unsafe; is difficult to reconstruct from the canonical sources at the point of work; is authority-level rather than implementation-level; and is useful for preventing an ownership, shared-write or circular-authority mistake. A routine relationship that fails this test remains derivable or JIT-only.

## 8.2 Canonical inputs

Section 8 uses these sources and does not create a second dependency authority:

| Source | Dependency use |
|---|---|
| Frozen Domain Map | Durable-truth ownership, allowed direction and circular-authority review. |
| Architecture Law | State authority, cross-boundary mutation, evidence, projection and failure rules. |
| ATLAS-03 | CAP authority scope, authoritative Domain and supporting Domains. |
| ATLAS-04 | Material CAPs for the active Feature Pack. |
| ATLAS-05 | Candidate Domain set and authority-sensitive Domain exceptions. |
| ATLAS-06 | Active lifecycle obligations and lifecycle ownership. |
| Roadmap / Product gates | Conditional or unresolved delivery constraints. |

## 8.3 Authority precedence

The dependency projection may never override durable-truth ownership, state authority, Product policy, Roadmap sequencing or lifecycle ownership.

```text
Product / Architecture / Domain Law
    > CAP authority
    > Feature Pack materiality
    > derived Domain participation
    > derived dependency projection
```

Roadmap sequencing and named Product gates remain upstream constraints alongside this precedence. They can make a dependency conditional and are never overridden by the projection.

The frozen Domain Map controls who owns durable business truth. CAP authority preserves that ownership at capability level. Feature Pack materiality determines what matters now. Domain participation and dependency projections are derived planning views and cannot create a new owner, Domain, lifecycle or shared write.

## 8.4 Conceptual dependency classes

These are the five and only five Section 8 dependency classes. They describe planning relationships, not implementation interfaces. Conditionality is readiness metadata, not a sixth relationship type.

### `AUTHORITATIVE_READ`

One Domain requires current authoritative truth owned by another Domain. The read does not grant mutation authority.

### `OWNER_CONTROLLED_CONSEQUENCE`

One outcome requires a durable consequence in another Domain. The target Domain owns and validates its own mutation. The dependency must not become a direct foreign write.

### `DERIVED_PROJECTION`

A Domain or approved projection exposes derived, rebuildable or read-oriented information based on source-owned truth. The projection never becomes authority.

### `ORCHESTRATION_WITHOUT_OWNERSHIP`

A coordinating Domain or platform capability manages a process that crosses multiple Domain-owned truths without owning those truths. Privacy and consent orchestration are examples at the conceptual level. No concrete workflow mechanism is defined here.

### `EVIDENCE_OBSERVATION`

Audit, Analytics, provider evidence or operational observation records or observes outcomes without becoming business authority.

### Conditionality and readiness

Any of the five relationship classes may be conditional or gated. Record that condition with the existing `Readiness` and `Gate / STOP` fields. For example, an owner-controlled consequence may be recorded as:

```text
OWNER_CONTROLLED_CONSEQUENCE
    + Readiness = GATED
    + Gate = OQ-022
```

Do not turn a named gate into a relationship class. If the relationship itself cannot be identified without resolving the gate, retain its best-supported class and mark the projection `STOPPED` rather than inventing a sixth class.

## 8.5 Runtime interaction boundary

Section 8 must not prescribe Ash actions, direct function calls, HTTP/API calls, commands, domain events, PubSub topics, queues, Oban jobs, GenServers, Redis, tables, schemas, foreign keys, indexes, cache keys, TTLs, retries or provider callback implementation.

This is permitted:

```text
Commerce
    → OWNER_CONTROLLED_CONSEQUENCE
    → Entitlements
```

Any statement that selects a concrete call, API, command, event, message, topic, queue, worker or cross-domain write path is outside the Atlas boundary and belongs to JIT work. The permitted statement records authority direction only.

## 8.6 Active-Feature-Pack derivation path

The deterministic workflow for an active Feature Pack is:

```text
Active Feature Pack
    → ATLAS-04 material CAP relationships
    → ATLAS-03 CAP authority/support
    → ATLAS-05 Domain projection and exceptions
    → ATLAS-06 lifecycle obligations
    → Domain Map + Architecture authority
    → temporary dependency projection
    → Phase 7A Feature Pack Skeleton + preliminary Gate Manifest
    → Phase 7B required JIT Domain Dossiers
    → Phase 7C Final Feature Pack Contract
    → separate post-Phase-7C / pre-Phase-8 architectural proof classification gate
    → Phase 8 executable architectural proof / TB when required and after Development Entry Hard Stops pass
    → VS
    → HH
    → Release / Readiness
```

For each active Feature Pack:

1. Confirm the exact approved `FP-*` outcome and its ATLAS-04 Feature Pack capability row.
2. Collect only the material CAP relationships marked `I`, `R`, `E` or `S` for that Feature Pack.
3. Resolve each material CAP through ATLAS-03. Preserve its authority scope, authoritative Domain, supporting Domains, lifecycle owner and broad pressure.
4. Use ATLAS-05 to identify candidate Domains and relevant authority-sensitive exceptions. Generic participation is a review signal, not proof that every candidate Domain needs a dependency row or JIT Dossier.
5. Use ATLAS-06 for lifecycle-bearing truths. Keep separate owners for separate durable truths and reference the active lifecycle projection rather than creating a synthetic cross-domain state machine.
6. Recheck the relationship against the Domain Map and Architecture authority. Preserve provider-as-evidence, projection-as-non-authority, privacy/audit orchestration and platform-control boundaries.
7. Create one temporary dependency row only when the active Feature Pack materially requires the relationship. Do not create one row for every pair of candidate Domains.
8. Classify the relationship with one of the five Section 8 classes. When an existing gate prevents safe finalisation, set `Readiness = GATED` and record the named `Gate / STOP`; do not create a conditional relationship class. If classifying the relationship requires inventing Product, Domain, lifecycle or implementation semantics, STOP.
9. Optional Grill-Me prompts may inform review during preparation. Create only the Phase 7B JIT Domain Dossiers and later proof work required by the active outcome and its controlling gates.

If any canonical input is missing, contradictory or insufficient to classify the relationship without invention, record the exact source, CAP, Domain and Feature Pack and apply the STOP rules below.

## 8.7 Temporary active-FP dependency projection

The active Feature Pack planner creates a temporary, non-authoritative projection. A dependency row exists only when the active Feature Pack materially requires the relationship.

| Field | Required meaning |
|---|---|
| Feature Pack / CAP | Exact active `FP-*`, relevant `CAP-*` and ATLAS-04 relationship. |
| Source Domain / context | Domain or platform-control context requiring the dependency. This is not automatically the owner of the source truth. |
| Target owner | Domain owning the durable truth involved, or the explicit platform-control boundary where no business Domain owns it. |
| Dependency class | Exactly one of the five Section 8 conceptual classes. Conditionality is recorded separately in `Readiness` and `Gate / STOP`. |
| Business purpose | Why this active Feature Pack materially needs the relationship. |
| Authority direction | Which side owns the relevant truth and mutation authority, including what the source side may not mutate. |
| Lifecycle reference | Relevant ATLAS-06 lifecycle projection or `NONE`. No lifecycle state or transition is invented here. |
| Broad failure consequence | High-level consequence if the dependency is unavailable, stale, duplicated or inconsistent. |
| Pressure flags | Existing broad pressure categories only where materially relevant. |
| Gate / STOP | Existing named gate, escalation or `NONE`. |
| JIT Dossier need | `YES`, `NO` or `CONDITIONAL`, with the reason. |
| Proof need | Whether a materially unproven architectural correctness claim requires proof review. |
| Provenance / source references | Exact current source paths and sections, CAP/decision/requirement/flow references or named gates supporting the row. |
| Authority basis | One permitted Section 2.2 basis: `PRODUCT`, `ARCHITECTURE`, `DOMAIN`, `ROADMAP`, `SUPPORTING`, `ATLAS_DERIVED`, `JIT`, `EVIDENCE` or `STOP`. This identifies the source of the statement, not a new dependency authority. |
| Readiness | One permitted Section 2.2 label: `VISIBLE`, `DEPENDENT`, `GATED`, `JIT_REQUIRED`, `PROVEN` or `STOPPED`. Keep readiness separate from pressure and risk. |

The projection is temporary, active-Feature-Pack-specific and non-authoritative. Rebuild it when relevant Product, Architecture, Domain or Roadmap authority, CAP relationships, gates or ownership evidence change. It must never become the permanent global dependency graph.

## 8.8 Failure consequence boundary

The temporary projection may identify broad failure classes such as:

- unavailable authoritative truth;
- stale decision;
- duplicate consequence;
- owner rejection;
- provider ambiguity;
- delayed consequence;
- partial orchestration;
- projection lag;
- revoked authority;
- unavailable evidence;
- capacity conflict; or
- safety re-evaluation mismatch.

These labels describe delivery impact only. Recovery implementation, retry behaviour and reconciliation mechanics belong to JIT Architecture/Domain work and later executable evidence.

## 8.9 Pressure and performance boundary

The projection may reference these existing broad pressure categories where the active relationship makes them material:

- `CONCURRENCY`;
- `BURST`;
- `DATABASE`;
- `ASYNC`;
- `PROVIDER`;
- `REALTIME`;
- `PROJECTION_FRESHNESS`;
- `EXPORT`; or
- `NONE`.

Pressure does not select a mechanism. Section 8 must not prescribe Redis structures, Cachex, ETS, GenServers, PgBouncer, read replicas, Oban, PubSub, indexes or TTLs. Preserve `authority != acceleration` and the simplest-correct-path-first rule.

## 8.10 Cycle rule

Read composition may form cycles:

```text
A reads B
B reads A
```

That shape is not automatically an authority defect.

An unresolved circular authoritative mutation dependency exists when a directed cycle of Domains exists:

```text
D1 requires D2 to mutate authoritative state
D2 requires D3 to mutate authoritative state
...
Dn requires D1 to mutate authoritative state
```

and no Domain in that cycle can safely establish its own durable consequence independently. The two-Domain case is:

```text
A requires B to mutate authoritative state
AND
B requires A to mutate authoritative state
AND
neither can safely establish its own durable consequence independently
```

This is a global STOP. On detection, report the active Feature Pack, relevant CAPs, every Domain in the cycle (including Domain A and Domain B for the two-Domain case), authoritative truths involved, current source references and the authority level that must resolve the dependency. Do not invent an ordering, event or call pattern to work around it.

## 8.11 Shared-write rule

STOP any dependency shape that implies:

- direct mutation of another Domain's durable truth;
- two Domains owning the same lifecycle state;
- shared write ownership; or
- projection, cache, provider or Analytics/Audit state replacing source authority.

Cross-domain consequences remain owner-controlled. The target owner validates and records its own durable truth through the authority boundary already established upstream.

## 8.12 Cross-domain lifecycle integration

Section 8 does not duplicate ATLAS-06. For a dependency that touches lifecycle-bearing truths, the temporary projection references the relevant ATLAS-06 lifecycle obligation. If separate Domains own separate durable lifecycle truths, the dependency projection preserves those separate owners.

Do not merge separate lifecycles into a synthetic cross-domain state machine. If coordination requires a new orchestration lifecycle, that lifecycle must have a clear authority owner or an explicit platform-control boundary. Otherwise mark the projection `STOPPED` and route it.

## 8.13 Permanent dependency invariant and exception register

The register below is reference-oriented. It keeps only the approved high-value seams and points to ATLAS-05 where an existing exception explains the planning concern. It does not copy ATLAS-05 exception prose, enumerate CAPs or Feature Packs, define runtime interactions or create a second dependency authority.

| Seam | Relevant ATLAS-05 exception | Permanent dependency invariant | Gate if any | Authority anchor |
|---|---|---|---|---|
| Identity grants vs relationship truth | `EX-001` | Identity & Access owns identity-side privilege/grant truth. The relationship-owning Domain retains relationship or assignment truth. | `NONE` | ATLAS-03 `CAP-002`; Domain Map §§4–5 |
| Health → Safety → Plan consequences | `NONE`, standard authority derivation | Health Records owns source health facts. Safety & Eligibility owns safety/eligibility decisions. Plans & Nutrition owns plan truth. No Domain writes another Domain's truth directly. | `OQ-005...OQ-011` where applicable | ATLAS-03 `CAP-013`, `CAP-014`, `CAP-015`; Domain Map §§4–5 |
| Commerce contract vs Entitlements access | `EX-005` | Commerce owns commercial, payment and recurring-contract truth. Entitlements owns access-right truth. | `OQ-004` where provider or recurring semantics apply | ATLAS-03 `CAP-010`, `CAP-011`, `CAP-022`; Domain Map §§4–5 |
| Privacy orchestration vs source records | `EX-003` | Privacy & Consent may coordinate rights requests and policy. Each source Domain retains record truth and owner-controlled fulfilment. | `OQ-009`, `OQ-029...OQ-032` where applicable | ATLAS-03 `CAP-004`; Domain Map §§4–5 |
| Professional Care → Safety / Plans | `EX-006` | Professional Care cannot acquire Health, Safety or Plan authority merely by reviewing or recommending. | `OQ-033` | ATLAS-03 `CAP-023`; Domain Map §6.14 |
| Events capacity vs Commerce payment | `EX-007` | Events & Live owns capacity, reservation and ticket truth. Commerce owns payment and refund truth. | `OQ-022`, `OQ-004` | ATLAS-03 `CAP-025`; Domain Map §6.13 |
| Experimentation / Analytics / source outcomes | `EX-008` | Experimentation owns assignment and learning decisions. Analytics owns measurement evidence. Source Domains retain business outcomes. | `OQ-040` | ATLAS-03 `CAP-026`, `CAP-027`; Domain Map §§6.16–6.17 |

Permanent seam register rows: `7`. The cycle STOP, shared-write STOP, provider-evidence rule and cross-cutting evidence rules are permanent invariants and are not counted as additional seam rows.

## 8.14 Provider evidence rule

External provider state is evidence, not business authority. The relevant platform Domain owns reconciliation and durable truth. If provider ambiguity materially affects an active dependency, record it in the temporary projection's failure consequence, gate and proof need. Do not create a permanent provider dependency owner or prescribe callback, retry or reconciliation implementation.

## 8.15 Audit and Analytics rule

Audit & Evidence and Analytics may observe or retain evidence according to their authority. They do not gain authority over source-Domain business truth. Do not create permanent rows for every source → Analytics or source → Audit relationship. Derive those relationships only when the active Feature Pack materially requires them.

## 8.16 Selective context contract

A fresh active-Feature-Pack planner should need only:

1. the active Feature Pack row from ATLAS-04;
2. relevant CAP entries from ATLAS-03;
3. relevant ATLAS-05 Domain projection and exceptions;
4. relevant ATLAS-06 lifecycle projections;
5. these Section 8 dependency rules; and
6. the exact Domain Map, Architecture, Product or Roadmap references required by those relationships.

The planner should not need to read the entire Atlas or reconstruct a global dependency graph. This selective context keeps the dependency review bounded while retaining the authority-sensitive seams that are unsafe to rediscover informally.

## 8.17 JIT Domain Dossier rule

A dependency does not automatically require a JIT Domain Dossier. A Dossier is required when the active Feature Pack needs implementation-grade semantics that are not already frozen, including owner-controlled consequence semantics, lifecycle effects, failure/reconciliation behaviour or sensitive cross-domain access.

If existing authority and current implementation already make the relationship clear, reuse that evidence. Do not create a ceremonial Dossier. If the relationship cannot be specified without resolving higher-level uncertainty, mark it `STOPPED` and route it.

## 8.18 Proof and Tracer Bullet rule

A dependency may set `Proof need` when a material architectural correctness claim remains unproven. Examples include concurrency across separately owned truths, provider ambiguity, cross-domain recovery, duplicate business consequences, scarce-capacity/payment races or stale safety decisions.

Proof need does not create a Tracer Bullet. Phase 7C freezes the proof requirement and applicable obligations; the separate post-7C, pre-Phase-8 classification gate selects `REUSE_EXISTING_PROOF` or `NEW_TRACER_BULLET`. No ceremonial TB is created by Section 8.

## 8.19 Existing gates and conditional seams

Section 8 does not resolve existing gates. Preserve, where relevant:

- `OQ-033` for professional-record authority;
- `OQ-022` for event reservation architecture;
- `OQ-004` for provider payment and recurring semantics;
- `OQ-040` for the experimentation boundary;
- clinical and calculation decisions; and
- future Product direction gates.

Use one of the five relationship classes together with `Readiness = GATED` or `STOPPED` and the existing `Gate / STOP` field according to the current evidence. Do not invent a resolution or a sixth class. FP-017 remains conditional until a separately approved Product direction names its affected owners.

## 8.20 Permanence principle

If a view can be deterministically reconstructed from stronger canonical views, do not permanently duplicate it unless permanent representation materially improves decision-making.

Dependency invariants and exceptional authority-sensitive seams pass this test. The complete dependency graph does not.

## 8.21 ATLAS-07 closure audit

| Audit | Result |
|---|---|
| Permanent global dependency-graph rows | `0` |
| Section 8 population placeholder | None remains |
| Conceptual dependency classes | Exactly `5`: `AUTHORITATIVE_READ`, `OWNER_CONTROLLED_CONSEQUENCE`, `DERIVED_PROJECTION`, `ORCHESTRATION_WITHOUT_OWNERSHIP`, `EVIDENCE_OBSERVATION`; conditionality is separate readiness metadata |
| Permanent seam register | `7` small reference-oriented rows; no routine Domain-pair enumeration |
| ATLAS-05 exception handling | Existing exception IDs are referenced; their explanations are not duplicated |
| Ownership safety | No shared authoritative writes or ownership transfers introduced |
| Cycle safety | Circular authoritative mutation is a global STOP; read cycles remain allowed |
| Provider/evidence authority | Provider, projection, Analytics and Audit state cannot become hidden business authority |
| Lifecycle integration | ATLAS-06 is referenced; no synthetic cross-domain state machine is created |
| Runtime boundary | No calls, events, messages, topics, queues, Resources, schemas, modules or mechanisms are defined |
| Current hard STOP | None identified in the approved ATLAS-07 scope; the documented STOP rules remain active for future projections |
| CAP/FP relationships | ATLAS-03 remains unchanged; ATLAS-04 uses the corrected permanent matrix and deferred-introduction rule |
| Selective derivation | Active-FP dependency rows are created only for material relationships from the canonical derivation path |
| Next Atlas section | ATLAS-08 and participant-journey work were not started |

ATLAS-07 remains a derived, working, non-authoritative and unfrozen planning contract. It does not prepare FP-001, create JIT Domain Dossiers, TBs, VSs, HHs or TOONs, or authorize implementation.

---

# 9. Participant Journey Boundaries & JIT Projection Contract

## 9.1 Purpose and permanence rule

This section helps an active Feature Pack planner answer:

> What participant-facing boundary or outcome is materially crossed by this Feature Pack, and what existing safety, privacy, identity, access, entitlement or recovery invariant must remain true?

It does not answer:

> What exact pages, screens, forms, navigation steps or interaction sequence will the participant use?

No exhaustive global participant journey map is permanently maintained. Most journey sequencing and outcomes are already represented by Product Law, the Roadmap, ATLAS-02, ATLAS-03, ATLAS-04, ATLAS-05, ATLAS-06, ATLAS-07 and the `FRONTEND_EXPERIENCE_SYSTEM`. Permanent Section 9 content exists only where a participant-centric boundary materially improves future decision safety and would otherwise require repeated cross-source reconstruction.

The Atlas permanence principle applies:

> If a view can be deterministically reconstructed from stronger canonical views, do not permanently duplicate it unless permanent representation materially improves decision-making.

The permanent register below is therefore a small reference-oriented index of authority-sensitive participant boundaries. It is derived planning material, not a new journey authority.

## 9.2 Journey boundaries

### Participant journey != Product Roadmap

Section 9 does not restate the 17 Feature Packs as a second sequence. The Roadmap remains authoritative for Feature Pack outcomes, prerequisites, sequencing, gates and release effects.

### Participant journey != Domain lifecycle

Lifecycle-bearing truths remain governed by ATLAS-06 and the relevant JIT Domain Dossier. Section 9 does not create participant-facing lifecycle states or merge separate Domain lifecycles into one journey state machine.

### Participant journey != cross-domain dependency graph

Section 9 references ATLAS-07 where a participant outcome depends on multiple Domain-owned truths. It does not recreate dependency rows, transfer ownership or introduce shared authoritative writes.

### Participant journey != frontend flow

The `FRONTEND_EXPERIENCE_SYSTEM` and later JIT frontend work own routes, pages, screens, forms, buttons, navigation, loaders, redirects, interaction sequencing, exact copy and component hierarchy. Section 9 records only medium-resolution participant outcomes and boundaries.

No performance implementation belongs in Section 9. It must not prescribe caching, CDN behaviour, Redis, browser storage, queues, PubSub, realtime mechanisms, indexes, APIs or prefetching.

## 9.3 Canonical inputs and authority precedence

| Source | Participant-journey use |
|---|---|
| Product Law | `docs/governance/product/PROJECT_NORTH_STAR_AND_MVP_v1.3.0.md`; `docs/history/platform/archive/00_PLATFORM_v1.9.0.md`; `docs/history/platform/archive/01_DECISIONS_v1.9.0.md` | Defines product purpose, approved outcomes, policy, MVP boundaries, non-negotiables and formal gates. |
| Roadmap | `docs/history/platform/archive/05_ROADMAP_v1.2.4.md` | Defines approved delivery phases, Feature Pack outcomes, dependencies, gates and sequencing (17 Feature Packs). |
| ATLAS-03 / ATLAS-04 | Relevant capability identity and active-Feature-Pack materiality. |
| ATLAS-05 | Participating Domains and ownership-sensitive exceptions. |
| ATLAS-06 | Lifecycle obligations and JIT lifecycle requirements. |
| ATLAS-07 | Cross-domain dependency direction and exceptional seams. |
| `FRONTEND_EXPERIENCE_SYSTEM` | Downstream experience, accessibility, bilingual and interaction constraints. |

The precedence is:

```text
Product Law
    > Architecture / Domain Law where relevant
    > Roadmap
    > canonical capability and Atlas derivations
    > temporary participant journey projection
```

The canonical downstream path from that temporary projection is:

```text
temporary participant journey projection
    → Phase 7A Feature Pack Skeleton + preliminary Gate Manifest
    → Phase 7B required JIT Domain Dossiers
    → Phase 7C Final Feature Pack Contract
    → separate post-Phase-7C / pre-Phase-8 architectural proof classification gate
    → Phase 8 executable architectural proof / TB when required and after Development Entry Hard Stops pass
    → VS
    → HH
    → Release / Readiness
```

A participant journey projection cannot create a new Product promise, entitlement, safety outcome, professional-care right, lifecycle state, Feature Pack or frontend requirement not supported upstream.

## 9.4 Permanent participant boundary register

The register keeps only boundaries whose omission could make future participant planning unsafe or repeatedly expensive. The labels below are conceptual planning categories, not lifecycle states or an approved participant vocabulary. No row exists merely because a Feature Pack exists.

| Boundary / invariant | Authority anchors | Relevant CAP / FP references | Prerequisite | Safety / privacy / access constraint | Recovery / exit seam | Approved later seam | JIT boundary |
|---|---|---|---|---|---|---|---|
| Public discovery → protected identity/access | Product Law §§8, 12, 15; Platform §§7.3, 21J; Roadmap §6 FP-001 | CAP-001, CAP-002, CAP-005 / FP-001 | Approved public entry and current account/verification boundary. | Protected participant access must not bypass identity, age, terms/privacy or current authorisation. | Account recovery and access revocation remain Identity & Access concerns; no protected access is inferred from presentation state. | Every later protected Feature Pack reuses the same identity/access boundary. | Exact authentication, recovery, field and frontend interaction semantics remain JIT. |
| Purchase/access acquisition → entitled delivery | Product Law §§11–12; Platform §§21A, 21L.4–21L.7; Roadmap §§3.2, 6 FP-002 | CAP-009, CAP-010, CAP-011 / FP-002 and later applicable entitlement-bearing packs | Approved offer or access source plus authoritative commercial reconciliation. | Commerce/payment truth and Entitlements/access truth remain distinct; provider or client-visible success is not entitlement authority; purchaser and participant remain distinct. | Pending, failed, revoked or expired access is handled through existing authority; no access recovery is invented here. | Membership, programme, live, event and future product access reuse the explicit entitlement boundary. | Provider, recurring, refund, grant, redemption and entitlement mechanics remain JIT/gated. |
| Safety/eligibility → governed personalised outcome | Product Law §§8–9, 12, 15; Platform §§12, 21C, 21D; Roadmap §§5–6 FP-004/FP-005 | CAP-013, CAP-014, CAP-015 / FP-004 and FP-005 | Required progressive health information and a current approved safety/eligibility decision. | Personalised guidance must not bypass Safety & Eligibility; no clinical thresholds, methodology or fallback rule is invented. | Safety re-evaluation, restriction, professional referral, correction and withdrawal remain owner-controlled and lifecycle-referenced through ATLAS-06. | The same safety boundary is reused by Nuwe Jy, adjustment, practitioner and later approved health outcomes. | Clinical rules, calculations, wording, re-evaluation and plan-generation semantics remain JIT/gated. |
| Delivery → progress / feedback / recovery | Product Law §§5.4, 8–9; Platform §§21F, 21H; Roadmap §§3.1, 6 FP-005/FP-008/FP-014 | CAP-018, CAP-019, CAP-020 / FP-005, FP-008 and FP-014 | An authorised delivered outcome and the relevant participant context. | Progress and feedback do not become clinical, journal or completion authority by implication; missed time must not silently fabricate failure or erase progress. | Interruption, pause, catch-up, resume, recovery and exit remain broad participant consequences; lifecycle detail references ATLAS-06. | Programme, habit, reflective-progress and long-term maintenance experiences may reuse the boundary when separately approved. | Exact progress, completion, journal, reminder and participant-facing interaction semantics remain JIT. |
| One-off → recurring / programme relationship | Product Law §§5.4, 18–19; Platform §§21A, 21F, 21H, 21L.8–21L.9; Roadmap §6 FP-008–FP-011/FP-014 | CAP-016, CAP-018, CAP-022 / FP-008–FP-011 and FP-014 | An approved recurring product, programme or participation entitlement and its applicable release gate. | Recurring commercial contract, access rights, programme enrolment and participation remain distinct; no renewal or membership promise is invented. | Cancellation, expiry, pause, restart and re-entry follow the applicable upstream contract; no automatic continuation is implied. | Basic, Premium, Nuwe Jy and later approved programme relationships reuse existing commercial, entitlement and programme authority. | Exact renewal, adjustment, pacing, enrolment and recovery semantics remain JIT/gated. |
| Self-service → professional review | Product Law §§5.2, 5.6, 8, 15; Platform §§12.3, 16, 21L.10; Roadmap §6 FP-012 | CAP-014, CAP-015, CAP-023 / FP-012 | An approved professional-review path, explicit consent and applicable active scoped relationship. | Professional Care does not acquire Health, Safety or Plan ownership; access remains scoped, expiring, auditable and capacity-controlled. `OQ-033` remains unresolved where professional-record authority is required. | Referral, restriction, non-acceptance, review completion or withdrawal are broad seams only; no professional lifecycle is invented. | Only the controlled practitioner-review pilot and later approved professional service use this boundary. | Exact case, record, access, disposition and communication semantics remain JIT/gated. |
| Correction / withdrawal / revocation / deletion / re-entry | Product Law §§8, 12, 19A; Platform §§21I, 21J; Roadmap §§6 FP-006 and 18 | CAP-003, CAP-004, CAP-028, CAP-030 / FP-006 and later affected packs | Current authority, applicable consent/rights decision and the relevant owner-controlled record boundary. | Consent, access revocation, correction, account closure and full deletion remain distinct; re-entry must not resurrect data that current deletion authority makes unavailable. | Recovery may include retry, re-entry, closure recovery or a safe exit, but never an invented restore path or storage mechanism. | Affected current and future products inherit the same privacy, retention, deletion and release-control boundaries. | Category-specific retention, deletion, export, restore, invalidation and operational mechanics remain JIT/gated. |

Permanent participant boundary rows: `7`.

Global participant journey-map rows: `0`.

## 9.5 Active-Feature-Pack derivation path

The deterministic path for an active Feature Pack is:

```text
Active Feature Pack
    → approved Product / Roadmap outcome
    → ATLAS-04 material CAPs
    → ATLAS-05 Domain participation
    → ATLAS-06 lifecycle obligations
    → ATLAS-07 dependency seams
    → applicable permanent participant boundaries
    → temporary active-FP participant journey projection
    → Phase 7A Feature Pack Skeleton + preliminary Gate Manifest
    → Phase 7B required JIT Domain Dossiers
    → Phase 7C Final Feature Pack Contract
    → separate post-Phase-7C / pre-Phase-8 architectural proof classification gate
    → Phase 8 executable architectural proof / TB when required and after Development Entry Hard Stops pass
    → VS
    → HH
    → Release / Readiness
```

Do not build a whole-platform participant journey before selecting the active Feature Pack. The planner should:

1. confirm the exact approved Feature Pack outcome;
2. retrieve its ATLAS-04 material CAP row;
3. resolve relevant ownership, lifecycle and dependency references through ATLAS-05, ATLAS-06 and ATLAS-07;
4. select only the permanent participant boundary rows materially crossed by that outcome;
5. create the temporary projection in §9.6;
6. optionally use the Feature Pack Grill-Me prompts; the approved outcome and source-owned gates determine required work; and
7. create only the JIT frontend or Domain planning artifacts genuinely required by the approved outcome.

## 9.6 Temporary active-FP participant journey projection

The active Feature Pack planner creates a temporary, non-authoritative projection. It is rebuilt when the Feature Pack, upstream authority, CAP materiality, ownership evidence or applicable gate changes.

| Field | Required meaning |
|---|---|
| Active Feature Pack / approved outcome | Exact `FP-*` and approved Roadmap outcome. |
| Participant outcome / milestone | Medium-resolution participant-visible result; not a screen or interaction sequence. |
| Entry condition / prerequisite | What must already be true before the outcome can be pursued. |
| Relevant CAPs | Material ATLAS-04 capability references. |
| Domain references | Relevant ATLAS-05 ownership and participation references. |
| Lifecycle references | Relevant ATLAS-06 projection or `NONE`; no lifecycle states are invented. |
| Dependency references | Relevant ATLAS-07 seam or `NONE`; no dependency rows are recreated. |
| Safety / privacy / access boundary | Existing authority and named gate only. |
| Failure / recovery / exit consequence | Broad participant consequence, without retry, redirect, restore or provider mechanics. |
| Approved later progression | Existing downstream Product or Roadmap seam only. |
| Frontend/JIT work | `YES`, `NO` or `CONDITIONAL`; `YES` does not authorise implementation. |
| Gate / STOP | Named existing gate or `NONE`. |
| Provenance | Exact current source paths, sections, IDs and gate references. |

The projection does not become a new Roadmap or Product authority. It does not create a Domain Dossier, frontend contract, TB or VS automatically. Optional Grill-Me prompts may help identify a need; the approved outcome and controlling contracts determine what is required.

## 9.7 Frontend/JIT rule

`Frontend/JIT work = YES` means only:

> This active participant outcome requires later implementation-grade experience specification.

Later frontend JIT work may define screens, routes, components, forms, navigation, redirects, exact validation UX, loading/error states and interaction choreography. Section 9 must not.

## 9.8 Safety, privacy, access and recovery rules

Section 9 preserves existing authority and gates. It may keep visible that:

- eligibility precedes personalised guidance;
- a blocked or uncertain safety outcome follows an approved fallback or professional route where Product Law permits;
- identity, payment, entitlement, programme membership and professional relationship remain distinct;
- consent and professional access remain scoped, expiring and auditable;
- correction, withdrawal, revocation, deletion and account closure remain distinct; and
- recovery or re-entry cannot resurrect deleted or invalidated data.

Section 9 must not create clinical thresholds, contraindications, calculation logic, renewal mechanics, professional policy, retention durations, deletion mechanisms or provider behaviour. Existing gates such as `OQ-033`, `OQ-022`, `OQ-004`, `OQ-005`, `OQ-008`, `OQ-010`, `OQ-011`, `OQ-019`, `OQ-025`, `OQ-009` and `OQ-029` through `OQ-032` remain at their existing authority level where materially relevant. Conditional `FP-017` remains conditional and is not given an inferred participant journey.

## 9.9 Selective context and JIT boundary

A fresh active-Feature-Pack planner should need only:

1. Product and Roadmap material for the active outcome;
2. the active ATLAS-04 CAP row;
3. relevant ATLAS-05 Domain references;
4. relevant ATLAS-06 lifecycle projections;
5. relevant ATLAS-07 dependency seams;
6. applicable Section 9 participant-boundary rows; and
7. the exact `FRONTEND_EXPERIENCE_SYSTEM` sections required for later planning.

The planner should not need a whole-platform participant journey map. A participant boundary does not automatically require a Domain Dossier, frontend contract, TB or VS. Atlas prompts may help route questions, while the approved outcome and controlling contracts determine required work.

---

# 10. Staff / Operator JIT Derivation Contract

## 10.1 Purpose and permanence rule

This section helps an active Feature Pack planner answer:

> Which approved actor requires attention, decision or action for this Feature Pack, which Domain owns the underlying truth, and which existing Operating Model rule governs the human workflow?

It does not define the complete mature staff workflow, queue, dashboard, screen or permission model.

No permanent Staff × Feature Pack journey map or actor/work register is maintained. Stable operator doctrine is already frozen in `docs/history/platform/archive/PLATFORM_OPERATING_MODEL_v1.0.1.md`, and frontend operator doctrine is already frozen in `docs/governance/supporting/FRONTEND_EXPERIENCE_SYSTEM_v1.0.1.md`. Permanent operator rows would duplicate stronger authority, increase drift and encourage premature workflow, permission or UI design.

The permanence rule is:

> If a view can be deterministically reconstructed from stronger canonical views, do not permanently duplicate it unless permanent representation materially improves decision-making.

Permanent actor/work rows: `0`.

## 10.2 Authority sources and precedence

Section 10 creates no operator authority. It routes active-Feature-Pack planning through the existing authority chain:

| Source | Operator-planning use |
|---|---|
| Product Law | `docs/governance/product/PROJECT_NORTH_STAR_AND_MVP_v1.3.0.md`; `docs/history/platform/archive/00_PLATFORM_v1.9.0.md`; `docs/history/platform/archive/01_DECISIONS_v1.9.0.md` | Defines product purpose, approved outcomes, policy, MVP boundaries, non-negotiables and formal gates. |
| Architecture Law | State authority, durable execution, provider/evidence and projection boundaries. |
| Domain Law | Durable-truth ownership and cross-domain mutation rules. |
| Roadmap | `docs/history/platform/archive/05_ROADMAP_v1.2.4.md` | Defines approved delivery phases, Feature Pack outcomes, dependencies, gates and sequencing (17 Feature Packs). |
| Platform Operating Model | Stable human and workflow doctrine. |
| Frontend Experience System | Operator interaction and experience doctrine. |
| ATLAS-04 | Material capabilities for the active Feature Pack. |
| ATLAS-05 | Participating Domains and ownership-sensitive exceptions. |
| ATLAS-06 | Lifecycle obligations and lifecycle ownership references. |
| ATLAS-07 | Cross-domain dependency seams and authority direction. |
| ATLAS-08 | Participant boundary where operator work protects a participant outcome. |

The precedence is:

```text
Product Law
    → Architecture Law
    → Domain Law
    → Roadmap
    → Platform Operating Model
    → Frontend Experience System
    → Atlas derivation
    → temporary active-FP operator projection
```

The canonical downstream path from that temporary projection is:

```text
temporary active-FP operator projection
    → Phase 7A Feature Pack Skeleton + preliminary Gate Manifest
    → Phase 7B required JIT Domain Dossiers
    → Phase 7C Final Feature Pack Contract
    → separate post-Phase-7C / pre-Phase-8 architectural proof classification gate
    → Phase 8 executable architectural proof / TB when required and after Development Entry Hard Stops pass
    → VS
    → HH
    → Release / Readiness
```

The temporary projection cannot override any stronger source. If a stronger source is contradictory, incomplete or requires a new policy, Section 10 records the escalation and does not guess.

## 10.3 Operating Model reference boundary

Section 10 references rather than reproduces the frozen Platform Operating Model. A future active Feature Pack loads only the exact relevant sections, including as applicable:

- staff roles and operator organisation;
- Command Centre and operator information architecture;
- Work presentation and guards;
- Work, Notification and Toast distinction;
- notes, timelines and support context;
- content, review, translation and publication operations;
- analytics and dashboard governance;
- scheduling and periodic operations;
- mobile operating requirements;
- performance and JIT handoff rules; and
- operating-model STOP conditions.

The Frontend Experience System remains the source for operator experience, interaction, dashboard presentation and frontend JIT boundaries. Section 10 does not copy its operator doctrine or define routes, screens, tables, cards, filters, navigation or components.

## 10.4 Role is not authority

Preserve:

```text
role
≠ relationship
≠ purpose
≠ scope
≠ business authority
```

The operator projection must never infer durable business authority from a role name. In particular:

- Support does not gain Health authority;
- Finance does not gain Entitlement ownership;
- Moderator does not gain unrestricted Community authority;
- Data Analyst does not gain source-data mutation rights;
- Developer/Platform does not gain unrelated participant access;
- Super Admin is not a universal business-policy bypass; and
- Practitioner authority remains scoped by approved relationship, consent and professional rules.

No permanent role-permission matrix is created. Exact policy, relationship, purpose, scope, consent, separation-of-duty and action guards remain with the relevant Product, Domain, Operating Model or JIT authority.

## 10.5 Work is attention, not authority

The frozen Platform Operating Model rule remains:

> Work is attention, not authority.

A queue or work item exposes a Domain-owned obligation or decision to an authorised actor. It does not create the underlying business truth, a second business-write API or a new operator-owned lifecycle. Queue visibility must not imply action permission. Resolving a Work projection requires the owning Domain's outcome and guard to succeed.

Do not create a `Task`, `Work`, `Assignment`, `Review` or `Admin` Domain. Do not reproduce the Operating Model's common presentation states as an Atlas lifecycle. Domain-specific lifecycles remain governed by ATLAS-06 and the relevant JIT Domain Dossier.

## 10.6 Operator surfaces are projections

The following remain projections or operating surfaces over existing authority:

```text
Command Centre
queue
dashboard
timeline
analytics view
saved view
notification
```

They do not own underlying business facts. Dashboards, work queues, timelines, analytics and audit views must not acquire hidden write authority.

Preserve the existing distinction:

- Work = action required;
- Notification = useful information; and
- Toast = transient acknowledgement.

Required work must never exist only in ephemeral frontend state. Section 10 does not duplicate channel, notification or dashboard implementation design.

## 10.7 Active-Feature-Pack derivation path

The deterministic derivation path is:

```text
Active Feature Pack
    → approved Roadmap operating outcome
    → ATLAS-04 material CAPs
    → ATLAS-05 participating Domains
    → ATLAS-06 lifecycle obligations
    → ATLAS-07 dependency seams
    → ATLAS-08 participant boundary where applicable
    → relevant Platform Operating Model rules
    → relevant Frontend Experience System rules
    → temporary active-FP operator projection
    → Phase 7A Feature Pack Skeleton + preliminary Gate Manifest
    → Phase 7B required JIT Domain Dossiers
    → Phase 7C Final Feature Pack Contract
    → separate post-Phase-7C / pre-Phase-8 architectural proof classification gate
    → Phase 8 executable architectural proof / TB when required and after Development Entry Hard Stops pass
    → VS
    → HH
    → Release / Readiness
```

Do not derive whole-platform operator workflow before selecting the active Feature Pack. Operator work enters only when the approved outcome requires it. FP-006 is the first major controlled core-operations and release boundary; it is not permission to pre-design every later practitioner, event, moderation, experimentation or future-market workflow.

## 10.8 Temporary active-FP operator projection

For an active Feature Pack, create a temporary, active-FP-specific, non-authoritative projection. It is rebuilt when relevant authority, CAP materiality, ownership evidence or gates change.

| Field | Required meaning |
|---|---|
| Active Feature Pack / operating outcome | Exact `FP-*` and approved Roadmap outcome. |
| Actor / scoped relationship | Existing approved role or relationship; never invent a role. |
| Required attention / decision / action class | Medium-resolution operator need. |
| Owning Domain / platform-control authority | Owner of the underlying truth or legitimate platform-control boundary. |
| Relevant CAPs | Material ATLAS-04 CAP references. |
| Domain references | Relevant ATLAS-05 participation and ownership references. |
| Lifecycle references | Relevant ATLAS-06 projection or `NONE`. |
| Dependency references | Relevant ATLAS-07 seam or `NONE`. |
| Participant boundary | Relevant ATLAS-08 boundary or `NONE`. |
| Operating Model anchor | Exact frozen Operating Model section or rule. |
| Current authority guard | Existing role, relationship, purpose and scope requirement. |
| Exception / escalation seam | Broad existing escalation, gate or authority route. |
| Evidence / audit requirement | Existing evidence obligation only. |
| Frontend / JIT need | `YES`, `NO` or `CONDITIONAL`. |
| Gate / STOP | Existing OQ, gate or `NONE`. |
| Provenance | Exact current source paths, sections and identifiers. |

The projection is task-shaped, not database-shaped. It answers who needs to act or decide, what needs attention, why, who owns the truth, what authority permits the actor, what happens if work cannot proceed, what evidence matters and what JIT work remains.

It must not define database tables, schemas, Resources, actions, queue names, routes, page names, components, exact filters, worker names, PubSub topics or Redis structures.

## 10.9 Review, approval and escalation boundary

Section 10 may identify that an active Feature Pack needs review, approval, assignment, changes requested, escalation or exception handling. It must not invent an approval hierarchy, reviewer role, self-approval rule, separation-of-duty matrix, SLA, escalation timer or retry schedule.

Use existing Product, Domain, Operating Model and named OQ authority. An operator need does not automatically create a JIT Domain Dossier, workflow contract, frontend contract, Tracer Bullet, Vertical Slice or Horizontal Hardening task. Optional review prompts may help identify candidates; the approved outcome and source-owned gates determine required artifacts.

## 10.10 Evidence, scheduling and analytics boundary

Evidence does not become business authority. Audit & Evidence may retain proof of operator action, decision, approval, escalation, assignment, incident, release or correction while the owning Domain retains the business outcome. No permanent evidence catalogue is created here.

When an active Feature Pack has business-significant scheduling, reference the frozen requirement for durable execution and current-authority revalidation. Do not prescribe worker names, queue names, cron expressions, retry counts, Redis, GenServers or PubSub.

Do not create a dashboard catalogue, KPI register, universal reporting model or dashboard builder. Dashboard visibility does not imply source-data mutation, drill-down permission or export permission.

## 10.11 Selective context contract

A fresh active-Feature-Pack planner should need only:

1. the exact Roadmap Feature Pack entry;
2. the active ATLAS-04 CAP row;
3. relevant ATLAS-05 Domain references;
4. the relevant ATLAS-06 lifecycle projection;
5. relevant ATLAS-07 dependency seams;
6. the relevant ATLAS-08 participant boundary;
7. exact relevant Platform Operating Model sections;
8. exact relevant Frontend Experience System sections; and
9. applicable gates and OQs.

It should not need a permanent whole-platform staff journey table. A temporary projection is rebuilt when its upstream inputs change.

## 10.12 Existing gates and STOP conditions

Preserve named gates only where materially relevant, including as applicable:

- `OQ-004`;
- `OQ-009`;
- `OQ-016`;
- `OQ-020`;
- `OQ-021`;
- `OQ-022`;
- `OQ-023`;
- `OQ-029` through `OQ-033`; and
- `OQ-035` through `OQ-040`.

Do not create an Open Work duplicate or resolve these gates in Section 10.

STOP if a new role, role-based authority, universal Task/Work/Admin Domain, universal business Work lifecycle, hidden projection authority, direct foreign write, invented permission or professional/clinical/legal/accounting/provider rule is required. Also STOP if exact frontend design, a frozen Operating Model modification, an unresolved OQ resolution or an Atlas-level assumption is needed.

On STOP report the actor, active Feature Pack, relevant CAP, Domain, work or decision, conflicting source, deciding authority and minimum safe resolution. Do not guess.

---

# 11. Frontend JIT Derivation Contract

## 11.1 Purpose and permanence rule

This section helps an active Feature Pack planner answer:

> What participant, public or operator experience must represent this approved outcome, which frozen frontend rules apply, and does the active Feature Pack require new JIT frontend design or only reuse of existing patterns?

It does not answer:

> What exact route, page, LiveView, component or file implements the experience?

No permanent Frontend Surface × Feature Pack progression map or frontend surface register is maintained. The Roadmap already owns outcome sequencing, ATLAS-04 owns capability introduction/reuse/extension, ATLAS-08 owns participant-boundary derivation, ATLAS-09 owns operator-work derivation and the frozen `FRONTEND_EXPERIENCE_SYSTEM_v1.0.1.md` owns stable frontend doctrine. Permanent surface rows would duplicate stronger sources, increase drift and encourage premature information architecture, routes, pages and components.

The Atlas permanence rule remains:

> If a view can be deterministically reconstructed from stronger canonical views, do not permanently duplicate it unless permanent representation materially improves decision-making.

Permanent frontend surface rows: `0`.

## 11.2 Authority sources and precedence

Section 11 creates no new frontend authority. It derives only the minimum temporary context required by an active Feature Pack.

| Source | Frontend-planning use |
|---|---|
| Product Law | `docs/governance/product/PROJECT_NORTH_STAR_AND_MVP_v1.3.0.md`; `docs/history/platform/archive/00_PLATFORM_v1.9.0.md`; `docs/history/platform/archive/01_DECISIONS_v1.9.0.md` | Defines product purpose, approved outcomes, policy, MVP boundaries, non-negotiables and formal gates. |
| Architecture Law | Authoritative interaction, projection, failure/degradation and runtime boundaries. |
| Domain Law | Durable-truth ownership and policy-sensitive relationships. |
| Roadmap | `docs/history/platform/archive/05_ROADMAP_v1.2.4.md` | Defines approved delivery phases, Feature Pack outcomes, dependencies, gates and sequencing (17 Feature Packs). |
| Platform Operating Model | Stable operator and human workflow doctrine. |
| Frontend Experience System | Stable frontend, interaction, accessibility, responsive, design-system, SEO and measurement doctrine. |
| ATLAS-04 | Material capabilities for the active Feature Pack. |
| ATLAS-05 | Participating Domains and ownership-sensitive exceptions. |
| ATLAS-06 | Lifecycle obligations reflected by the frontend. |
| ATLAS-07 | Cross-domain dependency seams. |
| ATLAS-08 | Participant-facing boundary where applicable. |
| ATLAS-09 | Operator-work projection where applicable. |

The precedence is:

```text
Product Law
    → Architecture Law
    → Domain Law
    → Roadmap
    → Platform Operating Model
    → Frontend Experience System
    → Atlas derivation
    → temporary active-FP frontend projection
```

The canonical downstream path from that temporary projection is:

```text
temporary active-FP frontend projection
    → Phase 7A Feature Pack Skeleton + preliminary Gate Manifest
    → Phase 7B required JIT Domain Dossiers
    → Phase 7C Final Feature Pack Contract
    → separate post-Phase-7C / pre-Phase-8 architectural proof classification gate
    → Phase 8 executable architectural proof / TB when required and after Development Entry Hard Stops pass
    → VS
    → HH
    → Release / Readiness
```

If stronger authority conflicts or is incomplete, Section 11 records the conflict and routes it to the correct authority. It does not repair or resolve the conflict locally.

## 11.3 Frontend Experience System reference boundary

Section 11 references rather than reproduces the frozen `FRONTEND_EXPERIENCE_SYSTEM_v1.0.1.md`. A future active Feature Pack loads only the exact relevant sections, including where applicable:

- public, participant and operator experience;
- frontend authority and presentation-state doctrine;
- participant onboarding, purchase, recovery and plan/report delivery;
- operator Work doctrine;
- content, editorial and media experience;
- token/design-system architecture and forms;
- responsive and accessibility rules;
- frontend presentation states;
- dashboards and analytics UI;
- SEO and public publishing;
- integrations, embeds and observability;
- the JIT frontend performance pass; and
- deferred-detail and STOP boundaries.

The Atlas does not formalise a second permanent frontend vocabulary. The active projection references the exact applicable FES surface or experience section rather than renaming the frozen concepts into a new Atlas enum.

## 11.4 Presentation is not authority

Preserve:

```text
presentation != business authority
```

Frontend state, route state, LiveView assigns, browser state, dashboards, queues and optimistic interactions must not create or replace Domain truth. The frontend represents current authoritative outcomes; it does not own identity, payment, entitlement, eligibility, safety, plans, professional outcomes, publication or accounting truth.

## 11.5 Frontend surface is not implementation structure

Preserve:

```text
frontend experience / surface
    != route
    != page
    != LiveView
    != component
    != file
```

Section 11 may identify a medium-resolution visible experience outcome. It must not define URL paths, routes, endpoints, page names as implementation law, Phoenix modules, LiveViews, layouts, component files, CSS files, folder structure or API contracts. These remain JIT.

## 11.6 Frontend surface is not a Domain

A composed frontend experience may represent several Domain-owned truths but never becomes an owner. Participant Home does not own Plans, Programmes or Entitlements; checkout does not own Commerce; Work does not own Domain obligations; a dashboard does not own Analytics or source facts; account/settings does not create an Account Domain; and authoring UI does not own Content publication truth.

No new Domain may be introduced because a surface exists.

## 11.7 Frontend state is not business lifecycle

The frozen FES already defines presentation state machines where appropriate. Section 11 does not reproduce form presentation states, asynchronous interaction states, dashboard trust/freshness states or loading/error/degraded states as new Atlas state machines.

An active projection may reference the exact FES presentation-state rule when the active Feature Pack materially exercises it. Business lifecycles remain owned by Domains and ATLAS-06/JIT Domain Dossiers.

## 11.8 Shared experience rule

NewYou has one evolving participant Home/Today experience composing the next authorised action. Section 11 must not create permanent Assessment Home, Plan Home, Membership Home, Programme Home or Event Home concepts merely because separate Feature Packs contribute to those outcomes.

A Feature Pack may extend or reuse an existing experience without creating a new top-level surface. Operator capabilities feed the existing Command Centre and Work doctrine rather than creating a new administration application per Feature Pack.

## 11.9 Active-Feature-Pack derivation path

The deterministic derivation path is:

```text
Active Feature Pack
    → approved Roadmap outcome
    → ATLAS-04 material CAPs
    → ATLAS-05 participating Domains
    → ATLAS-06 lifecycle obligations
    → ATLAS-07 dependency seams
    → applicable ATLAS-08 participant boundary
    → applicable ATLAS-09 operator projection
    → exact relevant Frontend Experience System rules
    → temporary active-FP frontend projection
    → Phase 7A Feature Pack Skeleton + preliminary Gate Manifest
    → Phase 7B required JIT Domain Dossiers
    → Phase 7C Final Feature Pack Contract
    → separate post-Phase-7C / pre-Phase-8 architectural proof classification gate
    → Phase 8 executable architectural proof / TB when required and after Development Entry Hard Stops pass
    → VS
    → HH
    → Release / Readiness
```

Do not derive a mature whole-platform route or screen map.

## 11.10 Temporary active-FP frontend projection

For an active Feature Pack, create a temporary, active-FP-specific, non-authoritative projection. Rebuild it when upstream authority, Feature Pack materiality, ownership, gates or frontend authority changes.

| Field | Required meaning |
|---|---|
| Active Feature Pack / approved outcome | Exact `FP-*` and Roadmap outcome. |
| Actor / journey | Existing public, participant, operator or scoped relationship. |
| Experience outcome | Medium-resolution visible outcome; never a screen specification. |
| FES anchor | Exact relevant frozen Frontend Experience System section or rule. |
| Relevant CAPs | Material ATLAS-04 CAP references. |
| Domain references | Relevant ATLAS-05 participation and ownership references. |
| Lifecycle references | Relevant ATLAS-06 lifecycle projection or `NONE`. |
| Dependency references | Relevant ATLAS-07 dependency seam or `NONE`. |
| Participant boundary | Relevant ATLAS-08 boundary or `NONE`. |
| Operator projection | Relevant ATLAS-09 projection or `NONE`. |
| Authority / access dependency | Existing current-authority requirement only. |
| Presentation obligation | Relevant exact FES state or interaction reference, or `NONE`. |
| Accessibility / bilingual / responsive obligation | Only materially exercised frozen obligations. |
| SEO | `REQUIRED`, `NOT_APPLICABLE` or `CONDITIONAL`. |
| Measurement concern | Existing privacy-safe measurement obligation only. |
| User-visible failure / recovery consequence | Presentation consequence only. |
| JIT frontend contract | `YES`, `NO` or `CONDITIONAL`, with reason. |
| Gate / STOP | Existing gate/OQ or `NONE`. |
| Provenance | Exact current source paths, sections and identifiers. |

The projection does not become a new Product, Roadmap, Domain, lifecycle, frontend or implementation authority.

## 11.11 Frontend JIT-contract trigger

A separate JIT frontend contract is justified only when the active Feature Pack materially introduces or exercises frontend design that cannot be safely handled by straightforward reuse of frozen patterns. Possible triggers include:

- a materially new interaction family;
- a materially complex form or journey;
- a new governed content-composition pattern;
- a materially new operator workflow representation;
- a new dashboard interaction family;
- high-risk safety or privacy frontend behaviour;
- a materially new provider-ambiguity or degraded interaction;
- unusual responsive or accessibility pressure;
- a materially new public/SEO experience contract; or
- a genuinely reusable new component or pattern contract.

Simple reuse of existing FES patterns may use `JIT frontend contract = NO`, with the reason recorded. A Feature Pack having UI does not automatically require a separate frontend contract.

## 11.12 Design-system and component boundary

Section 11 must not define exact palette, fonts, spacing values, radii, token numbers, Tailwind configuration, CSS filenames, a complete component inventory or package versions. It references the frozen FES token/design-system architecture only as required.

No permanent component catalogue is created. A reusable component or pattern still requires a real use case, meaningful reuse, understood states, accessibility behaviour and responsive behaviour. Therefore:

```text
Feature Pack has UI
    != new reusable component required
```

Component decisions remain JIT.

## 11.13 Accessibility, bilingual and responsive rule

Accessibility, bilingual delivery and responsive behaviour are baseline frontend correctness requirements. Section 11 does not copy the complete FES checklist. An active projection records only materially exercised obligations, such as approved bilingual content, an accessibility-critical interaction, long bilingual labels, a complex responsive form, a mobile-safe operator action, an accessible chart alternative, print representation or a reduced-motion-sensitive interaction.

Exact frontend implementation remains JIT.

## 11.14 SEO rule

SEO remains FES-owned baseline correctness for relevant public slices. The active projection may classify it as `REQUIRED`, `NOT_APPLICABLE` or `CONDITIONAL` and cite the exact FES rule.

Section 11 does not create an SEO Domain, SEO Feature Pack, URL catalogue, route map or schema catalogue. Exact page and schema implementation remains JIT.

## 11.15 Analytics and measurement rule

Frontend measurement remains evidence, not business authority. Section 11 does not create a permanent event catalogue, KPI catalogue, funnel implementation, provider configuration, dashboard catalogue or tracking-script design.

The temporary projection records only the current privacy-safe measurement requirement and authoritative source.

## 11.16 Failure and degraded experience

An active projection may identify broad user-visible consequences such as pending, validating, conflict, restricted, unavailable, delayed, degraded or requires attention. These are frontend/presentation consequences.

Section 11 must not invent Domain recovery, provider reconciliation, retry semantics, lifecycle state or cancellation/refund behaviour. Those semantics are referenced through upstream authority and ATLAS-06/07/08/09.

## 11.17 Frontend performance

Later implementation slices reference the frozen FES sequence:

```text
BUILD CORRECTLY
    → VERIFY CORRECTNESS
    → COMPLETE THE SLICE
    → HIGH-LEVERAGE PERFORMANCE PASS
    → ACCEPTANCE
    → STOP
```

Section 11 must not prescribe Redis, ETS/Cachex, GenServers, PubSub topics, replicas, database indexes, cache TTLs or exact asset/preload strategy. These remain evidence-driven JIT decisions.

## 11.18 Roadmap and ATLAS-08/ATLAS-09 boundary

Do not create a frontend rendering of Roadmap sequencing such as `FP-001 → account`, `FP-002 → checkout` or `FP-003 → assessment`. That adds no new authority and encourages a false one-Feature-Pack/one-surface assumption. The Roadmap remains the source of sequencing and ATLAS-04 remains the source of capability introduction and reuse.

Preserve:

```text
ATLAS-08
    → participant boundary / outcome

ATLAS-09
    → operator work / attention requirement

ATLAS-10 temporary projection
    → frontend representation obligation
```

Section 11 consumes only the relevant active-FP ATLAS-08 and ATLAS-09 projections. It does not copy participant-boundary rows or operator workflow into a permanent frontend table.

## 11.19 Selective context contract

A fresh active-Feature-Pack planner should need only:

1. the exact Roadmap Feature Pack entry;
2. the active ATLAS-04 CAP row;
3. relevant ATLAS-05 Domain references;
4. the relevant ATLAS-06 lifecycle projection;
5. relevant ATLAS-07 dependency seams;
6. the applicable ATLAS-08 participant boundary;
7. the applicable ATLAS-09 operator projection;
8. the exact relevant FES sections; and
9. applicable gates and OQs.

The temporary frontend projection is rebuilt from these sources. A whole-platform frontend progression map is not required.

## 11.20 Existing gates and STOP conditions

Preserve existing gates only where materially relevant, including as applicable:

- `OQ-034`;
- `OQ-035`;
- `OQ-036`;
- `OQ-004`;
- `OQ-005`;
- `OQ-008`;
- `OQ-010`;
- `OQ-013`;
- `OQ-015`;
- `OQ-016`;
- `OQ-020`;
- `OQ-021`;
- `OQ-022`;
- `OQ-023`;
- `OQ-029` through `OQ-033`; and
- `OQ-040`.

Section 11 does not duplicate Open Work or resolve these gates.

STOP if:

- a new Product experience or promise must be invented;
- a frontend surface would imply a new Domain or cross-domain write owner;
- presentation state would become business authority;
- a permanent Surface × Feature Pack map is required only to restate Roadmap sequencing;
- exact routes, pages, LiveViews, components or files are required;
- Section 11 needs to substantially duplicate or semantically amend frozen FES doctrine;
- exact palette, font or token values are required;
- a speculative component catalogue is required;
- frontend convenience requires inventing business lifecycle semantics;
- safety, clinical, legal, privacy, accounting or provider semantics must be invented;
- an unresolved OQ must be resolved locally; or
- Foundation Integrity fails.

On STOP, report the active Feature Pack, actor, experience outcome, relevant CAP, Domain, conflicting source, deciding authority and minimum safe resolution. Do not guess.

---

# 12. Data Authority & Projection JIT Derivation Contract

## 12.1 Purpose and permanence rule

This section helps an active Feature Pack planner answer:

> Which authoritative fact or evidence is needed, who owns it, who consumes it, for what purpose, under which existing dependency and authority contract, how fresh or rebuildable it may be, what happens on withdrawal, failure or ambiguity, and what JIT design or proof remains?

It does not answer:

> Which table, index, cache, Redis key, worker, queue, topic, TTL or API implements the relationship?

No permanent source→consumer data-flow matrix is maintained. Architecture already defines authority and projection mechanisms; Domain Law defines durable-truth ownership; ATLAS-07 defines dependency classes and high-value seams; the Roadmap owns sequencing; and ATLAS-08/09/10 derive participant, operator and frontend delivery context.

If a view can be deterministically reconstructed from stronger canonical views, do not permanently duplicate it unless permanent representation materially improves decision-making.

Permanent source→consumer rows: `0`.

New Section-12 flow classes: `0`.

Section 12 creates no new owner, authority boundary, architecture mechanism, source-to-consumer matrix or dependency taxonomy.

## 12.2 Existing authority and precedence

Section 12 consumes existing authority only:

| Source | Section-12 use |
|---|---|
| Product Law | `docs/governance/product/PROJECT_NORTH_STAR_AND_MVP_v1.3.0.md`; `docs/history/platform/archive/00_PLATFORM_v1.9.0.md`; `docs/history/platform/archive/01_DECISIONS_v1.9.0.md` | Defines product purpose, approved outcomes, policy, MVP boundaries, non-negotiables and formal gates. |
| Architecture Law | Authority, durability, projection, provider evidence, async, failure and scaling doctrine. |
| Domain Law | Exact durable-truth owner and approved cross-domain relationships. |
| Roadmap | `docs/history/platform/archive/05_ROADMAP_v1.2.4.md` | Defines approved delivery phases, Feature Pack outcomes, dependencies, gates and sequencing (17 Feature Packs). |
| ATLAS-04 | Material capabilities for the active Feature Pack. |
| ATLAS-05 | Participating Domains and ownership-sensitive exceptions. |
| ATLAS-06 | Lifecycle obligations and lifecycle ownership references. |
| ATLAS-07 | Existing dependency class, seam, consequence and pressure vocabulary. |
| ATLAS-08 | Participant consequence where relevant. |
| ATLAS-09 | Operator consequence where relevant. |
| ATLAS-10 | Frontend representation consequence where relevant. |

The authority precedence is:

```text
Product Law
    → Architecture Law
    → Domain Law
    → Roadmap
    → Atlas derivations
    → temporary active-FP data projection
```

The canonical downstream path from that temporary projection is:

```text
temporary active-FP data projection
    → Phase 7A Feature Pack Skeleton + preliminary Gate Manifest
    → Phase 7B required JIT Domain Dossiers
    → Phase 7C Final Feature Pack Contract
    → separate post-Phase-7C / pre-Phase-8 architectural proof classification gate
    → Phase 8 executable architectural proof / TB when required and after Development Entry Hard Stops pass
    → VS
    → HH
    → Release / Readiness
```

An ownership or architecture contradiction is a STOP. Section 12 records and routes it; it does not resolve it locally.

## 12.3 Authority boundaries

### Authority is not movement

```text
data moves
    != authority moves
```

A consumer may read, reference, project, aggregate, cache, observe or retain authorised evidence without obtaining source mutation authority. Physical data presence does not establish Domain ownership.

### Authority is not acceleration

```text
authority
    != cache
    != Redis
    != ETS
    != LiveView
    != PubSub
    != browser storage
    != CDN
```

PostgreSQL remains the frozen default durable structured business authority unless stronger current Architecture says otherwise. Acceleration is evidence-gated. Section 12 must not select an acceleration mechanism. Later JIT work must preserve the authoritative source, allowed stale behaviour, invalidation/rebuild semantics, unavailable-acceleration behaviour and privacy/access constraints.

### Source fact is not projection

A projection may combine facts from one or more authoritative owners without becoming a new durable-truth owner. Participant Home, Command Centre, Work queues, dashboards, search projections, analytics aggregates, discovery projections and entitlement-aware delivery views remain projections. A projection does not create a Domain.

### Owner-controlled consequence

When one authoritative transition requires another Domain to establish its own durable truth:

```text
Domain A
    → governed consequence / request / evidence
    → Domain B authoritative boundary
```

Domain A must not directly mutate Domain B persistence. Section 12 references the existing ATLAS-07 dependency class or seam and does not prescribe a call, event, message, job, topic or transaction topology.

### Provider evidence

```text
provider state
    = evidence
    != platform business truth
```

The owning platform Domain reconciles provider evidence into platform meaning. Provider ambiguity remains explicit. Section 12 does not freeze callback names, provider schemas, retries, routes, reconciliation jobs or provider-specific state machines.

### Privacy, deletion and export

Privacy & Consent may coordinate consent withdrawal, deletion, retention, export, suppression and legal/purpose governance. It does not acquire ownership of source-Domain records. Each source owner performs its approved consequence. Section 12 does not create a universal deletion Resource, universal source-record lifecycle or shared privacy write ownership. Existing legal and professional gates remain applicable where material.

### Analytics, Audit and presentation

```text
Analytics
    = governed derived measurement

Audit & Evidence
    = governed evidence

neither
    = source business authority
```

Analytics and Audit relationships are referenced only when an active Feature Pack materially needs them. Frontend, LiveView, dashboards, queues, PubSub and other observation mechanisms may represent authoritative state but do not create it. Long-lived consumers may require current-authority revalidation. Refresh intervals, polling, subscription topology and browser-cache behaviour remain downstream.

## 12.4 Active-Feature-Pack derivation

The deterministic derivation path is:

```text
Active Feature Pack
    → approved Roadmap outcome
    → ATLAS-04 material CAPs
    → ATLAS-05 participating Domains
    → ATLAS-06 lifecycle obligations
    → ATLAS-07 dependency class / seam / pressure
    → ATLAS-08 participant boundary where applicable
    → ATLAS-09 operator projection where applicable
    → ATLAS-10 frontend projection where applicable
    → exact Domain Map ownership references
    → exact Architecture authority / projection references
    → temporary active-FP data authority / projection view
    → Phase 7A Feature Pack Skeleton + preliminary Gate Manifest
    → Phase 7B required JIT Domain Dossiers
    → Phase 7C Final Feature Pack Contract
    → separate post-Phase-7C / pre-Phase-8 architectural proof classification gate
    → Phase 8 executable architectural proof / TB when required and after Development Entry Hard Stops pass
    → VS
    → HH
    → Release / Readiness
```

Section 12 does not derive a whole-platform data-flow graph. A temporary row is created only when the active Feature Pack materially requires the data relationship. The relevant ATLAS-07 class or seam is referenced, not redefined.

## 12.5 Temporary active-FP data projection

For an active Feature Pack, create one temporary, active-FP-specific, non-authoritative projection. Rebuild it when the active outcome, material CAPs, ownership evidence, gates or relevant upstream authority change.

| Field | Required meaning |
|---|---|
| Active Feature Pack / approved outcome | Exact `FP-*` and Roadmap outcome. |
| Source fact / evidence | Exact durable fact, provider evidence or projection being consumed; descriptive only and not a new enum. |
| Owning Domain / authority | Exact Domain Map owner or existing platform-control authority. |
| Consumer / purpose | Domain, participant/operator/frontend projection or external obligation consuming the data and why. |
| ATLAS-07 relationship | Existing dependency class and seam where applicable. |
| Mutation / consequence rule | Read-only/reference or owner-controlled consequence using existing authority. |
| Lifecycle reference | Relevant ATLAS-06 obligation or `NONE`. |
| Participant / operator / frontend reference | ATLAS-08/09/10 where applicable. |
| Current-authority requirement | Existing revalidation requirement before use. |
| Access / purpose / minimisation boundary | Current approved authority only. |
| Retention / export / deletion / withdrawal effect | Broad owner-controlled consequence. |
| Freshness / stale / rebuild expectation | Medium-resolution statement; no TTL taxonomy. |
| Failure / ambiguity consequence | Broad business, operating or presentation effect only. |
| External evidence | Existing provider/evidence requirement or `NONE`. |
| Measurement / audit need | Existing evidence requirement or `NONE`. |
| Performance pressure | Existing ATLAS-07 pressure category or `NONE`. |
| JIT design need | `YES`, `NO` or `CONDITIONAL`, with reason. |
| Proof need | Existing or proposed proof requirement or `NONE`; never auto-creates a TB. |
| Gate / STOP | Existing gate/OQ or `NONE`. |
| Provenance | Exact current paths, sections and identifiers. |

Do not add an `Authority role` enum or a new Section-12 flow type field. Use existing Domain, Architecture and ATLAS-07 vocabulary.

## 12.6 Freshness, stale use and rebuildability

Freshness and rebuildability are data-specific JIT questions, not a new permanent taxonomy. Record them in plain medium-resolution language:

- Must the consumer re-read current authority before action?
- Is bounded-stale use safe for this purpose?
- Is the representation a reproducible historical snapshot?
- Can it be deterministically rebuilt from stronger authority?
- Does external ambiguity require a pending state?
- Would stale data create safety, privacy, payment, entitlement or capacity harm?

Conceptually distinguish durable authoritative truth, required durable evidence, rebuildable projection and unresolved external evidence requiring reconciliation. Do not specify seconds, minutes, hours, cache TTLs, polling intervals or refresh timers. Do not create a permanent storage-class taxonomy.

## 12.7 Failure, ambiguity and withdrawal

The temporary projection may record broad consequences such as:

- authoritative source unavailable;
- projection stale;
- projection unavailable;
- provider evidence ambiguous;
- downstream consequence pending;
- authority revoked;
- consent withdrawn;
- source corrected;
- source deleted;
- analytics delayed; or
- protected view restricted.

These are delivery impacts only. Retries, reconciliation algorithms, compensation, restore procedures and Domain transition semantics remain owner/JIT responsibilities.

## 12.8 No universal data-flow state machine

Section 12 must not create generic lifecycles such as:

```text
CREATED
    → PROJECTED
    → CACHED
    → INVALIDATED
```

or:

```text
PENDING
    → SYNCED
    → STALE
    → REBUILT
```

ATLAS-06 remains lifecycle authority at delivery-planning level. Exact reconciliation and projection lifecycles belong to the appropriate owner/JIT contract.

## 12.9 Purpose-shaped, not storage-shaped

The temporary projection answers what fact or evidence is required, who owns it, who consumes it, why, whether the consumer can mutate it, which authority must be current, whether stale use is safe, whether it is rebuildable, what deletion or withdrawal means, what ambiguity or failure means and what evidence or proof remains.

It does not define tables, columns, schemas, indexes, Redis keys, hashes, bitmaps, sets, ZSETs, TTLs, topics, queues, workers, GenServers or API routes.

## 12.10 Performance and scarce-capacity boundary

At Section-12 level, preserve broad pressure only and use the existing ATLAS-07 pressure vocabulary where applicable. Ask:

- Is current authoritative data required?
- Could stale data violate a hard invariant?
- Is the path concurrency or burst sensitive?
- Is it high-read or high-write?
- Could it be paginated or streamed?
- Could later acceleration be justified without creating a second authority?
- Is proof likely before implementation?

Do not select a performance mechanism. `OQ-039` remains the implementation-grade performance/scaling mapping gate.

For scarce-capacity Feature Packs, Events & Live remains capacity authority, Commerce remains payment authority, ATLAS-07 preserves the dependency seam and `OQ-022` remains the architecture/performance gate. Exact locks, holds, expiry, Redis, queue or bitmap design remains JIT. No permanent flash-sale mechanism belongs here.

## 12.11 Roadmap, Domain Map and ATLAS-07 boundaries

Roadmap owns sequencing. Section 12 is projected for one active Feature Pack at a time and must not create `FP-001 data flows`, `FP-002 data flows` or any equivalent permanent matrix.

Section 12 references exact Domain Map ownership rows and does not reproduce the 18 approved Domains, 48-row ownership matrix, Domain Architecture Profiles or the full Domain dependency matrix. If the required owner is unclear, STOP and route to Domain Law.

Section 12 consumes ATLAS-07 and does not reproduce its dependency classes, seven seam rows, cycle rule, shared-write rule, provider rule, Analytics/Audit rule, proof/TB doctrine or pressure definitions. It adds only data-specific questions for consumption purpose, freshness, rebuildability, withdrawal and failure.

Architecture remains the authority for durability, authority, cross-domain writes, async consequences, provider evidence, projections, privacy/security, failure/degradation and scaling. Section 12 keeps that restatement minimal and does not select mechanisms.

## 12.12 Selective context contract

A fresh active-FP planner should need only:

1. the exact Roadmap Feature Pack entry;
2. the active ATLAS-04 CAP row;
3. the relevant ATLAS-05 Domain projection;
4. the relevant ATLAS-06 lifecycle projection;
5. the relevant ATLAS-07 class, seam and pressure;
6. the applicable ATLAS-08 participant boundary;
7. the applicable ATLAS-09 operator projection;
8. the applicable ATLAS-10 frontend projection;
9. exact Domain Map ownership references;
10. exact Architecture references; and
11. applicable OQs and gates.

The planner should not need a permanent whole-platform data-flow matrix.

## 12.13 JIT design and proof rule

A data relationship does not automatically create a JIT Domain Dossier or Architecture contract. Set `JIT design need = YES` or `CONDITIONAL` only when implementation-grade semantics are genuinely unresolved, including owner-controlled consequences, sensitive access/minimisation, provider reconciliation, stale-data correctness, projection rebuild/invalidation, high-concurrency behaviour, deletion/withdrawal consequences, exact evidence retention or async durability.

A material flow may require proof for payment→entitlement idempotency, scarce-capacity/payment races, stale safety prevention, provider ambiguity/recovery, deletion propagation, high-volume projection behaviour or experimentation consistency. Proof need does not create a Tracer Bullet. Phase 7C freezes the proof requirement and applicable obligations; the separate post-7C, pre-Phase-8 classification gate selects `REUSE_EXISTING_PROOF` or `NEW_TRACER_BULLET`.

## 12.14 Existing gates and STOP conditions

Carry only gates materially required by the active flow, including as applicable:

- `OQ-004`;
- `OQ-009`;
- `OQ-014`;
- `OQ-016`;
- `OQ-022`;
- `OQ-029` through `OQ-033`;
- `OQ-037`;
- `OQ-039`; and
- `OQ-040`.

Do not create a duplicate global OQ inventory or resolve any gate.

STOP if:

1. a durable truth lacks one clear authoritative owner;
2. shared authoritative write ownership appears;
3. a consumer requires direct mutation of another Domain's persistence;
4. provider, cache, projection, Analytics, Audit, LiveView or browser state would become authoritative truth;
5. a permanent source→consumer matrix is required only to restate Domain Law or ATLAS-07;
6. a new Section-12 flow/dependency taxonomy is required without genuine unique value;
7. provider state must be treated as business truth;
8. privacy orchestration would acquire source-record ownership;
9. Analytics or Audit would acquire source business authority;
10. a synthetic cross-domain/data-flow lifecycle must be invented;
11. exact tables, schemas, indexes, Redis structures, TTLs, topics, queues, workers or APIs must be fixed;
12. safety, clinical, legal, accounting, professional or provider semantics must be invented;
13. an unresolved OQ must be resolved locally;
14. frozen Architecture or Domain Law would require semantic amendment; or
15. Foundation Integrity fails.

On STOP report the active Feature Pack, source fact/evidence, authoritative owner, consumer, existing ATLAS-07 relationship, conflicting source, deciding authority and minimum safe resolution. Do not guess.

---

# 13. Integration progression

## 13.1 Integration rule

The Atlas may show when an external provider or integration becomes relevant to an approved outcome, which domain owns the platform meaning, what evidence must be validated and which failure state must remain visible.

It must not freeze provider configuration, retry values, routes, credentials, webhook names, package choices, deployment topology or provider-specific state as platform law.

Every populated integration entry must identify:

- the approved capability it supports;
- the platform-owned authority boundary;
- the external evidence or service dependency;
- the relevant legal, clinical, privacy, security or operational gate;
- the broad success, pending, degraded and recovery classes; and
- the Feature Pack and JIT contract where exact behaviour becomes mandatory.

## 13.2 Population structure

| Integration / provider capability | Owning platform domain | Approved outcome | External evidence required | Gate / authority | Broad failure class | First relevant Feature Pack | Reuse / replacement seam | JIT contract need | Status |
|---|---|---|---|---|---|---|---|---|---|
| _Populate in a later Atlas task._ |  |  |  |  |  |  |  |  |  |

---

# 14. Analytics and measurement progression

## 14.1 Measurement rule

Analytics remains derived from governed authoritative facts. The Atlas may show when a product, operational or learning measure becomes necessary and how the measure relates to a Feature Pack or release decision.

The view must preserve these boundaries:

- native NewYou facts remain authoritative for payment, entitlement, safety, eligibility, content, participant and approved conversion outcomes;
- purpose-built canonical dashboards are preferred over an unrestricted dashboard builder;
- experiment assignment and decision authority remain distinct from Analytics measurement;
- external analytics, search and provider dashboards are complementary evidence; and
- privacy, consent, minimisation, deletion and restricted access apply to measurement.

ATLAS-01 does not create a KPI catalogue, metric contract, dashboard, experiment or analytics implementation.

## 14.2 Population structure

| Measure / evidence need | Semantic owner | Authoritative source facts | Feature Pack / release purpose | Freshness / quality concern | Privacy / deletion boundary | Experiment relationship | Operational response | JIT analytics need | Status |
|---|---|---|---|---|---|---|---|---|---|
| _Populate in a later Atlas task._ |  |  |  |  |  |  |  |  |  |

---

# 15. Security, privacy and safety escalation

## 15.1 Escalation rule

The Atlas must make the first delivery point for a protection visible. It must not lower a protection to preserve sequencing or convenience.

The following priorities remain in force:

```text
clinical and safety authority
    → privacy, consent and security
    → payment, entitlement and accounting integrity
    → confirmed capacity and inventory integrity
    → correctness and recoverability
    → freshness, latency, convenience and UI polish
```

The ordering is a planning priority, not a substitute for the source law. Temperament never overrides clinical or safety authority. A protected data path requires current purpose, policy and access checks. A material correction, withdrawal, revocation or deletion effect must remain visible across affected projections and delivery surfaces.

## 15.2 Population structure

| Protection concern | Protected outcome / data class | First relevant Feature Pack | Upstream authority | Trigger for escalation | Required owner / expert authority | Broad consequence if unresolved | JIT dossier / proof need | Status |
|---|---|---|---|---|---|---|---|
| _Populate in a later Atlas task._ |  |  |  |  |  |  |  |  |

The Atlas must record unresolved clinical, legal, professional, provider or privacy policy as a gate or STOP. It must not invent thresholds, wording, retention periods, consent interpretations or access exceptions.

---

# 16. Performance and scaling progression

## 16.1 Performance rule

The Atlas preserves the frozen, evidence-led architecture:

- record authoritative data layer and broad hot, warm or cold character;
- record broad concurrency sensitivity, burst behaviour and DB or async pressure;
- record possible acceleration candidates only as candidates;
- record the evidence that would justify acceleration; and
- keep PostgreSQL authority and simplest-correct-path-first doctrine intact unless upstream Architecture Law says otherwise.

The Atlas must not introduce Redis, ETS/Cachex, GenServers, replicas, specialist services, microservices, queue topology or caching merely because they may be useful. Any such mechanism remains evidence-gated and JIT unless already mandated upstream.

Performance entries describe future proof obligations. They do not claim measured latency, capacity, workload, safe envelope or breakpoint evidence before the appropriate proof stage exists.

## 16.2 Population structure

| Capability / flow | Authoritative layer | Temperature | Concurrency / burst character | DB / async pressure | Candidate acceleration | Evidence required before use | Architectural Proof / Hardening stage | JIT OQ-039 need | Status |
|---|---|---|---|---|---|---|---|---|---|
| _Populate in a later Atlas task._ |  |  |  |  |  |  |  |  |  |

---

# 17. Failure and recovery progression

## 17.1 Failure rule

The Atlas may show which broad failure and recovery classes become relevant as an outcome enters delivery. It must preserve the architecture's distinction between authoritative refusal, pending external ambiguity, durable asynchronous recovery, stale or unavailable projection, provider outage, overload, correction or withdrawal, deletion/restore behaviour and release rollback.

A failure class is a delivery seam. It is not an implementation choice.

## 17.2 Population structure

| Outcome / flow | Failure class | Authority affected | Participant / operator effect | Recovery or correction expectation | Proof / hardening stage | Feature Pack relationship | JIT need | Status |
|---|---|---|---|---|---|---|---|---|
| _Populate in a later Atlas task._ |  |  |  |  |  |  |  |  |

The Atlas must not claim recovery is complete until the relevant evidence exists at the correct stage. A provider response, queue state, projection or UI message is not proof of authoritative success by itself.

---

# 18. Architectural proof map

## 18.1 Proof rule

The Atlas may identify likely architectural-proof boundaries and the invariant or failure pressure that makes them material. It must not create a Tracer Bullet or select the final proof classification.

Phase 7C freezes the architectural proof requirement and applicable obligations. The separate classification gate after Phase 7C and before Phase 8 selects `REUSE_EXISTING_PROOF` or `NEW_TRACER_BULLET`. The Atlas may record that decision only after the gate's approved evidence exists.

## 18.2 Population structure

| Architectural claim / path | Upstream DEC / ARC / FLOW anchor | Affected Feature Pack | Affected domains | Hard invariant | Failure / pressure to prove | Existing evidence relationship | Required proof stage | Classification gate (after Phase 7C, before Phase 8) | JIT task dependency | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| _Populate in a later Atlas task._ |  |  |  |  |  |  |  |  |  |  |

No `TB-nnn` is created by ATLAS-01. No executable proof is prepared here.

---

# 19. Horizontal hardening map

## 19.1 Hardening rule

The Atlas may identify categories of hardening that a proven capability could require. It must tie them to evidence or an explicit release gate. It must not create `HH-nnn` work or add a hardening category merely because a technology exists.

Possible categories include load and contention, provider failure, queue saturation, restore and deletion replay, security, accessibility, observability, multi-node behaviour, cache stampede, migration pressure and operational rehearsal. The applicable category is determined by the affected outcome and evidence.

## 19.2 Population structure

| Capability / outcome | Hardening category | Evidence or gate trigger | Affected invariant | Relevant Feature Pack | Proof already available | Release / readiness effect | JIT HH contract need | Status |
|---|---|---|---|---|---|---|---|
| _Populate in a later Atlas task._ |  |  |  |  |  |  |  |  |

---

# 20. Future-extension seam register

## 20.1 Seam rule

This register protects approved future direction without designing it early. A seam may be recorded only when an upstream source identifies an approved future capability, a controlled expansion path or a legitimate reuse boundary.

The Atlas must not create generic tenancy, unrestricted product spaces, parallel commerce or entitlement systems, or specialist infrastructure without an approved outcome and the authority needed to support it.

Each seam must state:

- the current authority that creates or permits the future direction;
- what must remain stable for reuse;
- what new authority, policy or evidence will be required;
- the trigger for moving the seam into a Feature Pack;
- what is explicitly not being designed now; and
- the STOP condition if the future direction conflicts with current law.

## 20.2 Population structure

| Future seam | Upstream basis | Stable shared boundary | Future trigger | New authority / evidence required | Explicitly deferred detail | Risk if closed early | Candidate Feature Pack | JIT boundary | Status |
|---|---|---|---|---|---|---|---|---|---|
| _Populate in a later Atlas task._ |  |  |  |  |  |  |  |  |  |

---

# 21. Feature Pack delivery projections

## 21.1 Projection rule

The delivery projection is the Atlas's medium-resolution view of how a Feature Pack travels through preparation, proof, slices, hardening and readiness. It may show dependencies and expected evidence without becoming a Feature Pack contract.

The Roadmap remains authoritative for the Feature Pack outcome and sequencing. The Feature Pack contract remains authoritative for implementation-entry scope and gates. The Atlas must link to both and must not substitute for either.

## 21.2 Population structure

| Feature Pack | Roadmap phase | Outcome anchor | Entry dependencies | Capability movement | Domain / lifecycle impact | Journey / frontend impact | Integration / measurement impact | Safety / privacy impact | Performance / failure pressure | Proof expectation | Hardening expectation | Readiness dependency | Atlas status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| _Populate in a later Atlas task._ |  |  |  |  |  |  |  |  |  |  |  |  |  |

This view may project a relationship such as "reuse existing capability" or "full lifecycle specification required here". It may not project exact implementation tasks.

---

# 22. Cross-Feature-Pack risk register

## 22.1 Risk rule

The risk register tracks a risk that crosses an outcome boundary or could make later reuse unsafe. A risk must have an authority source, an owner or routing target, a trigger and a response boundary.

Risk entries are not issue tickets, implementation tasks or replacement Product/Architecture/Domain decisions.

## 22.2 Population structure

| Risk | Feature Packs affected | Domain / capability affected | Risk class | Upstream evidence | Trigger | Owner / authority route | Consequence | Mitigation boundary | JIT / proof / hardening dependency | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| _Populate in a later Atlas task._ |  |  |  |  |  |  |  |  |  |  |

---

# 23. Development navigation rules

The Atlas may help navigate delivery preparation when relevant. It summarizes derived relationships and routes questions to the authority that owns them; it does not make its own navigation step a gate or prerequisite. Atlas cannot override current upstream authority or its STOP; when sources conflict, the controlling source governs.

1. Start with the approved Roadmap outcome or Feature Pack and current Product, Architecture, Domain and Roadmap sources.
2. Consult relevant Atlas views when they help locate shared capabilities, Domain participation, lifecycle, journey, integration, measurement, risk, proof or hardening relationships.
3. Confirm material Atlas statements against their exact current source. If an Atlas route is stale or conflicts with authority, the source controls.
4. Follow canonical Phase 7A Skeleton + Gate Manifest → required JIT Domain Dossiers → Final Feature Pack Contract only as the applicable sources and approved contract require. The POM defines no additional Phase 7 artifact types.
5. Follow proof classification, proof, execution, evidence and readiness requirements from the owning Roadmap, approved Feature Pack/JIT contract and other applicable authority.
6. Revalidate current authority when resuming or when a relevant change may affect the work. No named Continuation Review artifact is required by this Atlas alone.
7. STOP when current authority is missing or contradictory, ownership is unclear, required upstream evidence is absent, scope exceeds the approved outcome, or continuing would require inventing policy or implementation semantics.

Atlas checklists and review prompts may help organize this work. Their absence is not a blocker unless a current upstream source or approved contract requires the item. The historical ATLAS-02 population work performed only the Feature Pack Portfolio Register. ATLAS-03 through ATLAS-11 are recorded in Sections 5 through 12. This working artifact does not perform Phase 7 or downstream work and does not authorize a deliverable.

# 24. Atlas governance/change policy

## 24.1 Change classes

Atlas changes are classified before editing:

| Change class | Allowed handling |
|---|---|
| Editorial clarification | May correct wording without changing a relationship or authority claim. Preserve source references. |
| Derived navigation correction | May correct an Atlas relationship when current upstream sources prove the correction. Record the source and review the affected views. |
| Structural Atlas change | May add or refine a view or classification only through an explicit working-artifact review. It must not create a new authority layer. |
| Upstream amendment required | Stop Atlas work and route the issue to the authority that owns the rule. |
| Implementation detail required | Stop the Atlas entry and route the detail to the affected Feature Pack/JIT Domain Dossier. |

Working changes must preserve the artifact status. A working Atlas update does not freeze the Atlas and does not modify the current-authority manifest unless a separate governance decision requires it.

## 24.2 Mandatory routing

| Finding | Route |
|---|---|
| Upstream contradiction | **STOP** and route to the conflicting upstream authority. |
| Missing Product policy | Product Law and a formal Product decision or gate. |
| Architecture mechanism conflict | Architecture Law / Architecture authority. |
| Ownership or invariant conflict | Domain Law / Domain Map. |
| Sequencing or scope conflict | Roadmap authority. |
| Missing implementation semantics | Affected JIT Domain Dossier under the selected Feature Pack. |
| Execution ambiguity | TB / VS / HH contract, after the upstream gates are satisfied. |

The Atlas must state the exact source references, the unresolved question, the route and the downstream effect. It must never silently repair upstream authority.

## 24.3 Revalidation

Revalidation is recommended when current context may affect the planned work; a named Continuation Review artifact is not required by this Atlas. Current authority always controls. Recheck affected Atlas entries when:

- a Product, Architecture, Domain or Roadmap source is amended;
- an upstream gate changes status;
- proof evidence changes the known safe boundary;
- a release or hardening result contradicts a planning assumption; or
- a new approved future direction changes a shared capability seam.

Revalidation may mark an entry stale, gated or stopped. It may not hide the change by rewriting history. If current authority changed materially or conflicts with the work, stop because the owning authority controls—not because an Atlas-only review record is missing.

---

# 25. Global STOP conditions

STOP Atlas work and report the exact source references and required authority level if any of the following occurs:

- Product Law conflicts;
- Architecture Law conflicts;
- Domain ownership is ambiguous;
- a circular authoritative dependency is found;
- Roadmap sequencing conflicts;
- an unresolved expert or vendor OQ is required to continue;
- legal, clinical, commercial or provider policy would need to be invented;
- Atlas work requires concrete implementation semantics;
- the Atlas would effectively amend a Feature Pack outcome;
- current authority documents disagree materially;
- existing foundation integrity validation fails;
- the work would create or imply an exact Ash Resource or action name;
- the work would create or imply schemas, tables, columns, migrations, indexes, Redis keys or structures, TTLs, Oban workers or queues, PubSub topics, GenServer modules, routes, API endpoints, frontend component/file structures, package choices or versions, deployment sizing or source code;
- the work would create a TOON implementation task;
- the work would begin FP-001 preparation or any other Phase 7 deliverable; or
- the work would create Architectural Proof, Vertical Slice, Horizontal Hardening or release/readiness artifacts.

Do not STOP solely because an Atlas-only Grill-Me, Implementation Handoff, Continuation Review or checklist item is absent. STOP when a controlling source requires missing evidence or review, when stronger authority is unresolved or contradictory, when ownership or scope is unclear, or when proceeding would require invention. When STOP occurs, report:

1. the exact source path and section or identifier;
2. the finding and the evidence that produced it;
3. the authority level that must decide or correct it;
4. the affected Atlas view and Feature Pack relationship;
5. the safe downstream action after resolution; and
6. the fact that no Atlas-level guess was made.

---

# 26. Closure/readiness audit

## 26.1 ATLAS-01 completion standard

This subsection records the completion standard for the ATLAS-01 contract layer. It remains the historical baseline for the ATLAS-02 update.

ATLAS-01 is ready for review only when the evidence shows all of the following:

| Requirement | Required evidence |
|---|---|
| Authority contract exists | This artifact names the upstream hierarchy, source set and subordinate role of the Atlas. |
| Working status is explicit | The artifact is marked derived, working and non-authoritative, and says it does not authorise implementation. |
| Scope is explicit | The artifact defines medium-resolution navigation across the complete approved roadmap. |
| Delivery lifecycle governance is explicit | The Delivery Lifecycle Governance section defines the Roadmap-to-next-decision flow, Feature Pack, TB, VS and HH lifecycles, optional Grill-Me prompts, useful handoff and revalidation aids, and evidence/closure requirements owned by current authority and approved contracts. |
| Decision escalation is explicit | The Decision Escalation Matrix routes discoveries to the lowest correct authority and defines lower-level boundaries, escalation response and STOP conditions. |
| Future templates remain conceptual | The future template registry names the expected files and their purposes without creating any files under `docs/templates/`. |
| Proposed views are defined | Sections 3 through 22 define the mature-platform view, portfolio map, registers, matrices, journeys, flows, proof, hardening, seams and risks without substantive pack analysis. |
| Lifecycle boundary is explicit | Section 7 records the eventual state-machine requirements and limits Atlas lifecycle coverage to existence, ownership, known upstream semantics and the Feature Pack where full specification becomes mandatory. |
| Performance boundary is explicit | Section 16 preserves PostgreSQL authority, evidence-led acceleration and simplest-correct-path-first sequencing. |
| Governance is explicit | Section 24 defines amendment classes and routes each finding to the correct authority. |
| STOP conditions are explicit | Section 25 includes upstream contradiction, ambiguity, unresolved gates, implementation semantics, foundation integrity failure and scope expansion. |
| No authority source was changed | `git diff` shows only the requested working artifact, apart from an explicitly approved repository convention if one exists. |
| Foundation remains intact | The existing foundation integrity audit and applicable documentation tests pass. |
| No implementation or lower-level preparation was created | No product code, Feature Pack preparation, JIT Domain Dossier, TB, VS, HH or TOON exists as part of ATLAS-01. |
| Atlas remains unfrozen | No freeze verdict or current-authority promotion is made by this artifact. |

## 26.2 ATLAS-01 review protocol

The ATLAS-01 delivery report used the following protocol:

1. inspect the full diff;
2. confirm the branch and changed-file set;
3. run the existing applicable foundation integrity and documentation checks;
4. run `git diff --check`;
5. confirm no implementation tooling or implementation artifact was introduced;
6. confirm no Feature Pack, JIT dossier, TB, VS, HH or TOON was prepared;
7. record any contradiction found, or state that none was found; and
8. report `PASS` only when every requirement above is evidenced. Otherwise report `STOP` with the exact route.

ATLAS-01 historically ended with the contract captured above, and ATLAS-02 subsequently added the Feature Pack Portfolio Register under that same authority boundary. ATLAS-03 through ATLAS-11 are captured in the later sections of this current working artifact. None of those Atlas views authorises Phase 7, implementation or a lower-level artifact.

## 26.3 ATLAS-02 completion standard

ATLAS-02 is ready for review only when the evidence shows all of the following:

| Requirement | Evidence in this artifact |
|---|---|
| Complete portfolio coverage | The summary and register contain all 17 approved Roadmap Feature Packs in Roadmap order. |
| Required entry structure | Each pack has Purpose, Intended Outcome, Roadmap Position, Approved Dependencies, Known Unlocks, High-Level Domain Involvement, Known Gates, Release Significance and Authority Anchors. |
| Authority fidelity | Purpose, outcomes, positions, dependencies, unlocks and release significance derive from the frozen Roadmap; domain names and ownership boundaries derive from the frozen Domain Map; gate references remain tied to current authority. |
| Dependency and gate discipline | No dependency, unlock, gate or domain role is added by inference; conditional FP-017 remains explicitly unassigned until its required future direction exists. |
| Navigation scope | The register remains outcome-level delivery navigation and does not become implementation planning or another Atlas view. |
| Working boundary | The artifact remains derived, working, non-authoritative and unfrozen; later ATLAS-03 through ATLAS-11 views remain derived and do not authorise Phase 7 or implementation. |

## 26.4 ATLAS-05 completion standard

ATLAS-05 is ready for review only when the evidence shows all of the following:

| Requirement | Evidence in this artifact |
|---|---|
| Derivation rule exists | Section 6 identifies the four canonical inputs and the procedure for reconstructing a Feature Pack's candidate Domain set. |
| Authority precedence is explicit | Section 6 places the frozen Domain Map above CAP authority, Feature Pack participation context and the temporary JIT projection. |
| No duplicate matrix is maintained | Section 6 explicitly rejects any permanent Domain × Feature Pack matrix (including the historical 18 × 17 = 306-cell plan and the current 20-Domain equivalent) and records zero maintained Domain × Feature Pack cells. |
| Exception register exists | Section 6 records only cross-domain, platform-control, conditional or otherwise non-obvious relationships that require a future planner's attention. |
| Ownership remains frozen | No exception or projection transfers Domain ownership, creates shared authoritative writes or alters the Domain Map. |
| JIT projection contract exists | Section 6 defines the temporary current-Feature-Pack fields for Domain role, relevant CAPs, existing authority, lifecycle impact, durable consequence, dossier need and gate/STOP status. |
| Implementation boundary is explicit | Section 6 defers reads, commands, consequences, projections, schemas, Resources, APIs, PubSub, database consequences and other implementation interactions to selected Feature Pack work. |
| Coverage is complete | 17/17 Feature Packs have ATLAS-02 involvement and ATLAS-04 material CAP summary rows, and each material CAP resolves to an ATLAS-03 entry. |
| Conditional scope is protected | FP-017 remains conditional and stops until a separately approved Product Law direction names the affected owners. |
| STOP routing is explicit | Missing CAPs, contradictory authority, shared writes, unresolved lifecycle meaning, implementation dependency or an outside-Atlas governance change routes upstream without an Atlas guess. |
| Working boundary is preserved | The artifact remains derived, working, non-authoritative and unfrozen; no authority document or current-authority manifest is changed. |

## 26.5 ATLAS-05 review protocol

The ATLAS-05 delivery review uses the following protocol:

1. inspect the full diff;
2. confirm the branch and changed-file set contain only the working Atlas;
3. run the Foundation Integrity Audit and existing documentation tests;
4. run `git diff --check`;
5. confirm that no permanent Domain × Feature Pack matrix or lower-level implementation artifact was introduced;
6. verify each exception against the cited ATLAS-02, ATLAS-03, ATLAS-04, Domain Map or Roadmap evidence;
7. confirm that no Product, Architecture, Domain, Roadmap or manifest file changed;
8. record any contradiction found, or state that none was found; and
9. report `PASS` only when every requirement above is evidenced. Otherwise report `STOP` with the exact route.

## 26.6 ATLAS-06 completion standard

This subsection records the completion standard for the ATLAS-06 lifecycle derivation contract. It does not create lifecycle rows or begin ATLAS-07.

ATLAS-06 is ready for review only when the evidence shows all of the following:

| Requirement | Evidence in this artifact |
|---|---|
| No permanent lifecycle inventory | Section 7 states that no permanent platform-wide lifecycle concept table is maintained and records permanent lifecycle rows as `0`. |
| Canonical derivation inputs | Section 7 uses ATLAS-03, ATLAS-04, ATLAS-05 and frozen Product, Architecture, Domain and Roadmap authority without creating a second lifecycle authority. |
| Deterministic JIT path | Section 7 defines the active-Feature-Pack derivation path from material CAP relationships through temporary projection, optional review prompts, source-required JIT Domain Dossiers and justified proof or execution artifacts. |
| Capability/concept distinction | Section 7 permits zero, one or multiple lifecycle-bearing concepts within a CAP and defers decomposition until active-FP evidence supports it. |
| Temporary projection boundary | Section 7 defines the minimum projection fields and explicitly keeps the projection temporary and non-authoritative. |
| Exact coverage vocabulary | Section 7 uses exactly `NONE`, `EXISTENCE_ONLY`, `UPSTREAM_SEMANTICS`, `FULL_SPEC_REQUIRED`, `PROOF_REQUIRED` and `STOPPED`. |
| Separate risk vocabulary | Section 7 keeps coverage status separate from the controlled broad risk flags and does not require a risk flag for every lifecycle. |
| Source-owned complete lifecycle requirement | `FULL_SPEC_REQUIRED` records a source-owned requirement for complete implementation-grade lifecycle semantics in the affected JIT Domain Dossier before governed implementation proceeds; the Atlas does not create that gate. |
| Proof boundary | `PROOF_REQUIRED` surfaces a materially unproven correctness claim but does not automatically create a Tracer Bullet; Phase 7C freezes the proof requirement and obligations, then the separate post-7C / pre-Phase-8 classification gate selects proof reuse or a new Tracer Bullet. |
| Cross-domain ownership | Section 7 preserves separate durable-truth owners and prevents a coordinator or platform-control lifecycle from acquiring another Domain's business authority. |
| No premature mechanism selection | Section 7 records broad risk visibility without prescribing databases, locks, queues, caches, processes, provider mechanisms or schemas. |
| No invented lifecycle semantics | No lifecycle concepts, states, transitions, guards, side effects or terminal semantics are invented in this contract. |
| Upstream authority unchanged | No Product, Architecture, Domain, Roadmap, Open Work or current-authority manifest source is changed. |
| Existing Atlas views unchanged | The 31 ATLAS-03 CAP lifecycle records, ATLAS-04 relationships and ATLAS-05 Domain derivation remain unchanged. |
| Selective retrieval | A fresh Feature Pack agent can retrieve only the active-FP summary, relevant CAPs, relevant Domain projection or exceptions, this contract and required upstream references. |
| ATLAS-07 boundary | ATLAS-06 does not define Section 8 dependency content; ATLAS-07 is a separate contract. |
| Foundation integrity | Foundation Integrity Audit and applicable documentation tests pass. |
| Working boundary | The Atlas remains `WORKING / NON-AUTHORITATIVE`, derived planning material and unfrozen. |

## 26.7 ATLAS-06 review protocol

The ATLAS-06 delivery review uses the following protocol:

1. inspect the full diff;
2. confirm the branch and changed-file set contain only the working Atlas;
3. confirm the starting `main` SHA contains the approved ATLAS-05 baseline;
4. run the Foundation Integrity Audit and existing documentation tests;
5. run `git diff --check`;
6. run a focused Section 7 audit for zero permanent lifecycle rows, the exact coverage vocabulary, the exact risk-flag vocabulary, status/risk separation, the source-owned `FULL_SPEC_REQUIRED` requirement and affected JIT Domain Dossier obligation, the `PROOF_REQUIRED` proof/TB boundary, cross-domain ownership, platform-control boundaries, non-authoritative projection and selective retrieval;
7. confirm that no lifecycle concept or implementation-grade state-machine semantics were invented;
8. confirm that ATLAS-07, Feature Pack preparation, JIT Domain Dossiers, TBs, VSs, HHs and TOONs were not started;
9. confirm that pre-existing untracked `AGENTS.md` and `.agents/` material remains untouched;
10. record any contradiction or escalation with its exact CAP/Domain/Feature Pack, source references, deciding authority and minimum safe resolution; and
11. report `PASS` only when every requirement above is evidenced. Otherwise report `STOP` with the exact route.

## 26.8 ATLAS-07 completion standard

ATLAS-07 is ready for review only when the evidence shows all of the following:

| Requirement | Evidence in this artifact |
|---|---|
| No exhaustive permanent graph | Section 8 records `0` permanent global dependency-graph rows and no routine Domain-pair enumeration. |
| No Section 8 placeholder | The former population-oriented table is removed and no Section 8 placeholder remains. |
| Exactly five conceptual classes | Section 8 defines exactly `AUTHORITATIVE_READ`, `OWNER_CONTROLLED_CONSEQUENCE`, `DERIVED_PROJECTION`, `ORCHESTRATION_WITHOUT_OWNERSHIP` and `EVIDENCE_OBSERVATION`; conditionality is expressed through readiness and gate metadata. |
| Permanent seams stay compact | The reference-oriented register contains `7` approved high-value seams; global safety rules are invariants, not graph rows. |
| ATLAS-05 is referenced, not copied | The register points to existing ATLAS-05 exception IDs and does not duplicate their full explanations. |
| Canonical inputs are explicit | Section 8 uses the Domain Map, Architecture Law, ATLAS-03, ATLAS-04, ATLAS-05, ATLAS-06 and applicable Roadmap/Product gates. |
| Authority precedence is explicit | Product, Architecture and Domain Law outrank CAP authority, Feature Pack materiality, Domain participation and the dependency projection. |
| Deterministic active-FP derivation | Material ATLAS-04 CAPs flow through ATLAS-03, ATLAS-05, ATLAS-06 and upstream authority into one temporary projection only when the relationship is materially required. |
| Ownership remains frozen | No dependency transfers durable-truth ownership, creates shared authoritative writes or gives a coordinator business authority. |
| Cycle STOP is explicit | Read cycles remain allowed; unresolved circular authoritative mutation is a global STOP with exact FP/CAP/Domain reporting. |
| Provider and evidence authority is protected | Provider, projection, Analytics and Audit state remain evidence or derived state rather than source-domain business authority. |
| Lifecycle integration is preserved | Section 8 references ATLAS-06 and does not create a synthetic cross-domain state machine. |
| Proof and TB boundary is preserved | Proof need informs the Phase 7C proof requirement and obligations; the separate post-7C / pre-Phase-8 classification gate selects reuse or a new Tracer Bullet, and proof need does not create a TB automatically. |
| Runtime boundary is preserved | No calls, events, messages, topics, queues, Resources, schemas, modules, caches or provider mechanisms are defined. |
| Existing views remain aligned | ATLAS-03 CAP ownership is unchanged; corrected ATLAS-04 relationships and the dependent ATLAS-05 exception semantics remain derived from current authority. |
| Selective context is explicit | A fresh active-FP planner can use the selected CAPs, relevant Domain exceptions, lifecycle projection, Section 8 rules and exact upstream references without a global graph. |
| Foundation remains intact | The existing Foundation Integrity Audit and applicable documentation tests pass. |
| Working boundary is preserved | The Atlas remains derived, working, non-authoritative and unfrozen, and no authority document or manifest changes. |
| Next work is stopped | ATLAS-08, participant-journey work, FP-001 preparation, JIT Dossiers, TBs, VSs, HHs and TOONs were not started. |

## 26.9 ATLAS-07 review protocol

The ATLAS-07 delivery review uses the following protocol:

1. inspect the full diff;
2. confirm the starting `main` SHA contains the approved ATLAS-06 baseline;
3. confirm the branch and changed-file set contain only the working Atlas;
4. run the Foundation Integrity Audit and existing documentation tests;
5. run `git diff --check`;
6. run a focused Section 8 audit for zero global dependency-graph rows, no placeholder, exactly five conceptual classes with separate readiness/gate metadata, seven reference-oriented seams, ATLAS-05 reference discipline, active-FP-only projection, selective context and the permanent safety boundaries;
7. confirm no runtime mechanism, implementation artifact, synthetic lifecycle or upstream authority change was introduced;
8. confirm that pre-existing untracked `AGENTS.md` and `.agents/` material remains untouched;
9. record any contradiction or escalation with its exact FP/CAP/Domain, source references, deciding authority and minimum safe resolution; and
10. report `PASS` only when every requirement above is evidenced. Otherwise report `STOP` with the exact route.

## 26.10 ATLAS-08 completion standard

ATLAS-08 is ready for review only when the evidence shows all of the following:

| Requirement | Evidence in this artifact |
|---|---|
| No exhaustive permanent participant journey map | Section 9 records `0` global journey-map rows and keeps only the compact boundary register. |
| Old Section 9 placeholder removed | Section 9 contains no population placeholder and no comprehensive mature-platform journey table. |
| Permanent boundary register stays compact | Section 9 contains `7` participant-boundary/invariant rows and no row per Feature Pack. |
| Product/Roadmap outcomes remain authoritative | Section 9 references Product Law and the Roadmap without creating a second participant timeline or Feature Pack-by-journey matrix. |
| ATLAS-05 Domain semantics are not duplicated | Section 9 references Domain participation and ownership-sensitive exceptions rather than creating a Domain × Feature Pack or journey matrix. |
| ATLAS-06 lifecycle semantics are not duplicated | Section 9 references lifecycle obligations and creates no participant-facing state machine or lifecycle states. |
| ATLAS-07 dependency semantics are not duplicated | Section 9 references dependency seams and creates no replacement dependency graph or shared-write rule. |
| Frontend boundary is preserved | No routes, pages, screens, forms, buttons, navigation, loaders, redirects, components, exact copy or interaction workflows are defined. |
| No Product promises are invented | Every permanent boundary and projection field is constrained to existing upstream authority and named gates. |
| Safety/privacy/access authority is preserved | Eligibility, consent, purchaser/participant separation, professional scope, entitlement, revocation, deletion and recovery boundaries remain references to existing authority. |
| Active-FP projection is temporary and non-authoritative | Section 9.6 defines the active-FP derivation path, required fields, rebuild trigger and non-authoritative boundary. |
| Selective context is deterministic | Section 9.9 defines the bounded Product/Roadmap → ATLAS-04 → ATLAS-05/06/07 → participant-boundary retrieval path. |
| No unnecessary JIT/TB/VS artifacts are created | Sections 9.6 and 9.9 keep review prompts advisory; the approved outcome and source-owned gates determine whether downstream artifacts are required. |
| Section 10 remains untouched | Staff/operator journey progression remains a template-only section and was not populated or redesigned by ATLAS-08. |
| Working boundary is preserved | The Atlas remains derived, working, non-authoritative, unfrozen and outside authority-document records, with its path listed only under graph/navigation paths;  no upstream document changed. |
| Next work is stopped | ATLAS-09, staff/operator journey work, FP-001 preparation, JIT Dossiers, TBs, VSs, HHs and TOONs are not started by this change. |

## 26.11 ATLAS-08 review protocol

The ATLAS-08 delivery review uses the following protocol:

1. inspect the full diff;
2. confirm the starting `main` SHA contains the approved ATLAS-07 baseline;
3. confirm the branch and changed-file set contain only the working Atlas;
4. run the Foundation Integrity Audit and existing documentation tests;
5. run `git diff --check`;
6. run a focused Section 9 audit for zero global journey-map rows, no placeholder, a compact permanent boundary register, no Feature Pack-by-journey matrix, no UI design, no lifecycle states, preserved safety/privacy/access references, temporary non-authoritative projection and untouched Section 10;
7. confirm that no Product, Architecture, Domain, Roadmap or authority-manifest change was introduced;
8. confirm that pre-existing untracked `AGENTS.md` and `.agents/` material remains untouched;
9. record any contradiction or escalation with its exact participant outcome, Feature Pack, CAP, Domain, source references, deciding authority and minimum safe resolution; and
10. report `PASS` only when every requirement above is evidenced. Otherwise report `STOP` with the exact route.

## 26.12 ATLAS-09 completion standard

ATLAS-09 is complete at its current scope only when the evidence shows all of the following:

| Requirement | Evidence in this artifact |
|---|---|
| Permanent operator rows are zero | Section 10 records permanent actor/work rows as `0`. |
| Old Section 10 placeholder is removed | Section 10 contains a derivation contract and no Staff × Feature Pack population table. |
| No permanent Staff × Feature Pack map exists | Operator context is active-FP-only and reconstructed from stronger canonical views. |
| Platform Operating Model is not duplicated | Section 10 references exact Operating Model anchors without copying complete role, Command Centre, Work, cadence, dashboard, support, scheduling or mobile doctrine. |
| Frontend operator doctrine is not duplicated | Section 10 references the frozen Frontend Experience System and creates no route, screen, dashboard or component design. |
| Role authority is preserved | The role, relationship, purpose, scope and business-authority distinction is explicit; no role-permission matrix exists. |
| Work authority is preserved | Work remains attention over Domain-owned truth; no universal Task, Work, Assignment, Review or Admin Domain or business lifecycle is created. |
| Projection authority is preserved | Command Centre, queues, dashboards, timelines, analytics, saved views and notifications remain projections. |
| Active-FP projection is defined | The temporary, non-authoritative projection has bounded task-shaped fields and exact provenance. |
| Selective context is deterministic | Roadmap → ATLAS-04 → ATLAS-05 → ATLAS-06 → ATLAS-07 → ATLAS-08 → relevant operating/frontend anchors → temporary projection is explicit. |
| Existing gates remain unresolved | Named OQs are referenced only where relevant and are not resolved or duplicated. |
| JIT artifacts remain gated | Approved outcomes and source-owned gates determine whether Domain, workflow, frontend, proof or hardening artifacts are required; optional review prompts can help identify candidates. |
| Next work is stopped | Section 11, FP-001 preparation, JIT Dossiers, TBs, VSs, HHs, TOONs and implementation code are not started. |
| Authority and working boundary remain intact | No Product, Architecture, Domain, Roadmap, Open Work or authority-manifest source is changed; the Atlas remains working, non-authoritative, unfrozen and implementation-inert. |

Permanent actor/work rows: `0`.

## 26.13 ATLAS-09 review protocol

The ATLAS-09 implementation review uses the following protocol:

1. inspect the full diff;
2. confirm the starting `main` SHA, branch and synchronized `origin/main` baseline;
3. confirm that only the working Atlas changed;
4. run `git diff --check`;
5. run the existing documentation tests and Foundation Integrity Audit;
6. run a focused Section 10 audit for zero permanent actor/work rows, removed placeholder, no Staff × Feature Pack matrix, no role-permission matrix, no universal Task/Admin Domain, no duplicated Work lifecycle, no frontend/dashboard design and temporary non-authoritative projection;
7. confirm Section 11 remains untouched;
8. confirm no upstream authority, authority manifest, JIT dossier, proof, slice, hardening or implementation artifact changed;
9. record any contradiction or escalation with the exact actor, active Feature Pack, CAP, Domain, source, deciding authority and minimum safe resolution; and
10. report `PASS` only when every requirement above is evidenced. Otherwise report `STOP` with the exact route.

## 26.14 ATLAS-10 completion standard

ATLAS-10 is complete at its current scope only when the evidence shows all of the following:

| Requirement | Evidence in this artifact |
|---|---|
| Permanent frontend surface rows are zero | Section 11 states `0`; no permanent surface register or Surface × Feature Pack rows exist. |
| Old Section 11 placeholder is removed | Section 11 contains the Frontend JIT Derivation Contract and no population placeholder. |
| No Surface × Feature Pack matrix exists | Frontend context is derived for the active Feature Pack only. |
| No second frontend taxonomy is created | Section 11 references exact frozen Frontend Experience System sections rather than defining a new permanent enum. |
| Frozen frontend doctrine is not duplicated | Stable frontend, interaction, design-system, accessibility, SEO, analytics and performance rules remain in the frozen Frontend Experience System. |
| Roadmap sequencing is not duplicated | Roadmap remains the source of Feature Pack outcomes, sequencing, dependencies and gates; ATLAS-04 remains the source of capability introduction and reuse. |
| ATLAS-08 participant boundaries are not duplicated | Section 11 consumes only the applicable temporary participant boundary and does not create a journey map or participant table. |
| ATLAS-09 operator workflow is not duplicated | Section 11 consumes only the applicable operator projection and does not create a Work, role or operator table. |
| Presentation remains non-authoritative | Frontend state, routes, LiveView assigns, dashboards, queues and optimistic interactions cannot create or replace Domain truth. |
| Frontend surface is not implementation structure | No routes, pages, LiveViews, modules, layouts, components, files, CSS, folders or API contracts are defined. |
| No business lifecycle is created | Presentation states are referenced through FES; Domain lifecycle remains governed by ATLAS-06 and JIT Domain Dossiers. |
| Temporary active-FP projection is explicit | Section 11.10 defines the bounded, rebuildable and non-authoritative projection fields. |
| JIT frontend-contract trigger is explicit | Section 11.11 distinguishes new frontend design triggers from straightforward reuse. |
| Selective context is deterministic | Section 11.19 defines the Roadmap → ATLAS-04 through ATLAS-09 → FES → temporary projection path. |
| Existing gates remain unresolved | Section 11.20 references applicable OQs without resolving or duplicating them. |
| Section 12 was not started | Section 12 remains the existing authority/flow template with its population placeholder and no populated rows. |
| Working boundary is preserved | The Atlas remains derived, working, non-authoritative, unfrozen and outside authority-document records, with its path listed only under graph/navigation paths;  no upstream source changed. |
| Downstream work is stopped | No FP-001 preparation, frontend implementation contract, JIT Domain Dossier, TB, VS, HH, TOON or implementation code is created. |

Permanent frontend surface rows: `0`.

## 26.15 ATLAS-10 review protocol

The ATLAS-10 implementation review uses the following protocol:

1. inspect the full diff;
2. confirm the starting `main` SHA, branch and synchronized `origin/main` baseline;
3. confirm that only the working Atlas changed;
4. run `git diff --check`;
5. run the existing documentation tests and Foundation Integrity Audit;
6. run a focused Section 11 audit for zero permanent frontend rows, removed placeholder, no Surface × Feature Pack matrix, no new taxonomy, no routes/pages/components/files, no token or component catalogue, no duplicated FES state machines, no Roadmap re-expression, no ATLAS-08/09 duplication, explicit temporary projection, explicit JIT trigger and deterministic selective context;
7. confirm Section 12 remains untouched and template-only;
8. confirm no Product, Architecture, Domain, Roadmap, Decisions/Open Work or authority-manifest source changed;
9. confirm no Feature Pack preparation, JIT Dossier, proof, slice, hardening or implementation artifact was created;
10. record any contradiction or escalation with the exact active Feature Pack, actor, experience outcome, CAP, Domain, source, deciding authority and minimum safe resolution; and
11. report `PASS` only when every requirement above is evidenced. Otherwise report `STOP` with the exact route.

## 26.16 ATLAS-11 completion standard

ATLAS-11 is complete at its current scope only when the evidence shows all of the following:

| Requirement | Evidence in this artifact |
|---|---|
| Permanent source→consumer rows | Section 12 states `0`; no permanent source→consumer matrix is maintained. |
| Section 12 placeholder | The former Section-12 population placeholder is removed. |
| Current seven-class taxonomy | The former Section-12 flow-class table is removed. |
| New Section-12 taxonomy | Section 12 creates exactly `0` flow classes and no replacement flow enum. |
| Architecture boundary | Architecture remains authority for durability, projection, provider evidence, async, failure and scaling mechanisms. |
| Domain Map boundary | No ownership matrix or Domain ownership is duplicated or amended. |
| ATLAS-07 boundary | Existing dependency classes, seams, evidence rules and pressure vocabulary are referenced rather than duplicated. |
| Roadmap boundary | No Feature Pack-by-data-flow matrix or sequencing re-expression is created. |
| Authority ≠ movement | Data movement, references, projections, aggregates, caches and observations do not transfer mutation authority. |
| Authority ≠ acceleration | PostgreSQL authority remains distinct from cache, Redis, ETS, LiveView, PubSub, browser and CDN acceleration. |
| Provider evidence | Provider state remains evidence and is not frozen as platform business truth. |
| Privacy ownership | Privacy & Consent orchestrates rights; source Domains retain source-record ownership and fulfil consequences. |
| Analytics / Audit boundary | Analytics remains derived measurement and Audit & Evidence remains governed evidence; neither becomes source authority. |
| Lifecycle boundary | No universal data-flow lifecycle or state machine is created; ATLAS-06 remains lifecycle authority. |
| Temporary projection | An explicit active-FP, non-authoritative data projection contract is defined. |
| Freshness / rebuildability | Freshness, stale-use, rebuildability, withdrawal and failure questions are captured without TTLs or refresh mechanics. |
| Performance boundary | Broad pressure is retained; mechanism selection remains JIT under `OQ-039` and applicable proof. |
| Proof boundary | Proof need does not automatically create a Tracer Bullet. |
| Selective context | The active-FP derivation path is deterministic and bounded to relevant upstream references. |
| Section 13 boundary | Section 13 remains untouched and template-only. |
| Downstream boundary | No Feature Pack preparation, JIT Domain/Architecture dossier, frontend contract, TB, VS, HH, TOON or implementation code is created. |
| Authority manifest / working boundary | No upstream authority or manifest source changes; the Atlas remains working, non-authoritative, unfrozen and implementation-inert. |

## 26.17 ATLAS-11 review protocol

The ATLAS-11 implementation review uses the following protocol:

1. inspect the full diff;
2. confirm the starting `main` SHA, dedicated branch and synchronized `origin/main` baseline;
3. confirm that only `docs/history/platform/archive/DELIVERY_ATLAS_WORKING_v0.1.0.md` changed;
4. run `git diff --check`;
5. run the existing documentation/unit tests and Foundation Integrity Audit;
6. run a focused Section 12 audit for zero permanent source→consumer rows, removed placeholder, removed seven-class taxonomy, zero replacement taxonomy, no ownership or Feature Pack matrix, no schemas/indexes/cache mechanisms, no universal data-flow lifecycle, referenced ATLAS-07 vocabulary, explicit temporary projection, freshness/rebuildability/withdrawal questions, JIT/proof rules and deterministic selective context;
7. confirm Section 13 remains untouched and template-only;
8. confirm no Product, Architecture, Domain, Roadmap, Decisions/Open Work or authority-manifest source changed;
9. confirm no Feature Pack preparation, JIT Dossier, frontend contract, proof, slice, hardening or implementation artifact was created;
10. record any contradiction or escalation with the active Feature Pack, source fact/evidence, owner, consumer, ATLAS-07 relationship, conflicting source, deciding authority and minimum safe resolution; and
11. report `ATLAS-11 PASS` only when every requirement above is evidenced. Otherwise report `ATLAS-11 STOP` with the exact route.

## 26.18 ATLAS reconciliation (`v0.3.0`) completion standard

This subsection records the completion standard for the post-Roadmap derived Atlas reconciliation. It is **not** an ATLAS-12 view-population contract. Open Work may continue to show `ATLAS-12 NOT_STARTED` because no ATLAS-12 contract was defined in this artifact.

Reconciliation is ready for review only when the evidence shows all of the following:

| Requirement | Evidence in this artifact |
|---|---|
| Versioned predecessor | Archived routing predecessor is `docs/history/platform/archive/DELIVERY_ATLAS_WORKING_v0.3.8.md`; its predecessor v0.2.3 remains preserved byte-identically at `docs/history/platform/archive/DELIVERY_ATLAS_WORKING_v0.2.3.md`. |
| Non-authority preserved | Artifact remains DERIVED / WORKING / NON-AUTHORITATIVE and outside authority-document records; its path is listed only under graph/navigation paths. |
| Current-source routing | §1.1 points to North Star/MVP `v1.3.0`, Product `v1.6.0`, Decisions `v1.6.0`, Architecture `v1.1.1`, Domain Map `v1.2.0`, Roadmap `v1.2.0` and current Open Work `v1.2.59`. |
| Feature Pack set | Exactly 17 Feature Packs `FP-001`–`FP-017`; no Research/Voting/Tools/PMR/Competitions Feature Pack. |
| Domain set | Exactly 20 Domains, including Domain 19 Research & Feedback and Domain 20 Voting & Balloting. |
| FP-001 status navigation | FP-001 and CAP-001 retain required IAM-owned PMR; PMR reconciliation and Identity v0.2.0 current-status promotion are COMPLETE / CERTIFIED, with the prior promoted/current v0.1.4 snapshot preserved in archive; Communications JIT Domain Dossier v0.1.0 is COMPLETE / CERTIFIED / CURRENT, with finalisation BLOCKED / STOP. |
| Research representation | CAP-032 / EX-011 show FUTURE-GATED / FEATURE-PACK-UNASSIGNED; not CAP-019; not FP-005/006/008/009/017. |
| Voting representation | CAP-033 / EX-012 show FUTURE-GATED / FEATURE-PACK-UNASSIGNED; not required by FP-008/FP-013; no Voting/Competitions FP. |
| Interactive Tools | No Tools CAP/Domain/FP; EX-013 preserves purpose-distributed `calculation != authority`. |
| Matrix truthfulness | Unassigned capabilities use zero material cells rather than fake introductions. |
| No new law | This derived routing successor creates or changes no Product, Architecture, Domain, Roadmap, AR-000, Operating Model or FES law; it does not amend FP-001 or HARDEN-02 or authorise implementation. |
| Classification | This work is `ATLAS_RECONCILIATION`, not `ATLAS-12`. |

## 26.19 ATLAS reconciliation review protocol

1. confirm base SHA is the certified post-Roadmap-amendment state;
2. confirm predecessor Atlas blob/hash is unchanged in `archive/`;
3. confirm only allowed derived/routing/test paths changed;
4. run `git diff --check`, focused Atlas tests, existing Atlas consistency tests, full unittest discovery and Foundation Integrity Audit;
5. confirm Feature Packs=17, Domains=20, Atlas outside authority-document records with graph/navigation path only, executable development blocked;
6. confirm contradiction count is zero or report STOP with exact upstream route;
7. report PASS only when every requirement above is evidenced.

- `v0.4.10` — PATCH tracker #120 closure provenance and current-source routing from main `3f4c9bf564b2b011e96171b8664428423eeba558`. Routes current Open Work v1.2.68 and preserves the completed Phase 7B, NEXT-only Phase 7C and downstream stops. No Atlas or delivery semantics change.

- v0.4.11 — PATCH current routing from baseline main 1a51755d505279821afe166b030be735fe0b6a1c. Routes Open Work v1.2.69, records Phase 7C candidate-authored / review-pending status under tracker #124, and keeps Phase 7B complete/current, proof unclassified, and Phase 8 unauthorised. Derived navigation only; no Atlas or delivery semantics change.


## 26.20 Phase 7C tracker closure routing (historical pre-classification status)

Phase 7A is COMPLETE. The required JIT dossier set is DISPOSITION-COMPLETE. Phase 7B reconciliation, Phase 7C and Final Feature Pack Contract v0.1.0 are COMPLETE / CERTIFIED / CURRENT. Issue #124 is CLOSED / COMPLETED after PR #126 resulting-main verification. PR #126 reviewed head `e7d5d3908bedf1a75c6627448c3ed0c067b076f8` merged as `69bef7bb2782cbff00a48505504ebd2686eb53d9`; both trees are `f5586314db6c3addab6482e866b8d781faba75bc`. Exact-head run 39141076412 passed. Resulting-main run 39143147487 passed with 455 tests, 728 Foundation Integrity assertions and 0 findings.

PHASE 7C EXECUTION/CONTROL TRACKER #124: CLOSED / COMPLETED
PROGRAMME ROUTER #111: OPEN
ARCHITECTURAL PROOF CLASSIFICATION: COMPLETE / FINALISED
PROOF CLASSIFICATION: NEW_TRACER_BULLET
ARCHITECTURAL PROOF REQUIREMENT / SELECTED PROOF VEHICLE: NEW_TRACER_BULLET
REUSE_EXISTING_PROOF: NOT SELECTED
TRACER BULLET: REQUIRED / NOT YET DEFINED
TRACER BULLET ID: NONE / NOT CREATED
ARCHITECTURAL PROOF EXECUTION: NOT STARTED
PHASE 8 / APPLICATION IMPLEMENTATION: UNAUTHORISED

- v0.4.12 — historical PATCH certification/current-status routing from resulting main `cfc63a7a77299cd59c98d88b57a88bb5b4ac29e5`. Routes Open Work v1.2.70 and records the completed PR #125 candidate/resulting-main lifecycle, while preserving proof classification as NOT FINALISED, Phase 8 as UNAUTHORISED, and the #124 tracker as OPEN through promotion verification. Derived navigation only; no Atlas or delivery semantics change.

- v0.4.13 — PATCH Phase 7C tracker-closure status and provenance after PR #126 resulting-main verification. Current Open Work is v1.2.71. The six affected Domains, seven material capability relationships and Atlas semantics are unchanged.


## 26.21 FP-001 architectural proof classification route (historical predecessor)

Phase 7A is COMPLETE. The required JIT dossier set is DISPOSITION-COMPLETE. Phase 7B reconciliation, Phase 7C and Final Feature Pack Contract v0.1.0 are COMPLETE / CERTIFIED / CURRENT. Issue #124 is CLOSED / COMPLETED, and programme router #111 remains OPEN.
PHASE 7C EXECUTION/CONTROL TRACKER #124: CLOSED / COMPLETED

ARCHITECTURAL PROOF CLASSIFICATION: COMPLETE / FINALISED
PROOF CLASSIFICATION: NEW_TRACER_BULLET
ARCHITECTURAL PROOF REQUIREMENT / SELECTED PROOF VEHICLE: NEW_TRACER_BULLET
REUSE_EXISTING_PROOF: NOT SELECTED
TRACER BULLET: REQUIRED / NOT YET DEFINED
TRACER BULLET ID: NONE / NOT CREATED
ARCHITECTURAL PROOF EXECUTION: NOT STARTED
DEVELOPMENT ENTRY HARD STOP CONDITION 9: SATISFIED
REMAINING DEVELOPMENT ENTRY HARD STOP CONDITIONS: NOT EVALUATED / MUST PASS BEFORE PHASE 8
PHASE 8: UNAUTHORISED
APPLICATION IMPLEMENTATION: UNAUTHORISED
NEXT GOVERNANCE ACTION: DEVELOPMENT ENTRY HARD STOP EVALUATION

Classification satisfies only Development Entry Hard Stop condition 9. Phase 8 and application implementation remain UNAUTHORISED until all other applicable conditions are independently evaluated and satisfied. OQ-035, OQ-036 and other expert, provider, release-only and future gates retain their current status. This Atlas is navigation only and is not the classification authority or event.

## 26.22 FP-001 Development Entry Hard Stop PASS current route (historical predecessor state)

PHASE 7C EXECUTION/CONTROL TRACKER #124: CLOSED / COMPLETED
PROGRAMME ROUTER #111: OPEN
ARCHITECTURAL PROOF CLASSIFICATION: COMPLETE / FINALISED
PROOF CLASSIFICATION: NEW_TRACER_BULLET
ARCHITECTURAL PROOF REQUIREMENT / SELECTED PROOF VEHICLE: NEW_TRACER_BULLET
REUSE_EXISTING_PROOF: NOT SELECTED
DEVELOPMENT ENTRY HARD STOP: PASS / ALL 10 CONDITIONS SATISFIED
PHASE 8: AUTHORISED (ARCHITECTURAL PROOF ONLY)
APPLICATION IMPLEMENTATION: AUTHORISED (BOUNDED PHASE 8 ARCHITECTURAL PROOF ONLY)
PHASE 9 / VERTICAL SLICES: NOT STARTED / NOT AUTHORISED
NEXT GOVERNANCE ACTION: NEW_TRACER_BULLET PROOF CONTRACT / TASK DEFINITION
TRACER BULLET: REQUIRED / NOT YET DEFINED
TRACER BULLET ID: NONE / NOT CREATED
ARCHITECTURAL PROOF EXECUTION: NOT STARTED

Development Entry Hard Stop evaluation independently satisfied all ten conditions. This Atlas is derived navigation only, remains DERIVED / NON-AUTHORITATIVE, and DOES NOT AUTHORISE IMPLEMENTATION; the bounded Phase 8 authorisation is recorded in current Open Work v1.2.74. OQ-035, OQ-036 and other expert, provider, release-only and future gates retain their current status.


## 26.23 FP-001 Phase 8 TB-001 candidate route (historical predecessor)

At the Open Work v1.2.75 predecessor state, FP-001 Architectural Proof Classification was COMPLETE / FINALISED as NEW_TRACER_BULLET. The proof contract was `docs/history/platform/archive/FP-001_TRACER_BULLET_CONTRACT_WORKING_v0.1.0.md`, identifier TB-001, CANDIDATE / REVIEW PENDING / NOT CERTIFIED. PROOF DESIGN: FROZEN TO THE ACCEPTED Q1–Q90 DECISIONS. PROOF EXECUTION: NOT STARTED. PROOF RESULT: NOT STARTED. PROOF CERTIFICATION: NOT STARTED. This Atlas remains derived navigation and does not authorize implementation. Current Open Work was v1.2.75. The contract predecessor is preserved at `docs/history/platform/archive/FP-001_TRACER_BULLET_CONTRACT_WORKING_v0.1.0.md`.

## 26.24 FP-001 Phase 8 TB-001 successor candidate route (historical predecessor)

FP-001 Architectural Proof Classification remains COMPLETE / FINALISED as NEW_TRACER_BULLET. The proof contract is `docs/history/platform/archive/FP-001_TRACER_BULLET_CONTRACT_WORKING_v0.1.1.md`, identifier TB-001, CANDIDATE / REVIEW PENDING / NOT CERTIFIED. PROOF DESIGN: FROZEN TO THE ACCEPTED Q1–Q90 DECISIONS. PROOF EXECUTION: NOT STARTED. PROOF RESULT: NOT STARTED. PROOF CERTIFICATION: NOT STARTED. The next governance action is TB-001 CONTRACT CANDIDATE REVIEW / CERTIFICATION. PHASE 9 / VERTICAL SLICES: NOT STARTED / NOT AUTHORISED. This Atlas remains derived navigation and does not authorize implementation. Current Open Work is v1.2.76.


## 26.25 FP-001 Phase 8 TB-001 successor candidate route (historical predecessor)

FP-001 Architectural Proof Classification remains COMPLETE / FINALISED as NEW_TRACER_BULLET. The proof contract is `docs/history/platform/archive/FP-001_TRACER_BULLET_CONTRACT_WORKING_v0.1.2.md`, identifier TB-001, CANDIDATE / REVIEW PENDING / NOT CERTIFIED. Its v0.1.1 predecessor is archived byte-identically; v0.1.0 remains archived. PROOF DESIGN: FROZEN TO THE ACCEPTED Q1–Q90 DECISIONS. PROOF EXECUTION: NOT STARTED. PROOF RESULT: NOT STARTED. PROOF CERTIFICATION: NOT STARTED. The next governance action is TB-001 CONTRACT CANDIDATE REVIEW / CERTIFICATION. PHASE 9 / VERTICAL SLICES: NOT STARTED / NOT AUTHORISED. This Atlas remains derived navigation and does not authorize implementation. Current Open Work is v1.2.77.

## 26.26 FP-001 Phase 8 TB-001 approved contract route (historical predecessor)

FP-001 Architectural Proof Classification remains COMPLETE / FINALISED as NEW_TRACER_BULLET. TB-001 CONTRACT/DESIGN REVIEW: COMPLETE / PASS. TB-001 CONTRACT STATUS: CURRENT / APPROVED FOR BOUNDED PHASE 8 PROOF EXECUTION; exact reviewed candidate bytes are preserved at `docs/history/platform/archive/FP-001_TRACER_BULLET_CONTRACT_WORKING_v0.1.2.md`. PROOF DESIGN: FROZEN TO THE ACCEPTED Q1–Q90 DECISIONS. PROOF EXECUTION: STARTED (BOUNDED; BASELINE MAIN SHA `c91016ecb75ea29adc9cc21e4bf30bab51dcdc3c`). PROOF RESULT: NOT STARTED. PROOF CERTIFICATION: NOT STARTED. PHASE 9 / VERTICAL SLICES: NOT STARTED / NOT AUTHORISED. NEXT EXECUTION ACTION: FP-001 P8 04 — Build the deterministic Phase-8 proof harness (WELL-5). This Atlas remains derived navigation and does not authorize implementation. Current Open Work is v1.2.79.


## 26.27 WELL-5 completion and P8-05 planning route (historical predecessor)

WELL-5 / P8-04 deterministic proof harness implementation is COMPLETE. PR [#141](https://github.com/JCSchoeman96/NewYou/pull/141) merged to main as `991a57ade059b9d9a2eaa8a788da8eeeee765d0e`. Reviewed head `6186545eb0b8d8c59388e364ece72df743a0f635` reached main with an identical Git tree.

Post-merge self-test run [40014798086](https://github.com/JCSchoeman96/NewYou/actions/runs/40014798086) passed. The post-merge current-state TB-001 run [40014798103](https://github.com/JCSchoeman96/NewYou/actions/runs/40014798103) returned INCOMPLETE / COVERAGE-INCOMPLETE. The ten required business/browser manifests remain unavailable. Full TB-001 architectural proof remains INCOMPLETE; proof certification is NOT CERTIFIED; Phase 8 is NOT CERTIFIED.

The harness is available to later authorised Phase-8 proof slices. The next execution unit is P8-05 / WELL-6 planning. WELL-6 must complete Grill-Me/JIT planning, spec/ticket decomposition and independent planning review before implementation. Phase 9 remains NOT STARTED / NOT AUTHORISED. This status route changes no Product, Architecture, Domain, Roadmap, TB-001 design or proof-obligation semantics.

## 26.28 WELL-5 completion and P8-05 planning route (historical predecessor)

WELL-5 / P8-04 deterministic proof harness implementation is COMPLETE. PR [#141](https://github.com/JCSchoeman96/NewYou/pull/141) merged to main as `991a57ade059b9d9a2eaa8a788da8eeeee765d0e`; reviewed head `6186545eb0b8d8c59388e364ece72df743a0f635` reached main with an identical Git tree.

The self-test passed. The current-state TB-001 run returned INCOMPLETE / COVERAGE-INCOMPLETE because ten required business/browser manifests remain unavailable. Full TB-001 architectural proof remains INCOMPLETE, proof certification is NOT CERTIFIED, and Phase 8 is NOT CERTIFIED.

The approved TB-001 contract remains CURRENT / APPROVED FOR BOUNDED PHASE 8 PROOF EXECUTION. P8-05 / WELL-6 planning is next; Grill-Me/JIT planning, spec/ticket decomposition and independent planning review must precede implementation. Phase 9 remains NOT STARTED / NOT AUTHORISED. Current Open Work is v1.2.81. This Atlas remains derived navigation and does not authorize implementation.

## 26.29 WELL-5 completion and P8-05 planning route (historical predecessor state; superseded by v0.4.24)

Current Open Work v1.2.82, FP-001 Skeleton v0.1.24 and HARDEN-02 v0.5.25 are the active status routes. Identity v0.2.0 is COMPLETE / CERTIFIED / CURRENT under PR #151. Its exact PR #150 candidate remains at `docs/history/platform/archive/FP-001_IDENTITY_ACCESS_JIT_DOMAIN_DOSSIER_WORKING_v0.2.0.md`; the promoted/current v0.1.4 snapshot remains separately preserved at `docs/history/platform/archive/identity_promotions/FP-001_IDENTITY_ACCESS_JIT_DOMAIN_DOSSIER_WORKING_v0.1.4.md`.

WELL-5 / P8-04 deterministic proof harness implementation is COMPLETE. Proof certification is not complete: the current TB-001 result is INCOMPLETE / COVERAGE-INCOMPLETE because ten required business/browser manifests remain unavailable. Full TB-001 architectural proof remains INCOMPLETE; Phase 8 is NOT CERTIFIED and Phase 9 / Vertical Slices remain NOT STARTED / NOT AUTHORISED.

Programme router #111 remains OPEN. This route preserves #120 as CLOSED / COMPLETED historical evidence for Phase 7B reconciliation. The accepted WELL-48 decisions for email canonicalisation, PMR representation and RegistrationOperation/request binding are canonically recorded by this promotion. P8-05 / WELL-6 Grill-Me/JIT planning and spec/ticket decomposition are complete. Independent planning review is COMPLETE / PASS WITH NON-BLOCKING CORRECTIONS. WELL-45 remains blocking; WELL-48 remains Backlog / non-executable. P8-05 implementation remains UNAUTHORISED pending the status promotion becoming effective, applicable implementation/JIT verification and explicit P8-05 implementation authorization. Application implementation remains AUTHORISED only inside the bounded Phase 8 Architectural Proof stage. Identity v0.2.0 is COMPLETE / CERTIFIED / CURRENT under PR #151; the exact PR #150 candidate and promoted/current v0.1.4 snapshot remain separately preserved in archive. This Atlas remains derived navigation and does not authorize implementation.


## 26.30 WELL-5 completion and P8-05 planning route (historical predecessor state)

Current Open Work v1.2.83, FP-001 Skeleton v0.1.25, HARDEN-02 v0.5.26, Roadmap v1.2.4 and Product Law v1.10.0 / DEC-316 are the active routes. Identity v0.2.0 remains COMPLETE / CERTIFIED / CURRENT under PR #151; its exact PR #150 candidate and prior promoted/current v0.1.4 snapshot remain separately preserved in archive.

WELL-5 / P8-04 deterministic proof harness implementation is COMPLETE. Proof certification is not complete: the current TB-001 result is INCOMPLETE / COVERAGE-INCOMPLETE because ten required business/browser manifests remain unavailable. Full TB-001 architectural proof remains INCOMPLETE; Phase 8 is NOT CERTIFIED and Phase 9 / Vertical Slices remain NOT STARTED / NOT AUTHORISED.

P8-05 / WELL-6 Grill-Me/JIT planning and spec/ticket decomposition are complete. Independent planning review is COMPLETE / PASS WITH NON-BLOCKING CORRECTIONS. The accepted WELL-48 decisions for email canonicalisation, PMR representation and RegistrationOperation/request binding remain canonically recorded. WELL-45 is LEGAL/PRIVACY RELEASE GATE OPEN — DEVELOPMENT BASELINE PERMITTED; it is not legally approved and does not block development in explicitly permitted non-production contexts. WELL-48 remains Backlog / non-executable.

P8-05 development eligibility requires current Product v1.10.0 / DEC-316, both immutable English development-baseline Terms/Privacy versions, all other applicable P8-05 JIT/implementation gates and explicit P8-05 implementation authorization. This route grants no P8-05 implementation authorization. Production and applicable real-participant release remain blocked until approved English Terms and Privacy versions and required legal/privacy approval evidence exist, and all other release gates pass.
P8-05 implementation remains unauthorised; this route grants no P8-05 implementation authorization.

This Atlas remains derived navigation and does not authorize implementation. Bounded Phase 8 proof remains authorised globally but incomplete and not certified. Phase 9 remains NOT STARTED / NOT AUTHORISED.


## Current P8-05 implementation authorization

P8-05 / WELL-6 IMPLEMENTATION: AUTHORISED — BOUNDED PHASE 8 ARCHITECTURAL PROOF ONLY

PHASE 8: NOT CERTIFIED

TB-001 PROOF RESULT: INCOMPLETE / COVERAGE-INCOMPLETE

PHASE 9 / VERTICAL SLICES: NOT STARTED / NOT AUTHORISED

WELL-45: LEGAL/PRIVACY RELEASE GATE OPEN — DEVELOPMENT BASELINE PERMITTED; NOT LEGALLY APPROVED

WELL-48: COMPLETE / MERGED VIA PR #156; WELL-49: BLOCKED / WAITING ON WELL-61; WELL-50: BACKLOG / NOT STARTED. WELL-50's agreed WELL-48 Account/PMR contract is complete; its own gates remain. WELL-51 follows the required WELL-48–50 seams and owns the first integrated acceptance boundary; WELL-52 follows WELL-51, and WELL-53 follows WELL-48–52 and closes the P8-05 proof outcome.

This authorization does not authorize production, public or applicable real-participant release, Phase 9, Phase 8 certification or legal approval. Current Product Law v1.12.0 continues to permit the immutable English development baselines under DEC-316 for governed non-production development; those baselines are not legally approved. Approved English Terms and Privacy and approval evidence remain required for production and applicable real-participant release.


## 26.31 WELL-60 Communications no-lost-handoff candidate route (historical predecessor)

WELL-60 has prepared a proposed Model B successor. P8-05 commits `MessageIntent` and the required protected envelope with valid source acceptance; it does not require a Communications Oban job. P8-10/WELL-10 owns durable intent discovery/recovery, AshOban/Oban scheduling, and the real Communications executor lifecycle. The successor remains pending independent review and is not current authority. WELL-49 remains blocked by WELL-60 and WELL-61. This derived route changes no Product, Decision, Architecture, Domain, or Roadmap authority.

## 26.32 WELL-60 TB-001 v0.1.3 current-status promotion route (historical predecessor state)

WELL-60 is OPEN with its status-promotion candidate ready for independent Master Gate review. TB-001 v0.1.3 is CURRENT / APPROVED FOR BOUNDED PHASE 8 PROOF EXECUTION, with contract/design review COMPLETE / PASS. PR #164 reviewed head `73725a3d3339bf07fdcd44b9a7ec86026db3e984` merged as `429677295a396b8c78e9ab6b436a57d9249eaddc`; resulting tree `c947544000f66c104a51240e2aee3d0d123b23ec`. Exact candidate bytes remain pinned at `docs/history/platform/archive/FP-001_TRACER_BULLET_CONTRACT_WORKING_v0.1.3.md`. TB-001 proof remains INCOMPLETE / COVERAGE-INCOMPLETE; Phase 8 is NOT CERTIFIED and Phase 9 is NOT AUTHORISED. WELL-49 remains blocked by WELL-60 and WELL-61; WELL-61 remains PLANNING / INCOMPLETE. This route changes status, routing and evidence only and changes no authority or Model B semantics.


## 26.33 WELL-60 post-merge tracker closure

WELL-60 is COMPLETE after PR #165 passed exact-head Master Gate review, merged unchanged and passed resulting-main required CI. Certified head `98ad1ce5ef33cf10183cda68802b623afcf41378`; merge/resulting main `ac8b7c7eeaddd2001c3ad3e2a8fbce46296b0a40`; resulting tree `8d98e9db1780cbd45885b5d0859ecf2987b57a28`; resulting-main workflow `41031269566` PASS. TB-001 v0.1.3 remains current. The reviewed Model B boundary is settled and unchanged: P8-05/WELL-49 commits durable `MessageIntent`, required source/provenance and the protected-delivery envelope at source acceptance without requiring Communications Oban scheduling; P8-10/WELL-10 owns discovery/recovery, real AshOban/Oban scheduling, current source/content/capability checks, `DeliveryAttempt` admission and later provider I/O, observation, retry and reconciliation. Initial Audit E2 scheduling remains unchanged and atomic under its separate contract.

WELL-49 remains BLOCKED / WAITING ON WELL-61 and must not start until every applicable prerequisite clears. WELL-61 remains PLANNING / INCOMPLETE. Its exact-byte English/Afrikaans approvals, current Content role grant for `verification_message_lifecycle`, and per-locale Content & Media eligibility decisions remain outstanding; no WELL-61 evidence changed here. No WELL-49 execution has started. TB-001 proof remains INCOMPLETE / COVERAGE-INCOMPLETE and NOT CERTIFIED; Phase 8 remains NOT CERTIFIED and Phase 9 remains NOT STARTED / NOT AUTHORISED. This is status and routing only; no authority or Model B semantics changed.
