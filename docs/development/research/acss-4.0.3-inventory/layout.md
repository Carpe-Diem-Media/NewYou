# ACSS 4.0.3 layout module inventory

Research scope: read-only inspection of the supplied ACSS 4.0.3 archive and current NewYou source. The archive was verified by the parent task against SHA-256 `17ee65acfd7e045e73b68f2373a2e4fba5e46ab3fd22ec5cc451472a7f5d63b5`; no plugin execution or compilation is claimed here. Vendor references below are paths relative to `automatic-css/` and identify observed source, not permission to copy it. Proposed NewYou work is JIT implementation guidance, not approval of values or a visual redesign.

NewYou authority section 8.1 requires a lean native-variable system, compact spacing and content-width/gutter tokens, `calc()`, `minmax()`, logical properties, reusable recipes, and avoidance of arbitrary utilities. The existing math note gives the equal-track identity `track=(W-(N-1)G)/N` and fitting threshold `N*M+(N-1)G`; its intrinsic-grid caveats apply here. NewYou currently has a fixed `--content-width: 1280px`, `--gutter: var(--space-lg)`, `--grid-gap: var(--space-lg)`, plus separate fluid gutter candidates. Those are observed current values, not recommendations to change.

## Grid

### Inputs and gates

ACSS exposes a traditional grid family with 1-12 equal `minmax(0, 1fr)` tracks and six unequal premade ratios. It declares `$option-grid: off` and `$option-grid-variables: on`. The token output is present, while the inspected standard entry does not import a traditional grid class-output module. A legacy flag or cheatsheet class name alone does not prove CSS emission. The variable-grid is a separate feature. `$option-variable-grid` defaults to `off` in `assets/scss/modules/grid/variable-grid/_vars.scss:1-1`. Its single `.variable-grid` recipe uses `auto-fit`, a default minimum based on half content width minus `--space-xxl`, and gap fallback to `--grid-gap`. Sources: `assets/scss/modules/grid/traditional-grid/_vars.scss:1-2`, `.../_maps.scss:1-52`, `.../_tokens.scss:1-10`, `assets/scss/modules/grid/variable-grid/_output.scss:1-10`.

### Relationships

Equal tracks divide available grid width after `N-1` gaps; the conventional track size is `(W-(N-1)G)/N`, where W and G share a length unit. Traditional tracks have zero minimum and fractional growth. Variable-grid instead repeats as many intrinsic tracks as fit subject to its minimum. The latter requires a definite available inline size for percentage calculations and a meaningful minimum, as documented in the NewYou math note.

### Emitted tokens/selectors

Traditional variables emit `--grid-1` through `--grid-12`, plus premade ratios under their map keys. The traditional `.grid--N` selector family is not established by this import path; direct `grid-template-columns` consumption of the declared tokens is the source-backed path. Variable-grid emits `.variable-grid` with `display:grid!important`, computed columns, rows `var(--grid-1)`, and `gap:var(--gap,var(--grid-gap))`. The variable-grid selector has strong display priority and should not be adopted as a broad utility without checking conflicts.

### Dependencies/scope

Traditional grids depend on the shared grid map and, when used as CSS variables, `--grid-*` tokens. Variable-grid depends on `--content-width`, `--space-xxl`, and `--grid-gap`; callers may override `--min` and `--gap` on the grid element. Its effects are limited to the selected `.variable-grid` element and its direct grid placement context.

### NewYou comparison

NewYou has Tailwind-authored fixed grid patterns and a `.ds-card-grid` with one visual column initially, two at 744px and three at 1128px. Each card spans two of the four/six alignment tracks. The 1441px breakpoint does not add six visual card columns. It also has documented custom span and final-row alignment rules in `lib/new_you_web/live/design_system_live.html.heex:143-153` and `assets/css/design-system.css:157-158,229-249`. This is partial coverage of conventional grids; there is no shared ACSS-style grid-variable family or variable-grid recipe found in the searched CSS and LiveView sources. Existing last-row centring must not be replaced by auto-fit.

### Decision and implementation contract

**Adapt.** Keep page composition and current card alignment. Consider a small reusable native CSS intrinsic-grid recipe only where an actual repeated component needs content-driven fitting. A candidate seam is the existing design-system CSS layer and its semantic `--design-grid-gap`/content-width aliases; do not add every ACSS column count by default. Implementation tasks: (1) identify a real consuming grid and its minimum-card requirement; (2) write a local recipe using `repeat(auto-fit, minmax(min(100%, ...), 1fr))`, `min-inline-size:0`, and explicit overflow handling; (3) verify widths around fit thresholds and 1 through `2N+1` item counts; (4) preserve the current centered remainder behavior and breakpoint resets. No new numeric minimum is authorized by this inventory.

### Missing proof

`LAY-GRID-01`: no source-backed requirement yet selects an additional reusable grid recipe or minimum card width. `LAY-GRID-02`: no rendered threshold and item-count evidence for a candidate intrinsic recipe. `LAY-GRID-03`: preserve the existing centring proof rather than treating it as absent. `docs/development/research/design_math_browser.mjs:84-131` exercises actual columns, remainder populations and alignment; its recorded 212-check Chrome result predates this documentation pass. A new recipe needs its own threshold and remainder proof, including other engines before any cross-engine claim.

## Auto-grid

### Inputs and gates

ACSS mixin inputs are `$column-count` (default 1), `$min` (derived from content width, gap, and column count), `$flow` (selected from configured `auto-fit`/`auto-fill`), and `$internal-use`. The configured aggressiveness defaults to `.7`, flow to `auto-fit`, and auto-grid token output is enabled by default. A separate map emits `--grid-auto-2` through `--grid-auto-12`. Sources: `assets/scss/modules/grid/auto-grid/_mixins.scss:1-17`, `.../_vars.scss:1-17`, `.../_tokens.scss:1-9`.

### Relationships

For N requested columns, the nominal minimum card width is `M=(C-(N-1)G)/N`, where C is content width and G the gap. With dimensionless aggressiveness A, define B=A*M and T=(W-(N-1)G)/N. The minimum track is min(W, max(B, T)), expressed as a length-percentage in CSS. The inner max enforces both the scaled minimum and an N-column cap; the outer min prevents a minimum wider than the container. This requires N to be a positive integer and compatible non-negative gap/width inputs. It repeats the resulting minimum with the selected auto-fit/auto-fill keyword and a flexible maximum. `auto-fit` collapses empty tracks; `auto-fill` keeps them. The token map duplicates the formula for each fixed N, while the mixin can take a custom count and minimum.

### Emitted tokens/selectors

Mixin application writes `--min`, `--column-count`, and `--grid-template-columns`; unless internal use is set, it also emits `display:grid!important`, grid columns, `gap:var(--grid-gap)`, `inline-size:100%`, a `--min-formula`, and direct-child min-width/max-width/overflow-wrap rules. Token mode emits root `--grid-auto-N` properties and `--auto-grid-aggressiveness`. This is broader child styling than only track calculation.

### Dependencies/scope

Depends on `--content-width`, `--grid-gap`, aggressiveness, and flow configuration. Mixin styles apply to the host and all direct children. Root token mode adds global properties but no element selector. `!important` on display can override consumer display declarations.

### NewYou comparison

NewYou has a guide-only `.ds-lighting-cards` auto-fit layout with a 16rem minimum at `assets/css/design-system.css:19-19`. A shared, parameterised auto-grid contract with column caps, minimum width and fit/fill choices is not implemented. Some page layouts use explicit Tailwind responsive columns; the design system exposes `--design-content-width` and `--design-grid-gap` in `assets/css/design-tokens.css:107-112`. This is partial intrinsic-layout coverage, not an implementation of the complete ACSS auto-grid recipe.

### Decision and implementation contract

**Adapt.** Reuse the intrinsic CSS relationship only for a concrete responsive card/list pattern. Do not carry over a global 2-12 token family, fixed `.7` aggressiveness, `!important`, or broad direct-child text rules. Candidate seam: a component-owned class in `assets/css/design-components.css` or a narrowly scoped rule in `design-system.css`, consuming existing semantic gap/width tokens and accepting a reviewed local minimum. Tasks: define scope and min-card need; select fit/fill behavior from desired empty-track spacing; implement the recipe and child overflow rules explicitly; inspect at the mathematical threshold with one-pixel boundary cases. Values remain subject to design review.

### Missing proof

`LAY-AUTO-01`: actual component needing auto-fit and its minimum width are unestablished. `LAY-AUTO-02`: fit versus fill behavior is not specified for a consuming pattern. `LAY-AUTO-03`: no browser rendering evidence exists for candidate narrow widths, unbroken content, or empty tracks.

## Gutter

### Inputs and gates

ACSS computes `$gutter` with `fluidClamp($gutter-min,$gutter-max)` from source-declared defaults 2.4 and 3, converted to rem endpoints by `assets/scss/helpers/_functions.scss:21-30`. The helper uses slope `(max-min)/(vp-max-vp-min)`, intercept `min-slope*vp-min`, and ordered clamp bounds. It emits the slope in vw and the intercept/endpoints in rem. The source viewport defaults are 36 and 128 at `assets/scss/modules/breakpoints/_vars.scss:1-5`; these are source defaults, not NewYou values. The root `--gutter` token is inside the default-section-style gate; section padding utilities are independently gated by `$option-section-padding`, default on. `--grid-gap` is a contextual spacing token, not the gutter itself. Sources: `assets/scss/modules/spacing/_vars.scss:1-14`, `.../tokens.scss:1-31`, `assets/scss/modules/sections/_defaults.scss:1-18`, `.../_utilities.scss:1-20`.

### Relationships

The gutter is a responsive length generated from two endpoints and shared across horizontal section padding and content-grid safe lanes. ACSS defaults do not mean every runtime build resolves to those values: user configuration may override Sass variables, and the helper's viewport bounds/root conversion also affect emitted CSS. Separate spacing maps create contextual `--grid-gap`, `--content-gap`, and `--container-gap` aliases.

### Emitted tokens/selectors

The token is `:root { --gutter: ... }`. Section utilities `.section--{size}` and `.section--none` use it for inline padding; `.header--{size}` also uses it. Default top-level sections and body header/footer use it when default section styles load. Content-grid uses it to form outer tracks and safe full-width padding.

### Dependencies/scope

Depends on the spacing clamp helper, its viewport bounds, spacing configuration, and section options. Root token scope is global; utility padding applies by class; default section selectors affect top-level sections and body-level header/footer. The separate grid gap/contextual spacing values may differ.

### NewYou comparison

NewYou currently has `--gutter` aliasing `--space-lg` in `assets/css/design-tokens.css:107-112` and a separate `--fluid-gutter` with min/max tokens in `assets/css/design-tokens.css:166-171`, used by a development specimen in `assets/css/design-system.css:274,299-300`. The specimen is not evidence that production layout consumes the fluid gutter. `--design-gutter` aliases the current static gutter for the design-system container, whose width/gutter use is at `assets/css/design-system.css:42-47`. This is partial coverage: semantic tokens exist, but global section padding and production fluid binding are not demonstrated by this source inventory.

### Decision and implementation contract

**Adapt.** Retain the semantic gutter token and existing fluid candidate. Before connecting it to a production layout, identify actual consumers and evaluate the existing design review and fluid-sizing contract. Candidate seam is token-only: maintain one semantic `--gutter` alias for approved usage, with any fluid implementation using the already governed endpoint/`--fluid` mechanism. Do not copy the ACSS endpoint values or global section selectors. Tasks: inventory consumers; decide whether the fluid specimen graduates; bind only approved consumers; confirm reduced-width and root-font behavior and inspect the rendered gutters.

### Missing proof

`LAY-GUTTER-01`: a production consumer and padding owner must be selected. `LAY-GUTTER-02`: the static-versus-fluid production choice and any approved endpoints remain open. `LAY-GUTTER-03`: existing specimen proof covers gutter candidates at multiple root sizes, descending endpoints and fallback tiers in `docs/development/research/design_math_browser.mjs:21-84`. Production wrapper nesting, local overrides and other browser engines still need proof.

## Content-width

### Inputs and gates

ACSS declares `$vp-min:36`, `$vp-max:128`, then derives `$content-width: $vp-max * 1rem`; the shown source therefore yields a build-time 128rem width before overrides, not a browser-measured or universally fixed 1280px value. Its root `--content-width` and safe variant are emitted under `$option-load-default-section-styles`, default on. Width utilities separately expose `.content-width` and `.content-width--safe`, gated by `$option-width`, default on. Sources: `assets/scss/modules/breakpoints/_vars.scss:1-5`, `assets/scss/modules/sections/_tokens.scss:1-7`, `assets/scss/modules/width/_vars.scss:1-2`, `assets/scss/modules/width/_output.scss:1-40`.

### Relationships

The safe width is `min(content-width, 100%-2*gutter)`. A content-width container has full available inline size, caps at content width, and centers with auto inline margins. The safe version caps against both the maximum measure and the viewport/container space inside two gutters. Width fraction utilities multiply the shared content-width token by configured fractions.

### Emitted tokens/selectors

Root variables include `--content-width`, `--content-width-safe` and the independently gated `--width-10` through `--width-90` plus `--width-full`. The fraction map is `assets/scss/modules/width/_width-maps.scss:1-14`, and token emission is `assets/scss/modules/width/_tokens.scss:1-8`. The source-defined `--width-full` multiplies content width by the map value `100%`, whereas `.width--full` uses 100% of the containing block. The token expression needs separate computed-value proof because that product is not a plain length times a unitless fraction; do not silently substitute the safe class behaviour for the token. Selectors include `.content-width`, `.content-width--safe`, `.width--{fraction}`, `.width--full`, and intrinsic width utilities. The token output is not identical to selector utility output and their feature gates differ.

### Dependencies/scope

The token depends on breakpoint variables and section-style gate. Safe width depends on `--gutter`. Width utilities depend on `--content-width` and `$widths`; element selectors scope max inline size and centering to opted-in elements. Token is root-scoped and can be overridden downstream.

### NewYou comparison

NewYou defines `--content-width:1280px` and aliases it as `--design-content-width` in `assets/css/design-tokens.css:107-111`. The style guide container consumes the design alias for max width and the design gutter for inline padding in `assets/css/design-system.css:42-47`. Thus semantic content width is implemented, but the generic `.content-width` behavior and derived safe-width calculation were not found in searched NewYou CSS.

### Decision and implementation contract

**Adapt.** Preserve the existing canonical token and value. A safe-width relationship may be useful only where an actual full-width container needs a bounded inline measure; use native `min()`/`calc()` and the existing gutter token. Candidate seam is `design-tokens.css` for a single derived token only if multiple consumers justify it, otherwise use the relationship locally in the relevant component. Do not add utility families preemptively or alter the approved width. Tasks: find/record consumers; establish whether they need width cap, safe cap, or both; add the smallest reusable native rule; verify long content, narrow viewport, and centered gutters.

### Missing proof

`LAY-WIDTH-01`: no consumer requiring a separate safe-width token is identified. `LAY-WIDTH-02`: no multi-consumer evidence justifies a new root alias. `LAY-WIDTH-03`: no visual proof of safe-width behavior at narrow and wide viewports.

## Breakout

### Inputs and gates

No separately named breakout module or "breakout" selector was found in the inspected SCSS module tree. ACSS implements this need through the optional content-grid feature, default off, with an additional option to make it the default structure for top-level sections, also off. `$content-grid-exclusions` defaults to `.content-grid--off` and can exclude selected sections. Its source-declared lane defaults are `$content-feature:50px` and `$content-feature-max:100px`; these are Sass defaults, not approved NewYou dimensions. Sources: `assets/scss/modules/grid/content-grid/_options.scss:1-2`, `.../_vars.scss:1-5`, `.../_mixins.scss:1-40`, `.../_index.scss:1-67`.

### Relationships

The grid has seven named tracks: flexible outer `full` lanes, two feature-max lanes, two feature lanes, and a central content lane. The central lane is `min(content-width, 100%-2*gutter)`. Each adjacent feature lane grows up to its configured feature width; each feature-max lane grows up to its wider configured width; outer lanes absorb remaining width with a gutter minimum. Children default to the `content` named line. Marker classes assign children to `feature`, `feature-max`, or `full`; `full-safe` adds gutter padding.

### Emitted tokens/selectors

The opt-in `.content-grid` selector applies a grid recipe. `.content--feature`, `.content--feature-max`, `.content--full`, `.content--full-safe` select named lines. Optional section-default mode applies the recipe to top-level `section` elements, with `.content-grid--off` or configured exclusions as escape paths. This feature changes parent display, column gap, padding, direct-child sizing, and child placement.

### Dependencies/scope

Depends on `--gutter`, `--content-width`, feature lane Sass defaults or per-grid custom properties `--feature-width`/`--feature-max-width`. It also interacts with section padding options and classes. Parent grid effects include `display:grid!important`, `column-gap:0!important`, and `padding-inline:0`; child placement only applies to direct children. Section default mode has broad page-wide scope and should not be copied as a default.

### NewYou comparison

No content-grid lane classes or equivalent named breakout tracks were found in current NewYou CSS/HEEx. Existing page containers use max width plus gutters in `assets/css/design-system.css:42-47`; the LiveView design guide demonstrates card grids at `lib/new_you_web/live/design_system_live.html.heex:143-153` but not article breakout lanes. This module is missing as a reusable capability, but no current page requirement for breakout has been established.

### Decision and implementation contract

**Defer.** The four named content zones are implementable with native CSS grid and match the section 8.1 preference for `minmax()`, but adopting it needs a named real content page and reviewed lane widths. Candidate seam is a page-scoped layout recipe in the relevant component stylesheet, consuming existing content-width and gutter tokens. Start with an explicit page wrapper and opt-in child markers; do not globally convert sections or reproduce vendor selectors. Tasks if needed: identify content page and its feature/full-width content; agree semantic lane needs through existing design review; implement named grid lines with a bounded scope; test nested sections, overflow, images/figures, narrow widths, and full-safe padding.

### Missing proof

`LAY-BREAKOUT-01`: no current NewYou consumer requiring breakout lanes is identified. `LAY-BREAKOUT-02`: feature and feature-max widths have no approved NewYou values. `LAY-BREAKOUT-03`: no rendering evidence covers nested sections, media, overflow, or narrow widths.

## Cross-module source observations

ACSS has separate configuration boundaries for root variables, utilities, and default section styling. Source defaults are Sass-level defaults and can be overridden before compilation; this inventory does not infer active plugin configuration. `automatic-imports_precompiled.scss` contains assembled SCSS source, not evidence of a runtime-generated NewYou stylesheet. No claim is made that the inspected precompiled assets reflect a specific customer's settings. The vendor auto-grid mixin writes a `--min-formula` custom property referencing `var(--min)` after its own `--min` declaration; token mode uses a different independently inlined expression. Treat this as two source paths with distinct emitted shapes, not as proof of a defect or runtime failure. The content-grid expression `min(var(--content-width), 100% - var(--gutter) * 2)` is recorded as authored. CSS math functions accept arithmetic directly; a missing nested `calc()` is not evidence of a defect. See [MDN min() syntax](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Values/min). The actual Sass output and complete seven-track behaviour still need separate proof. This research did not compile Sass or execute the plugin.

The source has one further version/configuration ambiguity. ACSS 4.x setup guidance describes CSS variables such as `--grid-3` and `--grid-auto-3` and warns against carrying 3.x classes forward. This inventory treats exact 4.0.3 source gates as authority: the traditional class catalog in its cheatsheet is not proof of generated/active selectors, and `$option-grid` defaults off while the `--grid-N` variable gate defaults on. The archive's supplied `.css` files contain no compiled ACSS frontend stylesheet, and the precompiled import is assembled SCSS. No active customer configuration, compiler run, or runtime output was inspected. Thus recommendations apply to reusable relationships and token seams, not an assumption that vendor utility classes execute in NewYou.

Auto-grid runtime override scope is also narrower than the exposed root token may suggest. The `--grid-auto-N` formulas interpolate `$auto-grid-aggressiveness` into generated CSS at compile time. The separately emitted `--auto-grid-aggressiveness` custom property is not referenced by those formulas in `_tokens.scss`; changing that CSS variable at runtime therefore does not tune those emitted formulas. The mixin path writes the aggressiveness into local `--min`, so runtime changes to the root token likewise do not affect its precomputed declaration. Treat aggressiveness as a build-time Sass setting unless another source path is found. This finding is limited to the two cited source files and does not establish all plugin behavior.

## Worked relationships and implementation boundaries

These examples are independent arithmetic, not approved design values or copied
CSS. For three equal columns in 1000px with a 24px gap, a track is
`(1000 - 2*24)/3 = 317.333px`. Three 240px-minimum cards require
`3*240 + 2*24 = 768px`. Test one pixel below, at and above any real threshold.
For source-style auto-grid with C=1000px, N=3, G=24px and A=0.7, B is
222.133px. At W=1000px the cap term T is 317.333px; at W=700px it is
217.333px, so the minimum becomes B. Fit/fill and item population still affect
used track widths. Centring the final row remains a separate placement recipe.

The supplied gutter helper is a build-time clamp generator. With its authored
2.4/3 endpoints and 36/128 interval, the slope is 0.6/92 and the rem intercept
is about 2.165217. Root size and viewport units must be checked together; a
100% root default appears in `assets/scss/modules/text/_text-vars.scss:9-9`.
Do not reinterpret those settings as NewYou's existing 24px gutter or 1280px cap.

Give one wrapper responsibility for inline gutters. A full-width border box
with inline padding consumes two gutters; its content cap must state whether
the cap measures that border box or only the inner content. Nested wrappers
must not charge the same gutters twice. Root-derived aliases can also retain
root inputs: a local `--gutter` edit does not automatically recompute an
inherited `--content-width-safe` or NewYou's `--design-gutter`. Derive a new
relationship at its consuming scope or consume the direct semantic input.

The content grid has seven tracks and four named zones. If the inner feature
lanes reach F each and the outer feature-max lanes reach M each, their widths
are content C, feature C+2F and feature-max C+2F+2M before outer full lanes.
The two outer tracks have a gutter minimum. Under narrow allocation the four
feature tracks can shrink toward zero. Future proof must check their actual
used geometry and avoid assuming feature-max means C+2M. Nested grids, section
padding removal, media intrinsic sizes and the configured exclusion selector
are separate cases. No `100vw` breakout or global section conversion is proposed.
