# NewYou documentation

Use these roots to find the right kind of repository documentation:

- `governance/` contains durable Product, Architecture, Domain and Roadmap law, plus current supporting authority.
- `delivery/` contains current Feature, JIT, proof, execution and content-evidence contracts beneath governance.
- `development/` contains engineering, process and CI documentation.
- `history/` contains frozen provenance and historical evidence. Treat it as read-only during ordinary delivery.

Start with `governance/CURRENT_GOVERNANCE_ROUTER.json` for durable authority and `delivery/CURRENT_DELIVERY_ROUTER.json` for current delivery contracts. Read only the sources relevant to the task.

Authority remains Product Law → Architecture Law → Domain Law → governing Roadmap → applicable supporting authority → semantic Feature/JIT/proof contracts → implementation. Plane project `WELL` remains the live execution authority for work-item state, priority, blockers, dependencies, sequencing and review/merge readiness.

The repository engineering contract is [AGENTS.md](../AGENTS.md). Foundation Smoke validates current routing and merge-gate topology. Foundation Full protects governance, frozen history and provenance. Application CI protects implementation and applicable delivery work.

Implementation maps and their review requirements live in development documentation:

- [Vertical-slice handoff standard and reusable template](development/implementation-handoff-standard.md)
- [P8-05 registration implementation handoff](development/p8-05-registration-handoff.md)
- [P8-10 Communications implementation handoff](development/p8-10-communications-handoff.md)
- [P8-11 Audit E2 recovery addendum](development/p8-11-audit-recovery-addendum.md)
- [P8-07 explicit email verification implementation handoff](development/p8-07-verification-handoff.md)
- [P8-08 password Session implementation handoff](development/p8-08-password-session-handoff.md)

These maps describe source at a recorded revision. Verify current code before reuse; they are not semantic authority routes or live status ledgers.
