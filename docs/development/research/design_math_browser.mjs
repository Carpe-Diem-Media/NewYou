// Read-only research proof against existing guide CSS; no application dependency.
import assert from "node:assert/strict"
import {createRequire} from "node:module"
import {resolve} from "node:path"

const require = createRequire(resolve(process.env.BROWSER_TOOLS_ROOT || ".", "package.json"))
const browser = await require("puppeteer-core").launch({
  executablePath: process.env.CHROME_PATH || "/usr/bin/google-chrome",
  headless: true
})
const base = process.env.DESIGN_SYSTEM_URL || "http://127.0.0.1:4237"
const page = await browser.newPage()
let checks = 0
const errors = []
page.on("pageerror", error => errors.push(error.message))
const close = (actual, expected, label) => {
  assert.ok(Math.abs(actual - expected) < 0.05, `${label}: ${actual} != ${expected}`)
  checks++
}
const roles = {display: [2.5, 4], body: [1, 1.125], space: [1, 3], gutter: [1, 1.5]}
const measure = () => page.evaluate(() => {
  const properties = [["display", "fontSize"], ["body", "fontSize"],
    ["space", "paddingBlockStart"], ["gutter", "paddingInlineStart"]]
  return Object.fromEntries(properties.map(([role, property]) =>
    [role, parseFloat(getComputedStyle(document.querySelector(`#fluid-${role}`))[property])]))
})

try {
  await page.goto(`${base}/dev/design-system`, {waitUntil: "networkidle0"})
  for (const root of [16, 20, 32]) {
    await page.evaluate(root => document.documentElement.style.fontSize = `${root}px`, root)
    for (const width of [320, 480, 840, 1200, 1920]) {
      await page.setViewport({width, height: 900})
      const actual = await measure()
      const p = Math.max(0, Math.min(1, (width - 30 * root) / (45 * root)))
      for (const [role, [low, high]] of Object.entries(roles)) {
        close(actual[role], root * (low + p * (high - low)), `${role}, root ${root}, width ${width}`)
      }
    }
  }

  await page.evaluate(roles => {
    const root = document.documentElement
    root.style.fontSize = "16px"
    for (const [role, [low, high]] of Object.entries(roles)) {
      root.style.setProperty(`--fluid-${role}-min`, `${high}rem`)
      root.style.setProperty(`--fluid-${role}-max`, `${low}rem`)
    }
  }, roles)
  for (const width of [320, 480, 840, 1200, 1920]) {
    await page.setViewport({width, height: 900})
    const actual = await measure()
    const p = Math.max(0, Math.min(1, (width - 480) / 720))
    for (const [role, [low, high]] of Object.entries(roles)) {
      close(actual[role], 16 * (high + p * (low - high)), `${role}, descending, width ${width}`)
    }
  }

  await page.reload({waitUntil: "networkidle0"})
  await page.setViewport({width: 840, height: 900})
  for (const tier of ["native-progress", "trigonometric", "static"]) {
    if (tier !== "native-progress") {
      const condition = tier === "trigonometric" ? "progress(" : "tan(atan2("
      const removed = await page.evaluate(condition => {
        const visit = rules => {
          for (let index = rules.cssRules.length - 1; index >= 0; index--) {
            const rule = rules.cssRules[index]
            if (rule.type === CSSRule.SUPPORTS_RULE && rule.conditionText.includes(condition)) {
              rules.deleteRule(index)
              return true
            }
            if (rule.cssRules && visit(rule)) return true
          }
          return false
        }
        return [...document.styleSheets].some(sheet => { try { return visit(sheet) } catch { return false } })
      }, condition)
      assert.equal(removed, true, `remove ${condition} rule`)
      checks++
    }
    assert.equal(await page.evaluate(() => getComputedStyle(document.documentElement).getPropertyValue("--fluid-method").trim()), tier)
    checks++
    const actual = await measure()
    for (const [role, [low, high]] of Object.entries(roles)) {
      close(actual[role], 16 * (tier === "static" ? low : (low + high) / 2), `${tier} ${role}`)
    }
  }

  for (const width of [744, 1128, 1440]) {
    await page.setViewport({width, height: 900})
    const columns = width < 1128 ? 2 : 3
    for (const alignment of ["start", "center"]) {
      for (let count = 1; count <= 2 * columns + 1; count++) {
        await page.goto(`${base}/dev/design-system?alignment=${alignment}&count=${count}`, {waitUntil: "domcontentloaded"})
        await page.waitForSelector(`#card-grid > article:nth-child(${count})`)
        const geometry = await page.evaluate(() => {
          const grid = document.querySelector("#card-grid").getBoundingClientRect()
          const cards = [...document.querySelectorAll("#card-grid > article")].map(card => card.getBoundingClientRect())
          const row = cards.filter(card => Math.abs(card.top - cards.at(-1).top) < 1)
          return {gridLeft: grid.left, gridMiddle: (grid.left + grid.right) / 2,
            firstRowCount: cards.filter(card => Math.abs(card.top - cards[0].top) < 1).length,
            lastRowCount: row.length, rowLeft: row[0].left, rowMiddle: (row[0].left + row.at(-1).right) / 2}
        })
        assert.equal(geometry.firstRowCount, Math.min(columns, count), `actual columns at ${width}px`)
        assert.equal(geometry.lastRowCount, count % columns || columns, `actual remainder for ${count} cards`)
        checks += 2
        close(alignment === "center" ? geometry.rowMiddle : geometry.rowLeft,
          alignment === "center" ? geometry.gridMiddle : geometry.gridLeft, `${alignment}, width ${width}, count ${count}`)
      }
    }
  }

  // Observe current scope semantics without declaring local themes implemented.
  const scopedTokens = await page.evaluate(() => {
    const original = document.querySelector("#buttons button[data-variant=primary]")
    const probe = original.cloneNode(true)
    probe.removeAttribute("id")
    probe.style.cssText = "--primary:rgb(1,2,3);--radius-xl:37px;--font-body:monospace;position:absolute;visibility:hidden"
    document.body.append(probe)
    const css = getComputedStyle(probe)
    const result = {originalColor: getComputedStyle(original).backgroundColor,
      scopedColor: css.backgroundColor, scopedRadius: css.borderRadius, scopedFamily: css.fontFamily}
    probe.remove()
    return result
  })
  assert.deepEqual(errors, [])
  checks++
  console.log(JSON.stringify({checks_passed: checks, browser: await browser.version(),
    scope: "existing Chrome CSS; CSSOM fallback selection, not unsupported-engine emulation", scopedTokens}, null, 2))
} finally {
  await browser.close()
}
