// Read-only guide proof; external browser tooling is not an app dependency.
import assert from "node:assert/strict"
import {createRequire} from "node:module"
import {resolve} from "node:path"
import {contrastRatio} from "../../assets/js/design_system.js"

const require = createRequire(resolve(process.env.BROWSER_TOOLS_ROOT || ".", "package.json"))
const browser = await require("puppeteer-core").launch({
  executablePath: process.env.CHROME_PATH || "/usr/bin/google-chrome",
  headless: true,
  args: ["--blink-settings=primaryHoverType=2,availableHoverTypes=2,primaryPointerType=4,availablePointerTypes=4"]
})
const page = await browser.newPage()
const base = process.env.DESIGN_SYSTEM_URL || "http://127.0.0.1:4237"
const errors = []
page.on("pageerror", error => errors.push(error.message))

async function measureContrast(button) {
  const bytes = [...await button.screenshot()]
  return page.evaluate(async bytes => {
    const bitmap = await createImageBitmap(new Blob([new Uint8Array(bytes)], {type: "image/png"}))
    const canvas = document.createElement("canvas")
    canvas.width = bitmap.width
    canvas.height = bitmap.height
    const ctx = canvas.getContext("2d", {willReadFrequently: true})
    ctx.drawImage(bitmap, 0, 0)
    const pixels = []
    // The horizontal gradient is uniform. Sample padding alongside the label,
    // across its entire vertical region, excluding rim/shadow and glyph pixels.
    for (let y = 14; y <= bitmap.height - 14; y += 2) {
      for (const x of [12, bitmap.width - 13]) pixels.push([...ctx.getImageData(x, y, 1, 1).data].slice(0, 3))
    }
    bitmap.close()
    return pixels
  }, bytes)
}

try {
  await page.setViewport({width: 1440, height: 1000})
  await page.goto(`${base}/dev/design-system#lighting`, {waitUntil: "networkidle0"})
  await page.waitForSelector("#lighting-primary[data-treatment=lit]")
  assert.equal(await page.evaluate(() => matchMedia("(hover: hover)").matches), true)
  const button = await page.$("#lighting-primary")
  const state = () => button.evaluate(b => {
    const s = getComputedStyle(b)
    return {height: s.height, gradient: s.backgroundImage, shadow: s.boxShadow,
      top: s.borderTopColor, bottom: s.borderBottomColor}
  })
  await page.mouse.move(0, 0)
  const rest = await state()
  assert.equal(rest.height, "48px")
  assert.match(rest.gradient, /linear-gradient/)
  assert.notEqual(rest.shadow, "none")
  assert.notEqual(rest.top, rest.bottom)
  const minimumContrast = []
  for (const interaction of ["rest", "hover", "pressed"]) {
    if (interaction === "hover") await button.hover()
    if (interaction === "pressed") await page.mouse.down()
    const pixels = await measureContrast(button)
    const minimum = Math.min(...pixels.map(rgb => contrastRatio([255, 255, 255], rgb)))
    assert.ok(minimum >= 4.5, `${interaction} gradient label contrast ${minimum.toFixed(2)}:1`)
    minimumContrast.push({interaction, minimum: Number(minimum.toFixed(2))})
    if (interaction === "hover") assert.notEqual((await state()).gradient, rest.gradient)
    if (interaction === "pressed") assert.equal(((await state()).shadow.match(/inset/g) || []).length, 2)
  }
  await page.mouse.up()

  const levels = await page.evaluate(() => {
    const canvas = document.createElement("canvas")
    canvas.width = canvas.height = 1
    const ctx = canvas.getContext("2d")
    return [...document.querySelectorAll(".ds-lighting-level")].map(el => {
      ctx.fillStyle = getComputedStyle(el).backgroundColor
      ctx.fillRect(0, 0, 1, 1)
      const rgb = [...ctx.getImageData(0, 0, 1, 1).data].slice(0, 3)
      const linear = rgb.map(n => n / 255).map(n => n <= 0.04045 ? n / 12.92 : ((n + 0.055) / 1.055) ** 2.4)
      return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
    })
  })
  assert.ok(levels[0] < levels[1] && levels[1] < levels[2], "neutral elevation increases lightness")

  const edgeLighting = el => {
    const style = getComputedStyle(el)
    const canvas = document.createElement("canvas")
    canvas.width = canvas.height = 1
    const ctx = canvas.getContext("2d")
    const lightness = color => {
      ctx.fillStyle = style.backgroundColor
      ctx.fillRect(0, 0, 1, 1)
      ctx.fillStyle = color
      ctx.fillRect(0, 0, 1, 1)
      const linear = [...ctx.getImageData(0, 0, 1, 1).data].slice(0, 3).map(n => n / 255)
        .map(n => n <= 0.04045 ? n / 12.92 : ((n + 0.055) / 1.055) ** 2.4)
      return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
    }
    return {top: lightness(style.borderTopColor), bottom: lightness(style.borderBottomColor), shadow: style.boxShadow}
  }
  const raised = await page.$eval("#lighting article[data-variant=raised]", edgeLighting)
  assert.ok(raised.top > raised.bottom && raised.shadow !== "none", "raised card catches light above and casts below")
  const secondary = await page.$("#lighting-secondary")
  const secondaryRest = await secondary.evaluate(edgeLighting)
  assert.ok(secondaryRest.top > secondaryRest.bottom, "secondary edge is lighter above")
  await secondary.hover()
  await page.mouse.down()
  const secondaryPressed = await secondary.evaluate(edgeLighting)
  assert.ok(secondaryPressed.top < secondaryPressed.bottom, "pressed secondary reverses edge lighting")
  assert.equal((secondaryPressed.shadow.match(/inset/g) || []).length, 2)
  await page.mouse.up()

  await page.$eval("#lighting [data-treatment=flat]", el => el.focus())
  await page.keyboard.press("Tab")
  assert.equal(await page.evaluate(() => document.activeElement.id), "lighting-primary")
  assert.equal(await button.evaluate(b => parseFloat(getComputedStyle(b).outlineWidth) > 0), true)

  const disabled = await page.$("#lighting-disabled")
  const disabledBefore = await disabled.evaluate(b => ({gradient: getComputedStyle(b).backgroundImage, shadow: getComputedStyle(b).boxShadow}))
  await disabled.hover()
  assert.deepEqual(await disabled.evaluate(b => ({gradient: getComputedStyle(b).backgroundImage, shadow: getComputedStyle(b).boxShadow})), disabledBefore)
  assert.equal(disabledBefore.shadow, "none")

  for (const width of [320, 390, 744, 1128, 1920]) {
    await page.setViewport({width, height: 1000})
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true, `reflow at ${width}px`)
  }
  await page.setViewport({width: 320, height: 1000})
  const resized = await page.evaluate(() => {
    const b = document.querySelector("#lighting-primary")
    const old = b.textContent
    const oldFont = b.style.fontSize
    b.textContent = "Continue with your personalised programme / Gaan voort met jou persoonlike program"
    b.style.fontSize = `${parseFloat(getComputedStyle(b).fontSize) * 2}px`
    const result = {fits: b.scrollWidth <= b.clientWidth + 1, grows: b.getBoundingClientRect().height > 48,
      pageFits: document.documentElement.scrollWidth <= innerWidth}
    b.textContent = old
    b.style.fontSize = oldFont
    return result
  })
  assert.deepEqual(resized, {fits: true, grows: true, pageFits: true})

  await page.setViewport({width: 1440, height: 1000})
  const changed = await page.evaluate(() => {
    const root = document.documentElement
    const before = getComputedStyle(document.querySelector("#lighting-primary")).backgroundImage
    root.style.setProperty("--primary", "#004fbf")
    const after = getComputedStyle(document.querySelector("#lighting-primary")).backgroundImage
    root.style.removeProperty("--primary")
    return before !== after
  })
  assert.equal(changed, true, "gradient follows live source token")

  await page.emulateMediaFeatures([{name: "forced-colors", value: "active"}])
  await button.hover()
  await page.mouse.down()
  assert.equal((await state()).gradient, "none", "forced colours remove gradient even while pressed")
  assert.equal((await state()).shadow, "none")
  await page.mouse.up()
  await page.emulateMediaFeatures([{name: "forced-colors", value: "none"}, {name: "prefers-reduced-motion", value: "reduce"}])
  await page.addStyleTag({content: ":root { --action-primary-gradient: none; --action-primary-hover-gradient: none; --shadow-ink: transparent; }"})
  assert.equal((await state()).gradient, "none", "solid fallback remains usable")
  assert.deepEqual(errors, [])
  console.log("PASS: lighting hierarchy, native states, screenshot gradient contrast, 320px/200% text reflow, keyboard focus, token propagation and forced-colour/solid fallbacks", JSON.stringify(minimumContrast))
} finally {
  await browser.close()
}
