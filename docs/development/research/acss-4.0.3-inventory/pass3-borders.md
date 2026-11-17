# Next pass 3: border purposes and divider ownership

WELL-112 / draft [PR #227](https://github.com/Carpe-Diem-Media/NewYou/pull/227), continuing from `84ec925ecace26b6f19be756ded71752de037436`. This implements the bounded border pass in the [next-pass roadmap](next-passes.md). It preserves the approved palette, shapes, production typography and premium lit-primary treatment. Current delivery and shared-resource reservations remain in Plane. This note does not close WELL-114 or certify integration.

## Research decision and source

Adapt purpose-owned borders and local divider relationships. The supplied ACSS archive is fixed by the identity and source hashes in [Phase 5](phase5-content.md#source-findings-and-decisions). Relevant vendor locators, relative to `automatic-css/assets/scss/`, are `modules/dividers/_vars.scss:1-18`, `_tokens.scss:3-16` and `_classes.scss:3-58`. The [component findings](phase3-components.md) already cover radius and elevation decisions. This pass extends NewYou's independent border-box recipe, without copying vendor code or adding Sass, WordPress, pseudo-element separators, another shadow ladder or global auto-radius selectors.

## Canonical inputs and consumers

Edit [design-tokens.css](../../../../assets/css/design-tokens.css). Existing `--design-border-width: 1px` remains the shared fallback. Optional purpose inputs are deliberately unset by default so a local legacy base-width override can still work. Add a purpose input once at root to change every appropriate consumer, or in an approved canonical CSS context to change a bounded component.

- `--border-decorative-width`, `--border-decorative-style`, `--border-decorative-color` select the flat card's border. Defaults are the existing base width, solid style and `--hairline`.
- `--border-control-width`, `--border-control-style`, `--border-control-color` select shared text/email/password field boundaries. Defaults are the existing base width, solid style and stronger `--ink-meta`.
- `--border-separator-width`, `--border-separator-style`, `--border-separator-color` select native `.ds-divider` and decorative `.ds-divided` boundaries. Defaults are the existing base width, solid style and `--hairline`. Existing local `--divider-width`, `--divider-style` and `--divider-color` take precedence over the corresponding purpose input.
- `--border-lit-width` and `--border-lit-style` select lit buttons, raised cards and boxed icons. Defaults retain the existing base width and solid style. Their directional colours remain the existing `--edge-*` and action edge relationships. A generic lit-colour override would discard that direction, so it is not added.

Use finite nonnegative compatible lengths for decorative/separator widths and divider gaps. Keep a visible positive control/lit boundary when the component needs one. Supported styles are solid, dashed and dotted; styles such as none/hidden do not belong to the inset-radius contract because their used border width differs from the selected length. Colours must remain approved role references and need contrast review for their actual purpose. Percentage widths, negative lengths and incompatible expressions are outside this contract. The numeric source gate is not a runtime validator for arbitrary optional CSS.

Derived `--border-decorative`, `--border-control` and `--border-separator` shorthands resolve at root for readouts and again at their actual consumer. They are outputs, not edit points. Editing only an inherited shorthand cannot replace a consumer's own derivation. Optional inputs, including ancestor-scoped inputs, are the supported way to change these relationships.

The existing Tailwind utilities continue to own typography, spacing, layout and focus. CSS component rules consume the border outputs directly. The card no longer also emits the Tailwind `border` and flat colour utility, which would otherwise compete with purpose width/style/colour. No second palette namespace or utility framework is introduced. Component-owned `data-variant` and `data-treatment` retain their finite existing meanings; border width is a token input, not a new data attribute.

Actual consumers are the shared [card](../../../../lib/new_you_web/components/design/card.ex), [field](../../../../lib/new_you_web/components/design/field.ex), [button](../../../../lib/new_you_web/components/design/button.ex) and [icon](../../../../lib/new_you_web/components/design/icon.ex), styled by [design-components.css](../../../../assets/css/design-components.css). The registration pilot uses the same card, fields and lit primary. Its copy, native controls and transport are unchanged. Legacy page hairlines, secondary flat action boundaries and the error-text marker retain their existing owners. This pass does not claim a site-wide legacy migration.

## Calculations and override precedence

```text
decorative width = purpose decorative width, otherwise shared base width
control width    = purpose control width, otherwise shared base width
invalid width    = 2 * selected control width
separator width  = local divider width, otherwise purpose separator width, otherwise base
lit width        = purpose lit width, otherwise shared base width
card width       = decorative width for flat; lit width for raised
inset radius x   = max(0px, outer radius - card width - inline padding)
inset radius y   = max(0px, outer radius - card width - block padding)
```

`--design-control-invalid-width`, `--design-lit-border-width`, `--design-lit-border-style`, `--design-icon-border` and `--design-card-border-width` are local derived outputs. Raised cards select their lit width before the inset calculations resolve. A 32px outer radius, 3px lit border, 8px inline padding and 12px block padding therefore produce 21px/17px inset radii. The flat sibling with a 1px decorative border produces 23px/19px. Padding larger than the remaining radius still clamps at zero. This corrects the new unequal-purpose case without changing default geometry or legacy local base-width overrides.

Invalid state doubles only the selected field boundary. The existing 2px focus outline and 2px offset remain separate and can appear with an invalid boundary. Errors remain associated through `aria-describedby`, with `aria-invalid` on the native input. A decorative hairline does not identify an interactive control. The default authored field boundary measures 6.25:1 against its white input background in the observed browser. [WCAG non-text contrast](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html) applies its 3:1 threshold to visual information needed to identify active controls and states, not indiscriminately to decorative lines. Changing the boundary or its adjacent background requires measuring the new pairing.

## Native separators and nested groups

[design-content.css](../../../../assets/css/design-content.css) retains the existing recipes. A native `.ds-divider` hr has one block-start border and no own margin; the containing stack or prose owns separation. Use hr for a thematic change, consistent with [MDN's native hr semantics](https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/hr). Decorative `.ds-divided` groups use real borders without extra separator announcements.

```text
d = local --divider-gap, otherwise --content-gap / 2
b = selected separator width
group gap = 0
following direct child's margin = d
following direct child's top border = b
following direct child's padding = d
previous border-box bottom to following content start = 2*d + b
```

The final equation assumes that the following child's first content has no additional margin/padding. The recipe does not reset arbitrary descendants. Default outer d=12px and b=1px give 25px; inner d=8px gives 17px. Root content gap 40px changes the outer distance to 41px while the explicit inner distance stays 17px. A local inner d=0 leaves only its border thickness.

When an inner group has local gap or width inputs, wrap it in a neutral direct child of the outer `.ds-divided`. The outer boundary resolves on that frame, and the inner group resolves its own child boundaries. Direct nesting lets the child's local values also affect the boundary assigned to that child by the outer selector. The guide demonstrates the frame rather than adding a general wrapper interpreter. Keep one spacing owner per group.

The first rendered specimen check measured 41px instead of the intended 17px. Computed-style diagnostics showed that the inner margin and padding were already 8px each; the guide's `.ds-note` added another 24px paragraph margin. A guide-only reset now removes note margins inside these layout examples. The shared divider recipe did not need changing. The regression measures actual content geometry so this extra spacing cannot silently return.

## Guide and native states

[`DesignSystemBorders.border_contracts/1`](../../../../lib/new_you_web/live/design_system_borders.ex) adds `/dev/design-system#borders`, after content rhythm. It renders the actual shared components, root shorthand readouts, actual measured widths, default/local native hr, a nested decorative EN/AF group and enabled/pending lit-primary comparisons. [design-borders.css](../../../../assets/css/design-borders.css) supplies guide layout only. Local specimen inputs remain in canonical CSS. The isolated preview excludes this lab.

The pending comparison uses the same label, native disabled and `aria-busy="true"`. The caller still owns state and localized copy. Aria-busy alone does not disable a control. This is a comparison of existing native behavior, not a loading controller or a new LiveView lifecycle. Existing interaction regression covers the production button. The upper 12px shine, gradient colours, light top/darker bottom border, hover treatment, pressed inversion and inward shadow remain unchanged. Disabled removes the cast shadow. Forced colours remove decoration and retain system boundaries and focus. No animation, overlay or extra stacking context is added.

## Proof and limits

The browser contract first failed on the unmodified guide with `missing root border role decorative`, before application edits. The new [independent helper](../../../../test/assets/design_border_contract.mjs) verifies purpose defaults, root/local propagation and sibling isolation, legacy width compatibility, invalid thickness, actual selected card radii and nested divider geometry. It also exercises exact doubled long EN/AF text and a 240px component allocation. Both engines run it through the existing [compatibility runner](../../../../test/assets/design_compatibility_browser.mjs) at 320/744/1440px alongside the existing type, layout, content and shipped fallback proof.

The [dedicated Chrome runner](../../../../test/assets/design_borders_browser.mjs) covers computed guide readouts, native focus/order, pending dimensions, hover/press, disabled shadow, reduced motion, forced colours, no-script markup and field-boundary contrast. Repeated CDP viewport emulation cleared Chromium's pointer/hover capability; a fresh desktop page now separates actual pointer proof from responsive measurements and asserts the hover capability before testing it. No application hover rule was changed to accommodate the test.

Observed pre-handoff checks pass 322 dedicated border assertions and 18,383 compatibility assertions in Chrome 155 and Firefox 160, plus 51 existing component-contract assertions. The existing [lighting regression](../../../../test/assets/design_lighting_browser.mjs) still measures painted CTA label regions at 5.32:1 rest, 9.41:1 hover/press and 5.31:1 for wrapped doubled text. The supported six-file Hallmark guide render reports zero FAIL/open REFLEX/rejected waivers, two existing waivers and the retained 3.97:1 gradient-endpoint WARN. That endpoint sits above the label; it is not substituted for the painted label-region measurement. Registration/Tidewave's inherited findings remain open, so this is not overall Hallmark certification.

Compile, assets, token and architecture checks pass at the source checkpoint. TEST/deep initially waited for fresh coordination after WELL-134 released its windows. The owner subsequently granted both windows; final-source outcomes and release are recorded below. Previous 660/660 proof belongs to `84ec925` and is not reused for these changes. No resets or manual cleanup were authorized or performed.

Repeat with the existing DEV server on 4237 and external browser tooling already installed:

```sh
NEW_YOU_PORT=4237 ERL_FLAGS='+S 4:4' mise exec -- devcore-project run dev -- mix assets.build
NEW_YOU_PORT=4237 ERL_FLAGS='+S 4:4' mise exec -- devcore-project run dev -- mix design.check
NEW_YOU_PORT=4237 ERL_FLAGS='+S 4:4' mise exec -- devcore-project run dev -- mix check.architecture
BROWSER_TOOLS_ROOT=/tmp/newyou-refinement-tools node test/assets/design_borders_browser.mjs
BROWSER_TOOLS_ROOT=/tmp/newyou-refinement-tools node test/assets/design_lighting_browser.mjs
BROWSER_TOOLS_ROOT=/tmp/newyou-refinement-tools node test/assets/design_component_contracts_browser.mjs
BROWSER_TOOLS_ROOT=/tmp/newyou-refinement-tools DESIGN_BROWSER=chrome node test/assets/design_compatibility_browser.mjs
BROWSER_TOOLS_ROOT=/tmp/newyou-refinement-tools DESIGN_BROWSER=firefox FIREFOX_PATH=/snap/bin/firefox FIREFOX_PROFILE_ROOT="$HOME/snap/firefox/common" node test/assets/design_compatibility_browser.mjs
HALLMARK_PUPPETEER=/tmp/newyou-refinement-tools CHROME_PATH=/usr/bin/google-chrome node /home/jcschoeman96/.agents/skills/hallmark/scripts/sloplint.mjs assets/css/design-tokens.css assets/css/design-system.css assets/css/design-typography.css assets/css/design-components.css assets/css/design-content.css assets/css/design-borders.css --scope app --genre modern-minimal --url http://127.0.0.1:4237/dev/design-system --json
```

WebKit, true browser zoom, screen readers and Firefox media-feature emulation remain unverified. The first compatibility run retained four unresolved Firefox DEV reload diagnostics; the final source run retained two. Neither count is treated as a resolved runtime defect. Current-main conflicts, exact-head hosted CI, independent Master Gate and WELL-114 resulting-main certification remain separate delivery gaps. No merge recommendation, participant release or Plane Done follows from this pass.

Documentation impact: these presentation tokens, component CSS and internal specimens add no Domain/schema/business-interface/lifecycle contract. A new semantic capability map is exempt; this source-linked note, the developer guide and generated PR history document the extension.


## Final implementation-source proof and handoff

Implementation source is `a58fd9bcaf55750f02619ff49c907b7b1cf1cce7`. The owner explicitly granted the next exclusive TEST and separate PLT/deep windows. Activation was recorded at 2026-11-15 20:34:24 UTC on WELL-112, WELL-134 and WELL-125. DevCore doctor passed; source remained unchanged throughout sequential focused, canonical and deep commands:

```sh
ERL_FLAGS='+S 4:4' mise exec -- devcore-project run test -- mix test test/new_you_web/design_component_contracts_test.exs test/new_you_web/live/design_system_live_test.exs test/new_you_web/design_system_infrastructure_test.exs test/new_you_web/design_field_test.exs
ERL_FLAGS='+S 4:4' mise exec -- devcore-project run test -- mix check
ERL_FLAGS='+S 4:4' mise exec -- devcore-project run test -- mix check.deep
```

Focused tests exited 0 with 56/56 passing, seed 729072, 0.6 seconds. Canonical started 20:34:55 UTC and exited 0 with 661/661 passing, seed 474420, 318.6 seconds. Deep exited 0 with zero errors/skips in 11.92 seconds. Logs are `/tmp/newyou-borders-focused.log`, `/tmp/newyou-borders-check.log` and `/tmp/newyou-borders-deep.log`. Canonical has zero test-failure headings and retains 25 error-level diagnostic lines, including request and Postgrex connection diagnostics. A passing suite does not establish an error-free runtime, and no exception dumps or record values are repeated here.

Both windows were explicitly released at 20:40:38 UTC. Release comments are WELL-112 `b0e4e211-2cff-45c1-a5d1-db7385929b2a`, WELL-134 `0b9b0698-0ee1-49e3-865f-9145839d208f` and WELL-125 `8a0ca528-96dd-41b0-a959-8b69a12be38b`. No DB-backed command, Dialyzer, PLT/core preparation remains running or reserved. No reset, manual cleanup, role/service/credential change, source workaround or shared-core warmth claim occurred. Future DB/PLT use requires fresh coordination.

Dedicated border proof passes 322 assertions. The final compatibility run passes 18,383 assertions in each observed engine, Chrome 155.0.8059.84 and Firefox 160.0, retaining two Firefox DEV reload diagnostics. Existing component proof passes 51 assertions; the existing lighting proof retains the measured contrast above. Six-target guide Hallmark reports zero FAIL/open REFLEX/rejected waivers, two existing waivers and one endpoint WARN. Asset build, compile with warnings-as-errors, format, design enforcement, architecture, 54 routing/smoke tests, whitespace and 17 local documentation links/fences pass. Desktop/phone guide and divider/action captures were inspected. Independent bounded review of the complete 18-file `84ec925` to `a58fd9b` delta found no actionable functional defects. That source review did not rerun runtime/TEST checks or provide Master Gate certification. Subsequent proof/history commits change documentation only.

Author self-assessment, IMPLEMENTATION / WELL-112 Pass 3: local criteria 1–6 in the implementation plan are covered by the source, documented contracts and observed checks above. Delivery certification is outside that local 6/6 count and remains blocked. Requirements 4/4 + observed verification 2/3 + correctness/architecture 2/2 + documentation 1/1 give raw 9/10, capped at Implementation Score 5/10 for inherited mandatory-check/dependency gaps. Confidence Score is 90% for the bounded implementation, with integration and excluded browser/assistive-technology behavior still uncertain. Verification Status is BLOCKED for overall delivery; NOT_VERIFIED_FOR_MERGE.

The verification deduction reflects unavailable exact-head hosted CI and unresolved overall Hallmark proof, not a failed new local border assertion. Reaching 8+/10 delivery evidence requires the responsible independent reviewer to close WELL-114's post-merge certification, disposition the inherited Hallmark gap, reconcile the branch against current main, and obtain fresh required CI and Master Gate/resulting-main proof. None is pre-awarded by the local pass. The owner-authorized UI continuation remains separate from integration authority. The next planned UI batch is surface/foreground pairings; no new palette adoption or dependent merge is authorized by this handoff.
