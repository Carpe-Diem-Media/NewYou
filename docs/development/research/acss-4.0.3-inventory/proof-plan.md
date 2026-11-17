# Proof plan for ACSS adaptations

This is the implementation handoff from the [Phase 1 inventory](README.md). It names remaining proof and preserves evidence already present at NewYou `4967b498d7413b7530303a64b4027e139e0b6d46`. These identifiers are local research references. They do not create tickets, approve design endpoints or require building every vendor capability.

## Select a bounded next implementation

Start with one existing production-page consumer and the current semantic components. Record the consuming component, intended behavior, approved values, owning stylesheet and states before changing code. Group work by actual dependency: container/gutter/content cap first where needed, then card/grid/icon behavior, then opt-in decoration. A shared relationship belongs at root only when multiple real consumers need it; a component-local relationship should compute from local inputs at the consuming scope.

Keep the existing button gradient/shine, approved palette/shapes, font tokens, flat defaults and current card alignment. An `adapt` decision does not require a new utility family. `defer` items remain deferred until a named consumer justifies them. Do not add WordPress, Sass, a second icon library or an attribute interpreter.

For each implemented pattern, supply focused regression coverage, a guide specimen rendered by the same production component, and the applicable `mix check`, asset, browser and supported Hallmark checks. Check keyboard/focus, native disabled/loading behavior, contrast, reduced motion, long EN/AF labels, 320 CSS pixels and 200% text resizing. Browser claims must name tested engines and versions. LiveView hook changes additionally need mount/update/teardown and reconnection checks. A static guide or arithmetic pass alone does not prove those behaviors.

## Grid and auto-grid

Existing evidence: `.ds-card-grid` uses one, two and three visual columns with separate alignment tracks. `design_math_browser.mjs:84-131` tests actual columns, final-row populations and alignment. Its recorded 212-check Chrome result predates this inventory. The guide also has a local auto-fit lighting-card layout. Neither establishes a shared parameterised auto-grid contract.

- `LAY-GRID-01`: name the repeated consumer, minimum content requirement and intended final-row alignment. Record why the existing layout cannot meet it. No new recipe is needed if it can.
- `LAY-GRID-02`: for the selected minimum M and gap G, calculate each threshold `N*M+(N-1)*G`; inspect one pixel below, at and above it. Render 1 through `2N+1` children with long unbroken content and confirm no inline overflow or unintended track expansion.
- `LAY-GRID-03`: retain and rerun existing start/centre remainder proof when touching that recipe. Verify reset rules at each composition breakpoint and direct-child grid spans. A passing fit calculation is not proof of last-row centring.
- `LAY-AUTO-01`: state C, G, positive integer N, dimensionless A and any allowed local minimum. Reject non-finite/invalid numeric inputs in whatever supported authoring boundary is introduced. Do not ship an apparently live tuning variable that the formula never reads.
- `LAY-AUTO-02`: select auto-fit or auto-fill from the desired empty-track behavior. Test a single item, fewer than N, N, and more than N; measure used track widths and occupied tracks. Do not promise fit/fill interchangeability.
- `LAY-AUTO-03`: render the real component at narrow allocation, threshold boundaries, altered root font size and nested/sidebar contexts. Verify image/text intrinsic sizes, wrapping, gap accounting and item-count cap separately. Cross-engine proof remains required before any compatibility claim.

For independent arithmetic, source-style auto-grid uses `B=A*(C-(N-1)*G)/N`, `T=(W-(N-1)*G)/N`, and `minimum=min(W,max(B,T))`. The browser must still resolve percentages and track layout. Confirm that the component's available width W, not the viewport width, is the input.

## Gutter and content width

Existing evidence: canonical NewYou `--gutter`, `--content-width`, design aliases and the guide container already exist. Fluid values remain candidates. The recorded Chrome math proof already exercises the gutter specimen at multiple root sizes, descending endpoints and fallback tiers in `design_math_browser.mjs:21-84`. It does not certify production wrapper nesting or other engines. Preserve current values unless separately approved.

- `LAY-GUTTER-01`: record which wrapper owns inline padding. Test nested wrappers and section/card boundaries to prove that gutters are neither doubled nor removed.
- `LAY-GUTTER-02`: if a fluid candidate is chosen, define units and viewport bounds explicitly. Verify ordered, finite endpoints and a positive viewport interval; check below/at/between/above bounds, a changed root font size, and a static fallback. Source ACSS settings are not NewYou endpoints.
- `LAY-GUTTER-03`: test local token edits at the consuming scope. Confirm root-derived aliases do not retain unexpected root values. Measure actual inline padding and overflow at 320px and with long labels.
- `LAY-WIDTH-01`: select a real consumer and distinguish a plain cap, a safe cap, inner content width and padded border-box width. Define which box the maximum measures.
- `LAY-WIDTH-02`: justify any new root token with multiple actual consumers. Otherwise compute `min(cap, available-inline-size - 2*gutter)` locally with compatible lengths and valid non-negative allocation.
- `LAY-WIDTH-03`: measure centered gutters/cap below and above the maximum, at narrow allocation and when nested. Test long content and media. If evaluating vendor output, separately prove the `--width-full` typed product and `.width--full`; one is not evidence for the other.

## Breakout

No current consumer or NewYou lane values were established. The source inventory is complete; implementation remains deferred.

- `LAY-BREAKOUT-01`: identify the exact content page and which elements need content, feature, feature-max or full zones. Prefer an opt-in wrapper; do not convert every section.
- `LAY-BREAKOUT-02`: obtain reviewed feature lane values and define their cumulative geometry. With inner F lanes and outer M lanes at maximum, the feature width is `C+2F` and feature-max is `C+2F+2M`. Record the outer gutter/full lanes independently.
- `LAY-BREAKOUT-03`: prove narrow-track collapse, nested sections, direct-child placement, media intrinsic width, full-safe padding, overflow, exclusions and stacking. Test an unmarked child and nested marked descendants to prevent broad marker rules from affecting unrelated content.

## Shadows and radius

Existing evidence: NewYou has semantic lighting inputs, opt-in action/card treatments, fallbacks and existing browser proof recorded in the development guide. ACSS adds no approved shadow values or shape tiers. Visual elevation and CSS z-index remain separate contracts.

- `SHAPE-SHADOW-ROLE`: identify the approved component/state that needs the shadow. Measure or inspect its light direction and contrast on each allowed surface. Preserve flat defaults and the current shine.
- `SHAPE-SHADOW-SILHOUETTE`: if a filter shadow is proposed, demonstrate why alpha-silhouette behavior is needed. Compare transparent artwork against its box bounds. No text/drop-shadow family is required merely because ACSS offers one.
- `SHAPE-SHADOW-STATE`: render applicable default, lit, hover, pressed, loading and disabled states; confirm focus visibility and label contrast. Inspect clipping and overlapping neighboring controls. Avoid layout shifts.
- `SHAPE-SHADOW-FALLBACK`: force solid color and forced-colors paths; confirm borders, native focus and readable state cues survive absent shadows/mixing. Use the existing fallback proofs rather than duplicating tests of unchanged rules.
- `SHAPE-RADIUS-SCALE`: verify current approved five-token mappings and consumers. ACSS's 1rem/1.5 geometric scale is an example, not a replacement. Test altered root sizes for any new rem-based relationship without silently changing approved px values.
- `SHAPE-RADIUS-AUTO-SCOPE`: only if a repeated target justifies auto-radius, enumerate an explicit allow-list and prove cascade/precedence, nested media, native controls and unclipped focus outlines. A broad tag selector is not justified by low specificity.
- `SHAPE-RADIUS-CONCENTRIC`: identify the actual outer/inner edges, border widths and padding on each axis. Select standard addition or reverse subtraction deliberately. Use compatible lengths and an approved minimum; test zero/large/asymmetric padding, border width, narrow cards and media clipping. Public half-padding recipes and archive full-padding cards are different contracts.
- `SHAPE-RADIUS-INVERTED`: deferred. A future approved composition must prove pseudo-element ownership, stacking/isolation, background matching, clipping, forced colors, contrast and decorative semantics. Do not consume pseudo-elements already owned by a component.

## Icons, cards and attributes

Existing evidence: `design_system_infrastructure_test.exs:87-190` covers current card variants, unrelated metadata forwarding, owned class/variant collision rejection and unsupported variants. Buttons already own visual attributes and preserve unrelated HTML/ARIA/LiveView metadata. These tests are evidence to retain, not missing work.

- `COMP-ICONS-001`: with a justified presentation wrapper, render decorative icons and named icon-only native controls. Prove accessibility semantics at the consuming component, finite non-null size/treatment mappings, owned-attribute rejection and metadata forwarding. Retain Heroicons artwork. Test size/color inheritance, focus and optional list/hover behavior only where introduced.
- `COMP-CARDS-001`: preserve current card tests. Add media/avatar/slot tests only with a real API use case. Prove semantic alternatives, aspect/crop and intrinsic sizing, text wrapping, local radius relationships and adjacent native action keyboard behavior. The outer article remains noninteractive.
- `COMP-DATA-ATTRIBUTES-001`: maintain an explicit ownership list per component. Assert accepted generated values, invalid-input rejection, collision rejection, unrelated data/ARIA/LiveView preservation and native state attributes. Add JS selector scope/lifecycle proof only where hooks change. Keep theme state separate from visual variants; do not infer universal behavior from arbitrary attributes.

## Vendor-output uncertainties

These questions bound the research. They are not reasons to recreate the plugin inside NewYou, and do not block independently implementing ordinary mathematics in native CSS.

1. The archive lacks configured compiled frontend CSS. Exact stored settings, UI defaults, PHP transformations, Sass compiler behavior and output-layer configuration remain unobserved together. Source declarations therefore describe intended output under their gates.
2. Traditional grid classes and shadow utility classes are not established by the inspected output imports. Cheatsheets/legacy registries are insufficient. Find a real output generator before claiming emission.
3. The exposed auto-grid aggressiveness CSS property is not read by the two inspected formulas. Any future runtime tuning API must demonstrably change used layout.
4. `--width-full`, the default card selector's trailing comma, null icon size tokens with emitted size selectors, and defined zero icon border-style need configured/default compile and computed-value proof if vendor behavior is being asserted. Record failures as reproducible cases; do not repair vendor code speculatively.
5. Generic public docs can differ from this archive. Keep version-specific source locators with every claim. Resolve direct source/asset reuse terms before copying any implementation.

## Review and delivery

An implementing agent should select the smallest justified subset, confirm live Plane authority/dependencies, and implement under the existing ticket workflow. Attach exact tests and render evidence to that implementation. Do not create speculative future tickets for every local proof ID.

Phase 1 itself requires ten complete source traces, explicit decisions and implementation seams, source-identity/range validation and an independent documentation/source review. It makes no new runtime or accessibility claims. WELL-114 certification, exact-head hosted CI, independent Master Gate and resulting-main proof remain open delivery concerns outside this research assessment.
