# Phase 5 browser compatibility proof

This proof-only continuation starts at `70a817dd9ec55326117fa744c9e92e1ba2619742`, after the [content-rhythm implementation](phase5-content.md). It adds evidence for existing recipes, not another ACSS adoption phase. Application CSS, components, copy, legal artifacts, controllers, release gates, palette, fonts and the premium CTA treatment are unchanged. The [six-criterion proof plan](../../../superpowers/plans/2026-11-15-browser-compatibility.md) defines the bounded work.

## Exact text enlargement

The registration test originally read each element's computed size immediately before doubling it. A paragraph enlarged first could pass its new size to a nested link, which was then doubled again. That tested 400% for some links while claiming 200%. This was a verification defect, not a product font-size defect.

A new exact-size assertion failed on the old mutation loop. [The corrected registration proof](../../../../test/assets/design_registration_browser.mjs) snapshots every target's original computed size before changing any ancestor. For each target it now checks `abs(actual - original * 2) < 0.1px`, separately from overflow. All six EN/AF/viewport combinations retain that assertion. The complete Chromium registration proof now passes 111 assertions, including native invalid-submit blocking, deliberately invalid server rejection, error associations, password omission, forced colors and reduced motion. No successful registration is submitted.

Text-size overrides are browser-test stress conditions. They do not simulate every browser/OS zoom mode or promote fluid typography into production.

## Repeatable engine selection

[design_compatibility_browser.mjs](../../../../test/assets/design_compatibility_browser.mjs) uses the existing external Puppeteer setup. It rejects unknown engine names and never substitutes Chrome for Firefox. It makes no registration POST, including deliberately invalid ones. No application package or browser dependency was installed by this batch.

```sh
BROWSER_TOOLS_ROOT=/tmp/newyou-refinement-tools DESIGN_BROWSER=chrome CHROME_PATH=/usr/bin/google-chrome node test/assets/design_compatibility_browser.mjs
BROWSER_TOOLS_ROOT=/tmp/newyou-refinement-tools DESIGN_BROWSER=firefox FIREFOX_PATH=/snap/bin/firefox FIREFOX_PROFILE_ROOT="$HOME/snap/firefox/common" node test/assets/design_compatibility_browser.mjs
BROWSER_TOOLS_ROOT=/tmp/newyou-refinement-tools CHROME_PATH=/usr/bin/google-chrome node test/assets/design_registration_browser.mjs
BROWSER_TOOLS_ROOT=/tmp/newyou-refinement-tools CHROME_PATH=/usr/bin/google-chrome node test/assets/design_content_browser.mjs
```

`DESIGN_SYSTEM_URL` optionally replaces `http://127.0.0.1:4237`. `BROWSER_TOOLS_ROOT` points to the external directory containing package.json/node_modules. Observed tooling is Puppeteer Core 25.17.0, Chrome 155.0.8059.84 and system Firefox 160.0. These are evidence versions, not permanently frozen support policy.

Firefox requires an explicit executable and profile root. The local `/usr/bin/firefox` is a Snap wrapper; this command uses `/snap/bin/firefox` directly. Snap could not read Puppeteer's default host `/tmp` profile. A unique `newyou-design-proof-*` profile under the supplied Snap-visible root launches successfully. The test closes the browser and removes only its own newly created profile, including after failure. It never opens, reuses or edits a normal user profile.

Firefox 160 rejected Puppeteer's BiDi `emulation.setScriptingEnabled` command. For no-JavaScript proof the runner closes its scripted browser, removes its owned profile and launches a second fresh profile with native `javascript.enabled: false`. Chrome uses its supported runtime toggle. Both engines first load a controlled inline-script sentinel and prove it did not execute. The guide additionally proves `window.liveSocket` is absent. Explicit automation can still inspect the resulting DOM/CSS.

## What the runner proves

Both engines pass 6,889 assertions at the source checkpoint:

- The same exported [verifyLayoutFoundations](../../../../test/assets/design_layouts_browser.mjs) runs at 320/744/1440px. It checks actual auto-fit/auto-fill thresholds, incomplete rows, fixed alignment, containers, gutter ownership, breakout lanes, unbroken text and intrinsic media. Its equations are reused rather than copied into an engine-specific fork. The export is only part of the larger original layout runner; this count does not claim that its separate URL/reconnection checks ran in Firefox.
- Actual shared card inset radii follow outer radius minus border and per-axis padding. Heroicons retain nonzero mask artwork, currentColor and named-image semantics. Actual EN/AF prose keeps first/last margins, nested paragraph rhythm, native list markers and internal dividers. Consumer-local role edits isolate siblings, and divided-group geometry matches its margin plus border plus padding without a second flex gap.
- Actual fluid display/body/space/gutter specimens match endpoint interpolation and clamping at 320/480/840/1200/1440px, under 16px and 32px root sizes. Both observed engines report support for relative OKLCH, color-mix in OKLab, trigonometric math and native progress. Removing only shipped progress enhancement blocks selects the shipped trigonometric path; removing both math enhancements selects the shipped static path. This exercises fallback declarations in modern engines, not historical unsupported browsers. Production typography remains fixed.
- Actual EN/AF registration retains native required constraints, the real lit submit button, a loaded Inter face and available 400/500/700 weights. The form reflows at 320/390/744/1440/1920px, under exact doubled text with long content, and when allocated 320px inside a wide viewport. Root content/section/control/font/action edits reach real consumers. All twelve application controls retain native order and solid focus rings of at least 2px.
- At 320px with page scripting genuinely disabled, the guide and both registration locales remain visible and reflow; semantic hr and native language links survive. No account POST or unclassified page error is allowed.

Media-feature emulation is not part of this compatibility runner because Puppeteer's Firefox implementation delegates it to unsupported CDP behavior. The unchanged Chrome content proof passes 69 assertions and the corrected Chrome registration proof passes 111, preserving their existing forced-color/reduced-motion coverage. WebKit, Firefox media emulation, true browser zoom, screen readers, font-swap layout-shift measurement and broader authentication journeys remain unverified.

### Firefox DEV reload diagnostics

Firefox emits two kinds of pageerror message for `/phoenix/live_reload/socket/websocket?vsn=2.0.0`: inability to establish the connection, and interruption while loading. Four such events occurred at the checkpoint. The initial strict error assertion failed on these messages after the UI assertions completed. Their exact cause remains unconfirmed; this batch changes no reload configuration or server code.

The result retains these exact messages in `unresolvedDevReloadErrors`. Only the two observed message forms bound to the configured base URL's exact DEV live-reload socket path are classified separately. Application exceptions, the LiveView `/live` socket, other origins/paths and other network messages still fail the assertion. The scripted guide independently must establish its LiveView connection. This is passing bounded UI proof with unresolved DEV-tool diagnostics, not an error-free Firefox runtime or full compatibility certification. The observation belongs in WELL-112's verification evidence.

## Hallmark focus finding

The installed checker was inspected without modification. Its `sloplint.mjs` supports `--scope page|component|app`, which classifies the target; it does not restrict keyboard probing to a DOM selector. Its renderer's `focusRing()` inspects `document.activeElement` without following `shadowRoot.activeElement`.

At 1440px on both locales, independent inspection and the new Chrome diagnostic show twelve application stops with visible rings, followed by two stops whose document-level active element is `div#tidewave-toolbar`. The actual shadow buttons have their own native outline. The toolbar host has no outline and no normal layout height, so the checker's small-element fallback inspects the parent body and reports body as bare. The runner records the full document/shadow focus chain after the application checks. Nothing is hidden, moved or restyled.

The pilot's source focus rules are in [design-components.css](../../../../assets/css/design-components.css), [design-pilot.css](../../../../assets/css/design-pilot.css), [shared links](../../../../lib/new_you_web/components/design/link.ex) and [shared buttons](../../../../lib/new_you_web/components/design/button.ex). The legacy `.registration-page:not([data-design-pilot]) :focus-visible` rule does not apply to this pilot and is not evidence for its ring.

The developer-toolbar diagnostic targets Hallmark's Chrome runtime only. Tabbing beyond the page in Firefox can transfer focus to browser chrome; `document.hasFocus()` then becomes false and subsequent programmatic focus has no :focus-visible ring. This was reproduced during test development. The application test requires an active document, verifies all twelve product controls, and does not mix that separate Chrome diagnostic into Firefox's next locale. It does not omit an application control or add fake focus styles.

```sh
HALLMARK_PUPPETEER=/tmp/newyou-refinement-tools CHROME_PATH=/usr/bin/google-chrome node /home/jcschoeman96/.agents/skills/hallmark/scripts/sloplint.mjs assets/css/design-tokens.css assets/css/design-components.css assets/css/design-layouts.css assets/css/design-content.css assets/css/design-pilot.css --scope app --genre modern-minimal --url 'http://127.0.0.1:4237/register?locale=en' --url 'http://127.0.0.1:4237/register?locale=af' --json
```

The fresh render still exits 1 with two inherited gate 26a FAILs, two inherited gradient-endpoint WARNs, zero open REFLEX, seven existing waivers and zero rejected waivers. No Floor waiver, body ring, toolbar removal, installed-tool patch or configuration workaround is introduced. This finding is explained but remains unresolved for the mandatory gate. No Hallmark-verified completion is claimed. The source of the inspected renderer has SHA-256 `3af79afa100a9804f248ade24d5128cea4fde1ef6d1a279f1dd935bfe6dc41cd`; the driver has `f8ada364c68a9db4b3dd5784bd416a7c412125e887aeae87d627e072d3848289`.

## Handoff and remaining gates

The only executable changes are browser proof and its measurement correction. No Domain, business interface, lifecycle, schema, persistence or participant copy changes. This source-linked proof addendum maintains the existing presentation-only semantic-map exemption. Generated PR history is refreshed before exact-head independent review. Final canonical check/check.deep results, exact head, live issue states and hosted CI are recorded in PR/Plane rather than pre-awarded here.

The first five proof-plan criteria have bounded local evidence. The sixth remains partial while mandatory certification/delivery gaps are open. WELL-114 independent resulting-main certification, inherited PR conflicts, required hosted CI and independent Master Gate remain unresolved. The current branch's prior 656-test pass is historical evidence until fresh checks run at the new head. No merge, Done transition, release or broader WELL-131 delivery follows from this proof.
