// Repeatable proof against shared components rendered by the real guide.
import assert from "node:assert/strict"
import {createRequire} from "node:module"
import {resolve} from "node:path"
const require = createRequire(resolve(process.env.BROWSER_TOOLS_ROOT || ".", "package.json"))
const browser = await require("puppeteer-core").launch({
  executablePath: process.env.CHROME_PATH || "/usr/bin/google-chrome", headless: true
})
const page = await browser.newPage()
const errors = []
page.on("pageerror", error => errors.push(error.message))
const base = process.env.DESIGN_SYSTEM_URL || "http://127.0.0.1:4237"
let checks = 0
const check = (condition, message) => {assert.ok(condition, message); checks++}
try {
  await page.setViewport({width: 1440, height: 1000})
  await page.goto(`${base}/dev/design-system#contracts`, {waitUntil: "networkidle0"})
  await page.waitForSelector("#contract-card-local > .ds-design-card-inset")
  const geometry = await page.evaluate(() => {
    const card = document.querySelector("#contract-card-local")
    const sibling = document.querySelector("#contract-card-default")
    const measure = node => {
      const s = getComputedStyle(node), inset = getComputedStyle(node.querySelector(":scope > .ds-design-card-inset"))
      return {radius: s.borderTopLeftRadius, border: s.borderTopWidth, x: s.paddingInlineStart,
        y: s.paddingBlockStart, inset: inset.borderTopLeftRadius, shadow: s.boxShadow, overflow: s.overflow,
        z: s.zIndex}
    }
    const initial = measure(card), baseline = measure(sibling), cases = []
    // All edits are test-only and restored before the next proof.
    for (const [radius, border, x, y] of [[32,1,16,12],[32,1,0,0],[16,1,48,48],[32,4,8,16],[8,2,2,4]]) {
      card.style.setProperty("--radius", `${radius}px`)
      card.style.setProperty("--design-border-width", `${border}px`)
      card.style.setProperty("--design-card-padding-inline", `${x}px`)
      card.style.setProperty("--design-card-padding-block", `${y}px`)
      cases.push({input: {radius, border, x, y}, value: measure(card)})
    }
    card.removeAttribute("style")
    const parent = card.parentElement
    parent.style.setProperty("--design-card-padding-inline", "8px")
    const inherited = measure(sibling)
    parent.removeAttribute("style")
    const root = document.documentElement
    root.style.setProperty("--radius", "24px")
    root.style.setProperty("--space-lg", "8px")
    const rootEdit = measure(sibling)
    root.removeAttribute("style")
    return {initial, baseline, cases, inherited, rootEdit, restored: measure(sibling)}
  })
  check(geometry.initial.radius === "32px" && geometry.initial.inset === "15px 19px", "local concentric geometry")
  check(geometry.baseline.radius === "16px" && geometry.baseline.inset === "0px", "default geometry clamps at zero")
  check(geometry.baseline.shadow === "none" && geometry.initial.shadow !== "none", "bounded elevation opt-in")
  check(geometry.initial.overflow === "visible" && geometry.initial.z === "auto", "card does not clip focus or change stacking")
  for (const {input: i, value: v} of geometry.cases) {
    const x = Math.max(0, i.radius - i.border - i.x), y = Math.max(0, i.radius - i.border - i.y)
    check(v.inset === (x === y ? `${x}px` : `${x}px ${y}px`), `per-axis radius ${JSON.stringify(i)}`)
  }
  check(geometry.inherited.x === "8px", "ancestor optional input survives consumer derivation")
  check(geometry.rootEdit.inset === "15px" && geometry.rootEdit.radius === "24px", "root source edits propagate")
  assert.deepEqual(geometry.restored, geometry.baseline); checks++
  check(await page.evaluate(() => {
    const body = document.querySelector("#contract-card-default > .ds-design-card-body")
    const child = document.createElement("div")
    child.className = "ds-design-card-inset"
    body.append(child)
    const s = getComputedStyle(child)
    const untouched = s.paddingTop === "0px" && s.borderTopLeftRadius === "0px" && s.overflow === "visible"
    child.remove()
    return untouched
  }), "inset styling affects explicit direct children only")
  const icons = await page.evaluate(() => {
    const nodes = [...document.querySelectorAll("#contracts .ds-icon-list .ds-design-icon")]
    return nodes.map(n => {
      const glyph = n.firstElementChild, s = getComputedStyle(glyph)
      return {size: n.dataset.size, width: s.width, height: s.height, mask: s.maskImage,
        color: getComputedStyle(n).color, glyphColor: s.backgroundColor,
        hidden: n.getAttribute("aria-hidden"), role: n.getAttribute("role"), label: n.getAttribute("aria-label")}
    })
  })
  for (const icon of icons) {
    check(icon.width === ({sm:"16px",md:"24px",lg:"32px"})[icon.size] && icon.height === icon.width, "finite nonzero glyph sizes")
    check(icon.mask !== "none" && icon.color === icon.glyphColor, "Heroicons artwork and currentColor")
    check(icon.label ? icon.role === "img" && icon.hidden === null : icon.hidden === "true" && icon.role === null, "icon semantics")
  }
  check(await page.evaluate(() => {
    const icon = document.querySelector("#contract-icon-named"), parent = icon.parentElement
    const before = getComputedStyle(icon.firstElementChild).width
    parent.style.setProperty("--design-icon-size", "32px")
    const local = getComputedStyle(icon.firstElementChild).width
    const sibling = getComputedStyle(document.querySelector("#contracts .ds-icon-list .ds-design-icon").firstElementChild).width
    parent.removeAttribute("style")
    return before === "24px" && local === "32px" && sibling === "16px"
  }), "icon ancestor override and sibling isolation")
const contrast = await page.evaluate(() => {
    const canvas = document.createElement("canvas"), ctx = canvas.getContext("2d", {willReadFrequently:true})
    const rgb = color => {ctx.clearRect(0,0,1,1); ctx.fillStyle=color; ctx.fillRect(0,0,1,1); return [...ctx.getImageData(0,0,1,1).data].slice(0,3)}
    const luminance = color => rgb(color).map(v => {v/=255; return v<=0.04045?v/12.92:((v+0.055)/1.055)**2.4}).reduce((a,v,i)=>a+v*[0.2126,0.7152,0.0722][i],0)
    return [...document.querySelectorAll("#contracts .ds-design-icon[data-treatment=boxed]")].map(n => {
      const s=getComputedStyle(n), a=luminance(s.color), b=luminance(s.backgroundColor)
      return (Math.max(a,b)+0.05)/(Math.min(a,b)+0.05)
    })
  })
  check(contrast.every(ratio => ratio >= 3), "boxed icon contrast on its actual neutral surface")
  const idle = await page.$("#contract-idle"), busy = await page.$("#contract-busy")
  assert.deepEqual(await idle.evaluate(n => [n.offsetWidth,n.offsetHeight]), await busy.evaluate(n => [n.offsetWidth,n.offsetHeight])); checks++
  check(await busy.evaluate(n => n.disabled && n.getAttribute("aria-busy") === "true"), "native pending state")
  check(await page.evaluate(() => {
    const n = document.querySelector("#contract-busy"); let count = 0
    n.addEventListener("click", () => count++, {once:true}); n.click(); return count === 0
  }), "disabled blocks activation")
  const action = await page.$("#contract-icon-action")
  await action.focus()
  await page.keyboard.press("Space")
  check(await page.$eval("#token-status", n => n.textContent === "Measurements refreshed from CSS."), "named icon action activates with the keyboard")
  await page.keyboard.press("Tab")
  check(await page.evaluate(() => document.activeElement.id === "contract-idle" && getComputedStyle(document.activeElement).outlineStyle !== "none"), "keyboard focus and order")
  await page.keyboard.press("Tab")
  check(await page.evaluate(() => document.activeElement.id !== "contract-busy"), "disabled skips keyboard focus")
  for (const width of [320, 744, 1440]) {
    await page.setViewport({width, height:1000})
    for (const scale of [1,2]) {
      const fit = await page.evaluate(scale => {
        const section = document.querySelector("#contracts")
        const nodes = [...section.querySelectorAll("p, h3, a, button")]
        for (const n of nodes) {
          if (!n.dataset.originalSize) n.dataset.originalSize = getComputedStyle(n).fontSize
          n.style.fontSize = `${parseFloat(n.dataset.originalSize) * scale}px`
        }
        const body = document.querySelector("#contract-card-local > .ds-design-card-body p")
        body.textContent = "A long English label and 'n lang Afrikaanse beskrywing. " + "LangOnonderbrokeBeskrywing".repeat(12)
        return [...section.querySelectorAll("article, .ds-design-card-body, .ds-design-card-inset, button")].every(n => n.scrollWidth <= n.clientWidth + 1 && n.scrollHeight <= n.clientHeight + 1)
          && document.documentElement.scrollWidth <= innerWidth + 1
      }, scale)
      check(fit, `reflow at ${width}px, ${scale * 100}% text`)
    }
  }
  await page.setViewport({width:1440,height:1000})
  await page.goto(`${base}/dev/design-system#contracts`, {waitUntil:"networkidle0"})
  await page.reload({waitUntil:"networkidle0"})
  await page.emulateMediaFeatures([{name:"prefers-reduced-motion",value:"reduce"}])
  check(await page.evaluate(() => {
    const n = document.querySelector("#contract-idle"), s = getComputedStyle(n)
    return n.offsetHeight > 0 && s.animationName === "none" && s.transitionDuration === "0s"
  }), "reduced motion requires no animation")
  const session = await page.createCDPSession()
  for (const scheme of ["light","dark"]) {
    await session.send("Emulation.setEmulatedMedia", {features:[{name:"forced-colors",value:"active"},{name:"prefers-color-scheme",value:scheme}]})
    check(await page.evaluate(() => {
      const n = document.querySelector("#contract-idle"), s = getComputedStyle(n)
      const icon = getComputedStyle(document.querySelector("#contracts .ds-design-icon[data-treatment=boxed]"))
      return matchMedia("(forced-colors:active)").matches && s.backgroundImage === "none" && s.boxShadow === "none" && parseFloat(icon.borderTopWidth) > 0
    }), `forced ${scheme} colors retain boundaries without gradients or shadows`)
    check(await page.evaluate(() => [...document.querySelectorAll("#contracts .ds-design-icon-glyph")].every(n => {
      const s=getComputedStyle(n), parent=getComputedStyle(n.parentElement)
      return s.backgroundColor === parent.color && s.backgroundColor !== parent.backgroundColor
    })), `forced ${scheme} colors keep mask ink equal to the parent text color`)
  }
  // Exercise the real fallback declarations. This does not emulate an older browser.
  check(await page.evaluate(() => {
    let removed=0
    const visit=owner => {
      for (let i=owner.cssRules.length-1;i>=0;i--) {
        const rule=owner.cssRules[i]
        if (rule instanceof CSSSupportsRule && rule.conditionText.includes("forced-color-adjust: preserve-parent-color")) {
          owner.deleteRule(i); removed++
        } else if (rule.cssRules) visit(rule)
      }
    }
    for (const sheet of document.styleSheets) {try {visit(sheet)} catch {}}
    return removed>0 && [...document.querySelectorAll("#contracts .ds-design-icon-glyph")].every(n => {
      const s=getComputedStyle(n)
      return s.forcedColorAdjust === "none" && s.backgroundColor === s.color && s.backgroundColor !== "rgba(0, 0, 0, 0)"
    })
  }), "forced-color mask fallback uses system text ink")
  await session.send("Emulation.setEmulatedMedia", {features:[]})
  await page.$eval("#contracts", n => n.scrollIntoView())
  await page.screenshot({path:"/tmp/newyou-phase3-components-desktop.png"})
  await page.setViewport({width:390,height:1000})
  await page.$eval("#contracts", n => n.scrollIntoView())
  await page.screenshot({path:"/tmp/newyou-phase3-components-phone.png"})
  await page.setJavaScriptEnabled(false)
  await page.reload({waitUntil:"networkidle0"})
  check(await page.$eval("#contract-card-local", n => n.offsetHeight > 0), "no-JavaScript card visibility")
  check(await page.$eval("#contract-icon-named", n => n.offsetWidth > 0 && n.getAttribute("aria-label") === "Saved"), "no-JavaScript icon semantics")
  assert.deepEqual(errors, []); checks++
  console.log(`PASS: ${checks} component-contract assertions; Chromium ${await browser.version()}`)
} finally {await browser.close()}
