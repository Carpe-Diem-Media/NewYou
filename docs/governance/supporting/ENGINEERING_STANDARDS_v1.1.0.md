# Engineering Standards v1.1.0

- **Document version:** v1.1.0
- **Predecessor:** `docs/governance/supporting/ENGINEERING_STANDARDS_v1.0.1.md`
- **Date:** 2026-11-12
- **Status:** CURRENT / SUPPORTING AUTHORITY
- **Authority class:** SUPPORTING AUTHORITY / ENGINEERING STANDARDS
- **Promotion baseline main SHA:** `73eca9d9148a82cab8ae988c5950539bfee0d7f9`
- **Certification status successor base main SHA:** `596d9560aa2b3b3cb941560b01bdc6c8ba7c525a`
- **Source Grill:** `docs/history/platform/analysis/TARGETED_ENGINEERING_POLICY_GRILL_WORKING_v0.1.0.md`
- **Source Grill SHA-256:** `27bc75f1e17ca88922005374cc6643e0896ec40d477b87ac8b5e6b3c08ba2017`
- **HARDEN-02 authority basis:** `docs/history/platform/archive/HARDEN-02_CONTRACT_WORKING_v0.4.8.md`, H02-3R and I-12
- **Authority classification:** current supporting authority registered under `reference_documents`, not `governing_documents`

## Boundary

This document is the minimum Engineering Standards content promoted from the accepted Stage 4B Engineering-Policy Grill. It records engineering HOW rules. It does not create Product Law, Architecture Law, Domain Law, Roadmap Law, a Feature Pack, an OQ, a governed identifier or an implementation permission.

The source Grill remains preserved, working and non-authoritative. This supporting authority does not replace it. The separate status successor records certification and routes NEXT to `FP001_RECONCILIATION_REQUIRED`; it does not perform reconciliation or advance any later stage.

Higher authority wins. A conflict with Product Law, Architecture Law, Domain Law, Roadmap Law, the Platform Operating Model or an approved Feature Pack is a STOP condition. This document must not restate or mutate those authorities as Engineering Standards.

## Promotion provenance

The promoted material comes only from the accepted policy decisions in the source Grill:

| Standards section | Grill decision | Stage 3B provenance |
|---|---|---|
| Risk classification | `EP-Q1` | shared classification for the accepted policy questions |
| Error handling | `EP-Q2` | `A-08` |
| Operational observability | `EP-Q3` | `B-09` |
| Code contracts and automated quality | `EP-Q4` | `D-02`, `D-03`, `D-07` |
| Tests, review and proof | `EP-Q5` | `D-04`, `D-05` |

The Stage 4A Architecture Grill is a constraint, not Engineering-Policy provenance. No Architecture, Product or Domain rule is copied into this document as a new authority.

## Risk classification

Use three engineering-policy risk levels:

- `LOW`
- `STANDARD`
- `HIGH`

Do not add a `CRITICAL` tier at this scope.

`LOW` covers presentation-only helpers, simple pure utilities and mechanically obvious transformations with no authoritative, sensitive, concurrent, provider or consequential boundary.

`STANDARD` covers ordinary application or domain code where failure is bounded and recoverable and the code does not itself establish high-consequence truth.

Classify a change as `HIGH` when it materially involves one or more of:

- authoritative state transitions;
- authentication or authorisation;
- privacy, consent or sensitive data;
- concurrency or idempotency;
- provider reconciliation;
- durable asynchronous execution or recovery;
- migrations affecting authoritative data; or
- participant-facing consequential calculations.

The HIGH classification is mandatory when a trigger applies. Use consequence tags when relevant: `financial`, `entitlement`, `safety`, `privacy_deletion`, `privileged_security` and `irreversible`. Tags select or strengthen proof obligations. They do not create a risk class, Domain owner, Product classification or Architecture authority.

Authors may propose a classification and tags. A consequential classification must be reviewable, and a developer may not downgrade a HIGH change to avoid proof. If classification is reasonably ambiguous, the reviewer must agree. Do not use an elaborate scoring system.

## Error handling

Use the current Ash/Splode error model. Do not create a parallel NewYou-wide error framework. The authoritative application or action boundary owns business meaning.

- Use built-in Ash/Splode errors when they express the required meaning.
- Create a custom `Splode.Error` only for a stable, meaningful application distinction that the built-in model cannot express. Do not create one for different wording alone.
- Participant-facing messages must be safe and localisable through the approved Gettext path. They must not expose sensitive or internal diagnostics, authorisation policy detail or unsafe existence information.
- Keep richer technical diagnostics internal, access-controlled and redacted as needed.
- Adapters translate provider failures into application-understood semantics. Raw provider payloads, exception detail and provider SDK semantics are not participant-facing contracts or business authority.
- Where operationally relevant, the responsible application or provider boundary classifies retryable, terminal, unresolved/unknown or reconciliation-required outcomes according to existing Architecture failure semantics. Do not infer retryability only from a Splode class. `unknown` does not automatically mean retryable. A provider timeout or ambiguous acknowledgement must not silently become success or trigger blind duplicate retries.

Apply the risk model proportionally. LOW uses ordinary result or exception handling. STANDARD uses framework-native handling and separates public copy from diagnostics. HIGH adds explicit failure, retry and reconciliation semantics where applicable, plus leakage and non-enumeration proof where privacy or security requires it.

## Operational observability

Use backend-neutral operational observability conventions. Do not mandate OpenTelemetry, a telemetry vendor, an APM backend, a dashboard product, an Observability Domain or a second telemetry authority store.

Preserve the existing Architecture separation between metrics, traces, structured logs, domain-outcome operational signals and Audit/security evidence. Material signals need stable names, a defined measurement or contextual field, bounded cardinality, opaque correlation, minimum necessary context, an owner and a purpose.

Minimise sensitive data before logging or telemetry. Account IDs, participant identifiers, health content and other sensitive or high-cardinality values must not be used casually as metric labels. Correlation identifiers must not become authentication, Account identity or business authority.

A material alert needs an identified owner, a meaningful operator action or decision and a clear reason to exist. Do not manufacture alerts simply because a metric exists. Dashboards are projections for operational understanding, never business authority. When a dashboard disagrees with authoritative state, authoritative state wins and the discrepancy is investigated.

Telemetry and exporter failure may reduce visibility but must not fail an otherwise valid business transaction. Telemetry remains bounded and failure-isolated. For HIGH changes, provide enough evidence where applicable to correlate request, job and provider activity, find unresolved obligations or important outcomes, reconstruct consequential incidents and diagnose provider or reconciliation failures. Risk-sensitive sampling is allowed. Do not require zero sampling globally.

## Code contracts and automated quality

Use risk-proportional contract evidence and staged automation. Do not install an Elixir quality toolchain as part of this promotion. Once an authorised Elixir application baseline exists, cheap, deterministic and high-signal checks should become normal blocking evidence. Noisy or style-oriented findings stay advisory or policy-scoped until a clean baseline and failure policy exist. Automation must enforce repeatable, valuable rules with an acceptable false-positive burden. Human review remains necessary for novel Architecture or Domain boundary reasoning and approved escape hatches.

- LOW needs no documentation for a trivial private helper. Document where understanding benefits.
- STANDARD documents meaningful public or application contracts and externally consumed interfaces.
- HIGH documents the relevant contract and a short rationale for consequential actions, policies, adapters, escape hatches and other material boundaries.
- Do not require comments that only restate code.
- Do not require `@spec` on every Elixir `def`. Require useful typespec or equivalent contract evidence for meaningful public interfaces, behaviours and callbacks, cross-domain or application interfaces, complex HIGH boundaries and dense logic where it improves understanding or analysis. Keep this policy adaptable if Elixir's type-system capabilities supersede current typespec practice.
- Once an application exists, formatting, approved compiler-warning policy and reproducible dependency state are blocking evidence. New unexplained static-analysis regressions block after a clean approved baseline. Noisy style findings do not become automatically fatal without that policy.
- Automate Architecture-boundary rules only when they are repeatable and high-signal. Examples include forbidden ordinary Repo writes around an owning boundary, forbidden dependency direction and delivery code bypassing the application boundary. Existing Architecture and Domain Law remain authority. Approved exceptions require governed review.

This policy does not select Credo, Dialyzer, `mix xref`, Hex `boundary`, an audit package, warning flags or a dependency version.

## Tests, review and proof

Use risk-proportional tests and a justified HIGH proof menu. Do not require universal 100% coverage, property tests everywhere, concurrency tests for non-concurrent code, every expensive proof in permanent CI or security tooling as a maturity badge. CI is evidence, not Product, Architecture or business authority.

- LOW may use minimal testing for mechanically obvious logic. Non-obvious pure logic gets focused examples. Ordinary review is sufficient.
- STANDARD includes positive behaviour plus important rejection and edge cases. Application changes carry enough tests to make their intended contract repeatable.
- Every HIGH change evaluates the applicable proof menu. The author marks each item applicable or not applicable with a meaningful reason, and the reviewer agrees. For HIGH consequence tags such as financial, safety, privacy/deletion, privileged security and material concurrency, a weak or unjustified `N/A` blocks approval.

The proof menu may include positive and negative tests, invariant or state-transition tests, policy or authorisation tests, concurrency or idempotency tests, duplicate/reorder/retry tests, failure/recovery/reconciliation tests, migration-safety evidence, sensitive-data leakage or redaction tests, provider-reconciliation tests, security/privacy review evidence and reviewer acknowledgement of authority boundaries. Apply only the proofs that attack the actual failure modes.

Use property or generative testing when a generator meaningfully attacks an invariant or state space. Require concurrency testing when correctness materially depends on concurrent execution, duplicate requests, ordering or idempotency. Do not require it for code without a concurrency surface.

HIGH changes should receive review appropriate to the applicable consequence tag. Permanent CI contains cheap repeatable checks appropriate to the application. Load testing, game days, restore testing, penetration testing and large-scale concurrency proof remain JIT or stage-specific unless repeated evidence justifies permanent automation. Do not move later Architecture Proof or Release Readiness work into every PR. Coverage is diagnostic; no universal numeric coverage target is authority for correctness.

## Deferred choices and closed alternatives

This standard does not select or install any package, framework, tool, version, flag, provider or vendor. That includes Ash, Splode, Gettext, Telemetry exporters, OpenTelemetry, APM or log backends, dashboards, Credo, Dialyzer, `mix xref`, Hex `boundary`, audit tools, StreamData, Sobelow, coverage reporters, exact formatter or warning flags, HTTP error envelopes, Oban backoff numbers, sampling rates and retention periods.

The following Grill items remain deferred or rejected at their recorded scope: a universal participant/support occurrence ID, universal RFC 9457, a native execution seam, a native safety checklist, Rustler selection for an actual workload, a global error-code registry, an Observability Domain or second telemetry store, mandatory OpenTelemetry or vendor choice, a Rust/NIF platform standard, NIFs as a generic async or blocking-I/O substitute, maximum ceremony for every change and manufactured CI stages or coverage thresholds.

Exact strings, worker mapping tables, event grammar, CI job lists and implementation-grade package/API choices require later authorised JIT work. Current stable ecosystem facts must be rechecked against primary sources before any such choice is frozen.

## Certification lifecycle and preserved downstream state

The v1.0.0 promotion candidate is preserved byte-identically at `docs/history/platform/archive/ENGINEERING_STANDARDS_v1.0.0.md`. This v1.0.1 status successor records the accepted candidate as certified/current without changing the EP-Q1…EP-Q5 normative body. Both manifest records remain under the reference classification; only v1.0.1 is active, and Engineering Standards is not governing-root authority.

The sole normative source remains the accepted Stage 4B Engineering-Policy Grill at `docs/history/platform/analysis/TARGETED_ENGINEERING_POLICY_GRILL_WORKING_v0.1.0.md`, SHA-256 `27bc75f1e17ca88922005374cc6643e0896ec40d477b87ac8b5e6b3c08ba2017`. Stage 4A Architecture Grill evidence remains constraint context only.

### PR #65 candidate certification evidence

| Evidence | Value |
|---|---|
| PR | [#65](https://github.com/JCSchoeman96/NewYou/pull/65) |
| Certified pre-merge candidate head | `36de8f04c83a837f8b2d5e162ce10cc29f817d55` |
| Candidate and resulting-main tree | `1206905fe7b5391564841fa2a8b9198635c84848` |
| Resulting main | `596d9560aa2b3b3cb941560b01bdc6c8ba7c525a` |
| Candidate artifact SHA-256 | `feb2bf132fdca74bd534c83526a19e06659879a9b4f09bec7f5ca4b2e3c89df4` |
| Exact-head Foundation Integrity run | [36920390090](https://github.com/JCSchoeman96/NewYou/actions/runs/36920390090), PASS on `36de8f04c83a837f8b2d5e162ce10cc29f817d55` |
| Resulting-main Foundation Integrity run | [36967771106](https://github.com/JCSchoeman96/NewYou/actions/runs/36967771106), PASS on `596d9560aa2b3b3cb941560b01bdc6c8ba7c525a` |
| Pre-merge attestation | [PR #65 comment 5945899280](https://github.com/JCSchoeman96/NewYou/pull/65#issuecomment-5945899280) |
| Post-merge attestation | [PR #65 comment 5946270554](https://github.com/JCSchoeman96/NewYou/pull/65#issuecomment-5946270554) |
| Fresh independent post-merge review | PASS, bound to resulting main `596d9560aa2b3b3cb941560b01bdc6c8ba7c525a` |

These records certify the PR #65 candidate lifecycle. This v1.0.1 status successor separately records that promotion as COMPLETE / CERTIFIED. Its own exact-head and resulting-main lifecycle evidence belongs to its status-successor PR.

The current route remains:

```text
CERTIFIED HARDEN-02 EXECUTION
→ CERTIFIED ENGINEERING STANDARDS AUTHORITY PROMOTION
→ FP001_RECONCILIATION_REQUIRED
→ COMMUNICATIONS JIT DOMAIN DOSSIER
→ REMAINING REQUIRED / CONDITIONAL PHASE 7B
→ PHASE 7C
→ PROOF CLASSIFICATION
→ PHASE 8 ONLY AFTER DEVELOPMENT ENTRY HARD STOP PASSES
```

Engineering Standards Authority Promotion is COMPLETE / CERTIFIED. `FP001_RECONCILIATION_REQUIRED` is REQUIRED / NEXT / NOT PERFORMED. Communications remains REQUIRED / NOT_STARTED / DOWNSTREAM AFTER FP-001 RECONCILIATION. Privacy & Consent, Content & Media and Audit & Evidence remain CONDITIONAL / PENDING EXPLICIT ADJUDICATION; Analytics remains NOT REQUIRED. Phase 7C remains BLOCKED / NOT_STARTED, proof classification remains NOT FINALISED, and Phase 8/application implementation remain BLOCKED. Store/CER remains EXCLUDED from HARDEN-02.

## Primary-source verification note

On 2026-10-01, the candidate preparation checked the official HexDocs and Hex.pm entries for the ecosystem references named by the Grill. Those checks confirmed current stable documentation and releases, but this document adopts no version or dependency constraint. The Grill's original source table remains historical provenance for the accepted policy decisions.

No package, framework, tool, version, flag, provider or vendor is selected by this standard.


## v1.1.0 amendment scope

For eligible development, ChatGPT Master Gate completes the technical review and publishes one authenticated JCSchoeman96 GitHub APPROVED review for the exact final head. That review is both technical approval and standing merge authorization. No second founder comment or base-SHA line is required. The implementing agent must not use founder credentials.

Before merge, verify the current required CI and live branch protection. Run the read-only `tools.ci_attestation native-candidate` check from trusted integrated `main`, perform the normal GitHub merge bound to the reviewed head, then run `tools.ci_attestation native-result` with the tested candidate. These checks create no persisted evidence files or merge intent. If the merge result is uncertain, inspect the PR and `main` before taking further action. Reconcile Plane to Done only after the resulting commit, ordered parents and tested tree match.

Require stronger approval only when a governing or external obligation requires it. Paths and edits to CI, agent instructions, approval tooling or governance do not by themselves require a stricter route. PR #224 remains under current-main requirements and needs fresh complete review, successful CI and explicit owner authorization for its exact merge transition. Collection-only comment 6821263762 is not authorization; do not self-approve or self-merge. Any settings change after its authorized integration needs separate authorization and independent live verification.

Meaningful capabilities and material Domain/interface/lifecycle/schema changes keep one canonical source-linked JSON map in the same PR. The implementation-handoff standard defines its scope; independent review checks semantic claims against source and tests. This amendment changes no Product, Architecture, Domain or production authority.
