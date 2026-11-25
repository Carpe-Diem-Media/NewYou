# Application CI scheduling

Foundation Integrity uses the reusable Application CI workflow for routed PRs. A short Mix dry run declares the candidate’s test identities. The eight execution jobs run complete files, with independent PostgreSQL, BEAM, fixtures and build directories. The static job runs the same static alias as local `mix check`. Foundation Integrity also waits for Smoke, conditional Dialyzer and the routed Hex audit.

ExUnit declarations come from `module_started` before filtering. Execution evidence comes from `test_finished` on the normal test run. The coverage job checks each assigned file’s full identity set against the independent declarations. An excluded, skipped, invalid, failed or missing result fails the current contract. Integrated proof helpers still run via their existing tests. The verifier also checks the current run, attempt, merge candidate and successful job metadata.

## Timing registry

The planner uses the latest compatible registry artifact from the trusted main workflow when one is available. The publisher runs after a protected merge on main. It reads the successful Foundation Integrity attempt for the merged PR, checks the ordered parents and exact tested tree, and reads the coverage job’s artifact. It publishes a registry artifact with the median of up to five compatible observations per unchanged file. Compatibility includes the BEAM runtime, runner image and CPU, PostgreSQL, ExUnit concurrency and dependency graph. Measurements exclude setup and dependency preparation from file weights.

Registry artifacts are retained for 21 days. The reviewed WELL-202 bootstrap records the measured source tree and provider and expires after 45 days. Timings match by path and Git blob. Modified files get a conservative estimate using the prior weight and the fallback floor. New and renamed files use the upper quartile of matching history, with a five-second minimum. Deleted files disappear at discovery. Unavailable or invalid timing data falls back to the bootstrap or the positive weight floor. The artifact influences scheduling only.

The coverage summary reports weight provenance, fallback counts, predicted and observed per-shard execution, startup and queue costs, cache outcomes and runner-minutes. Timing publication needs a successfully integrated candidate. The draft phase can exercise the validation and rolling allocation through fixtures and publish verified candidate observations without writing trusted history.
