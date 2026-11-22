import assert from "node:assert/strict"
import {createRequire} from "node:module"
import {resolve} from "node:path"
import {contrastRatio} from "../../assets/js/design_system.js"

const require = createRequire(resolve(process.env.BROWSER_TOOLS_ROOT ?? ".", "package.json"))
const puppeteer = require("puppeteer-core")
const base = process.env.DESIGN_SYSTEM_URL ?? "http://127.0.0.1:4237"
const browser = await puppeteer.launch({
  executablePath: process.env.CHROME_PATH ?? "/usr/bin/google-chrome",
  headless: true,
  args: ["--no-sandbox"]
})

try {
  const page = await browser.newPage()
  const errors = []
  page.on("pageerror", error => errors.push(error.message))
  await page.emulateMediaFeatures([{name: "prefers-reduced-motion", value: "reduce"}])
  await page.setViewport({width: 1440, height: 900})
  const response = await page.goto(`${base}/dev/design-system#section-layouts`)
  assert.equal(response.status(), 200)
  await page.evaluate(() => document.fonts.ready.then(() => null))

  const geometry = () => page.$eval("#section-layouts", guide => {
    const hero = guide.querySelector("#layout-hero")
    const action = guide.querySelector("#layout-action")
    const [copy, media] = hero.children
    const [actionCopy, controls] = action.children
    const rect = element => element.getBoundingClientRect()
    const grid = [...guide.querySelectorAll("#layout-features li")].map(rect)

    return {
      mediaOnLeft: rect(media).right <= rect(copy).left,
      mediaBelow: rect(media).top >= rect(copy).bottom,
      actionsInRow: rect(controls).left >= rect(actionCopy).right,
      actionsBelow: rect(controls).top >= rect(actionCopy).bottom,
      gridColumns: grid.filter(item => Math.abs(item.top - grid[0].top) < 1).length,
      fits: [guide, hero, action, ...guide.querySelectorAll(".ds-section-copy, li, form")]
        .every(element => element.scrollWidth <= element.clientWidth + 1)
    }
  })

  assert.deepEqual(await geometry(), {
    mediaOnLeft: true, mediaBelow: false, actionsInRow: true, actionsBelow: false,
    gridColumns: 3, fits: true
  })

  await page.$eval("#section-layouts", element => element.style.inlineSize = "240px")
  const stacked = {
    mediaOnLeft: false, mediaBelow: true, actionsInRow: false, actionsBelow: true,
    gridColumns: 1, fits: true
  }
  assert.deepEqual(await geometry(), stacked)
  await page.$eval("#section-layouts", element => element.style.removeProperty("inline-size"))
  await page.setViewport({width: 320, height: 900})
  assert.deepEqual(await geometry(), stacked)

  const title = "#layout-hero-heading"
  const titleSize = () => page.$eval(title, element => parseFloat(getComputedStyle(element).fontSize))
  const initialSize = await titleSize()
  await page.$eval("#section-layouts", guide => {
    const text = [...guide.querySelectorAll("h3, h4, p, a, button")]
    const sizes = text.map(element => parseFloat(getComputedStyle(element).fontSize))
    text.forEach((element, index) => {
      element.style.fontSize = `${sizes[index] * 2}px`
    })
    guide.querySelector("#layout-features li p").textContent =
      "Voorbeeldteks met 'n besonderlangAfrikaansewoordwatmoetomvou."
  })
  assert.equal(await titleSize(), initialSize * 2)
  assert.deepEqual(await geometry(), stacked)
  await page.reload()

  const pairs = await page.$eval("#section-layouts", guide => {
    const context = document.createElement("canvas").getContext("2d")
    const rgb = value => {
      context.fillStyle = value
      context.fillRect(0, 0, 1, 1)
      return [...context.getImageData(0, 0, 1, 1).data].slice(0, 3)
    }

    return [
      ["#layout-hero h3", "#layout-hero"],
      ["#layout-hero a", "#layout-hero"],
      ["#layout-features article p", "#layout-features article"],
      ["#layout-action button", "#layout-action button"]
    ].map(([foreground, background]) => [
      rgb(getComputedStyle(guide.querySelector(foreground)).color),
      rgb(getComputedStyle(guide.querySelector(background)).backgroundColor)
    ])
  })
  for (const [foreground, background] of pairs) {
    assert.ok(contrastRatio(foreground, background) >= 4.5)
  }

  await page.$eval("#layout-hero", element => {
    element.tabIndex = -1
    element.focus()
  })
  for (const selector of ["#layout-hero a", "#layout-action button"]) {
    await page.keyboard.press("Tab")
    assert.ok(await page.$eval(selector, element => {
      const style = getComputedStyle(element)
      return element.matches(":focus-visible") && style.outlineStyle !== "none" &&
        parseFloat(style.outlineWidth) > 0 && style.animationName === "none" &&
        style.transitionDuration === "0s"
    }), selector)
  }
  await Promise.all([page.waitForNavigation(), page.keyboard.press("Enter")])
  assert.equal(new URL(page.url()).pathname, "/dev/design-system/preview")
  assert.deepEqual(errors, [])
  console.log(`Section geometry, 200% text, contrast, keyboard focus, reduced motion and CTA passed in ${await browser.version()}`)
} finally {
  await browser.close()
}
