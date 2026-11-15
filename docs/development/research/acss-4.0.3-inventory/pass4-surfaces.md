# Next pass 4: complete opaque surface pairings

WELL-112 / draft [PR #227](https://github.com/Carpe-Diem-Media/NewYou/pull/227), continuing from `2267fce3321335eb1ee8579fdf93f6b13bcdca93`. This implements the bounded surface pass in [the next-pass roadmap](next-passes.md#pass-4-complete-surface-and-foreground-pairings). Existing palette, type, geometry and premium CTA definitions remain fixed. Profiles and local comparisons in the guide do not approve additional visual values or participant release. Live execution and resource reservations remain in Plane.

## Research decision and scope

Adapt complete contextual background/foreground relationships using explicit component boundaries. The supplied ACSS archive and module identities remain those recorded in the [module inventory](README.md) and [component research](components.md). This is independent NewYou CSS/Phoenix implementation. No vendor code, Sass/WordPress runtime, automatic dark scheme, global background detector or second JS color authority is added.

The second source trace uses the same supplied 4.0.3 archive, SHA-256 `17ee65acfd7e045e73b68f2373a2e4fba5e46ab3fd22ec5cc451472a7f5d63b5`. Vendor locators below are relative to `automatic-css/assets/scss/`, not NewYou files:

- `modules/contextual-colors/_contextual-vars.scss:1-20` defines separate variable/class feature gates and light/dark text/background defaults. `_contextual-maps.scss:1-18` groups those into named maps. `_contextual-tokens.scss:1-17` emits root `--body-bg-color`, `--text-*` and `--bg-*` under the variable gate; `_output.scss:1-23` emits `.bg--*` and `.text--*` under the class gate. Separate gates mean class declarations alone do not prove available token output.
- `modules/color-relationships/_vars.scss:1-91` enables relationships, defaults text/heading/link/hover/focus/icon assignments to null, defaults button styles to primary, and extracts maps. `_tokens.scss:1-21` emits non-null role tokens under the relationship gate; a hover token requires its base link tuple entry. `_text.scss:1-12`, `_headings.scss:1-18` and `_links.scss:1-33` bind relative foreground outputs to background selectors and configured surface selectors. Link exclusions are an additional dependency. `_focus.scss:1-13` also assigns focus to button-like descendants because their specificity differs.
- `modules/surfaces/_functions.scss:1-21` constructs matching `.surface-*` selector extensions from the configured surface map and its relationship key. `_vars.scss:3-16` shows the first surface's feature flag, background, optional asset/overlay/animation and default relationship `none`; this is not an automatically complete pairing. Scheme remapping and card/button/icon styling are additional outputs, not evidence of accessible default pairs.

Selected source identities for repeatable inspection:

```text
modules/contextual-colors/_contextual-vars.scss   a851bf7c50e0bfe4b2f5700d6ca5379fef2faf6663db0848974ffb9574712d09
modules/contextual-colors/_contextual-tokens.scss 6ef43c18e6ac854a3b96174a2786affe8da314ab33c026bfedcb4ff6b283c1ac
modules/color-relationships/_vars.scss            5b7de28d27d67e36a5cdadde6384307d0fbc44b7e656531464585b84f6bc00e6
modules/color-relationships/_tokens.scss          d52a4b977e05ed6e05c87a8925d507003aff333046e6266b6d031c3997466450
modules/color-relationships/_links.scss           7a736d26ed04a30cec5f34db63e639eeb0effbcbbbebf3649f17be5d76e18ca6
modules/color-relationships/_focus.scss           5a8745fc7cb0ce8be1d02907fba28113443c1a75ce44319f1ffca908dd492064
```

NewYou adapts complete assignments and an explicit boundary; it does not import nullable vendor defaults or infer accessibility from their names. All seven outputs are assigned at every boundary. General surface assets/overlays/animation, automatic light/dark remapping and descendant button-style replacement remain deferred. Vendor compiler/configured-output proof remains missing and is not needed to establish the independently measured NewYou recipe.

Four existing opaque backgrounds have a concrete purpose:

- `plain` uses `--surface`, the existing white flat-card/input surface.
- `canvas` uses the existing `--surface-canvas` shaded-canvas lighting output.
- `panel` uses the existing `--surface-panel` mixed-panel lighting output.
- `raised` uses the existing `--surface-raised` white raised-card output.

Plain and raised are intentionally the same background colour at current inputs; their border/shadow contracts remain distinct. Canvas and panel retain existing lighting math. These profile names do not imply new elevation or spacing. Default foreground sources are `--secondary` for headings, body and links, `--ink-meta` for muted text, and `--primary` for focus. The existing default charcoal links retain their colour on hover; the local guide comparison demonstrates an explicit approved-source hover input.

```text
canvas = color-mix(in oklab, secondary at surface-canvas-shade, canvas source)
panel  = color-mix(in oklab, canvas source at surface-panel-mix, surface source)
plain = raised = surface source
```

Current shade/mix inputs remain the existing 4% and 50%. The complementary opaque source fills the remaining weight. Relative OKLCH conversion preserves the source palette; it does not choose a foreground or prove contrast. Local source changes require fresh measured pairing and lighting-order review.

## Editing contract and inheritance

[design-tokens.css](../../../../assets/css/design-tokens.css) owns optional inputs `--surface-{profile}-{bg|heading|body|muted|link|link-hover|focus}`. Inputs stay unset by default; add them at root or in an approved canonical context. No values are authored in Elixir or JavaScript.

```text
--context-background = selected profile bg input, otherwise that profile's existing background
--context-heading    = selected profile heading input, otherwise --secondary
--context-body       = selected profile body input, otherwise --secondary
--context-muted      = selected profile muted input, otherwise --ink-meta
--context-link       = selected profile link input, otherwise --secondary
--context-link-hover = selected profile link-hover input, otherwise --secondary
--context-focus      = selected profile focus input, otherwise --primary
```

`--context-*` are derived outputs, not edit points. Every `.ds-surface[data-surface]` profile assigns all seven locally, even when its defaults equal another profile. The plain profile also resolves at root, so shared text links outside an explicit boundary preserve their default charcoal appearance. Shared cards declare their own plain/raised profile and recompute every role.

Root profile inputs update matching boundaries throughout shared consumers. A locally scoped `--surface-canvas-link` changes canvas links there; a nested plain profile reads its own plain inputs. Profile inputs deliberately inherit, so two matching profiles beneath a theme context share that context's source values. This is different from inheriting a parent's already-resolved `--context-link`: a child always recomputes that output. A local primitive edit such as `--canvas` also recomputes canvas/panel lighting at a surface boundary because `.ds-surface` joins the existing local lighting selector. [MDN's custom-property guidance](https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/Cascading_variables/Using_custom_properties) explains inherited custom properties and consumer substitution.

Use valid opaque approved-source colors for backgrounds and foreground roles. Any custom pairing needs fresh contrast and visual review. Transparent backgrounds, images, gradients, overlays, ancestor opacity, filters and arbitrary external CSS are outside this opaque-pair contract. The design gate is not a general CSS-expression or runtime-contrast validator. Do not change only a background and assume the inherited foregrounds remain usable. A replacement profile must supply and verify the complete set.

## Shared components and selector ownership

[`Surface.design_surface/1`](../../../../lib/new_you_web/components/design/surface.ex) is a neutral noninteractive div with a required content slot and `surface` values `plain|canvas|panel|raised`, defaulting to plain. It owns `.ds-surface` and `data-surface`, and rejects class/style, role/tabindex and listed click/key interaction attributes in atom and string forms. Native content retains its source order. The caller may supply ID, ARIA labels and unrelated data metadata. The boundary adds colour only; caller-owned existing layout wrappers supply width, padding and gap. No radius, border, shadow, clipping, z-index, event, state or persistence is introduced.

Here, noninteractive describes the component's own neutral semantics and lack of an interaction API. The guard rejects the enumerated collisions; it does not prohibit every behavior a caller could attach. Other forwarded Phoenix globals, including native event handlers and `phx-*`, remain the caller's responsibility. Do not treat this wrapper as a caller-JavaScript sandbox or add interactive semantics through forwarded attributes. A future interaction contract needs its own explicit component owner.

The existing [card](../../../../lib/new_you_web/components/design/card.ex) owns `data-surface="plain"` for flat and `"raised"` for raised, rejecting caller collisions. Its redundant flat background/body utilities are removed so profile inputs can reach the actual component. Default computed background/body colours stay unchanged; raised directional borders, selected-border radius math and shadow keep their existing owners. No card padding, slot or interaction API changes.

The shared [text link](../../../../lib/new_you_web/components/design/link.ex) uses `.ds-design-link` and `--context-link|link-hover`, preserving native anchor semantics, underline and existing focus dimensions. [design-surfaces.css](../../../../assets/css/design-surfaces.css) supplies scoped heading and opt-in `.ds-context-muted` colours, native link colours, and contextual focus colour. Native inputs and CTA buttons keep their own text/background roles. The context changes their outline colour only, against the surrounding background. No general descendant text-colour reset overrides button labels or field values.

The focus selector uses `:is()` for the finite native-element list. A permanent browser assertion reproduced the initial failure: the old guide selector's element specificity overrode the new `:where()` selector, leaving a blue outline despite a local charcoal focus input. Matching the guide selector's specificity lets the later context rule win. Focus width/offset and instant appearance remain owned by existing rules.

Tailwind still owns the shared layout/type/shape utilities. Contextual colours are consumed by shared CSS rules; there is no new palette utility namespace or enforcement exception. Existing legacy screens are not migrated. This branch's registration pilot receives the shared card boundary and unchanged defaults. Main advanced from `f004ac7` to `79fa504` during this pass through separate sign-in work; its auth/copy changes are not imported or certified here. The shared design-system source seams were not superseded. Later base reconciliation needs fresh integration proof.

## Contrast math and readouts

For opaque browser-resolved sRGB channels, the independent proof uses standard linearization and luminance:

```text
c = channel / 255
linear(c) = c / 12.92                    when c <= 0.04045
linear(c) = ((c + 0.055) / 1.055)^2.4    otherwise
L = 0.2126*R + 0.7152*G + 0.0722*B
ratio = (max(Lforeground, Lbackground) + 0.05) /
        (min(Lforeground, Lbackground) + 0.05)
```

All default heading/body/muted/link/hover roles are tested against 4.5:1, including large headings. Contextual focus colour is tested against its adjacent opaque background at 3:1. These are separate requirements, as described by [WCAG text contrast](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html) and [non-text contrast](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html). Do not round a failing result up to a threshold. This does not certify every focus-appearance, visibility, area or obscuration requirement.

Observed default minimum text contrast is 5.28:1; minimum focus colour is 4.49:1 on the shaded canvas. That focus colour passes its outline threshold but does not meet the small-text threshold. The guide therefore displays focus as an aria-hidden swatch with a readable numeric result, rather than as small coloured label text. A Node regression first failed when the existing text-only grader returned "Large text only" for a focus measurement; the optional focus-kind grading now uses 3:1 without changing ordinary text grading.

[`DesignSystemSurfaces.surface_pairings/1`](../../../../lib/new_you_web/live/design_system_surfaces.ex) adds `/dev/design-system#surface-pairings`. Four actual shared surface components show long internal EN/AF text, links and role readouts. A local canvas comparison uses existing primary links and body ink for muted text, with a nested plain reset. A panel contains the actual flat/raised cards. The isolated preview excludes this lab. Inspectors are open initially so each pairing is visible; native details may still be collapsed. Short bilingual action labels avoid default phone wrapping while paragraphs retain long EN/AF stress content.

The existing [measurement hook](../../../../assets/js/design_system.js) accepts an explicit `data-contrast-background` target. It samples that element's actual opaque background and the probe's computed foreground. Missing targets, translucent backgrounds and image-bearing backgrounds return "Not measured"; the browser regression exercises each case. No ancestor-background search or whole-gradient score is inferred. `data-contrast-kind="focus"` selects only the readout threshold; it does not style a component. The guide's other text-pair readouts retain their default grading.

## Decoration and system fallbacks

Existing gradient/noise/overlay samples remain aria-hidden decoration with their existing canonical limits and no text overlay. The premium CTA remains the separately proven short-shine treatment. Presence in the guide does not promote decorative backgrounds into these opaque profiles.

Without the shipped color-mix enhancements, canvas/panel fall back to existing solid colours and all roles remain usable. The browser proof selects the real fallback declarations through CSSOM; it does not emulate a historical browser. Forced colors explicitly reset the seven outputs to canonical Canvas/CanvasText/LinkText tokens, while the existing raised-card rules remove shadows. Actual keyboard focus remains visible. Reduced-motion proof confirms that boundaries add no animation. No-script server-rendered boundaries retain their colours and semantics; readouts remain "Measured in browser" rather than claiming a result.

## Proof and current limits

The browser contract first failed on the prior guide with `missing surface plain`, before application edits. Pure `mix run --no-start` component tests pass 4/4 without application/database startup. They cover finite/default/invalid profiles, metadata forwarding, visual/interaction collision rejection in both key forms and card ownership. A test-file map-order syntax error was corrected before this observed pass; it was not a product failure. Node contrast tests pass 5/5, including the red-to-green focus-threshold regression.

The [independent shared helper](../../../../test/assets/design_surface_contract.mjs) checks actual content against role probes, opaque defaults, every profile output, root/local edits, production card propagation, sibling isolation, contaminated parent-output resets, local primitive recomputation and named-profile inheritance. It stresses open readouts, exact doubled EN/AF text and 240px allocation. The [dedicated Chrome runner](../../../../test/assets/design_surfaces_browser.mjs) passes 2,315 assertions across five viewport widths from 320px through 1920px, native hover/keyboard/local focus, rejected measurements, forced colours, actual solid fallbacks, reduced motion and no-script behavior.

The compatibility runner includes these helpers alongside existing type/layout/content/border/registration proof in both engines. The final checkpoint passes 19,532 assertions each in Chrome 155 and Firefox 160, retaining two Firefox DEV reload diagnostics. Final source outcomes are recorded in PR/Plane. Existing lighting, component and border regressions retain their baseline passes and CTA painted-label contrast. The supported seven-file Hallmark guide render reports zero FAIL/open REFLEX/rejected waivers, two existing waivers and the retained gradient-endpoint WARN. Initial guide REFLEX findings were resolved by short bilingual link labels and initially visible inspectors; no waiver was added or lint rule weakened. Registration/Tidewave's inherited findings remain open, so overall Hallmark certification is not claimed.

WebKit, true browser zoom, screen readers, Firefox media emulation and comprehensive focus-appearance certification remain unverified. WELL-114 certification, branch conflicts, hosted CI and independent Master Gate/resulting-main proof remain open. The owner's continuation exception authorizes UI work, not integration.

WELL-125 explicitly released TEST at 2026-11-15 21:14:14 UTC. The owner then granted WELL-112 the next TEST and separate PLT/deep windows. The reservation was recorded on WELL-112 and WELL-125 before any new database command. Activation, source-bound focused/canonical/deep outcomes and explicit releases will be recorded in Plane and the PR. Previous Pass 3 canonical proof belongs to its recorded source and is not reused for these changes. No reset or manual cleanup is authorized.

Repeatable non-DB commands with existing DEV on 4237 and externally installed browser tooling:

```sh
NEW_YOU_PORT=4237 ERL_FLAGS='+S 4:4' mise exec -- devcore-project run dev -- mix assets.build
NEW_YOU_PORT=4237 ERL_FLAGS='+S 4:4' mise exec -- devcore-project run dev -- mix compile --warnings-as-errors
NEW_YOU_PORT=4237 ERL_FLAGS='+S 4:4' mise exec -- devcore-project run dev -- mix design.check
NEW_YOU_PORT=4237 ERL_FLAGS='+S 4:4' mise exec -- devcore-project run dev -- mix check.architecture
NEW_YOU_PORT=4237 ERL_FLAGS='+S 4:4' mise exec -- devcore-project run dev -- mix run --no-start -e 'ExUnit.start(); Code.require_file("test/new_you_web/design_surface_test.exs")'
node --test test/assets/design_system_test.mjs
BROWSER_TOOLS_ROOT=/tmp/newyou-refinement-tools node test/assets/design_surfaces_browser.mjs
BROWSER_TOOLS_ROOT=/tmp/newyou-refinement-tools node test/assets/design_lighting_browser.mjs
BROWSER_TOOLS_ROOT=/tmp/newyou-refinement-tools DESIGN_BROWSER=chrome node test/assets/design_compatibility_browser.mjs
BROWSER_TOOLS_ROOT=/tmp/newyou-refinement-tools DESIGN_BROWSER=firefox FIREFOX_PATH=/snap/bin/firefox FIREFOX_PROFILE_ROOT="$HOME/snap/firefox/common" node test/assets/design_compatibility_browser.mjs
HALLMARK_PUPPETEER=/tmp/newyou-refinement-tools CHROME_PATH=/usr/bin/google-chrome node /home/jcschoeman96/.agents/skills/hallmark/scripts/sloplint.mjs assets/css/design-tokens.css assets/css/design-system.css assets/css/design-typography.css assets/css/design-components.css assets/css/design-content.css assets/css/design-borders.css assets/css/design-surfaces.css --scope app --genre modern-minimal --url http://127.0.0.1:4237/dev/design-system --json
```

Documentation impact: this presentation component/profile contract adds no Domain, durable schema, business interface or meaningful lifecycle. A separate semantic capability map is exempt. This source-linked note, the developer guide and generated PR history document its supported API and proof limits.

## Final implementation-source proof and handoff

The tested implementation is `c00b2f0a463bf4bf9cdaa43c709b066c740d4bd1`. The complete 23-file pass delta from `2267fce3321335eb1ee8579fdf93f6b13bcdca93` was inspected. Later proof/history changes are limited to documentation and do not claim a separate canonical run on their commit. Current PR base metadata remains `a3d7e2e2ac11c3b7ecdd6610e40e1328c226b216`; separately integrated main is `79fa504a58bbe9bc350627a03cc61d9e614c1142`. No base merge or conflict repair is included.

WELL-125 released TEST at 21:14:14 UTC. The owner granted WELL-112 the next TEST window and separate PLT/deep window. TEST activation was recorded at 21:17:21 UTC, before doctor/focused checks. Canonical started at 21:17:46 UTC on unchanged source. PLT/deep activation followed the canonical pass. Both windows were explicitly released at 21:23:36 UTC on WELL-112, WELL-125 and WELL-134. Release comment IDs are `e1e15209-ab6c-4f2b-a546-a911ca2bc2b7`, `99bf8be3-c995-41a8-83cf-9e7453c369d9` and `6e1a169c-e9eb-431b-beb4-8dc1b9e7e54c`. No DB-backed command, Dialyzer or shared PLT preparation remains running/reserved. No reset, manual cleanup or source workaround occurred. Future use requires fresh coordination.

```sh
ERL_FLAGS='+S 4:4' mise exec -- devcore-project doctor
ERL_FLAGS='+S 4:4' mise exec -- devcore-project run test -- mix test test/new_you_web/design_component_contracts_test.exs test/new_you_web/live/design_system_live_test.exs test/new_you_web/design_system_infrastructure_test.exs test/new_you_web/design_field_test.exs test/new_you_web/design_surface_test.exs
ERL_FLAGS='+S 4:4' mise exec -- devcore-project run test -- mix check
ERL_FLAGS='+S 4:4' mise exec -- devcore-project run test -- mix check.deep
```

Doctor passed. Focused tests exited 0 with 61/61 passing, seed 557523, in 0.7 seconds. Canonical exited 0 with 666/666 passing, seed 988176, in 314.0 seconds. Deep exited 0 with zero errors/skips in 12.63 seconds. Logs are `/tmp/newyou-surfaces-doctor.log`, `/tmp/newyou-surfaces-focused.log`, `/tmp/newyou-surfaces-check.log` and `/tmp/newyou-surfaces-deep.log`. Canonical retains 25 error-level request/connection diagnostics and zero test-failure headings. This pass does not establish an error-free runtime or replace independently bound resulting-main proof.

Final browser logs confirm 2,315 dedicated surface assertions and 19,532 compatibility assertions in each engine. Existing component/border proof passes 51/322 assertions; the painted CTA measurements above remain unchanged. Supported guide Hallmark, assets, warnings-as-errors compile, format, design/architecture, Node and pure component checks passed as described above. The 54 routing/smoke tests passed. All 13 local links in this note resolve, its code fences balance, and six cited ACSS file hashes match the inspected archive. Desktop/phone/nested screenshots were inspected. WebKit, true zoom, screen readers, Firefox media emulation and the inherited DEV diagnostics remain outside verified coverage.

Independent source review inspected the exact committed delta and raised one P2 interpretation: forwarding globals such as `onmouseover`, `onfocus` and `phx-hook` might contradict "noninteractive". A second bounded independent adjudication checked the approved plan, enumerated guards/tests and installed Phoenix global-attribute behavior. It found no demonstrated accepted-contract violation and recommended clarifying the wording. The explicit limit above resolves that ambiguity without broadening the API or changing application source. Neither review reran runtime/TEST gates or supplied Master Gate certification. No other functional defect was confirmed by those source reviews.

Author self-assessment, IMPLEMENTATION / WELL-112 Pass 4: local criteria 1 through 6 in the [plan](../../../superpowers/plans/2026-11-15-surface-pairings.md) are covered by the documented contracts, source review and observed local checks. Integration certification is outside that local 6/6 count and remains blocked. Requirements 4/4 + observed verification 2/3 + correctness/architecture 2/2 + handoff 1/1 give raw 9/10, capped at Implementation Score 5/10 for inherited required-check/dependency gaps. Confidence Score is 90% for the bounded implementation, with integration and excluded browser/assistive-technology behavior uncertain. Verification Status is BLOCKED for overall delivery; NOT_VERIFIED_FOR_MERGE.

The verification deduction reflects missing exact-head hosted CI and unresolved overall Hallmark proof. Reaching 8+/10 requires the responsible independent reviewer to close WELL-114's post-merge certification, disposition the inherited Hallmark findings, reconcile the branch against current main, then obtain fresh required CI, Master Gate and resulting-main proof. These points are not awarded for planned checks. The next UI pass is bounded shared native-form contracts; this handoff does not start it, release participants or authorize integration.
