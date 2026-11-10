// Run against the development server with external browser tooling. No application dependency.
import assert from "node:assert/strict"
import {createRequire} from "node:module"
import {resolve} from "node:path"

const require = createRequire(resolve(process.env.BROWSER_TOOLS_ROOT || ".", "package.json"))
const puppeteer = require("puppeteer-core")
const base = process.env.DESIGN_SYSTEM_URL || "http://127.0.0.1:4237"
const browser = await puppeteer.launch({executablePath: process.env.CHROME_PATH || "/usr/bin/google-chrome", headless: true})
const page = await browser.newPage()
const errors = []
page.on("pageerror", error => errors.push(error.message))

try {
  await page.setViewport({width: 1440, height: 900})
  await page.goto(`${base}/dev/design-system`, {waitUntil: "networkidle0"})
  await page.waitForFunction(() => window.liveSocket?.isConnected() && document.querySelector("[data-token='--primary']")?.textContent.trim() !== "CSS value")

  for (const width of [320, 390, 743, 744, 1127, 1128, 1440, 1920]) {
    await page.setViewport({width, height: 900})
    const result = await page.evaluate(() => {
      const grid = document.querySelector("#card-grid")
      const boxes = [...grid.children].map(child => child.getBoundingClientRect())
      const firstRow = boxes.filter(box => Math.abs(box.top - boxes[0].top) < 1)
      return {width: innerWidth, overflow: document.documentElement.scrollWidth > innerWidth, columns: firstRow.length}
    })
    assert.equal(result.overflow, false, `horizontal overflow at ${width}px`)
    assert.equal(result.columns, width < 744 ? 1 : width < 1128 ? 2 : 3, `grid at ${width}px`)
  }

  for (const width of [744, 1128, 1440]) {
    await page.setViewport({width, height: 900})
    for (const count of [1, 2, 4, 5, 7, 8]) {
      await page.goto(`${base}/dev/design-system?alignment=center&count=${count}`, {waitUntil: "networkidle0"})
      const balanced = await page.evaluate(() => {
        const grid = document.querySelector("#card-grid").getBoundingClientRect()
        const cards = [...document.querySelectorAll("#card-grid > article")].map(card => card.getBoundingClientRect())
        const lastTop = cards.at(-1).top
        const row = cards.filter(card => Math.abs(card.top - lastTop) < 1)
        const midpoint = (row[0].left + row.at(-1).right) / 2
        return Math.abs(midpoint - (grid.left + grid.right) / 2) < 2
      })
      assert.equal(balanced, true, `${count} cards must centre at ${width}px`)
    }
  }

  await page.goto(`${base}/dev/design-system`, {waitUntil: "networkidle0"})
  await page.waitForFunction(() => window.liveSocket?.isConnected())
  await page.select("#grid-count", "4")
  await page.select("#grid-alignment", "center")
  await page.waitForFunction(() => document.querySelectorAll("#card-grid > article").length === 4 && document.querySelector("#card-grid").dataset.alignment === "center")
  assert.ok(new URL(page.url()).searchParams.get("count") === "4")

  await page.click("[phx-value-viewport='desktop']")
  await page.waitForFunction(() => document.querySelector("#responsive-preview").dataset.viewport === "desktop")
  const frame = await (await page.$("#design-preview-frame")).contentFrame()
  await frame.waitForSelector("#preview-content")
  assert.equal(await frame.evaluate(() => innerWidth), 1128)

  const changed = await page.evaluate(async () => {
    const root = document.documentElement
    const primary = root.style.getPropertyValue("--primary")
    const radius = root.style.getPropertyValue("--radius")
    const shadow = root.style.getPropertyValue("--box-shadow")
    root.style.setProperty("--primary", "#004fbf")
    root.style.setProperty("--radius", "24px")
    root.style.setProperty("--box-shadow", "0px 2px 8px rgba(0, 0, 0, 0.12)")
    await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))
    const button = getComputedStyle(document.querySelector("#buttons button.bg-design-primary"))
    const swatch = getComputedStyle(document.querySelector("[data-swatch='primary']"))
    const card = getComputedStyle(document.querySelector("#card-grid > article"))
    const result = {
      sameColor: button.backgroundColor === swatch.backgroundColor,
      label: document.querySelector("[data-token='--primary']").textContent.trim(),
      radius: card.borderRadius,
      shadow: card.boxShadow,
      contrast: document.querySelector("[data-pair='primary']").parentElement.querySelector("[data-contrast-result]").textContent
    }
    for (const [name, value] of [["--primary", primary], ["--radius", radius], ["--box-shadow", shadow]]) {
      if (value) root.style.setProperty(name, value)
      else root.style.removeProperty(name)
    }
    return result
  })
  assert.equal(changed.sameColor, true)
  assert.equal(changed.label, "#004fbf")
  assert.equal(changed.radius, "24px")
  assert.notEqual(changed.shadow, "none")
  assert.match(changed.contrast, /:1 \/ (AA|AAA)/)

  await page.keyboard.press("Tab")
  const focus = await page.evaluate(() => {
    const css = getComputedStyle(document.activeElement)
    return {outline: css.outlineStyle, width: parseFloat(css.outlineWidth)}
  })
  assert.notEqual(focus.outline, "none")
  assert.ok(focus.width >= 2)

  await page.emulateMediaFeatures([{name: "prefers-reduced-motion", value: "reduce"}])
  assert.equal(await page.evaluate(() => [...document.querySelectorAll(".ds-guide *")].every(element => getComputedStyle(element).animationName === "none")), true)

  await page.click("[data-refresh-tokens]")
  await page.waitForFunction(() => document.querySelector("#token-status").textContent.includes("refreshed"))
  assert.deepEqual(errors, [])
  console.log("PASS: 8 responsive widths; 18 incomplete-row cases; LiveView URL state; iframe viewport; live color/radius/shadow propagation; contrast refresh; keyboard focus; reduced motion; no browser errors.")
} finally {
  await browser.close()
}
