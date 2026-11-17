# Phase 5 contextual spacing, prose and dividers

The later [Pass 2 continuation](pass2-content.md) extends this baseline with card content/action roles, figure/caption flow and explicit nested spacing boundaries. The recorded Phase 5 evidence below retains its original scope and revision.

WELL-112 / draft PR [#227](https://github.com/Carpe-Diem-Media/NewYou/pull/227), continuing from `9c95f8cc0e68a8597d5a5451a53ad22af66117aa`. The owner accepted the recommended contextual-spacing, scoped-prose and divider batch. This addendum describes independently implemented CSS relationships and their bounded consumers. It does not import ACSS, add Sass or promote a participant journey.

The [Phase 1 inventory](README.md), [Phase 2 layouts](phase2-layouts.md), [Phase 3 component contracts](phase3-components.md) and [Phase 4 registration proof](phase4-registration.md) retain their recorded source baselines and proof limits. No vendor code or asset is copied, compiled or executed. Direct vendor-source reuse terms remain unresolved in the earlier research.

## Source findings and decisions

Archive identity remains SHA-256 `17ee65acfd7e045e73b68f2373a2e4fba5e46ab3fd22ec5cc451472a7f5d63b5`, supplied Automatic.css 4.0.3. Vendor paths below are archive locators relative to `automatic-css/assets/scss/`, not repository paths. The archive has no configured compiled frontend CSS, so declarations and gates do not prove deployed vendor output.

- **Adapt contextual spacing.** `modules/spacing/_tokens.scss:1-32` separately gates default section styles, standard spacing, section spacing and contextual token output. `modules/spacing/_vars.scss:32-48` multiplies each mobile/desktop spacing endpoint by its corresponding section factor before interpolation. NewYou retains its approved static values for this batch. Three semantic assignments describe purpose without generating a second scale. No runtime section multiplier or fluid promotion is added.
- **Adapt smart spacing narrowly.** `modules/spacing/smart-spacing/_mixins.scss:3-7` normalizes margins; lines 9-121 define flow, headings, lists, figures, captions and quotes. The mixin clears row gap with `!important` and uses adjacent content rules. NewYou uses an explicit opt-in block container, omits the global reset and builder-specific rules, and supports only the needed headings, paragraphs, lists, quotations and links. Figures/captions/media, arbitrary wrappers and builder selectors are not promised.
- **Adapt divider relationships.** `modules/dividers/_vars.scss:1-18` supplies feature defaults, line geometry, contextual gap, light/dark mixing and a scheme-dependent border shorthand. `_tokens.scss:3-16` gates root token emission. `_classes.scss:3-58` defines positioned pseudo-element recipes and a child-group recipe. NewYou uses native hr for a thematic break and real borders for decorative grouping. Its border-box arithmetic below is independent of the vendor's positioned line/margin recipe. Existing hairline ink supplies decorative separators; it is not promoted to a native-control boundary color.

Whole-file identities for repeatable source inspection:

```text
modules/spacing/_tokens.scss                         32 lines  f0d7282155ea4e1138c09830d902ac80511959bc1d86739c76060fae72ce4a79
modules/spacing/_vars.scss                           48 lines  dd22f9c0d1cdde75501dde8f03032f1d8c12221f8f49e3952f35a509cff269e5
modules/spacing/smart-spacing/_mixins.scss           121 lines  ce968f43d98426f9c2f9137e7971fe308e4b796023adf2c1885e820a562763d8
modules/dividers/_vars.scss                          18 lines  ee8425808b8135835f60694ff4ad9cb23f87a09b05c81497ac31ccf6a35f5c7e
modules/dividers/_classes.scss                       58 lines  93f41cb8f236f8332d8842bc2025aefac8bc49982df136a32b11a0ddfab5ea42
modules/dividers/_tokens.scss                        16 lines  be27065312608829168fa256f506e73fd2125a1f3bda588947ae14d93c99c2bb
```

Current [contextual-spacing](https://docs.automaticcss.com/spacing/contextual-spacing), [smart-spacing](https://docs.automaticcss.com/spacing/smart-spacing) and [divider documentation](https://docs.automaticcss.com/borders-dividers/global-divider-system) explain the concepts. The archive fixes the inspected version; public recipes and classes can differ. No assertion about arbitrary WordPress settings or compiled output is made here.

## Canonical assignments and editing

Edit [design-tokens.css](../../../../assets/css/design-tokens.css). Three new roles initially reference approved values:

- `--content-gap` references `--space-lg`, currently 24px. Shared `.ds-stack` and prose paragraph flow consume it.
- `--section-space` references `--space-2xl`, currently 48px. The actual registration content uses its Tailwind `py-design-section` utility.
- `--control-gap` references `--space-base`, currently 16px. Shared `.ds-row` and guide token rows consume it.

Tailwind also exposes `gap-design-content`, `gap-design-control` and the other spacing utilities from the corresponding `--spacing-design-*` mappings. These map to the semantic role at the consuming element. Existing card padding inputs remain the Phase 3 contract; this phase adds no competing card alias, radius tier, palette or CTA treatment.

Root assignments resolve at root. Editing a root primitive updates its root-authored aliases, but overriding a primitive below root does not automatically rebind an inherited root alias. For a local content change, override `--content-gap` explicitly. Optional prose/divider inputs remain unset at root and resolve at their consumers, so local heading/list primitives still work where those fallbacks read them directly.

Keep overrides in canonical CSS contexts, not inline template declarations. Browser tests use temporary styles only to exercise propagation. The existing numeric gate is not a validator for every optional expression. Use finite nonnegative compatible lengths for spacing/indent/line width; positive readable measure; a valid CSS border style and approved color role. Percentage gaps, negative dimensions and incompatible units are outside this contract.

## Prose contract

[`design-content.css`](../../../../assets/css/design-content.css) defines `.ds-prose` as block flow with `display: flow-root`, the existing readable `--measure`, body typography and wrapping. It contains child margins without clipping focus. It is not a flex/grid stack. Keep form controls outside it. Apply a nested `.ds-prose` explicitly when content gains an additional wrapper that needs its own flow.

For flow F, heading input H and list gap L:

```text
F = --prose-flow-space, falling back to --content-gap
heading separation = max(F, --prose-heading-space or --space-xl)
L = --prose-list-space, falling back to --space-sm
indent = --prose-indent, falling back to --space-lg
```

Direct adjacent blocks get F before the later block. Direct headings after content get the larger heading separation. First children have no leading margin and last children have no trailing margin. Nested list items, lists and additional blocks inside list items use L. Multiple paragraphs inside quotations use F. Native unordered/ordered markers remain disc/decimal. Logical indentation follows writing direction. Blockquotes add an inset without an invented attribution, italic heading or decorative status cue. Links keep underline and immediate focus; shared text links retain their component color/font contract.

Heading levels remain semantic HTML. The recipe styles h1 through h6 using existing approved type roles; it does not infer an outline from the parent or rewrite tags. There is no truncation, line clamp, media crop, sanitization, content parsing or localization runtime. Trusted markup and content ownership remain caller responsibilities.

## Divider math and semantics

`.ds-divider` styles a native hr with one block-start border and no own margins. Its containing layout owns spacing. Inside `.ds-prose`, ordinary adjacent flow supplies the hr's preceding margin; source order keeps the hr reset from erasing that rhythm. Use hr only for a thematic break, not to add an extra accessibility announcement for every decorative line.

`.ds-divided` is a vertical flex group with zero gap. Direct children have zero block margins except the generated boundary before each following child. Internal child layouts remain intact. For local optional divider gap d and border thickness b:

```text
d = --divider-gap, falling back to --content-gap / 2
before-line space = d
line thickness = b
inside space after line = d
preceding child border-box bottom to following child content start = 2*d + b
```

Default content gap 24px produces d=12px and distance 25px at b=1px. The following child's own internal first-child margin/padding, if any, adds to that distance. The separator follows that child's border-box width; a prose child's readable cap can make its line narrower than the full group. The recipe does not promise a full-width line or normalize unrelated child padding. Do not combine it with another gap owner on the same group.

Optional `--divider-width`, `--divider-style` and `--divider-color` otherwise fall back to the existing uniform border width, solid style and decorative hairline. No pseudo-element, z-index or shadow is consumed. Native forced colors can replace the authored line ink; no forced-color opt-out is added.

## Actual application consumer and preservation

The [registration template](../../../../lib/new_you_web/controllers/registration_html/new.html.heex) uses a native thematic break before safety copy, scoped safety/privacy prose, and a divided Terms/Privacy group. Checkboxes, error alerts and acceptance controls remain outside prose. Current default geometry is retained: the old safety transition was 24px parent gap + 1px border + 24px padding; the new hr receives two 24px parent gaps and its 1px border. Both total 49px. The legal-item context sets `--divider-gap: var(--content-gap)` locally, preserving its former 49px transition too. A computed baseline probe confirms the old `pt-design-lg` utility resolves to 24px, not 32px; the browser regression measures both aggregate distances.

Exact copy keys/bytes, names, CSRF, opaque operation ID, native required/age/Terms/Privacy facts, legal targets, selected language, safe retained values, password omission, error associations and focus order are unchanged. No controller, Identity implementation or release gate changes. The premium lit primary keeps its shine, gradient and borders.

Legal routes return exact hash-checked English development artifacts. They cannot gain a wrapper/stylesheet through a cosmetic edit without changing that response contract. Both raw legal bodies and their hashes remain untouched. WELL-131 remains planning-only and outside this increment; the registration pilot does not deliver or release the broader journey.

## Guide and executable proof

[`DesignSystemContent.content_recipes/1`](../../../../lib/new_you_web/live/design_system_content.ex) adds `/dev/design-system#content` with root role readouts, EN/AF internal prose, nested lists with multiple paragraphs, quotations, ordered lists, internal hr, shared links, a labelled local override and a divided group. The preview excludes this lab. The existing measurement hook reads the new role outputs; no JavaScript state or sizing formula is added.

```sh
ERL_FLAGS='+S 4:4' mise exec -- devcore-project run dev -- mix assets.build
ERL_FLAGS='+S 4:4' mise exec -- devcore-project run test -- mix test test/new_you_web/live/design_system_live_test.exs test/new_you_web/controllers/registration_controller_test.exs test/new_you_web/design_field_test.exs test/new_you_web/design_component_contracts_test.exs test/new_you_web/design_system_infrastructure_test.exs
BROWSER_TOOLS_ROOT=/tmp/newyou-refinement-tools CHROME_PATH=/usr/bin/google-chrome node test/assets/design_content_browser.mjs
BROWSER_TOOLS_ROOT=/tmp/newyou-refinement-tools CHROME_PATH=/usr/bin/google-chrome node test/assets/design_registration_browser.mjs
```

Two new composition tests first failed on absent guide/application recipes, then passed. A nested-paragraph browser regression observed 0px spacing where 8px was required; the scoped list/quote rules and internal-hr source order were corrected. The final proof measures actual rendered margins/geometry, not just source declarations.

Observed source-checkpoint results: 81 focused ExUnit tests and 69 content assertions pass on Chrome 155.0.8059.84. The actual registration proof retains 105 passing assertions, layout proof 6688 and component proof 51. Content checks cover first/last margins, paragraph/heading/list/quote rhythm, native markers/hr, separator equations, local measure, root/local font/role inputs, optional overrides and sibling isolation, all three roles on the actual page, 240px allocation, 320/390/744/1440/1920px, doubled/long EN/AF/unbroken text, native keyboard links, forced-color separators, reduced motion and no-JavaScript visibility. Computed font sizes are snapshotted before doubling ancestors/children so nested content is stressed at 200%, not accidentally 400%. Desktop/phone captures were inspected.

This remains Chromium proof, not Firefox/WebKit, screen-reader or every browser/OS text-zoom mode certification. Registration loading, business and error paths retain their existing coverage; a static prose/divider recipe adds no meaningful lifecycle, failure retry or durable state.

## Gates, documentation impact and acceptance

Use the installed Hallmark script with the changed CSS and existing guide/registration routes. Existing-UI checks do not authorize a redesign, theme selection or full audit. Final commands, observed exact-head gate results, independent review and generated-history checks belong in PR/Plane. The source-checkpoint guide render has zero FAIL/open REFLEX and one inherited gradient endpoint WARN. The prior registration/Tidewave toolbar focus findings remain recorded and cannot be waived as Floor findings.

This is a bounded presentation extension. No Domain, business interface, lifecycle, schema, persistence or eligibility changes; the existing semantic-map exemption applies. This source-linked proof addendum and generated PR history record the new recipes. The registration capability map's unchanged business snapshot is not rewritten.

Acceptance follows the [six-criterion plan](../../../superpowers/plans/2026-11-15-content-rhythm.md): semantic roles; scoped prose; single-owner dividers; shared guide and unchanged application/copy contract; stated runtime proof; documentation and mandatory exact-head delivery checks. The first five have local source/test/browser evidence. Criterion six remains partial while required checks/certification are unresolved. WELL-114 stays open under the owner UI-continuation exception. PR conflicts, absent hosted checks, independent Master Gate and resulting-main proof remain separate obligations. No merge, Done transition or complete-delivery claim follows from these recipes.
