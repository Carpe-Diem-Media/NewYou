# Browser compatibility proof plan

Continue WELL-112 / draft PR227 from `70a817dd9ec55326117fa744c9e92e1ba2619742`. This is a verification continuation of the existing design, with no application dependency or visual change. Execute inline under ticket-implement and code-change-verification; requesting-code-review supplies bounded independent review. The owner-authorized WELL-114 continuation exception remains recorded.

## Acceptance criteria

1. Reproduce the registration browser test's accidental compound text enlargement. Snapshot all computed sizes before edits, then assert each targeted element is exactly twice its original size and still reflows with long EN/AF content. Preserve the existing Chromium interaction/error/forced-color proof.
2. Add `test/assets/design_compatibility_browser.mjs`, using existing external Puppeteer tooling with explicit Chrome/Firefox selection. Firefox owns a fresh test profile and removes only that profile after closing. Never use the user's normal profile or silently substitute an engine. No npm/application dependency change.
3. Reuse the actual `verifyLayoutFoundations` export at 320/744/1440px in both engines. Check actual shared card/icon geometry, content rhythm/dividers and root/local overrides. Check fluid candidates at both root sizes and boundaries, and select the shipped trigonometric/static fallbacks through CSSOM without presenting that as an old-browser simulation.
4. Check actual EN/AF registration at narrow/wide allocations and doubled text, native constraints/focus, contextual roles and no-JavaScript HTML/navigation. Make no valid or invalid account POST in the new compatibility runner. Report browser feature probes and exact versions. Unsupported media emulation, WebKit, true browser zoom and screen-reader proof remain explicit exclusions.
5. Independently trace the inherited Hallmark focus report through the document and shadow-root focus chain. Use supported tooling only. No toolbar hiding, body ring, installed-tool patch, config change, Floor waiver or full Hallmark redesign/audit. Record a checker limitation as unresolved rather than a product fix.
6. Add a source-linked compatibility proof addendum and developer entry. Run the relevant browser suites, canonical TEST mix check/check.deep, assets/design and history/whitespace checks on the final candidate. Update PR/Plane with exact outcomes and clean status. Keep independent certification, inherited conflicts and missing hosted checks open; no merge or Done claim.

## Execution

- [ ] In `test/assets/design_registration_browser.mjs`, capture baseline sizes before the existing mutation loop and add `sizes.every(([node, size]) => Math.abs(parseFloat(getComputedStyle(node).fontSize) - size * 2) < .1)`. Observe the existing loop fail before changing its mutation order. Then iterate the snapshot instead of reading sizes after ancestor mutations; retain the assertion.
- [ ] Add the compatibility runner with `DESIGN_BROWSER=chrome|firefox`, `BROWSER_TOOLS_ROOT`, optional `CHROME_PATH`, explicit `FIREFOX_PATH` and `FIREFOX_PROFILE_ROOT`. Reject unsupported engines. Use `mkdtemp`/`rm` only for the unique test profile. Reuse the exported layout verifier rather than copying its formulas; assert public rendered outcomes on the existing guide/registration DOM.
- [ ] Run both engines. Investigate actual failures before changing CSS or expectations. A browser/tool limitation is reported, not silently skipped. Run `design_content_browser.mjs` and the corrected `design_registration_browser.mjs` in Chrome to retain their existing media/interaction proof.
- [ ] Write `docs/development/research/acss-4.0.3-inventory/phase5-compatibility.md` and link it from the inventory/developer guide. Describe exact commands, feature probes, checks and exclusions. This proof-only change maintains the existing presentation-map exemption; business capability maps are untouched.
- [ ] Commit source, refresh live PR/Plane receipts and generated history, then request exact-head independent review. Run required canonical checks, inspect the complete delta, push/link PR227, record final results and leave a clean worktree.

## Commands

Use `ERL_FLAGS='+S 4:4' mise exec -- devcore-project run test --` for mix checks after DevCore doctor. Build through `devcore-project run dev -- mix assets.build`. The running server is port 4237. Browser examples:

```sh
BROWSER_TOOLS_ROOT=/tmp/newyou-refinement-tools DESIGN_BROWSER=chrome CHROME_PATH=/usr/bin/google-chrome node test/assets/design_compatibility_browser.mjs
BROWSER_TOOLS_ROOT=/tmp/newyou-refinement-tools DESIGN_BROWSER=firefox FIREFOX_PATH=/snap/bin/firefox FIREFOX_PROFILE_ROOT="$HOME/snap/firefox/common" node test/assets/design_compatibility_browser.mjs
BROWSER_TOOLS_ROOT=/tmp/newyou-refinement-tools CHROME_PATH=/usr/bin/google-chrome node test/assets/design_registration_browser.mjs
```

Snap Firefox cannot read Puppeteer's default host `/tmp` profile. Its own `snap/firefox/common` allocation is visible. The runner never modifies a normal Firefox profile, OS preferences or shared browser installation. No database cleanup, reset, base merge, vendor copying or new visual treatment is part of this proof batch.
