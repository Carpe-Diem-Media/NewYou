# Design-system development

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
- The approved Inter fallback is used because the source font is not present; its line-height values apply DESIGN.md's approximately 5% increase to the extracted values.
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
- Do not add brand font files or illustrations. The token layer uses the Inter fallback explicitly approved by DESIGN.md; no font asset is downloaded.

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

The initial sloplint pass reports four REFLEX findings and no FAILs: it recommends tinting the explicitly specified white surface/on-primary and black on-canvas tokens, and counts numeric font-weight tokens (and Tailwind's imported Georgia default) as extra font families. Those color values map directly to DESIGN.md; Inter is the approved single project fallback, while legacy framework font defaults remain grandfathered.

## Migration state

WELL-80 establishes the infrastructure only. Existing pages, forms, layouts, dark mode, validation/error styling, and DaisyUI usage remain unchanged. Migrate those scopes in separate reviewed work. Dark-mode authority, validation/error authority, and the remaining in-app product visual system are follow-up design decisions.

## LiveView visual reference

WELL-112 adds `/dev/design-system` and `/dev/design-system/preview` for development and tests. The production router does not compile either route. This is an internal refinement tool; its example copy does not approve participant content or a replacement design.

Implementation source revision: `3c966c8067926e021d6b480d6b11b231510940a3`. Verify current source before extending this map. This map is engineering documentation, not design authority or live delivery state.

Start the worktree server through the pinned toolchain and DevCore:

```sh
NEW_YOU_PORT=4237 mise exec -- devcore-project run dev -- mix phx.server
```

Use a free permitted worktree port in `4221..4239`. The primary checkout uses `4220`. Run `devcore-project doctor` first. If existing migrations are pending, use the same DEV wrapper and worktree port for `mix ecto.migrate`; do not reset shared data or create another database stack.

The guide contains all approved palette tokens, twelve type specimens, font weights, line heights, tracking, spacing, button/link examples, cards, Heroicons, grid controls, breakpoint/container measurements, foreground/background contrast and radius/shadow samples. Its specimens consume the shared CSS, not copies of the values in Elixir or JavaScript. The declared Inter fallback is not bundled; the page explicitly reports that the browser may use sans-serif.

### Edit one source

Edit the `:root` block in [design-tokens.css](../../assets/css/design-tokens.css). Existing `design-*` Tailwind utilities map to those variables. For example:

```css
:root {
  --primary: #0061ef;
  --secondary: #2d2c2b;
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

The guide and canonical application components share these values. This does not migrate legacy DaisyUI or `ny-*` screens. `--secondary` is the existing neutral ink role, not another saturated CTA. `--radius` controls cards; the other approved component radii retain their separate tiers. `--box-shadow` starts at `none` because the approved system is flat.

Keep deliberate changes to locked values consistent with [DESIGN.md](../../DESIGN.md). `mix design.check` still checks the approved palette, resolves alias chains and rejects mismatches, unknown references, cycles and extra color tokens. Styles can consume declared aliases without an inline-style exemption or new raw values. The existing design-debt baseline remains intact.

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
BROWSER_TOOLS_ROOT=/tmp/newyou-well-112-tools DESIGN_SYSTEM_URL=http://127.0.0.1:4237 CHROME_PATH=/usr/bin/google-chrome node test/assets/design_system_browser.mjs
```

Observed author verification used Elixir 1.20.5, OTP 29.1.2, Tailwind 4.3.3 and system Chrome:

- The initial focused tests reproduced the absent route and missing palette-alias support. The resulting focused suite passed 31 tests.
- The two JavaScript contrast tests passed, including invalid channels and AA/AAA threshold boundaries.
- Browser proof passed at 320, 390, 743, 744, 1127, 1128, 1440 and 1920px. Eighteen centred-row cases passed across tablet and desktop widths. LiveView URL controls, the real iframe width, live primary/radius/shadow propagation, contrast refresh, keyboard focus and reduced motion passed with no browser errors.
- `mix assets.build` passed. `mix check.deep` passed with zero errors. The fast gate's formatting, compilation, design, architecture, usage-rule, Credo and Sobelow stages passed before its ExUnit stage failed.
- Full `mix check` is blocked by the shared TEST database state tracked in WELL-114. Retained fixture rows predate this task; current main cannot load an `identity_recovery_completed` evidence type, and whole-resource Communications reads encounter unrelated rows. An unchanged Disposition test independently reproduced three failures. No shared fixture data was deleted. The full-suite failure is not waived.

The first hosted PR run exposed missing CI classification for `DESIGN.md`, `.hallmark/log.json` and `.hallmark/preflight.json`. [The classifier](../../tools/foundation_integrity_routing.py) now names these exact engineering files. [Routing regressions](../../tests/test_foundation_lane_routing.py) reproduced all three failures before correction and preserve rejection of unclassified neighbours. Design-only changes select Application CI without forcing Dialyzer; the guide's Elixir source independently selects the deep lane. Foundation Full remains nightly-only. This routing correction changes no application behavior from the implementation revision above.

### Hallmark and visual review

The existing `DESIGN.md` supplies the direction; there is no new theme, brand font or stock imagery. This is app scope, so the marketing hero review is inapplicable. The exact render command was:

```sh
HALLMARK_PUPPETEER=/tmp/newyou-well-112-tools CHROME_PATH=/usr/bin/google-chrome node /home/jcschoeman96/.agents/skills/hallmark/scripts/sloplint.mjs assets/css/design-tokens.css assets/css/design-system.css --scope app --genre modern-minimal --url http://127.0.0.1:4237/dev/design-system --json
```

The final observed result was zero FAIL, zero open REFLEX, zero WARN and three waived findings. Gate 7b's two findings are the exact approved black `on-canvas` reference swatch and its Tailwind mapping; tinting either would change locked values. Gate 37 treats numeric font weights as font families. The source has one approved Inter fallback family. The specimen-only line-height waiver records why the reference must retain the approved scale rather than rewrite it.

The initial rendered FAIL at 320px was a wrapped navigation control; shorter index labels fixed it and the rerun passed. The independent fresh-context finish review reported one state-clarity finding on the disabled specimen. Its lock icon and explicit unavailable label now provide a non-color cue while the approved button appearance and native disabled behavior remain intact. The author checked the recapture. The existing Tidewave developer overlay can cover content in captured phone views; it is not part of the design system.

Documentation impact: this section is the source-linked handoff for the developer reference and shared styling extension. Ash interfaces, persistence constraints, asynchronous schedules and business recovery are inapplicable. A cold-start walkthrough followed the route, validated display choices, semantic components, token mapping, browser measurements and executable tests against the implementation revision above. Full-suite certification remains subject to WELL-114; independent Master Gate, exact-head hosted CI, trusted-operator attestation and owner merge authorization remain required before integration.

References studied: [Frames layouts](https://getframes.io/layouts/?brx_c0563d=style-guide), [Automatic CSS documentation](https://docs.automaticcss.com/), [Tailwind v4 theme variables](https://tailwindcss.com/docs/theme), and the local LiveFrame `AutomaticCSS.FidelityResolver`. These inform implementation; NewYou's repository authority controls the result. No LiveFrame or WordPress runtime dependency was added.
