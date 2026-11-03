# Design-system development

## Authority chain

DESIGN.md
    ↓
assets/css/design-tokens.css
    ↓
Phoenix semantic components
    ↓
feature templates and LiveViews

The canonical lane defines new and deliberately migrated UI. The compatibility lane preserves existing NewYou behavior until each scope is migrated:

assets/css/tokens.css and existing legacy UI
    ↓
grandfathered temporarily
    ↓
incremental migration
    ↓
DESIGN.md + executable tokens + semantic components

## Authority levels

**CANONICAL**

- DESIGN.md is the authority for every visual concept and state it defines.
- assets/css/design-tokens.css maps those concepts into namespaced Tailwind v4 theme utilities. It is executable representation, not a second source of truth.
- The approved Inter fallback is used because the source font is not present; its line-height values apply DESIGN.md's approximately 5% increase to the extracted values.
- New recurring visual primitives use semantic Phoenix components, beginning with NewYouWeb.Components.Design.Button.primary_button/1.
- New tokens or design primitives require an explicit authority change in DESIGN.md first.

**TEMPORARY COMPATIBILITY**

- Existing values in assets/css/tokens.css may support currently undefined dark-mode and form validation/error states.
- This compatibility applies only to existing tokens and states. Do not create a new dark or error visual state by inference.
- Existing dark-mode and validation behavior is preserved. Neither is migrated to DESIGN.md.

**LEGACY IMPLEMENTATION**

- Existing DaisyUI classes/themes and default Tailwind visual utilities are grandfathered where they already occur.
- Legacy styling is frozen against new use. DaisyUI is not design authority.
- Existing screens are not required to pass a repository-wide migration before new canonical UI can land.

## Tailwind and enforcement

Tailwind 4 remains CSS-first. Utilities with the design- namespace expose the project tokens. Use Tailwind for structural layout, state variants, and the project breakpoints defined from DESIGN.md: design-tablet at 744px, design-desktop at 1128px, and design-wide at 1441px (the first whole CSS-pixel width above 1440px).

Tailwind's default theme namespaces remain available to grandfathered code because clearing them globally would alter current pages and DaisyUI components. New or increased design bypasses in changed Phoenix frontend and asset source fail mix design.check, which is part of mix check. The check compares changed files with the base revision; local runs use the merge base with origin/main, and CI supplies DESIGN_SYSTEM_BASE_SHA. There is no inline disable. Existing violations remain tolerated until their class/value count increases.

The check targets class and style contexts. It rejects arbitrary visual values, default palette and DaisyUI classes, unapproved typography/spacing/radius/shadow utilities, default Tailwind breakpoints, raw visual CSS declarations, and light design-token overrides inside dark-mode variants. Layout and accessibility utilities remain available.

## Component and accessibility rules

- Prefer semantic Phoenix component variants for recurring UI; callers do not supply colors, radii, typography, shadows, or raw class lists to design components.
- Preserve native elements, ARIA attributes, form semantics, and LiveView phx-* bindings.
- Keep browser focus indication; do not add outline-none without an approved visible focus treatment.
- The primary button preserves its native disabled attribute. DESIGN.md does not define a disabled appearance, so a new disabled visual treatment requires an authority decision first.
- Do not add brand font files or illustrations. The token layer uses the Inter fallback explicitly approved by DESIGN.md; no font asset is downloaded.

## DaisyUI migration status

DaisyUI can coexist with the canonical layer while existing components remain grandfathered. Its component classes carry visual styling, so globally retheming it to project colors would change existing pages. The least disruptive path is progressive replacement of DaisyUI visual components in deliberately migrated scopes. Retaining DaisyUI as behavior-only infrastructure would require separating its visual rules and verifying each migrated component; WELL-80 does not perform that work.

## Hallmark

/hallmark consumes the existing design system. It is not a design-authority or enforcement boundary.

    /hallmark

    Use the root DESIGN.md as the locked design authority.

    Preserve the existing Phoenix/LiveView architecture and behaviour.
    Preserve HEEx bindings, events, forms, routes and accessibility semantics.
    Use existing semantic Phoenix design components first.
    Use only approved project design tokens.
    Do not invent colours, typography, radii, shadows or spacing tokens.
    Do not expand DaisyUI styling.
    Do not introduce React, Vue, Svelte or another frontend framework.
    Do not alter Ash resources, policies, actions or other domain logic.
    Do not fill dark-mode or validation gaps through guesswork.
    If the requested design requires a token/component/state not authorized by DESIGN.md or the existing compatibility tokens, STOP and report the missing design decision.

The initial sloplint pass reports four REFLEX findings and no FAILs: it recommends tinting the explicitly specified white surface/on-primary and black on-canvas tokens, and counts numeric font-weight tokens (and Tailwind's imported Georgia default) as extra font families. Those color values map directly to DESIGN.md; Inter is the approved single project fallback, while legacy framework font defaults remain grandfathered.

## Migration state

WELL-80 establishes the infrastructure only. Existing pages, forms, layouts, dark mode, validation/error styling, and DaisyUI usage remain unchanged. Migrate those scopes in separate reviewed work. Dark-mode authority, validation/error authority, and the remaining in-app product visual system are follow-up design decisions.
