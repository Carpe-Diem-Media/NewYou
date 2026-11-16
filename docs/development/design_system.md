# Design-system development

Source-linked mathematical research and proposed implementation rules are in
[Automatic.css 4.0.3 mathematics](research/automatic-css-4.0.3-math.md). This is
engineering research; existing approved values and candidate status remain in
force. It includes an independent arithmetic reference check and the unresolved
direct-source licensing limitation.

The [Phase 1 ACSS module inventory](research/acss-4.0.3-inventory/README.md) records ten module traces, source hashes, proposed decisions and missing proof. It is research for bounded future native-CSS adaptations; it changes no current tokens or component contracts.

The [Phase 2 layout foundations](research/acss-4.0.3-inventory/phase2-layouts.md) document the allocated-space lab, four candidate inputs, intrinsic fitting, container/gutter ownership, breakout geometry and repeatable verification.

## Authority chain

DESIGN.md
    ↓
assets/css/design-tokens.css
    ↓
Phoenix semantic components
    ↓
feature templates and LiveViews

The canonical lane defines new and deliberately migrated UI. The compatibility lane preserves existing NewYou behavior until each scope is migrated:

assets/css/tokens.css and existing legacy UI
    ↓
grandfathered temporarily
    ↓
incremental migration
    ↓
DESIGN.md + executable tokens + semantic components

## Authority levels

**CANONICAL**

- DESIGN.md is the authority for every visual concept and state it defines.
- assets/css/design-tokens.css maps those concepts into namespaced Tailwind v4 theme utilities. It is executable representation, not a second source of truth.
- The owner approved self-hosted Inter on 2026-11-12. Its existing line-height values retain DESIGN.md's approximately 5% increase to the extracted values.
- New recurring visual primitives use semantic Phoenix components, beginning with NewYouWeb.Components.Design.Button.primary_button/1.
- New tokens or design primitives require an explicit authority change in DESIGN.md first.

**TEMPORARY COMPATIBILITY**

- Existing values in assets/css/tokens.css may support currently undefined dark-mode and form validation/error states.
- This compatibility applies only to existing tokens and states. Do not create a new dark or error visual state by inference.
- Existing dark-mode and validation behavior is preserved. Neither is migrated to DESIGN.md.

**LEGACY IMPLEMENTATION**

- Existing DaisyUI classes/themes and default Tailwind visual utilities are grandfathered where they already occur.
- Legacy styling is frozen against new use. DaisyUI is not design authority.
- Existing screens are not required to pass a repository-wide migration before new canonical UI can land.

## Tailwind and enforcement

Tailwind 4 remains CSS-first. Utilities with the design- namespace expose the project tokens. Use Tailwind for structural layout, state variants, and the project breakpoints defined from DESIGN.md: design-tablet at 744px, design-desktop at 1128px, and design-wide at 1441px (the first whole CSS-pixel width above 1440px).

Tailwind's default theme namespaces remain available to grandfathered code because clearing them globally would alter current pages and DaisyUI components. New or increased design bypasses in changed Phoenix frontend and asset source fail mix design.check, which is part of mix check. The check compares changed files with the base revision; local runs use the merge base with origin/main, and CI supplies DESIGN_SYSTEM_BASE_SHA. There is no inline disable.

Legacy debt is baselined by violation-key counts per file. Keys include the finding kind and extracted value where available. New or increased keys fail. The baseline is not location-level provenance tracking, so moving an existing violation within a file can remain tolerated when its key count does not increase.

The scanner reads each source file as one buffer and reports the line from each match offset. It checks static and multiline HEEx class attributes, balanced multiline `class={...}` expressions, CSS `@apply` and declarations, the first quoted literal in direct JavaScript `classList.add/remove/toggle`, `className`, and `setAttribute("class", ...)` forms, and direct JavaScript style-property assignments. The JavaScript check is lexical, not a JavaScript parser; it does not inspect computed class/style values or additional `classList` arguments. The check rejects arbitrary visual values, default palette and DaisyUI classes, unapproved typography/spacing/radius/shadow utilities, default Tailwind breakpoints, raw visual CSS declarations, and light design-token overrides inside dark-mode variants. Layout and accessibility utilities remain available.

`bg-design-primary` is restricted to the semantic primary CTA and the reserved `lib/new_you_web/components/design/enterprise_band.ex` context. This matches DESIGN.md's primary CTA and enterprise-band authorization. The reserved path does not imply that an enterprise-band component exists.

## Component and accessibility rules

- Prefer semantic Phoenix component variants for recurring UI; callers do not supply colors, radii, typography, shadows, or raw class lists to design components.
- Preserve native elements, ARIA attributes, form semantics, and LiveView phx-* bindings.
- Keep browser focus indication; do not add outline-none without an approved visible focus treatment.
- The primary button preserves its native disabled attribute. DESIGN.md does not define a disabled appearance, so a new disabled visual treatment requires an authority decision first.
- Inter is self-hosted under the owner's 2026-11-12 decision. Register font assets only in design-tokens.css and retain their licenses. Other brand fonts and illustrations still require explicit approval.

## Classes, data attributes and native state

Use native CSS and Tailwind v4. CSS versus SCSS is a build-tool choice; either
language can select classes and attributes. This project keeps its CSS-first
pipeline and does not add Sass. `assets/css/design-tokens.css` remains the single
editable source for font families and shared visual values.

Classes identify components and express layout. Data attributes select bounded,
approved component options. Native HTML and ARIA describe interaction state.
For example, `primary_button/1` renders a native button with
`class="ds-design-button ..."` and `data-variant="primary"`. Its component-owned
`data-[variant=primary]:bg-design-primary` utility consumes the same root colour
token as the guide. `secondary_button/1` emits `data-variant="secondary"` and
`design_card/1` defaults to `variant="flat"`, emitting `data-variant="flat"`.
The owner-approved lighting candidate additionally supports `variant="raised"`.
These describe existing appearances; they do not approve new visual variants.

Phoenix components own the emitted variant and all styling utilities. Callers use
the semantic component functions and supported options. They cannot forward
`class`, `data-variant` or `data-treatment` to replace controlled styling, including through atom or
string keys in `rest`. Other metadata such as `data-tracking-id`, native HTML,
ARIA and `phx-*` attributes still pass through. Data attributes are presentation
and metadata only, never authorization or business-state authority.

Use `:hover`, `:focus-visible`, `:disabled` and other native states where they
apply. Use meaningful `aria-expanded`, `aria-selected` or `aria-busy` when the
actual interaction requires them. Do not duplicate those as `data-hover` or
`data-disabled`. `aria-busy="true"` communicates busy status; it does not disable
a control. Pass the native boolean `disabled` when behavior requires it.
`data-state` is reserved for a bounded presentation state with no suitable native
equivalent, and needs an actual component contract before use. A presence
selector such as `[data-loading]` also matches `data-loading="false"`; use exact
value selectors or omit a false attribute.

Keep variant styling in one place. Flat components use Tailwind attribute variants within their modules.
The opt-in lighting treatment uses the components layer in
`assets/css/design-components.css`; flat fill utilities do not match lit controls,
so the two paths do not compete over the same visual properties. If custom component CSS is needed later, scope selectors to the component
class and put them in the components cascade layer. Avoid escalating specificity
or adding `!important` to resolve competing definitions. Preserve token enforcement
for attribute-selected utilities as well as ordinary utilities.

Responsive behavior remains CSS-owned. Use intrinsic sizing and wrapping first,
container queries for available component space, and approved viewport
breakpoints for page composition. Do not create JavaScript-driven `data-mobile`
or `data-desktop` state. The guide's existing `data-alignment="start|center"`
selects an intentional grid option; media queries determine its layout at each
width. Variant attributes do not replace layout utilities or responsiveness.

Adopt this convention as each production scope migrates. Keep existing legacy
styling on its compatibility lane. This internal presentation change introduces
no material capability, lifecycle, schema or Domain interface, so a new capability
JSON map is exempt. The automatically generated PR history still applies.

The owner-approved implementation is recorded at source commit
`4ee2ecfa4d8a5cbc2b275f8a62d2c0ba423e54b2`. Repeatable verification uses:

```sh
ERL_FLAGS='+S 4:4' mise exec -- devcore-project run test -- mix test test/new_you_web/design_system_infrastructure_test.exs test/new_you_web/live/design_system_live_test.exs
ERL_FLAGS='+S 4:4' mise exec -- devcore-project run dev -- mix assets.build
ERL_FLAGS='+S 4:4' mise exec -- devcore-project run dev -- mix design.check
ERL_FLAGS='+S 4:4' mise exec -- devcore-project run test -- mix check
ERL_FLAGS='+S 4:4' mise exec -- devcore-project run test -- mix check.deep
BROWSER_TOOLS_ROOT=/tmp/newyou-refinement-tools DESIGN_SYSTEM_URL=http://127.0.0.1:4237 CHROME_PATH=/usr/bin/google-chrome node test/assets/design_system_browser.mjs
```

Observed results for this batch: 32 focused tests pass; assets, design enforcement
and the deep gate pass. The guide browser proof verifies compiled variants,
48px button heights, approved hover, native disabled behavior, responsive grids,
token propagation, keyboard focus and reduced motion. It explicitly configures
a desktop pointer and checks hover-media support. The separate typography browser
proof, four Node contrast tests and 54 routing/smoke tests also pass.
The supported Hallmark render reports zero FAIL/open REFLEX/WARN with the existing
numeric-weight waiver. Its static reader accepts CSS, so the two component `.ex`
arguments do not count as inspected source files; the rendered guide exercises
the actual changed components. The bounded independent source review reports no
actionable findings and does not constitute Master Gate certification.

The canonical fast gate exits 2 after 371.4 seconds, with 635/636 tests passing.
The unchanged password-session rollback test at
`test/new_you/identity/password_session_test.exs:324` fails its global token-count
assertion at line 344. An isolated retry passes 1 test with 16 excluded. Its
full-suite failure cause is unproven and recorded under WELL-114. No fixture repair
or database cleanup was performed. Existing registration/Tidewave Hallmark gate
26a and WELL-114 independent resulting-main certification remain open. Hosted CI
and exact-head independent review are separate gates; this batch does not certify
the whole site or delivery complete.

## DaisyUI migration status

DaisyUI can coexist with the canonical layer while existing components remain grandfathered. Its component classes carry visual styling, so globally retheming it to project colors would change existing pages. The least disruptive path is progressive replacement of DaisyUI visual components in deliberately migrated scopes. Retaining DaisyUI as behavior-only infrastructure would require separating its visual rules and verifying each migrated component; WELL-80 does not perform that work.

## Hallmark

/hallmark consumes the existing design system. It is not a design-authority or enforcement boundary.

    /hallmark

    Use the root DESIGN.md as the locked design authority.

    Preserve the existing Phoenix/LiveView architecture and behaviour.
    Preserve HEEx bindings, events, forms, routes and accessibility semantics.
    Use existing semantic Phoenix design components first.
    Use only approved project design tokens.
    Do not invent colours, typography, radii, shadows or spacing tokens.
    Do not expand DaisyUI styling.
    Do not introduce React, Vue, Svelte or another frontend framework.
    Do not alter Ash resources, policies, actions or other domain logic.
    Do not fill dark-mode or validation gaps through guesswork.
    If the requested design requires a token/component/state not authorized by DESIGN.md or the existing compatibility tokens, STOP and report the missing design decision.

Historical pre-centralization evidence: the initial sloplint pass reported four REFLEX findings and no FAILs: it recommends tinting the explicitly specified white surface/on-primary and black on-canvas tokens, and counts numeric font-weight tokens (and Tailwind's imported Georgia default) as extra font families. Those color values map directly to DESIGN.md; At that initial revision Inter was the approved single project fallback and legacy framework font defaults remained grandfathered. The site-wide font decision below supersedes those family defaults.

## Migration state

WELL-80 establishes the infrastructure only. Existing page composition, forms, layouts, dark mode, validation/error styling, and DaisyUI usage remain unchanged. The later owner-approved font centralization applies across these pages without migrating their other styling. Migrate those scopes in separate reviewed work. Dark-mode authority, validation/error authority, and the remaining in-app product visual system are follow-up design decisions.

## LiveView visual reference

WELL-112 adds `/dev/design-system` and `/dev/design-system/preview` for development and tests. The production router does not compile either route. This is an internal refinement tool; its example copy does not approve participant content or a replacement design.

Implementation source revision: `3c966c8067926e021d6b480d6b11b231510940a3`. Verify current source before extending this map. This map is engineering documentation, not design authority or live delivery state.

Start the worktree server through the pinned toolchain and DevCore:

```sh
NEW_YOU_PORT=4237 mise exec -- devcore-project run dev -- mix phx.server
```

Use a free permitted worktree port in `4221..4239`. The primary checkout uses `4220`. Run `devcore-project doctor` first. If existing migrations are pending, use the same DEV wrapper and worktree port for `mix ecto.migrate`; do not reset shared data or create another database stack.

The guide contains all approved palette tokens, twelve type specimens, font weights, line heights, tracking, spacing, button/link examples, cards, Heroicons, grid controls, breakpoint/container measurements, foreground/background contrast and radius/shadow samples. Its specimens consume the shared CSS, not copies of the values in Elixir or JavaScript. Inter is bundled locally; the guide identifies the central body/display tokens and explains the sans-serif network-failure fallback.

### Edit one source

Edit the `:root` block in [design-tokens.css](../../assets/css/design-tokens.css). Existing `design-*` Tailwind utilities map to those variables. For example:

```css
:root {
  --palette-primary-srgb: #0061ef;
  --palette-secondary-srgb: #2d2c2b;
  --primary: var(--palette-primary-srgb);
  --secondary: var(--palette-secondary-srgb);
  --radius: 16px;
  --box-shadow: none;
  --grid-gap: var(--space-lg);
}

@theme static {
  --color-design-primary: var(--primary);
  --color-design-ink: var(--secondary);
  --radius-design-md: var(--radius);
  --shadow-design: var(--box-shadow);
}
```

Edit source colors through `--palette-*-srgb`. A feature-detected identity OKLCH layer references these sources through the existing semantic names, so editing only the sRGB fallback alias does not change supported-browser colors. Inline developer-tool overrides on `--primary` remain possible. The guide and canonical application components share these values. This does not migrate legacy DaisyUI or `ny-*` screens. `--secondary` is the existing neutral ink role, not another saturated CTA. `--radius` controls cards; the other approved component radii retain their separate tiers. `--box-shadow` starts at `none` because the approved system is flat.

Keep deliberate changes to locked values consistent with [DESIGN.md](../../DESIGN.md). `mix design.check` still checks the approved palette, resolves alias chains and identity relative OKLCH conversions, and rejects mismatches, unknown references, cycles and extra color tokens. Styles can consume declared aliases without an inline-style exemption or new raw values. The existing design-debt baseline remains intact.

Typography specimens show their exact scale size, even on a narrow screen. The responsive component preview separately demonstrates display sizes and grid reflow. The tablet, desktop and wide preview widths derive from the matching breakpoint tokens. Tailwind compiles media-query thresholds during the asset build; editing their CSS source requires rebuilding assets. The development watcher does this automatically. Changing a breakpoint property only in browser developer tools cannot rewrite an already compiled media query.

### Source and interaction map

1. [Router](../../lib/new_you_web/router.ex) compiles the two routes only when `Mix.env()` is `:dev` or `:test`, through the existing browser pipeline and root layout.
2. [DesignSystemLive](../../lib/new_you_web/live/design_system_live.ex) renders the [guide template](../../lib/new_you_web/live/design_system_live.html.heex). `handle_params/3` validates the URL's card count, row alignment and viewport against finite choices. Counts range from one to nine. Invalid or malformed values fall back safely.
3. `handle_event/3` patches validated display choices into the URL with replacement history. They survive a reload; a new URL without choices restores defaults. These assigns are transient presentation state. There is no database, async work, Domain mutation, grant or business lifecycle.
4. [DesignSystemComponents](../../lib/new_you_web/live/design_system_components.ex) provides specimen metadata and token names. The [button](../../lib/new_you_web/components/design/button.ex), [card](../../lib/new_you_web/components/design/card.ex) and [link](../../lib/new_you_web/components/design/link.ex) modules own reusable appearance. They reject caller class overrides and retain native attributes, ARIA and LiveView bindings. A card remains noninteractive; its child action is a native link.
5. [DesignSystem browser hook](../../assets/js/design_system.js) reads computed CSS, measures opaque foreground/background samples, copies token identifiers and reports demo actions. It never saves theme edits. Clipboard failure produces a visible manual-copy message. Unsupported transparent samples report that contrast was not measured.
6. [Guide CSS](../../assets/css/design-system.css) scopes the reference styles to `.ds-guide`. Cards use four half-width tracks at tablet and six at desktop, with two tracks per card. `:nth-child` and `:nth-last-child` rules centre one or two remaining cards without stretching them. The preview is a same-origin iframe using the same components and app CSS. It scales visually to fit the panel while retaining its actual CSS viewport width. A browser measurement supplies only the local scale variable; it does not override theme tokens.

Content renders before LiveView connects. With scripting disabled, the specimens and CSS remain visible and computed-value labels identify themselves as CSS values. Copy controls stay disabled; the page explains which tools need JavaScript. The preview contains no nested iframe. Global legacy theme handling remains unchanged; this reference uses the approved light baseline without inventing dark/error states.

### Repeatable verification

Use the repository toolchain and isolated DevCore TEST profile for Elixir checks:

```sh
ERL_FLAGS='+S 4:4' mise exec -- devcore-project run test -- mix test test/new_you_web/live/design_system_live_test.exs test/new_you_web/design_system_infrastructure_test.exs test/new_you_web/security/authentication_reachability_test.exs
ERL_FLAGS='+S 4:4' mise exec -- devcore-project run test -- mix check
ERL_FLAGS='+S 4:4' mise exec -- devcore-project run test -- mix check.deep
ERL_FLAGS='+S 4:4' mise exec -- devcore-project run test -- mix assets.build
node --test test/assets/design_system_test.mjs
git diff --check
```

[LiveView tests](../../test/new_you_web/live/design_system_live_test.exs) cover sections, URL state, malformed inputs, preview rendering and production-route exclusion. The production check compiles the real router AST with its environment changed to `:prod` and inspects the resulting routes. [Infrastructure tests](../../test/new_you_web/design_system_infrastructure_test.exs) exercise alias resolution and failure cases, CSS enforcement and component attribute boundaries. The route-security allowlist includes both development routes explicitly.

[Browser proof](../../test/assets/design_system_browser.mjs) requires external `puppeteer-core` tooling and Chrome. It does not add an application package. Set `BROWSER_TOOLS_ROOT` to the directory containing that tooling's `package.json` and `node_modules`, and adjust the server URL if necessary:

```sh
BROWSER_TOOLS_ROOT=/tmp/newyou-refinement-tools DESIGN_SYSTEM_URL=http://127.0.0.1:4237 CHROME_PATH=/usr/bin/google-chrome node test/assets/design_system_browser.mjs
```

Observed author verification used Elixir 1.20.5, OTP 29.1.2, Tailwind 4.3.3 and system Chrome:

- The initial focused tests reproduced the absent route and missing palette-alias support. The resulting focused suite passed 31 tests.
- The two JavaScript contrast tests passed, including invalid channels and AA/AAA threshold boundaries.
- Browser proof passed at 320, 390, 743, 744, 1127, 1128, 1440 and 1920px. Eighteen centred-row cases passed across tablet and desktop widths. LiveView URL controls, the real iframe width, live primary/radius/shadow propagation, contrast refresh, keyboard focus and reduced motion passed with no browser errors.
- `mix assets.build` passed. `mix check.deep` passed with zero errors. The fast gate's formatting, compilation, design, architecture, usage-rule, Credo and Sobelow stages passed before its ExUnit stage failed.
- Historical initial verification: full `mix check` was blocked by the shared TEST database state tracked in WELL-114. Retained fixture rows predate this task; current main cannot load an `identity_recovery_completed` evidence type, and whole-resource Communications reads encounter unrelated rows. An unchanged Disposition test independently reproduced three failures. No shared fixture data was deleted. The full-suite failure is not waived.

The first hosted PR run exposed missing CI classification for `DESIGN.md`, `.hallmark/log.json` and `.hallmark/preflight.json`. [The classifier](../../tools/foundation_integrity_routing.py) now names these exact engineering files. [Routing regressions](../../tests/test_foundation_lane_routing.py) reproduced all three failures before correction and preserve rejection of unclassified neighbours. Design-only changes select Application CI without forcing Dialyzer; the guide's Elixir source independently selects the deep lane. Foundation Full remains nightly-only. This routing correction changes no application behavior from the implementation revision above.

### Hallmark and visual review

The existing `DESIGN.md` supplies the direction; there is no new theme, brand font or stock imagery. This is app scope, so the marketing hero review is inapplicable. The exact render command was:

```sh
HALLMARK_PUPPETEER=/tmp/newyou-well-112-tools CHROME_PATH=/usr/bin/google-chrome node /home/jcschoeman96/.agents/skills/hallmark/scripts/sloplint.mjs assets/css/design-tokens.css assets/css/design-system.css --scope app --genre modern-minimal --url http://127.0.0.1:4237/dev/design-system --json
```

The final observed result was zero FAIL, zero open REFLEX, zero WARN and three waived findings. Gate 7b's two findings are the exact approved black `on-canvas` reference swatch and its Tailwind mapping; tinting either would change locked values. Gate 37 treats numeric font weights as font families. At that historical revision the source had one approved Inter fallback family. The specimen-only line-height waiver records why the reference must retain the approved scale rather than rewrite it.

The initial rendered FAIL at 320px was a wrapped navigation control; shorter index labels fixed it and the rerun passed. The independent fresh-context finish review reported one state-clarity finding on the disabled specimen. Its lock icon and explicit unavailable label now provide a non-color cue while the approved button appearance and native disabled behavior remain intact. The author checked the recapture. The existing Tidewave developer overlay can cover content in captured phone views; it is not part of the design system.

Documentation impact: this section is the source-linked handoff for the developer reference and shared styling extension. Ash interfaces, persistence constraints, asynchronous schedules and business recovery are inapplicable. A cold-start walkthrough followed the route, validated display choices, semantic components, token mapping, browser measurements and executable tests against the implementation revision above. Full-suite certification remains subject to WELL-114; independent Master Gate, exact-head hosted CI, trusted-operator attestation and owner merge authorization remain required before integration.

References studied: [Frames layouts](https://getframes.io/layouts/?brx_c0563d=style-guide), [Automatic CSS documentation](https://docs.automaticcss.com/), [Tailwind v4 theme variables](https://tailwindcss.com/docs/theme), and the local LiveFrame `AutomaticCSS.FidelityResolver`. These inform implementation; NewYou's repository authority controls the result. No LiveFrame or WordPress runtime dependency was added.


### Refinement token ownership

The owner accepted OKLCH representation, color-mix relationships, decorative surface comparisons and fluid sizing candidates. The current palette is authored once in `--palette-*-srgb` variables. Relative `oklch(from var(...) l c h)` preserves the exact color rather than rounding new constants. Unsupported relative-color syntax retains the original sRGB aliases. [Palette enforcement](../../lib/mix/tasks/design.check.ex) recognizes only the identity conversion, with regression tests rejecting channel changes, transparency, unknown references and cycles.

`--design-surface-tint` and `--design-surface-shade` are opaque color-mix specimens with browser-measured contrast against the existing ink. The gradient, seeded SVG noise and translucent scrim remain decorative candidates in `#surfaces`. Their captions state usage limits, and the guide does not infer whole-gradient or image-overlay contrast from a single flat color. The SVG is a local data URL with no external request. `--design-noise-opacity`, `--design-noise-size`, `--design-gradient-angle` and `--design-overlay-strength` control the treatment. The `bg-design-wash` Tailwind utility consumes the shared gradient token. Existing application cards retain `--box-shadow: none` and the approved flat surface.

The `#fluid` specimens read independent semantic endpoints for display, body, block padding and inline gutters. The viewport boundaries are `--fluid-vmin` and `--fluid-vmax`. Keep the start below the end. The static minimum works without advanced math; a feature-detected trigonometric ratio supplies continuous interpolation, and native `progress()` overrides it where supported. All tiers use the same endpoint tokens. The displayed method comes from CSS. Current-size outputs read computed styles of the actual specimens. Minimum and maximum outputs retain authored rem values and also show resolved pixels from hidden CSS probes, so all three values can be compared without JavaScript unit conversion. JavaScript does not resize text or implement the fluid formula.

Rem endpoints preserve user root-font preferences. At a 16px root, display reaches 64px; at a larger root, that maximum grows with the user preference. Existing fixed typography, spacing, line-height, tracking and responsive breakpoints remain the canonical application baseline. The fluid scale and surface candidates require later deliberate adoption in application components; adding reference specimens does not migrate legacy screens.

The canvas sampler rejects invalid assignments, transparent colors and unavailable/throwing contexts. It accepts equivalent valid color representations without reusing stale canvas state. Capability labels describe the actual relative OKLCH, color-mix and progress feature checks. Without JavaScript, the CSS specimens remain visible and measurement text makes no claim that a browser value has been read.

Documentation impact: this extends the existing developer-reference map; no new Domain lifecycle, persistence, authorization or background job is introduced. Independent post-merge certification for WELL-114 remains recorded in Plane. The owner explicitly permitted UI work with that gap open; this is not permission to merge or certify delivery complete.


Refinement source revision: `4b1a17ac90a39027222367928e822281027ea13b`. Bounded independent development reviews covered specification compliance and code quality. The initial comparison-unit mismatch was corrected by showing CSS-resolved pixel endpoints beside rem tokens. The subsequent review suggestion to exercise conservative color fallbacks was implemented. These reviews do not supply independent merge attestation.

Observed frontend proof at that source revision: the asset build, four Node tests and the external browser script pass. Browser coverage checks all four fluid candidates below, at, between and above viewport bounds; exact midpoint values; resolved endpoint outputs; viewport-bound edits; an 80px display maximum at a 20px root; forced native-to-trigonometric-to-static progression; sRGB source equivalence; forced relative-color, mixing and gradient fallbacks; no-JavaScript specimens; original grid/iframe controls; focus; reduced motion; and no page errors. System Chrome is version 155.0.8059.84. This is Chrome evidence, not a claim that every browser engine was exercised.

The supported Hallmark command above was rerun with `/tmp/newyou-refinement-tools` for external Puppeteer. It rendered five screenshots and reported zero FAIL, zero open REFLEX, zero WARN, one waived finding and zero rejected waivers. The one waiver is gate 37's numeric-weight/font-family misclassification. An auxiliary CSS-only run without the locked genre configuration rejected an existing line-height waiver; the documented two-file command with the existing app scope and modern-minimal genre passed. No lint rule or enforcement gate was weakened. Phone and desktop crops of the added sections were also inspected.


Engineering evidence for the refinement:

- `ERL_FLAGS='+S 4:4' mise exec -- devcore-project run test -- mix test test/new_you_web/live/design_system_live_test.exs test/new_you_web/design_system_infrastructure_test.exs test/new_you_web/security/authentication_reachability_test.exs` passed 32 tests after the endpoint correction.
- `ERL_FLAGS='+S 4:4' mise exec -- devcore-project run test -- mix check` passed 632 tests at the initial refinement revision and again after the endpoint correction, the latter in 324.8 seconds at source revision `dff7832dc48bd405f6f2e7f9915e5615aaedf334`. All preceding fast engineering stages passed. The subsequent `4b1a17a` commit changes only the JavaScript capability probe and browser regression coverage; its assets build, Node/browser tests and design check passed separately. Elixir, HEEx and CSS source are unchanged between those revisions.
- `ERL_FLAGS='+S 4:4' mise exec -- devcore-project run test -- mix check.deep` passed after the final JavaScript correction, with zero errors and zero skips.
- `python3 -m unittest tests.test_foundation_lane_routing tests.test_foundation_smoke` passed 50 tests. `git diff --check` passed.

The old dirty-TEST failures above are historical. The merged WELL-114 correction and its separately owner-authorized environment repair removed that technical blocker; this implementation performed no reset or historical-row cleanup. Missing independent resulting-main certification remains a distinct delivery gate in Plane. Hosted CI for the updated draft PR and independent Master Gate review remain separate from these local observations.


Final visual correction at `52a56259b912c930cd44517d0cbe5c942387babb`: empty endpoint probes are explicitly excluded from layout. A browser regression first failed because the probes had nonzero height; it then passed after the CSS correction, while all computed endpoint outputs still matched. The final browser suite, asset build, supported Hallmark render and design check passed again. The final change after the recorded engineering suite affects only CSS probe display and the corresponding browser assertion; it changes no Elixir or HEEx source. Exact-head hosted CI remains required for integration.

## Central font selection, 2026-11-12

The owner approved locally served Inter and required future family changes to propagate throughout the site from one CSS edit. The editable family tokens live in `assets/css/design-tokens.css`:

```css
--font-body: Inter, sans-serif;
--font-display: var(--font-body);
```

Change `--font-body` to select the site-wide family. Headings follow automatically. A deliberately separate heading family uses `--font-display` in that same token block. The root HTML and headings, canonical Tailwind family utilities, default sans/serif utility mappings and legacy `--ny-font-body`/`--ny-font-display` aliases consume those roles. Existing legacy family literals were removed rather than granting an enforcement exception. Legacy colors, sizing, states and composition remain on their existing lane. Source-code samples retain their existing monospace treatment.

A token selects a font; it does not download an arbitrary family. A replacement custom font needs its licensed WOFF2 asset and one `@font-face` registration in the same CSS file. Change the family token after registering it. No per-page font declarations or Sass build is required. The single Inter variable asset preserves existing weights, including legacy 600, while canonical components keep 400/500/700. `font-display: swap` keeps fallback text available while loading. No metrics override is guessed; font-swap layout stability remains a measured review concern.

The official upstream Inter 4.1 archive supplies `priv/static/fonts/inter/InterVariable.woff2` and its unmodified SIL Open Font License. `priv/static/fonts/inter/README.md` records upstream provenance and the font hash. The application already serves the fonts static path. No runtime CDN request or application dependency is added.

Repeatable read-only browser proof:

```sh
BROWSER_TOOLS_ROOT=/tmp/newyou-refinement-tools DESIGN_SYSTEM_URL=http://127.0.0.1:4237 CHROME_PATH=/usr/bin/google-chrome node test/assets/design_typography_browser.mjs
```

The proof checks real font loading at weights 400/500/700; one-token family propagation across the guide, EN/AF registration, its language-choice page, the homepage and the guide preview; independent heading selection; five viewport widths; and readable server-rendered registration with visible inputs when font requests fail and JavaScript is disabled. This adds no form submission or Domain state mutation. The broader field/state/layout migration remains separate from this font baseline.

Authentication proof pages retain their strict Content Security Policy, with `font-src 'self'` added so the same local font can load. Scripts, external fonts, arbitrary origins and frames remain disallowed by their existing policy. Exact-header controller regressions cover magic login, password reset, password session and verification. These proof pages remain behind their existing development gates; the browser test does not enable those gates.

Documentation impact: this batch changes visual font selection/delivery and the minimum same-origin font permission needed by existing styled proof pages. It adds no Domain/application interface, lifecycle, persistence or schema contract. A new semantic capability map is exempt for this typography change; the existing registration map remains authoritative for its described implementation. The PR history record is regenerated through the required knowledge-capture command before review.

Observed typography-batch verification:

- DevCore doctor passed DEV and TEST reachability/authentication without exposing managed credentials. `mix assets.build` and `mix design.check` passed through their DevCore profiles.
- The typography browser proof passed on all six live/reference routes at 320/390/744/1128/1920px, including real 400/500/700 font loading, live family overrides, independent heading selection, product keyboard focus and blocked-font/no-JavaScript fallback. The original `test/assets/design_system_browser.mjs` also passed. Both use the documented external Puppeteer setup and system Chrome; Firefox/WebKit, full text-zoom coverage and font-swap layout-shift measurement were not added by this batch.
- `node --test test/assets/design_system_test.mjs` passed four tests. `mise exec -- python3 -m unittest tests.test_foundation_lane_routing tests.test_foundation_smoke` passed 54 tests after the smoke fixture was updated to include the newly referenced font provenance files. No smoke rule was weakened.
- `ERL_FLAGS='+S 4:4' mise exec -- devcore-project run test -- mix check.deep` passed with zero errors/skips. The full `mix check` command passed its earlier engineering stages but exited 2 after 342.2 seconds: 630/632 tests passed. The unchanged EmailVerificationTest at line 55 reads all Token rows with `[original] = Ash.read!(Identity.Token, authorize?: false)` and fails in the retained TEST state. Its separate AF Chromium proof also failed; that cause remains unconfirmed. No reset or global-read workaround was applied. The failures are recorded on WELL-114.
- The focused six-file controller/guide run passed 47/48; a passive magic-login count assertion failed, then its isolated rerun passed. That transient failure is retained in the evidence; its cause is unproven. The four exact CSP header regressions passed.
- The documented two-file Hallmark command on the guide passed with zero FAIL/open REFLEX/WARN/rejected waivers and one numeric-weight/font-family waiver. The additional `sloplint.mjs assets/css/tokens.css --scope app --genre editorial --url 'http://127.0.0.1:4237/register?locale=en' --json` render reports one gate 26a FAIL on `body` after tabbing through the existing Tidewave toolbar. Direct keyboard inspection shows all twelve registration controls with immediate solid 2px focus outlines, followed by the non-product developer toolbar. The new browser regression verifies visible product focus on EN/AF registration and language choice. This DEV-tool finding is recorded, not waived or presented as an entirely green Hallmark result. Phone/desktop renders were inspected.
- A bounded independent source review found no functional font/CSP/provenance issue and one stale documentation note, which was corrected. It did not supply independent merge certification.

The font requirement is implemented; the complete WELL-112 candidate remains BLOCKED for delivery verification. Highest-risk uncertainty is the unconfirmed AF proof failure. Next actions are fixture/proof reconciliation under WELL-114, a clean product-only keyboard lint result that accounts for Tidewave, fresh exact-head hosted CI and independent Master Gate. After this baseline, the planned registration component/state/layout migration and cross-engine checks remain separate unfinished adoption work.

## Overhead lighting specimens

The owner approved adding the proposed soft-depth treatment to the guide.
`/dev/design-system#lighting` compares flat and lit controls, flat and raised cards,
and the neutral canvas/panel/raised surface hierarchy. The expandable Lighting
tokens list reads current computed values from the same root variables.

Use `treatment="lit"` on the existing primary/secondary button functions and
`variant="raised"` on `design_card/1` for these opt-in examples. Default flat
appearances remain unchanged. Button components own `data-treatment` and reject
caller collisions, including forwarded atom/string keys. Cards retain their
controlled `data-variant`. No browser-side value becomes business state.

The canonical token stylesheet owns surface mix strengths, directional edge
alpha, shadow geometry/strength and action gradient/rim colours. Gradients derive from the
existing primary source; hover derives from the existing separately authored
primary-hover source. Colour-mix enhancement adds the material treatment over
solid/no-cast-shadow fallbacks. Pressed controls use inset edges and no cast
shadow. Disabled controls do not receive hover/pressed treatment. Forced colours
remove gradients and shadows while preserving native control identification.

Lit buttons retain a 48px minimum height and grow for wrapped or resized labels.
This preserves normal geometry while avoiding clipping at 200% text size. Flat
controls retain their existing fixed-height implementation. Border width remains
one pixel; casts are short and downward, without global shadows on ordinary
content or a legacy-site retint. No animation is introduced.

Repeatable proof with external browser tooling:

```sh
BROWSER_TOOLS_ROOT=/tmp/newyou-refinement-tools DESIGN_SYSTEM_URL=http://127.0.0.1:4237 CHROME_PATH=/usr/bin/google-chrome node test/assets/design_lighting_browser.mjs
```

The proof samples actual rendered button pixels beside the label across its
vertical region in default, hover and pressed states. It also checks semantic
lightness order, native states, keyboard focus, 320px reflow, long bilingual
labels with doubled text size, live primary-token propagation, forced colours
and a solid-fill fallback. Candidate material amounts still need owner visual
review before production-page adoption. This is a presentation extension with
no Domain/schema/lifecycle change; the existing semantic-map exemption applies.

Observed lighting verification at source
`f5973a306045ce8a97de6a8cd1f1936d2d9d26f6`: final canonical `mix check` exits 0,
637 tests passed in 326.8 seconds; `mix check.deep` exits 0 with zero errors/skips.
The 33 focused tests, assets build, `mix design.check`, four Node contrast tests,
54 Python routing/smoke tests and all three browser scripts pass. Guide Hallmark
reports zero FAIL/open REFLEX/WARN and the existing numeric-weight waiver. Actual
PNG samples give minimum white-label contrast of 5.08:1 at rest and 8.65:1 during
hover/press. The proof also asserts raised-card and secondary edge direction,
including reversed edges while pressed. The expanded token list fits at 320px.

The bounded independent source review found no actionable defect. It did not
execute checks or provide Master Gate certification. Runtime proof uses system
Chrome and external Puppeteer; no Firefox/WebKit claim is made. A solid fallback
is exercised by token overrides, without emulating an engine that lacks
colour-mix support. Prior registration/Tidewave gate 26a and WELL-114 independent
resulting-main certification remain open. The earlier global-count failures did
not recur in this run; their cause is not thereby proved fixed. Hosted CI and
independent review of the final PR head remain required before integration.

## Local token consumption and numeric input checks, 2026-11-13

Visual Tailwind mappings now use `@theme static inline`. Utilities consume the
semantic role at the element, so a local `--primary`, `--primary-hover`,
`--radius` or `--radius-xl` override reaches the shared controls. Breakpoints
remain in a separate static theme block because Tailwind compiles media queries.
Changing a breakpoint requires rebuilding the stylesheet.

Lighting relationships are declared once for the root and shared button/card
selectors. Their solid fallbacks, gradients, edges and shadows resolve against
that component's semantic inputs. Edit the source inputs in
`assets/css/design-tokens.css`; editing only a derived root output does not
replace a component's own calculation. Approved numeric and palette defaults
have not changed. Local palette-source aliases and local fluid-bound overrides
are not part of this contract. Fluid sizing remains a guide candidate.

`mix design.check` now validates the known literal numeric source inputs. Fluid
viewport boundaries must be positive rem values with the minimum below the
maximum. Size endpoints must be non-negative rem values; decreasing sizes are
allowed. Mix strengths must be percentages within 0..100 and noise opacity must
be unitless within 0..1. Missing, duplicate, non-finite and expression-valued
inputs fail the gate. This deliberately small check does not parse all CSS,
validate arbitrary runtime overrides or certify contrast.

The added `test/assets/design_token_scope_browser.mjs` checks local flat/lit
buttons, flat/raised cards, sibling isolation and a root edit. It also removes
the colour-mix enhancement rules through CSSOM and checks the real solid
fallback declarations. `design_lighting_browser.mjs` uses the same fallback
selection instead of injecting derived root outputs. These are Chrome feature
selection checks, not evidence from an older browser without colour-mix.

Documentation impact: no Domain capability or durable interface changes. The
existing design-system handoff remains canonical; a new capability map is
exempt for this CSS-consumption and engineering-validation batch. WELL-114's
independent resulting-main certification gap remains open under the owner's
recorded continuation exception. This batch does not certify merge readiness.

Observed hardening verification for implementation source
`abf7d4fdd1130835a6360d17c471b662ed7ef3be`:

- `ERL_FLAGS='+S 4:4' mise exec -- devcore-project run test -- mix check`
  exited 0: 639 tests passed in 344.8 seconds. It includes design enforcement,
  architecture, Credo and security checks. Expected failure-path logs did not
  produce an ExUnit failure.
- The same TEST prefix with `mix check.deep` exited 0 with zero errors/skips.
  `mix test test/new_you_web/design_system_infrastructure_test.exs
  test/new_you_web/live/design_system_live_test.exs` passed 35/35.
- The DEV prefix with `mix assets.build` passed. `mix design.check` passed,
  and `mix format --check-formatted` passed for the changed Elixir files.
- With `BROWSER_TOOLS_ROOT=/tmp/newyou-refinement-tools` and
  `CHROME_PATH=/usr/bin/google-chrome`, run `node` on
  `test/assets/design_token_scope_browser.mjs`,
  `test/assets/design_system_browser.mjs`,
  `test/assets/design_lighting_browser.mjs` and
  `docs/development/research/design_math_browser.mjs`. All passed; the last
  reports 212 assertions in Chrome 155. Lighting label contrast minima remain
  5.08:1 at rest and 8.65:1 on hover/press.
- `python3 docs/development/research/design_math_reference.py` passed 126
  arithmetic assertions. `node --test test/assets/design_system_test.mjs`
  passed 4/4. `mise exec -- python3 -m unittest
  tests.test_foundation_lane_routing tests.test_foundation_smoke` passed 54/54.
- The documented Hallmark command, using all three targets
  `assets/css/design-tokens.css assets/css/design-components.css
  assets/css/design-system.css`, rendered five screenshots and reported zero
  FAIL/open REFLEX/WARN/rejected waivers and one existing gate 37 waiver.
  Numeric font-weight tokens are not additional font families. The guide
  renders were inspected; no redesign or audit workflow was invoked.
- Bounded independent specification and quality reviewers found no actionable
  source defects. The quality review's stale-plan-checkbox nit was corrected.
  A comparison against `ea25cd3` confirms all literal token defaults unchanged.

These commands exercised the implementation committed at the source SHA above;
subsequent handoff/history changes contain no application-code changes. Hosted
CI must still bind the final PR head independently. Chromium fallback selection
does not establish Firefox/WebKit support or unsupported-engine behavior.

Batch criteria: local propagation, numeric input enforcement and documented
regression proof pass. Overall delivery remains BLOCKED by the inherited
WELL-114 certification gap, with the owner's continuation exception preserved.
Author self-assessment for this implementation batch: requirements 4/4,
observed verification 2/3, correctness/architecture 2/2, handoff 1/1, raw 9/10,
capped at 5/10 for the open delivery blocker. Confidence is 90%, based on the
observed tests and bounded reviews; hosted checks and other browser engines
remain uncertainty. To reach 8+/10 delivery evidence, the responsible independent
reviewer must certify WELL-114/resulting-main proof and the final PR head with
required hosted checks; the earlier DEV-toolbar Hallmark finding also remains
recorded. No score grants merge authority.

## Main guide button presentation correction, 2026-11-13

The owner reported that the premium button treatment appeared reverted. The
lighting CSS remained intact, but the main Buttons & links section and
responsive preview still selected the flat component default. Both now
explicitly use the existing `treatment="lit"` option. The main disabled example
uses that treatment too. The labelled flat comparison remains in Lighting &
depth. Shared component defaults and token values are unchanged.

Implementation source: `f4418d3e2e6ba8cb0c47b696a1a022cee6339e59`.
The LiveView regression first failed because the main primary example lacked
`data-treatment="lit"`; the browser regression first failed because its computed
background image was `none`. The final regression asserts the main example's
actual gradient, distinct top/bottom borders and shadow, as well as the
preview's lit primary and secondary components. This protects the presentation
that previously passed generic component-presence checks.

The existing focused command passed 35/35. Assets build, the Chrome guide and
lighting proofs, deep engineering check and Python routing/smoke 54/54 passed.
The supported three-target Hallmark render reported zero FAIL/open REFLEX/WARN
and the existing numeric-weight waiver. The main button section render was
inspected. A bounded independent source review found no actionable defect;
it did not certify merge readiness. Full-suite and final-head history evidence
is recorded below and in Plane. The existing handoff-map exemption and open
WELL-114/resulting-main, DEV-toolbar and hosted-review gaps remain applicable.

Final correction verification: canonical DevCore TEST `mix check` exited 0 with
639 tests passing in 350.4 seconds for the implementation source above. The
same commands documented in the hardening section were used for focused tests,
assets build, design enforcement, deep check, browser proofs, routing/smoke and
Hallmark. `mix check.deep` reported zero errors/skips. Only handoff and generated
history files changed afterward. Final-head hosted CI and independent merge
review remain separate requirements; this correction does not close WELL-114.

## Lit Primary sheen refinement, 2026-11-14

The owner requested a more visible gradient and shine on the existing Lit
Primary. `--action-light-strength` is now 14%, and the three-stop gradient fades
from the lightened top to the semantic action colour at
`--action-shine-height: 12px`, then to the existing 6% shaded base. The hover
and pressed gradient uses the matching hover role. These relationships still
resolve at the component. Borders, shadows, geometry and flat/fallback states
retain their existing definitions. The effect is static.

Edit the two inputs in `assets/css/design-tokens.css`; both are displayed in
the guide's Lighting tokens list. Keep the bright band above the label.
Increasing its height requires checking wrapped and resized label contrast,
not only a short button. The chosen 12px ends before the shared 14.3px block
padding and the label. It does not require another font, overlay element,
pseudo-element, animation or JavaScript.

The expanded lighting regression samples the painted label region after
wrapping the bilingual label and doubling its text size at 320px. A temporary
run with the previous full-height highlight reproduced a failure at 4.06:1.
The final short-band treatment passes at 5.31:1 there, 5.32:1 for the ordinary
label, and 9.41:1 on hover/press. The unchanged forced-colour and solid fallback
assertions pass. The main guide and scoped-token browser proofs also pass.
Focused component/LiveView tests pass 35/35; assets build and routing/smoke
54/54 pass. No new tests merely assert the literal cosmetic input values.

The supported three-target Hallmark guide render reports zero FAIL/open REFLEX,
one WARN and the existing numeric-weight waiver. Gate 40 reports 3.97:1 at
the bright gradient endpoint. This remains a recorded caution, not a waived
label failure: that endpoint is above the text; actual label-region samples
and wrapped-text proof pass as described above. The rendered action row was
inspected. The initial full-height candidate did not protect wrapped labels;
its superseded engineering run was stopped and the final source was checked
again. Full-suite, deep-check and exact-head history outcomes are recorded
with the implementation SHA below and in Plane.

Documentation impact: presentation-only refinement of the existing shared
component, with no Domain/schema/lifecycle or durable-interface change. The
existing handoff remains canonical and the capability-map exemption applies.
The prior WELL-114 certification and other delivery gaps remain open; this
refinement does not imply integration approval.

Final sheen verification at implementation source
`456b8c513a6fe5a59aba5230edc9c7b7c034a1f1`: canonical DevCore TEST
`mix check` exited 0 with 639 tests passing in 319.1 seconds. The same TEST
prefix with `mix check.deep` exited 0, zero errors/skips, in 13.14 seconds.
The focused test command passed 35/35. The existing browser, assets, routing
and Hallmark commands documented above produced the outcomes in this section.
The final bounded source review found no blocking findings in the short-band
recipe, fallback behaviour or wrapped-label regression. It did not run tests
or provide merge certification. Later commits contain handoff/history only.

Author assessment, IMPLEMENTATION/WELL-112: PASS 3/3 for visible token-driven
sheen, unchanged native/fallback behaviour and rendered label-contrast proof.
Requirements 4/4, observed verification 2/3, correctness/architecture 2/2,
handoff 1/1 gives raw 9/10, capped at 5/10 for inherited delivery blockers.
Confidence is 90%, supported by the observed tests and bounded source review.
Verification Status is BLOCKED for overall delivery. The gradient-endpoint WARN
is retained with its geometry and label-region evidence. WELL-114 remains In
Review; its independent certification and final-head hosted CI/Master Gate
review are still required. Those responsible independent checks must resolve
before reaching 8+/10 delivery evidence. No merge recommendation or issue-state
transition follows from this local verification.

## Phase 3 component contracts

The shared card and Heroicons contracts are rendered at `/dev/design-system#contracts`. See the [Phase 3 addendum](research/acss-4.0.3-inventory/phase3-components.md) for supported Phoenix attributes/slots, owned data attributes, local CSS override inputs, border-aware per-axis inset radii, native pending semantics, accessibility rules and regression commands. The existing flat defaults, approved radius tiers and lit primary shine remain intact. Media/avatar frameworks, global auto-radius and inverted corners remain deferred. These presentation-only changes require no new Domain capability map; the generated PR history records their source.

The guide does not certify Firefox/WebKit or assistive-technology behavior. WELL-114 post-merge certification and PR #227 integration/hosted-check gaps remain separate delivery work, as recorded in Plane.

## Phase 4 actual registration pilot

The actual `/register?locale=en` and `/register?locale=af` templates now use the shared flat card, decorative icon, text links, lit primary action and native text/email/password field. The guide renders that same field helper. Registration remains development-gated with exact existing copy, controller behavior and legal facts.

Use `.ds-container`, `.ds-auto-grid`, `.ds-stack` and `.ds-row` for the pilot's shared layout recipes. Guide and application use the same container/auto-fit declarations. Edit canonical `--content-width`, `--gutter`, `--grid-gap`, `--measure`, fonts and visual roles in `assets/css/design-tokens.css`; scope optional `--design-container-max`, `--design-grid-min` and `--design-grid-columns` there for approved contexts. The two-column form responds to allocated width, including a 408px form threshold at the default root size. The pilot uses the approved light palette under either legacy theme; other pages retain legacy styling.

See the [Phase 4 addendum](research/acss-4.0.3-inventory/phase4-registration.md) for input constraints, field ownership, copy/native invariants, promotion limits, full commands and the EN/AF responsive/error/keyboard proof. Reuse outside this gated pilot still requires delivery verification. Auto-fill, breakout, fluid typography, raised cards and decorative backgrounds remain candidates for this consumer. Chromium proof does not certify other engines or release the registration journey. The inherited Tidewave focus-lint finding, WELL-114 certification and PR integration/hosted-check gaps remain open.

## Phase 5 content rhythm

`/dev/design-system#content` renders scoped EN/AF prose and divider examples. The actual registration pilot uses the same CSS recipes around existing safety/privacy copy, with native acceptance controls outside prose. Legal artifact responses remain byte-identical.

Edit `--content-gap`, `--section-space` and `--control-gap` in canonical `assets/css/design-tokens.css`. They initially reference the existing 24/48/16px scale values. `.ds-stack`, registration section padding and `.ds-row` consume the corresponding roles. Root source edits propagate through root-authored aliases; local changes should override the semantic role explicitly. Optional prose/divider inputs resolve at their consumer and have no root defaults.

Use `.ds-prose` for block content with adjacent margins, `.ds-divider` on native thematic hr, and `.ds-divided` for direct-child decorative boundaries with one spacing owner. Do not combine prose flow with a flex/grid gap on the same container. The [Phase 5 addendum](research/acss-4.0.3-inventory/phase5-content.md) records supported content, formulas, local overrides, exact source findings, application geometry and proof limits. New contextual color pairs, fluid promotion, media recipes and the broader border framework remain future work requiring consumers and review.

The [compatibility proof addendum](research/acss-4.0.3-inventory/phase5-compatibility.md) documents repeatable Chrome/Firefox selection, shipped math fallbacks, exact 200% text sizing, no-JavaScript proof, native focus and the inherited Hallmark shadow-focus diagnosis. It records 6,889 bounded assertions per observed engine, 111 corrected registration assertions in Chrome and unresolved Firefox DEV reload diagnostics. This does not certify WebKit, Firefox media emulation, browser zoom, screen readers, mandatory Hallmark completion or integration.

## Candidate modular typography

The guide now compares all twelve production roles with candidate modular sizes at `/dev/design-system#type-scale`. Edit the eight `--type-{body|heading}-{base|ratio}-{min|max}` inputs in `assets/css/design-tokens.css`. Each family calculates six independent mobile/desktop endpoint pairs, then interpolates through the existing `--fluid` native-progress/trigonometric/static engine. Production `--text-*` values and their utilities remain unchanged. Candidate aliases use `--type-candidate-*` and namespaced `text-design-candidate-*` utilities; they are not approved application defaults.

The [typography pass notes](research/acss-4.0.3-inventory/pass1-typography.md) specify formulas, valid inputs, per-step overrides, explicit `.ds-type-scope` recomputation, semantic exceptions, current versus candidate measurements, EN/AF specimens and repeatable proof. Body candidates retain the existing body-xs minimum. Captions and button labels keep their production sizes; the premium button treatment is preserved. Font selection still belongs to root `--font-body`/`--font-display`. Line heights, tracking and readable measure need review with each future adopted size and replacement font.

These are guide candidates. The registration pilot and isolated application preview are not migrated. Visual approval, bounded consumer proof and current delivery verification remain prerequisites for adoption and integration. The existing WELL-114 and registration/Hallmark verification gaps remain recorded in Plane.

## Contextual spacing and scoped prose continuation

Shared cards now consume `--card-content-gap` for direct regions and `--card-action-gap` for their wrapping action rows. Both start at the existing `--space-base` value. Their Tailwind roles are `gap-design-card-content` and `gap-design-card-action`. Padding and inset radii retain separate inputs; prose inside a card retains `--content-gap` and explicit optional prose inputs. Root semantic-role edits propagate throughout shared consumers; local semantic overrides stay in their canonical CSS context.

Opt-in `.ds-prose` supports native figures and captions. `--prose-caption-space`, resolved on the prose boundary, falls back to `--space-sm`; caption typography uses the approved caption role. A neutral outer flow wrapper is required around a nested prose scope when its internal flow input changes, so the child's override cannot change the parent's separation. `/dev/design-system#content` shows default/local card roles, long EN/AF quotation figures and nested flow examples. It introduces no image/crop framework or rich-text parser. The existing registration recipe and hash-locked legal responses are preserved.

The [Pass 2 source and proof notes](research/acss-4.0.3-inventory/pass2-content.md) document formulas, ownership, valid inputs, the reproduced nesting failure, browser measurements and the absence of an eligible standalone rich-content page in this branch. TEST verification is subject to the owner's exclusive-window coordination; current proof and delivery gaps remain in PR/Plane.

## Border purposes and nested dividers

`/dev/design-system#borders` compares the actual shared card, field and lit-primary components with native thematic hr and nested decorative groups. Edit optional `--border-decorative-*`, `--border-control-*`, `--border-separator-*` or `--border-lit-{width|style}` inputs in canonical `assets/css/design-tokens.css`. Their derived shorthands resolve at each consumer. Existing values remain the defaults; local `--design-border-width` remains compatible. A local `--divider-{width|style|color}` takes precedence over the separator purpose input.

Invalid fields double their selected control width, with focus still supplied by a separate outline. Cards subtract their actual selected flat/raised border from each inset-radius axis. Nested divided groups with local inputs require a neutral outer frame so the inner values cannot change the outer boundary. The premium CTA gradient, short shine, directional edges and native interaction treatment retain their existing definitions.

The [Pass 3 implementation notes](research/acss-4.0.3-inventory/pass3-borders.md) specify the edit points, valid inputs, formulas, consumers, geometry, contrast purpose and repeatable proof. This is a bounded contract extension; it does not migrate legacy page borders or approve additional palette/shape values. TEST/deep coordination and inherited delivery gaps remain in PR/Plane.

## Complete opaque surface pairings

`/dev/design-system#surface-pairings` renders the shared `Surface.design_surface/1` component, complete foreground readouts and nested card boundaries. Finite `surface` values are plain, canvas, panel and raised, all using existing backgrounds. The component owns `data-surface` and colour only; existing layout wrappers own dimensions and spacing. Shared cards own plain/raised boundaries with unchanged defaults. Text links read their nearest context while retaining native semantics and underline/focus treatment.

Edit optional `--surface-{profile}-{bg|heading|body|muted|link|link-hover|focus}` inputs in canonical CSS. Every boundary recomputes all `--context-*` outputs; those outputs are not edit points. Named profile inputs intentionally inherit into matching profiles, while a different nested profile supplies its complete assignment again. Local primitive inputs also recompute the existing lighting relationships. Use opaque approved-source colours and verify the complete pairing after edits.

The [Pass 4 source/proof notes](research/acss-4.0.3-inventory/pass4-surfaces.md) define selectors, precedence, card/link integration, contrast math and measured limits. Text and focus colour have separate thresholds; the guide uses a focus swatch and native keyboard proof. Missing/translucent/image-bearing contrast targets are not scored. Gradients, noise and overlays remain decorative candidates. This extension does not approve dark/inverse profiles, text over those treatments, new palette values, a legacy migration or participant release.

## Shared native form contracts

`/dev/design-system#native-forms` uses the same `Field.design_checkbox/1`, `design_fieldset/1` and optional text-field help as the registration pilot. Native checked/required/disabled state owns behavior. Caller-localized labels and help/error text get deterministic associations; related actions stay outside labels. Unchecked boxes have no hidden companion value. Native fieldset disabling reaches descendant controls; caller `aria-busy` supplies only a projection of its operation.

Optional `--field-gap`, `--choice-gap` and `--choice-label-weight` inputs resolve at each consumer in canonical CSS. Defaults retain existing sizes; the age-label weight and privacy-error gap preserve their former markup's treatment. The [Pass 5 notes](research/acss-4.0.3-inventory/pass5-native-forms.md) record APIs, native submission math, ACSS source findings, selectors, copy/geometry preservation and proof limits. Radio/select/textarea/error-summary adoption awaits an actual consumer need. No validation, transport, governed copy, premium CTA or release behavior changes.

## Sessionless guide routing

The endpoint's browser boundary dispatches only reviewed paths. The two DEV/test
guide paths use [DesignSystemBoundary](../../lib/new_you_web/design_system_boundary.ex)
instead of a general Router fallback. LiveView renders from a fresh connection
containing route metadata and validated display choices. Original headers,
cookies, private assigns, the Identity session and endpoint secret never enter
that rendering connection. The original connection sends the HTML response and
retains its cookie behavior.

The guide alone connects to `/dev/design-system/live`. Both transports request
empty connect-info and enforce `check_origin: :conn`, including in DEV. This is
a sessionless display tool protected by connection-origin checks and signed
LiveView tokens; it does not perform session-backed CSRF validation or obtain
business authority. Production compiles neither the dispatch clauses nor the
dedicated socket. The ordinary `/live` socket retains its existing configuration.

The guide DOM exposes its canonical display URL. The browser removes unknown or
invalid display parameters before connecting. Grid changes and live patches
remain bounded by the same choices. A regression guard requires reviewing the
sessionless transport before another LiveView is added to the router.

The [reconciliation proof notes](research/acss-4.0.3-inventory/guide-route-reconciliation.md)
record exact commands, telemetry/origin/production tests, runtime limits and
unresolved current-main Content eligibility failures. The existing sign-in
capability map also links this shared privacy boundary. These records do not
certify the whole PR or close WELL-114.


## Opt-in floating labels

The shared `Field.design_field/1` accepts `label_placement="floating"` for text,
email and password inputs. Review `/dev/design-system#floating-labels` before
adopting it on a production page. Existing callers retain stacked labels.
The component projects its variant as `data-label-placement="floating"`; callers
do not supply visual classes or mirror native value/focus state into attributes.

A real wrapping label owns a label span and the native input. It provides the
whole control's click target and uninterrupted border. Separate in-flow rows
reserve space for the label and value, so long EN/AF labels grow beyond the
existing 58px minimum instead of overlapping. The label moves down by half its
line height only while empty and unfocused. Focus, nonempty values and autofill
raise it. Clearing and blurring restores rest. Native values restored without
input events still update the CSS state. Password values remain omitted from
server-rendered markup. Help/error associations and caller event bindings remain
unchanged. The blank placeholder is component-owned and is not the accessible
name; conflicting floating placeholders and unsupported variants are rejected.

Edit these optional inputs in `assets/css/design-tokens.css`, locally or globally:

- `--field-padding-inline`, default existing `--space-base`.
- `--field-padding-block`, default existing `--space-sm`.
- `--field-label-size`, default existing `--text-caption`. Use a positive size no
  larger than `--text-body-xs`; the scale derives with `tan(atan2(label, body))`.
- `--field-label-duration`, default 160ms. Reduced motion disables transitions.

Without supported transform math or relational selectors, the in-flow label
remains readable above the value. The inner input retains its normal focus ring
when relational selectors are unavailable. Supported browsers place the focus
ring around the full label/control boundary. No new colour, radius, shadow,
validation or transport behaviour is introduced. Select/textarea adoption and
production migration remain separate decisions.

Permanent proof is `test/assets/design_floating_fields_browser.mjs`. It blocks
POST, covers native click/Tab, fill/blur/clear, password omission, required/error
associations, readonly/fieldset-disabled states, local token propagation,
320/390/744/1440 widths, doubled text, LiveView patch/reconnect and no-script use.
Chromium additionally exercises native CDP Autofill and reduced motion. Firefox
160 uses a separate disposable profile with `javascript.enabled=false` because
BiDi scripting toggling is unsupported. Firefox autofill and WebKit are not
certified by this proof.

Observed browser runs passed 61 checks on Chrome 155 and 59 on Firefox 160, with
zero POSTs and zero product page errors. Chromium native autofill produces two
external Tidewave toolbar TypeErrors. The unchanged stacked `#forms-email`
control reproduces the same errors at `tidewave.ai/tc/assets/toolbar-*.js`.
The test reports this exact external signature separately and still rejects all
unrecognized errors. It does not suppress toolbar scripts or alter their code.
Component/contract/token tests passed 48/48 through an explicit ExUnit runner
using `mix run --no-start`, without application or Repo startup. These focused
results do not certify the entire PR's mandatory gates or integration.
