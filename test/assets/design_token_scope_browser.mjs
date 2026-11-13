// Read-only regression for local semantic inputs on shared design components.
import assert from "node:assert/strict"
import {createRequire} from "node:module"
import {resolve} from "node:path"

const require = createRequire(resolve(process.env.BROWSER_TOOLS_ROOT || ".", "package.json"))
const browser = await require("puppeteer-core").launch({
  executablePath: process.env.CHROME_PATH || "/usr/bin/google-chrome",
  headless: true,
  args: ["--blink-settings=primaryHoverType=2,availableHoverTypes=2,primaryPointerType=4,availablePointerTypes=4"]
})
const page = await browser.newPage()
const base = process.env.DESIGN_SYSTEM_URL || "http://127.0.0.1:4237"

try {
  await page.setViewport({width: 1440, height: 1000})
  await page.goto(`${base}/dev/design-system#lighting`, {waitUntil: "networkidle0"})
  await page.waitForSelector("#lighting-primary[data-treatment=lit]")

  const result = await page.evaluate(() => {
    const baselineButton = document.querySelector("#lighting-primary")
    const baselineCard = document.querySelector("#lighting article[data-variant=raised]")
    const baseline = {
      buttonBackground: getComputedStyle(baselineButton).backgroundColor,
      buttonGradient: getComputedStyle(baselineButton).backgroundImage,
      buttonRadius: getComputedStyle(baselineButton).borderRadius,
      cardShadow: getComputedStyle(baselineCard).boxShadow
    }
    const specs = [
      ["button-flat-local", "#lighting [data-treatment=flat]"],
      ["button-lit-local", "#lighting-primary"],
      ["card-flat-local", "#lighting [data-variant=flat]"],
      ["card-raised-local", "#lighting article[data-variant=raised]"]
    ]
    const copies = Object.fromEntries(specs.map(([id, selector]) => {
      const source = document.querySelector(selector)
      const clone = source.cloneNode(true)
      clone.id = id
      clone.removeAttribute("disabled")
      clone.style.setProperty("--primary", "#a020f0")
      clone.style.setProperty("--primary-hover", "#7b1fa2")
      if (id.startsWith("card-")) clone.style.setProperty("--secondary", "#183a2b")
      clone.style.setProperty("--radius-xl", "9px")
      clone.style.setProperty("--radius", "11px")
      source.parentElement.append(clone)
      return [id, clone]
    }))
    const styles = Object.fromEntries(Object.entries(copies).map(([id, node]) => {
      const style = getComputedStyle(node)
      return [id, {background: style.backgroundColor, gradient: style.backgroundImage,
        radius: style.borderRadius, shadow: style.boxShadow}]
    }))
    const sibling = document.querySelector("#lighting-primary")
    const siblingStyle = getComputedStyle(sibling)
    const siblingCardStyle = getComputedStyle(document.querySelector("#lighting article[data-variant=raised]"))
    const root = document.documentElement
    const originalRoot = root.style.getPropertyValue("--primary")
    const beforeRootEdit = getComputedStyle(sibling).backgroundImage
    root.style.setProperty("--primary", "#004fbf")
    const afterRootEdit = getComputedStyle(sibling).backgroundImage
    root.style.setProperty("--primary", originalRoot)
    return {styles, baseline, sibling: {buttonBackground: siblingStyle.backgroundColor, buttonGradient: beforeRootEdit,
      buttonRadius: siblingStyle.borderRadius, cardShadow: siblingCardStyle.boxShadow},
      rootEditChangesGradient: beforeRootEdit !== afterRootEdit}
  })

  const localLit = await page.$("#button-lit-local")
  await localLit.hover()
  const hovered = await localLit.evaluate(node => {
    const style = getComputedStyle(node)
    return {background: style.backgroundColor, gradient: style.backgroundImage}
  })
  await page.mouse.down()
  const pressedShadow = await localLit.evaluate(node => getComputedStyle(node).boxShadow)
  await page.mouse.up()

  assert.equal(result.styles["button-flat-local"].background, "rgb(160, 32, 240)")
  assert.equal(result.styles["button-lit-local"].background, "rgb(160, 32, 240)")
  assert.equal(result.styles["button-flat-local"].radius, "9px")
  assert.equal(result.styles["button-lit-local"].radius, "9px")
  assert.match(result.styles["button-lit-local"].gradient, /linear-gradient/)
  assert.notEqual(result.styles["button-lit-local"].gradient, result.sibling.gradient,
    "local primary input changes the lit button gradient")
  assert.equal(hovered.background, "rgb(123, 31, 162)", "hover reads the local primary-hover input")
  assert.notEqual(hovered.gradient, result.sibling.gradient, "hover gradient reads local palette inputs")
  assert.equal((pressedShadow.match(/inset/g) || []).length, 2, "pressed lighting reads local hover palette")
  assert.equal(result.styles["card-flat-local"].radius, "11px")
  assert.equal(result.styles["card-raised-local"].radius, "11px")
  assert.notEqual(result.styles["card-raised-local"].shadow, "none")
  assert.notEqual(result.styles["card-raised-local"].shadow, result.sibling.cardShadow,
    "local secondary input changes the raised card shadow")
  assert.deepEqual(result.sibling, result.baseline, "local clones leave the untouched siblings unchanged")
  assert.equal(result.rootEditChangesGradient, true, "root primary edit still reaches the lit gradient")

  await page.evaluate(() => {
    const remove = container => {
      for (let i = container.cssRules.length - 1; i >= 0; i--) {
        const rule = container.cssRules[i]
        if (rule.type === CSSRule.SUPPORTS_RULE && rule.conditionText.includes("color-mix(")) container.deleteRule(i)
        else if (rule.cssRules) remove(rule)
      }
    }
    for (const sheet of document.styleSheets) {
      try { remove(sheet) } catch {}
    }
  })
  await page.mouse.move(0, 0)
  const fallback = await localLit.evaluate(node => {
    const style = getComputedStyle(node)
    return {background: style.backgroundColor, gradient: style.backgroundImage, top: style.borderTopColor}
  })
  assert.equal(fallback.gradient, "none", "component-local fallback stays solid")
  assert.equal(fallback.background, "rgb(160, 32, 240)")
  assert.equal(fallback.top, fallback.background, "fallback edge follows the local primary role")
  console.log("PASS: component-local inputs, sibling isolation and root token propagation", JSON.stringify(result))
} finally {
  await browser.close()
}
