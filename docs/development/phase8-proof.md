# Phase 8 proof runner

The proof runner provides deterministic test infrastructure for the approved FP-001 Phase 8 work. Its self-test exercises only the harness. It does not implement or certify registration, identity, communications, audit, recovery, privacy, or browser behavior.

The governing implementation design is [WELL-5 P8-04 proof harness spec](../superpowers/specs/2026-10-22-well-5-p8-04-proof-harness-spec.md), with result shape defined by [proof-result-v1 schema](../superpowers/specs/p8-04-proof-result-v1.schema.json). TB-001 remains the source for later business proof obligations.

## Run locally

Use DevCore to check local TEST readiness and supply the test environment:

```sh
devcore-project doctor
devcore-project run test -- mise exec -- mix test test/new_you/proof
```

Choose a new output path for each invocation. The runner refuses to overwrite an existing result:

```sh
devcore-project run test -- mise exec -- mix run test/proof/run.exs --mode harness_self_test --output /tmp/phase8-self-test-run-1.json
devcore-project run test -- mise exec -- mix run test/proof/run.exs --mode tb001 --output /tmp/phase8-tb001-run-1.json
```

`harness_self_test` must exit `0` only when every required infrastructure case passes and cleanup is confirmed. A PASS means the proof machinery passed its own checks; it is not an architectural PASS.

Dependency provenance derives `runtime_required` from the TEST Mix dependency graph before it checks loaded application versions. Mix documents the dependency `:runtime` option in its [v1.20.4 dependency task reference](https://mix.hexdocs.pm/1.20.4/Mix.Tasks.Deps.html). The runner reads the resolved graph through `Mix.Dep.cached/0`, which is an internal API in the [v1.20.4 Mix.Dep source](https://github.com/elixir-lang/elixir/blob/v1.20.4/lib/mix/lib/mix/dep.ex). Recheck this derivation when upgrading Mix.

At WELL-5 completion, `tb001` was expected to exit `1` because later business-family manifests and cases, including `browser_spine`, are unavailable. The result must identify those missing obligations. That expected failure is acceptance evidence, not Phase-8 architectural PASS. Once later slices supply complete reviewed manifests and cases, this mode can pass only when every required family, case, assertion, provenance check, and cleanup condition passes.

`diagnostic` runs selected infrastructure cases for investigation. It cannot qualify as full proof.

Exit codes are `0` for complete success in the selected mode, `1` for invariant or coverage failure, and `2` for preflight, metadata, timeout, cleanup, schema, or output failure. A failed run invalidates its result; do not rerun into the same output path or reuse an earlier PASS artifact.

## Manual GitHub workflow

Run **Phase 8 proof** from the Actions tab and select `harness_self_test` or `tb001`. The workflow provisions an isolated TEST PostgreSQL role with `NOCREATEDB`, runs only the selected mode, and uploads the result even when the command fails. It is a manual diagnostic workflow, not an ordinary PR merge gate.

Review the artifact’s exact Git SHA, source cleanliness, dependency identity, runtime versions, TEST PostgreSQL version, complete case statuses, verdict, and cleanup. Artifacts contain only synthetic proof inputs and bounded reason codes; handle them as restricted CI evidence.

## Scope and interpretation

Proof controls and probes live under `test/` and are excluded from production builds. They do not provide a runtime switch, business authority, provider transport, production write path, or durable recovery mechanism. PostgreSQL advisory locks exist only in infrastructure fixtures that demonstrate actual contention; later business races must execute through their owning Ash interfaces without harness-supplied transactions or locks.

The runner and scenario controller remain outside the worker being terminated. Worker replacement can demonstrate consumed instructions stay consumed, uncommitted database work is dropped, locks are released, and replacement work owns a fresh connection. It does not prove business durable-recovery semantics. Later slices must reconstruct business truth through fresh owning interfaces from PostgreSQL or durable executor state. A whole runner or BEAM crash invalidates the run; never resume an old PASS.

WELL-53 adds the bounded P8-05 mappings described in [P8-05 production-path proof](p8-05-proof.md). Their success still does not certify the later families or full TB-001.

## Result schema checks

The proof tests check the companion schema's draft and identifier, required top-level keys, fixed coverage inventory, modes, cut-points, and closed result and case objects. The workstation has the `jsonschema` 4.26.0 CLI, which supports the schema's 2020-12 draft. It is not a project or CI dependency, so it is used for the manual artifact checks in the WELL-5 handoff. `Result.validate/2` enforces semantic and cross-field rules in every proof run.
