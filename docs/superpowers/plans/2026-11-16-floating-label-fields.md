# Floating-label field implementation plan

> Execute within WELL-112 using the existing shared field and guide. The owner approved this design and requested implementation. Continue source work under the recorded WELL-114 exception; do not infer integration or completion authority.

**Goal:** Add opt-in floating labels inside native text, email and password controls, with canonical tokens and development-guide examples.

**Architecture:** `Field.design_field/1` keeps its stacked default and accepts `label_placement="floating"`. A real wrapping label contains a label span and the native input. Both remain in normal grid flow so long labels increase control height. CSS moves/scales the label using native focus, value and autofill selectors. No JavaScript value mirror, new validation, copy rewrite or production migration.

**Stack:** Phoenix components, LiveView guide, Tailwind v4, canonical CSS, ExUnit and the existing Puppeteer browser harness.

## Contract

- Empty and unfocused rests inside. Focus, a nonempty value or browser autofill raises the label. Clearing and blurring restores the resting state.
- A component-owned blank placeholder supplies the CSS empty-value cue, never the accessible name. Reject conflicting placement/placeholder overrides.
- Text/password/email keep native semantics, help/error descriptions, required/disabled/readonly state and caller event attributes. Password values are never rendered back.
- Wrapper boundaries and focus use existing tokens. Label size/scale, spacing and transition duration resolve in canonical CSS. Reduced motion removes movement. Forced colors retain native focus.
- Keep the input's existing 58px minimum, allowing growth for long labels and 200 percent text. Do not notch or interrupt the border.
- Guide examples show English/Afrikaans, empty/filled/password/invalid/readonly/disabled and inherited fieldset disabling. Existing registration markup and default component geometry remain unchanged.

## Tasks

- [x] Add `DesignFieldTest` cases for valid/invalid placement, label/input associations, placeholder ownership, password omission and unchanged stacked defaults. Run the focused suite and observe RED before implementation.
- [x] Extend `lib/new_you_web/components/design/field.ex`; append scoped CSS to `assets/css/design-forms.css`; define local-resolving roles in `assets/css/design-tokens.css` and record the approved extension in `DESIGN.md`.
- [x] Extend `lib/new_you_web/live/design_system_forms.ex` with `#floating-labels` specimens and usage guidance. Add focused render assertions.
- [x] Add `test/assets/design_floating_fields_browser.mjs` for actual focus/fill/blur/clear, autofill, long-label reflow, 200 percent text, reduced motion, no script and LiveView patch/reconnect. Block POST requests. Recheck unchanged registration focus.
- [ ] Run formatting, focused ExUnit, design enforcement and assets build. Run supported Hallmark static/render checks against affected CSS/guide, distinguishing inherited findings. Request bounded source review, fix introduced issues, document exact proof and residual gaps in the existing handoff.

## Proof commands

Use pinned Mise and DevCore profiles. Component-only ExUnit may run through `mix run --no-start` with an explicit ExUnit runner to avoid application/DB startup. Run the browser script with the existing `BROWSER_TOOLS_ROOT` and DEV guide at port 4237. No new dependencies or DB preparation.

The final full gate, deep gate, OCR and current-head hosted CI remain delivery requirements. Do not repeat a known inherited failing broad suite solely to rediscover WELL-114. A source implementation is not certified delivery while that dependency and the recorded Hallmark/tooling gap remain open.
