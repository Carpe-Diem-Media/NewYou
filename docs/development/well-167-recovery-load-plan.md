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
