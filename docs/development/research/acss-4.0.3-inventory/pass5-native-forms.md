# Next pass 5: shared native form contracts

WELL-112 / draft [PR #227](https://github.com/Carpe-Diem-Media/NewYou/pull/227), continuing from `b7e1787ccb3ddf4f2a76bff5f6712d7ad622b2d9`. The [bounded plan](../../../superpowers/plans/2026-11-15-native-form-contracts.md) implements the approved [native-form pass](next-passes.md#pass-5-extend-native-form-components-from-real-consumers). It preserves existing palette, typography, geometry, exact registration copy and premium CTA definitions. Live authority and resource windows remain in Plane. This does not certify WELL-114, integration or participant release.

## Focused ACSS findings and decisions

The inspected vendor input remains the supplied 4.0.3 archive, SHA-256 `17ee65acfd7e045e73b68f2373a2e4fba5e46ab3fd22ec5cc451472a7f5d63b5`. These locators are relative to `automatic-css/assets/scss/`; they are research inputs, not NewYou runtime paths.

- `dashboard/_options.scss:14` enables the forms module. `modules/forms/_vars.scss:1-23` defines light/dark options, automatic styling, global-token output off by default, primary accent inputs, excluded third-party selectors and WS Form integration. The rest of that file imports element-specific inputs. Enabled inputs do not by themselves prove generated CSS or approved NewYou appearance.
- `modules/forms/elements/checkbox/_vars.scss:1-15` separates checkbox gaps, radius and normal/checked/button/switch colors. The source uses a 4px radius, 6px inline gap and 10px block gap. Those are vendor defaults, not NewYou decisions.
- `elements/help/_vars.scss:1-12` and `elements/fieldset/_vars.scss:1-10`, under the same forms directory, give help and fieldset legends independent type/color roles and `0.5em` gaps. That gap follows the consuming font size. `elements/legend/_vars.scss:1-13` is a separate section-legend contract with its own weight, line height and gap; it should not be conflated with a fieldset label.
- `modules/forms/ws-form/_maps.scss:61-75` maps fieldset/help inputs to WS Form properties. Lines 123-127 map checkbox radius/gaps and choose `1lh` for checkbox size. `1lh` follows the consuming line height. This differs from NewYou's existing fixed token-sized native control and does not justify changing its approved geometry.
- `modules/forms/ws-form/_output.scss:1-44` omits null/empty map values, then emits under the forms gate. Global mode writes both root and `form.wsf-form` because local WS Form styling would win over inheritance. Automatic mode targets WS forms; manual mode requires the form theme classes. The light/dark utilities select color scheme. Button/focus output is imported separately. These selector/platform dependencies are not a standalone native-control API.

Selected source identities:

```text
modules/forms/_vars.scss                    87efc0cdb1c462ab5a516a812b015fe80f2d60d3288ae15edab0acd92ca76544
modules/forms/elements/checkbox/_vars.scss  e4c84368b0f105132addb5d23667488824ccce7a2f5b20ec378a2ea26e3d716c
modules/forms/elements/help/_vars.scss      4814bd12e85d33356a128a903f1a744b0f1ce610fdfd97c3f8f487e0b997aa81
modules/forms/elements/fieldset/_vars.scss  f0897e2c5cba45d15c7cb5062f198afb5fd976bc5de9ede3579d6fdf230a0083
modules/forms/ws-form/_maps.scss            30d60249b93a0c579d1be4d0b0193c86ca7bc3156d43e8eb3d8ddff681a3c295
modules/forms/ws-form/_output.scss          35447b97b44acf174755a62f3503043673ae69f42bc3521bee60106b4391f34f
```

Adapt the separation of field/choice/help relationships and consumer-local derivation. Keep NewYou's existing source values and actual native controls. Defer vendor widget painting, switches, button-like choices, `1lh` size adoption, light/dark form schemes, WS Form selectors, automatic/global form styling and a complete form generator. No vendor source, Sass, WordPress or new dependency is imported. This is a focused trace for the actual consumer, not a claim that every ACSS form element has been implemented or compiler-tested.

## Native behavior and ownership

[`Field`](../../../../lib/new_you_web/components/design/field.ex) now supplies three small helpers. Each accepts already-localized strings; none validates business input, translates copy or owns operation state.

- `design_field/1` keeps native text/email/password, existing flags and password-value omission. Optional help adds `id-help` before the existing `id-error` association. With no help, the prior output contract remains intact.
- `design_checkbox/1` owns one native checkbox with explicit ID, name, value, checked, required and disabled inputs. Default value is the existing literal `true`. Its wrapper is `id-field`, with shared `.ds-design-field.ds-design-choice` classes. One native label contains input/span. Optional actions are siblings outside that label. Help/error paragraphs have deterministic IDs; errors retain `role="alert"`. No hidden unchecked companion is emitted.
- `design_fieldset/1` owns a native fieldset and first legend, with text content only in that legend. Optional help/error descriptions follow its contents. Native `disabled` applies to descendants. The caller may supply `aria-busy` as a projection of its own operation; busy alone does not disable controls or create a component lifecycle.

For a named, form-associated checkbox, successful-control behavior is:

```text
included in FormData = checked AND NOT effectively disabled
submitted value     = the explicit checkbox value
unchecked           = no name/value entry
description IDs     = present help ID, then present error ID, joined by one space
```

The browser owns the current checked property and native constraint behavior. A rendered `checked` attribute supplies the default state, not durable business truth. [MDN's checkbox reference](https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/input/checkbox) documents omitted unchecked values and the distinction between default/current state. Server validation remains authoritative.

A disabled fieldset disables its descendant controls except controls in its first legend. This helper's legend is plain caller text, so it introduces no interactive exception. Test effective state with `:disabled`; a descendant's own `disabled` property can still be false. [MDN's fieldset reference](https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/fieldset) also describes the native grouping and special fieldset formatting box.

Explicit guards reject owned attributes in both atom/string key forms. Checkbox guards include native identity/state, class/style, label/description/validation ARIA, `role`, `aria-checked` and `aria-disabled`. Fieldset owns its role and disabled/description ARIA. Text fields now also reject `aria-disabled` contradicting native disabled state. This is a finite ownership contract, not an exhaustive ban on caller JavaScript; other forwarded Phoenix globals remain caller-owned. Components introduce no click/key handler, event route, storage, timer or business lifecycle.

The first helper review found contradictory forwarded ARIA state could bypass the original guard. Three regressions reproduced the gap, then passed after the narrow guard correction. This differs from the prior surface wording-only question: these attributes restate state explicitly owned by the native form helper. The subsequent helper quality review confirmed no functional issue within its bounded source scope; neither review ran runtime gates or certified merge.

## Token math, geometry and overrides

[design-tokens.css](../../../../assets/css/design-tokens.css) is the input/edit location. Optional `--field-gap`, `--choice-gap` and `--choice-label-weight` stay unset by default. Derived outputs resolve at each matching consumer:

```text
design-field-gap           = field-gap, otherwise space-sm
design-choice-gap          = choice-gap, otherwise design-field-gap
design-choice-label-weight = choice-label-weight, otherwise weight-regular
```

The shared field wrapper consumes the first gap; checkbox help/errors consume the second. Both default to the existing 8px field gap. `--control-gap` remains the separate 16px wrapping-row role. A local field input reaches descendant matching consumers; each recomputes its output. A choice input does not alter fieldset or unrelated row spacing. Edit inputs, not `--design-*` outputs. Use valid nonnegative length gaps and the approved weight roles; arbitrary invalid runtime overrides are not validated by the source gate.

[design-components.css](../../../../assets/css/design-components.css) takes the old pilot checkbox selectors into the shared component layer. Label minimum block size stays `--space-button-height`, 48px. Input size stays `--space-base`, 16px, with `--space-xxs`, 4px, top alignment. Label gap is the existing `--space-md`, 12px; block padding remains `--space-sm`, 8px. Native appearance and primary accent remain intact. A sole label fills the row; an action-bearing row preserves its natural wrapping. Focus retains its existing outline independently of invalid state. No checkbox glyph, custom switch, animation, forced-color override or visual state color is introduced.

Two canonical consumer inputs preserve existing differences. `#registration-age-field` uses the existing medium label weight because the old age label was a direct field child. `#registration-privacy-field` uses `--content-gap`, 24px, between label and error, matching its old stack. Other descriptions retain 8px. `#forms-local` demonstrates existing 16px fieldset and 12px choice gaps. These are approved-source comparisons, not new value tiers. Readouts use the existing computed-style hook; JavaScript supplies no sizing formula.

## Actual consumer and copy preservation

Only the [registration template](../../../../lib/new_you_web/controllers/registration_html/new.html.heex) migrates. It already imports the Field module. Existing IDs/error IDs, form names, true values, required flags, checked restoration, copy calls, order and link destinations are retained. Terms links remain outside the label; privacy explanatory prose stays before its separate checkbox. Preferred language retains its hidden locale input and help ID; the shared fieldset now also names that help association.

All 24 literal copy references in the template match the baseline multiset. The copy registry/page manifest, style guide and glossary were inspected. Existing narrow development consumption is reused; candidate metadata is not promoted into release approval. No governed string or artifact bytes are edited. No controller, Domain, route, acceptance fact, CSRF/operation identifier, autofocus, password handling, validation rule or release gate changes.

Before edits, six static EN/AF baselines were captured at 320/744/1440px. They contain visible normalized text, control names/types/flags/labels and selected rectangles, excluding hidden values and credentials. Chrome compares the extracted page against those snapshots to a 1px geometry tolerance. Portable reruns also compare labels against registry strings with the actual platform-name substitution. Temporary before/after snapshots are supplementary evidence, not runtime content authority.

## Guide and repeatable proof

[`DesignSystemForms.native_forms/1`](../../../../lib/new_you_web/live/design_system_forms.ex) renders `/dev/design-system#native-forms` with the exact shared helpers. It shows long internal EN/AF labels, help, required/checked/invalid choices, an external related action, a native disabled/busy fieldset, a text field with help and local gap comparisons. The isolated application preview excludes this lab. Existing premium CTA definitions and other guide sections retain their owners.

The [pure tests](../../../../test/new_you_web/design_native_form_test.exs) run without application/test_helper/DB startup. The first run failed six missing-helper/help cases before implementation. A later ARIA guard regression failed three cases, then all eight passed. This includes password omission and no-help compatibility. Browser proof first failed `missing shared native-form specimens` before application edits.

The [shared browser helper](../../../../test/assets/design_native_form_contract.mjs) measures native DOM/associations, hit area, control size, disabled fieldsets, root/local gap propagation and reflow. The [dedicated runner](../../../../test/assets/design_native_forms_browser.mjs) prohibits every POST and verifies native Space/Tab, required-choice focus, omitted/checked/disabled FormData entries, unrelated LiveView patch identity/focus, reconnect disabled/busy markup, no-script behavior and exact doubled text. It does not promise durable client choices after remount. Chrome also exercises forced colors/reduced motion. The compatibility runner imports the same contracts with existing typography/layout/content/border/surface/registration checks.

The first Firefox attempt timed out in Puppeteer's no-script `$$eval` utility. A small repeatable probe reproduced the timeout, then returned the same three controls through one direct form query. The runner keeps the full assertion and verifies actual scripting disablement. Exact inherited Firefox DEV reload messages are retained in output under the same narrow policy as the existing compatibility runner; other socket/application errors still fail. WebKit, true zoom, screen readers and Firefox media emulation remain unverified.

At the first checkpoint, Chrome passed 593 assertions, including all six baseline comparisons and zero POSTs. Firefox 160 passed 361 portable assertions with zero POSTs, retaining 12 exact DEV reload diagnostics across repeated navigation/reconnection. It does not reuse Chrome's before-change geometry snapshots or claim media-feature emulation. Eight-file supported guide Hallmark reports zero FAIL/open REFLEX/rejected waivers, two existing waivers and the retained endpoint WARN. Assets, compile with warnings-as-errors, format, design/architecture, eight pure cases, five Node cases and 54 routing/smoke tests pass. Phone/desktop captures were inspected. Final source-bound outcomes belong in the final proof section and PR/Plane; prior surface canonical results are not reused for this changed implementation.

WELL-125 released TEST at 2026-11-15 21:48:46 UTC. WELL-112 has not claimed a fresh TEST or PLT window at this checkpoint. Doctor/focused/canonical/deep checks require a fresh coordinated grant. No reset or manual cleanup is authorized. Existing WELL-114 certification, overall registration/Tidewave Hallmark findings, base conflicts, exact-head hosted CI and independent Master Gate/resulting-main proof remain open.

Repeatable commands, with existing DEV on 4237 and external browser tooling:

```sh
NEW_YOU_PORT=4237 ERL_FLAGS='+S 4:4' mise exec -- devcore-project run dev -- mix assets.build
NEW_YOU_PORT=4237 ERL_FLAGS='+S 4:4' mise exec -- devcore-project run dev -- mix run --no-start -e 'ExUnit.start(); Code.require_file("test/new_you_web/design_native_form_test.exs")'
BROWSER_TOOLS_ROOT=/tmp/newyou-refinement-tools node test/assets/design_native_forms_browser.mjs
BROWSER_TOOLS_ROOT=/tmp/newyou-refinement-tools DESIGN_BROWSER=firefox FIREFOX_PATH=/snap/bin/firefox FIREFOX_PROFILE_ROOT="$HOME/snap/firefox/common" node test/assets/design_native_forms_browser.mjs
```

Documentation impact: these presentation helpers change no Domain capability, durable schema, business interface or lifecycle. A new semantic capability map is exempt. This source-linked note, developer handoff and generated PR history describe the contracts and proof limits. No merge, Done, participant activation or integration certification follows from this continuation.
