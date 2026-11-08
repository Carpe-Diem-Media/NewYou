# Identity reconciliation implementation plan

WELL-15 implements bounded Phase-8 Identity reconciliation against base `75185b44b535d0f6513dcab1922e06c35a48029a`. Current routers supersede obsolete ticket paths. WELL-7 and WELL-14 are Done; WELL-15 moved Ready to In Progress after live verification.

Goal: preserve original Accounts/history while applying one human-reviewed canonical decision and permanently retiring the losing PMR.

Architecture: private Ash ReconciliationCase actions and an Identity owner interface. Lock every involved Account in UUID order before case, token, Session and grant locks. Independently commit Audit E1 before the apply transaction. Recheck current authority, review and version at apply. Keep source outcome and Audit E2 obligation atomic.

Mechanisms: USE Ash/AshPostgres guarded actions, PostgreSQL constraints, existing permanent PMR reservations, Session revocation and scoped MFA. Use ordinary guarded actions for the small case lifecycle. Signals cannot carry required durable consequences. Temporal Resources are experimental and unnecessary for immutable linked cases. No new dependency. Existing Communications and Audit histories remain associated with original Account IDs; owner review must reject unsupported consequences. No commercial or professional Domain implementation is added.

- [ ] Add failing lifecycle and authorization tests in `test/new_you/identity/reconciliation_test.exs`, using existing P8-04/P8-05 fixture and concurrency machinery.
- [ ] Generate `ReconciliationCase` with Igniter, then add private state transitions, candidate/provenance FKs and PostgreSQL guards. Add Account canonical/PMR retirement state, retaining permanent reservations.
- [ ] Extend the bounded Support catalogue and step-up purposes for reconciliation review/apply. Implement current verified-control review, explicit survivor selection, conflict/rejection and compensating provenance.
- [ ] Extend Audit admission classification and linked result guards. Apply only after independent E1, with rollback/retry and minimised evidence. Revoke losing Sessions and close the losing Account.
- [ ] Exercise same-case and overlapping-case contention, stale/revoked authority, source failure, replay, permanent non-reuse and fresh-process reconstruction. Preserve original foreign histories through owner interfaces.
- [ ] Add full source-linked `docs/development/p8-14-reconciliation-handoff.md`, link it in docs index and audit its claims.
- [ ] Run focused tests, `mix check`, `mix check.deep`, codegen and exact diff/security checks. Obtain independent review. Production input changes require fresh WELL-91 security assessment and owner exact-digest approval before rebinding the existing Assent exception. Do not claim review readiness until required checks pass.
- [ ] Open the scoped PR, link it and record exact evidence in Plane. Do not merge.
