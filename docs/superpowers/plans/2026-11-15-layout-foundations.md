# Layout foundations implementation plan

Continue WELL-112 and draft PR #227 from `9160f034969e9caf95faa126f44afaa85894f9ff`. The owner requested Phase 2 guide specimens after the source inventory. Existing design direction and guide-only candidate status are approved; remaining details are JIT choices. WELL-114 certification remains open under the recorded continuation exception.

## Contract

1. Add a development-only layout lab for fixed grids, intrinsic auto-fit/auto-fill, capped containers, single-owner gutters and four breakout zones. Preserve existing shared components and the original card grid.
2. Use one canonical CSS token source. Candidate inputs live in `assets/css/design-tokens.css`; recipes consume direct inputs at their own scope. No copied plugin source, Sass, dependencies, global section conversion or production breakout promotion.
3. Provide bounded URL-backed available-width, count and alignment choices. Native labelled selects remain keyboard usable. Malformed values fall back; malformed event envelopes are ignored. With JavaScript absent, server-rendered specimens remain visible.
4. Test allocation independently of viewport, exact intrinsic fitting thresholds, overflow, empty tracks and incomplete rows. Preserve existing viewport-grid regressions and lit CTA styling.
5. Keep detailed formulas, token-editing rules, proof results and remaining gaps in the development documentation. No Domain, durable-state, authorization or schema change.

## Files and choices

- `lib/new_you_web/live/design_system_layouts.ex`: guide-only Phoenix function components for the specimens and controls. Reuse the current card count/alignment display choices and existing measurement output protocol.
- `lib/new_you_web/live/design_system_live.ex` and `.html.heex`: validate the new allocation choice and include the lab at the existing layout section. Keep old default query URLs compatible and preserve allocation across other guide changes.
- `assets/css/design-tokens.css`: explicit candidate minimum/count/narrow-allocation/content-cap/feature-lane inputs. `DESIGN.md` records only permission and bounds for these requested guide candidates, preserving all application defaults.
- `assets/css/design-layouts.css` and `assets/css/app.css`: scoped logical-property recipes, existing palette/type/spacing utilities. Fixed grid reuses `.ds-card-grid`. Auto-grid limits columns with `min(100%, max(minimum, (100%-(N-1)*gap)/N))` and distinguishes auto-fit/fill. Container padding has one owner. Seven named tracks form content/feature/feature-max/full zones; selectors affect only opted-in direct children. The cap and lane sizes derive from existing tokens and remain candidates.
- `test/new_you_web/live/design_system_live_test.exs`: render, URL-state, malformed input and preview exclusion regressions.
- `test/assets/design_layouts_browser.mjs`: repeatable geometry proof against the actual specimens, with a browser-evaluable function and optional external Puppeteer runner. No app dependency.
- `docs/development/research/acss-4.0.3-inventory/phase2-layouts.md` and the developer guide: canonical phase notes and entry links. Phase 1 catalog stays bound to its historical baseline.

## Execution and verification

- Add focused LiveView tests and the geometry proof, observe failure because the specimens/allocation contract are absent.
- Implement the bounded state and component markup; rerun focused tests.
- Implement canonical candidate inputs and scoped CSS; build assets and run design enforcement.
- Verify actual allocation thresholds at minus/at/plus one pixel, counts 1 through 2N+1, fit/fill empty tracks, nested gutters, local/root token edits, seven-track breakout geometry, long EN/AF and unbroken content, intrinsic media, 320px reflow and 200% text sizing. Check no-JavaScript visibility and keyboard focus.
- Run existing guide/math/lighting regressions where affected, canonical DevCore TEST `mix check`, `mix check.deep`, supported Hallmark lint/render and Python routing/smoke checks. Fix introduced failures; retain explicit inherited limitations.
- Record observed evidence and independent review, inspect the final diff, update PR/Plane, regenerate/check PR history and leave a clean worktree. Do not merge or claim independent post-merge certification.

Documentation impact: guide-only display/layout APIs have no Domain lifecycle, schema or business interfaces. Maintain the existing developer handoff and a focused Phase 2 addendum; a new capability map is exempt. Read the exact implementation rather than treating research decisions as production authority.

Execution outcomes and remaining delivery gates are recorded in Plane and the PR. This plan describes the work and is not a live status ledger.
