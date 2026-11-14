# LiveView design-system implementation plan

WELL-112 implements the owner's requested visual reference on branch `t3/newyou-liveview-style-guide`, based on `98fbeb8766ff1d20efe4f4f10baa6fc3abcc62f6`.

The approved scope is the owner's request and WELL-112's eight acceptance criteria. `DESIGN.md` supplies the existing visual baseline. WELL-80's namespaced Tailwind utilities and constrained Phoenix components remain the application API. The reference lives at `/dev/design-system`, compiled only for development and tests. No business state, Ash interface or database schema changes.

## Implementation choices

- Put editable CSS aliases in `assets/css/design-tokens.css`, then map the existing Tailwind theme to them. Preserve all existing values. Record the alias contract in `DESIGN.md` as the deliberate design-system change requested by the owner.
- Resolve CSS-variable references in the palette authority check. Keep mismatch, extra-color, unresolved-reference and cycle detection. Test these guards before changing their implementation.
- Add secondary-button and link primitives using existing approved component definitions. Keep the primary-button API compatible.
- Add `DesignSystemLive`, its HEEx template and reference components. Sections cover palette, type, spacing, buttons/links, cards/icons, layout/responsiveness, shape and color relationships.
- Keep section/grid choices in query parameters. Validate count, alignment and preview values against bounded allowlists. Invalid input falls back safely. These are transient display choices and reset on a new visit.
- Use a small LiveView hook for computed CSS values, contrast measurements, copy actions and viewport measurements. Values come from the browser, not duplicated Elixir or JavaScript constants. Read-only preview iframes use the same stylesheet and semantic components.
- Use existing responsive breakpoints. Centre incomplete rows with a six-track grid: three cards span two tracks each; the last one or two cards shift start columns. At tablet, use four tracks with two-track spans.

## Tasks and evidence

1. Add focused failing tests in `test/new_you_web/live/design_system_live_test.exs` and the existing infrastructure test. Run through `ERL_FLAGS='+S 4:4' mise exec -- devcore-project run test -- mix test <paths>` and confirm the missing route and alias support fail.
2. Implement token aliases and enforcement, then run infrastructure tests. Reuse the existing palette and dimensions; no enforcement exemptions.
3. Implement semantic components, the development route, guide and preview. Run LiveView tests for all sections, URL state, grid counts/centering, invalid input and copy bindings. Verify production route exclusion through compilation of the router with the guard disabled.
4. Build assets and run the guide locally. Run Hallmark's supported app-scope static/render checks and fresh-context finish review. Verify 320/390/744/1128/1440/1920 widths, keyboard focus, reduced motion, button states, contrast and live token propagation. Document actual findings and justified Reflex waivers.
5. Run `mix check`, `mix check.deep`, `mix assets.build` and `git diff --check`. Inspect the complete diff and final SHA. Update `docs/development/design_system.md` with source-linked usage, tests and observed verification. Open a PR and move WELL-112 to In Review after local gates pass. Independent Master Gate and owner merge authorization remain separate.

## Documentation impact

Update the existing design-system guide with a source-linked engineering handoff. This is a developer reference and shared styling extension, with no Domain lifecycle, persistence, asynchronous work or external side effects. A separate Domain vertical-slice map is unnecessary. Describe request/render/event paths, production isolation, transient preview state and the token-editing contract in the existing guide.

## Reconnaissance

Canonical authority is the current docs routers, `AGENTS.md`, `DESIGN.md`, the Frontend Experience System and the existing design-system guide. The current registry identifies ordinary internal copy as Class C JIT copy; the guide does not approve participant copy. The local LiveFrame `AutomaticCSS.FidelityResolver` demonstrates semantic token references for typography, gutters, buttons and foreground/background relationships. It is an implementation reference, not a NewYou dependency or authority. Official version-matched LiveView 1.2 and Tailwind v4 theme documentation were checked.
