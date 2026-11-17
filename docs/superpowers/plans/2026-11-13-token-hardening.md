# Token hardening implementation plan

> For agentic workers: use the subagent-driven-development workflow for the
> bounded CSS/browser task; the parent owns validation, integration and review.

**Goal:** Close the numeric-input and local-consumption gaps identified by the
second pass without changing approved default values or promoting fluid sizes.

**Architecture:** Keep native CSS inputs in design-tokens.css. Tailwind utilities
consume roles at the element; shared button/card lighting derivations are
re-evaluated at their component scope. Extend the existing build gate for the
known numeric source inputs. No new theme API, framework dependency or Domain work.

**Tech stack:** Phoenix, Tailwind v4, CSS custom properties, ExUnit and external
Puppeteer/Chrome. Continue WELL-112 / draft PR #227 under the recorded owner
exception for the open WELL-114 resulting-main certification gap.

The owner requested implementation after reviewing the research notes and second
pass. This plan records JIT mechanisms for that accepted direction; no new
visual value or approval of global fluid typography is inferred.

## Task 1: local semantic consumers

Files: assets/css/design-tokens.css and
test/assets/design_token_scope_browser.mjs.

- [x] Add a browser regression that clones actual shared flat/lit buttons and
  flat/raised cards. Apply local primary/hover/radius inputs, verify computed
  colours/radii and lit gradients/shadows follow them, and verify an unmodified
  sibling retains the baseline. Include a root edit so the existing contract
  remains covered. Observe failure before changing CSS.
- [x] Keep numeric defaults and static breakpoint declarations. Map semantic
  visual utilities inline while retaining emitted theme aliases needed by CSS.
  Re-declare only palette-dependent lighting relationships at shared component
  scope, in the token file, so local inputs reach those calculations. Do not
  reset inherited input values or create per-component raw values.
- [x] Run the new scope proof, existing guide and lighting proofs. Preserve native
  disabled/focus and forced-colour/solid fallbacks. Do not claim arbitrary parent
  themes, local palette-source aliases or local fluid-bound overrides supported.

## Task 2: numeric source input gate

Files: lib/mix/tasks/design.check.ex and
test/new_you_web/design_system_infrastructure_test.exs.

- [x] Add focused ExUnit regressions through Check.token_numeric_violations/1.
  Accept the actual token source, descending fluid size endpoints and boundary
  percentages. Reject missing inputs, invalid literals/units, negative sizes,
  zero/equal/reversed viewport bounds, percentages outside 0..100 and noise
  opacity outside 0..1. Observe failure before implementing the function.
- [x] Implement a small explicit input schema using the existing CSS declaration
  scan. Require rem for fluid boundaries/endpoints; require numeric percentages
  for known mixing inputs and a unitless noise opacity. Permit decreasing size
  endpoints while requiring a positive ordered viewport interval. Reject missing
  or duplicate source input declarations instead of silently picking one.
- [x] Include the function in the existing mix design.check error aggregation.
  This is build-time input checking, not validation of arbitrary runtime CSS,
  generic CSS parsing, colour contrast or every token dependency.

## Task 3: integration and exact evidence

- [x] Update DESIGN.md with the narrowly authorised editing/validation mechanism,
  preserving its visual values; the enforcement task requires authority and
  executable-token changes together. Document supported scope and limitations
  in docs/development/design_system.md. Preserve historical research observations
  and add a dated implementation note.
- [x] Run focused ExUnit, assets build, numeric gate, scope/guide/lighting browser
  proof, supported Hallmark checks, arithmetic reference, Node colour checks and
  routing/smoke tests. Run DevCore TEST mix check and mix check.deep.
- [x] Obtain bounded independent diff review, fix findings, and inspect the final
  diff. Refresh generated PR history from live GitHub/Plane metadata, push as
  JC-Agents, and record exact source/test evidence without closing WELL-114 or
  claiming merge certification. A new Domain capability map is exempt because
  this change affects only CSS consumers and engineering validation.

Implementation and bounded reviews are complete. Both reviewers found no actionable
source defect. Final engineering-gate and PR-history evidence is recorded in the
handoff and Plane; this checklist does not close inherited delivery gates.
