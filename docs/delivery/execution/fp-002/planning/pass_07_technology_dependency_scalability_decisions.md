# FP-002 planning enhancement — Pass 7 of 7
## Technology, dependency and scalability selection gate

- **Status:** planning candidate; user approved conducting this seventh review and integrating its findings. Exact plan/source publication and Plane `/to-tickets` approval remain separate decisions.
- **Baseline reviewed:** NewYou `main` `1bfb351e295d8e03704e6b057b334f84429581aa` on 2026-11-23. Reverify immediately before PR publication, Ready and implementation. No package change or application runtime code is authorised by this document.
- **Scope:** P1 architectural correctness and platform-wide **options** relevant to later FP-002 work. Not a universal technology mandate or an instruction to load new dependencies during P1.
- **Authority order:** [AGENTS.md](https://github.com/Carpe-Diem-Media/NewYou/blob/main/AGENTS.md); [Architecture §4.1, §§7.1–7.4](https://github.com/Carpe-Diem-Media/NewYou/blob/main/docs/governance/architecture/03_ARCHITECTURE_v1.1.1.md); [Domain Map](https://github.com/Carpe-Diem-Media/NewYou/blob/main/docs/governance/domain/04_DOMAIN_MAP_v1.2.0.md); [FP-002 approved P1 exact design](https://github.com/Carpe-Diem-Media/NewYou/blob/main/docs/delivery/proof/fp-002/FP-002_TRACER_BULLET_DESIGN_CANDIDATE_v0.1.0.md); [Engineering Standards v1.1.0](https://github.com/Carpe-Diem-Media/NewYou/blob/main/docs/governance/supporting/ENGINEERING_STANDARDS_v1.1.0.md). Supporting planning records **do not** override Product, Architecture, Domain, Roadmap or the approved P1 design.

### 7.1 Observed installed stack and compatibility boundary

`mix.exs` and `mix.lock` at the verified snapshot explicitly pin `ash == 3.37.2`, `ash_postgres == 2.15.2`, `ash_state_machine == 0.3.0`, `ash_oban == 0.10.2`, `oban == 2.24.2`, `reactor == 1.0.1`, plus `ash_authentication == 5.0.0-rc.17`, `ash_cloak == 0.4.0`, `argon2_elixir == 4.1.3`, and Phoenix `~> 1.8.17`, Phoenix LiveView `~> 1.2.0`. The pinned Reactor version is intentional: `mix.exs` comments that newer Reactor requires a prerelease `multigraph` dependency. The **locked** application baseline is the checked-in `mix.lock`; no transitive upgrade is implied by listing newer ecosystem documentation.

Application CI uses ephemeral **PostgreSQL 18.6**; this is evidence about CI, **not** a claim that every production database version or extension is verified. `config/config.exs` uses one Repo, PostgreSQL-backed Oban `Basic` engine and notifier, queues `default: 10`, `audit: 10`, `communications: 10`; queue additions and throughput tuning require measured resource budgets. The current registered Ash Domains do not include Commerce or Entitlements; P1 must integrate their Identity reconciliation owner reviews.

### 7.2 Adopt / conditional / defer / reject decision register

| Technology or pattern | Candidate disposition | Reason, scope and review trigger |
|---|---|---|
| Ash 3.37.2 + AshPostgres 2.15.2 + PostgreSQL | **RETAIN / P1** | Required owner-mediated Ash operations, SQL authority and DB-enforced invariants; do not fork another ordinary Ecto/Repo business-write API. Re-evaluate only through tested version/compatibility upgrade. |
| AshStateMachine 0.3.0 | **RETAIN / CONDITIONALLY USE** | Appropriate when a Resource has meaningful persisted transitions, guards, side effects and terminal states. P1 must model lifecycles; exact use of the extension for each Resource remains JIT. Guard business states in persisted invariants, not merely UI/DSL. |
| Oban 2.24.2 / AshOban 0.10.2 | **RETAIN / P1 EXECUTION** | Transactional durable work when sufficient and owner-backed rediscovery/reconciliation when work must survive lost/exhausted jobs. Queue uniqueness does **not** replace source-level idempotency. New queue/concurrency only when resource budget justified. |
| Reactor 1.0.1 / Ash.Reactor | **RETAIN / OPTIONAL** | Suitable for bounded multi-step orchestrations and compensation. NOT a cross-transaction ACID boundary, durable payment ledger or automatically restart-resumable financial workflow. **P1 does not require Reactor**; prefer direct owner actions plus durable intents. No Reactor upgrade without lockfile compatibility/CI. |
| AshPhoenix (`ash_phoenix`) | **SELECT FOR FIRST SUITABLE UI SLICE; NOT P1** | Architecture already prefers `AshPhoenix.Form` for Ash-backed forms. Package currently absent. For checkout/account UI prove current actor/policies, error/redaction behaviour, nested form validation and LiveView tests, then install with Igniter and exact dependency-resolution verification. Current docs suggest the 2.3.x line; **do not freeze a speculative package version** before `mix deps.get`/resolver proof. |
| AshAdmin (`ash_admin`) | **EVALUATE IN RESTRICTED DEV/STAGING; DO NOT ADOPT IN P1** | Package is absent. Admin docs state there is no builtin security beyond application policy; a mounted dashboard risks privileged financial/health data access. No production generic super-admin surface. Any future trial requires environment routing, explicit actor/security/policy, least privilege, audit, data minimisation and tests. Finance/Support mutations must be governed purpose-built owner actions. |
| `Ash.Signals` (Ash core 3.37.2) | **OPTIONAL, NON-AUTHORITATIVE** | Default inline listeners run nested within a transaction; post-commit listeners/delivery are not intrinsically durable. Signals cannot be the *only* evidence or mechanism for mandatory Commerce → Entitlements grant. Durable Commerce consequence plus Entitlements source-grant action remains authoritative. Trigger: a concrete bounded reaction with loss/replay semantics. |
| Ash Temporal Resources (Ash core) | **DEFER / EXCLUDE P1 FINANCIAL TRUTH** | Experimental; PostgreSQL implementation needs PG18+. Temporal valid-time/query semantics do not automatically prove accepted payment, idempotency, immutable financial history or eventual grant. Reconsider for concrete temporal validity use case after upgrade maturity and actual production PG verification. |
| AshStorage (`ash_storage`) | **DEFER; UNRELEASED / PACKAGING GATE** | GitHub project provides attachment/blob/storage features, but as of this review **no stable Hex release was independently verified**. Public community launch initially described it as not yet on Hex. Files are not P1 scope; evaluate maturity, released dependency, S3 security, deletion/retention/orphan recovery at the first governed binary-object feature. Do not assume production readiness or add Git dependency now. |
| AshAuthenticationPhoenix | **DEFER / EXISTING IDENTITY REVIEW** | May simplify Phoenix auth views; must not create parallel session/account authority. First inspect current Identity and security policies and actual UI needs. |
| AshMoney | **DEFER / FINANCE REQUIREMENT GATE** | For P1's one fixed 39900 ZAR-minor amount, integer minor units and explicit currency are simpler. Consider when multi-currency or precision/rounding rules justify it; Finance invariants still owned by Commerce. |
| AshPaperTrail / AshArchival | **DEFER** | May help general resource audit/archival, but cannot replace authoritative Audit evidence or immutable Commerce payment facts. Determine retention/deletion and audit ownership first. |
| AshJsonApi / AshGraphql / AshTypescript | **DEFER** | New external consumer contract, throughput and authorization testing needed. No API layer merely for future optionality. |
| AshRateLimiter / external anti-abuse | **DEFER, SECURITY-RISK GATED** | Use only after concrete abuse/traffic requirement and approved identity-based limits/failover semantics. Do not infer Redis or central process authority from selecting a limiter. |
| AshDoubleEntry / event-sourcing-style packages | **NO ADOPTION FOR P1** | A one-payment-one-right architectural tracer is not a general ledger system; choosing accounting authority is a separate high-cost durable decision. No second source of financial truth. |
| OpenTelemetry exporters / APM / extra monitoring stack | **DEFER VENDOR; REQUIRE INSTRUMENTATION SEMANTICS** | Stable metrics/traces/logs with PII-safe labels and outage isolation now; select exporter later on operational evidence. Existing Engineering Standards explicitly do not select observability vendor. |
| Redis / Cachex / new Repo / microservices / Kafka / external workflow engine | **REJECT UNJUSTIFIED INTRODUCTION** | Architecture permits evidence-gated acceleration, never substitute business authority. Start with current modular BEAM/Phoenix/Ash app and one primary PostgreSQL. Only add another component after measured capacity/failure reason and explicit authority approval. |

### 7.3 Exact P1 correctness contract independent of chosen helpers

1. Commerce alone accepts immutable payer/recipient/Plan version/39900-ZAR minor-unit purchase binding, creates known pending attempt and qualifies **internal TEST-only** observation through its genuine owning Ash actions. Synthetic evidence producers must be production-excluded and not forgeable through browser/provider input.
2. Apply one payment and one mandatory durable consequence **atomically in Commerce's PostgreSQL transaction**. Do not publish only a PubSub message, after-transaction signal, Oban job or Reactor step as mandatory truth.
3. Entitlements alone grants one source/component right `held_unconsumed` after rechecking committed consequence; no direct Commerce write to Entitlements tables or content delivery.
4. Independently running transactions must converge via DB uniqueness and source idempotency, not process-local locks, queue de-duplication or assumed global serial execution.
5. Restore from fresh process after (a) pre-Commerce-commit rollback, (b) post-Commerce commit/pre-Entitlements grant, (c) post-grant/pre-acknowledgement; recover from durable state even when worker notification/job is missing.
6. P1-07 Identity reconciliation requires new registered Commerce/Entitlements owners to contribute positive, negative, stale and restart owner reviews without weakening the existing unknown-Domain fail-close guard.
7. No genuine Paystack interaction, no real Plan content, no Assessment/bundle, no provider proof certification, no production fixture privileges in P1.

### 7.4 Scalability and operational design: order of investment

| Priority | Baseline improvement | Evidence required before adding an infrastructure dependency |
|---|---|---|
| 1 | Profile real Ash queries, bounded pagination/preloads, unique/partial indexes for actual idempotency and read patterns, transaction duration and lock waits | SQL traces/`EXPLAIN` and representative workload evidence; migration and PostgreSQL connection-pool budget |
| 2 | Budget Oban queue concurrency and retries against PostgreSQL connections, provider limits, retries and failure isolation | Queue age, throughput, recovery-to-convergence, exhausted job reconciliation and restart behaviour |
| 3 | Instrument successful/failed business outcomes, authentication denial, failed qualification, outstanding grant consequence, recovery lag and latency percentiles | Low-cardinality metrics; redact payer/recipient/health/provider secrets; exporter failures must not block transactions |
| 4 | Measure synthetic concurrent duplicate evidence, process loss, release/restart and outage recovery | P1-02–05 independent-connection database proof and replay counts; later provider-stage measurements without invented universal SLA |
| 5 | Add same-release application replicas or separate web/worker roles **only when traffic and recovery evidence justify** | Per-instance connection multiplication, no local business truth, PubSub freshness behavior, deploy/restart proof and primary DB capacity |
| 6 | Introduce cache/search/Redis/external services only for observed bottlenecks | Explicit source of truth, invalidation, failure degradation, rebuildability, privacy and cost/operational risks |

**Performance and release gates:** P1 proves correctness under its targeted concurrency and crash cuts. End-to-end callback burst, provider throttling, backlog draining, latency and release-readiness evidence remain **stage-appropriate later FP-002 requirements**, not an invented performance SLA or Kafka/Redis adoption prerequisite for P1.

### 7.5 Verification before exact implementation Ready

- Re-fetch live `main`, version pins and exact `mix.lock`; verify dependency graph with the repository toolchain rather than pasting current Hex version numbers into Product law.
- For P1: no new dependency is **required** by this review. If implementation discovers an essential additional library, record its capability/alternatives/risks in the PR, run Igniter where supported, check the resolved transitive graph, update lockfile deliberately and prove existing integration/security tests.
- For AshPhoenix: during the first UI ticket, explicitly reconcile version compatibility and compilation with current Ash/Phoenix/LiveView; test actor/policy propagation, nested forms and error hygiene. Do not prematurely change P1's backend-only scope.
- For AshAdmin: any future dev/staging evaluation must prove network access boundary, actor context, policy enforcement, no broad unreviewed writes, redaction and audit. Exclude production route unless separately governed.
- For Reactor: keep at pinned 1.0.1 until an independently tested upgrade is justified. For any orchestration use prove compensation is not relied on to reverse an already committed payment, and durable recovery is external to in-memory execution.
- For temporal/storage and other deferred libraries: repeat primary-source compatibility, security and maturity checks at the actual first feature, not as speculative dependencies in P1.
- File this review alongside Passes 1–6, link it from candidate v0.2.0 plan and P1 ticket draft. **The approved user instruction authorises analysis/integration, not an exact P1 plan approval, `/to-tickets` approval, ticket Ready or merge.**

### 7.6 Primary documentation used for feature behaviour

- Ash 3.37.2 Signals: <https://ash.hexdocs.pm/3.37.2/signals.html>; `<https://ash.hexdocs.pm/3.37.2/Ash.Signals.html>`.
- Ash Temporal Resources (version-specific): <https://ash.hexdocs.pm/3.37.2/temporal-resources.html>; AshPostgres temporal requirements: <https://ash-postgres.hexdocs.pm/temporal-resources.html>.
- AshPhoenix 2.3.x Forms: <https://ash-phoenix.hexdocs.pm/AshPhoenix.Form.html>; package releases <https://hex.pm/packages/ash_phoenix>.
- AshAdmin: <https://ash-admin.hexdocs.pm/getting-started-with-ash-admin.html>.
- Reactor 1.0.1 handling/compensation: <https://reactor.hexdocs.pm/1.0.1/02-error-handling.html>; Ash.Reactor (Ash 3.37.2): <https://ash.hexdocs.pm/3.37.2/Ash.Reactor.html>.
- AshStorage project and known incomplete roadmap: <https://github.com/ash-project/ash_storage>; community release discussion: <https://elixirforum.com/t/ashstorage-attachment-and-file-management-for-ash-framework/74916>.

**Pass 7 disposition:** Select the existing pinned stack and its owner/transaction/recovery obligations for P1; **no new package installation** is justified by P1. Set AshPhoenix as the first UI dependency candidate, Reactor as optional orchestration and AshAdmin as non-production restricted evaluation. Defer experimental/immature storage and temporal additions. This closes the *capability-selection review* gap but does not automatically freeze implementation-internal mechanisms.