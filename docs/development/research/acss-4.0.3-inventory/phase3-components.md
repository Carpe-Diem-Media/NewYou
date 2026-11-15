# Phase 3 component contracts

Continuation of WELL-112 and draft PR #227 from `f3de8c8c687f12a7e45d1472ca9133ff70650344`. The owner requested cards, icons, radius relationships, elevation, attribute variants, local overrides and native accessibility rules after Phases 1 and 2. This addendum describes the resulting presentation contract. It does not promote guide candidates into every application page or certify integration.

The [Phase 1 inventory](README.md), [component findings](components.md), [shape findings](shape.md) and [proof plan](proof-plan.md) remain source evidence at their recorded baseline. Their vendor hashes and locators have not changed. No plugin code was copied, executed or compiled. No Sass, dependency, extra icon library or business state was added.

## Ownership and supported inputs

Use Phoenix attributes for finite choices. The component emits its owned data attributes. Classes identify the component; native HTML and ARIA carry behavior. There is no universal attribute interpreter and no new JavaScript lifecycle.

- [`design_card/1`](../../../../lib/new_you_web/components/design/card.ex) owns its class, `data-variant=flat|raised` and article structure. Flat remains the default. `heading_level` accepts integers 2 through 6, default 3. Choose the level from the containing page outline, not its visual size. `title` remains required; body remains required. Optional `leading`, `inset` and `actions` slots render only when supplied. Leading can contain a decorative icon. Inset is a contained content region; native actions belong in the body or actions slot. Actions wrap and align to the bottom of equal-height cards.
- [`design_icon/1`](../../../../lib/new_you_web/components/design/icon.ex) owns its class, `data-size=sm|md|lg`, `data-treatment=plain|boxed`, `role`, `aria-label` and `aria-hidden`. Defaults are medium, plain and decorative. Glyphs use existing 16/24/32px spacing roles. Boxed adds the existing small padding/radius and neutral surface/edge, without elevation. A nil label hides decoration. Nonblank label text produces a named `role=img`; its artwork has no independent meaning. Blank labels are rejected.
- [`primary_button/1` and `secondary_button/1`](../../../../lib/new_you_web/components/design/button.ex) retain `data-variant=primary|secondary` and `data-treatment=flat|lit` ownership. Flat remains default. The primary component accepts only its existing primary variant. Native `type`, `disabled`, LiveView events and unrelated metadata keep their existing behavior. No `data-disabled` or `data-loading` API is introduced.
- [`text_link/1`](../../../../lib/new_you_web/components/design/link.ex) retains its native anchor, required href, underline and immediate focus indicator. Both atom and string class collisions now raise. Navigation remains navigation; no disabled anchor is simulated.

Card and icon reject atom/string collisions for their owned visual and semantic keys. Card rejects `class`, `style`, `data-variant`, `role`, `tabindex`, `onclick`, `onkeydown`, `onkeyup`, `phx-click`, `phx-capture-click`, `phx-keydown` and `phx-keyup`. Icon rejects `class`, `style`, `data-size`, `data-treatment`, `role`, `aria-label`, `aria-labelledby`, `aria-hidden`, `tabindex` and those same event keys. These restrictions prevent the common ways of turning either presentation component into a control. Consumers must not add custom event listeners to make an article/icon interactive. They are not a security sandbox.

Unrelated data/ARIA attributes and suitable LiveView metadata remain forwarded. For example, article `id`, `phx-hook`, `data-tracking-id` and `aria-label` survive. Buttons preserve native form/event attributes and ARIA state. A metadata attribute conveys no authorization and triggers no automatic behavior. Theme selection, business state and visual variants remain separate concerns.

Heroicons artwork still comes through [`CoreComponents.icon/1`](../../../../lib/new_you_web/components/core_components.ex) and the existing [`Tailwind plugin`](../../../../assets/vendor/heroicons.js). Names must be single `hero-*` classes with the existing suffix convention. Use literal names visible to Tailwind source scanning, including outline, `-solid`, `-mini` and `-micro` only where the corresponding installed artwork exists. The wrapper validates the class shape, not the installed artwork catalog. Runtime-computed or database-supplied names are unsupported unless a deliberate finite source-visible mapping is added and tested. The browser proof checks actual masks for every new guide example.

## Radius and local token math

All declarations remain in [`design-tokens.css`](../../../../assets/css/design-tokens.css). [`design-components.css`](../../../../assets/css/design-components.css) consumes them; component templates contain no raw visual CSS or caller inline styles.

Approved radius tiers remain 8, 16, 24, 32 and 800px. The card uses `--radius`, a uniform `--design-border-width`, and the existing `--space-lg` padding by default. Optional inputs are unset unless deliberately overridden:

```css
/* Scoped declarations belong in design-tokens.css. */
.my-approved-card-context {
  --design-card-padding-inline: var(--space-base);
  --design-card-padding-block: var(--space-md);
}
```

For outer border-box corner radius R, uniform border thickness b, inline padding Px and block padding Py, the inset region starts b+Px and b+Py inside the corresponding outer edges:

```text
rx = max(0px, R - b - Px)
ry = max(0px, R - b - Py)
border-radius: rx / ry
```

This is reverse subtraction with a zero floor, extended to elliptical per-axis corners. It includes border width. It is neither ACSS's full-padding outer addition nor the public half-padding recipe. It does not derive the outer card radius from the inset. Example default: R=16px, b=1px, Px=Py=24px gives 0px. Labelled local guide example: R=32px, b=1px, Px=16px and Py=12px gives `15px 19px`. The local values use existing approved tokens; they add no global radius tier. CSS can normalize oversized corners to fit a short or narrow box, so these computed values do not prove an exact parallel curve at every point.

Inputs must be compatible nonnegative lengths, with positive icon size. Do not use percentages, auto, invalid strings, negative padding or per-edge border overrides. Individual corner and per-side padding overrides are outside this contract. CSS source review remains responsible for these optional inputs; the existing numeric gate does not claim to validate every CSS expression.

The derived radii resolve on each card. Selectors style only its explicit direct inset child, so unrelated nested content does not receive automatic rounding. Only the inset clips decoration. Keep interactive controls out of this clipped region so their focus indicators remain visible. Images, if placed there in a later justified consumer, still require alt decisions, intrinsic dimensions and crop/aspect proof. No generic media/avatar API is included in Phase 3.

Optional `--design-icon-size` overrides the selected glyph dimension. `--design-icon-padding` and `--design-icon-radius` override boxed geometry; otherwise the glyph size, small padding and small radius resolve from current semantic spacing/radius inputs. The namespaced Tailwind `size-design-icon-glyph` utility consumes the computed token at the glyph. This avoids the Heroicons utility layer overriding a component-layer width. No enforcement exception for arbitrary dynamic classes was added.

Optional inputs deliberately have no root alias default. Their CSS var fallbacks resolve at the consumer, preserving both ancestor overrides and component-local source-token changes. A root alias such as `--design-card-padding-inline: var(--space-lg)` could freeze its default against a later component-local `--space-lg`. Test both root source changes and ancestor/direct input overrides. Existing lighting relationships also recompute at icon consumers for local neutral surfaces and edges.

## Elevation and native states

Elevation and z-index are separate. None of these variants sets stacking order. Flat cards use the existing surface, hairline and `--box-shadow`, currently none. Raised cards opt into `--surface-raised`, brighter top edge, shaded lower edge and `--shadow-raised`. Boxed icons add no cast shadow. Interactive descendants retain their own native states; the card and icon do not gain hover lift or a pointer cursor.

Lit primary keeps its 12px upper shine, gradient, lighter top border and short cast shadow. Hover and press use existing roles. Press moves shading inward. Disabled removes the cast shadow. Secondary remains the quiet neutral treatment. Forced colors retain system boundaries/focus and remove decorative gradients/shadows. Solid fallbacks remain usable where mixing is unavailable. No blanket shadow ladder, filter shadow, text shadow, inverted corner or broad auto-radius selector was adopted.

The guide's pending specimen uses the same text and dimensions as its idle sibling, plus native disabled and `aria-busy=true`. It is an explanatory specimen, not a simulated successful business request. The calling page owns submission state, server result, recoverable errors and a suitably scoped status announcement. `aria-busy` alone never blocks activation. Do not use this specimen as a substitute for real LiveView loading/reconnection proof on a future production journey.

Icon-only actions use a native button/link with an action name on that control and a decorative icon inside. Named standalone icons use the image label path. Avoid repeating an adjacent visible label in the icon's accessible name. Color alone never communicates status. Glyphs inherit currentColor; boxed glyph contrast is checked against the actual neutral background. Native disabled controls cannot activate and are skipped in tab order. Focus remains immediate, visible and outside clipped decoration. Reduced motion requires no animation for these components; specimens remain visible with JavaScript off.

## Guide and regression entry points

[`DesignSystemContracts.component_contracts/1`](../../../../lib/new_you_web/live/design_system_contracts.ex) renders actual shared components at `/dev/design-system#contracts`. The normal guide includes it; the iframe preview does not duplicate the full lab. The guide retains all earlier layout, lighting, font and token examples. Local geometry belongs only to `#contract-card-local` in canonical CSS. No production page is migrated.

[`design_component_contracts_test.exs`](../../../../test/new_you_web/design_component_contracts_test.exs) checks heading bounds, slot structure, finite icon variants, decorative/named semantics, invalid inputs, atom/string ownership collisions, link regression and metadata. Existing infrastructure tests retain button/card variant/native-state coverage. [`design_system_live_test.exs`](../../../../test/new_you_web/live/design_system_live_test.exs) checks real guide composition, native pending attributes and preview exclusion.

Run from the repository root:

```sh
ERL_FLAGS='+S 4:4' mise exec -- devcore-project run test -- mix test test/new_you_web/design_component_contracts_test.exs test/new_you_web/design_system_infrastructure_test.exs test/new_you_web/live/design_system_live_test.exs
BROWSER_TOOLS_ROOT=/tmp/newyou-refinement-tools CHROME_PATH=/usr/bin/google-chrome node test/assets/design_component_contracts_browser.mjs
```

The browser runner requires the existing guide on port 4237 and externally installed Puppeteer/Chrome. It does not install an application dependency. It verifies radius arithmetic for zero/large/asymmetric padding and changed border thickness, root/ancestor/local token propagation and sibling isolation, direct-child selector scope, actual icon artwork/currentColor/contrast/sizing, native disabled activation, pending dimensions, keyboard order/focus, 320/744/1440px with 200% text and long EN/AF/unbroken content, forced colors, reduced motion and no-JavaScript visibility. Existing lighting and local-token proofs cover unchanged shine/state/solid fallback behavior. Runtime browser evidence remains Chromium only; Firefox/WebKit and assistive-technology interaction are not certified by these checks.

## Phase 1 proof reconciliation

- `COMP-ICONS-001`: shared wrapper, finite sizes/treatments, semantic names, owned attributes, metadata and actual artwork have focused component/browser proof. No hover/list behavior or second icon language was added.
- `COMP-CARDS-001`: existing variant/metadata proof retained; explicit leading/inset/actions slots, heading outline choice, radius arithmetic, narrow text and native actions added. Media/avatar/crop behavior remains deferred without a production consumer.
- `COMP-DATA-ATTRIBUTES-001`: ownership list above, generated accepted values, invalid/collision tests and native-state examples. No JavaScript selector interpreter or hook lifecycle change.
- `SHAPE-RADIUS-SCALE`: existing five tiers preserved. `SHAPE-RADIUS-CONCENTRIC`: border-aware per-axis subtraction measured. `SHAPE-RADIUS-AUTO-SCOPE`: no general auto-radius implementation; direct-child inset selectors are bounded. `SHAPE-RADIUS-INVERTED`: deferred.
- `SHAPE-SHADOW-ROLE`, `SHAPE-SHADOW-STATE`, `SHAPE-SHADOW-FALLBACK`: existing roles/shine/state/solid and forced-color proof retained and rerun. `SHAPE-SHADOW-SILHOUETTE`: no alpha artwork shadow use case, so no filter/text family implemented.

## Evidence and delivery limits

Observed focused and browser results, Hallmark findings, exact candidate SHA and canonical checks are recorded in PR #227 and Plane. Initial contract tests failed for missing card/icon APIs and the string-key text-link collision before implementation. An initial design check rejected dynamic icon classes; the final wrapper uses the existing core artwork component and static token utility. An initial browser failure exposed utility-layer sizing precedence; the token utility corrects it without weakening enforcement. Hallmark's new narrow-sidebar label failure was fixed by shortening its navigation label to Contracts. The inherited gradient-endpoint warning remains explicit; painted CTA label contrast is separately measured by the lighting proof.

Observed Phase 3 checks before final canonical gates: 46 focused Elixir tests passed, 47 new browser assertions passed, and the existing layout browser proof passed 6,688 assertions. Existing guide, local-token and lighting browser regressions passed. Lighting measured minimum painted-label contrast of 5.32:1 at rest, 9.41:1 on hover/press and 5.31:1 for wrapped doubled text. Hallmark reported zero FAIL, zero open REFLEX, one inherited gradient WARN and the existing numeric-font-weight waiver. The exact final-head canonical gate results remain in PR/Plane so this note does not invent a future self-referential SHA.

Documentation impact: these are presentation-only component and development-guide contracts. No Domain, durable state, schema, authorization or business lifecycle changed. Maintain this addendum and the existing developer guide; a new semantic capability JSON is exempt. The generated PR history still records the source changes.

WELL-114 independent post-merge certification remains open under the owner's continuation exception. PR #227 also has inherited base conflicts and lacks required hosted CI evidence. The local UI proof does not close those gaps, authorize merge or move WELL-112 to Done. Independent Master Gate and resulting-main certification remain required.
