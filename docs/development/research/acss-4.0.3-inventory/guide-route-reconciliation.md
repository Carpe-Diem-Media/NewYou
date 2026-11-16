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
