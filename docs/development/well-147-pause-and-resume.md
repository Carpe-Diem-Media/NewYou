# WELL-147 — paused integration and safe resume handoff

**Checkpoint:** 2026-11-20. **PR:** [NewYou #273](https://github.com/Carpe-Diem-Media/NewYou/pull/273). **Plane:** WELL-147 (live status, dependencies, blockers and acceptance).

> This is a dated engineering evidence and restart checklist, **not** a live work-state tracker or new execution authority. Re-read live Plane, the current GitHub PR and current `main` before resuming. This file is a documentation-only handoff. Its commit advances the PR head, so previous exact-head CI, receipts, reviews and authorizations **do not automatically certify the new head**. Never merge or activate from this file alone.

## Executive checkpoint: what happened

The underlying **real two-agent managed TEST lifecycle succeeded** on 2026-11-20, but the overall one-use pilot **exited 1**: its private controller attempted to write an approximately 4,775-byte postflight record through a 4,096-byte mailbox writer. It never published `acceptance.json`. This is a private reporting failure, **not** a confirmed database isolation or automatic-cleanup failure. An independent offline reconciliation passed 17 evidence checks; it is supplemental evidence and **cannot replace or retroactively change the original failed operation result**.

A separately requested, one-shot **canonical exact-head local verification was stopped before execution**: a private supervision wrapper failed mandatory independent review in two places. The gate recorded **zero canonical attempts, zero admission operations and zero new backend jobs**. Admission remained disabled and historical receipts and protected generations were preserved. **No merge, routine activation, manual release or quarantine reconciliation occurred.**

**Disposition:** pause further attempts, preserve evidence, and use the existing coordinated legacy TEST workflow for other NewYou development. The two private wrapper defects, final-head local proof, full independent Master Gate and merge/resulting-main reconciliation remain outstanding. No automatic retry.

## Fixed historical reference (do not treat as current HEAD)

| Reference | Evidence at this checkpoint |
| --- | --- |
| PR branch | `feat/well-147-managed-slots`, Draft PR #273 |
| Reviewed application head before this documentation-only update | `9e5e25a1ba9d9431334af81915656e2ab50fd56e` |
| Historical PR base / `main` | `fc8e12fb2b5710322f8011fdcfff4322cbfd244d` |
| Exact historical PR diff digest | `030c03ac392f3e0bf45acd03e744f5897c801357843efc75f4e08df5efd44ce5` (76 changed paths) |
| Exact-head hosted CI on historical head | Run [44508125950](https://github.com/Carpe-Diem-Media/NewYou/actions/runs/44508125950): all six applicable jobs passed. It does not certify a later documentation head |
| Successful earlier canonical local receipt | Source `bbcc272a7973bf1c1099564987a326f0bebae1e6`; focused tests + `mix check` + `mix check.deep` passed **at that source**, not at `9e5e25a1` or a later head |
| Installed DevCore observed at preflight | 1.2.1 executable SHA-256 `2ed9f8bba9abd3775b578bf159bb1c01787dac33cbbc668d71849752171916b7`; manifest SHA-256 `3fb71d0ed24dfc4ab8ef75226916da624f5ca4a18343695a154733eb2a93e556` (revalidate live) |
| Pilot authorization | [Owner comment #7030203413](https://github.com/Carpe-Diem-Media/NewYou/pull/273#issuecomment-7030203413), bound to packet `f886c0f50b393a2743a56c5c99e27a366f59808e294cbc2eaeb90b729d55f049`; **consumed and expired** |
| Last local-gate request | SHA-256 `40ec89fcf7cc599ecd7b1435a06eaf76c842d0a9c53a0dc3fbfc9003611189c0`; historical, pinned to old head, preflight blocked; **not portable authorization for a new head** |

## Proven versus unproven acceptance

**Observed in the single real bounded pilot:** two independent T3 agents had genuine simultaneous seed execution; assigned slots 5 and 3 and distinct TEST databases, roles, leases, generations and ports; both migrations and Ash-backed writes completed; `own_count=1` / `peer_count=0` per agent; cross-slot and legacy TEST connections were denied; owned child receipts completed; seed exits were `[0,0]`. Both seed generations were automatically cleaned and independently absent. Both agents reacquired **fresh** generations, verified no prior fixture data, exited `[0,0]` and received ordinary automatic cleanup. Root/watchdog reported admission closed, protected slots 1/2 and retained B4 unchanged, and no sampler-fault record. Offline review corroborated the original evidence with 17 checks. The sampler's clean join is supported by controller control flow and the normal-stop receipt; **no separate persisted sampler-join receipt exists**.

**Not established:** a successful original controller exit or `acceptance.json`; the old reporting failure's repair; a complete canonical local verification receipt at the PR's current exact head; independent founder Master Gate of the complete final diff; resulting-main verification; routine activation; two simultaneous full suites/20-heavy-job capacity; or blanket completion of remaining WELL-147 criteria (including intentionally failed-generation retention and the separately unverified historical browser cause). Static review covered 76 historical changed paths, 62 independently and 14 by the author; that is **not** complete independent Master Gate approval. Hosted CI does not replace required canonical local proof.

No source-level tracked application defect was confirmed by these private-control failures; **do not reinterpret this as an unconditional PR PASS**.

## Current stop: two PRIVATE canonical-gate wrapper defects

At the stopped prelaunch, the proposed private `controller.py` had SHA-256 `40d23f2e8fb99ecad5752b034326488d5eaa48b4895d27f5036404d66774f0d2`; the referenced original private `run_live.py` had SHA-256 `e2a54c74f423348156d52587d1b9624b8043bda20ff62f8e7843267e83ce347d`. These files are **not part of the tracked PR**. The precise static review is retained in the private `supervision-review.md` and Plane comment listed below.

1. **Critical: enable/close race.** The coordinator checked watchdog health and then enabled global admission without serializing enable with watchdog closure. A slow enable can finish **after** watchdog disable + closed-marker publication + watchdog exit. Coordinator loss then leaves admission globally open without a closer. Fix the **whole enable/close transaction** under one cross-process ownership/lock protocol: closed is terminal; enable must check closed/owner/window identity under that lock; watchdog must serialize **disable and closed-marker publication** with enable, not merely lock marker creation. Ensure a coordinator crash releases its lock and the living watchdog can disable; never kill admitted/unknown jobs. Prove this with deterministic adversarial scheduling and coordinator-death tests, not only green happy-path tests.
2. **Deterministic approval lookup failure.** Private `controller.py` called the restricted NewYou `run_live.github_api` helper with a DevCore repository comment path, which that helper intentionally refuses. Use a separate, **exactly scoped authenticated read-only lookup** of the pinned DevCore manifest approval. Validate account/source/manifest binding as required, test valid and invalid paths, and **do not widen** the reviewed NewYou helper allowlist.

Both defects must be corrected and independently reviewed against their **exact changed private bytes**, including source hashes and focused tests, before any future admission.

## Durable evidence index / private archive warning

Live Plane comments are the authoritative index for current execution state; raw workstation paths are **not durable storage**. The following references preserve the provenance without copying operational credentials, private database identities, approval records or large logs into the repository:

- [Source review PASS](https://github.com/Carpe-Diem-Media/NewYou/pull/273#issuecomment-7030203413) — GitHub comment is owner approval for the **consumed historical pilot**, not new authorization. Independent source PASS: Plane `7956cfd3-f863-4dec-a560-cb853a37fd3d`.
- **Actual runtime pilot:** Plane `ddb5cd47-5ddf-4522-8191-1f49bbcfb95f`. Private receipt tree: `/tmp/well147-live-final-20261119/`; consolidated private report: `/tmp/well147-real-two-agent-20261119/runtime-evidence-20261120/runtime-result.json`. Original controller exit 1, no acceptance.
- **Offline independent reconciliation (17 checks):** Plane `0d643d83-eb39-49bd-a829-f86fc9dbcad2`; private report `/tmp/well147-offline-reconciliation-20261120/independent/report.md`; bundle `/tmp/well147-offline-reconciliation-20261120/well147-offline-reconciliation.zip`. Supplemental report does not change original exit status.
- **One-shot local-gate request/conditional authorization:** Plane `44c84811-a150-475f-897b-cd9374f24313`; private request `/tmp/well147-offline-reconciliation-20261120/outstanding-local-gate-request.json` (old-head bound).
- **Prelaunch BLOCKED:** Plane `b3e02bca-2d88-4221-b032-737e0fcadf5a`; private review `/tmp/well147-current-head-gate-20261120/supervision-review.md`; preservation ledger `/tmp/well147-current-head-gate-20261120/blocked-prelaunch.json`; hashed earlier-receipt copy `/tmp/well147-current-head-gate-20261120/blocked-prelaunch-bbcc-preservation/`. Admission disabled; zero attempts.
- Other private source and test packets: `/tmp/well147-real-two-agent-20261119/` and `/tmp/well147-current-head-gate-20261120/`; inspect their manifests/hashes before trusting contents.

**Before closing the workstation or removing any worktree:** preserve the relevant private controllers, reviewed source ZIPs, exact consent/approval references, original receipts, journals, replay scripts, source/diff hashes and independent reviews in a separately access-controlled, durable location; verify restored hashes and index that location in Plane. This GitHub documentation records **references and expected hashes only**; it does **not** back up private `/tmp` files or certify that an off-host archive exists. Do not commit raw operational evidence, live credentials, protected allocation identifiers or private logs to this PR.

## Resume sequence — execute only after explicitly unpausing WELL-147

1. **Re-establish authority and exact state (read-only).** Open `AGENTS.md`, `docs/README.md`, the current governance/delivery routers, this guide, the current [managed-slot operating guide](managed-local-slots.md), exact tracked implementation/tests, current PR #273 base/head/diff, current `main`, live Plane WELL-147 and blocking comments. Check DevCore's actual source/install/manifest and the workstation's owner/client/legacy-lock/ports/jobs/resources. Use current Plane sequencing; this handoff does not turn a Changes Requested ticket into Ready.
2. **Recover and authenticate private evidence.** Verify an access-controlled archive contains the private controller, watchdog/sampler/harness, exact reviewed sources, logs/receipts, blocked-prelaunch artifacts and earlier canonical `bbcc272a` state. Hash-check against manifests; if missing, mark the proof gap rather than claiming the historic `/tmp` files exist. Keep protected slots 1/2/B4 untouched. Never fabricate a past success receipt.
3. **Correct ONLY the two private wrapper blockers.** Implement the serialized enable/closure ordering and exact scoped manifest-approval read. Add negative race, coordinator-loss, watchdog-death, closed-window/re-enable and approval-lookup tests. Obtain an independent review of the corrected exact private source, tests and shutdown paths. Do not modify tracked NewYou business code/governance merely to record private wrapper learning.
4. **Rebuild operational authorization for the *then-current* head.** The old `9e5e25a1` gate request and its conditional authorization are **not reusable for a changed PR head**. Check all previously consumed grants/expiry. Require fresh, exact source, request, owner approval and process/window identity under the reviewed contract; no approval is inferred from Plane state, a prior comment or this documentation. Fresh preflight and first resource sample must succeed **before** any admission. Independent watchdog ready and full fail-closed enable/closure invariant are mandatory.
5. **At most one newly approved canonical local attempt.** From one clean isolated worktree on the **current exact head**, run the repo's canonical focused `unittest` then `mix check` then `mix check.deep` through the current `.agents/skills/code-change-verification/scripts/handoff.py local --deep --focused ...` entry point. The historical focused targets were `tests.test_local_session tests.test_local_plt_cache tests.test_managed_handoff_commands tests.test_foundation_lane_routing tests.test_well147_pilot tests.test_well147_pilot_runtime tests.test_well147_pilot_identity tests.test_well147_pilot_cli`; revalidate against current code. Use sequential managed heavy admission (maximum one heavy job at a time), a bounded ≤30-minute window, no automatic retries or extensions, and normal automatic successful-generation cleanup only. Preserve the old `bbcc272a` receipt **before** the canonical executor invalidates its own prior state. On any failure stop new admission, independently verify disable, preserve resources/diagnosis, and STOP.
6. **Independently certify, don't self-approve.** Obtain new exact-head hosted CI (a documentation commit invalidates the old-head CI binding), complete independent diff/source and relevant Product/Architecture/Domain/Roadmap review, live Plane acceptance check, and exact-head canonical local evidence. Explicitly adjudicate residual criteria (e.g. failure retention, heavy capacity, OCR if applicable, activation). Distinguish offline lifecycle support from missing original `acceptance.json`. Only a genuine full Master Gate outcome may advance to merge consideration.
7. **Merge/result/activation are separate gates.** Keep PR Draft and no APPROVED review until certified. Respect current required checks, the authenticated founder review and the read-only `tools.ci_attestation native-candidate` pre-merge check; no admin bypass. Merge only after separate owner authority for the **exact reviewed head**. Verify resulting-`main` SHA/tree, candidate/no drift, and required CI with native-result afterward; only then move Plane to Done and open dependents. Routine managed-slot activation and any quarantine reconciliation need **separate** approval and proof. Nonconsenting worktrees keep the legacy shared TEST coordination protocol.

## Exit criteria for this parked checkpoint

- [x] Original real two-agent seed, isolation, cleanup and fresh-empty lifecycles supported by actual receipts and offline independent checks (bounded probe only).
- [x] Original pilot `exit 1`, missing acceptance, and offline-report limitation explicitly preserved.
- [x] Original `bbcc272a` local evidence preserved by prelaunch hash ledger (on workstation; off-host backup unverified).
- [x] The two private wrapper safety defects and exact stopped-preflight evidence recorded in Plane.
- [ ] Private durable evidence archive restored and independently hash-checked off-host.
- [ ] Both private wrapper defects corrected and independently tested/reviewed.
- [ ] Fresh, valid, exact-head local-gate authorization; one canonical local execution PASS.
- [ ] New current-head hosted CI and independent full Master Gate PASS.
- [ ] Explicit merge authority; resulting-main reconciliation; Plane Done.
- [ ] Separate routine activation decision and successful rollout (not implied by merge).

**Until then:** WELL-147 is **BLOCKED / NOT VERIFIED FOR MERGE** at this dated checkpoint. Keep the proven legacy TEST-owner coordination for ongoing application development.
