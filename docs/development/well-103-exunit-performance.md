# WELL-103 ExUnit performance profile

## Scope and outcome

This record profiles the 579-test suite at `6651a08b29f984029d3c1816a225372c58cf24c9` before changing tests. Work used the isolated DevCore TEST profile on Linux x86_64 with 24 logical CPUs, 31 GiB memory, OTP 29.1.2 and Elixir/Mix 1.20.5. No production code, application dependencies, database configuration or CI cache configuration changed.

The profile found no demonstrated high-impact speed improvement that can be made without weakening isolation or proof coverage. The PR keeps the high-cost synchronous proof modules synchronous. It also makes one narrow, measured test-stability correction: a privileged-access test pins the process-local test clock to the same captured instant used to generate its TOTP. It does not reduce the number or strength of its assertions.

## Normal-mode baselines

Both runs used the unchanged canonical TEST environment and normal ExUnit scheduling. Command shape:

```sh
devcore-project run test -- mise exec -- mix test --seed SEED
```

| Seed | ExUnit time | Async / sync | Result | Shell wall time |
| --- | ---: | ---: | --- | ---: |
| `10301` | 280.4s | 2.1s / 278.2s | 579 passed | 339.19s, including initial dependency compilation |
| `10302` | 287.2s | 2.2s / 284.9s | 578 passed, 1 failed | 287.99s |

The second run exposed a boundary-sensitive failure in `NewYou.Identity.PrivilegedAccessTest`, “wrong password, wrong TOTP and same-period replay fail and persist the attempt marker”. The test generated a code from wall-clock time, then checked wrong-password and wrong-code paths before its final valid-code check. The TEST seam defaults to `System.os_time(:second)`, so a 30-second TOTP period could change between code generation and validation. The test passed by itself with seed `10302`; that supports, but does not directly measure, the period-rollover diagnosis.

The test in [`privileged_access_test.exs`](../../test/new_you/identity/privileged_access_test.exs) now captures one timestamp, installs it in `NewYou.Proof.PrivilegedAccessSeam` for the assertions, generates the TOTP for that timestamp, and restores the previous process-local seam value in `after`. The wrong-password, wrong-code, successful confirmation, replay rejection and durable attempt-marker assertions are unchanged. Ten isolated runs with seeds `24111` through `24120` each passed (one test, six excluded).

After this change, the canonical check completed with 579 passing tests:

```sh
devcore-project run test -- mise exec -- mix check
```

ExUnit reported 280.2s (2.3s async, 277.9s sync); command wall time was 282.46s. This confirms unchanged test-count coverage and does not demonstrate a runtime improvement. The performance comparison remains subject to seed, runner and dependency-cache differences.

## Diagnostic rankings

ExUnit 1.20.5 trace mode was run on the unchanged source:

```sh
devcore-project run test -- mise exec -- mix test --slowest 40 --slowest-modules 30 --seed 10303
```

It reported 579 passed in 279.7s (2.5s async, 277.2s sync). These timings are diagnostic only. The Mix `--slowest` options enable trace and preload, changing scheduling; they are not comparable to normal parallel-suite timings. See the [Mix test options](https://mix.hexdocs.pm/1.20.5/Mix.Tasks.Test.html#module-command-line-options) and [ExUnit configuration](https://ex-unit.hexdocs.pm/1.20.5/ExUnit.html).

Slowest modules in trace mode:

| Module | Time |
| --- | ---: |
| `NewYou.Proof.RunnerTest` | 88.5s |
| `NewYou.Identity.ReconciliationTest` | 34.3s |
| `NewYou.Proof.P805Test` | 34.2s |
| `NewYou.Communications.MagicLoginDeliveryTest` | 12.0s |
| `NewYou.Identity.MagicLoginLifecycleTest` | 11.4s |
| `NewYou.Proof.P813Test` | 11.3s |
| `NewYou.Identity.PasswordSessionTest` | 11.0s |
| `NewYou.Identity.MagicLoginRequestTimingTest` | 8.4s |
| `NewYou.Identity.SecurityHoldTest` | 7.1s |
| `NewYou.Identity.GrantRevocationTest` | 6.8s |
| `NewYou.Identity.MagicLoginTest` | 6.0s |
| `NewYou.Identity.MfaEnrollmentTest` | 5.4s |
| `NewYou.Identity.IdentityGrantTest` | 4.4s |
| `NewYou.Identity.PrivilegedAccessTest` | 4.1s |
| `NewYou.Communications.DeliveryEvidenceTest` | 4.1s |

The top 30 modules account for 276.4s (98.8%) of trace-mode test time. The slowest individual cases were:

| Case | Time |
| --- | ---: |
| Isolated production-build exclusion evidence (`RunnerTest`) | 53.7s |
| Full owned-obligation runner / incomplete TB-001 (`P805Test`) | 33.9s |
| Timed-out callback cleanup (`RunnerTest`) | 15.0s |
| CLI exception, exit, throw and timeout fixtures (`RunnerTest`) | 14.3s |
| Session authority across BEAM restarts (`PasswordSessionTest`) | 6.7s |
| Identity proof contention/restart (`MagicLoginLifecycleTest`) | 5.9s |
| `same_attempt` competing transactions (`ReconciliationTest`) | 5.8s |
| Superseded/expired/revoked/consumed delivery proof (`MagicLoginDeliveryTest`) | 5.8s |
| Privileged-support restart proof (`P813Test`) | 4.4s |
| Audit E2 restart backlog (`E2RecoveryTest`) | 2.9s |

## Isolation and optimization decision

The expensive cases exercise the proof properties WELL-103 requires us to retain: isolated production builds, child BEAM/CLI behavior and timeout cleanup, transaction contention, revocation and replay, and restart/recovery. See [`runner_test.exs`](../../test/new_you/proof/runner_test.exs), [`p8_05_test.exs`](../../test/new_you/proof/p8_05_test.exs), and the [`P805.with_fixture/1` fixture](../../test/support/proof/p8_05.ex). The fixture changes application configuration and process-local seams and uses an unboxed database checkout with cleanup. These are not candidates for blanket `async: true` without redesigning their shared state and sandbox ownership.

The repository has 38 synchronous test modules and 18 async modules. Test source inspection found deliberate timeout and cancellation coverage, including a 10.1-second wait in [`runner_test.exs`](../../test/new_you/proof/runner_test.exs) and bounded polling in [`concurrent.ex`](../../test/support/proof/concurrent.ex). These timings establish part of the behavior under test; shortening them would weaken timeout/recovery evidence. Database fixture setup/cleanup and registration/password hashing also contribute to case durations. The ExUnit trace does not isolate each setup, teardown, query or Argon2 cost, so the trace cannot rank those sub-operations independently. No password-hash parameter or database-fixture change is supported by these measurements.

No measured optimization justified changing module concurrency, removing cases, shortening proof time bounds or changing password hashing parameters. The only source edit fixes the observed clock-boundary instability. The security, concurrency, idempotency, revocation, rollback, restart and failure-injection assertions remain intact.

## Hosted cache and timing evidence

The trusted-main warm run `42773857566` (attempt 3, main SHA `6651a08b29f984029d3c1816a225372c58cf24c9`) ran on Ubuntu 24.04.5 with 4 vCPUs and image `ubuntu24-20261101.360.1`. It missed the exact cache key below, compiled the locked dependencies, wrote the cache manifest and saved that key:

```text
app-deps-v1-Linux-X64-ubuntu24-20261101.360.1-test-2a1d0b79be80bd79b5b400b1b6b332d009e8000c7e0620355a297014f826d168
```

The first PR run after that save must establish whether this candidate restores the exact main-produced cache. Record its run ID, head SHA, key, cache-hit result, manifest/locked-preparation result, runner, seed, ExUnit async/sync/total, compile time and hosted job/check duration in the PR description and the WELL-102 evidence comment after inspecting hosted logs. Do not infer a cache hit from a successful warm run or claim a speedup from different runner environments.

## Documentation impact

This is test-only proof maintenance and profile evidence. It changes no application interface, domain lifecycle, persistence or recovery contract. This focused addendum records source-linked rationale, measurements, commands and limitations; no full implementation handoff is applicable.
