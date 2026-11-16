# Retained-fixture observation correction

Resume WELL-114's owner-approved non-destructive correction from integrated main
`a30d8b3c112b61b6b867c12e1cc4c14e8a17cbd2`. Keep this separate from WELL-112's
design-guide branch. Preserve retained rows, existing assertion cardinalities,
owner interfaces and normal fixture teardown. No application, schema, service,
credential or retained-data mutation is in scope.

The recorded RED source has 76 failures on `95d733b`, including a sanitized
reproduction of a singleton read seeing retained message intents. Relevant
business code, failing tests and fixture scenario inputs are byte-identical at
this base. The later Product eligibility evidence adds no code change. Do not
repeat the broad baseline solely for this worktree.

1. Add permanent query-scoping regressions with independently owned synthetic
   operations, foreign-row exclusion, extra same-fixture children, and an
   unsupported foreign enum inside an explicitly rolled-back transaction.
2. Extend the existing P805 observation seam. Supply explicit operation/email
   context for sandbox callers; current P805 fixtures use their existing tracked
   values. Filter in Ash before hydration. Never silently fall back to a global
   read. Child queries retain all rows owned by the selected fixture.
3. Replace the remaining global observations in delivery/recovery scenarios,
   delivery evidence, email verification, password sessions and registration
   primitive tests. Scope job reads in the database as well. Preserve every
   existing same-fixture count, state, retry, replay and privacy assertion.
4. Prove the regression and affected suites, then run one stable-source canonical
   gate and applicable deep/static checks. Detect actual conflicting commands;
   routine booking and release messages are not prerequisites. No deletion/reset
   or fixture workaround.
5. Review the complete diff, maintain affected source-linked proof/map references,
   record exact evidence and open a separate Draft PR as JC-Agents. OCR follows
   applicable passing local gates. No self-certification, merge or Done claim.

The private observation helper is a JIT test implementation choice. Igniter does
not express these assertion-preserving query edits. Application behaviour and
durable Domain semantics remain locked. Documentation impact is a proof update
to existing maps and this focused plan, plus generated PR history.

## Source findings before the coordinated test session

The seven failing module counts remain recorded under WELL-112's resumed proof.
The PasswordSession failure at `password_session_test.exs:412` is specifically
`Identity.expire_due_sessions/0` returning a global result where the test assumes
exactly one due Session. This is distinct from the separate global SQL counts in
the Account-lock race. The owner implementation reads up to 100 active due
Sessions and expires them through Ash. Merely accepting any positive count
would weaken the test and could still commit changes to retained Sessions.

Before running that case, retain its actual owner reconciliation coverage and
prove the selected fixture transitions exactly once. Any global owner operation
must be contained in an explicit test transaction that rolls back, with exact
batch/count and retained-state restoration assertions. Do not alter the owner
API or silently replace reconciliation with a direct per-record action. Inspect
the actual focused failure before choosing the smallest assertion-preserving
test correction. This was the initial source finding before correction.

The initial observation regression checks all six finite
resource branches, two same-fixture delivery attempts, exclusion of an
independently tracked operation and an incompatible synthetic foreign enum.
The enum test follows the existing Audit regression: transactional CHECK removal,
an explicitly selected negative decoder control, a marker proving the scoped
read completed, exact decoder-error inspection, and constraint/value restoration
after rollback. Only that test's synthetic row is updated. No retained row is
used as the incompatible negative control. The existing same-source RED and
sanitized singleton reproduction were reused before implementing `P805.read/3`.


## Source checkpoint and observed focused proof

Committed source is `8ee903d745369b559234e52a6f7e2a5179e71c94` on base
`a30d8b3c112b61b6b867c12e1cc4c14e8a17cbd2`. This is an implementation
checkpoint, not LOCAL_VERIFIED or independent review readiness.

The six finite resources filter by tracked operation IDs, canonical emails, or
owning parent relationships before Ash hydration. Fifty-three formerly broad
reads now use that seam. Registration primitives use unique per-test email
inputs, retaining explicit local-part case distinctions and domain normalization.
SQL before/after checks bind all Token and Session children to the fixture Account.
The delivery recovery job selector compares the complete JSON primary-key map
in SQL before Ecto hydrates jobs.

The delivery privacy test intentionally still searches all jobs for its own
unique proof/body. This negative privacy assertion must detect a leak into an
incorrectly addressed job, so narrowing it to known target IDs would lose
coverage. It does not use global cardinality or decode an Ash enum. A proposed
helper that included every newly observed job was removed after source review
because creation time alone is not fixture ownership.

Global Session expiry still exercises the real owner API in exact batches of
100 or fewer and checks idempotence and exactly one expired Session for the
selected Account. A separate synthetic Account is due as an explicit foreign
control. The test transaction always rolls back; a complete Session
signature and both synthetic states must be restored afterward. The existing
global expired-token maintenance test now also rolls back after its original
positive deletion, retained Session history, denial and fresh-login assertions.
Complete Token and Session signatures must be restored after that rollback.
Signature rows remain private; only hash comparisons are reported.

Observed command:

```sh
ERL_FLAGS='+S 4:4' mise exec -- devcore-project run test -- mix test test/new_you/proof/fixture_observation_test.exs
```

It passed 2/2, seed 994967, in 0.7 seconds after the finite query helper and
caller replacements. This predates the later maintenance wrappers; those still
need focused runtime proof. `mix compile --warnings-as-errors` and formatting
passed after correction of an undefined helper call in an intermediate draft.
No failing draft was published as verified. Mise resolved Elixir 1.20.5,
Erlang/OTP 29.1.2 and Node 26.2.0.

Two bounded static reviews were completed. The first found the global new-job
fallback and fixed email overrides; both were corrected. The second reviewed
the maintenance rollback boundaries and unique emails against owner/dependency
code and reported no findings. Neither review ran DB tests or certifies merge.

The owner explicitly superseded routine shared-resource reservations again.
WELL-136 has an actual canonical `mix check` process running while this source
and documentation work proceeds. Only commands that conflict with that process
are delayed. No permission or release message is required before continuing
once the actual conflict ends. Do not stop unrelated development, launch a
competing full suite, interrupt the other command or alter retained fixtures.

Next proof is the affected focused suites on this checkpoint, followed by one
stable-source canonical gate, applicable deep/static checks, OCR and exact-head
CI/review. Observe failures before repeating a broad gate. The independent
post-merge obligation remains open; no merge, Done or release is claimed.


## Corrected maintenance proof and focused result

Final test source is `145c2be40ff7e71357b46a28cf9e604abce489a5`. The first seven-file run returned 108/111,
seed 673275, in 28.1 seconds. Two registration maintenance cases still assumed
that the owner's global count was the fixture count. The third failure showed
that an expected Ash authentication denial aborted the explicitly nested outer
Repo transaction. These failures were diagnosed before repeating the wider run.

The corrected maintenance helper temporarily checks out Ecto's native sandbox
connection for the global-maintenance assertions, then checks it in and restores
the unboxed fixture connection in `after`. Ash transactions use their normal
sandbox savepoints, so an expected denial does not abort the enclosing proof.
Checking in rolls back all maintenance effects. Existing missing-token denial,
retained-session and fresh-login assertions remain inside that sandbox. Full
Token and Session signatures after checkin prove restoration. The expiry test
uses the same native mechanism and retains exact batch counts and both synthetic
Session restoration checks. No production callback or business API was changed.

Registration maintenance already runs in DataCase's sandbox. Its helper checks
each exact global batch, drains to the owner's idempotent zero result, and returns
the exact number of the fixture's newly tombstoned operations. The existing
2/0/1 fixture-count expectations and state/binding assertions remain. A focused
four-case correction run passed 4/4, with 41 excluded, seed 85844, in 2.0 seconds.

The complete affected focused command then passed **111/111**, seed **985650**,
in **36.1 seconds**, on the bytes committed at the final source SHA above:

```sh
flock -n /tmp/newyou-shared-test-plt.lock env ERL_FLAGS='+S 4:4' mise exec -- devcore-project run test -- mix test test/new_you/proof/fixture_observation_test.exs test/new_you/communications/delivery_test.exs test/new_you/communications/delivery_recovery_test.exs test/new_you/communications/delivery_evidence_test.exs test/new_you/identity/registration_primitives_test.exs test/new_you/identity/email_verification_test.exs test/new_you/identity/password_session_test.exs
```

Private log `/tmp/newyou-well114-affected-green.log`, SHA-256
`b7fb2b4d46a5e50589b16ed1026c5bfb340a0d140ed17e15fa5c7e299d32573a`.
The earlier failed log and correction log remain private, with no record dumps
published. The command released its advisory lock automatically; a nonblocking
probe confirmed it was free afterward. No standing TEST/PLT reservation remains.
WELL-136's requested focused/deep commands follow this actual command; routine
booking or permission messages remain unnecessary.

The static command `mise exec -- python3 -m unittest tests.test_capability_knowledge
tests.test_foundation_lane_routing tests.test_foundation_smoke` passed 71 tests
in 18.277 seconds. The initial capability check correctly detected changed
source hashes; the existing four affected maps are refreshed after semantic
review against the committed source. Schema/hash checks do not certify semantics.

The corrective PR changes only tests/support code and descriptive documentation.
Under AGENTS.md, canonical `mix check` remains required for executable engineering
changes. `mix check.deep` is required for application code, dependencies or
architecture-rule changes, none of which this diff contains. A second local PLT
build is therefore not applicable to this corrective PR. Required routed hosted
checks still apply. WELL-112's application/UI gates remain separate obligations.

The focused result is not LOCAL_VERIFIED: canonical integration, OCR, exact-head
CI, independent review and resulting-main certification remain outstanding.
Do not import the patch as already approved or mark WELL-114 Done.


## Canonical overlap diagnosis and controlled retry

The first canonical attempt on clean head
`96a84555598caa8f5db99a4672e49ad17e2cf1d8` exited 2: 826/831 passed,
five failed, seed 813027, in 592.4 seconds. It began while the observed
WELL-136 command was PLT-only, bypassing the combined advisory lock. WELL-136
subsequently ran 22 affected owner/controller/P812 tests during that canonical
command. Local logs confirm the overlap. A process snapshot did not prevent a
later conflicting command; it was insufficient coordination.

The five failures were two P807 cases failing their trailing no-new-consequences
assertion after their named business assertions passed, and three delivery
evidence cases returning `registration_unavailable` during fixture registration.
P805's observation deliberately includes new otherwise-unattributed consequences,
and P812 installs temporary global insert-failure triggers. These are concrete
interference mechanisms; the exact trigger timing was not independently traced.
No assertion, owner behaviour or source was changed to obtain a passing result.

After both commands exited, the same-source, same-seed diagnostic command passed
47/47 in 8.1 seconds, exit 0:

```sh
flock -n /tmp/newyou-shared-test-plt.lock env ERL_FLAGS='+S 4:4' mise exec -- devcore-project run test -- mix test test/new_you/identity/email_verification_test.exs test/new_you/communications/delivery_evidence_test.exs --seed 813027
```

Only after that diagnosis, one controlled canonical retry held the same advisory
lock for the entire command and passed **831/831**, seed **813027**, in
**547.2 seconds**, exit **0**, on unchanged clean head `96a8455`:

```sh
flock -n /tmp/newyou-shared-test-plt.lock env ERL_FLAGS='+S 4:4' mise exec -- devcore-project run test -- mix check --seed 813027
```

The actual wrapper also ran DevCore doctor and read-only Repo fingerprint
observations before and after that canonical command under the same lock.
Doctor passed. Mise resolved Elixir 1.20.5-otp-29, Erlang 29.1.2 / OTP29 and
Node 26.2.0. The canonical gate includes formatting, warnings-as-errors compile,
design-system, architecture, usage-rule, strict Credo, Sobelow and the full tests.
No conflicting TEST command remained in the observed process inventory.
The command-scoped lock released automatically after the final observation;
a nonblocking probe then confirmed it free. No standing lease or manual
permission/release-message requirement was introduced.

Private before/after SELECT aggregates matched complete row fingerprints and
counts for 12 of 14 observed tables, including retained message intents,
Accounts, Tokens, Sessions, operations, envelopes, obligations, jobs, grants and
Privacy rows. The two differences were expected retention-sensitive tables:
nonce reservations increased from 4863 to 4914 and permanent PMR reservations
from 94086 to 94967. `EnvelopeNonce` explicitly outlives cleared envelopes;
P805 cleanup preserves permanent PMRs, whose migration forbids update/delete
and truncate. No manual reconciliation was performed. Aggregate snapshots do
not prove individual preexisting nonce membership in a growing set; do not
claim all 14 tables were byte-identical or that retained-row authorship is known.

An optional psql observation wrapper initially exited before starting canonical
because DevCore supplies TEST_DATABASE_* configuration rather than libpq PG*
variables. It made no DB connection. The corrected observation uses
`mise exec -- devcore-project run test -- mix run --no-start` with the existing
configured Repo, starts no application and runs only SELECT aggregates. No
credentials or rows were printed. Fingerprints remain private.

The failed log, diagnostic pass and controlled pass remain distinct evidence:

- `/tmp/newyou-well114-canonical.log`, SHA-256 `90e45ab49a13ccb119210172aa52264f6cb9fc6ed0fa26877d6f9e55480f19b7`.
- `/tmp/newyou-well114-canonical-targeted.log`, SHA-256 `07a1545fe8f3431910e81107676114543266930ece64decba93fb9bfe9edda5f`.
- `/tmp/newyou-well114-quiet-canonical.log`, SHA-256 `8d84417fb79346acf741bf908ee47cb4bfd350ec6b33cfa2ab091b74fa7b8a55`.

This proves the local canonical gate for these executable inputs, not OCR,
exact-final-head hosted CI, independent Master Gate, integration or resulting-main
certification. Those delivery obligations remain open. WELL-112's separate
Hallmark/tooling and delivery gaps are unchanged.
