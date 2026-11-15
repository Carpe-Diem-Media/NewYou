# Phase 4 registration presentation pilot

WELL-112 / draft PR [#227](https://github.com/Carpe-Diem-Media/NewYou/pull/227), continuing from `ae49a4a04339387ecd6be09c9285e665b6e3098b`. The owner requested one real page using the components and layouts from Phases 2 and 3. This phase migrates the actual [registration template](../../../../lib/new_you_web/controllers/registration_html/new.html.heex). It preserves its development gate. A successful browser render does not make registration eligible for participant release.

The [Phase 1 inventory](README.md), [layout proof](phase2-layouts.md) and [component contracts](phase3-components.md) remain tied to their recorded baselines. No ACSS implementation is copied, compiled or executed. No Sass, package, service, schema or business lifecycle is added.

## Authority and scope

Live WELL-112 remains In Progress, with WELL-114 In Review and its independent post-merge certification open. The existing owner authorization permits continued UI work while that gap remains. It supplies no merge or completion authority.

WELL-131 concerns the larger bilingual public-entry and verified-account journey. Its description remains planning-only and explicitly does not authorize implementation or release. This bounded visual pilot changes no home, pending or verification template, controller, Domain interface, content registry, legal artifact or eligibility decision. Registration's existing copy reuse is retained byte-for-byte. Candidate copy is not promoted by changing its presentation.

## Recipes adopted in this pilot

These recipes now have a real application consumer and guide examples. Adoption is bounded to the development-gated pilot. Further rollout must retain these contracts and resolve the recorded delivery checks; this is not blanket production certification.

- `.ds-container` is a centred border-box wrapper, width 100%, capped by `--design-container-max` or `--content-width`, with one horizontal gutter owner. Padding is `min(var(--gutter), 50%)`. The current cap is 1280px including both 24px gutters. Header and content are separate siblings. Nested form/card elements do not add another page gutter.
- `.ds-auto-grid` uses the same declaration as the guide's `.ds-layout-auto`. Registration chooses two maximum columns with a scoped `--design-grid-columns: 2`. Empty tracks collapse through auto-fit. Remaining items align to the start; this recipe does not centre incomplete rows.
- `.ds-stack` lays out vertical content with the existing large spacing role. `.ds-row` wraps native content with the existing base gap. They do not infer responsive breakpoints, reorder content or add margins to children.
- The existing flat `design_card/1`, decorative `design_icon/1`, `text_link/1` and `primary_button/1` with `treatment="lit"` render the actual registration section and actions. The card gets optional `heading_id` so its article can retain `aria-labelledby="registration-heading"`. It remains noninteractive; the native descendants own actions.
- `design_field/1` renders the four repeated registration inputs and the guide's default/error field examples. It owns label, input, error association and presentation classes. Labels and errors are caller-supplied localized strings. It does no translation or business validation.

The guide container uses an explicit half-width input for its constrained specimen. Registration uses the full canonical cap. Both use the same container declaration; equal specimen widths are not an adoption requirement. Guide auto-fill and breakout remain candidates. Fixed-grid last-row centring remains its separate existing recipe. Raised cards, boxed icons, inset decoration, fluid type/gutters, noise and overlays are not promoted by this page.

## Layout inputs and arithmetic

For available grid width W, gap g, positive minimum m and positive integer maximum columns N:

```text
track minimum = min(W, max(m, (W - (N - 1) * g) / N))
columns = repeat(auto-fit, minmax(track minimum, 1fr))
```

The `min(W, ...)` bound lets a single track shrink in a narrow parent. Registration's default minimum remains the existing `--design-layout-min: 12rem`, with `--grid-gap: 24px`. At a 16px root, the two-column transition is `2 * 192 + 24 = 408px` of form allocation, not viewport width. Actual-page proof measures one column at 407px and two at 408/409px. Page gutters and card border/padding reduce the available form width before that calculation.

Canonical values and context inputs belong in [design-tokens.css](../../../../assets/css/design-tokens.css). Optional inputs remain unset at root so fallbacks resolve at the consumer:

```css
/* An approved context in design-tokens.css, not an inline template value. */
.my-form-context {
  --design-grid-columns: 2;
  --design-grid-min: 12rem;
}
```

`--design-grid-columns` falls back to the existing layout count, and `--design-grid-min` falls back to the existing layout minimum. Keep counts positive integers and minima, gaps, caps and gutters compatible nonnegative lengths. Prefer a positive minimum and cap; percentages, invalid strings and negative dimensions are outside this contract. The numeric gate does not validate every possible CSS expression. Optional `--design-container-max` changes the border-box cap locally. Root `--content-width`, `--gutter`, `--grid-gap`, `--font-body`, `--primary` and `--radius` remain shared sources. The readable paragraph measure is `--measure: 65ch`. Components do not introduce independent font-family literals.

## Field and state contract

[`Field.design_field/1`](../../../../lib/new_you_web/components/design/field.ex) accepts `id`, `name`, `label`, `type`, `value`, `error`, `required`, `disabled` and `autofocus`. Supported types are text, email and password. Global metadata and supported native autocomplete/constraint attributes pass through. Class/style, identity/value, native owned state and ARIA label/error-association collisions are rejected for both atom and string keys. Use a labelled approved CSS context for token overrides, not forwarded inline styles.

- Normal fields use the approved white surface, strong ink, small radius and 58px minimum input height. Existing `ink-meta` supplies a discernible boundary; the decorative card hairline is too faint for that role.
- Focus adds an immediate 2px primary outline with offset. Disabled is native and cannot submit or focus. Readonly remains native. Browser constraint validation remains enabled.
- A non-nil error creates `id + "-error"`, `role="alert"`, `aria-invalid="true"` and `aria-describedby`. Associated neutral text, a heavier input border and the error marker convey the state without introducing a red palette. Error text grows naturally; space is not pre-reserved. Labels and errors wrap; single-line native input values scroll inside their control.
- Password values are always omitted, including if a caller passes one. Non-password safe values retain the controller's existing behavior. Autofocus remains controlled by the existing first-name/global-error decision.
- The lit submit action keeps its established gradient, shine, top/bottom edges and native semantics. It has a 48px minimum height and may grow for wrapped labels. This controller form has no new synthetic loading state, spinner, LiveView hook or reconnect behavior.

The page retains exact copy keys/bytes and document language, language navigation, POST target, CSRF, operation ID, input names/autocomplete, age requirement, separate Terms and Privacy facts, error IDs/alerts and legal links. The controller and Identity boundary remain unchanged. `color-scheme: light` and canonical tokens apply only to the opted-in pilot. Legacy registration selectors exclude `[data-design-pilot]`; other templates retain their existing styling and theme behavior.

## Repeatable proof

Run the existing server through DevCore on port 4237. Browser tooling stays external to application dependencies.

```sh
ERL_FLAGS='+S 4:4' mise exec -- devcore-project doctor
ERL_FLAGS='+S 4:4' mise exec -- devcore-project run dev -- mix assets.build
ERL_FLAGS='+S 4:4' mise exec -- devcore-project run test -- mix test test/new_you_web/design_field_test.exs test/new_you_web/design_component_contracts_test.exs test/new_you_web/controllers/registration_controller_test.exs test/new_you_web/design_system_infrastructure_test.exs test/new_you_web/live/design_system_live_test.exs
BROWSER_TOOLS_ROOT=/tmp/newyou-refinement-tools CHROME_PATH=/usr/bin/google-chrome node test/assets/design_registration_browser.mjs
BROWSER_TOOLS_ROOT=/tmp/newyou-refinement-tools CHROME_PATH=/usr/bin/google-chrome node test/assets/design_layouts_browser.mjs
BROWSER_TOOLS_ROOT=/tmp/newyou-refinement-tools CHROME_PATH=/usr/bin/google-chrome node test/assets/design_component_contracts_browser.mjs
```

The actual-page runner covers both EN and AF at 320, 390, 744, 1128, 1440 and 1920px; 320px parent allocation at a wide viewport; exact field-column transitions; one gutter/cap; local overrides and sibling isolation; live font/action/radius changes; equal canonical colors under both legacy themes; keyboard order and visible focus on all twelve application controls; text/boundary contrast; native validation; localized server errors; safe value retention; omitted passwords; long EN/AF and unbroken text; doubled text at 320/744/1440px; reduced motion; forced colors; no-JavaScript form and language links.

First it attempts a native invalid submission and observes the invalid event, focused required field and no POST. Separately, one deliberately invalid POST per locale bypasses browser validation only to obtain the actual existing server-error response. Empty required name/email and missing age/legal facts trigger rejection before Identity. The controller TEST suite proves server rejection creates no account; browser proof does not submit a valid DEV account or inspect unrelated data. Accepted/pending and business paths remain controller TEST coverage, not a browser journey-release claim.

The independent review identified the missing native-submit proof; that check was added. Focused tests first failed for the absent shared APIs and template composition, then passed. An expanded ownership regression failed before the Field rejected forwarded atom/string identity and accessibility collisions. These observations are separate from final exact-head verification.

Observed local results and exact final-head canonical checks belong in PR/Plane evidence. At the source checkpoint, focused ExUnit passed 79 tests, registration proof passed 105 assertions, shared layout proof passed 6688 assertions and component proof passed 51 assertions on Chrome 155.0.8059.84. Desktop, phone and AF-error captures were inspected. This is Chromium evidence. Firefox/WebKit, screen-reader interaction, true browser zoom/OS text settings and broader LiveView reconnection are not certified. Doubled computed font sizes are an explicit text-resize stress test, not an emulation of every browser zoom mode.

## Hallmark findings and delivery limits

The supported affected-file/render command is:

```sh
HALLMARK_PUPPETEER=/tmp/newyou-refinement-tools CHROME_PATH=/usr/bin/google-chrome node /home/jcschoeman96/.agents/skills/hallmark/scripts/sloplint.mjs assets/css/design-tokens.css assets/css/design-components.css assets/css/design-layouts.css assets/css/design-pilot.css --scope app --genre modern-minimal --url 'http://127.0.0.1:4237/register?locale=en' --url 'http://127.0.0.1:4237/register?locale=af' --json
```

It reports two inherited gate 26a FAILs, one per locale, on body after focus enters the development-only Tidewave toolbar. Direct inspection shows twelve application controls with immediate solid 2px outlines, then two zero-height toolbar-host stops. The lint's small-element fallback climbs from that host to body and reports body as lacking focus. The application regression traverses the actual twelve controls. No body ring, toolbar hiding, tool patch or Floor waiver was added. The mandatory route check remains unresolved; this is not Hallmark-verified completion.

There are zero open REFLEX findings and zero rejected waivers after corrections. Recorded project-grounded waivers retain locked black/white swatches, numeric font-weight tokens, the approved 58px field height and wrapped exact legal links at 320px. An initial invalid Floor waiver was removed. Headings now balance. Two existing gradient-endpoint WARNs remain, one per locale. The lighting regression measures painted contrast across the label region and retains its independent pixel evidence; endpoint sampling includes the brighter decorative shine outside that region.

WELL-114 certification, PR #227's inherited base conflicts, absent exact-head hosted checks and independent Master Gate/resulting-main proof remain separate delivery gaps. Do not merge, recommend merge or mark WELL-112 Done from this local pilot proof.

## Documentation impact and acceptance evidence

This is a presentation migration with a bounded internal field helper and card heading-ID option. No Domain, business interface, lifecycle, schema, persistence or release contract changes. The existing [registration capability map](../../knowledge/identity.registration.json) covers acceptance behavior and references unchanged controller/Domain sources. Its business snapshot is not rewritten. This focused addendum describes presentation contracts and proof limits; automatically generated PR history records the source changes before final review.

The six criteria in the [implementation plan](../../../superpowers/plans/2026-11-15-production-page-pilot.md) are assessed separately:

1. Shared components on the actual template and guide: locally proved by component, controller, LiveView and browser composition checks.
2. Copy/native/business/gate preservation: locally proved by retained controller regressions, exact markup contracts and actual invalid/server-error states.
3. Shared layout recipes and bounded inputs: locally proved by actual threshold/override checks and the retained 6688-assertion guide geometry proof.
4. Bounded light pilot and discernible controls: locally proved under both legacy themes, text/field contrast, focus and forced-color checks. Other templates are excluded from this opt-in.
5. EN/AF responsive/state proof: locally proved for the stated Chromium matrix and limits.
6. Documentation, all mandatory checks and exact-head delivery evidence: partial. The mandatory Hallmark route failure and inherited delivery gaps remain open. Final-head local gates/review/history outcomes must be recorded without implying hosted CI or integration.

Author assessment remains BLOCKED for delivery until those checks resolve. The next independent actor must reconcile WELL-114 and the exact candidate's required hosted CI/Master Gate. Resolving those gaps, including a supported clean product focus lint or explicit project waiver for the development-tool check gap, is required before claiming full verification or an 8+/10 delivery score.
