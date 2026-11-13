// Run against the development server with external browser tooling. No application dependency.
import assert from "node:assert/strict"
import {createRequire} from "node:module"
import {resolve} from "node:path"

const require = createRequire(resolve(process.env.BROWSER_TOOLS_ROOT || ".", "package.json"))
const puppeteer = require("puppeteer-core")
const base = process.env.DESIGN_SYSTEM_URL || "http://127.0.0.1:4237"
const browser = await puppeteer.launch({
  executablePath: process.env.CHROME_PATH || "/usr/bin/google-chrome",
  headless: true,
  // Exercise Tailwind's hover media query with an explicit desktop pointer.
  args: ["--blink-settings=primaryHoverType=2,availableHoverTypes=2,primaryPointerType=4,availablePointerTypes=4"]
})
const page = await browser.newPage()
const errors = []
page.on("pageerror", error => errors.push(error.message))

try {
  await page.setViewport({width: 1440, height: 900})
  await page.goto(`${base}/dev/design-system`, {waitUntil: "networkidle0"})
  await page.waitForFunction(() => window.liveSocket?.isConnected() && document.querySelector("[data-token='--primary']")?.textContent.trim() !== "CSS value")
  assert.equal(await page.evaluate(() => matchMedia("(hover: hover)").matches), true)

  const primarySelector = "#buttons button[data-variant='primary']:not(:disabled)"
  const primary = await page.$(primarySelector)
  const secondary = await page.$("#buttons button[data-variant='secondary']")
  assert.ok(primary, "shared primary variant is present")
  assert.ok(secondary, "shared secondary variant is present")
  const primaryBefore = await primary.evaluate(button => {
    const style = getComputedStyle(button)
    return {background: style.backgroundColor, height: style.height, radius: style.borderRadius,
      gradient: style.backgroundImage, top: style.borderTopColor, bottom: style.borderBottomColor, shadow: style.boxShadow}
  })
  assert.match(primaryBefore.gradient, /^linear-gradient\(/, "main primary example shows the agreed gradient")
  assert.notEqual(primaryBefore.top, primaryBefore.bottom, "main primary example has directional borders")
  assert.notEqual(primaryBefore.shadow, "none", "main primary example shows its restrained shadow")
  assert.equal(primaryBefore.height, "48px")
  assert.equal(primaryBefore.radius, "32px")
  await primary.hover()
  const primaryHovered = await primary.evaluate(button => getComputedStyle(button).backgroundColor)
  assert.notEqual(primaryHovered, primaryBefore.background, "approved hover colour applies")
  await page.mouse.move(0, 0)
  assert.equal(await primary.evaluate(button => getComputedStyle(button).backgroundColor), primaryBefore.background)
  const secondaryStyle = await secondary.evaluate(button => {
    const style = getComputedStyle(button)
    return {height: style.height, background: style.backgroundColor, border: style.borderTopStyle}
  })
  assert.equal(secondaryStyle.height, "48px")
  assert.equal(secondaryStyle.border, "solid")
  assert.notEqual(secondaryStyle.background, primaryBefore.background)
  const nativeStates = await page.evaluate(() => {
    const disabled = document.querySelector("#buttons button[disabled]")
    disabled.focus()
    return {disabled: disabled.disabled, focused: document.activeElement === disabled,
      duplicate: disabled.hasAttribute("data-disabled"),
      cards: [...document.querySelectorAll("#card-grid > article")].every(card => card.dataset.variant === "flat")}
  })
  assert.equal(nativeStates.disabled, true)
  assert.equal(nativeStates.focused, false)
  assert.equal(nativeStates.duplicate, false)
  assert.equal(nativeStates.cards, true)

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
      await page.goto(`${base}/dev/design-system?alignment=center&count=${count}`, {waitUntil: "domcontentloaded"})
      await page.waitForSelector(`#card-grid > article:nth-child(${count})`)
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
    const button = getComputedStyle(document.querySelector("#buttons button[data-variant='primary']"))
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

  const sourceColorChecks = await page.evaluate(async () => {
    const root = document.documentElement
    const sourceToken = "--palette-primary-srgb"
    const oldSource = root.style.getPropertyValue(sourceToken)
    const button = document.querySelector("#buttons button[data-variant='primary']")
    const swatch = document.querySelector("[data-swatch='primary']")
    const before = getComputedStyle(swatch).backgroundColor
    root.style.setProperty(sourceToken, "#004fbf")
    await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))
    const buttonColor = getComputedStyle(button).backgroundColor
    const swatchColor = getComputedStyle(swatch).backgroundColor
    if (oldSource) root.style.setProperty(sourceToken, oldSource)
    else root.style.removeProperty(sourceToken)
    return {before, buttonColor, swatchColor}
  })
  assert.notEqual(sourceColorChecks.before, sourceColorChecks.swatchColor, "semantic color follows its source sRGB token")
  assert.equal(sourceColorChecks.buttonColor, sourceColorChecks.swatchColor, "component and palette retain exact source color equivalence")

  const fluidCases = []
  for (const width of [320, 480, 840, 1200, 1920]) {
    await page.setViewport({width, height: 900})
    await page.waitForFunction(() => {
      const output = document.querySelector("[data-measure-target='fluid-display']")
      const target = document.querySelector("#fluid-display")
      return output && target && output.textContent.trim() === getComputedStyle(target).fontSize
    })
    fluidCases.push(await page.evaluate(() => {
      const sample = document.querySelector("#fluid-display")
      const current = document.querySelector("[data-measure-target='fluid-display']").textContent.trim()
      const rootSize = parseFloat(getComputedStyle(document.documentElement).fontSize)
      const min = parseFloat(document.querySelector("[data-fluid-value='display-min'] [data-token]").textContent) * rootSize
      const max = parseFloat(document.querySelector("[data-fluid-value='display-max'] [data-token]").textContent) * rootSize
      const measurements = {
        display: parseFloat(getComputedStyle(sample).fontSize),
        body: parseFloat(getComputedStyle(document.querySelector("#fluid-body")).fontSize),
        space: parseFloat(getComputedStyle(document.querySelector("#fluid-space")).paddingBlockStart),
        gutter: parseFloat(getComputedStyle(document.querySelector("#fluid-gutter")).paddingInlineStart)
      }
      const bounds = Object.fromEntries(["display", "body", "space", "gutter"].map(kind => [kind, Object.fromEntries(["min", "max"].map(edge => [edge, document.querySelector(`[data-measure-target='fluid-${kind}-${edge}']`).textContent.trim()]))]))
      return {width: innerWidth, size: measurements.display, current, min, max, measurements, bounds}
    }))
  }
  assert.equal(fluidCases[0].size, fluidCases[0].min, "fluid size reaches minimum below vmin")
  assert.equal(fluidCases[1].size, fluidCases[1].min, "fluid size begins at vmin")
  assert.deepEqual(fluidCases[2].measurements, {display: 52, body: 17, space: 32, gutter: 20}, "each fluid token interpolates at the midpoint")
  assert.deepEqual(fluidCases[2].bounds, {
    display: {min: "40px", max: "64px"},
    body: {min: "16px", max: "18px"},
    space: {min: "16px", max: "48px"},
    gutter: {min: "16px", max: "24px"}
  }, "resolved pixel bounds compare directly with current computed values")
  assert.equal(fluidCases[3].size, fluidCases[3].max, "fluid size reaches maximum at vmax")
  assert.equal(fluidCases[4].size, fluidCases[4].max, "fluid size stays capped above vmax")
  for (const item of fluidCases) {
    assert.equal(item.current, `${item.size}px`, "readout uses computed CSS")
  }
  for (const [id, property] of [["fluid-body", "font-size"], ["fluid-space", "padding-block-start"], ["fluid-gutter", "padding-inline-start"]]) {
    const output = await page.evaluate(({id, property}) => {
      const target = document.querySelector(`#${id}`)
      return {measured: document.querySelector(`[data-measure-target='${id}']`).textContent.trim(), actual: getComputedStyle(target).getPropertyValue(property).trim()}
    }, {id, property})
    assert.equal(output.measured, output.actual, `${id} readout uses its computed CSS`)
  }

  assert.equal(await page.$$eval(".ds-fluid-bound-probe", probes => probes.every(probe =>
    probe.getBoundingClientRect().height === 0
  )), true, "endpoint probes must not affect visible line layout")

  await page.setViewport({width: 1200, height: 900})
  const fluidAdaptation = await page.evaluate(async () => {
    const root = document.documentElement
    const before = getComputedStyle(document.querySelector("#fluid-display")).fontSize
    root.style.setProperty("--fluid-vmin", "60rem")
    root.style.setProperty("--fluid-vmax", "90rem")
    await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))
    const afterViewportTokens = getComputedStyle(document.querySelector("#fluid-display")).fontSize
    root.style.removeProperty("--fluid-vmin")
    root.style.removeProperty("--fluid-vmax")
    const oldFontSize = root.style.fontSize
    root.style.fontSize = "20px"
    await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))
    const afterRootFont = getComputedStyle(document.querySelector("#fluid-display")).fontSize
    if (oldFontSize) root.style.fontSize = oldFontSize
    else root.style.removeProperty("font-size")
    return {before, afterViewportTokens, afterRootFont}
  })
  assert.notEqual(fluidAdaptation.before, fluidAdaptation.afterViewportTokens, "viewport-bound token edits affect fluid size")
  assert.notEqual(fluidAdaptation.before, fluidAdaptation.afterRootFont, "root font enlargement affects rem-based fluid bounds")

  await page.setViewport({width: 1500, height: 900})
  const rootZoomSize = await page.evaluate(async () => {
    const root = document.documentElement
    const oldFontSize = root.style.fontSize
    root.style.fontSize = "20px"
    await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))
    const size = getComputedStyle(document.querySelector("#fluid-display")).fontSize
    if (oldFontSize) root.style.fontSize = oldFontSize
    else root.style.removeProperty("font-size")
    return size
  })
  assert.equal(rootZoomSize, "80px", "fluid maximum scales with enlarged root font size")

  await page.setViewport({width: 840, height: 900})
  const fallbackMethods = await page.evaluate(async () => {
    const rules = []
    const visit = container => [...container.cssRules].forEach((rule, index) => {
      if (rule.type === CSSRule.SUPPORTS_RULE) rules.push({container, index, condition: rule.conditionText})
      if (rule.cssRules) visit(rule)
    })
    for (const sheet of document.styleSheets) {
      try { visit(sheet) } catch {}
    }
    const removeSupport = async matcher => {
      const match = rules.find(item => item.condition.includes(matcher) && item.container.cssRules[item.index])
      if (!match) return false
      match.container.deleteRule(match.index)
      await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))
      return true
    }
    const nativeRemoved = await removeSupport("progress(")
    let root = getComputedStyle(document.documentElement)
    const afterNative = root.getPropertyValue("--fluid-method").trim()
    const sizeAfterNative = getComputedStyle(document.querySelector("#fluid-display")).fontSize
    const trigRemoved = await removeSupport("tan(atan2(")
    root = getComputedStyle(document.documentElement)
    const afterTrig = root.getPropertyValue("--fluid-method").trim()
    const sizeAfterTrig = getComputedStyle(document.querySelector("#fluid-display")).fontSize
    return {nativeRemoved, afterNative, sizeAfterNative, trigRemoved, afterTrig, sizeAfterTrig}
  })
  assert.equal(fallbackMethods.nativeRemoved, true, "CSSOM can remove the native progress support rule")
  assert.equal(fallbackMethods.afterNative, "trigonometric", "trigonometric method becomes active when native progress is unavailable")
  assert.equal(fallbackMethods.sizeAfterNative, "52px", "trigonometric tier keeps fluid interpolation")
  assert.equal(fallbackMethods.trigRemoved, true, "CSSOM can remove the trigonometric support rule")
  assert.equal(fallbackMethods.afterTrig, "static", "static method remains when both progress tiers are unavailable")
  assert.equal(fallbackMethods.sizeAfterTrig, "40px", "static fallback stays at the minimum")
  await page.reload({waitUntil: "domcontentloaded"})
  await page.waitForSelector("#fluid-display")

  const surfaceChecks = await page.evaluate(async () => {
    const tint = document.querySelector("[data-pair='tint']")
    const oldPrimary = document.documentElement.style.getPropertyValue("--primary")
    const initial = getComputedStyle(tint).backgroundColor
    document.documentElement.style.setProperty("--primary", "#004fbf")
    await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))
    const changed = getComputedStyle(tint).backgroundColor
    const result = tint.parentElement.querySelector("[data-contrast-result]").textContent
    if (oldPrimary) document.documentElement.style.setProperty("--primary", oldPrimary)
    else document.documentElement.style.removeProperty("--primary")
    return {initial, changed, result}
  })
  assert.notEqual(surfaceChecks.initial, surfaceChecks.changed, "derived tint follows its source color token")
  assert.match(surfaceChecks.result, /:1 \/ (AA|AAA|Large text only|Insufficient text contrast)/)
  assert.equal(await page.evaluate(() => [...document.querySelectorAll(".ds-treatment")].every(item => item.getAttribute("aria-hidden") === "true")), true)

  const colorFallbacks = await page.evaluate(() => {
    const removeColorSupports = container => {
      for (let index = container.cssRules.length - 1; index >= 0; index--) {
        const rule = container.cssRules[index]
        if (rule.type === CSSRule.SUPPORTS_RULE &&
            /oklch\(from|color-mix\(|linear-gradient\(135deg in oklab/.test(rule.conditionText)) {
          container.deleteRule(index)
        } else if (rule.cssRules) removeColorSupports(rule)
      }
    }
    for (const sheet of document.styleSheets) {
      try { removeColorSupports(sheet) } catch {}
    }
    const root = getComputedStyle(document.documentElement)
    const context = document.createElement("canvas").getContext("2d")
    const rgb = value => {
      context.fillStyle = value
      context.fillRect(0, 0, 1, 1)
      return [...context.getImageData(0, 0, 1, 1).data]
    }
    const value = name => root.getPropertyValue(name).trim()
    return {
      primary: rgb(getComputedStyle(document.querySelector("[data-swatch='primary']")).backgroundColor),
      source: rgb(value("--palette-primary-srgb")),
      tint: value("--design-surface-tint"), canvas: value("--canvas"),
      shade: value("--design-surface-shade"), hairline: value("--hairline"),
      overlay: value("--design-overlay"), ink: value("--secondary"),
      gradient: getComputedStyle(document.querySelector("[data-treatment='gradient']")).backgroundImage
    }
  })
  assert.deepEqual(colorFallbacks.primary, colorFallbacks.source, "sRGB palette fallback preserves source colors")
  assert.equal(colorFallbacks.tint, colorFallbacks.canvas, "unsupported mixing retains the canvas tint fallback")
  assert.equal(colorFallbacks.shade, colorFallbacks.hairline, "unsupported mixing retains the hairline shade fallback")
  assert.equal(colorFallbacks.overlay, colorFallbacks.ink, "unsupported mixing retains an opaque ink scrim")
  assert.match(colorFallbacks.gradient, /^linear-gradient\(/, "conventional gradient fallback still renders")
  assert.doesNotMatch(colorFallbacks.gradient, /in oklab/, "advanced gradient interpolation was removed")
  await page.reload({waitUntil: "domcontentloaded"})
  await page.waitForFunction(() => window.liveSocket?.isConnected())

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
  const noScript = await browser.newPage()
  await noScript.setJavaScriptEnabled(false)
  await noScript.setViewport({width: 320, height: 800})
  await noScript.goto(`${base}/dev/design-system`, {waitUntil: "domcontentloaded"})
  await noScript.waitForSelector("#fluid-display")
  const noScriptState = await noScript.evaluate(() => ({
    visible: document.querySelector("#fluid").getBoundingClientRect().height > 0,
    size: getComputedStyle(document.querySelector("#fluid-display")).fontSize,
    placeholder: document.querySelector("[data-measure-target='fluid-display']").textContent.trim()
  }))
  assert.equal(noScriptState.visible, true, "fluid specimens render without JavaScript")
  assert.equal(noScriptState.size, "40px", "CSS fluid sizing works without JavaScript")
  assert.equal(noScriptState.placeholder, "Current size measured in browser", "no-script output remains an honest placeholder")
  await noScript.close()

  assert.deepEqual(errors, [])
  console.log("PASS: responsive grid and URL state; iframe viewport; live token propagation; derived color pairs; fluid min/intermediate/max and computed readouts; contrast refresh; keyboard focus; reduced motion; no browser errors.")
} finally {
  await browser.close()
}
