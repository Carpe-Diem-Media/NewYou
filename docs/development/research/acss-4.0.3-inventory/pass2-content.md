# Next pass 2: contextual card spacing and scoped prose

WELL-112 / draft [PR #227](https://github.com/Carpe-Diem-Media/NewYou/pull/227), continuing from `86ba37300a95f7087e87ab0260fad51902aca55f`. This implements Pass 2 of the [next-pass roadmap](next-passes.md), extending [Phase 5](phase5-content.md) and preserving [candidate typography](pass1-typography.md). Exact-head delivery evidence and execution state belong in PR/Plane. Presence in the guide is not visual approval or participant release.

## Research decision

Adapt contextual spacing and narrowly scoped smart spacing. The existing [Phase 5 source findings](phase5-content.md#source-findings-and-decisions) bind the supplied ACSS 4.0.3 archive, hashes and selectors. Relevant vendor locators are `assets/scss/modules/spacing/_tokens.scss:1-32`, `modules/spacing/_vars.scss:32-48`, and `modules/spacing/smart-spacing/_mixins.scss:3-121`. The earlier implementation deliberately deferred figures/captions and card roles; this continuation fills those bounded gaps. It introduces no vendor source, WordPress/Sass runtime, global margin reset, arbitrary-wrapper interpreter or `gap: 0 !important` rule.

NewYou keeps the approved static scale. This pass does not add a fluid section multiplier, new spacing scale, media/crop framework or site-wide migration. The existing production typography, palette, radius tiers and premium lit-primary shine remain intact.

## Role ownership and formulas

Edit [design-tokens.css](../../../../assets/css/design-tokens.css). Existing roles remain `--content-gap: var(--space-lg)`, `--section-space: var(--space-2xl)` and `--control-gap: var(--space-base)`. New roles are:

- `--card-content-gap: var(--space-base)`, initially 16px. The actual shared card's `gap-design-card-content` owns gaps between its direct regions.
- `--card-action-gap: var(--space-base)`, initially 16px. The card's wrapping action row uses `gap-design-card-action` between actions and action rows.

The corresponding Tailwind theme variables are `--spacing-design-card-content` and `--spacing-design-card-action`. They reference semantic roles at the consuming element through the existing inline theme. Existing values are retained. No independent value is authored in Elixir or JavaScript.

For a card with content gap C, action gap A and available free block space E:

```text
ordinary direct-region separation = C
minimum separation before actions = C
extra space before actions = max(0, E), through margin-block-start: auto
between/wrapped action separation = A
```

The action row stays at the inner bottom of a stretched card. A screenshot or measurement can therefore show more than C before it. Padding remains `--design-card-padding-inline|block` with the existing 24px fallbacks. Inset radius remains `max(0px, outer-radius - border - per-axis-padding)` independently on each axis. C and A never enter that calculation. Prose inside the card body still owns paragraph margins through its own explicit `.ds-prose` wrapper; card gap does not style arbitrary body descendants.

Root edits update shared cards throughout the site, including the existing registration card, while preserving the initial geometry. Local overrides set `--card-content-gap` or `--card-action-gap` on a canonical CSS context. A local primitive edit does not automatically rebind an inherited root alias. Keep content, section, control, card and padding roles separate unless the actual consumer deliberately couples them.

`#content-card-local` demonstrates C=8px and A=24px using existing scale tokens. Its sibling remains at 16px/16px. This is an internal comparison, not a new global default or variant API. The semantic role itself is the local override; no new data attribute is needed.

## Figure and caption contract

[design-content.css](../../../../assets/css/design-content.css) adds native `figure` and `figcaption` to the existing scoped normalization. Figures have zero inline margins. Supported block descendants keep zero initial block margins; direct adjacent blocks retain the existing prose flow. The figure's first child starts without a leading margin, and its last child has no trailing margin.

```text
F = --prose-flow-space, falling back to --content-gap
K = --prose-caption-space, falling back to --space-sm
preceding outer block to figure = F
figure block to next block = F
figure child to following figcaption = K
```

K is initially 8px. The optional input remains unset at root and `--design-prose-caption-gap` resolves on each `.ds-prose` scope. Override `--prose-caption-space` at that boundary, not on an arbitrary descendant after the derived token has already resolved. Use finite nonnegative compatible lengths; zero is supported. Percentages, negative gaps and incompatible expressions are outside the recipe. The numeric source gate is not a general runtime CSS validator.

Captions use the existing caption size, unitless leading, tracking and body font. No italic, new color or attribution styling is introduced. The specimens are self-contained internal quotations with explanatory captions, not invented testimonials. Figure content stays in source order, and captions remain associated through native HTML. This contract supports the demonstrated block content and phrasing captions. It does not promise image aspect ratios, intrinsic dimensions, crop behavior, arbitrary media, sanitization or rich-text parsing.

## Nested content and margin ownership

Lists retain their smaller list-item rhythm. Quotations retain the surrounding paragraph flow. To give a nested content scope different spacing, use an explicit nested `.ds-prose` inside a neutral outer flow wrapper:

```html
<article class="ds-prose">
  <p>Outer content</p>
  <div>
    <section class="ds-prose" aria-labelledby="nested-heading">
      <h3 id="nested-heading">Nested content</h3>
      <p>First paragraph</p>
      <p>Second paragraph</p>
    </section>
  </div>
  <p>Outer content resumes</p>
</article>
```

Put the local flow input on the nested `.ds-prose` through canonical CSS. The outer prose assigns a margin to the neutral wrapper using its own inputs; the inner scope assigns margins to its own children. The first and last child remain flush inside each scope. Plain wrappers do not automatically receive an internal flow recipe. Keep form controls outside prose and do not also apply a stack/grid gap recipe to the prose container.

Browser proof caught why the wrapper matters: a directly nested `.ds-prose` with a local 8px flow also resolved its own outer margin to 8px instead of the parent's 24px. Custom properties in a margin resolve on that child. The neutral wrapper now retains 24px before the scope, the scope starts at 0px inside it, and its paragraph gap is 8px. Changing the outer flow to 40px leaves the inner paragraph gap at 8px. Direct nesting without local flow changes remains usable; independent outer/inner spacing requires the wrapper. No unsupported claim about arbitrary wrappers is made.

## Guide and actual consumers

[`DesignSystemContent.content_recipes/1`](../../../../lib/new_you_web/live/design_system_content.ex) extends `/dev/design-system#content` with five root role readouts, long EN/AF quotation figures, native captions, explicit nested flow frames, and actual shared card/action comparisons. `#prose-local` also shows a 4px caption gap using an existing scale value. The guide preview excludes this lab. No event, route, persistence or JS sizing engine is added.

The existing registration pilot already consumes the shared card and Phase 5 content/section/control/prose/divider recipes. Default card geometry and registration copy, controls, transport and release gates remain unchanged. No action slot is added to that page just to demonstrate a token.

The router and actual templates were inspected for the later Pass 6 content consumer. The root page remains the legacy Phoenix starter composition. Registration, sign-in/reset/verification templates are forms or short outcomes. The legal routes serve exact hash-checked development artifacts. This branch has no eligible standalone rich-content page with approved EN/AF content to migrate. Record this prerequisite for bounded adoption rather than inventing a page or adding wrappers/CSS to legal response bodies. Current main's additional sign-in work does not authorize expanding this pass.

## Proof and limits

Two new ExUnit source/guide contracts failed before implementation. The first focused set then passed 55 tests. The owner subsequently required exclusive shared TEST coordination. WELL-125 reported its quiet run complete and explicitly released to the next WELL-134 window; WELL-112 will run no further DB-backed check until coordination and explicit release. No active command was interrupted, and no reset or cleanup was performed. Exact-head fast-gate status must stay unverified for this continuation until its own coordinated run. The earlier typography failure remains recorded, including the owner's report of overlapping TEST runs; overlap does not prove the sole cause.

[`design_content_contract.mjs`](../../../../test/assets/design_content_contract.mjs) provides independent computed geometry and cascade checks imported by both engines. It covers root/local card roles, zero gaps, padding/border/outer and per-axis inset-radius preservation, action bottom alignment/wrapping, control/prose isolation, figures/captions, explicit nesting and sibling isolation. An initial Firefox check incorrectly compared an inline anchor's nonzero scroll width with its zero client width. Diagnostics established that measurement mismatch; inline checks now compare actual line fragments with their containing box, while block boxes retain scroll/client overflow checks.

[`design_content_browser.mjs`](../../../../test/assets/design_content_browser.mjs) stresses the actual new figures/nested content with approved and candidate typography, exact doubled text, long EN/AF labels, user paragraph/line/letter/word spacing, five viewport widths and a 240px parent. It retains native keyboard links, no-script content, forced colors and registration geometry/token checks without POSTs. The compatibility runner checks both geometry and exact doubled/long text, current/candidate typography, user text spacing and 240px allocation at 320/744/1440px in Chrome and Firefox, alongside the existing typography/fallback/layout/registration coverage. CSSOM path selection is not historical-browser simulation. WebKit, true browser zoom, screen readers and Firefox media emulation remain outside this proof.

Observed source-checkpoint proof passes 185 dedicated Chrome content assertions and 18,083 compatibility assertions in each of Chrome 155 and Firefox 160. The five-file guide Hallmark run has zero FAIL/open REFLEX/rejected waivers, two existing waivers and one retained CTA endpoint WARN. Compilation, format, design and architecture checks pass; static Dialyxir passes with zero errors/skips in 12.41 seconds. The first DEV architecture invocation rejected a missing worktree port; the corrected explicit 4237 invocation passes. The 54 Python routing/smoke tests and local Markdown links/fences pass. Desktop card/figure and phone captures were inspected. These observations do not replace pending exact-head canonical TEST proof.

Repeatable non-TEST/browser commands, with the existing DEV server on 4237 and external browser tooling already installed:

```sh
ERL_FLAGS='+S 4:4' mise exec -- devcore-project run dev -- mix assets.build
ERL_FLAGS='+S 4:4' mise exec -- devcore-project run dev -- mix design.check
NEW_YOU_PORT=4237 ERL_FLAGS='+S 4:4' mise exec -- devcore-project run dev -- mix check.architecture
BROWSER_TOOLS_ROOT=/tmp/newyou-refinement-tools node test/assets/design_content_browser.mjs
BROWSER_TOOLS_ROOT=/tmp/newyou-refinement-tools DESIGN_BROWSER=chrome node test/assets/design_compatibility_browser.mjs
BROWSER_TOOLS_ROOT=/tmp/newyou-refinement-tools DESIGN_BROWSER=firefox FIREFOX_PATH=/snap/bin/firefox FIREFOX_PROFILE_ROOT="$HOME/snap/firefox/common" node test/assets/design_compatibility_browser.mjs
HALLMARK_PUPPETEER=/tmp/newyou-refinement-tools CHROME_PATH=/usr/bin/google-chrome node /home/jcschoeman96/.agents/skills/hallmark/scripts/sloplint.mjs assets/css/design-tokens.css assets/css/design-system.css assets/css/design-typography.css assets/css/design-components.css assets/css/design-content.css --scope app --genre modern-minimal --url http://127.0.0.1:4237/dev/design-system --json
```

Run DB-backed TEST ExUnit and the canonical fast gate only within the coordinated window. Dialyxir was inspected to confirm its compile/static-analysis task does not start the application; the deep check can run without database access. Final exact-head commands, counts and failures belong in PR/Plane. Supported guide Hallmark findings must distinguish new findings from the retained CTA endpoint WARN and existing waivers. Registration/Tidewave findings, WELL-114 certification, current-main conflicts, hosted CI and independent Master Gate remain separate open delivery work. No guide result closes them.

Documentation impact: presentation-only tokens, classes and internal specimens introduce no Domain, schema, business interface or meaningful lifecycle. A new semantic capability map is exempt. This source-linked addendum, the developer guide and generated PR history describe the extension.
