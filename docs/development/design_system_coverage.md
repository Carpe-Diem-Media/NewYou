# Design-system implementation coverage

This is the current implementation index for WELL-112. It describes application
and guide source inspected at `86461db98051fbd901b1e6b6953af42eb76b732b`.
The associated [PR #227](https://github.com/Carpe-Diem-Media/NewYou/pull/227) is
Draft at that recorded checkpoint. This index is descriptive documentation beneath [DESIGN.md](../../DESIGN.md),
not visual approval, live execution authority or release certification. Plane
owns current delivery state. Recheck source and proof before reuse.

The [ACSS inventory](research/acss-4.0.3-inventory/README.md) records the original
4.0.3 source traces and decisions. Its historical baseline and the unchecked
contracts in the [next-pass roadmap](research/acss-4.0.3-inventory/next-passes.md)
do not describe every later implementation. Use this index to find those
continuations without rewriting their historical evidence.

## Adoption terms

- **Foundation** means canonical tokens or an editing mechanism exist. It does
  not mean every legacy selector has migrated.
- **Application consumer** means the recipe is used by actual application
  markup. The current registration consumer is development-gated by
  [RegistrationController](../../lib/new_you_web/controllers/registration_controller.ex).
  This is not a released production journey.
- **Guide candidate** means executable specimens and bounded proof exist, but
  a new production mapping or treatment still needs review and consumer proof.
- **Deferred** means the missing API or adoption is deliberate until a real
  consumer establishes its requirements. It is not an implementation claim.

Visual approval, adoption and verification are separate. A passing calculation
or a specimen's presence does not promote its values. There is no whole-framework
completion or site-wide migration claim.

## One editing source

[design-tokens.css](../../assets/css/design-tokens.css) owns the editable CSS
inputs and their namespaced Tailwind aliases. Component CSS consumes those
inputs; Phoenix components own finite options; native HTML and ARIA own native
state. Do not add a second Sass or JavaScript calculation authority.

- **Fonts, foundation:** edit `--font-body` and optionally `--font-display`.
  Heading fonts follow the body family by default. Legacy aliases and the
  default Tailwind font mappings refer to those inputs. The locally served
  Inter face and license live under [fonts/inter](../../priv/static/fonts/inter/README.md).
  A replacement font needs permitted files, face registration and a wrapping
  review; changing a family token does not supply a missing font asset.
- **Palette, foundation:** edit approved `--palette-*-srgb` sources, consumed by
  semantic `--primary`, `--secondary`, canvas, surface and ink roles. Relative
  OKLCH preserves those colors where supported; mixing is progressive enhancement.
  `--primary-hover` has its own source. Changing the primary source alone does
  not choose a new hover color. Recheck complete pairings after color edits.
- **Production typography, foundation/application consumer:** existing semantic
  `--text-*`, leading, tracking and measure roles remain the application baseline.
- **Modular and fluid type, guide candidate:** eight `--type-{body|heading}-{base|ratio}-{min|max}` inputs generate independent mobile/desktop endpoints.
  `--fluid-vmin`, `--fluid-vmax` and the shared native `progress()` /
  trigonometric / static engine interpolate them. Candidate aliases remain
  separate from production roles. See [typography](research/acss-4.0.3-inventory/pass1-typography.md).
- **Spacing, foundation/application consumer:** grid, gutter, content, section,
  control and card roles remain distinct. Initial role assignments preserve
  approved values. Fluid spacing/gutters remain guide candidates. See
  [content spacing](research/acss-4.0.3-inventory/pass2-content.md).

## The ten requested ACSS systems

1. **Grid, adapt.** Fixed responsive grids and incomplete-row centering are
   implemented in the guide. The start/center policy and supported remainders
   are explicit; it is not the same recipe as intrinsic fitting. Owner and proof:
   [design-system.css](../../assets/css/design-system.css),
   [layout specimens](../../lib/new_you_web/live/design_system_layouts.ex),
   [layout browser test](../../test/assets/design_layouts_browser.mjs).
2. **Auto-grid, adapt.** `.ds-auto-grid` uses shared intrinsic auto-fit CSS in
   both registration and the guide. Explicit minimum/count/gap inputs determine
   transitions. Auto-fill remains a guide candidate; incomplete intrinsic rows
   retain their track widths. Owner and formulas:
   [design-layouts.css](../../assets/css/design-layouts.css) and
   [layout notes](research/acss-4.0.3-inventory/phase2-layouts.md).
3. **Shadows/elevation, adapt.** The lit primary treatment is an application
   consumer. Raised cards and elevation comparisons remain guide candidates;
   flat cards still default to `--box-shadow: none`. ACSS authored shadow tiers
   were not copied as a calculated elevation scale. Owner:
   [component CSS](../../assets/css/design-components.css),
   [lighting proof](../../test/assets/design_lighting_browser.mjs).
4. **Radius, adapt.** Approved tiers feed shared controls/cards. The guide
   demonstrates local per-axis inset radii with
   `max(0, outer radius - border width - padding on that axis)`. Insets remain
   opt-in; global auto-radius, inverted corners and media/avatar APIs are
   deferred. See [component contracts](research/acss-4.0.3-inventory/phase3-components.md).
5. **Gutter, adapt.** Registration and the guide use one `.ds-container` owner
   for horizontal padding. Canonical `--gutter` is static; the fluid alternative
   has guide specimens, not application adoption. Nested wrappers must not
   silently double page gutters. See [layout notes](research/acss-4.0.3-inventory/phase2-layouts.md).
6. **Content width, adapt.** Shared containers consume the approved 1280px cap
   through `--content-width` and an optional local container maximum. The guide's
   reduced allocation is a comparison, not a new global cap. Readable prose
   measure is separate from page width. Owner:
   [layout CSS](../../assets/css/design-layouts.css),
   [registration template](../../lib/new_you_web/controllers/registration_html/new.html.heex).
7. **Breakout, guide candidate; application adoption deferred.** Seven tracks
   implement content, feature, feature-max and full zones, with full-safe gutter
   handling and direct-child ownership. Narrow collapse has proof. No current
   application page adopts those lanes. See [breakout geometry](research/acss-4.0.3-inventory/phase2-layouts.md#breakout-geometry-and-scope).
8. **Icons, adapt.** Shared Heroicons semantics have a registration consumer.
   Finite plain/boxed and size options are documented; decoration and named images
   have different accessible semantics. The icon wrapper is not an interactive
   control. Source: [Icon](../../lib/new_you_web/components/design/icon.ex),
   [contracts proof](../../test/assets/design_component_contracts_browser.mjs).
9. **Cards, adapt.** The flat shared card is used by registration. Leading,
   inset and action slots, bottom-aligned actions and local spacing/radius inputs
   are implemented. Raised/inset comparisons have guide specimens; a general
   media/avatar framework remains deferred. Source:
   [Card](../../lib/new_you_web/components/design/card.ex),
   [contracts](research/acss-4.0.3-inventory/phase3-components.md).
10. **Data attributes, adopt selectively.** Components own visual variant and
    surface attributes; callers use their documented Phoenix API. Classes own
    component identity/layout, and native disabled/checked/readonly/focus state
    remains native. Unrelated data/ARIA/LiveView metadata is forwarded where
    supported. There is no universal attribute interpreter. See
    [attribute ownership](design_system.md#classes-data-attributes-and-native-state)
    and [contract tests](../../test/new_you_web/design_component_contracts_test.exs).

These are independent NewYou recipes. Nothing further must be extracted from
ACSS before this foundation can be finished and adopted.

## Section layouts

The development guide's [section examples](../../lib/new_you_web/live/design_system_sections.ex)
show three [Phoenix functions](../../lib/new_you_web/components/design/section.ex)
for composing an introduction, a feature list and a call to action. Import
`NewYouWeb.Components.Design.Section` where needed. Give each instance a unique
`id` and set `heading_level` to fit the caller's page outline. The section
derives its heading ID from that ID. The caller supplies localized copy, media
alternatives and the native controls used in the action slots.

```heex
<.split_hero id="introduction" title={@title} heading_level={1}>
  <:body><p>{@description}</p></:body>
  <:media><img src={@image_url} alt={@image_alt} /></:media>
</.split_hero>

<.feature_grid id="features" title={@features_title}>
  <:item :for={feature <- @features}>
    <.design_card title={feature.title}><p>{feature.summary}</p></.design_card>
  </:item>
</.feature_grid>

<.action_section id="next-step" title={@next_title}>
  <:actions><.text_link href={@next_path}>{@next_label}</.text_link></:actions>
</.action_section>
```

Contain the section in the page's existing gutter. Noninteractive hero media
can sit to the left of the copy on a wide layout and follows the copy when
stacked. Feature grids with no items and action sections with no actions are
omitted. The guide is the current consumer. Participant adoption requires a
named consumer and the applicable copy review.

The [render tests](../../test/new_you_web/design_section_test.exs) cover the
slot contract and section semantics. The [browser check](../../test/assets/design_sections_browser.mjs)
uses the [existing guide tooling](design_system.md#repeatable-verification)
to check reflow, contrast and keyboard behavior:

```sh
BROWSER_TOOLS_ROOT=/path/to/browser-tools node test/assets/design_sections_browser.mjs
```

## Content, surfaces and controls

- **Contextual spacing and prose, application consumer:** registration uses
  content/control rhythm, `.ds-prose` and dividers. Nested lists, quotations,
  figures/captions and nested prose have scoped guide recipes. No standalone
  eligible editorial page was selected; legal responses were not migrated.
  See [content continuation](research/acss-4.0.3-inventory/pass2-content.md) and
  [content CSS](../../assets/css/design-content.css).
- **Opaque surface pairings, application consumer plus guide comparisons:**
  the shared card resets its own roles. Plain/canvas/panel/raised boundaries
  provide background, heading, body, muted, link, link-hover and focus outputs.
  Inputs resolve at each explicit boundary. Gradient, translucent and image
  surfaces are outside this measured opaque contract. See
  [surface contracts](research/acss-4.0.3-inventory/pass4-surfaces.md).
- **Borders/dividers, application consumer:** decorative edges, control
  boundaries, separators and directional lighting have separate purposes.
  Native `hr` and scoped divided groups own their spacing. See
  [border continuation](research/acss-4.0.3-inventory/pass3-borders.md).
- **Buttons/links, application consumer:** shared native actions preserve the
  premium lit-primary gradient/shine, focus and native state behavior. Do not
  treat disabled links as buttons or fabricate a new feedback palette. Source:
  [Button](../../lib/new_you_web/components/design/button.ex),
  [Link](../../lib/new_you_web/components/design/link.ex).
- **Native forms, application consumer:** shared text/email/password fields,
  checkboxes, fieldsets and help/error association are used by registration.
  Caller-localized content and native interaction remain authoritative. Radios,
  selects, textareas and a shared error-summary API remain deferred until a real
  consumer needs them. See [form contracts](research/acss-4.0.3-inventory/pass5-native-forms.md).
- **Floating labels, guide candidate for application adoption:** the approved
  opt-in variant is implemented for text/email/password. Registration still
  uses stacked labels. Long EN/AF labels, native focus/value/autofill, reduced
  motion and no-script behavior have browser proof. Source:
  [Field](../../lib/new_you_web/components/design/field.ex),
  [floating-label notes](design_system.md#opt-in-floating-labels).
  The later [composition correction](design_system.md#floating-field-composition-corrections)
  resolves local borders on the painted wrapper and applies surrounding surface
  focus roles to that wrapper's keyboard outline. Its permanent browser contract
  combines those recipes; the earlier individual proofs missed this interaction.
- **Decorative backgrounds, guide candidate:** gradients, seeded noise and
  overlays have tokens/specimens and usage limits. Their presence does not
  approve text pairings or image-overlay contrast.

## Delivery and proof limits

The guide is DEV/test-only. The actual registration template is an application
consumer under development gates, not a participant release. Legacy styling
remains temporarily supported; [design.check](../../lib/mix/tasks/design.check.ex)
rejects new or increased bypasses rather than certifying a site-wide migration.

At the recorded source, local canonical proof passed 892/892 and deep proof
reported zero errors. Hosted [run 43948099726](https://github.com/Carpe-Diem-Media/NewYou/actions/runs/43948099726)
passed Foundation Integrity, smoke, application check/deep and security audit
for exact head `86461db`. Later changes need their own applicable proof and CI;
these results are not a current-main or future-head certification.

WELL-114 is independently integrated in main `f72cf637453408896a5037dcb2f8d37f0d29e3af`.
That closes the former dependency gap. The owner explicitly accepted measured
alternate evidence for the two documented Hallmark detector limitations. Keep
the original FAIL reports and this scoped exception; it is not a passing linter
result or merge authorization. Remaining delivery work includes OCR, current-head
CI and independent exact-head Master Gate. See the
[quality diagnosis](research/acss-4.0.3-inventory/quality-gate-diagnosis.md).
No author score, source index or passing engineering suite closes those findings.

Chromium and Firefox have bounded proof, with exclusions documented per runner.
WebKit, screen-reader behavior and true browser zoom are not certified. Legacy
screen coverage and complete canonical form-family coverage are also unfinished.

## Next adoption decisions

First resolve the current quality/review gates. Then visually approve semantic
candidate typography and any fluid spacing/gutters on an actual page. Complete
only the controls that page needs, and review its whole responsive/state behavior
before wider rollout. Do not promote every guide recipe together.

Later consumer-driven ACSS research may cover media aspect/intrinsic/crop
relationships, image/card radii, sticky-header/anchor offsets and DEV diagnostics.
These are deferred. No additional WordPress plugin, Sass runtime or vendor code
is required by the current plan.
