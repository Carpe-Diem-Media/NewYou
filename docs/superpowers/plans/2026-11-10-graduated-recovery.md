# WELL-16 graduated recovery implementation plan

Implement the Ready ticket against main `98fbeb8766ff1d20efe4f4f10baa6fc3abcc62f6`. Identity owns the case and existing Token proof. PostgreSQL Account locks serialize all security effects. No new dependency, proof store or service is needed.

## Locked requirements and JIT decisions

Use the eight specified case states. Keep monotonic required assurance separate from satisfied assurance. The bounded ordinary representative uses verified email proof. MFA-enabled, privileged or held Accounts require manual escalation and independent scoped MFA/step-up staff approval. A request cannot lower the Account's established assurance floor. Proof consumption and case assurance update share one Ash transaction. Completion shares credential/version, Session/Device invalidation, registration-binding invalidation, E2 and durable Communications obligations in one transaction. Manual completion additionally requires independently committed E1 and fresh scoped authority. Store only non-bearer claims and a keyed Account-state binding, following password reset.

The approved Content types explicitly exclude recovery. Implement unbound held Communications obligations and fail closed before provider execution. Actual delivery remains an affected execution blocker pending Product classification and eligible exact EN/AF Content decisions. Do not amend governance or reuse unrelated approvals.

Ash Resources/actions, policies, identities and database checks are USE. AshStateMachine is USE for case transitions. Ash Signals are NOT APPLICABLE to must-not-lose E2/Communications acceptance because their results are mandatory before source commit. Temporal Resources are NOT APPLICABLE to current-state recovery with append-only transition provenance. AshOban's existing owner schedules remain USE; jobs carry identifiers only.

## Execution

- [ ] Write focused request/proof/completion RED tests and observe failure.
- [ ] Generate RecoveryCase with Igniter, add private transition actions, constraints and owning Identity interfaces. Extend existing Token for recovery metadata and purpose-specific consume.
- [ ] Prove atomic proof/assurance acceptance, duplicates, terminal outcomes and Account binding.
- [ ] Add current scoped manual review and E1 completion with independent approver. Prove authorization, changed authority and failure ordering.
- [ ] Extend Communications with held unbound proof and completion-notice obligations, preserving existing content requirements.
- [ ] Generate/review migrations and immutable/monotonic database guards. Migrate without resetting shared DevCore data.
- [ ] Extend P8-04 machinery for genuine PostgreSQL competing transactions, rollback, restart, replay, scanner and Domain-negative proofs.
- [ ] Run targeted tests, architecture, code generation, fast and deep gates. Preserve actual output under `/tmp/newyou-well16-evidence`.
- [ ] Add a full source-linked implementation handoff and update the documentation index. Record implementation SHA separately from documentation head.
- [ ] Inspect the full diff, open a focused PR, reconcile Plane and request independent Master Gate review when all mandatory requirements are review-ready. Keep an incomplete PR draft and report the content blocker truthfully.

## Affected files

Identity `RecoveryCase`, recovery orchestration/actions, Account security guards, existing Token, grants/step-up and Domain interfaces; Audit admission/outcome allowlists; Communications intent and executor; generated migrations/snapshots; targeted lifecycle and shared proof support; full handoff. No UI composition or participant copy is authorised by this implementation choice.

## Verification

Use `mise exec -- devcore-project run test -- mix ...` for the repository's Elixir/OTP versions and isolated test profile. Begin with existing password-reset tests as baseline. Then run focused recovery tests and real concurrent unboxed PostgreSQL proofs. Verify public non-enumeration, no proof consumption from retrieval, no bearer persistence, no Privacy/other-Domain writes and fail-closed delivery. Final checks are `mix check`, `mix check.deep`, `mix ash.codegen --check`, and the complete diff at the recorded head.
