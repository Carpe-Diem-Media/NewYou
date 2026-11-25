# WELL-167 controlled concurrent-load characterization plan

This plan was committed before any hosted load run. It predeclares the sample
counts, concurrency, fixture isolation, expected durable effects, pass criteria
and stopping conditions. It changes no Recovery behavior. It does not certify
the 350 ms transaction budget, a production warm-up or production activation.

## Question

Does concurrent Recovery traffic change the timing measured by the Step 2
characterization? Do the 350 ms checkout deadline, transaction atomicity, replay
safety and neutral public timing hold under each load condition?

## Fixed conditions

- Each child BEAM uses `pool_size: 10` from `config/test.exs`. A batch uses at
  most nine connections: one Account-lock holder and eight request tasks. The
  child releases its top-level sandbox connection before the batch starts.
- Pool queueing is not exercised. This plan measures up to eight requests in
  flight at once. It does not measure oversubscription.
- Every child first runs one sequential cold request on a fresh fixture. This
  is the only cold measurement. Batch requests run after first-use
  initialization.
- Every child runs a batch of eight requests. Concurrency is the number of
  requests in flight at the same time.
- Runner: `ubuntu-latest`, unchanged. The disposable database checks in
  `RecoveryLease.verify_fixture!` and the runner gate are unchanged.
- Other shards run on separate runners, so runner-level contention across
  shards is not controlled. This plan characterizes in-process concurrency only.
- The Step 2 switch `P815_CHARACTERIZE_BUDGET` stays on in the same run. Its 15
  identities are unchanged.

## Scenarios

| Scenario | Concurrency | Batch | Account-lock holder | Replicates |
| --- | --- | --- | --- | --- |
| Independent, serial | 1 | 8 known requests on 8 distinct Accounts | none | 3 |
| Independent, concurrent | 8 | 8 known requests on 8 distinct Accounts | none | 3 |
| Same-operation replay | 8 | 8 identical replay requests on one pre-issued case | none | 3 |
| Released contention | 8 | 8 known requests on one Account | held 150 ms, then released | 3 |
| Prolonged contention | 8 | 8 known requests on one Account | held 1000 ms, then released, followed by one authorized request | 3 |
| Mixed public timing | 8 | 2 known, 2 replay (each on its own pre-issued case), 2 unknown and 2 malformed on two idle cases | none | 3 |

Totals: 18 child BEAMs, 18 cold samples, 144 batch samples and 3 authorized
follow-up samples. The prolonged scenario is the only one with a follow-up.

## Expected durable effects

| Scenario | Expected effect |
| --- | --- |
| Independent, serial and concurrent | Every fixture ends with exactly one issuance: one version increment, one token and one account-recovery message intent. |
| Same-operation replay | The pre-issued case ends with exactly one issuance. No batch request adds a token or an intent. |
| Released contention | The Account ends with exactly one issuance. Every batch request closes with `none`. |
| Prolonged contention | Every batch request closes with `checkout_deadline` and commits nothing. The authorized follow-up commits exactly one issuance. |
| Mixed public timing | Each known and replay case ends with exactly one issuance. Each idle case used by unknown or malformed requests remains unchanged. |

The cold fixture in every child ends with exactly one issuance.

## Verification method

Each sample emits one `P815_BUDGET` line and one `P815_LEASE` line. The cold
report is first and the authorized follow-up report is last. Batch reports sit
between them in completion order.

Concurrent tasks print in completion order, so batch budget lines cannot be
paired one to one with lease lines. The analysis uses aggregates for batch
samples. The parent checks batch lease closures by position, and it checks
durable state for each fixture after the child exits, using the existing fixture
assertions.

## Pass criteria

1. Each child reports status `ok`, cleanup `confirmed` and marker `requested`.
2. The number of budget reports and lease reports equals one, plus the batch
   size, plus the authorized follow-up count.
3. Each batch lease closure equals the closure in the scenario table. Every
   closure is `none` except the prolonged scenario, which expects
   `checkout_deadline`.
4. Each fixture matches its expected durable effect.
5. Every public duration is at least 500 ms.
6. The child output stays below the port's 8,192-byte cap.

These thresholds are fixed in this plan. They are not changed after results
are seen.

## Stopping conditions

- A failed criterion is recorded as an observed result. The load run is not
  repeated to find a passing result.
- A failed durable-effect check blocks any Step 4 recommendation to keep or
  change the current behavior until the cause is explained.
- A run on a different head, a different runner label or a different inventory
  is not evidence for this plan.
- Results count only for the commit that produced them, and only when the
  required CI checks for that exact head are green.

## Fixture isolation and temporary switches

- Each child uses the existing P805 fixture scope and cleanup. Every fixture is
  a committed, disposable Account in the per-run `new_you_test` database that
  `RecoveryLease.verify_fixture!` checks.
- No shared local TEST database is used.
- No production Recovery code changes. The change adds a child `sample_load`
  mode, a parent `characterize_load` helper and the test wiring.
- Temporary switch `P815_CHARACTERIZE_LOAD: "1"` is set on the discover and
  shards steps only. Both steps must match so the inventories agree. Both
  temporary switches are removed before merge review.

## Output

Each child writes one `P815_LOAD_CHILD` JSON line to stderr. The line contains
the scenario, concurrency, replicate, every budget report and every lease
report.

Addendum A1 amends this section. The parent writes the `P815_LOAD_CHILD` line
and prints it before any acceptance assertion. See Addendum A1.

## Addendum A1 (2026-11-25): corrections after Master Gate review

This addendum is committed before any corrected code and before any corrected
hosted run. It amends the instrument and adds criteria. It leaves the workload
unchanged. The scenario table, the sample counts, the concurrency, the runner,
the durable-effect expectations, criteria 1 to 6 and the stopping conditions
still apply.

### Reasons for the correction

The Master Gate returned CHANGES REQUIRED for four instrument defects.

- MG-326-05: The prolonged scenario checked rollback only after the child exited.
  The authorized follow-up ran before any proof that the batch had rolled back.
- MG-326-06: Batch reports printed in completion order, without an ordinal.
  Budget, lease and task outcomes could not be tied to one request. Concurrent
  task exits and missing results had no explicit status.
- MG-326-07: The child did not verify the contention case and operation before
  it acquired the Account lock. The run did not record when the lock was
  acquired, released or granted. It therefore did not show that batch requests
  waited on the lock.
- MG-326-08: The load summary printed after the acceptance assertions. A failed
  assertion discarded the observations.

The static CI job also failed Credo nesting at `test/proof/p8_15_restart.exs:76`.
That is a code-quality finding. It is not a measurement result.

### Pre-correction evidence

These results stay on record. They are not discarded, and they do not count as
evidence for the corrected instrument.

- Run 45610376935 on head `76faf83d` was cancelled. It produced no evidence.
- Run 45610585106 on head `3ba289d9` concluded with failure. The Static job
  failed at Credo nesting. All eight test shards passed. The coverage and
  Foundation Integrity aggregators failed because the Static job failed.
- Shard 3 of run 45610585106 printed 18 `P815_LOAD_CHILD` records. All 18
  children passed their assertions. Their 165 timed requests each produced one
  budget report and one lease report.

| Scenario (concurrency) | Children | Reports | Transaction outcomes | Lease closures |
| --- | --- | --- | --- | --- |
| Independent (1) | 3 | 27 | `transaction_returned` 27 | `none` 27 |
| Independent (8) | 3 | 27 | `transaction_returned` 27 | `none` 27 |
| Same-operation replay (8) | 3 | 27 | `transaction_returned` 27 | `none` 27 |
| Released contention (8) | 3 | 27 | `transaction_returned` 27 | `none` 27 |
| Prolonged contention (8) | 3 | 30 | `transaction_returned` 6, `transaction_error` 24 | `none` 6, `checkout_deadline` 24 |
| Mixed public timing (8) | 3 | 27 | `transaction_returned` 15, `transaction_error` 6, `unobserved` 6 | `none` 27 |

Public durations ranged from 500 to 505 ms. The table does not attribute the
mixed-scenario outcomes to individual requests, because the pre-correction
output had no ordinals. The prolonged table includes the cold and follow-up
reports.

Accounting for the original predeclared run is 165 = 18 cold + 144 batch + 3
follow-up.

### Corrections

1. Ordinals. Each timed request has one ordinal. The cold request is 0. Batch
   requests are 1 to 8, in batch order. The authorized follow-up is 9. Each
   `P815_BUDGET` and `P815_LEASE` line prints its ordinal. The parent joins
   reports by ordinal. Its assertions compare the sorted ordinals with the
   expected set, which also detects duplicates.
2. Task handling. Batch requests run under `Task.async_stream` with
   `ordered: true`, `on_timeout: :kill_task` and the existing 10-second deadline.
   Each request maps to one status: `completed`, `raised`, `timeout`, `exit` or
   `incomplete` when no result exists. The child does not print exit reasons.
   Each batch task reports its admission and lock-grant times. The output carries
   no identifiers, PIDs, tokens or request data.
3. Contention boundaries. Before it acquires the Account lock, the child verifies
   the contention case and operation with `RecoveryLease.verify_fixture!/2`.
   `RecoveryBudget.with_account_lock/2` returns the acquisition and release
   times. It records the release time before it sends the release message. The
   child prints `P815_HOLD` with the release time relative to acquisition.
   `P815_TASK` lines give each admission and grant relative to acquisition. The
   admission event is `:transaction_entered`. The grant event is `:account_locked`.
4. Prolonged rollback proof. Before the batch, the child reads the contention
   Account and RecoveryCase and counts their Tokens and MessageIntents. After the
   batch, it takes the Account row lock with `FOR UPDATE` under a three-second
   `lock_timeout`. Acquiring the lock shows that no batch transaction still holds
   the row. The child then reads the same state and prints `P815_STATE
   after_batch <settled|unsettled> <unchanged|changed|unknown> <tokens>
   <intents>`. The child runs the authorized follow-up only when the state is
   settled and unchanged, with zero Tokens and zero MessageIntents.
5. Replay. Each replay batch request must report `transaction_returned` with
   closure `none` and no error. This is the replay effect. Durable state is
   checked separately: one version increment, one Token and one MessageIntent.
6. Emission before assertions. The parent builds the `P815_LOAD_CHILD` record
   from the parsed reports and prints it before any acceptance assertion. The
   record lists every timed request by ordinal, with its budget, lease and task
   categories. Each child reports 1 + 8 + f requests, where f is 1 for the
   prolonged scenario and 0 otherwise. The three children of a scenario report
   the same count, and all 18 children together report 165.
7. Credo nesting. The held-batch logic moves into helper functions. Its behavior
   does not change.
8. Step 2 format. The Step 2 budget line gains the ordinal field. The recorded
   Step 2 evidence at head `8291aa0a` stays as recorded. The Step 2 switch stays
   on in the corrected run.

### Added criteria

Criteria 1 to 6 are unchanged. These criteria are added before the corrected
run and fixed in this addendum.

7. Each timed request has exactly one budget report and one lease report. Each
   batch request has one `completed` task status.
8. Released contention: every batch request is admitted before release, and is
   granted at or after release. Prolonged contention: every batch request is
   admitted before release, and none is granted.
9. Prolonged rollback: before the follow-up, the state is settled, unchanged,
   with zero Tokens and zero MessageIntents. The follow-up then produces exactly
   one issuance.
10. Replay: every replay batch request has the replay effect. The durable state
    after the batch shows one issuance.

### Runner, switches and stopping rules

- The runner stays `ubuntu-latest`, the `CI_RUNNER` default.
- Temporary switches `P815_CHARACTERIZE_BUDGET` and `P815_CHARACTERIZE_LOAD`
  stay on in the Draft PR. Both are removed before merge review.
- A failed criterion in the corrected run is recorded as an observed result. The
  run is not repeated to obtain a pass.
- Pre-correction runs stay on record. They do not count as passing evidence for
  the corrected instrument.

## Hosted observations and final diagnostic cleanup

[Run 45615917313](https://github.com/Carpe-Diem-Media/NewYou/actions/runs/45615917313)
tested head `518e7dafd111129e08e7f5becf854f52f86bf272` against base
`86ed70ad58ca7675cb152602c3047481177b03a0`. The job used the configured
`blacksmith-4vcpu-ubuntu-2404` label. This differs from the predeclared
`ubuntu-latest` and the GitHub-hosted environment used in Step 2.

The 18 children reported all 165 timed requests and all 144 batch tasks
completed. The 24 prolonged batch requests reported `checkout_deadline`.
The other 141 requests reported no lease closure. All 24 released-contention
batch requests returned, with transaction callbacks from 157.046 to
160.878 ms. Their Account grants followed the release signal. Public
responses ranged from 500.039 to 502.634 ms. Mixed ordinals 7 and 8 in each
replicate use malformed email input. Recovery rejects that input during email
canonicalization, before transaction entry. These are the six `unobserved`
transaction outcomes. In the mixed batch, public response ranges in
milliseconds were 500.039 to 500.823 for known requests, 500.185 to 500.968
for replay, 500.264 to 500.471 for unknown accounts and 500.068 to 500.852
for malformed input.

The run recorded unchanged Account and RecoveryCase state, zero Tokens and
zero MessageIntents before each prolonged follow-up. All three follow-ups
returned and passed the issuance assertions. The settlement observer
at that head could report success for a failed transaction result or a query
that locked no rows. MG-326-09 now requires an explicitly successful
transaction with exactly one locked Account row. MG-326-10 retains all planned
ordinals even when reports are absent. Missing budget and lease reports are
null. Missing batch results are `incomplete`, with unavailable timings.
The original observations still belong to the original head. The final
corrections have focused regression tests. The normal hosted inventory omits
both characterization batches after the temporary workflow switches are removed.

Independent Master Gate retained the 350 ms transaction budget and 500 ms
public response floor. The experiment did not measure concurrent cold starts,
pool oversubscription or a grant in the 350–450 ms band. The historical
lease-loss initiating event remains UNKNOWN. Causal attribution or explicit
independent release-risk disposition remains required before Recovery activation.
