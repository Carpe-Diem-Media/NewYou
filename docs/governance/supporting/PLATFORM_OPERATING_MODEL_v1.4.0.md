# PLATFORM_OPERATING_MODEL_v1.4.0.md

- **Document status:** CURRENT / SUPPORTING PLATFORM OPERATING MODEL v1.4.0
- **Document version:** v1.4.0
- **Predecessor:** `docs/governance/supporting/PLATFORM_OPERATING_MODEL_v1.3.0.md`
- **Earlier frozen baseline:** `docs/history/platform/archive/PLATFORM_OPERATING_MODEL_v1.0.1.md`
- **SemVer transition:** `v1.3.0 → v1.4.0` — solo-founder merge workflow.
- **Date:** 2026-11-12
- **Derived experience provenance:** `docs/delivery/feature-contracts/experience/EXPERIENCE_DECISIONS_WORKING_v0.7.0.md` (working, non-authoritative)
- **Authority basis at this model's freeze:** `docs/history/platform/archive/PROJECT_NORTH_STAR_AND_MVP_v1.2.1.md`, `docs/history/platform/archive/00_PLATFORM_v1.2.1.md`, `docs/history/platform/archive/01_DECISIONS_v1.2.2.md`, `docs/history/platform/archive/02_OPEN_WORK_v1.2.28.md`, `docs/history/platform/archive/03_ARCHITECTURE_v1.0.0.md`, `docs/history/platform/archive/04_DOMAIN_MAP_v1.0.0.md`, `docs/history/platform/archive/05_ROADMAP_v1.0.0.md`
- **Upstream authority order:** Product Law → Architecture Law → Domain Law → Roadmap
- **Implementation status:** this model grants no runtime business capability or production/release authority.
- **Authority boundary:** Product Law → Architecture Law → Domain Law → Roadmap remain upstream. This document governs stable human/operating workflow beneath those authorities; it must not invent business truth, implementation schemas or unresolved expert policy. Durable authority plus dependency-cleared Plane `Ready` governs implementation permission; that permission is separate from runtime role/grant authority.
- **JIT boundary:** This document intentionally stops before exact Resource/action/schema/queue/topic/threshold/provider configuration. Those details belong to the affected Feature Pack and JIT dossiers/contracts.

## v1.3.0 Amendment Scope

This successor records JC's current sole-developer/operator freedom for authorized non-production engineering while keeping runtime roles and all business/release authority governed separately. It consumes DEC-320 and does not create production capability.

## v1.2.0 Amendment Scope

This successor aligns staff-role operation with Product Law v1.11.0 and DEC-317/DEC-318. It defines the expected multi-role operator bundle, Platform Administrator's ordinary delegation boundary, Super Admin's exceptional approval role, governed bootstrap/recovery and the Domain-sensitive approval boundary. GOVERNED BOOTSTRAP AUTHORITY establishes the initial role/scope grants as a sealed root-of-trust transition; it is neither a person nor a capability holder. Identity & Access owns durable grants; Domain owners retain authority over business capabilities and approval requirements. This operating model does not authorise runtime implementation or create expert authority.

## v1.1.0 Amendment Scope

This narrow semantic successor aligns the translation operating rules with Product Law v1.10.0 and DEC-316. The platform remains bilingual, while governing Terms and Privacy document bodies use one authoritative English version. All other required participant-facing bilingual content and approval rules remain in force. This changes no implementation representation or authority ownership.

---

# 1. Purpose

Define how participants, staff, analysts, reviewers and operators use NewYou day to day.

The operating model is **workflow-first, not CRUD-first**:

> Humans should see meaningful work, decisions, exceptions, queues and outcomes rather than navigate database-shaped screens.

This document describes the stable operating model that Feature Packs may instantiate incrementally. It does not require the full mature operating surface to exist in FP-001.

---

# 2. Repo-alignment rules

1. Every durable business truth remains owned by exactly one Domain.
2. Administration, support screens, dashboards and work queues are UI/operating projections; they do not create new Domains.
3. Cross-domain action invokes the owning Domain; the operating UI never becomes a second business-write API.
4. PostgreSQL remains the default structured business authority.
5. Oban remains the default durable asynchronous executor.
6. PubSub/LiveView improve freshness and interaction but do not become durable truth.
7. Analytics remains derived from governed authoritative facts.
8. Exact packages, Resources, tables, indexes, Redis keys, TTLs, worker names, PubSub topics, provider configuration and UI component structure remain JIT unless already frozen upstream.
9. Unresolved OQs remain gates for the affected production capability and are not silently answered by workflow design.
10. Phase 7 remains planning/preparation; executable development begins only after the existing development-entry gates are met.

---

# 3. Core operating principles

1. **Role-aware Command Centre** is the default staff landing surface.
2. **Work is attention, not authority.** Domain owners retain the underlying business truth.
3. Required work is distinct from informational notifications and transient toasts.
4. Sensitive/high-risk operations use explicit policy, current authority and durable evidence.
5. Participants follow journeys and next authorised actions rather than internal Domain structure.
6. Content operations use **Library + Work Queue + Editorial Calendar**.
7. Analytics uses a small set of trustworthy purpose-built dashboards; no general dashboard builder is required.
8. Business-significant scheduled work is durable and revalidates current Domain authority when executed.
9. SEO is an experience/publishing quality requirement from the first relevant public slice.
10. Operational decisions and material changes remain sufficiently traceable for support, audit and governed review.

---

# 4. Staff roles and operator organisation

## 4.1 Product-Law staff baseline

Initial staff categories remain:

- Support
- Finance
- Platform Administrator
- Super Admin
- Content
- Moderator
- Data Analyst
- Event Admin
- Developer

One identity may hold multiple explicit, removable and auditable roles. Platform Administrator is the broad day-to-day platform administration role and ordinary operational delegator.

Clinical, methodology, practitioner, cohort/facilitation and other later authority is granted only through the relevant approved role/relationship/scope. There is no universal Super Admin bypass.

When governed runtime staff roles are provisioned, the expected initial operator bundle is Platform Administrator and Developer, with dormant Super Admin break-glass and other authorised non-expert role/scope grants where needed. JC may be an initial subject, not the source of any capability. Any subject with the same valid grants has the same authority. Bootstrap establishes grants under Product Law §15.1B; it does not confer expert authority. This later runtime provisioning does not gate ordinary authorized software development.

Platform Administrator delegates only ordinary non-sensitive operational role/scope grants within its governed catalogue. Super Admin independently approves platform-operational privileged grants to another identity, under break-glass protections. Domain-sensitive grants require their designated Domain approval. Content lifecycle actions require the Content & Media role/scope and applicable approval. Product Law governs classification, evidence, recovery and privileged authentication.

## 4.1A Non-production development execution

Development execution authority is separate from runtime role/grant authority. Durable authority plus a dependency-cleared Plane `Ready` ticket is sufficient permission to implement. A developer does not additionally require a materialised runtime Account, IdentityGrant, staff-role assignment or production capability grant merely to write, migrate, seed, execute, inspect or test authorised software. A runtime authorization mechanism or real operator identity cannot be a prerequisite for developing that same mechanism or its dependent feature, unless an external real-world requirement is intrinsically necessary even for the bounded development action. Any such exception must be explicit, narrowly scoped and justified by governing authority; a future production role requirement alone is insufficient.

JC is currently the sole developer/operator and may perform all authorised non-production engineering and administration required for delivery, including migrations and seeds, database reset/rebuild, test-data creation and deletion, synthetic user/account creation, synthetic role/grant creation, privileged-path exercise, invoking private development/test interfaces, inspecting internal state, simulating different staff/business roles, and testing failure, recovery and revocation paths. Local, automated-test, development and explicitly bounded proof environments may create deterministic synthetic Accounts, identities, synthetic roles and grants, relationships and fixtures needed to exercise every authorization path. Their use grants no production authority.

Runtime role/capability semantics remain mandatory design and test work: authorised actions, denied actions, missing grants, wrong scopes, expired and revoked grants, sensitive-role boundaries and relevant audit behaviour. Development-only fixtures, seeds, bypasses and synthetic grants must be impossible or fail closed in production/release contexts. JC's non-production engineering freedom creates no production role, public-release authority, paid-pilot authority, real-participant authority, Content publication authority, clinical authority, safety authority, legal/privacy approval authority, financial approval authority, Domain-business authority or Super Admin production bypass. Actual runtime/release actions remain subject to governed Accounts, roles, scopes, grants, approvals and release gates. `NewYou.Identity.Account` remains the canonical runtime identity.

## 4.2 Operator information architecture

The staff application may organise work under experience groupings such as:

- **Home / Command Centre**
- **Work**
- **People**
- **Content**
- **Health & Plans**
- **Programmes**
- **Commerce**
- **Community & Events**
- **Communications**
- **Experiments**
- **Analytics**
- **Platform / Audit / Configuration**

These are navigation/operating groupings only. They do not amend the 20-Domain ownership model in the current Domain Map.

---

# 5. Command Centre

The Command Centre answers:

- What needs my attention?
- What am I responsible for?
- What is unassigned?
- What is overdue or at risk?
- What is scheduled or upcoming?
- What exceptions/incidents are active?
- What important data/platform conditions should I know?

Role, relationship, purpose and current policy determine what is visible and actionable.

Typical emphasis may include:

- **Content:** drafts, reviews, translation gaps, scheduled publication, review dates, publication exceptions.
- **Finance:** payment/reconciliation exceptions, refunds/disputes, commercial operational indicators.
- **Support:** participant cases, identity/access/entitlement/payment issues permitted to Support.
- **Moderator:** moderation queue, sanctions/appeals permitted by Community law.
- **Data Analyst:** data quality, canonical dashboards, experiment evidence where authorised.
- **Event Admin:** event/live operational work when those capabilities enter scope.
- **Developer/Platform:** technical operational/release evidence without unrelated business-data access.

Specific clinical/safety work appears only for actors holding the required scoped authority.

---

# 6. Work operating contract

NewYou presents a unified **Work** experience over Domain-owned obligations.

## 6.1 Important boundary

The following is a **common operator presentation vocabulary**, not a universal `Task` Resource or new authoritative Domain lifecycle.

A specific Domain may expose work using its own Resource/state machine and map it into this operating vocabulary.

## 6.2 Common presentation states

Where applicable:

- `UNASSIGNED`
- `ASSIGNED`
- `IN_PROGRESS`
- `CHANGES_REQUESTED`
- `RESOLVED`

`CANCELLED` is shown only where the owning workflow actually permits cancellation.

## 6.3 Common transitions

| From | Operator transition | To | Guard | Operating consequence |
|---|---|---|---|---|
| UNASSIGNED | claim / assign | ASSIGNED | actor may handle work | assignment becomes visible |
| ASSIGNED | start | IN_PROGRESS | current authority still valid | work becomes active |
| IN_PROGRESS | request changes | CHANGES_REQUESTED | owning workflow supports review return | reviewer context preserved |
| CHANGES_REQUESTED | resume | IN_PROGRESS | responsible actor authorised | work resumes |
| IN_PROGRESS | resolve | RESOLVED | owning Domain outcome/criteria satisfied | work closes in projection |
| non-terminal | reassign | ASSIGNED | owning workflow permits | responsibility changes |

## 6.4 Guards

- Queue visibility never grants business-action authority.
- Self-approval is allowed only where the relevant policy permits it.
- Separation of duties is required where governing law says so.
- Bulk action is allowed only if every selected item can still pass its own policy and invariants.
- Due/target times and escalation thresholds are workflow-specific and remain JIT/policy where not already frozen.

---

# 7. Work, Notification and Toast

- **Work:** action is required.
- **Notification:** information is useful to the actor.
- **Toast:** transient UI acknowledgement.

Required work must never exist only as a toast, email or ephemeral LiveView state.

---

# 8. Notes, timeline and participant support

## 8.1 Internal notes

Internal notes are scoped to the relevant case/work context and remain distinct from:

- participant-visible communication;
- professional/clinical records;
- append-only audit evidence.

## 8.2 Human-readable timeline

Important records may expose a curated, permission-aware business timeline derived from authoritative/audit facts.

The timeline is a read projection and never becomes a second source of truth.

## 8.3 Support workspace

Support sees the minimum permitted context necessary to resolve the issue.

Sensitive health/professional information requires explicit current authority.

Routine impersonation is prohibited. Prefer safe preview/simulation; true impersonation, if ever justified, requires separate governed design and audit.

---

# 9. Content operating model

Content operations use three coordinated surfaces:

- **Library** — what content exists?
- **Work Queue** — what requires action?
- **Editorial Calendar** — what is publishing/releasing when?

Content & Media remains the authoritative Domain for governed content/translation/publication versions and editorial media.

---

# 10. Content creation and composition

A content item:

1. begins as an authorised idea/request or direct draft;
2. selects a governed content type;
3. has an explicit responsible editor/owner while active;
4. uses approved reusable blocks, sections, components and patterns;
5. receives risk classification early enough to derive the correct review path;
6. passes all applicable scoped Product-Law approvals;
7. is previewed;
8. is published now or scheduled;
9. is monitored and later corrected, superseded or withdrawn as required.

The approved content-type catalogue is extensible and currently includes the Product-Law identifiers `article`, `lesson`, `devotional`, `recipe`, `plan_instruction`, `assessment_interpretation`, `safety_notice`, `faq`, `product_page`, `event_page`, `live_session` and `download`.

Reusable templates may precompose approved structures, slots and defaults. Template changes must not silently rewrite immutable published versions unless explicitly designed to do so.

---

# 11. Content risk and approval

Product-Law risk classes remain:

- `editorial_low_risk`;
- `health_education`;
- `personalisation_guidance`;
- `clinical_guidance`;
- `safety_critical`;
- `legal_or_consent`.

Approval authority follows content risk, language and professional scope, with required approvals recorded separately. Language approval and clinical/professional approval remain distinct; one person may hold several roles, but each approval is separately recorded.

Low-risk content must not inherit unnecessary specialist bureaucracy.

Exact routing rules belong to the affected JIT Content Domain/Resource dossier where not already frozen.

---

# 12. Translation operating lifecycle

Translation must preserve frozen Product Law.

At this model's freeze, Product Law §21E.2 (`docs/history/platform/archive/00_PLATFORM_v1.2.1.md`) defined the operational translation identifiers below. They refined, rather than replaced, DEC-125 (`docs/history/platform/archive/01_DECISIONS_v1.2.2.md`): DEC-125's `draft / machine-draft`, `review`, `approval`, `publication`, `superseded` and `withdrawn` semantics map to `draft → machine_draft`, `language_review` plus any required `clinical_review_required`, `approved`, `published`, `superseded` and `withdrawn`. Where clinical review is not required by risk, `language_review` proceeds to `approved`.

## States

- `missing`
- `draft`
- `machine_draft`
- `language_review`
- `clinical_review_required` (where the content risk requires it)
- `approved`
- `published`
- `superseded`
- `withdrawn`

These states are independently governed per language variant.

## Core transition intent

`missing → draft → machine_draft → language_review → clinical_review_required (where required) → approved → published`

Published translation may later become:

`published → superseded`

or:

`published → withdrawn`

## Guards

- Machine translation creates draft material only, records its source version and becomes stale when the source changes.
- Human language review remains required; clinical/professional review is an additional distinct step where the content risk requires it.
- Registration/authentication, checkout/subscriptions, participant-facing consent/privacy notices, assessments, paid reports, personalised plans, safety/clinical warnings, cancellation/refund communication and core onboarding require approved Afrikaans and English variants. The governing Terms and Privacy document bodies are the narrow English-only exception in §12.1.
- Optional low-risk editorial content may use only the explicit fallback rule: state that the selected translation is unavailable and offer the available language without silently switching.
- Paid or contractual content, participant-facing consent/privacy notices, assessments, plans, clinical or safety content, and core-onboarding content are blocked from publication/delivery until their required approved translations exist; an unapproved machine fallback is never used. The governing Terms and Privacy document bodies are published only as the approved English versions under §12.1; no Afrikaans legal translation or runtime translation is used.

Exact Ash Resource/action representation remains JIT.

## 12.1 Governing Terms and Privacy documents

The governing Terms and Conditions and Privacy Policy / Privacy Notice are maintained as immutable English-only legal documents. Both Afrikaans and English product experiences link to the same English versions. No official Afrikaans legal translation is required or maintained. This exception applies only to those governing document bodies and does not change the bilingual requirements for participant-facing UI, consent/privacy notices, assessments, plans, clinical or safety content, core onboarding, verification UI or general paid content.

Each version is tied to its immutable content/version ID, document type, `en` locale, exact content, applicability status, approval state and approval reference/date when approved, with its supersession or withdrawal relationship. Development-baseline versions are explicitly marked `DEVELOPMENT BASELINE / NOT LEGALLY APPROVED` and are usable only in the non-production contexts expressly allowed by current Product Law. Legal approval creates a separate immutable version; it never changes a baseline in place. Current Product Law requires production and applicable real-participant release to fail closed without approval evidence for the exact selected versions. This operating model does not claim legal sufficiency or add an implementation schema.

---

# 13. Publication, correction and withdrawal

Publication must preserve immutable/versioned content history where Product Law requires it.

Every material edit creates a new immutable and traceable content version.

Scheduled publication:

- revalidates approval/current policy before publication;
- is idempotent;
- is observable;
- has durable failure/recovery handling.

`OQ-016` remains the authority gate for exact publication scheduler reliability, retry policy, alert ownership, stale-approval checks and recovery.

Correction handling preserves the Product-Law classes:

- `minor_editorial_correction`;
- `material_content_correction`;
- `safety_correction`;
- `legal_or_consent_correction`;
- `full_withdrawal`.

Handling is proportional to the correction class.

---

# 14. Media operations

Use a governed Media Library supporting, where applicable:

- source/provenance;
- metadata;
- rights/attribution;
- derivatives;
- usage references;
- replacement/version semantics.

Exact media Resources, storage keys, derivative pipelines and provider configuration remain JIT.

---

# 15. Content-led acquisition

Public NewYou is **content-first and value-first**.

The public header keeps:

- Create account
- Log in
- language switching

clearly discoverable without aggressive signup pressure.

Preferred relationship progression:

`useful public content → relevant CTA/value exchange → mailing-list contact and/or free account → product/programme discovery → purchase where appropriate`

Mailing-list contact, account holder, purchaser, recipient, participant and entitlement remain separate concepts.

Public educational content remains readable without an account where Product Law says it is public.

---

# 16. SEO operating rule

SEO is a baseline quality requirement for every relevant public Feature Pack/slice.

The applicable page/content contract evaluates:

- crawl/indexability;
- canonical URL;
- title/meta description;
- social metadata;
- `robots.txt`;
- XML sitemap participation;
- breadcrumbs / BreadcrumbList schema;
- legitimate content-type structured data/schema;
- redirects;
- language/locale metadata and alternates where applicable;
- internal linking;
- responsive media/performance.

SEO is an experience/publishing operating requirement. It does not create new Content or Analytics authority.

Exact schema fields and technical implementation remain JIT by public content/page type.

---

# 17. Analytics operating model

Use **purpose-built canonical dashboards**, not a general dashboard creation product.

Only canonical dashboards required by the current Feature Pack/release need to exist. This model does not define a future KPI catalogue.

Dashboard visibility is role/policy-aware and does not imply drill-down/export permission.

---

# 18. Metric governance

Canonical metrics require an explicit, versioned definition sufficient to preserve meaning, including as applicable:

- business/semantic owner;
- authoritative source facts;
- formula;
- time basis/timezone;
- dimensions/exclusions;
- freshness;
- quality/reconciliation rules.

Versioning preserves the **metric definition**, not duplicate copies of underlying analytical data.

Historical report snapshots are retained only where reproducibility of a material decision/report requires them.

Exact Analytics Resource/state-machine implementation remains JIT.

---

# 19. Dashboard operating behaviour

Applicable dashboards:

- expose explicit filters;
- expose explicit comparison baselines;
- update reactively when a filter/date/comparison/refresh interaction changes;
- show material freshness/data-quality state;
- distinguish no-data/error/restricted states from a true zero;
- support governed drill-down;
- treat export as a separate permission;
- may later support saved filter presets without creating new dashboards.

Large exports use bounded durable async generation where required.

---

# 20. Attribution and analytics preservation

Preserve as much trustworthy first-party content, funnel, behavioural and performance signal as is appropriate under Privacy & Consent law.

Native authoritative facts remain the basis for business outcomes such as:

- permissioned email subscription;
- account creation;
- verified purchase/sales outcome;
- entitlement;
- assessment milestone;
- programme milestone;
- other approved conversions.

External analytics/search platforms are complementary evidence and never replace NewYou source business truth.

Exact GA4/GTM/Zaraz/Search Console integration belongs to the Frontend Experience System and affected JIT integration work, not this Operating Model.

---

# 21. Scheduling and periodic operations

Business-significant scheduling follows frozen Architecture:

- PostgreSQL-backed durable execution;
- Oban as default durable async executor;
- current Domain guards rechecked when work executes.

Typical operating uses may include:

- scheduled content publication;
- content review reminders;
- workflow ageing/escalation;
- provider reconciliation;
- notification scheduling;
- programme release;
- retention/deletion orchestration.

Do not use an in-memory global heartbeat as authoritative business scheduling.

`OQ-016` remains the gate for exact scheduler reliability, retry, alert ownership, stale-authority checks and recovery behaviour.

Exact worker/queue names, cron expressions, thresholds and retry values remain JIT.

---

# 22. Operating cadence

The platform should support a predictable operating rhythm without hardcoding unnecessary meeting schedules.

## Daily

Typical pattern:

`Command Centre → urgent/at-risk work → own queue → approvals/exceptions → scheduled work → operational health → handoff/close`

## Weekly / periodic review

Review only the areas currently in operation, such as:

- content/review/translation/publication;
- commerce/reconciliation/refunds;
- product funnel;
- safety/professional cases;
- programme/cohort progress;
- analytics quality/freshness;
- platform incidents/capacity.

## Monthly / management-period review

As applicable:

- commercial performance;
- participant/product outcomes;
- retention/cohorts;
- content/SEO/acquisition;
- safety/support trends;
- experiments;
- platform/performance trends.

Exact cadence and meeting ownership remain operating-team policy.

---

# 23. Mobile operating rule

Essential staff triage, review, approval, communication and urgent actions are mobile-safe.

Complex content authoring and dense analytical exploration may remain desktop-first while still remaining responsively correct.

---

# 24. Performance operating rule

Every implementation slice later applies the accepted JIT high-leverage performance pass:

`build correctly → verify correctness → complete slice → proportionate performance pass → acceptance → STOP`

Focus on obvious high-return issues such as:

- N+1/repeated queries;
- missing critical indexes;
- unbounded collections;
- oversized LiveView assigns/diffs;
- avoidable rerenders;
- expensive synchronous work;
- obvious preload/batching opportunities;
- unnecessarily large assets/media;
- unnecessary provider calls.

Do not turn every slice into speculative optimisation work.

Material risks that require broader work are routed to the appropriate proof/hardening gate.

---

# 25. Phase 7 / JIT handoff

The current repo authority for Phase 7 remains:

`Feature Pack Skeleton + Gate Manifest → required JIT Domain Dossiers → Final Feature Pack Contract`

This Operating Model adds workflow input to that process.

This document creates no additional Phase 7 artifact types. Any later governance addition must be explicitly routed through the repository's approved planning authority before use.

---

# 26. Development boundary

This document does **not** authorise:

- Phoenix/Ash implementation;
- exact Ash Resources/actions;
- database schema/migrations/indexes;
- exact Redis/ETS/Cachex usage;
- exact Oban workers/queues/schedules;
- exact PubSub topics;
- exact provider configuration;
- exact UI component/file structure;
- TOON execution prompts;
- FP-001 executable work.

Current planning remains bounded by the repo's Phase 7/Phase 8 development-entry gates.

---

# 27. STOP conditions

STOP if operating-model work would:

- contradict Product Law;
- change Domain ownership;
- invent clinical/legal/accounting/provider rules;
- resolve a blocking OQ without its required authority/evidence;
- turn Work, timeline, dashboard or Analytics into hidden source authority;
- introduce a generic Task/Administration Domain;
- promote implementation detail into operating law without a current need;
- contradict a locked Experience Decision;
- expand unrelated mature-platform workflow merely for completeness.

---

# 28. Hardening exit criteria

This Platform Operating Model was admitted to freeze review after confirming:

1. no Product/Architecture/Domain/Roadmap contradiction remains;
2. all Product-Law lifecycle semantics quoted here match their source;
3. no operating projection is mistaken for business authority;
4. unresolved OQs are still correctly routed;
5. implementation-specific decisions remain JIT;
6. the document is sufficient to guide Feature Pack workflow planning without trying to pre-design the mature implementation.


## v1.4.0 amendment scope

Eligible non-production founder-development uses one full ChatGPT technical Master Gate review published as JCSchoeman96 GitHub APPROVED for the exact head and declared base. That authenticated account approval supplies standing owner delegation after current required CI and the trusted integrated-main live merge guard pass. It does not prove another physical human. No duplicate founder comment, extra routine external reviewer or manual attestation files are required. The implementing account cannot approve its own work using founder credentials.

The guard validates repository/organization identity, current head/base, review, protected-main/no bypass, successful exact tested candidate and regular merge. It saves one automatic durable intent before mutation, verifies resulting main SHA/ordered parents/tree/no drift, and blocks Plane Done on uncertainty. Reconciliation is read-only and retryable; uncertain merges cannot be repeated automatically. Follow `docs/development/foundation-integrity-merge-gate.md` for the lifecycle, commands and exact refusal/recovery contract. No new App, workflow or approval platform is required.

Stronger regulated, clinical, legal, production-security, privileged and release rules remain. Approval/CI/governance changes use strict review; ambiguous consequence cannot select routine delegation. Native GitHub approval and stale-review enforcement need separate owner authorization and live verification. PR #224 cannot apply these proposed rules to itself: fresh independent review, CI and expressly authorized current-main bootstrap remain necessary. This successor changes no Product, Architecture, Domain or production authority.
