# Phase 2 layout foundations

Work item WELL-112, draft PR [#227](https://github.com/Carpe-Diem-Media/NewYou/pull/227). The owner requested implementation of guide specimens after the [Phase 1 inventory](README.md). This addendum describes the later implementation; the Phase 1 catalog remains bound to its original archive and NewYou baseline. No vendor source or Sass runtime is adopted.

## Scope and entry points

The existing `/dev/design-system` layout section now includes a layout lab. It renders fixed grids, auto-fit, auto-fill, a capped container with nested content, and a seven-track breakout comparison. A full/narrow allocation control changes the available width independently of the viewport. The count and remainder controls share the guide's existing bounded display state. The existing viewport preview, card specimens, canonical components and lit buttons retain their behavior.

Implementation entry points:

- `NewYouWeb.DesignSystemLayouts.layout_foundations/1` in `lib/new_you_web/live/design_system_layouts.ex` owns specimen/control markup. It is a guide component, not a newly admitted production layout API.
- `NewYouWeb.DesignSystemLive.handle_params/3`, `handle_event/3` and `patch_choices/2` in `lib/new_you_web/live/design_system_live.ex` validate and preserve display choices. `design_system_live.html.heex` includes the lab in the existing layout section. The preview route excludes it.
- `assets/css/design-layouts.css` owns the recipes and imports through `assets/css/app.css`. Selectors use the `ds-layout-*` namespace. Breakout placement targets opted-in direct children only.
- `assets/css/design-tokens.css` owns four candidate inputs. `DESIGN.md` records the owner-requested candidate scope without changing any application default.
- The existing `DesignSystem` browser hook reads actual computed widths and gaps through its measurement protocol. No JS sizing formula or second dimension source was added.

The existing frontend authority prefers native CSS relationships and meaningful reuse. These are guide candidates for evaluating those relationships. They do not migrate pages, make every section a content grid or approve production breakout lanes. Shared production APIs still require a real repeated consumer and its state/accessibility contract.

## Editable input contract

Edit the four inputs once in `design-tokens.css`:

- `--design-layout-min` initially `12rem`. It is the positive minimum used by the intrinsic grids before available-width clamping.
- `--design-layout-columns` initially `3`. It is a whole-number limit between 1 and 12, not a promise that the allocation can fit that many items.
- `--design-layout-narrow` initially `18rem`. It caps the specimen allocation for comparison; width remains at most the available parent width.
- `--design-layout-content-ratio` initially `0.5`. It is greater than zero and at most one. Multiplying the existing content-width by this ratio makes room for breakout lanes inside the guide.

The design gate rejects missing, duplicate, wrong-unit or invalid values for these inputs. Fractional column counts are rejected. The existing fluid/colour checks remain intact. This is a bounded literal-source check; arbitrary runtime CSS edits are not validated by the Mix task.

Canonical `--content-width`, `--gutter`, `--grid-gap`, `--space-lg` and `--space-2xl` remain unchanged. The recipes read those properties where they are used. They do not store a root-derived safe width or minimum expression that retains root inputs when a component overrides its base token. Local overrides of the named consumer inputs therefore recompute the corresponding relationship; they do not promise automatic rebinding of unrelated inherited aliases.

Default examples assume non-negative spacing and positive finite dimensions. A useful content allocation must leave room for its intended text after gutters. Zero-clamping prevents negative track expressions; it cannot make content readable in an allocation with no remaining content width. Root rem changes and actual text enlargement are separate checks.

## Grid relationships

The fixed specimen reuses `.ds-card-grid` with one visual column below 744px, two at 744px and three at 1128px. Tablet/desktop use four/six alignment tracks with each item spanning two. Its start/centre remainder policy stays distinct from intrinsic fitting. A narrow allocation does not change viewport media queries; the fixed specimen deliberately makes that distinction visible.

Let W be the intrinsic grid's allocated inline size, M its positive minimum, G the actual grid gap, and N its integer column limit. The recipe uses:

```text
minimum track = min(W, max(M, (W - (N - 1) * G) / N))
fit threshold for k columns = k * M + (k - 1) * G
```

`minmax(minimum track, 1fr)` grows equal tracks. Auto-fit collapses empty tracks; auto-fill preserves them. With enough items to occupy the first row, a partially filled final row stays at the start and retains track widths. Deliberately centred final rows use the fixed-grid placement recipe instead.

At a 16px root, M=192px and G=24px. Two columns fit at 408px; three at 624px. The tests inspect each threshold minus/at/plus one pixel. At a fixed viewport, changing M or N changes actual fitting. The minimum is a live CSS input, unlike the archive paths that interpolate aggressiveness during compilation. No unconnected aggressiveness token is exposed here.

Items have zero minimum inline size and explicit wrapping for unbroken content. Images have a maximum inline size of 100% and preserve their intrinsic aspect ratio. The cell insets use existing spacing tokens; they do not define a new card treatment.

## Container and gutter ownership

The container cap is `content-width * demo ratio`. It measures the border box, including both inline gutters. The container has width 100%, a capped maximum and auto inline margins. One wrapper applies gutter padding; nested content adds no second wrapper gutter. Small text insets inside the nested specimen are component spacing, not another page gutter.

The container reads local `--content-width` and `--gutter` directly. For example, local content-width 800px produces a 400px demo cap, and a local 40px gutter applies only to that consumer. Padding is bounded by half the allocation to avoid a negative box allocation. This is a comparison recipe, not permission to replace all production containers with the half-width cap.

## Breakout geometry and scope

The seven tracks run in this order: flexible outer lane, outer feature lane, inner feature lane, central content, inner feature lane, outer feature lane, flexible outer lane. Named lines form content, feature, feature-max and full zones. An unmarked direct child defaults to content. Full-safe occupies full while retaining its own inline gutters.

The central content track is bounded by both the demo cap and `max(0, W - 2*G)`. Inner feature lanes grow up to `--space-lg`; outer feature lanes grow up to `--space-2xl`. Outer flexible tracks have a bounded gutter minimum. Column gap is zero because the lanes themselves provide the horizontal structure; row spacing is independent.

When both feature pairs reach maximum, with inner F and outer B:

```text
content = C
feature = C + 2*F
feature-max = C + 2*F + 2*B
full = W
```

At current inputs and 900px allocation, C=640px, F=24px and B=48px. Feature is 688px, feature-max is 784px and outer full lanes share the remaining 116px. At 240px and 320px allocation, feature tracks collapse and content retains the two gutters. Intermediate allocations need not have maximum feature widths; do not apply the maximum-width equations before those tracks have enough space.

A nested `data-zone="full"` label remains inside its parent. The selector contract never promotes arbitrary descendant markers. The wrapper does not remove padding from unrelated sections or use viewport-width breakout calculations. These lanes remain a guide candidate until an approved production composition needs them.

## Display state and accessibility

`allocation` accepts only `full` or `narrow`. Existing count accepts 1 through 9 and alignment accepts `start` or `center`. Malformed values fall back; malformed event envelopes are ignored. URLs retain non-default allocation across grid and viewport patches. Default full allocation is omitted from patched URLs to preserve existing guide links.

The controls are native labelled selects with the guide's immediate focus outline. They have no business effects or durable writes. Reload/reconnection uses the URL as the display source. Server-rendered specimens remain visible without JavaScript; the existing no-script notice explains that measurement and preview controls require it. Measurements are initially "Not measured" and do not claim a browser read before the hook runs.

New copy is internal development reference copy, Class C under the inspected copy workspace. The Afrikaans line is a wrapping specimen, not a new participant journey or approved production copy packet.

## Repeatable verification

Use the existing external browser tooling and project environment; install no app dependency:

```sh
mise exec -- devcore-project doctor
NEW_YOU_PORT=4237 ERL_FLAGS='+S 4:4' mise exec -- devcore-project run dev -- mix phx.server
ERL_FLAGS='+S 4:4' mise exec -- devcore-project run dev -- mix assets.build
ERL_FLAGS='+S 4:4' mise exec -- devcore-project run test -- mix test test/new_you_web/live/design_system_live_test.exs test/new_you_web/design_system_infrastructure_test.exs
BROWSER_TOOLS_ROOT=/tmp/newyou-refinement-tools CHROME_PATH=/usr/bin/google-chrome node test/assets/design_layouts_browser.mjs
BROWSER_TOOLS_ROOT=/tmp/newyou-refinement-tools CHROME_PATH=/usr/bin/google-chrome node test/assets/design_system_browser.mjs
ERL_FLAGS='+S 4:4' mise exec -- devcore-project run test -- mix check
ERL_FLAGS='+S 4:4' mise exec -- devcore-project run test -- mix check.deep
HALLMARK_PUPPETEER=/tmp/newyou-refinement-tools CHROME_PATH=/usr/bin/google-chrome node /home/jcschoeman96/.agents/skills/hallmark/scripts/sloplint.mjs assets/css/design-tokens.css assets/css/design-system.css assets/css/design-components.css assets/css/design-layouts.css --scope app --genre modern-minimal --url http://127.0.0.1:4237/dev/design-system --json
```

The browser geometry function can also run through the shared preview evaluator. This workstation's shared preview twice timed out waiting for animation frames, including a minimal frame callback, with "Preview automation evaluate timed out after 15000ms." The established external Chrome runner supplies the automated proof instead. That tooling issue is not evidence that the CSS failed.

The browser tests measure the actual guide DOM and stylesheet with controlled allocation/token edits. They do not implement a duplicate CSS layout engine. The expected threshold and lane equations are independent assertions. The read-only browser fixtures restore their edited markup/styles before checking page overflow. No-JavaScript checks use a fresh browser page.

## Phase 1 proof reconciliation

- `LAY-GRID-02`, `LAY-GRID-03`, `LAY-AUTO-02`, `LAY-AUTO-03`: the new guide proof covers threshold geometry, item populations, fit/fill empty tracks, wrapping/media and fixed-grid remainder placement. It supplements existing browser proofs. It does not establish cross-engine compatibility.
- `LAY-GRID-01`, `LAY-AUTO-01`: the guide is a concrete comparison consumer. Admission of an additional shared production recipe still needs a real production use case and reviewed minimum.
- `LAY-GUTTER-01`, `LAY-GUTTER-03`, `LAY-WIDTH-03`: guide ownership, nesting, centered cap, local-input and narrow allocation proof are implemented. Existing fluid gutter specimen proof remains historical evidence; production binding is not changed.
- `LAY-GUTTER-02`, `LAY-WIDTH-01`, `LAY-WIDTH-02`: production static/fluid adoption and new shared container roles remain separate decisions. No new root safe-width alias or production endpoint is approved.
- `LAY-BREAKOUT-03`: guide lane geometry, narrow collapse and direct-child scope now have proof. Production consumer selection and lane approval in `LAY-BREAKOUT-01`/`02` remain deferred. The default guide lane inputs are illustrative derivations from existing roles.

The other module decisions and proof IDs in Phase 1 remain unchanged. Public [ACSS auto-grid documentation](https://docs.automaticcss.com/grids/auto-grids) checked during this phase explicitly describes the 4.x variable approach and absence of old utility classes. The [content-grid documentation](https://docs.automaticcss.com/grids/content-grid) explains four zones and gutter ownership. The [CSS grid reference](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/grid-template-columns) supports the native track syntax. Those pages are context; the exact archive references still govern claims about the inspected 4.0.3 source.

## Observed proof and review record

The two new LiveView tests first failed because the lab and allocation state were absent. The numeric-input test first failed because the new token contract was absent. Focused tests then passed after implementation. The initial geometry evaluator likewise failed on the missing `layout-lab` before CSS/markup implementation.

The completed external Chrome geometry suite passed 6,688 assertions in Chrome 155.0.8059.84. It runs the threshold/remainder matrix at 320px, 744px and 1440px viewports, then checks exact viewport boundaries, live allocation/count state, reconnection, local/root token changes, 200% computed text sizing, keyboard focus and fresh no-JavaScript rendering. It includes wide intrinsic media in both auto-grid cells and breakout content, plus nested-marker isolation. The image constraint in breakout also relies on the existing Tailwind preflight; the test preserves that observed behavior rather than adding a redundant image framework.

The expanded token test also verifies missing/duplicate declarations for all four inputs and rejects a column count above the upper limit. Exact focused and full engineering-gate counts are recorded in the PR and Plane for the final source revision.

Other observed checks:

- The original guide browser proof passed, including viewport/grid controls, live token propagation, contrast, focus, reduced motion and no browser errors.
- The math browser proof passed its 212 checks. The independent Python reference passed 126 arithmetic assertions; Python routing/smoke passed 54/54.
- Node colour tests passed 4/4. The asset build and design enforcement passed. `mix check.deep` passed with zero errors/skips in 13.17 seconds.
- The four-target supported Hallmark render reported zero FAIL, zero open REFLEX, one existing WARN, one accepted existing waiver and zero rejected waivers. Initial introduced gate 72 text-edge findings were fixed with existing small text insets, then the render passed again. The retained gate 40 WARN samples the existing CTA gradient endpoint at 3.97:1; the existing numeric-weight/font-family gate 37 waiver is unchanged. No new waiver or lint exclusion was added.
- The existing lighting proof passed unchanged, including painted CTA text contrast of 5.32:1 at rest, 9.41:1 on hover/press and 5.31:1 for wrapped doubled text. This phase does not change the CTA implementation or claim that its retained Hallmark endpoint warning disappeared.
- Desktop and 320px phone captures of the new lab were inspected. The existing Tidewave toolbar is visible in DEV screenshots and remains separate from product UI.

The first bounded source review identified missing viewport coverage in the initial new proof and the not-yet-written handoff. The runner now exercises phone/tablet/desktop remainder populations and the breakpoint boundaries; this addendum and developer-guide link supply the planned handoff. Those findings were addressed without changing existing card-grid CSS. The later complete-delta source/document/UX review found no substantive findings and confirmed those gaps were addressed. Its review did not repeat test execution and is not Master Gate certification. Final engineering/CI evidence belongs to PR/Plane records.

## Delivery boundaries

WELL-114 independent post-merge certification remains open under the owner's continuation exception. This phase supplies no Master Gate approval, resulting-main proof or merge authorization. Exact-head engineering, hosted CI and independent review evidence must be recorded separately. Firefox/WebKit and full browser text-zoom certification require their own observed runs; a Chrome result is not a cross-engine claim.

Documentation impact: no Domain, schema, authorization or business lifecycle changes. The existing developer handoff and this focused addendum describe the guide-only display/layout contract; a new capability map is exempt. The generated PR history remains the mechanical complete-change record.
