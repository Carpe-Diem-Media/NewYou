# Overhead lighting for NewYou

Status: proposed for owner review. This document changes no runtime styling and
does not replace DESIGN.md. It records the owner's request for a more dimensional
system with light from above, directional borders, restrained shadows and a more
distinct primary CTA. Implementation starts after review of this proposal.

Baseline: `e5d16610b99f36a31ba73a181590b93864d51cb6`, WELL-112 / draft PR #227.
WELL-114's certification gap and the owner-authorized UI continuation exception
remain open. This proposal is not delivery or merge certification.

## Recommended direction

Use soft depth. Surfaces have small lightness differences, one-pixel directional
edges and short downward shadows. The CTA has a shallow blue gradient and a fine
highlight. Keep the existing font, button height, corner shapes and blue identity.

Alternative: a stronger bevel with a darker lower band and more visible shadow.
It makes controls more prominent but competes with content and is not recommended
as the default. A glossy highlight stripe or animated shine is excluded.

## Surface hierarchy

The lowest neutral background is darkest. A panel is lighter than its surrounding
canvas; a raised neutral surface is lighter again. Use semantic surface roles,
not numeric CSS z-index values, to select the treatment. Arbitrary stacking order
must not change a colour automatically.

Proposed candidate roles, derived from existing palette tokens in Oklab:

- `--surface-canvas`: 96% existing `--canvas`, 4% `--secondary`.
- `--surface-panel`: 50% existing `--canvas`, 50% `--surface`.
- `--surface-raised`: existing `--surface`.

These percentages are proposed starting values for visual and contrast review.
They are not additions to the authored brand palette. Text keeps its existing
semantic ink role. Blue CTAs remain chromatic controls with their own directional
lighting; the neutral-surface lightness sequence does not turn them white.

A raised surface must not create unnecessary nested cards. Static content can
use the panel fill and directional edge without a cast shadow.

## Border direction and shadows

Keep one-pixel borders, drawn inside the existing box size. Raised components use
a lighter upper edge, quiet side edges and a darker lower edge. Candidate edge
colours derive from the existing white surface and secondary ink:

- `--edge-highlight`: surface at 70% opacity.
- `--edge-side`: secondary ink at 10% opacity.
- `--edge-shade`: secondary ink at 18% opacity.

Use these as decorative material cues. Preserve existing functional input
boundaries and visible focus indicators; do not replace them with faint edges.

Proposed shadow roles:

- `--shadow-flat`: none, for ordinary content and adjacent sections.
- `--shadow-control`: 0 horizontal, 1px downward, 2px blur, secondary ink at 8%.
- `--shadow-raised`: 0 horizontal, 3px downward, 8px blur, secondary ink at 8%.

No upward cast shadows or shadow on every card. Use the smallest applicable role;
the broader shadow is reserved for genuinely raised/overlapping content. No
independent hardcoded box-shadow declarations in feature templates.

## Primary CTA

Keep the current 48px height, 32px radius, font, padding and white label. The whole
outline remains blue; the light upper edge is a fine highlight within that outline.

The proposed default gradient runs vertically, top to bottom:

- `--action-primary-top`: 96% `--primary`, 4% `--surface`.
- `--action-primary-bottom`: 94% `--primary`, 6% `--secondary`.
- `--action-primary-edge-light`: 78% `--primary`, 22% `--surface`.
- `--action-primary-edge-dark`: 82% `--primary`, 18% `--secondary`.

The face uses the first pair; the rim uses the second pair. Add the short control
shadow and a one-pixel inset upper highlight. Avoid a thick bevel, glow, text
shadow, animated sheen or added icon solely for decoration.

Hover derives the same treatment from the existing approved `--primary-hover`
source. The existing separately authored hover source remains explicit in the
editing contract; it does not silently become a derivative of `--primary`.

Pressed removes the cast shadow and uses a dark inner upper edge with a light
inner lower edge. This is the recessed exception to the raised-edge rule. Keep
the label and control bounds stable. Focus-visible keeps the existing accessible
outline, independent of the highlight. Native disabled controls do not receive
hover/pressed decoration. Loading, when a component supports it, preserves width
and uses actual state/ARIA rather than decorative data attributes as authority.

Secondary buttons remain quieter. Keep their neutral outline and apply only the
shared directional-edge treatment, with no blue fill or promotional gradient.

## Token and component ownership

Author candidate values once in `assets/css/design-tokens.css`. Semantic aliases
and Tailwind expose them to the shared components; no Sass dependency is needed.
Components own any bounded treatment attributes and their styling. Callers cannot
inject border, gradient or shadow values through visual options.

After approval, add an explicit owner amendment to DESIGN.md identifying which
flat/no-shadow rules this treatment supersedes and where it applies. Keep the
original flat card available. Compare flat and proposed raised treatments in the
development guide before migrating a bounded production page. Do not globally
retint legacy screens or silently create dark-mode/error variants.

## Acceptance and verification

- The guide compares existing flat, proposed raised and pressed/recessed examples
  on the same warm background, including default, hover, focus and disabled CTA.
- Neutral lightness increases at each declared surface level. Border direction
  and shadow offsets follow the rules above, without changing layout or targets.
- Button text meets at least 4.5:1 against the actual background behind its label
  throughout default, hover and pressed gradients. Check gradient samples across
  the label area and any composited highlight, not just named endpoint tokens.
- Preserve functional non-text contrast and visible focus. Decorative bevels
  cannot substitute for control identification or keyboard focus.
- Check 320px reflow, long labels, 200% text resizing, keyboard use, reduced motion,
  forced colours and gradient/colour-mix fallbacks. Flat solid fills remain usable
  when decorative effects are unavailable.
- Apply existing design enforcement, focused component/browser regressions,
  supported Hallmark checks and repository engineering gates. Measure actual
  rendered colours before treating the proposed percentages as locked values.

## Review boundary

The owner request authorizes developing this direction. Exact material values
remain proposed. No production CSS, shared component implementation or canonical
visual authority has changed in this proposal. The next decision is whether to
adopt the recommended soft-depth treatment as the candidate to implement and
review in the guide, or use a stronger bevel instead.
