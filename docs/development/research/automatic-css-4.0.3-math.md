# Automatic.css 4.0.3 mathematics and NewYou implementation notes

Research date: 2026-11-12. Related work: WELL-112, PR #227.
NewYou source baseline: `ac74d455c3a60d78544d43827262ff40516db1a2`.

This is an engineering research note, not an amendment to DESIGN.md or an
approval of new production sizes, colours, states or layouts. The owner requested
a deeper assessment of the supplied plugin and reusable mathematics. No plugin
code, WordPress runtime or Sass dependency is adopted by this note. Examples
below are independent expressions of ordinary mathematics and native CSS.

## 1. Baseline, authority and evidence

Canonical repository: `Carpe-Diem-Media/NewYou`. The working branch is
`t3/newyou-liveview-style-guide-jc-agents`. The repository was clean at inspection.
Current routing starts at [the documentation index](../../README.md) and
[the governance router](../../governance/CURRENT_GOVERNANCE_ROUTER.json).

Locked constraints:

- [Frontend experience authority, section 8.1](../../governance/supporting/FRONTEND_EXPERIENCE_SYSTEM_v1.0.1.md)
  requires a lean native-variable system; Automatic.css is research material,
  not a runtime dependency. Do not introduce Sass merely to imitate it.
- [DESIGN.md](../../../DESIGN.md) and [the development guide](../design_system.md)
  govern existing values. Fluid sizing remains a development candidate.
- Central font selection, component-owned variant attributes, and opt-in
  overhead-lighting specimens are already implemented. Do not replace them.
- The owner authorised continued UI work with the WELL-114 independent
  post-merge certification gap recorded. This research does not close that gap.
  Live inspection still found WELL-112 In Progress and WELL-114 In Review.

Open JIT choices are the endpoint interpolation recipe, a compact set of semantic
spacing relationships, intrinsic layout recipes and their verification. Exact
visual endpoints and promotion into production still require the existing
design review route. A missing token-generation mechanism is not a governance
contradiction.

### Supplied archive

- Filename: `automatic.css-4.0.3.zip`; size: 3,436,059 bytes.
- SHA-256: `17ee65acfd7e045e73b68f2373a2e4fba5e46ab3fd22ec5cc451472a7f5d63b5`.
- ZIP CRC verification passed for its 947 entries. This proves archive integrity,
  not publisher authenticity or software security. The plugin was not executed.
- `automatic-css.php:12` identifies version 4.0.3. Its header and `readme.txt`
  declare GPL v2 or later. The readme contains stale version/PHP metadata, so use
  the main header for the inspected version, not the readme's stable tag.
- No plugin-level LICENSE/COPYING file was found at the package root. Vendor
  dependency licences apply to their respective dependencies, not automatically
  to all plugin assets.
- The [published EULA](https://automaticcss.com/policies/license-agreement/)
  contains restrictive reproduction terms. Package GPL notices are material
  evidence and must not be ignored. This note does not resolve their legal
  relationship or grant permission to copy source. Resolve applicable terms and
  GPL compliance before directly reusing vendor implementation or assets.

Package locators below are relative to `automatic-css/` inside that exact ZIP.
The attachment is retained outside the repository. Re-extract the same hashed
archive to follow them; temporary workstation extraction paths are not durable
dependencies. These source locators identify evidence, not copied code:

- A1: `assets/scss/helpers/_functions.scss:21-65`, slope/intercept clamps and
  root-font conversion. File SHA-256
  `c29013aec6d8a43c24c9261f018dc0d81cdb9ed1dbd478ffb7c888e935d26ec1`.
- A2: `assets/scss/modules/text/_text-mixins.scss:8-57`, endpoint modular scales,
  optional per-step overrides and bridge variables. File SHA-256
  `ecab1bedb1cb4653f7a704e0114c3f0a437dcb618c9f26e4e7c1fca83dc64bd1`.
- A3: `assets/scss/modules/spacing/_vars.scss:16-48` and `_maps.scss:1-53`,
  mobile/desktop spacing, section multipliers and contextual aliases.
- A4: `assets/scss/modules/grid/auto-grid/_mixins.scss:1-17` and
  `grid/content-grid/_mixins.scss:1-40`, intrinsic tracks and named content lanes.
- A5: the archive's `config/ui/` directory, file `typography.json`, lines 111
  and 1167, heading/text x-height leading defaults. These are external archive
  locations, not NewYou repository links.
- A6: `assets/scss/modules/palette/main/_primary.scss:4-39` and
  `modules/color-relationships/_tokens.scss:1-21`, authored OKLCH shade channels
  and background-dependent semantic assignments.
- A7: `assets/scss/modules/surfaces/_mixins.scss:1-10`, surface recipes;
  `modules/buttons/_button-properties.scss:1-75`, button property/state tokens;
  `modules/focus/_mixins.scss:1-46`, focus recipes.
- A8: `assets/scss/modules/spacing/smart-spacing/_mixins.scss:9-89`, editorial
  flow, heading/list spacing and final-child margin handling.

## 2. The common interpolation function

Let `V` be the driving length, `V0 < V1` its viewport bounds, and `A`, `B` the
desired size endpoints, all expressed in consistent length units:

```text
p = clamp(0, (V - V0) / (V1 - V0), 1)
F(V, A, B) = A + p * (B - A)
```

Required invariants: finite values; strictly positive viewport span; non-negative
size endpoints where the destination property requires them. `A > B` is valid
for deliberately shrinking values. The viewport bounds themselves must remain
ordered. Check both endpoints, an interior point and out-of-range widths.

A1 expresses the same linear relationship as slope/intercept:

```text
m = (B - A) / (V1 - V0)
b = A - m * V0
F = clamp(min(A, B), m * V + b, max(A, B))
```

For numeric inputs expressed in rem, the equivalent CSS preferred term is
`calc((100 * m) * 1vw + b * 1rem)`. In emitted CSS these coefficients must be
valid numbers. Do not mix px endpoint numbers with rem viewport numbers without
conversion. `px / root-px` converts a physical input to rem; it must not assume
the user always has a 16px root. Retain a 100% root font size.

A1's conversion uses a nominal 16px browser root adjusted by the configured
percentage. That is build-time configuration, not a measurement of the user's
font preference. Prefer rem inputs directly when implementing NewYou endpoints.

### NewYou recipe

Keep the existing runtime input tokens and dimensionless `--fluid` progression.
The CSS below illustrates the existing capability order; it is not a second
stylesheet to import:

```css
:root {
  --fluid: 0;
}

@supports (width: calc(100px * tan(atan2(1px, 1px)))) {
  :root {
    --fluid: clamp(0, tan(atan2(
      calc(100vw - var(--fluid-vmin)),
      calc(var(--fluid-vmax) - var(--fluid-vmin))
    )), 1);
  }
}

@supports (width: calc(100px * progress(50px, 0px, 100px))) {
  :root {
    --fluid: clamp(0, progress(
      100vw, var(--fluid-vmin), var(--fluid-vmax)
    ), 1);
  }
}
```

For positive `V1 - V0`, `tan(atan2(V - V0, V1 - V0))` recovers the unbounded
ratio without requiring length-by-length typed division. The outer clamp keeps
it bounded. The current [MDN progress reference](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Values/progress)
and [CSS Values 5 editor's draft](https://drafts.csswg.org/css-values-5/#progress)
describe default clamping, with an optional `no-clamp` extension. Keep NewYou's
explicit clamp for its contract; do not depend on the extension. The draft is
work in progress, not a browser-support guarantee.

Test support using a real consuming property, not `@supports (--fluid: ...)`:
unregistered custom properties accept token streams that may fail only when
used. Keep native progress as enhancement, the trigonometric path as a fallback,
and a usable static minimum. A generated classic clamp is a possible older-
browser strategy only if needed; it introduces coefficient generation and must
not become a separately maintained set of magic numbers. Neither direct typed
division nor `pow()` should be assumed available without their own support test.

Existing NewYou evidence: `assets/css/design-tokens.css` already defines these
bounds, four semantic endpoint pairs and the fallback sequence. Do not add a
parallel progress engine in JavaScript, LiveView assigns or Sass.

## 3. Modular typography: choose the interpolation model explicitly

For integer scale step `k`, independent body and display families can use:

```text
mobile[k]  = base_mobile  * ratio_mobile^k
desktop[k] = base_desktop * ratio_desktop^k
size[k]    = F(V, mobile[k], desktop[k])
```

This is the endpoint-first model observed in A2. Negative steps divide by the
ratio; positive steps multiply. In CSS, repeated multiplication/division can
express a small fixed number of steps without a new Sass build or native `pow()`.
Keep the permitted ratio range explicit and avoid producing unreadably small
body text through negative steps.

The owner's earlier example instead interpolates the base and ratio, then
multiplies them:

```text
alternative[k] = F(V, base_mobile, base_desktop)
                 * F(V, ratio_mobile, ratio_desktop)^k
```

Both agree at the endpoints; higher steps generally differ in between. The
alternative is generally nonlinear in viewport width. This matters when testing
an expected midpoint and deciding how a title wraps.

Recommendation: use endpoint-first interpolation for new scale candidates. It
provides a linear, easily audited result per role and matches the endpoint
contract already used by NewYou's four fluid candidates. Keep exact body,
heading and display values as reviewed role-specific inputs. Do not replace all
existing type tokens or force all semantic roles onto one mathematical ratio.

The accompanying reference check uses illustrative 16px/18px bases and
1.2/1.333 ratios over 480px to 1200px. These are comparison inputs from the
conversation, not a new approved production scale. It also distinguishes
interpolation at fixed root metrics from behaviour under user text resizing.

Keep tracking proportional where a role intends it: `tracking_px / font_px`
gives its `em` ratio. For example, the existing 64px display size and -1.92px
tracking have a -0.03em relationship. A future change must review this relationship
before replacing current absolute tracking; preservation of appearance is a
separate acceptance criterion.

## 4. Line height, font changes and readable measure

A5 and the [public typography guide](https://docs.automaticcss.com/typography/default-typography-styling)
describe adding a desired leading to twice the font's x-height:

```text
line_box = leading + 2 * x_height
```

`ex` follows font metrics. This can adapt to a replacement font, but it does not
guarantee readability, prevent clipping, or meet text-spacing requirements. Its
ratio to font size changes as size grows when the added leading is fixed. Do not
copy the vendor's fixed-pixel leading defaults as NewYou policy.

Use unitless line-height as the production baseline for inherited body/control
styles. Keep any x-height formula in a named specimen until Inter, a replacement
font, fallback rendering, accented EN/AF text, multiline headings and user text
spacing have been reviewed. Re-evaluate metric-sensitive values on the text
element itself; inherited computed lengths may retain an ancestor's font metrics.
Keep `ch` prose measures role-specific and test actual wrapping after font changes.

The existing `--font-body` and `--font-display` tokens remain the only family
selection inputs. A new custom font still needs a licensed local face registered
once. A font token does not fetch an asset or guarantee matching metrics.

## 5. Fluid spacing and semantic aliases

Use the same endpoint function, with separate mobile and desktop spacing ratios:

```text
space_mobile[k]  = spacing_base_mobile  * spacing_ratio_mobile^k
space_desktop[k] = spacing_base_desktop * spacing_ratio_desktop^k
space[k]        = F(V, space_mobile[k], space_desktop[k])
section[k]      = F(V, space_mobile[k]  * section_factor_mobile,
                      space_desktop[k] * section_factor_desktop)
gutter          = F(V, gutter_mobile, gutter_desktop)
```

The section endpoint calculation reflects A3. Multiplying an interpolated space
by an interpolated section factor instead creates a different curve. Document
which model each derived token follows.

Recommended semantic purposes are content flow, card padding, control spacing,
grid gap, page gutter and section padding. Alias them to the smallest useful
scale; do not introduce another independent number for every component. Keep
control minimum size and thin borders independent of decorative fluid spacing.
Small spacing can remain static when fluid growth adds no benefit.

A3 also generates many cross-step bridge tokens. Create one only when an actual
reviewed layout needs different mobile and desktop scale steps. Generating all
combinations adds unused public tokens and complicates maintenance.

For editorial flow, A8 supports purposeful heading/list spacing. NewYou should
scope any `> * + *` flow rule to an explicit prose container, use logical margins,
and avoid combining it with a flex/grid gap on the same axis. Do not globally
reset participant content margins or import builder-specific `!important` rules.

## 6. Containers, grids and incomplete rows

For an outer inline space `W`, content cap `C` and gutter `G`:

```text
content_inline_size = min(C, max(0, W - 2G))
```

Apply box-sizing consistently and count the gutter once. A percentage is relative
to the containing block; using `100vw` for page content can include scrollbar
width and cause overflow. Use intrinsic width and logical properties. Keep
named breakout tracks from A4 deferred until an actual page needs them.

For `N` equal columns with gap `G` and available inline size `W`:

```text
track_size = (W - (N - 1) * G) / N
threshold_for_N_columns = N * minimum_card_size + (N - 1) * G
```

An independent intrinsic recipe can express an upper column count and minimum
card width using `repeat(auto-fit, minmax(min(100%, max(minimum, track_size)), 1fr))`.
This is mathematical pseudocode: substitute typed length tokens and a `calc()`
expression for its named operands before using it as CSS. The container must
have a definite available inline size for the percentage-based fit calculation.
The input column count must be a positive integer and gaps non-negative. Use a
practical positive minimum width. `auto-fit` collapses empty tracks and permits
items to stretch; `auto-fill` reserves them. Decide this per pattern. Add
`min-inline-size: 0` to children and deliberate handling of unbroken strings.

Intrinsic grids solve fitting, not arbitrary last-row centring. NewYou already
has a bounded two-/three-column centring recipe in
`assets/css/design-system.css`. Preserve it until there is replacement proof.
For a doubled-track grid with `N` visual columns, each card spans two tracks. If
the final row contains `r` cards, its first card starts at line `N - r + 1`.
This centres the occupied row when the track gaps are accounted for. Selectors
must target the actual column count and remainder, and must be reset when that
count changes. Test counts 1 through at least `2N + 1`, with start alignment too.

Use named inline-size containers for components whose layout changes between a
sidebar and a main area. An element queries an eligible ancestor, not itself.
Container-relative size units also need an eligible query container; do not
assume they always refer to the nearest visual card. Keep viewport breakpoints
for page composition. Native CSS handles layout without a resize-event hook.

## 7. Colour relationships, mixing and actual contrast

A6 has OKLCH channel inputs and separately authored shades, including hover. It
does not establish that changing one primary input necessarily updates every
state. NewYou has the same deliberate distinction today between `--primary`
and its approved `--primary-hover`.

For an independent future shade recipe, select a base colour, explicit mixing
space and mix proportion. Oklab mixing is useful for neutral elevation and
avoids making a hue-path choice; OKLCH is useful for authored lightness/chroma/hue
adjustments. They are different operations. Preserve the current mixing space
unless a reviewed change is intended. See [CSS Color 4](https://drafts.csswg.org/css-color-4/)
and [the color-mix reference](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Values/color_value/color-mix).

Mix percentages must be valid and their normalisation/alpha behaviour understood.
With two colours and one specified percentage, the other is its complement.
Mixing an opaque colour with transparent chiefly changes opacity through
premultiplied-alpha interpolation. It is not equivalent to mixing with white.
Do not linearly interpolate OKLCH components by hand to emulate CSS rendering.
Out-of-gamut results and the eventual background affect the displayed colour.

Create explicit semantic pairings for each approved surface: text, muted text,
link and hover, focus and action. A background's hue or OKLCH lightness alone
cannot choose an accessible foreground. Avoid implicit ancestor selectors that
silently restyle every nested button or nested surface.

For rendered opaque sRGB channels `s` normalised to 0..1:

```text
linear(s) = s / 12.92                         if s <= 0.04045
            ((s + 0.055) / 1.055)^2.4         otherwise
Y = 0.2126 * linear(R) + 0.7152 * linear(G) + 0.0722 * linear(B)
contrast = (max(Y_foreground, Y_background) + 0.05)
           / (min(Y_foreground, Y_background) + 0.05)
```

Use actual composed colours. Resolve translucent overlays and surface ancestors
before calculating contrast; unresolved or invalid samples must not report a
passing ratio. Do not compare the OKLCH L channel as WCAG luminance.
For gradients/textures, sample beneath the full possible label area and relevant
states, including extrema and interior points. Checking two gradient endpoints
alone is not general proof. Normal text needs 4.5:1; eligible large text needs
3:1 under [WCAG 1.4.3](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html).
Control boundaries/focus require separate applicable non-text assessment.

Do not derive a new production hover colour merely to eliminate an editable
token. Prototype a derivation, measure its states and obtain the existing design
approval before replacing the current approved hover value.

## 8. Overhead lighting, borders, shadows and textures

These are NewYou design recipes; the inspected package is not authority for
their numerical choices. Preserve the existing opt-in `lit` button and `raised`
card implementation and flat defaults.

For the approved light theme, require increasing displayed neutral luminance
from canvas to panel to raised surface. Within a raised element, the top edge
is lighter than the bottom edge. These relationships are a visual check, not
a claim that z-index alone should automatically select a colour or that a
modal scrim must become lighter. Semantic states may have their own contrasts.

Define an elevation recipe as offset, blur, spread and alpha. Cast shadows have
a positive vertical offset in the chosen physical lighting model. Use small
approved levels, no automatic shadow on every box. A recessed pressed control
reverses its edge treatment and uses an inset cue rather than adding more cast
shadow. Reserve border width in the resting state to prevent state layout shift.

For concentric nested rounded boxes, `inner_radius = max(0, outer_radius - inset)`
is a useful geometric candidate when the inner boundary follows the same curve.
Use the actual border/padding inset. Independent buttons, pills and non-concentric
content retain their own approved radius roles.

CTA gradients stay shallow, vertical and derived from the approved primary.
Their minimum label contrast must survive hover and pressed states. Keep the
focus outline separate from decorative box shadows so one cannot erase the other.

Surfaces can group fill, optional image, overlay and placement as A7 does.
Texture intensity and overlay strength need explicit bounds per approved recipe.
Noise remains decorative, low contrast, non-interactive and preferably static;
it must not obscure text, focus, errors or disabled cues. A future texture layer
needs measured rendering and a licensed asset if applicable. Do not adopt a new
noise asset, animation, blend mode or fixed intensity through this research note.
Forced colours remove decoration and retain native boundaries/focus. Preserve
solid fallbacks outside colour-function support blocks.

An invalid colour function stored inside an unregistered custom property does
not necessarily activate `var(--token, fallback)`. The property can exist while
its substituted value is invalid for the consumer. Put advanced colour values
behind real-property `@supports` checks and retain a valid baseline token.

## 9. Token ownership, Tailwind and component contracts

Keep one editable source in `assets/css/design-tokens.css`: input values, derived
semantic roles, then existing namespaced Tailwind mappings. Components consume
roles and own their layouts/states. Do not mirror numbers into Elixir or JS.

Custom-property references resolve in the scope where a property is computed.
An inherited root-derived token need not re-evaluate because a child changes
only its input. Therefore:

- Global inputs and their derived values are declared in the same root scope.
- A local candidate/theme that overrides inputs must also re-declare the derived
  properties it expects to change, or consume those inputs directly locally.
- Aliases that must resolve at the utility consumer use Tailwind's
  [`@theme inline` mapping](https://tailwindcss.com/docs/theme#referencing-other-variables).
  This does not automatically fix unrelated inherited root derivations.
- Declare font-metric-dependent values where the relevant font is established.
- Test global and scoped edits separately. Do not assume propagation from names.

Keep classes for component identity/layout and existing owned `data-variant` /
`data-treatment` attributes for bounded visual choices. Use native disabled,
focus and pressed interaction semantics; a data attribute is not a substitute
for accessibility or behaviour. Loading must preserve the label's occupied
space, prevent duplicate actions where appropriate and expose busy state.
These are shared component requirements, not a new business lifecycle here.

Tailwind remains build syntax. Existing values can update through CSS tokens;
adding a new utility or changing build-time breakpoint definitions still needs
an asset rebuild. Runtime custom properties do not become valid media-query
thresholds merely because their names begin with `--breakpoint`.

## 10. Implementation sequence and proof required

1. Keep this research linked from the development guide. Retain the ZIP hash,
   source locators and direct-copy licensing limitation.
2. Add guide-only endpoint-first scale specimens and a comparison with the
   interpolated-ratio model. Use the existing `--fluid` engine and existing
   candidate namespace. Decide actual endpoints before adding production roles.
3. Add a small contextual spacing comparison and bounded intrinsic-grid examples.
   Exercise narrow containers independently of the viewport. Preserve final-row
   centring and current production component defaults.
4. Compare unitless and x-height leading with actual EN/AF content, a font change
   and font-loading failure. Keep the approved baseline until reviewed.
5. Review any proposed automatic hover derivation, surface pairings and texture
   intensity against actual composed contrast and the existing lighting recipes.
6. Promote only reviewed values/recipes through DESIGN.md, canonical components
   and the matching guide specimens. Migrate one bounded production page first.

Future implementation acceptance must include:

- Bounds, midpoint and descending-size checks; invalid zero/reversed viewport
  span rejection; finite positive ratios and valid destination values.
- Native, trigonometric and static capability paths, no JavaScript and real
  unsupported-engine evidence where a compatibility claim is made.
- Global and local token edits, family changes, root text-size changes and no
  unexpected fixed-height clipping. Test 200% text resizing separately from
  320 CSS-pixel reflow; a rem-based clamp is not automatic WCAG compliance.
- Viewports 320/390/744/1128/1920px, widths around actual grid-fit transitions,
  narrow component containers, long EN/AF labels and unbroken content.
- Keyboard focus, native disabled, loading/error/empty/reconnection states where
  applicable; reduced motion and forced colours; no decorative layer interception.
- Actual contrast across surface/action states and gradient label areas.
- Chromium, Firefox and WebKit for any cross-engine support claim; the existing
  Chrome proofs alone cannot establish that claim.
- Applicable `mix check`, deep checks for code changes, assets build,
  `mix design.check`, focused browser proof and supported Hallmark quality checks.
  Research alone neither requires redesign nor certifies a future UI.

### Reproducible research checks

Run `python3 docs/development/research/design_math_reference.py` from the repo.
It verifies independent arithmetic for interpolation, modular endpoints,
grid-fit thresholds, doubled-track centring and WCAG sRGB contrast anchors.
Its JSON includes comparison data for the two type-scale models. It does not
compile or execute Automatic.css, test CSS parsing, prove browser compatibility,
or certify a production palette. Browser and application proof remain separate.

Observed research proof: the reference command passed 104 arithmetic checks;
23 local Markdown link targets across this note and the guide existed;
`git diff --check` passed. Archive CRC verification and source hashes were
checked independently. These results do not close the licensing uncertainty,
certify future visual candidates, or replace the existing delivery gates.

`python3 -m unittest tests.test_foundation_lane_routing tests.test_foundation_smoke`
passed all 54 tests after the external typography-configuration locator was
expressed separately from repository links. The first run had four failures
caused by that citation. No smoke rule, fixture or application source was changed.

## 11. Second-pass review and corrections

Reviewed baseline: `40a6d7712c51bbeb2c7124708c8e5f16608c6a3c`. The second pass
combined source tracing, a bounded independent review of the equations and
reference code, rejection-case reproduction, and actual Chrome CSS checks.
The independent review found the core interpolation, modular endpoint,
equal-column threshold and doubled-track symmetry equations dimensionally
consistent. Its findings concern the reference validator and the distinction
between arithmetic proof and implemented selectors, not merge certification.

### Corrected: reference input validation

The original checker accepted NaN/infinite size endpoints, malformed or
out-of-range RGB channels, and an overflowing viewport span. A short RGB tuple
silently lost a luminance coefficient through `zip`; finite bounds alone did
not ensure a finite difference. Its 104 positive arithmetic checks did not
exercise these contracts. This was a defect in the research reference, not the
application colour sampler, which already rejects malformed measurements.

Added rejection cases first and observed failure, then corrected the reference:

- Size endpoints must be finite and non-negative. The size helper is deliberately
  not an implementation for signed tracking or translation values.
- Viewport inputs and span must be finite and ordered. Values outside a valid
  span return the relevant bound before unnecessary subtraction.
- Colours require exactly three finite numeric sRGB channels in 0..1. Strings,
  booleans, null, partial tuples and extra channels are rejected.
- Added mid-grey reference values that exercise nonlinear sRGB conversion and
  a near-threshold contrast pair; black/white anchors alone were insufficient.
- Added fixed-viewport root-size cases and retained descending-size checks.

The corrected command passes 126 arithmetic checks. This reference does not
validate arbitrary edits to the production stylesheet. The current design
enforcement scans palette/authority and bypass rules; it does not assert every
fluid bound, percentage or numerical relationship. CSS token edits still need
the applicable rendered checks. Do not describe the reference as automatic
runtime token validation or a complete token dependency linter.

### Confirmed: rem scaling also moves the viewport bounds

At an 840px CSS viewport, the current display candidate computes to 52px with a
16px root and 80px with a 32px root. This follows the rem endpoints and the moving
30rem/75rem interpolation interval. It does not double the computed font size.
This is why root resizing, text-only enlargement and browser zoom/reflow are
separate checks. The candidate engine's behaviour is confirmed, not certified
as satisfying all text-resize requirements. Do not replace those checks with
an assumption that rem automatically supplies proportional enlargement.

The [WCAG text-spacing guidance](https://www.w3.org/WAI/WCAG22/Understanding/text-spacing.html)
requires preserving content/function when users apply line-height 1.5 times the
font size, paragraph spacing 2 times, letter spacing 0.12 times and word spacing
0.16 times. These are override-test conditions, not required default styles.

### Confirmed: current token scope has an explicit limit

An actual cloned canonical primary button was given local overrides for primary
colour, XL radius and body font. The colour stayed at the root primary, the
radius stayed 32px despite a 37px local input, and the family became monospace.
This matches the current static colour/radius mappings and inline font mappings.

Global root edits remain the supported contract and already have browser proof.
Local colour/radius themes are not implemented by the research recommendations.
If a future scope requires them, deliberately change the relevant mappings to
consume local roles, redeclare local derived values as needed, and test flat,
lit and raised consumers together. Do not claim that changing a child input
already updates every inherited alias or lighting derivation. No production
mapping or visual default was changed by this second pass.

### Added: implemented CSS proof separate from arithmetic

Run the additional read-only proof with external tooling:

```sh
BROWSER_TOOLS_ROOT=/tmp/newyou-refinement-tools CHROME_PATH=/usr/bin/google-chrome node docs/development/research/design_math_browser.mjs
```

Observed result: 212 assertions pass in Chrome 155.0.8059.84. Coverage includes
all four fluid consumers at 16/20/32px roots and five viewport widths, descending
endpoint ranges, native/trigonometric/static selection, and real grid geometry
for both start and centre alignment. Grid checks assert actual column count,
last-row population and alignment for counts 1 through `2N + 1` at 744/1128/1440px.
The script also reports the local token-scope observation without making that
limitation an approved theme contract. Each browser mutation is confined to its
page; there are no application writes or source modifications.

Fallback selection uses CSSOM rule removal in Chrome. It is not a test of a
browser that lacks those functions. The new intrinsic auto-fit pseudocode,
future modular scale adoption, x-height leading, local themes and Firefox/WebKit
remain outside this proof. Browser assertions count separately from arithmetic.

The existing lighting proof was rerun and passed: neutral elevation order,
directional/composited edges, native states, gradient label contrast, focus,
320px long-label/200% text checks, token edits and forced-colour/solid fallbacks.
The supported Hallmark command from the development guide, targeting
`assets/css/design-tokens.css`, `assets/css/design-components.css` and
`assets/css/design-system.css` with app scope and modern-minimal genre, rendered
five screenshots and returned zero FAIL/open REFLEX/WARN/rejected waivers. The
single existing numeric-weight/font-family waiver remained. This guide result
does not close the earlier registration/Tidewave finding or WELL-114.

Documentation impact: research only; no Domain, persistence, lifecycle or public
application interface changes. No new capability map is required. WELL-114,
existing delivery gaps and exact-head review requirements remain open.
