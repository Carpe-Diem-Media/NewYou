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
- [ ] Run focused tests, assets/enforcement, full fast/deep gates, supported
  Hallmark render, browser contrast/state/keyboard/reflow/token/fallback proof and
  independent source review. Record observed failures under the existing gap.
- [ ] Update developer guidance, evidence and generated PR history, push draft
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
