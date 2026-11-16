# Guide routing after current-main reconciliation

WELL-112 application/test source is
`a2fd19007ad855c5d098f84197f33be0afd31d6d`, based on integrated main
`d1001ee3c935337676fe61f855d1004e080bc143`. This is a bounded restoration of
the existing guide, preserving its approved visual treatment. It does not adopt
more ACSS recipes or begin pass 6.

## Cause and implementation

Current main's endpoint finishes in `RegistrationBoundary`, which intentionally
does not fall back to the Router. The existing guide Router declarations therefore
returned 404. Routing through Phoenix directly would emit the original Conn in
Router telemetry. Rendering a LiveView directly from that Conn would also expose
its session and request through LiveView mount/handle-params telemetry.

The exact DEV/test GET allowlist now calls the internal
`DesignSystemBoundary.render/1`. HEAD uses the existing Plug.Head handling.
The helper reflects the known route metadata, validates display choices through
`DesignSystemLive.display_params/1`, and constructs a fresh rendering Conn. It
contains no original adapter, secret, session, headers, cookies or private data.
`Phoenix.Component.live_render/3` renders the guide on that projection. The
original Conn renders the root template and sends the response with no-store,
retaining its existing cookie behavior. Unsupported methods and nearby paths
remain 404. Errors still pass through bounded class-only failure handling.

The dedicated `/dev/design-system/live` websocket and long-poll transports request
no session connect-info and enforce connection-origin checking. DEV's general
`check_origin: false` does not override this explicit `:conn` setting. Sessionless
transport does not perform cookie-session CSRF validation. This read-only tool
uses origin checks and signed LiveView tokens and grants no Identity capability.
The normal `/live` configuration is unchanged. Both the dedicated socket and
guide dispatch are absent from a production compile.

The browser selects that socket only on the marked guide DOM and replaces the URL
with validated display choices before connecting. Existing grid events, URL-backed
choices, preview iframe and reload behavior remain supported. Since the socket
path does not itself restrict a signed token's view, a permanent test requires
reviewing this assumption before any other LiveView is routed.

No Domain interface, Ash Resource, durable lifecycle, schema, dependency or
participant copy is introduced. Ash business mechanism selection is inapplicable
to this internal rendering helper. Existing canonical capability maps are updated
for the shared source and privacy invariant; no second Domain capability map is
invented for a display-only helper.

## Test-first diagnosis and observed proof

The initial privacy/guide suite passed 4/7, seed 189794. Two guide assertions failed
with 404 and the dedicated socket was absent. After implementation, the focused
suite passed. A later raw-HTML response triggered Sobelow's low-confidence HTML
finding. The helper now uses normal Controller template rendering. A narrow
diagnosis identified its missing accepted format, which was corrected before
final verification. These failures were not waived or hidden.

Final observed results on the application source above:

- Nine focused design, guide, privacy, reachability and registration files passed
  **116/116**, seed **708015**, in 2.6 seconds. The expected forged-CSRF negative
  test retains its class-only error log. Exact invocation is in the evidence JSON.
- The canonical pre-test stages passed: formatting, warnings-as-errors compile,
  design enforcement against d1001ee, ARC-029 architecture, usage-rule freshness,
  strict Credo and Sobelow. This is not a complete `mix check` result. Sobelow's
  existing quoted-lockfile-key warnings remain in the private log.
- Assets build passed. Node contrast tests passed **5/5**. Capability/routing/smoke
  Python tests passed **72/72**. All **7** capability maps validate source locators.
  The five affected maps were mechanically refreshed together after semantic
  review because the single-map CLI validates every map after each refresh.
- The real Chrome browser regression passed, including the dedicated websocket,
  canonical URL cleanup, original cookie preservation, connected grid changes,
  iframe viewport, responsive reflow, token propagation, contrast refresh, keyboard
  focus and reduced motion. No browser errors were observed.
- The lighting regression passed. Painted CTA label contrast is 5.32:1 at rest,
  9.41:1 on hover/press and 5.31:1 with wrapped/doubled text. Its existing external
  Node module-type warning remains recorded.
- Hallmark rendered the guide against nine existing CSS files with **0 FAIL,
  0 open REFLEX, 1 WARN, 2 existing waivers and 0 rejected waivers**. The warning
  estimates 3.97:1 at a gradient endpoint, while the separate painted-label test
  above measures actual label placement. The existing waivers preserve approved
  58px input geometry and address numeric font weights classified as families.
  No waiver, palette, geometry or lint rule changed.
- A bounded independent source review of 8de042a..a2fd190 found no actionable
  issue. It ran no tests and supplies no Master Gate or merge certification.

The [evidence JSON](guide-route-reconciliation-evidence.json) preserves exact
commands, results and private-log SHA-256 identities. These are author records,
not independent attestations. Application inputs are unchanged by later evidence
or generated-history commits; exact-head hosted checks remain required.

## Runtime and remaining delivery limits

Browser and rendered lint proof used a temporary loopback TEST-backed endpoint
on port 4238. It starts through DevCore with the normal application configuration,
overriding only endpoint server/http/url settings. The ordinary DEV endpoint still
reports eight pending upstream migrations. No DEV migration, reset, cleanup,
credential or role change was performed. This is not production browser proof.

The owner removed routine shared TEST booking/release requirements after the
earlier checkpoint. Historical coordination messages in the plan do not require
new reservations. DevCore isolation, failure diagnosis and destructive-operation
approval remain mandatory. No PLT preparation or deep check ran in this batch.

Current-main magic-login and password-reset message readers still reject routed
v1.18 authority. Their files are unchanged from d1001ee. Narrow counter-evidence
and WELL-125's independent reproduction are recorded under WELL-138 and WELL-136.
No Content guard, digest or approved EN/AF byte was relaxed here. A complete
canonical run is not repeated on these known failing inputs. Deep verification
and required OCR remain pending, along with exact-head CI, independent review and
the owner-acknowledged WELL-114 post-merge certification gap. The PR stays Draft.

Against the six reconciliation-plan criteria, criteria 1, 2 and 3 PASS for bounded
source preservation, conflict resolution and guide/component behavior. Criterion
4 FAILS for overall canonical proof. Criterion 5 remains UNVERIFIED for the whole
site and independent certification. Criterion 6 is NOT_DONE for complete PR/CI
and review delivery. The verified count is 3/6. Overall verification
remains BLOCKED. Author Implementation Score is capped at **5/10** despite the
passing bounded repair. The underlying rubric is requirements 3/4, observed
verification 2/3, correctness/risk 1.5/2 and handoff 0.5/1. Confidence is **90%**
in the repair, based on regression and browser evidence; complete current-base
application behavior remains unproved. Reaching at least 8/10 requires owning
Content corrections, passing canonical/deep/OCR and exact-head review evidence.
Merge readiness is NOT_VERIFIED_FOR_MERGE.

## DEV migrations and resumed proof on 16 November

The owner authorized the pending DEV migrations. Eight existing forward
migrations, from `20261113181815` through `20261114183535`, applied successfully.
They create the integrated Privacy/Analytics structures and guards; no migration
was authored for this UI task. The T3 restart subsequently stopped the server
and verification process and removed their temporary logs. The interrupted
canonical run has no claimed result. Fresh inspection through
`mise exec -- devcore-project run dev -- mix ecto.migrations` found **58 up and
0 down**, so migrations were not reapplied. DEV was restarted on port 4237.
Both guide routes returned HTTP 200, and the full guide browser runner passed
against the normal DEV endpoint.

Normal DEV adds Phoenix's `/phoenix/live_reload/socket/websocket` alongside the
guide transport. The browser regression initially failed because its assertion
treated every socket as an application socket. Commit `8bf0dca` requires the
dedicated guide socket to be present and exempts only that exact live-reload
path from the subsequent application-socket check. `/live` and every other
unexpected path still fail. The corrected runner passed. A bounded independent
source review found no actionable issue. Application transport code and approved
button styling did not change in this correction.

Integrated main advanced to `d47d1b5ed10658b173a070a0df43a337b240b254`, containing
PR #248's WELL-137 Content compatibility correction. Normal merge
`95d733bb8069a77d5ec7a58edc3c8e10ef36d9e8` imports those sources and tests
unchanged. The sole conflict was the descriptive recovery map; it retains both
the WELL-112 guide-boundary note and the incoming WELL-137 lineage/test evidence.
A bounded independent comparison against both parents confirmed that result.
No Content guard or immutable approval was relaxed by WELL-112.

Fresh proof on `95d733b`, with Mise's Elixir 1.20.5, Erlang 29.1.2 and Node 26.2.0:

- The 12-file focused run passed **150/150**, seed **90857**, in 8.6 seconds.
  It includes the three corrected Content readers, guide, privacy, shared forms,
  reachability and registration tests.
- Canonical `mix check` completed with **811/887 passed, 76 failed**, seed
  **251294**, in 480.0 seconds. Its pre-test checks passed. The failing modules
  and exact commands are in the evidence JSON. This is not a green full gate.
- `mix check.deep` passed with zero errors and zero skips. Assets build, nine
  Node tests, 72 Python tests and seven capability-map validations passed.
- Chrome 155.0.8059.84 passed the guide and lighting regressions on DEV. Painted
  CTA-label contrast remains 5.32:1 at rest, 9.41:1 on hover/press and 5.31:1 with
  wrapped enlarged text. The premium gradient, directional borders and shadows
  remain intact.
- The guide's nine-file Hallmark render has zero FAIL/open REFLEX, one retained
  gradient-endpoint WARN and two existing waivers. EN and AF registration app
  renders each reproduce the inherited gate 26a FAIL on `body` after the DEV
  toolbar, one WARN and four existing waivers. No waiver or lint rule changed.

The canonical failure was diagnosed before any repeat. A temporary sanitized
test found **three message intents before and after** the unchanged admission
scenario. Its own fixture raises `MatchError` at
`test/support/proof/delivery_scenarios.ex:10`, which expects a singleton from a
global read. The diagnostic reports counts, exception class and source locations
without record values. It preserves the three preexisting rows. Their ownership
and relationship to the interrupted run are unproven. Business sources and
`test/new_you` are byte-identical to integrated main. The observed failures belong
to the existing WELL-114 fixture-reconciliation boundary, recorded in comment
`6b763c9e-cb04-4cfb-ba35-0203c3d403d9`. No reset, manual cleanup or source workaround
was performed, and the broad gate was not repeated on these unchanged inputs.

The `resumed_current_main` object in the evidence JSON records commands, fresh
log digests, the diagnostic and restart limits. Earlier checkpoint facts remain
historical. The owner's later instruction removes routine TEST booking; it does
not authorize destructive operations or waive required checks. OCR remains
unrun because applicable local gates fail. Current-source Firefox/WebKit,
independent exact-head review and resulting-main proof remain unverified.

Author assessment of the six reconciliation-plan criteria remains **3/6 PASS**.
Criteria 4 and 5 fail overall canonical and registration-quality proof; criterion
6 is not complete for independent delivery. **Implementation Score: 5/10**, capped
by the required failures. The underlying rubric is requirements 3/4,
verification 2/3, correctness/risk 1.5/2 and handoff 0.5/1. **Confidence: 90%** in
the bounded guide/migration result, with retained-row provenance and full-app
verification unresolved. **Verification Status: BLOCKED** for overall delivery.
To reach at least 8/10, resolve the WELL-114 fixture/proof obligation and inherited
registration quality gap, pass the canonical gate, then complete OCR and fresh
exact-head CI/review. The owner-approved WELL-114 continuation exception remains
open. Keep PR #227 Draft and NOT_VERIFIED_FOR_MERGE.
