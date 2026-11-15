# Automatic.css 4.0.3 module inventory

Phase 1 research, 2026-11-15. Work item WELL-112. This is the entry point for the ten requested module traces and the proposed NewYou implementation decisions. It supplements the earlier [mathematics research](../automatic-css-4.0.3-math.md); it does not replace its historical evidence.

The source baseline is NewYou `4967b498d7413b7530303a64b4027e139e0b6d46` on PR [#227](https://github.com/Carpe-Diem-Media/NewYou/pull/227). No production CSS, token values, components, fonts or dependencies change in this phase. Decisions below concern which mechanisms are worth retaining or adapting. They do not approve visual values or promote candidates into production.

The later [Phase 2 layout implementation notes](phase2-layouts.md) describe guide specimens and their proof. They supplement this source inventory; the catalog below remains tied to its recorded Phase 1 baseline.

## Scope and decisions

Each trace records inputs and defaults, feature gates, formulas, declared token/selector output, dependencies, current NewYou coverage, implementation seams and missing proof. `adopt` means keep an existing narrow pattern; `adapt` means use a relationship through native CSS and existing components; `defer` means the source inventory is complete but there is no current implementation need.

- Grid: **adapt**. Preserve the current fixed grid and last-row centring. Add a small intrinsic recipe only when a repeated consumer establishes its minimum width. See [layout](layout.md#grid).
- Auto-grid: **adapt**. Use bounded intrinsic fitting with explicit count, gap, minimum and fit/fill behavior. The source's emitted aggressiveness variable does not control its inspected formulas at runtime. See [layout](layout.md#auto-grid).
- Shadows: **adapt**. Preserve semantic flat/control/raised/action roles and existing button shine. ACSS shadow tiers are authored layer lists, not a calculated elevation scale. See [shape](shape.md#shadows).
- Radius: **adapt**. Retain approved NewYou shapes. Use concentric arithmetic locally only when real geometry requires it. Defer inverted-radius decoration and broad auto-radius selectors. See [shape](shape.md#radius).
- Gutter: **adapt**. Preserve the current token and give one wrapper responsibility for horizontal padding. A fluid candidate needs endpoint and nested-container proof. See [layout](layout.md#gutter).
- Content width: **adapt**. Preserve the current 1280px cap. Add safe-width relationships at the consuming scope only when needed. See [layout](layout.md#content-width).
- Breakout: **defer**. Seven tracks create four named zones, with cumulative feature lanes. No NewYou page currently establishes the need or approved lane widths. See [layout](layout.md#breakout).
- Icons: **adapt**. Keep Heroicons and native action semantics; add finite presentation options only for repeated usage. Styling does not provide artwork or accessible names. See [components](components.md).
- Cards: **adapt**. Extend the existing semantic card only for demonstrated media/avatar/icon needs. Preserve current variant ownership and native actions. See [components](components.md).
- Data attributes: **adopt selectively**. Continue component-owned visual attributes, native HTML/ARIA states and narrow behavior hooks. ACSS does not establish a universal `data-*` protocol. See [components](components.md).

The canonical machine-readable catalog is [inventory.json](inventory.json). It has ten module records, source locators, dependencies, proof IDs and whole-file source hashes. The [proof plan](proof-plan.md) translates the remaining questions into implementation acceptance steps. These proof IDs are local research identifiers, not invented Plane tickets.

## Source identity and output model

The supplied `automatic.css-4.0.3.zip` has SHA-256 `17ee65acfd7e045e73b68f2373a2e4fba5e46ab3fd22ec5cc451472a7f5d63b5`. All 947 ZIP entries passed CRC verification. That establishes archive integrity, not publisher authenticity. Vendor paths in these documents are relative to `automatic-css/` in that exact archive. The archive remains outside Git; no vendor implementation or asset is included.

The source has separate build-time configuration, CSS token output, utility selectors and default page styling. Trace them separately:

1. `classes/Framework/Core/Core.php:271-339` reads UI metadata and stored values, applies defaults, transforms units and values, and provides compilation inputs. User settings and filters can override the SCSS defaults described here. The live WordPress settings and configured output were not available.
2. `assets/scss/automatic-imports.scss:1-95` gathers options, helpers, module variables, maps and mixins. Sass variables and `!default` operate at build time. They are not interchangeable with CSS custom properties.
3. `assets/scss/modules/_tokens.scss:1-93` gathers token modules. `automatic.scss:4-6`, `automatic-tokens.scss:1-4`, `automatic-variables.scss:1-5`, and helper gates at `helpers/_mixins.scss:133-143` control output paths. A token-output option can differ from a selector-output option.
4. `automatic.scss:22-30` imports card/icon feature output. Its utilities import variable-grid, section and width output plus borders. Content-grid enters outside those layers at lines 74-75. A declared mixin has no effect until an output path calls it.
5. No compiled ACSS frontend stylesheet was found in the supplied package. `automatic-imports_precompiled.scss` is assembled SCSS, not emitted CSS. Cheatsheets and legacy class registry entries alone do not prove selector emission.

The catalog's source references have explicit `acss` and `newyou` origins. ACSS hashes bind to archive bytes; NewYou hashes bind to Git blobs at the baseline SHA. The fields `archive_member` and `git_blob_path` identify external and historical locators, respectively; neither asserts a current repository file link. Line numbers are inclusive and 1-based. Shared entry references and NewYou baseline references apply across the individual module records. Hash validation proves identity and valid ranges; it does not prove the prose's interpretation or browser behavior.

## Authority and implementation boundaries

[Frontend experience authority §8.1-8.4](../../../governance/supporting/FRONTEND_EXPERIENCE_SYSTEM_v1.0.1.md) requires lean native-variable tokens, purposeful reuse, understood states and accessibility. Automatic.css is research material. Do not introduce Sass merely to reproduce it. Keep [DESIGN.md](../../../../DESIGN.md), the [current token contract](../../design_system.md) and existing semantic Phoenix components as the production foundation.

The earlier research records package licence notices and unresolved published terms. This phase records independently described relationships and source locators. It does not resolve direct-source/asset reuse permission. No plugin code is copied or executed. A compiler proof, if later justified, must use an approved isolated setup and remain separate from production adoption.

WELL-112 remains In Progress and blocked by WELL-114's independent post-merge certification in the live tracker. WELL-114 remains In Review. The owner explicitly authorised continued UI work while keeping that gap open. This research neither closes that gap nor supplies merge approval. Required exact-head CI, independent review and resulting-main certification remain separate delivery obligations.

## Public documentation and version differences

Current public documentation provides context, while the supplied archive establishes the inspected 4.0.3 implementation. The [4.x setup guidance](https://docs.automaticcss.com/setup/working-in-acss-4) describes grid tokens and warns against importing 3.x class conventions. The [auto-grid page](https://docs.automaticcss.com/grids/auto-grids) still contains class-oriented examples. Record that difference rather than assuming every documented class is emitted here.

The [public icon framework](https://docs.automaticcss.com/icons/icon-framework) uses a `naked` treatment name; this archive declares `plain`. The [radius recipe](https://docs.automaticcss.com/recipes/border-radius-recipes) adds half the padding, whereas the inspected card framework's standard concentric mode adds full padding. They are separate recipes. Choose the formula from actual component geometry, not a name shared across documentation pages.

The [public content-grid description](https://docs.automaticcss.com/grids/content-grid) names four content zones. The archive implements those through seven tracks. Public documentation is not proof of used track dimensions, nested placement or overflow in any browser.

## Reproducible evidence checks

Use the original ZIP and a normal Python installation. Set `ACSS_ARCHIVE` to its local path without copying the archive into Git. The following read-only check verifies the archive, source-file hashes, reference ranges, module decisions and proof IDs. It does not execute PHP or compile SCSS.

```sh
ACSS_ARCHIVE=/absolute/path/to/automatic.css-4.0.3.zip python3 - <<'PY'
import hashlib, json, os, subprocess, zipfile
from pathlib import Path
root = Path('docs/development/research/acss-4.0.3-inventory')
doc = json.loads((root / 'inventory.json').read_text())
archive = Path(os.environ['ACSS_ARCHIVE'])
assert hashlib.sha256(archive.read_bytes()).hexdigest() == doc['archive']['sha256']
expected = {'grid', 'auto-grid', 'shadows', 'radius', 'gutter', 'content-width',
            'breakout', 'icons', 'cards', 'data-attributes'}
assert len(doc['modules']) == 10
assert {m['id'] for m in doc['modules']} == expected
sources = {s['id']: s for s in doc['sources']}
assert len(sources) == len(doc['sources'])
with zipfile.ZipFile(archive) as z:
    assert len(z.infolist()) == doc['archive']['entries']
    assert z.testzip() is None
    for s in sources.values():
        assert s['origin'] in {'acss', 'newyou'}
        path = s['archive_member'] if s['origin'] == 'acss' else s['git_blob_path']
        assert s['id'] == s['origin'] + ':' + path
        data = z.read(doc['archive']['root'] + path) if s['origin'] == 'acss' else subprocess.check_output(
            ['git', 'show', doc['baseline_sha'] + ':' + path])
        assert hashlib.sha256(data).hexdigest() == s['sha256'], s['id']
        assert len(data.splitlines()) == s['line_count'], s['id']
refs = doc['shared_entry_refs'] + doc['newyou_baseline_refs']
proof = (root / 'proof-plan.md').read_text()
for m in doc['modules']:
    assert m['decision'] in {'adopt', 'adapt', 'defer'}
    detail = (root / m['detail_document']).read_text()
    assert m['dependencies'] and m['missing_proof'] and m['source_refs']
    assert all(p in detail and p in proof for p in m['missing_proof']), m['id']
    refs += m['source_refs']
for r in refs:
    s = sources[r['source']]
    assert 1 <= r['start'] <= r['end'] <= s['line_count'], r
print(f"PASS: {len(doc['modules'])} modules, {len(sources)} source files, {len(refs)} locators")
PY
```

Also run `python3 docs/development/research/design_math_reference.py`, `python3 -m unittest tests.test_foundation_lane_routing tests.test_foundation_smoke`, and `git diff --check`. Before a NewYou handoff, run DevCore doctor and the canonical TEST `mix check`. The deep gate, asset build, browser tests and Hallmark are not new requirements for this documentation-only delta; prior UI evidence retains its recorded limitations. Do not claim these research checks certify candidate CSS, all browsers, accessibility or merge readiness.

## Phase 1 review and observed checks

The bounded independent source/document review found no substantive issue in the ten module traces, formulas, decisions or implementation notes. The reviewer did not run the plugin, compiler or runtime checks. The author subsequently clarified external/archive versus historical Git locators and preserved the already-recorded gutter specimen proof. Those editorial corrections introduce no runtime behavior.

Observed research checks on this documentation delta:

- The read-only archive/catalog command above passed for ten modules, 74 source-file identities and 104 line-range locators.
- The independent arithmetic reference passed 126 assertions. This is arithmetic proof, not CSS layout proof.
- `python3 -m unittest tests.test_foundation_lane_routing tests.test_foundation_smoke` passed 54/54 after the locator correction. Initial runs failed because generic `path` fields and unfenced archive JSON citations looked like current repository links. The final catalog uses explicit external/historical locator fields; no CI checker or repository reference rule was changed.
- Local Markdown link targets and `git diff --check` passed. DevCore doctor confirmed DEV and TEST connectivity without credential disclosure.

The canonical engineering-gate result, final PR head and live delivery state belong in PR/Plane evidence. No fresh rendering, cross-engine, Hallmark or post-merge certification is claimed by this inventory. A documentation-only delta has no new Domain/interface/lifecycle/schema behavior and does not require a new capability map.

Phase 3 implementation: [component contracts, token math, ownership, accessibility and proof limits](phase3-components.md). The Phase 1 source catalog remains historical.
