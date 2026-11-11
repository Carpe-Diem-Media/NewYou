# Design-system refinement implementation plan

> For agentic workers: use subagent-driven-development for the bounded guide implementation and independent spec/quality reviews. Keep root-owned CSS/token enforcement separate from guide markup and browser measurements.

Goal: extend the existing development guide with OKLCH color representation, explicit color-mix relationships, labelled surface-treatment candidates and bounded fluid token comparisons.

Architecture: preserve the current palette's rendered sRGB values, canonical component styling and production route exclusion. All actual values stay in design-tokens.css. New fluid and surface candidates are reference specimens until explicitly adopted into application components. Browser JavaScript measures CSS, never supplies responsive styling.

Tech stack: Phoenix LiveView, Tailwind v4, CSS custom properties, existing browser hook, ExUnit and external Puppeteer tooling. No packages, Domain resources or migrations.

## Execution exception

The owner explicitly authorized UI implementation while WELL-114's independent post-merge certification remains open. Keep that gap recorded; no merge, Done or overall delivery-completion claim. Integrate merged main 5a6b819 to obtain its test-isolation fixes; never reset shared databases.

## Task 1: Tokens and authority, root-owned

Files: DESIGN.md; assets/css/design-tokens.css; lib/mix/tasks/design.check.ex; test/new_you_web/design_system_infrastructure_test.exs.

- [ ] Write tests proving canonical OKLCH tokens retain the exact authorized color representation, reject altered/unapproved colors and retain cycle/unknown-reference checks.
- [ ] Run focused ExUnit and observe the expected failure before implementation.
- [ ] Declare palette sRGB source tokens once. Use identity relative OKLCH conversion behind a feature check, retaining sRGB aliases in unsupported browsers. Extend enforcement only for that exact identity conversion, not arbitrary relative transforms.
- [ ] Declare candidate opaque tint/shade, alpha scrim, gradient and seeded noise tokens. Mix only existing palette roles; preserve explicit hover color and flat canonical cards. Map candidate gradient to Tailwind's background-image namespace.
- [ ] Declare 30rem/75rem viewport bounds, a static-minimum fallback, a feature-detected trigonometric normalized value and native progress enhancement. Interpolate independent semantic candidate tokens: display 2.5rem/4rem, body 1rem/1.125rem, section space 1rem/3rem and gutter 1rem/1.5rem. Keep fixed application typography unchanged and retain rem-based zoom behavior.
- [ ] Document the intentional guide-only visual extension in DESIGN.md before using the new tokens. No replacement of the brand or production copy.

## Task 2: Guide and measurements, delegated bounded task

Files: lib/new_you_web/live/design_system_components.ex; lib/new_you_web/live/design_system_live.html.heex; assets/js/design_system.js; test/new_you_web/live/design_system_live_test.exs; test/assets/design_system_test.mjs; test/assets/design_system_browser.mjs.

- [ ] Add failing LiveView tests for new section anchors, candidate status, token identities and static/no-JavaScript-safe specimens.
- [ ] Add color relationships using --design-surface-tint and --design-surface-shade. Give gradient/noise/scrim specimens usage limits and no misleading whole-background contrast score.
- [ ] Add fluid comparisons with minimum/current/maximum readouts for display/body/space/gutter. CSS controls all sizing. Add concise capability and active-fallback readouts from actual computed CSS.
- [ ] Harden canvas sampling against invalid colors and unavailable contexts; keep contrast limited to opaque colors. Scope measurement output to the real specimen. Ensure cleanup of listeners/observers and copy behavior survives LiveView patches.
- [ ] Extend meaningful browser regression coverage for original sRGB color preservation, color-mix dependency updates, fluid endpoints/intermediate widths, viewport-bound edits, static/trig/native tiers, root-font enlargement, no-JavaScript display, reduced motion, focus, no overflow and original grid/iframe behavior.
- [ ] Root runs tests after CSS integration; fix introduced failures, then obtain fresh spec review followed by quality review.

## Task 3: Verification and evidence

Files: assets/css/design-system.css; docs/development/design_system.md; existing draft PR #218 and WELL-112 evidence.

- [ ] Style the added specimens using declared tokens and existing responsive composition. Preserve phone reflow, keyboard focus, warm canvas, flat cards and semantic action hierarchy.
- [ ] Run `node --test test/assets/design_system_test.mjs`, focused ExUnit, `mix assets.build`, browser tests, `mix check`, `mix check.deep`, `git diff --check` and complete final diff inspection.
- [ ] Run installed Hallmark app-scope lint/render on affected CSS and the development route. Fix introduced FAILs and record concrete REFLEX waivers; do not initiate redesign or theme selection.
- [ ] Update the existing implementation guide with token ownership, candidate status, progressive enhancement, observed commands and exact limitations. Inspect the complete final diff and record the exact implementation head.
- [ ] Update the draft PR and link it immediately after push. Keep WELL-114 certification open. No merge or completed-delivery claim; report observed verification and remaining exact-head CI/review requirements.
