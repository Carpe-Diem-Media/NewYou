# Overhead lighting implementation

Owner-approved continuation of the proposed soft-depth design in WELL-112.
Scope is the development guide and opt-in shared component treatments. Existing
production defaults remain flat. No Domain, fixture, dependency or font changes.

- [x] Add focused failing tests for `treatment="lit"` buttons, `variant="raised"`
  cards, rejected unsupported treatments and forwarded treatment collisions.
- [x] Amend DESIGN.md for these explicit developer specimens. Add all colours,
  gradients, edge widths and shadow values to `assets/css/design-tokens.css`, with
  solid/no-shadow fallbacks and colour-mix progressive enhancement.
- [x] Add `assets/css/design-components.css` as the component layer. Keep default
  flat utilities, and let opt-in treatments own their visual properties without
  competing utilities. Use native hover/active/disabled/focus states and forced
  colour recovery. No animation or fabricated interactive state is required.
- [x] Add an indexed Lighting & depth section with neutral level swatches,
  flat/raised cards, flat/lit primary actions, secondary action and disabled
  examples. All examples consume the shared components and editable root tokens.
- [x] Run focused tests, assets/enforcement, full fast/deep gates, supported
  Hallmark render, browser contrast/state/keyboard/reflow/token/fallback proof and
  independent source review. Record observed failures under the existing gap.
- [x] Update developer guidance, evidence and generated PR history, push draft
  PR #227, and leave WELL-114's certification dependency open.

Test before and after implementation. Verify 4.5:1 label contrast across default,
hover and pressed gradients using rendered pixel sampling. Exercise 320px reflow,
long labels, 200% text sizing, forced colours and no-gradient fallbacks. Preserve
48px button height, existing radii and visible focus. Neutral surface lightness
must increase with the declared semantic elevation.

Documentation impact: presentation-only opt-in component options, no material
capability/lifecycle/schema change. Maintain the developer reference and generated
PR history; a new Domain capability map is exempt. This plan does not close the
WELL-114/full-suite or independent merge/resulting-main certification gaps.

Observed at implementation source `f5973a306045ce8a97de6a8cd1f1936d2d9d26f6`: the
final canonical fast gate passes all 637 tests in 326.8 seconds. The deep gate has
zero errors/skips. Focused tests pass 33/33; assets/enforcement, four Node tests,
54 routing/smoke tests and all three browser proofs pass. Guide Hallmark reports
0 FAIL/open REFLEX/WARN with the existing numeric-weight waiver. Bounded source
review found no actionable defect; direct secondary/card edge proof was added.
Minimum sampled label contrast is 5.08:1 at rest and 8.65:1 on hover/press.
WELL-114 resulting-main certification, prior registration/Tidewave gate 26a and
final-head hosted CI remain separate delivery gates. No merge is authorized.
