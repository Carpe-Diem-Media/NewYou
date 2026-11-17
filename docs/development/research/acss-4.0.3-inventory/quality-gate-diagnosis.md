# Hallmark field-boundary and DEV focus diagnosis

WELL-112 / Draft [PR #227](https://github.com/Carpe-Diem-Media/NewYou/pull/227).
The original diagnosis used unchanged application/CSS source from
`86461db98051fbd901b1e6b6953af42eb76b732b`. That continuation improved one standalone
browser proof and documented detector limits. It did not change approved appearance, native semantics, installed lint,
waivers, governed copy, application behavior or database fixtures.

The later [floating-field composition corrections](../../design_system.md#floating-field-composition-corrections)
change two CSS selectors and extend the permanent browser runner. The hashes and
counts in this original diagnosis/evidence JSON describe its recorded checkpoint,
not the later runner. Current delivery status belongs in Plane and the PR.

The [evidence JSON](quality-gate-diagnosis-evidence.json) retains safe measured
results, exact commands and local log/tool hashes. Raw private reports are not
substitutes for independent review. The [coverage index](../../design_system_coverage.md)
separates actual consumers, guide candidates and remaining delivery work.

## Field edge, gate 40

The supported guide render reports `input.ds-design-field-input 1.00:1` at
1440px. Source inspection of installed Hallmark 2.0.0's
`scripts/sloplint-render.mjs:1141-1153` shows that it does inspect ancestors,
but only while each ancestor is at most `input height + 48px` high.

[Field.design_field/1](../../../../lib/new_you_web/components/design/field.ex)
puts the native input inside a real wrapping label. The label owns the full
border/fill/click target; its in-flow label row can grow for long content.
[design-forms.css](../../../../assets/css/design-forms.css) intentionally gives
the inner input no border and a transparent background.

The long AF field at 1440px measures:

- Chromium input 25.1875px, wrapping label 93.5625px.
- Firefox input about 25.2px, wrapping label about 93.6px.
- The Chromium ancestor limit is 73.1875px, so its visible wrapping border is
  outside the detector's traversal. The corresponding Firefox limit is also
  exceeded. Narrower allocations and doubled text increase this difference.

The earlier browser proof measured the border against its inside fill. That
was useful but did not establish the outside contrast stated by Hallmark.
The [updated permanent runner](../../../../test/assets/design_floating_fields_browser.mjs)
now independently resolves the actual opaque outside surface and compares all
four solid border sides with it. It walks transparent ancestors and refuses a score for translucent border paint
or unsupported image/translucent/opacity/filter/blend surroundings. Alpha border
paint also depends on background-clip, so this bounded proof does not guess it. It does not assume a white background or certify arbitrary images.

A negative control changes only the browser fixture's outside background to the
border color. The old inside measurement still passes, while the new outside
measurement must report under 1.01:1. This assertion failed before the new
measurement existed. The fixture's original inline style is restored in `finally`,
then the baseline must pass again. A second RED assertion required translucent
border paint to be explicitly unscored. After adding that guard, both complete
runners pass the refusal case and restore the original border style.

The complete runner passes 100 Chromium and 98 Firefox checks. It measures all
eight floating controls at 320/390/744/1440px and the enlarged long label at each
width. The lowest outside-edge ratio is 5.7263:1 in both engines. No field design
or production CSS changed. The original 3:1 outside-edge evidence gap is closed
for these opaque specimens, but the installed Hallmark FAIL remains unchanged.

## Keyboard focus, gate 26a

Both supported registration locale renders report
`body "Development Platfo"`. The installed `focusRing` at
`scripts/sloplint-render.mjs:354-373` initially excludes the body/document root.
However, when an active host has a dimension under 4px, it substitutes a label
or parent and does not repeat that exclusion. It does not descend through the
host's shadow root to the actual focused control.

A fresh 1440px native-Tab probe records:

- Stop 13 is the registration submit button, with a solid 2px focus outline.
- Stops 14 and 15 have `document.activeElement` equal to `#tidewave-toolbar`.
  Its host is 1440px wide and zero height; Hallmark substitutes its parent BODY.
- The actual shadow-root active descendants are toolbar BUTTONs. Both report
  `:focus-visible`, an `auto` outline and 1px outline width. This probe does not
  certify toolbar outline contrast or enlarge its styling contract.
- Stop 16 is the document body; the function's initial root guard returns null
  at that point. The misleading BODY finding originates at the preceding host
  substitution, not a missing product control or the final body stop.

The permanent [registration focus proof](../../../../test/assets/design_registration_focus_browser.mjs)
checks all 13 product stops forward/reverse across EN/AF and 320/744/1440px,
including ring-removal negative controls. Its recorded run passes 458 checks
and handles the DEV/document boundary separately. No synthetic tab stops,
body outline, toolbar suppression or altered focus sequence is introduced.

## Review and remaining disposition

A bounded independent source review identified the ancestor-height cutoff and
the missing outside comparator, recommended the proof correction and found no
established product focus defect. The fresh rendered measurements above refine
its initial diagnosis of the BODY finding. The reviewer did not run these
commands or certify the final head or Master Gate.

The smallest tooling correction would allow the real wrapping native-label
boundary without a fixed height cutoff, and inspect the actual shadow active
element before falling back from a zero-height host. Such changes belong to the
installed tool's owner or an approved supported version. This ticket does not
patch that installation or publish to an external repository.

The owner explicitly accepted the measured border-contrast and shadow-aware
focus checks as alternate evidence for these two detector limitations on
2026-11-16. Both automated FAILs remain recorded; there is no Hallmark-green or
Hallmark-verified completion claim. The exception covers only this documented
unchanged UI and these two reports. It does not waive other quality requirements,
current-head CI, OCR or independent Master Gate, and is not merge authorization.
Changed UI inputs require fresh applicable proof. This explicit disposition
removes the former prerequisite to OCR; passing CI alone did not do so.

## CI evidence-locator correction

Hosted run 43954286122 on `903cb15` passed application check/deep and the Hex
audit, but four Smoke assertions rejected the external installed-tool location
under JSON's reserved repository-reference key `path`. The evidence record now
uses `workstation_locator` with an explicit external scope, retaining its actual
location and tool hash. No repository-reference validation or exemption changed.

The existing `test_smoke_passes_both_current_routers` reproduced RED, then passed
after the correction. All 17 Foundation Smoke tests and 79 routing/capability/
knowledge-capture tests pass, plus the 77-assertion current authority smoke audit
and seven map validations. This corrects the evidence schema only; application,
browser-proof and installed-tool inputs remain unchanged. New-head hosted proof
and generated PR history still bind separately. The earlier lightweight link/
hash checks did not cover this reserved-key contract and were insufficient.

## Verification scope

The only executable change here is the standalone floating-field browser runner.
Its full Chromium/Firefox reruns verify the affected proof. Application, CSS,
Mix configuration, ExUnit, architecture and dependency inputs are byte-identical
to the passing 892-test/deep candidate. No duplicate DB-backed engineering gate
was run solely for this proof/documentation correction. The existing application
result and exact new-head hosted CI remain separately identified.

Documentation impact: no Domain/interface/schema/lifecycle changed, so there is
no new capability map. This focused proof note, source hash, current index and
mechanical PR history maintain the existing handoff. There is no new whole-PR
OCR exemption. No merge, release, Done or production-adoption claim follows.
