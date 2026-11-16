# Current-main reconciliation and bounded adoption

Continue WELL-112 / draft PR #227 under the owner's approved sequence. Starting head is `17a451ffe05ca0a0aea3cabaac840300fe97b080`; target integrated main is `d1001ee3c935337676fe61f855d1004e080bc143`. The existing worktree is isolated and clean before this plan. Preserve history with a normal main-into-feature merge; do not rewrite history, force-push or merge the PR into main.

## Bounded criteria

1. Preserve incoming current-main authority, infrastructure, owning business interfaces, security/CSRF/session/release behavior, exact eligible EN/AF content and existing journey regressions. Imported main changes are not new author certification.
2. Resolve the five preview conflicts minimally. Keep both `font-src 'self'` and current session `connect-src 'self'`; render the new locale-preserving registration login link through the shared link component. Retain both route exclusions and existing endpoint tests. Combine smoke-fixture requirements without weakening assertions.
3. Preserve canonical fonts, palette, geometry, local token ownership, premium CTA shine and shared native controls. Verify automatic router/controller/test merges, source enforcement and current registration consumer behavior. No speculative UI, schema, dependency or business-state changes.
4. Run narrow static/no-start/browser checks first. Reproduce any material regression narrowly before fixing it. Stable-source focused/canonical tests and separate deep verification require fresh coordinated TEST/PLT grants, activation and explicit release. No reset or cleanup. Observe current-main's Mise, OCR, identity-preflight and mechanical-history procedure.
5. Inspect the existing Hallmark finding through supported checks. Fix introduced product findings; retain an explicit gap where an external DEV-tool check cannot be satisfied without a separately approved change. No hidden waiver or lint weakening. Independent WELL-114 post-merge certification remains an independent obligation, not author self-certification.
6. Record the actual source and proof, update the existing draft PR with current history/CI evidence and obtain bounded independent review. Proceed to Pass 6 adoption only where current-page authority and candidate visual approvals permit it. Keep implementation, release and integration certification separate.

## Decisions and seams

The merge preview conflicts are `password_session_controller.ex`, `registration_html/new.html.heex`, `email_verification_controller_test.exs`, `authentication_reachability_test.exs` and `tests/test_foundation_smoke.py`. Root owns resolution and checks automatic merges in router, magic-login and other controller tests. A bounded independent reviewer examines conflict semantics without DB/app execution. Incoming governance/skills/tooling are retained byte-for-byte unless ordinary Git merging already combines an existing authorized branch change; no hand-authored durable authority amendment is planned.

This is implementation reconciliation, not a redesign. Existing approved design decisions and exact copy remain locked; conflict combination and proof structure are JIT choices. No owning Ash behavior changes are intended. Igniter does not express a Git conflict resolution safely. Keep the existing semantic maps; presentation-only component usage adds no new Domain capability or lifecycle. Validate maps after reconciliation and update only if actual source references or semantic descriptions require it. The canonical design-system handoff and focused proof notes remain the documentation entry point.

Current main requires independent OCR after applicable local gates for material engineering changes. If unavailable, record the exact gap and keep the PR Draft. Do not substitute a native source review for OCR or independent Master Gate. New source/base invalidates prior exact-head verification.

## Sequence

- Inspect both conflict sides and current authority; record the continuation in Plane.
- Merge current main into the feature worktree without committing automatically; resolve all conflicts and inspect the combined source.
- Run available targeted checks, keep source stable, coordinate final resource windows and record observed outcomes.
- Address applicable findings, update proof/PR/history and hand off the exact candidate without merge/Done claims.

## Observed checkpoint on 16 November

The normal main-into-feature merge is committed as
`962327723eb6659a5a155560521e1c455b95918e`, with integrated base
`d1001ee3c935337676fe61f855d1004e080bc143`. It has not been pushed at this
checkpoint. The five conflicts are resolved. Imported authority, skills, Domain
implementation, migrations and GitHub configuration match current main. Both
session CSP directives remain, and the registration login link uses the existing
locale key and shared link component.

Observed commands and local evidence:

- `NEW_YOU_PORT=4237 ERL_FLAGS='+S 4:4' mise exec -- devcore-project run dev -- mix assets.build`
  passed. Log `/tmp/newyou-reconcile-assets.log`.
- `mise exec -- python3 -m unittest tests.test_foundation_lane_routing tests.test_foundation_smoke`
  passed 62 tests. Log `/tmp/newyou-reconcile-smoke.log`.
- `DESIGN_SYSTEM_BASE_SHA=d1001ee3c935337676fe61f855d1004e080bc143 ERL_FLAGS='+S 4:4' mise exec -- devcore-project run dev -- mix design.check`
  passed. Log `/tmp/newyou-reconcile-design.log`.
- DevCore doctor passed for the committed DEV/TEST allocation. No environment
  repair, migration, reset or manual cleanup occurred.
- The focused 14-file journey/design run passed 116/136, seed 441526. Exact
  invocation is in `/tmp/newyou-reconcile-focused-receipt.json`; output is in
  `/tmp/newyou-reconcile-focused.log`.
- `NEW_YOU_PORT=4237 ERL_FLAGS='+S 4:4' mise exec -- devcore-project run test -- mix test test/new_you_web/live/design_system_live_test.exs:6 test/new_you/content/magic_login_message_test.exs test/new_you/content/password_reset_message_test.exs`
  passed 20/28, with 13 excluded. The eight failures comprise one guide404,
  four magic-login Content assertions and three reset Content assertions.
  Log `/tmp/newyou-reconcile-narrow-red.log`.
- A new regression in `test/new_you_web/privacy_telemetry_test.exs` expects the
  two guide paths to render without Router/error telemetry, while unsupported
  methods and unknown paths remain 404. Running that file passed 4/5, seed
  682168. The new assertion failed with 404 instead of 200, as expected before
  a fix. Log `/tmp/newyou-guide-boundary-red.log`.

These are partial, failing proof results. Neither canonical `mix check`, deep
verification nor OCR was started after the focused failures. Prior pass-5 proof
does not certify this reconciled source. The DEV preview also encounters pending
main migrations; no new browser or Hallmark pass is claimed.

### Guide dispatch and privacy

The endpoint ends in `NewYouWeb.RegistrationBoundary`, whose exact dispatch
allowlist does not include the guide. The Router declarations alone cannot make
these routes reachable. Do not add a general Router fallback. A bounded source
review also found that `Phoenix.LiveView.Controller.live_render/3` alone is
insufficient: installed LiveView static rendering puts the original Conn and
session in socket private data, then emits mount and handle-params telemetry.
The current `/live` transport also reads the browser session.

The next implementation must provide a sessionless guide render and transport that
preserve the browser's existing authenticated cookie without exposing it or its
decoded bearer in LiveView telemetry. This is a JIT privacy-preserving integration
choice, not permission to alter the privacy contract. Retain the current 404
until both HTTP and connected behavior are covered. Extend regression proof to
observe mount, handle-params and connected-event metadata with synthetic
transport, exercise a real live patch, and verify unsupported paths/methods and
production exclusions. The current new test covers Router/error telemetry only;
it is not complete privacy proof.

### Current-main Content compatibility

Unchanged main message readers still pin routed Product/Decisions v1.17.0 and
reject newly promoted v1.18.0. WELL-138 records the magic-login compatibility
defect, including permanent regression expectations and the prohibition on
blanket successor acceptance. WELL-136 already owns the reset-reader hotspot;
comment `60ccf71f-95c4-4224-87dd-f24257f7db7d` records this fresh failure.
Neither reader nor approved EN/AF bytes were changed in WELL-112. Resolve these
through their owning tickets before expecting the current-base canonical gate
to pass.

### Shared resources and remaining gates

WELL-112 activated TEST at 06:51:46 UTC under the owner's fresh grant. Both TEST
and the unused separate PLT reservation were explicitly released at
**2026-11-16 07:03:14 UTC**. No DB-backed test or PLT process remained. WELL-125
received the next TEST window. Release comments are WELL-112
`6c180372-7e62-46be-a821-704481f35b8c`, WELL-125
`2d3d069d-c401-42c1-bc9f-75ca9e9e38d9` and WELL-134
`3f9de312-71d0-4189-a057-7daa9f87dfe3`. Further TEST/PLT checks require fresh
coordination. WELL-125 explicitly released at **2026-11-16 07:05:14 UTC**, after
independently reproducing both Content eligibility failures on
`4af2f52` / `d1001ee`, with 0/2 passing, 25 excluded, seed 197674. It stopped
before canonical/OCR. WELL-112 has not claimed another window.

WELL-112 remains in progress. The owner-approved WELL-114 certification
exception remains open. Guide functionality, complete telemetry privacy proof,
current-source canonical/deep checks, current browser/Hallmark proof, OCR,
generated history, published head/CI and independent review remain unfinished.
Do not start pass-6 adoption or claim review readiness from this checkpoint.

### Checkpoint assessment

Task type is TESTING with repository reconciliation, WELL-112. This is an author
self-assessment of the reconciled candidate, not independent certification.
Against the six bounded criteria above: criterion 2 PASS; criterion 4 FAIL due
to the observed focused failures; criteria 1, 3 and 5 UNVERIFIED for complete
current-source behavior and visual proof; criterion 6 NOT_DONE because published
proof and review are still pending. Verified count is 1/6.

Implementation Score is 4.5/10: requirements 2/4, observed verification 1/3,
correctness/architecture/risk 1/2, handoff 0.5/1. The unmet guide contract costs
requirements points; failed focused tests and absent canonical/deep/runtime
proof limit verification; the unresolved safe dispatch integration limits
correctness; unpublished source/history limits handoff. Verification Status is
BLOCKED. Confidence Score is 90% in this diagnosis, based on narrow reproduction,
installed-source review and WELL-125's independent Content reproduction. The
safe connected-guide implementation remains unproved.

The gap to 8/10 is 3.5 points. First restore guide functionality with complete
HTTP/connected telemetry privacy regression proof. Have the owning tickets
resolve current-main Content compatibility without expanding eligibility. Then
coordinate fresh TEST/PLT windows, pass focused/canonical/deep checks and current
browser/Hallmark checks, run required OCR, refresh history and publish exact-head
CI evidence. A score of at least 8 remains conditional on those observed results;
none is awarded now. Merge readiness is NOT_VERIFIED_FOR_MERGE. WELL-114's
independent certification and the inherited Hallmark finding remain separate
open obligations.

## Later guide repair

The guide dispatch/privacy gap above is corrected in application source
`a2fd19007ad855c5d098f84197f33be0afd31d6d`. The [source/proof addendum](../../development/research/acss-4.0.3-inventory/guide-route-reconciliation.md)
records the sessionless HTTP and LiveView implementation, green focused/browser
checks and remaining overall gates. Earlier failing attempts and assessments
above remain historical evidence. The owner has since removed routine TEST
booking/release requirements. No new reservation is required to continue
authorized checks through DevCore; unrelated scope and destructive operations
still require their applicable authority.
