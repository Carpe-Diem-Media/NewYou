// Geometry proof for the actual guide specimens. No application dependency.
// This function also runs through T3 preview_evaluate on the shared browser.
export async function verifyLayoutFoundations() {
  let checks = 0
  const check = (ok, message) => { if (!ok) throw new Error(message); checks++ }
  const near = (a, b, message) => check(Math.abs(a - b) < 1, `${message}: ${a} != ${b}`)
  const byId = id => { const el = document.getElementById(id); check(!!el, `${id} exists`); return el }
  const box = el => el.getBoundingClientRect()
  const settle = () => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))
  const lab = byId("layout-lab")
  const fit = byId("layout-auto-fit"), fill = byId("layout-auto-fill")
  const fixed = byId("layout-fixed"), container = byId("layout-container")
  const breakout = byId("layout-breakout")
  const nodes = [lab, fit, fill, fixed, container, breakout, ...lab.querySelectorAll(".ds-layout-stage")]
  const snapshots = nodes.map(el => [el, el.getAttribute("style"), el.innerHTML, el.getAttribute("data-alignment")])
  const setCount = (el, n) => {
    const sample = el.firstElementChild.cloneNode(true)
    el.replaceChildren(...Array.from({length: n}, () => sample.cloneNode(true)))
  }
  const allocate = (el, width) => {
    const stage = el.closest(".ds-layout-stage")
    stage.style.maxInlineSize = "none"
    stage.style.inlineSize = `${width}px`
  }
  const rowRects = el => [...el.children].map(box)
  const noOverflow = (el, label) => check(el.scrollWidth <= el.clientWidth + 1, `${label} has no internal overflow`)
  try {
    const min = parseFloat(getComputedStyle(fit).getPropertyValue("--design-layout-min")) * parseFloat(getComputedStyle(document.documentElement).fontSize)
    check(Number.isFinite(min) && min > 0, "default minimum is a positive rem length")
    for (const minimum of [min, 120]) {
      for (const el of [fit, fill]) el.style.setProperty("--design-layout-min", `${minimum}px`)
      const gap = parseFloat(getComputedStyle(fit).columnGap)
      for (const width of [minimum - 1, minimum, 2 * minimum + gap - 1, 2 * minimum + gap, 2 * minimum + gap + 1,
        3 * minimum + 2 * gap - 1, 3 * minimum + 2 * gap, 3 * minimum + 2 * gap + 1, 800]) {
        const capacity = Math.max(1, Math.min(3, Math.floor((width + gap + 0.01) / (minimum + gap))))
        for (const count of [1, 2, 3, 4, 5, 6, 7]) {
          for (const [el, mode] of [[fit, "fit"], [fill, "fill"]]) {
            allocate(el, width); setCount(el, count)
            const rects = rowRects(el), grid = box(el)
            const occupied = Math.min(capacity, count)
            const first = rects.filter(r => Math.abs(r.top - rects[0].top) < 1)
            check(first.length === occupied, `${mode}: ${count} items, W=${width}, expected ${occupied} occupied columns`)
            const used = mode === "fit" ? occupied : capacity
            near(rects[0].width, (width - (used - 1) * gap) / used, `${mode} used track width`)
            for (const r of rects) check(r.left >= grid.left - 1 && r.right <= grid.right + 1, "auto-grid child stays in allocation")
            const final = rects.filter(r => Math.abs(r.top - rects.at(-1).top) < 1)
            near(final[0].left, grid.left, "intrinsic incomplete rows align to start")
            noOverflow(el, mode)
          }
        }
      }
    }
    for (const width of [288, 800]) {
      allocate(fixed, width)
      const tracks = getComputedStyle(fixed).gridTemplateColumns.split(" ").length
      const columns = tracks === 1 ? 1 : tracks / 2
      for (const alignment of ["start", "center"]) for (let count = 1; count <= 2 * columns + 1; count++) {
        fixed.dataset.alignment = alignment; setCount(fixed, count)
        const grid = box(fixed), rects = rowRects(fixed)
        const first = rects.filter(r => Math.abs(r.top - rects[0].top) < 1)
        check(first.length === Math.min(count, columns), "fixed visual column count")
        const row = rects.filter(r => Math.abs(r.top - rects.at(-1).top) < 1)
        if (alignment === "center") near((row[0].left + row.at(-1).right) / 2, (grid.left + grid.right) / 2, "fixed remainder centre")
        else near(row[0].left, grid.left, "fixed remainder start")
        rects.forEach(r => near(r.width, rects[0].width, "fixed card widths remain equal"))
        noOverflow(fixed, "fixed grid")
      }
    }
    for (const width of [240, 320, 900]) {
      allocate(container, width)
      const css = getComputedStyle(container), stage = box(container.parentElement), rect = box(container)
      const cap = parseFloat(css.maxInlineSize)
      near(rect.width, Math.min(width, cap), "container cap measures border box")
      near(rect.left - stage.left, stage.right - rect.right, "container is centred")
      check(css.boxSizing === "border-box", "container uses border-box")
      const nested = container.querySelector(".ds-layout-nested")
      near(box(nested).width, rect.width - parseFloat(css.paddingInlineStart) - parseFloat(css.paddingInlineEnd), "one gutter owner")
      near(parseFloat(getComputedStyle(nested).paddingInlineStart), 0, "nested content does not add a gutter")
      noOverflow(container, "container")
    }
    container.style.setProperty("--gutter", "40px")
    near(parseFloat(getComputedStyle(container).paddingInlineStart), 40, "local gutter input recomputes at consumer")
    container.style.setProperty("--content-width", "800px")
    near(parseFloat(getComputedStyle(container).maxInlineSize), 400, "local content cap recomputes at consumer")
    for (const width of [240, 320, 900]) {
      allocate(breakout, width)
      const zones = Object.fromEntries([...breakout.children].map(el => [el.dataset.zone || "default", box(el)]))
      const frame = box(breakout), css = getComputedStyle(breakout)
      near(zones.full.width, width, "full breakout width")
      near(zones.content.width, Math.min(640, width - 48), "content lane excludes both gutters")
      near(zones.default.width, zones.content.width, "unmarked direct child uses content lane")
      check(zones.content.width <= zones.feature.width + 1 && zones.feature.width <= zones["feature-max"].width + 1 && zones["feature-max"].width <= width + 1, "breakout zones are monotonic")
      if (width === 900) {
        near(zones.feature.width, 640 + 2 * 24, "feature includes inner lanes")
        near(zones["feature-max"].width, 640 + 2 * 24 + 2 * 48, "feature-max includes both lane pairs")
      } else near(zones.feature.width, zones.content.width, "feature lanes collapse in narrow allocation")
      for (const r of Object.values(zones)) check(r.left >= frame.left - 1 && r.right <= frame.right + 1, "breakout stays in allocation")
      check(css.columnGap === "0px", "breakout lanes do not inherit grid gaps")
      const safe = breakout.querySelector('[data-zone="full-safe"]')
      near(parseFloat(getComputedStyle(safe).paddingInlineStart), 24, "full-safe owns its gutter")
      noOverflow(breakout, "breakout")
    }
    allocate(breakout, 240)
    const contentZone = breakout.querySelector('[data-zone="content"]')
    const zoneImage = document.createElement("img")
    zoneImage.alt = ""; zoneImage.width = 2000; zoneImage.height = 80
    zoneImage.src = 'data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" width="2000" height="80"/>'
    contentZone.append(zoneImage)
    await zoneImage.decode()
    noOverflow(breakout, "breakout intrinsic media")
    check(box(zoneImage).width <= box(contentZone).width, "breakout image fits its zone")
    const nestedMarker = breakout.querySelector('[data-zone="full"] span') || breakout.lastElementChild.querySelector('[data-zone="full"]')
    check(getComputedStyle(nestedMarker).gridColumnStart === "auto", "nested zone marker has no breakout placement")
    allocate(fit, 288); setCount(fit, 5)
    fit.firstElementChild.querySelector("p").textContent = "A".repeat(160) + " Lang Afrikaanse inhoud wat oor meer as een reël moet vloei."
    const image = document.createElement("img")
    image.alt = ""; image.width = 2000; image.height = 80
    image.src = 'data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" width="2000" height="80"/>'
    fit.firstElementChild.append(image)
    await image.decode()
    noOverflow(fit, "unbroken text and wide intrinsic media")
    check(box(image).width <= box(fit.firstElementChild).width, "intrinsic media shrinks")
    await settle()
  } finally {
    // Restore outer stages last: their original markup also restores all nested specimens.
    for (const [el, style, html, alignment] of snapshots) {
      style === null ? el.removeAttribute("style") : el.setAttribute("style", style)
      el.innerHTML = html
      alignment === null ? el.removeAttribute("data-alignment") : el.setAttribute("data-alignment", alignment)
    }
  }
  await settle()
  check(document.documentElement.scrollWidth <= innerWidth, "restored guide has no page overflow")
  return {checks, scope: "actual guide geometry; available width independent of viewport"}
}

// Runner uses the existing external browser setup, never an application package.
if (typeof process !== "undefined" && process.argv[1] && import.meta.url === new URL(`file://${process.argv[1]}`).href) {
  const {createRequire} = await import("node:module")
  const {resolve} = await import("node:path")
  const require = createRequire(resolve(process.env.BROWSER_TOOLS_ROOT || ".", "package.json"))
  const browser = await require("puppeteer-core").launch({executablePath: process.env.CHROME_PATH || "/usr/bin/google-chrome", headless: true})
  const assert = (await import("node:assert/strict")).default
  try {
    const page = await browser.newPage()
    const errors = []
    page.on("pageerror", error => errors.push(error.message))
    const base = process.env.DESIGN_SYSTEM_URL || "http://127.0.0.1:4237"
    const load = async (query = "") => {
      await page.goto(`${base}/dev/design-system${query}`, {waitUntil: "networkidle0"})
      await page.waitForFunction(() => window.liveSocket?.isConnected())
    }
    let checks = 0
    for (const width of [320, 744, 1440]) {
      await page.setViewport({width, height: 900})
      await load()
      const result = await page.evaluate(verifyLayoutFoundations)
      checks += result.checks
    }
    for (const width of [320, 390, 743, 744, 1127, 1128, 1920]) {
      await page.setViewport({width, height: 900})
      await load()
      const geometry = await page.evaluate(() => {
        const grid = document.querySelector("#layout-fixed")
        const rects = [...grid.children].map(el => el.getBoundingClientRect())
        return {columns: rects.filter(r => Math.abs(r.top - rects[0].top) < 1).length,
          overflow: document.documentElement.scrollWidth > innerWidth}
      })
      assert.equal(geometry.columns, width < 744 ? 1 : width < 1128 ? 2 : 3)
      assert.equal(geometry.overflow, false, `guide reflow at ${width}px`)
      checks += 2
    }
    await page.setViewport({width: 1440, height: 900})
    await load()
    await page.select("#layout-allocation", "narrow")
    await page.waitForSelector('#layout-lab[data-allocation="narrow"]')
    await page.select("#layout-count", "7")
    await page.waitForSelector('#layout-auto-fit > :nth-child(7)')
    assert.ok(page.url().includes("allocation=narrow"))
    const allocated = await page.$eval("#layout-auto-fit", el => el.getBoundingClientRect().width)
    assert.equal(allocated, 288)
    await page.evaluate(() => window.liveSocket.disconnect())
    await page.evaluate(() => window.liveSocket.connect())
    await page.waitForFunction(() => window.liveSocket.isConnected())
    assert.equal(await page.$eval("#layout-allocation", el => el.value), "narrow")
    assert.equal(await page.$$eval("#layout-auto-fit > *", els => els.length), 7)
    checks += 4
    await load()
    const tokens = await page.evaluate(() => {
      const root = document.documentElement
      root.style.setProperty("--gutter", "32px")
      root.style.setProperty("--grid-gap", "32px")
      root.style.setProperty("--content-width", "1000px")
      const container = document.querySelector("#layout-container")
      const fit = document.querySelector("#layout-auto-fit")
      const result = {gutter: getComputedStyle(container).paddingInlineStart,
        cap: getComputedStyle(container).maxInlineSize, gap: getComputedStyle(fit).columnGap}
      container.style.setProperty("--gutter", "40px")
      result.local = getComputedStyle(container).paddingInlineStart
      result.sibling = getComputedStyle(document.querySelector('[data-zone="full-safe"]')).paddingInlineStart
      root.style.setProperty("--design-layout-min", "160px")
      fit.parentElement.style.inlineSize = "360px"
      const columns = () => {
        const rects = [...fit.children].map(el => el.getBoundingClientRect())
        return rects.filter(r => Math.abs(r.top - rects[0].top) < 1).length
      }
      result.before = columns()
      root.style.setProperty("--design-layout-min", "180px")
      result.after = columns()
      root.style.setProperty("--design-layout-columns", "4")
      fit.parentElement.style.inlineSize = "900px"
      result.capColumns = columns()
      root.style.fontSize = "32px"
      root.style.setProperty("--design-layout-min", "12rem")
      result.largeRootColumns = columns()
      return result
    })
    assert.deepEqual(tokens, {gutter:"32px", cap:"500px", gap:"32px", local:"40px", sibling:"32px", before:2, after:1, capColumns:4, largeRootColumns:2})
    checks += 9
    await page.setViewport({width: 320, height: 900})
    await load()
    await page.evaluate(() => {
      const els = [...document.querySelectorAll("#layout-lab, #layout-lab *")]
      const sizes = els.map(el => parseFloat(getComputedStyle(el).fontSize))
      els.forEach((el, i) => el.style.fontSize = `${sizes[i] * 2}px`)
    })
    const textResize = await page.evaluate(() => ({
      overflow: document.documentElement.scrollWidth > innerWidth,
      controlFits: [...document.querySelectorAll("#layout-controls select")].every(el => el.getBoundingClientRect().right <= innerWidth),
      fontSize: getComputedStyle(document.querySelector("#layout-allocation")).fontSize
    }))
    assert.deepEqual(textResize, {overflow:false, controlFits:true, fontSize:"32px"})
    checks += 3
    await load()
    await page.focus("#layout-allocation")
    assert.equal(await page.$eval("#layout-allocation", el => getComputedStyle(el).outlineStyle), "solid")
    await page.keyboard.press("ArrowDown")
    await page.waitForSelector('#layout-lab[data-allocation="narrow"]')
    checks += 2
    await page.setViewport({width: 1440, height: 900})
    await load()
    await page.$eval("#layout-lab", el => el.scrollIntoView())
    await page.screenshot({path:"/tmp/newyou-phase2-layout-desktop.png"})
    await page.setViewport({width: 320, height: 900})
    await page.$eval("#layout-lab", el => el.scrollIntoView())
    await page.screenshot({path:"/tmp/newyou-phase2-layout-phone.png"})
    const nojs = await browser.newPage()
    await nojs.setJavaScriptEnabled(false)
    await nojs.setViewport({width: 320, height: 900})
    await nojs.goto(`${base}/dev/design-system?allocation=narrow`, {waitUntil: "networkidle0"})
    assert.equal(await nojs.$eval("#layout-auto-fit", el => el.getBoundingClientRect().height > 0), true)
    assert.equal(await nojs.$eval("#layout-breakout", el => el.getBoundingClientRect().height > 0), true)
    assert.equal(await nojs.$eval("#layout-lab output", el => el.textContent), "Not measured")
    assert.equal(await nojs.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true)
    checks += 4
    await nojs.close()
    assert.deepEqual(errors, [])
    console.log(JSON.stringify({checks, scope:"actual grid thresholds/remainders, containers, gutters, breakout, URL/reconnection, token propagation, 320px/200% text, focus and no-JS", browser:await browser.version()}))
  } finally { await browser.close() }
}
