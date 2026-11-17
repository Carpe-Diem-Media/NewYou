# Design-system next-pass roadmap

The [current coverage index](../../design_system_coverage.md) reconciles these
pass contracts with later code and actual consumers. Unchecked boxes below
are the original contracts, not proof that every item is still unimplemented.
Historical WELL-114 and shared-TEST status statements describe their recorded
checkpoints; current delivery state belongs in Plane and the source-linked index.

Updated 2026-11-15 for WELL-112. This incorporates the owner's request to combine modular typography scaling with native `progress()` and preserves the remaining content, component and adoption work discussed in this thread. It is an engineering planning note, not the governing product Roadmap, a release approval or an implementation-completion record. Plane remains the live execution ledger.

## Baseline and constraints

The inspected source is `53cc276e86ba1ebf64e0f05ce55d4851c411573d` on draft [PR #227](https://github.com/Carpe-Diem-Media/NewYou/pull/227). The earlier numbered ACSS research/implementation phases retain their names and recorded evidence. The **passes below are the next runs**, not a renumbering or completion claim for those phases.

- The [module inventory](README.md), [layout proof](phase2-layouts.md), [component contracts](phase3-components.md), [registration pilot](phase4-registration.md), [content work](phase5-content.md) and [compatibility evidence](phase5-compatibility.md) are the starting point. Extend their proven recipes rather than rebuilding them.
- `assets/css/design-tokens.css` owns font roles, production type values and the existing fluid interpolation engine. Production typography is individually authored. The fluid display/body/spacing/gutter endpoints remain guide candidates; a complete modular typography generator is not implemented.
- Semantic content/section/control spacing, scoped `.ds-prose` and shared dividers already have a registration consumer. Card spacing roles, explicit figure/caption prose rules, complete surface pairings and several shared native form controls remain unfinished.
- Keep the approved palette, shapes, self-hosted Inter weights 400/500/700 and premium lit-primary shine. Font families remain editable through the canonical body/display CSS tokens. A future font replacement also needs a metrics and wrapping review.
- Use native CSS custom properties, namespaced Tailwind roles and existing Phoenix components. No Sass, WordPress runtime, vendor source import or second JavaScript sizing engine is required.
- WELL-114's independent post-merge certification gap remains open under the owner's explicit continuation exception. This roadmap does not close it or authorize integration. Recheck live dependencies before each implementation run.

## Pass 1: modular typography with the existing progress engine

Goal: make scale relationships inspectable and adjustable in one CSS source, then review their visual results before production adoption.

Implementation continuation: [candidate typography notes](pass1-typography.md) record the guide mechanisms and observed proof. The checklist below remains the pass contract; current execution/verification state belongs in Plane. Candidate values have not been promoted into production.

### Mathematics and token ownership

Use the endpoint-first model documented in [the typography research](../automatic-css-4.0.3-math.md#3-modular-typography-choose-the-interpolation-model-explicitly):

```text
mobile[k]  = mobile_base  * mobile_ratio^k
desktop[k] = desktop_base * desktop_ratio^k
p          = progress(viewport, viewport_min, viewport_max)
size[k]    = mobile[k] + p * (desktop[k] - mobile[k])
```

The modular scale determines endpoints. `progress()` supplies the interpolation factor and `calc()` produces the final length. Matching endpoints and viewport bounds produce the same linear curve as a correctly generated classic clamp. Interpolating the base and ratio first gives a different intermediate curve and must not replace this model accidentally. The [CSS specification](https://drafts.csswg.org/css-values-5/#progress) defines the native progress calculation.

- [ ] Define separate candidate inputs for heading/display and body scales where the roles require them: mobile/desktop bases, mobile/desktop ratios and a bounded list of steps. Describe negative steps and per-step endpoint overrides. Retain semantic exceptions for captions, controls and other roles that do not fit the scale.
- [ ] Keep the viewport bounds and `--fluid` calculation in the existing engine. Preserve its consuming-property `@supports` checks, native-progress enhancement, trigonometric fallback and usable static minimum. Do not test support through an unregistered custom property alone. Add no separately maintained slope/intercept values.
- [ ] Express the small fixed set of powers through multiplication/division unless separately tested native `pow()` support is justified. Validate finite positive bases, finite ratios at least 1, positive ordered viewport bounds and usable role endpoints. Document which inputs are root-only and which optional overrides resolve locally at the consuming element.
- [ ] Keep one source for font families and map reviewed sizes into existing semantic type roles and Tailwind utilities. Do not migrate every selector to mathematical step names. Show the difference between changing the font family, changing a scale input and overriding a role.
- [ ] Review unitless line heights, tracking relationships and readable widths with each size. Keep x-height-based leading as a separate candidate. Defer bridge-size families until an actual consumer needs one.

### Guide and proof

- [ ] Add side-by-side current and candidate specimens to the existing guide. Show input tokens, step endpoints, semantic assignments and computed sizes. Include long EN/AF headings, paragraphs, nested content and control labels. No specimen becomes approved through its presence in the guide.
- [ ] Extend `docs/development/research/design_math_reference.py` and the actual consuming CSS/browser checks. Test below/at/above the viewport bounds, a midpoint for every step, negative steps, equal size endpoints, endpoint overrides and invalid inputs. Bind expected values to endpoint-first interpolation.
- [ ] Force each supported native/trigonometric/static path in `test/assets/design_compatibility_browser.mjs` and compare computed sizes. Exercise root sizes 16px and 32px, narrow parents, 320 CSS px reflow, font-loading/fallback behavior and a controlled alternate-font check. Report true browser zoom separately from root-size simulation.
- [ ] Record visual review of hierarchy, wrapping, body readability, accented text, multiline clipping and control fit. Keep current production mappings until the candidate values have visual approval and bounded consumer proof in Pass 6.

Primary seams: `assets/css/design-tokens.css`, `assets/css/design-system.css`, `lib/new_you_web/live/design_system_live.ex`, the existing guide specimens, the arithmetic reference and compatibility runner. Inspect their current structure before selecting a focused helper or test file.

Exit: documented inputs and override precedence, verified endpoint arithmetic and fallback paths, reviewable guide candidates, and an explicit record of approved versus still-candidate role values. This pass must not imply site-wide typography adoption.

## Pass 2: finish contextual spacing and scoped prose

Build on the existing content/section/control roles and `.ds-prose` rather than repeating Phase 5.

Implementation continuation: [card spacing and scoped prose notes](pass2-content.md) document the role assignments, figure/caption flow, explicit nesting boundary, consumer inspection and proof. Current delivery state remains in Plane, including shared TEST coordination.

- [ ] Define card content/action spacing roles and map their initial values to the current geometry. Keep padding distinct from child spacing and control spacing.
- [ ] Add explicit figure/caption and nested rich-text behavior. One owner controls layout gaps; prose owns its margin flow. Preserve first/last-child rules and avoid doubled spacing.
- [ ] Show root edits and supported local overrides in the guide, with long EN/AF content and narrow parent examples. Identify an eligible existing content-page consumer for Pass 6. If none exists, record that fact instead of inventing a page or changing legal responses.

Primary seams: `assets/css/design-tokens.css`, `assets/css/design-content.css`, `assets/css/design-components.css`, `lib/new_you_web/live/design_system_content.ex` and their existing tests.

Exit: changing one spacing role affects its intended consumers without moving unrelated controls; prose remains readable with the typography candidates and approved production sizes.

## Pass 3: finish borders and divider contracts

Implementation continuation: [border purpose and divider notes](pass3-borders.md) record canonical inputs, local precedence, actual selected-border radius math, native state comparisons and nested ownership. The checklist remains the contract; current execution and exact-head verification belong in Plane.

- [ ] Distinguish decorative hairlines, visible control boundaries, semantic separators and directional lighting edges. Document width, style, color, ownership and local override rules for each purpose.
- [ ] Keep top edges lighter than lower edges for lit treatments, with restrained downward shadows where already approved. Preserve the premium primary gradient and shine through default, hover, pressed, loading, disabled and focus states.
- [ ] Extend existing divider arithmetic and native `hr` proof only for new behavior. Check nested groups, long labels, forced colors, focus clipping and contrast appropriate to each boundary's purpose.

Primary seams: canonical tokens, shared component/content CSS, existing button/card/divider components and guide specimens.

Exit: each border has a named purpose and owner, divider spacing is predictable, and no CTA styling or native state regresses.

## Pass 4: complete surface and foreground pairings

Implementation continuation: [opaque surface pairing notes](pass4-surfaces.md) record the finite shared boundary, complete profile roles, card/link integration, nested reset behavior, contrast thresholds and proof limits. Current execution, grants and exact-head delivery evidence remain in Plane.

- [ ] Define allowed surface roles with their heading, body, muted, link and focus assignments. Use a finite component-owned `data-surface` attribute where it expresses an actual component variant.
- [ ] Resolve dependent tokens at the consuming scope. Nested surfaces reset their own complete pairings rather than inheriting an incompatible parent foreground.
- [ ] Measure actual foreground/background contrast for every allowed pairing and relevant state. Review lighting order, approved gradients, overlay/noise intensity and text placement together. Do not infer usable text pairings from background lightness alone.
- [ ] Test attribute ownership, invalid values, unrelated metadata forwarding, nested overrides and solid-color/forced-colors fallbacks.

Primary seams: canonical tokens, shared component CSS/APIs, existing attribute-contract tests and guide color-relationship specimens.

Exit: every adopted surface provides a visually approved, measured set of foreground roles with predictable nesting. Additional palette or treatment values require deliberate review.

## Pass 5: extend native form components from real consumers

Implementation continuation: [native form notes](pass5-native-forms.md) record the actual registration/guide helpers, state and description ownership, field/choice inputs, ACSS source decisions and proof. Execution and shared-resource windows remain in Plane.

- [ ] Extract the registration pilot's repeated checkbox, fieldset and associated help/error patterns into shared semantic components without changing copy or validation behavior.
- [ ] Add radio, select or textarea contracts only when an actual consumer needs them. Keep native interaction semantics and caller-supplied localized content.
- [ ] Cover labels, descriptions, grouped choices, invalid/disabled/loading behavior, error association and an error summary where the consuming form requires it. Preserve control dimensions and focus during LiveView updates.
- [ ] Test keyboard behavior, long EN/AF labels, text enlargement, narrow layout, error navigation and applicable reconnection/loading states.

Primary seams: existing canonical Phoenix form components, registration template, pilot CSS and focused component/controller/browser tests. Re-read copy contracts before changing participant-visible markup or strings.

Exit: the pilot uses shared native controls with documented states, ownership and accessibility rules; exact governed copy and business behavior remain intact.

## Pass 6: prove and promote one bounded production consumer

- [ ] Reverify the existing registration pilot and select the genuine content-page consumer identified in Pass 2. Keep either task bounded to an actual approved page and its existing content.
- [ ] Apply only the typography, spacing, border, surface and form recipes relevant to that consumer. Preserve semantic role names and the single CSS source of values.
- [ ] Prove long EN/AF content, 320 CSS px reflow, narrow containers, text resizing, font loading, keyboard focus and applicable native/LiveView states. Run supported browser engines and report unavailable coverage explicitly.
- [ ] Update guide specimens to render those exact components. Record each recipe as candidate, approved or deprecated with its scope and proof. Obtain visual approval before promoting new type or surface values; do not label development-gated pages as released.

Exit: the selected page and guide share the same proven components and token assignments. If content authority or an eligible page is absent, stop only that adoption scope and record the missing prerequisite.

## Pass 7: diagnostics and controlled adoption

- [ ] Extend the existing guide with scoped overflow checks, missing-token diagnostics and useful computed/local-override readouts. Claim token-origin inspection only if the tool can establish the source reliably.
- [ ] Add focused regressions for the adopted patterns and a short recipe/editing guide. List known legacy consumers and migrate only an authorized next page, not the entire site at once.
- [ ] Reconcile the ACSS inventory's adopt/adapt/defer decisions with actual implementation and evidence. Keep unsuccessful or unproved candidates visible as such.

Exit: future changes have an edit location, a demonstrated consumer and a repeatable check. Diagnostics remain development-only and do not create runtime styling authority.

## Later, when a real consumer requires them

Evaluate media aspect/intrinsic/crop recipes and concentric image/card radii. Evaluate shared header-height relationships, sticky positioning and anchor offsets only against an actual header. Revisit breakout adoption and bridge typography only with a demonstrated layout need. Keep these deferred rather than creating speculative tickets or a general-purpose replacement for every ACSS module.

## Execution and proof for each pass

Before implementation, confirm the current source and live Plane scope/dependencies, then write a bounded pass-specific plan with exact files and tests. This roadmap sets sequencing; it does not authorize fresh implementation against a non-executable ticket or waive the existing delivery gates.

For each implemented pass, record inputs, formulas, generated tokens, selectors, dependencies, valid ranges, override ownership, guide specimens, actual consumers and missing proof. Preserve source references and extend the existing notes instead of duplicating them.

Use focused regression tests plus applicable `mix check`, `mix check.deep`, asset, token, browser and installed Hallmark checks. Preserve the existing design. Fix introduced failures; document inherited findings and supported waivers without weakening enforcement. Record browser versions and distinguish arithmetic, source, render and runtime evidence.

Keep an independent integration track for WELL-114 certification, the recorded Hallmark verification gap, unresolved development reload errors, base conflicts, exact-head hosted CI, independent Master Gate and resulting-main proof. Their latest status belongs in Plane. No pass completion or score supplies merge authorization or closes those obligations.

## Acceptance for this roadmap update

1. Typography is the first upcoming pass, with endpoint-first scale math, reuse of native `progress()` and existing fallbacks, semantic mapping and candidate-review boundaries.
2. The earlier spacing/prose, border, surface, form, page-proof and diagnostics work remains sequenced with explicit exit checks and deferred consumer-driven work.
3. Links resolve, current source and live execution boundaries are recorded, and no runtime styling or approval state changes as part of this documentation update.
