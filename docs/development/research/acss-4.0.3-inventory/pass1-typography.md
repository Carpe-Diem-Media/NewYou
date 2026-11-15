# Next pass 1: candidate modular typography

WELL-112 / draft [PR #227](https://github.com/Carpe-Diem-Media/NewYou/pull/227), 2026-11-15. This implements the first upcoming pass in [the roadmap](next-passes.md), following the owner's explicit selection. It follows the earlier numbered ACSS phases without renaming them. The starting branch revision was `8306a3f6473755eae683231ce92b75f3805c8ec5`; current exact-head engineering evidence belongs in PR/Plane and generated history.

## Decision and boundaries

Adapt the endpoint-first modular relationship described in [the mathematics research](../automatic-css-4.0.3-math.md#3-modular-typography-choose-the-interpolation-model-explicitly). ACSS generates separate mobile and desktop endpoints before interpolation. NewYou expresses that relationship directly in canonical CSS and reuses its existing interpolation engine. No vendor implementation, WordPress runtime, Sass compiler, dependency or JavaScript sizing engine is added.

The guide adds `/dev/design-system#type-scale` with `data-status="candidate"`. All twelve current semantic sizes appear beside candidate sizes. Registration, the isolated application preview, existing `--text-*` values and their production Tailwind mappings stay unchanged. Palette, shapes, self-hosted Inter, unitless line heights, tracking and the premium lit-primary treatment also remain unchanged. This proof is not visual approval, production adoption, participant release or integration certification.

## Inputs and formulas

Edit the eight literal inputs in `assets/css/design-tokens.css`:

- Body: `--type-body-base-min: 1rem`, `--type-body-base-max: 1.125rem`, `--type-body-ratio-min: 1.2`, `--type-body-ratio-max: 1.333`.
- Headings: `--type-heading-base-min: 1.5rem`, `--type-heading-base-max: 1.6875rem`, `--type-heading-ratio-min: 1.2`, `--type-heading-ratio-max: 1.333`.

These are initial comparison inputs. The heading bases were chosen as 1.5 times the body comparison bases to put the largest heading near the current display range. They are independently editable values, not live aliases to the body family. Editing a body input must not change headings.

Each family has six steps, `xs/s/m/l/xl/xxl`, corresponding to `k = -2/-1/0/1/2/3`:

```text
mobile[k]  = mobile_base * mobile_ratio^k
desktop[k] = desktop_base * desktop_ratio^k
size[k]    = mobile[k] + p * (desktop[k] - mobile[k])
```

CSS uses repeated multiplication or division by a unitless ratio, not native `pow()` or typed length division. The original `--fluid` engine supplies `p`: static 0, then the feature-tested trigonometric fallback, then native `progress()` where supported. `--fluid-vmin` and `--fluid-vmax` remain root-only. Its existing consuming-property support tests and explicit 0-to-1 clamp remain intact. There are no duplicate viewport formulas or authored slope/intercept coefficients.

At a 16px root, the body base endpoints are 16px and 18px. Heading xxl is approximately 41.472px and 63.952px. The names `min` and `max` refer to viewport boundaries; they do not require increasing sizes. Raw body xs decreases between the endpoints because the desktop ratio is larger. The guide labels measurements Mobile, Current and Desktop to avoid calling the smaller-viewport value a mathematical minimum.

## Generated tokens and semantic mapping

For each family and step, CSS supplies `--type-{family}-{step}-min`, `--type-{family}-{step}-max` and `--type-{family}-{step}`. The guide's hidden empty probes consume these as `font-size`; the existing hook reports their actual computed pixel sizes. Hidden mathematical probes do not contribute layout or accessible content. Negative steps are numerical examples rather than adopted small body text.

Candidate semantic aliases are distinct from production roles:

- Display XL/L/M/S map to heading xxl/xl/l/m.
- Heading M/S map to heading m/s.
- Body L maps to body l. Body M/S/XS currently map to body m. Those shared candidate defaults are deliberate comparison assignments, not a decision to erase the semantic distinctions.
- Every candidate body role applies `max(var(--text-body-xs), calculated-size)` so a small scale input cannot silently make running body text smaller than the current body-xs role.
- Button and caption aliases refer to `--text-button-md` and `--text-caption` directly. The mathematical body-xs step is not automatically used as a caption.

The aliases use `--type-candidate-{existing-role}` and expose corresponding `--text-design-candidate-{existing-role}` mappings through the existing `@theme static inline`. The existing production `text-design-*` utilities are unchanged. Candidate consumers are confined to the new guide section. The aliases are not approved production recipes.

Current and candidate examples retain the existing unitless `--leading-{role}` and absolute `--tracking-{role}` values. Their suitability with different sizes requires visual review. Proportional tracking, font-metric/ex-based leading and bridge-size families remain deferred.

## Scope and overrides

The derived token block applies at `:root` and `:where(.ds-type-scope)`:

1. Root edits to a family base or ratio update the whole candidate family, including explicit child scopes.
2. A local base or ratio on an explicit `.ds-type-scope` boundary rebinds the derived tokens there. Its sibling scopes keep their own inherited inputs. Ordinary descendants inherit the computed results; placing a base override on an arbitrary descendant does not promise to regenerate root-authored aliases.
3. Optional `--design-type-{family}-{step}-{min|max}` inputs replace only the named step endpoint at that boundary. Other steps still derive directly from the family's bases and ratios. An endpoint override is not fed into adjacent step calculations.
4. Nested scopes inherit their ancestor's inputs and optional overrides until explicitly changed. They do not reset themselves to root defaults.

The guide's local example replaces `--design-type-heading-xxl-max` with the existing `--text-display-md` value. It changes no production token. The neighboring default display and body samples demonstrate isolation. Its current-size readout targets the actual local consumer; input readouts elsewhere intentionally describe root inputs. Use the existing refresh control after browser-only local experiments that do not change geometry.

Font families remain in `--font-body` and `--font-display` in the same canonical stylesheet. Root body-font changes update both by default; an explicit display-font selection can keep headings separate. A replacement font needs its permitted files/face declaration plus a new wrapping/metrics review. The tests check serif/monospace selection as controlled experiments, not approved alternatives or installed assets.

## Validation contract

`Mix.Tasks.Design.Check.token_numeric_violations/1` now also checks these eight source inputs. Bases require one positive finite `rem` literal. Ratios require one finite unitless literal at least 1. Every unmodified step endpoint must remain finite and positive, including the negative powers; overflow and underflow are rejected. Equal family ratios and descending endpoint pairs remain valid. Existing color, fluid-bound, layout and texture enforcement is preserved.

This is a bounded source-input gate. It does not parse general CSS, validate arbitrary runtime/local overrides, guarantee browser precision for every extreme number, or approve readability. Optional endpoint values must be compatible positive lengths. Their consumer still follows normal CSS validity/cascade rules. Root inputs must stay within the reviewed visual range when candidates are eventually adopted.

## Implementation and proof entry points

- Canonical values, formulas, scope rebinding and Tailwind mappings: `assets/css/design-tokens.css`.
- Guide-only composition and selectors: `lib/new_you_web/live/design_system_typography.ex`, imported by the existing LiveView, and `assets/css/design-typography.css`, imported by the existing app stylesheet.
- Gate and missing/duplicate/invalid/overflow regression tests: `lib/mix/tasks/design.check.ex` and `test/new_you_web/design_system_infrastructure_test.exs`.
- Guide candidate/role/measurement/EN-AF/preview-isolation assertions: `test/new_you_web/live/design_system_live_test.exs`.
- Independent endpoint/interpolation/override arithmetic: `docs/development/research/design_math_reference.py`.
- Computed CSS, semantic mapping, scope/step/font overrides, text resizing/spacing and font-fallback proof: `test/assets/design_type_scale_browser.mjs`.
- Cross-engine and fallback selection: `test/assets/design_compatibility_browser.mjs`. It imports the shared proof and runs it on each native/trigonometric/static path, with 16px and 32px roots and explicit below/at/midpoint/at/above widths derived for each root. Selecting shipped CSS through CSSOM is not historical-browser emulation.

Repeatable commands:

```sh
python3 docs/development/research/design_math_reference.py
ERL_FLAGS='+S 4:4' mise exec -- devcore-project run test -- mix test test/new_you_web/design_system_infrastructure_test.exs test/new_you_web/live/design_system_live_test.exs test/new_you_web/design_component_contracts_test.exs test/new_you_web/design_field_test.exs
ERL_FLAGS='+S 4:4' mise exec -- devcore-project run dev -- mix assets.build
BROWSER_TOOLS_ROOT=/tmp/newyou-refinement-tools node test/assets/design_type_scale_browser.mjs
BROWSER_TOOLS_ROOT=/tmp/newyou-refinement-tools DESIGN_BROWSER=chrome node test/assets/design_compatibility_browser.mjs
BROWSER_TOOLS_ROOT=/tmp/newyou-refinement-tools DESIGN_BROWSER=firefox FIREFOX_PATH=/snap/bin/firefox FIREFOX_PROFILE_ROOT="$HOME/snap/firefox/common" node test/assets/design_compatibility_browser.mjs
HALLMARK_PUPPETEER=/tmp/newyou-refinement-tools CHROME_PATH=/usr/bin/google-chrome node /home/jcschoeman96/.agents/skills/hallmark/scripts/sloplint.mjs assets/css/design-tokens.css assets/css/design-system.css assets/css/design-typography.css assets/css/design-components.css --scope app --genre modern-minimal --url http://127.0.0.1:4237/dev/design-system --json
```

The external browser-tool directory and local server are workstation prerequisites, not new application dependencies. Firefox profiles are uniquely created and removed by the existing runner, including its separate native no-script profile. Test commands use DevCore TEST, asset builds use DEV, and no reset/cleanup is performed.

## Observed review and limits

The two new contract tests failed first for the absent input validation and guide section. The initial focused pair then passed 43 tests; the wider component/field set passed 53. The independent reference passes 303 arithmetic assertions. Chrome's focused typography proof covers actual semantic sizes, native disclosure/focus, exact doubled text rather than compounded inheritance, long EN/AF text, alternate-family propagation, blocked Inter delivery and no-script rendering. Root-size simulation is explicitly separate from true text doubling and browser zoom.

Bounded independent source review found no actionable defect in the scale, cascade, gate, guide isolation or proof design. It did not execute tests or assess merge readiness. Role-map tests check agreement with the selected candidate assignments; they cannot establish that those assignments are visually appropriate.

The first Hallmark run exposed an overly long new note, an invalid new waiver comment and an inherited field-height REFLEX when its owning stylesheet was absent from the target list. The note now uses existing `--measure`, the unnecessary malformed comment was removed, and the four-file run includes the existing component-owned 58px field waiver. The corrected run exits 0 with zero FAIL/open REFLEX/rejected waivers, two existing waivers and one retained gradient-endpoint WARN on the shared lit CTA. No new waiver is introduced. Desktop, phone and current/candidate captures were inspected. The lighting regression still measures 5.32:1 normal, 9.41:1 hover/pressed and 5.31:1 with wrapped enlarged text. The endpoint warning remains recorded; the premium button is not flattened to satisfy it.

Chrome 155 and Firefox 160 both passed the expanded boundary/fallback proof. Final exact-head counts and canonical gate outcomes are recorded in PR/Plane. Firefox DEV reload errors remain visible under the existing narrow classification. WebKit, true browser zoom, screen-reader checks and Firefox media emulation remain unverified. Existing registration Hallmark developer-toolbar findings and WELL-114 independent post-merge/full-suite reconciliation remain open. No passing guide check closes those delivery gaps.

Documentation impact: presentation-only tokens and guide specimens add no Domain, durable state, schema or business interface/lifecycle. A new semantic capability map is exempt. The generated PR history, developer guide and this focused source/proof addendum describe the change.
