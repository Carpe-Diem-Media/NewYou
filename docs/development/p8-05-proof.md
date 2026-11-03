# P8-05 production-path proof

WELL-53 adds twelve P8-05 cases to the existing P8-04 runner. The approved entrypoint remains `test/proof/run.exs`. Run the commands in [phase8-proof.md](phase8-proof.md) through DevCore with TEST credentials.

The browser cases require Node.js and a local Chromium installation. The dependency-free CDP driver checks the standard Google Chrome and Chromium executable paths. It starts an isolated headless browser against the actual Phoenix endpoint on a loopback-only ephemeral TEST port. It submits the rendered forms with their CSRF tokens and browser-generated operation IDs. It checks the exact registry-backed EN and AF copy, pinned English legal artifacts, accepted registration, localized pending content and explicit resend. The TEST HTTP wrapper observes the actual Phoenix session keys before responses leave the endpoint. It creates no substitute registration endpoint or business write API.

No frontend source, participant copy, dependency, migration or business lifecycle is changed. Chromium stderr, screenshots, traces, page bodies and protected inputs are not saved. Synthetic credentials travel to the browser only on stdin. Returned browser evidence contains fixed boolean facts and opaque operation IDs. Runner assertions, rather than a browser-supplied PASS, decide each case verdict.

## Mappings and interpretation

`NewYou.Proof.P805Catalog` defines the case-to-obligation mapping and deterministic family digests. The fixed ten-family TB-001 inventory is unchanged. Only P8-05 obligations are mapped:

- `registration_pmr_reconciliation` contains accepted state, rejected gates, envelope rollback, registration replay/neutrality, PMR collision pressure, actual same-email contention, resend and immutable resend binding.
- `audit_e2` contains initial Audit schedule insertion failure and the subsequent source-transaction boundary, after all acceptance writes and before Ash commits.
- `browser_spine` contains separate English and Afrikaans registration/pending/resend journeys.

These family entries describe the listed P8-05 cases. They do not certify later reconciliation, proof consumption, Audit materialisation, Communications execution or the full browser spine. Seven other required TB-001 families remain explicitly missing. Even when all twelve cases pass, the overall `tb001` result must remain non-zero and coverage-incomplete. Do not report TB-001, Phase 8, Phase 9 or production release readiness as passed.

The mechanism selection uses existing Ash Domain actions and owner-scoped private reads, AshPostgres transactions and constraints, the existing AshAuthentication password/token path, and the existing AshOban Audit schedule. Ash Signals and Temporal Resources are not applicable because this change introduces no runtime cross-Domain reaction or historical/as-of model. No extension is installed. Transaction and checkout behavior were checked against the installed dependency source and the [Ash 3.37.2 transaction reference](https://ash-project.github.io/ash/Ash.html#transact/3).

## Transactions, failures and concurrency

Each owner callback uses an independent, unboxed TEST PostgreSQL connection. The production Ash action owns its transaction and actual COMMIT. The proof adds no enclosing business transaction, advisory lock or substitute write path.

Envelope and Audit scheduling failures use scoped diagnostic PostgreSQL triggers. A temporary sequence records that the insertion cut actually ran despite rollback. Trigger bodies write no business state, and teardown removes their trigger, function and sequence.

The registration checkpoint is compiled only into TEST at the final return of `AcceptRegistration`, after Account/credential, PMR, Token, MessageIntent/envelope, Audit obligation/schedule and registration binding writes. Only the proof worker's process dictionary can bind it. Application input and runtime configuration cannot select a checkpoint. Production-build evidence checks both absence of all proof modules and absence of proof or Mix imports from the compiled owner module.

The source-boundary case arms the approved `transaction.before_commit` cut for a registered scenario worker. It observes the complete acceptance result inside the existing transaction, consumes the cut and verifies that fresh observations contain no partial consequence. Ash's injected exception is caught only in the proof worker; application exception/transaction behavior is unchanged.

The same-email case uses `Scenario` and `Concurrent` workers on independent PostgreSQL connections. It holds the first real acceptance transaction at that checkpoint and observes the second transaction blocked by the production uniqueness constraint through `pg_blocking_pids`. It records distinct transaction identities before releasing the first. There are no sleeps, synthetic business locks or sequential calls presented as a race. Fresh owning Ash reads establish the final result.

## Evidence and teardown

Callbacks report bounded booleans, counts and classifications through the runner assertion ledger. Passwords, password hashes, verification bearers, envelope ciphertext, keys, URLs and participant email are never proof observations. The accepted-state case inspects persisted rows for raw password and bearer absence without returning row contents. Audit job arguments must equal the approved primary-key envelope containing only `EvidenceObligation.id` as its business reference. No Communications job is required, and no Communications/Audit worker or provider runs.

Fixture teardown is diagnostic SQL under TEST support, never a business mutation API. It removes only synthetic rows bound to pre-registered fixture emails and operation IDs, plus their delivery/Audit consequences. It recovers browser-generated IDs from durable owner provenance if browser reporting fails. Successful cleanup requires checkin after the source transaction has ended. Cleanup starts unconfirmed for P8-05 callbacks, so interruption cannot inherit a successful connection/lock verdict.

Permanent PMR reservations remain permanent, matching the existing Identity test contract. They contain no fixture email or credential. All other fixture consequences and diagnostic DDL are removed. Nonce records associated with removed envelopes are also removed.
