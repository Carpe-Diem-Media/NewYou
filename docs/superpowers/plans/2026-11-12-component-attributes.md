# Controlled component attributes

The owner approved this bounded convention in the current WELL-112 continuation.
Keep native CSS, Tailwind v4 and the existing visual tokens. Classes identify
components and layout. Components emit allowlisted data attributes for approved
variants. Native HTML and ARIA describe interaction state. Existing appearance,
copy, fonts, routes and Domain behavior stay unchanged.

Implementation choices are JIT within the existing guide/components scope.
Primary and secondary button functions keep their existing APIs and emit
`data-variant="primary"` and `data-variant="secondary"`. The card accepts only its
existing `flat` appearance. Tailwind data variants select existing token utilities
inside the component modules. No additional stylesheet or SCSS build step is needed.
Reject caller-owned `class` and `data-variant` attributes, including atom/string
keys in forwarded maps. Preserve arbitrary unrelated data attributes and native
HTML, ARIA and phx-* attributes. Do not create data-disabled or data-hover state.

## Execution

- [x] Add regression tests in `test/new_you_web/design_system_infrastructure_test.exs`
  for emitted variants, unsupported card variants, controlled-attribute collisions,
  native disabled false/true, and preserved ARIA/LiveView/custom data attributes.
  Confirm failures before changing implementation.
- [x] Update `lib/new_you_web/components/design/button.ex` and `card.ex` to emit and
  consume those attributes without changing the public button call sites.
- [x] Update LiveView/browser assertions to select semantic attributes rather than
  internal utility classes. Check hover, native disabled semantics, token
  propagation, narrow layouts, existing grid alignment and visible keyboard focus.
- [x] Document ownership, specificity, responsive rules and native-state semantics
  in `docs/development/design_system.md`. This is an internal presentation
  refactor with no material capability/lifecycle/schema change; a new capability
  JSON map is exempt. Refresh the required generated PR history.
- [ ] Run focused ExUnit tests, assets build, design enforcement, canonical
  `mix check`, `mix check.deep`, existing browser checks and supported Hallmark
  lint. Review the complete PR diff and exact candidate, then request an independent
  bounded source review. Record observed failures without widening the task into
  TEST fixture repair. Update draft PR #227 and Plane evidence, preserving the
  WELL-114 dependency and owner continuation exception.

No merge or delivery-completion claim is authorised. Independent resulting-main
certification for WELL-114 remains open. Current main was inspected at
`c7f538251c1c703feb957eabc51bc56fe5f4872d`; its new recovery-message work does not
change this component seam. The continuation starts from `b80e391` on draft PR #227.

## Observed result

Implementation source: `4ee2ecfa4d8a5cbc2b275f8a62d2c0ba423e54b2`.
Focused ExUnit 32/32, assets build, design enforcement, deep gate, four Node
contrast tests, 54 routing/smoke tests, guide browser and typography browser pass.
Guide Hallmark reports 0 FAIL/open REFLEX/WARN and the existing numeric-weight
waiver. Bounded independent source review reports no actionable findings.
Canonical fast gate exits 2 after 371.4 seconds, with 635/636 tests passing.
The unchanged password-session rollback test fails a global token-count assertion;
its isolated retry passes 1 test with 16 excluded. The full-suite cause remains
unproven and recorded under WELL-114. Hosted CI and independent resulting-main
certification remain separate gates. The final verification step records an
attempt and evidence, not a successful delivery certification.
