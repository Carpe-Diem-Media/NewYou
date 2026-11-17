// Read-only font delivery and token propagation proof. Uses the guide's external tooling.
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
  for (const path of ["/dev/design-system", "/dev/design-system/preview", "/register?locale=en", "/register?locale=af", "/register", "/"]) {
    await page.setViewport({width: 1440, height: 900})
    const response = await page.goto(`${base}${path}`, {waitUntil: "networkidle0"})
    assert.equal(response.status(), 200, path)
    const delivery = await page.evaluate(async () => {
      const loaded = await Promise.all([400, 500, 700].map(weight => document.fonts.load(`${weight} 16px Inter`, "Afrikaans: ë é ê ô ŉ")))
      return loaded.map(faces => faces.length > 0 && faces.every(face => face.status === "loaded"))
    })
    assert.deepEqual(delivery, [true, true, true], `self-hosted font delivery: ${path}`)

    const propagation = await page.evaluate(() => {
      const root = document.documentElement
      const scope = document.querySelector(".ds-guide, .registration-page, main") || document.body
      const elements = [...scope.querySelectorAll("h1, h2, h3, p, a, button, input:not([type='checkbox']), select, textarea")]
      const initial = elements.every(element => getComputedStyle(element).fontFamily.includes("Inter"))
      root.style.setProperty("--font-body", "monospace")
      const shared = elements.every(element => getComputedStyle(element).fontFamily === "monospace")
      root.style.setProperty("--font-display", "serif")
      const heading = scope.querySelector("h1, h2, h3")
      const separateHeading = !heading || getComputedStyle(heading).fontFamily === "serif"
      const body = scope.querySelector("input:not([type='hidden']):not([type='checkbox'])") || scope.querySelector("p:not(.font-ny-display)")
      const bodyUnchanged = !body || getComputedStyle(body).fontFamily === "monospace"
      root.style.removeProperty("--font-body")
      root.style.removeProperty("--font-display")
      return {count: elements.length, initial, shared, separateHeading, bodyUnchanged}
    })
    assert.ok(propagation.count > 0, `real text and controls: ${path}`)
    assert.equal(propagation.initial, true, `shared default family: ${path}`)
    assert.equal(propagation.shared, true, `one body token updates every family: ${path}`)
    assert.equal(propagation.separateHeading, true, `optional display role: ${path}`)
    assert.equal(propagation.bodyUnchanged, true, `display override preserves body role: ${path}`)

    for (const width of [320, 390, 744, 1128, 1920]) {
      await page.setViewport({width, height: 900})
      assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth), false, `font reflow: ${path} at ${width}`)
    }

    if (path.startsWith("/register")) {
      const controls = await page.$$eval(".registration-page a[href], .registration-page button:not([disabled]), .registration-page input:not([type='hidden']):not([disabled])", elements => elements.filter(element => element.getClientRects().length && element.tabIndex >= 0).length)
      for (let index = 0; index < controls; index++) {
        await page.keyboard.press("Tab")
        assert.equal(await page.evaluate(() => {
          const control = document.activeElement
          const style = getComputedStyle(control)
          return Boolean(control.closest(".registration-page")) && control.matches(":focus-visible") && style.outlineStyle !== "none" && parseFloat(style.outlineWidth) > 0
        }), true, `visible product focus ${index + 1}: ${path}`)
      }
    }
  }

  // A font network failure must preserve usable server-rendered content.
  const fallback = await browser.newPage()
  await fallback.setViewport({width: 320, height: 900})
  await fallback.setJavaScriptEnabled(false)
  await fallback.setRequestInterception(true)
  fallback.on("request", request => request.resourceType() === "font" ? request.abort() : request.continue())
  await fallback.goto(`${base}/register?locale=af`, {waitUntil: "networkidle0"})
  const recovery = await fallback.evaluate(async () => {
    await document.fonts.ready
    return {
      failedFont: [...document.fonts].some(face => face.family.replaceAll('"', "") === "Inter" && face.status === "error"),
      headingVisible: document.querySelector("h1").getBoundingClientRect().height > 0,
      inputVisible: document.querySelector("#registration-first-name").getBoundingClientRect().width > 0,
      overflow: document.documentElement.scrollWidth > innerWidth
    }
  })
  assert.deepEqual(recovery, {failedFont: true, headingVisible: true, inputVisible: true, overflow: false})
  await fallback.close()
  assert.deepEqual(errors, [])
  console.log("Typography proof passed: local 400/500/700 delivery, six public/reference pages, live body/display token propagation, five widths, visible registration focus, and no-JavaScript font failure recovery.")
} finally {
  await browser.close()
}
