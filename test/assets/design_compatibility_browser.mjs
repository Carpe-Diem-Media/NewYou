// Read-only compatibility proof against the real guide and registration pilot.
// Browser tooling stays external. No account submissions or engine substitution.
import assert from "node:assert/strict"
import {createRequire} from "node:module"
import {mkdtemp, rm} from "node:fs/promises"
import {resolve, join} from "node:path"
import {verifyLayoutFoundations} from "./design_layouts_browser.mjs"
import {verifyTypeScale,verifyTypeScaleOverrides} from "./design_type_scale_browser.mjs"
import {verifyContentContracts,verifyContentReflow} from "./design_content_contract.mjs"

import {verifyBorderContracts,verifyBorderReflow} from "./design_border_contract.mjs"

import {verifySurfaceContracts,verifySurfaceReflow} from "./design_surface_contract.mjs"

const require=createRequire(resolve(process.env.BROWSER_TOOLS_ROOT || ".", "package.json"))
const engine=process.env.DESIGN_BROWSER || "chrome"
assert.ok(["chrome","firefox"].includes(engine),"DESIGN_BROWSER must explicitly select chrome or firefox")
if(engine==="firefox") {
  assert.ok(process.env.FIREFOX_PATH && process.env.FIREFOX_PROFILE_ROOT,"Firefox requires FIREFOX_PATH and a visible FIREFOX_PROFILE_ROOT")
}
const base=process.env.DESIGN_SYSTEM_URL || "http://127.0.0.1:4237"
let browser,profile,checks=0
const check=(ok,message)=>{assert.ok(ok,message);checks++}
const near=(a,b,message)=>check(Math.abs(a-b)<.1,`${message}: ${a} != ${b}`)
const launch=async(noScript=false)=>{
  if(engine==="firefox") profile=await mkdtemp(join(process.env.FIREFOX_PROFILE_ROOT,"newyou-design-proof-"))
  return require("puppeteer-core").launch({browser:engine,
    executablePath:engine==="firefox" ? process.env.FIREFOX_PATH : process.env.CHROME_PATH || "/usr/bin/google-chrome",
    ...(profile ? {userDataDir:profile} : {}),
    ...(engine==="firefox" && noScript ? {extraPrefsFirefox:{"javascript.enabled":false}} : {}),headless:true})
}
try {
  browser=await launch()
  let page=await browser.newPage()
  const errors=[],posts=[],focusDiagnostics={}
  const observe=p=>{
    p.on("pageerror",e=>errors.push(e.message))
    p.on("request",r=>{if(r.method()==="POST" && new URL(r.url()).pathname==="/register") posts.push(r.url())})
  }
  observe(page)
  await page.setViewport({width:1440,height:1000})
  await page.goto(`${base}/dev/design-system`,{waitUntil:"networkidle0"})
  await page.waitForFunction(()=>window.liveSocket?.isConnected())
  await page.evaluate(()=>document.fonts.ready)
  const features=await page.evaluate(()=>({
    oklch:CSS.supports("color","oklch(from red l c h)"),
    colorMix:CSS.supports("color","color-mix(in oklab, red, white)"),
    trigonometric:CSS.supports("width","calc(100px * tan(atan2(1px, 1px)))"),
    progress:CSS.supports("width","calc(100px * progress(50px, 0px, 100px))")
  }))
  check(features.oklch && features.colorMix,"current browser supports the enhanced color contract")
  checks+=(await page.evaluate(verifyTypeScaleOverrides)).checks
  for(const width of [320,744,1440]) {
    await page.setViewport({width,height:1000})
    checks+=(await page.evaluate(verifyLayoutFoundations)).checks
    checks+=(await page.evaluate(verifyContentContracts)).checks
    checks+=(await page.evaluate(verifyContentReflow)).checks
    checks+=(await page.evaluate(verifyBorderContracts)).checks
    checks+=(await page.evaluate(verifyBorderReflow)).checks
    checks+=(await page.evaluate(verifySurfaceContracts)).checks
    checks+=(await page.evaluate(verifySurfaceReflow)).checks
  }
  const components=await page.evaluate(()=>{
    const card=document.querySelector("#contract-card-local"),s=getComputedStyle(card)
    const radii=getComputedStyle(card.querySelector(":scope > .ds-design-card-inset")).borderTopLeftRadius.split(" ").map(parseFloat)
    const icon=document.querySelector("#contract-icon-named"),glyph=getComputedStyle(icon.firstElementChild)
    return {radii,expected:[parseFloat(s.borderTopLeftRadius)-parseFloat(s.borderTopWidth)-parseFloat(s.paddingInlineStart),
      parseFloat(s.borderTopLeftRadius)-parseFloat(s.borderTopWidth)-parseFloat(s.paddingBlockStart)],
      mask:glyph.maskImage,ink:glyph.backgroundColor===getComputedStyle(icon).color,size:parseFloat(glyph.width),
      label:icon.getAttribute("aria-label"),role:icon.getAttribute("role"),overflow:s.overflow}
  })
  check(components.radii.length===2,"unequal per-axis padding retains elliptical inset corners")
  components.radii.forEach((r,i)=>near(r,Math.max(0,components.expected[i]),"border/padding-aware inset radius"))
  check(components.mask!=="none" && components.ink && components.size===24,"actual named Heroicon artwork, ink and size")
  check(components.role==="img" && !!components.label && components.overflow==="visible","native card/icon accessibility boundaries")
  for(const locale of ["en","af"]) {
    const content=await page.$eval(`#prose-${locale}`,n=>({
      first:getComputedStyle(n.firstElementChild).marginBlockStart,last:getComputedStyle(n.lastElementChild).marginBlockEnd,
      paragraph:parseFloat(getComputedStyle(n.querySelectorAll(":scope > p")[1]).marginBlockStart),
      nested:parseFloat(getComputedStyle(n.querySelector("li > p + p")).marginBlockStart),
      marker:getComputedStyle(n.querySelector("ul")).listStyleType,
      divider:parseFloat(getComputedStyle(n.querySelector("hr")).marginBlockStart)
    }))
    check(content.first==="0px" && content.last==="0px" && content.marker==="disc",`${locale} scoped prose edges/native markers`)
    near(content.paragraph,24,"paragraph rhythm");near(content.nested,8,"nested paragraph rhythm");near(content.divider,24,"internal divider rhythm")
  }
  check(await page.evaluate(()=>{
    const n=document.querySelector("#prose-en"),sibling=document.querySelectorAll("#prose-af > p")[1]
    n.style.setProperty("--content-gap","40px")
    const ok=getComputedStyle(n.querySelectorAll(":scope > p")[1]).marginBlockStart==="40px" && getComputedStyle(sibling).marginBlockStart==="24px"
    n.removeAttribute("style");return ok
  }),"consumer-local content role isolates siblings")
  const d=await page.$eval("#content-divided",n=>{
    const [a,b]=n.children,c=getComputedStyle(b)
    return {gap:getComputedStyle(n).gap,distance:b.firstElementChild.getBoundingClientRect().top-a.getBoundingClientRect().bottom,
      expected:parseFloat(c.marginBlockStart)+parseFloat(c.borderBlockStartWidth)+parseFloat(c.paddingBlockStart)}
  })
  check(d.gap==="0px","divider group has a single spacing owner");near(d.distance,d.expected,"rendered separator equation")
  // Delete only shipped enhancement blocks to exercise their shipped fallbacks.
  // This selects real declarations; it does not emulate a historical browser.
  for(const mode of ["enhanced","trigonometric","static"]) {
    if(mode!=="enhanced") await page.evaluate(mode=>{
      const trim=rules=>{
        for(let i=rules.cssRules.length-1;i>=0;i--) {
          const r=rules.cssRules[i],condition=r.conditionText || ""
          if(condition.includes("progress(") || (mode==="static" && condition.includes("atan2("))) rules.deleteRule(i)
          else if(r.cssRules) trim(r)
        }
      }
      for(const sheet of document.styleSheets) trim(sheet)
    },mode)
    for(const rootSize of [16,32]) for(const width of new Set([320,480,840,1200,1440,
      30*rootSize-1,30*rootSize,52.5*rootSize,75*rootSize,75*rootSize+1])) {
      await page.setViewport({width,height:1000})
      const values=await page.evaluate(size=>{
        document.documentElement.style.fontSize=`${size}px`
        const css=getComputedStyle(document.documentElement),read=(id,p)=>parseFloat(getComputedStyle(document.getElementById(id))[p])
        return {method:css.getPropertyValue("--fluid-method").trim(),display:read("fluid-display","fontSize"),body:read("fluid-body","fontSize"),
          space:read("fluid-space","paddingBlockStart"),gutter:read("fluid-gutter","paddingInlineStart")}
      },rootSize)
      const method=mode==="static" ? "static" : mode==="enhanced" && features.progress ? "native-progress" : features.trigonometric ? "trigonometric" : "static"
      const p=method==="static" ? 0 : Math.max(0,Math.min(1,(width-30*rootSize)/(45*rootSize)))
      check(values.method===method,`selected fluid path ${mode}/${rootSize}/${width}`)
      near(values.display,rootSize*(2.5+p*1.5),"display interpolation")
      near(values.body,rootSize*(1+p*.125),"body interpolation")
      near(values.space,rootSize*(1+p*2),"spacing interpolation")
      near(values.gutter,rootSize*(1+p*.5),"gutter interpolation")
      checks+=(await page.evaluate(verifyTypeScale)).checks
    }
  }
  for(const locale of ["en","af"]) {
    await page.goto(`${base}/register?locale=${locale}`,{waitUntil:"networkidle0"})
    // Keyboard assertions require an active document, not browser chrome.
    await page.bringToFront()
    await page.waitForFunction(()=>document.hasFocus())
    check(await page.$eval("#registration-form",n=>!n.checkValidity() && !n.noValidate && n.method==="post"),"native required form contract")
    check(await page.$eval("#registration-submit",n=>n.type==="submit" && n.dataset.treatment==="lit" && getComputedStyle(n).backgroundImage!=="none"),"actual premium lit submit button")
    check(await page.evaluate(()=>[...document.fonts].some(f=>f.family.replaceAll('"',"")==="Inter" && f.status==="loaded") &&
      [400,500,700].every(w=>document.fonts.check(`${w} 16px Inter`))),"self-hosted Inter face and weights are available")
    for(const width of [320,390,744,1440,1920]) {
      await page.setViewport({width,height:1000})
      const result=await page.evaluate(()=>{
        const root=document.querySelector("main"),form=document.querySelector("#registration-form")
        const fits=()=>[root,...root.querySelectorAll("article,form,label,button,.ds-prose,.ds-divided")].every(n=>n.scrollWidth<=n.clientWidth+1 && n.scrollHeight<=n.clientHeight+1)
        const normal=fits(),columns=getComputedStyle(form).gridTemplateColumns.split(" ").length
        const sizes=[...root.querySelectorAll("h1,h2,p,a,label,legend,input,button")].map(n=>[n,n.getAttribute("style"),parseFloat(getComputedStyle(n).fontSize)])
        const paragraph=document.querySelector(".ds-registration-safety p"),copy=paragraph.textContent
        try {
          for(const [n,,size] of sizes)n.style.fontSize=`${size*2}px`
          paragraph.textContent+=" "+"LongEnglishContentLangAfrikaanseBeskrywing".repeat(10)
          return {normal,columns,doubled:fits(),exact:sizes.every(([n,,size])=>Math.abs(parseFloat(getComputedStyle(n).fontSize)-size*2)<.1)}
        } finally {
          for(const [n,style] of sizes) style===null ? n.removeAttribute("style") : n.setAttribute("style",style)
          paragraph.textContent=copy
        }
      })
      check(result.normal && result.columns===(width<=390 ? 1 : 2),`${locale} native grid/reflow at ${width}`)
      check(result.exact && result.doubled,`${locale} exact 200% long text at ${width}`)
    }
    check(await page.evaluate(()=>{
      const main=document.querySelector("main");main.style.inlineSize="320px"
      const ok=getComputedStyle(document.querySelector("#registration-form")).gridTemplateColumns.split(" ").length===1
      main.removeAttribute("style");return ok
    }),"component responds to its allocation")
    check(await page.evaluate(()=>{
      const root=document.documentElement,submit=document.querySelector("#registration-submit"),before=getComputedStyle(submit).backgroundImage
      root.style.setProperty("--content-gap","32px");root.style.setProperty("--section-space","40px");root.style.setProperty("--control-gap","20px")
      root.style.setProperty("--font-body","serif");root.style.setProperty("--primary","#004fbf")
      const ok=getComputedStyle(document.querySelector("#registration-privacy-copy > p + p")).marginBlockStart==="32px" &&
        getComputedStyle(document.querySelector(".ds-registration-content")).paddingBlockStart==="40px" && getComputedStyle(document.querySelector("nav.ds-row")).gap==="20px" &&
        getComputedStyle(document.querySelector(".ds-design-field-input")).fontFamily==="serif" && getComputedStyle(submit).backgroundImage!==before
      root.removeAttribute("style");return ok
    }),"actual contextual/font/action roles propagate")
    check(await page.$$eval('main a[href], main input:not([type=hidden]), main button',nodes=>nodes.length===12),"twelve application controls remain present")
    await page.$eval('nav a[lang=af]',n=>n.focus())
    await page.keyboard.press("Tab")
    await page.keyboard.down("Shift")
    try {await page.keyboard.press("Tab")} finally {await page.keyboard.up("Shift")}
    check(await page.evaluate(()=>{
      const n=document.activeElement,c=getComputedStyle(n)
      return document.hasFocus() && n.lang==="af" && c.outlineStyle==="solid" && parseFloat(c.outlineWidth)>=2
    }),`${locale} first application keyboard ring`)
    for(let i=0;i<11;i++) {
      await page.keyboard.press("Tab")
      check(await page.evaluate(index=>{
        const n=document.activeElement,c=getComputedStyle(n)
        const expected=document.querySelectorAll('main a[href], main input:not([type=hidden]), main button')[index]
        return n===expected && c.outlineStyle==="solid" && parseFloat(c.outlineWidth)>=2
      },i+1),`${locale} application keyboard order and ring ${i+2}`)
    }
    check(await page.evaluate(()=>document.activeElement.id==="registration-submit"),"native focus order ends at submit")
    // Hallmark renders in Chrome. This separate diagnostic must not tab Firefox
    // into browser chrome and deactivate the next locale's keyboard proof.
    // Never move, hide or restyle the injected developer toolbar.
    if(engine==="chrome") {
      const outside=[]
      for(let i=0;i<3;i++) {
        await page.keyboard.press("Tab")
        outside.push(await page.evaluate(()=>{
          const chain=[];let n=document.activeElement
          while(n) {const c=getComputedStyle(n);chain.push({tag:n.tagName,id:n.id,outline:c.outlineStyle,width:c.outlineWidth});n=n.shadowRoot?.activeElement}
          return {pageFocused:document.hasFocus(),chain}
        }))
      }
      focusDiagnostics[locale]=outside
    } else {
      focusDiagnostics[locale]="Not run: developer-toolbar diagnostic targets the Chrome Hallmark runtime"
    }
  }
  if(engine==="firefox") {
    // Firefox 160 does not implement BiDi emulation.setScriptingEnabled.
    // Use its native preference in a second, separately owned test profile.
    await browser.close();browser=undefined
    await rm(profile,{recursive:true,force:true});profile=undefined
    browser=await launch(true);page=await browser.newPage();observe(page)
  } else {await page.setJavaScriptEnabled(false)}
  await page.setViewport({width:320,height:1000})
  await page.goto("data:text/html,<p>No scripting</p><script>window.newYouScriptRan=true</script>")
  check(await page.evaluate(()=>window.newYouScriptRan!==true),"page scripts are actually disabled")
  for(const path of ["/dev/design-system","/register?locale=en","/register?locale=af"]) {
    await page.goto(`${base}${path}`,{waitUntil:"networkidle0"})
    check(await page.$eval("main",n=>n.offsetHeight>0 && n.scrollWidth<=n.clientWidth+1),`${path} no-JavaScript reflow`)
    check(await page.$eval(path.startsWith("/dev/") ? "#content-divider" : "#registration-safety-divider",n=>n.tagName==="HR" && parseFloat(getComputedStyle(n).borderBlockStartWidth)>0),"native no-JavaScript separator")
    if(path.startsWith("/dev/"))check(await page.evaluate(()=>typeof window.liveSocket==="undefined"),"guide client has not run")
    if(path.startsWith("/register"))check(await page.$eval('nav a[lang=en]',n=>n.href.endsWith("/register?locale=en")),"native no-JavaScript language link")
  }
  assert.deepEqual(posts,[]);checks++
  // Firefox reports navigation-time DEV live-reload socket failures as pageerror.
  // Keep those exact messages visible in the result; do not suppress LiveView,
  // application errors, other socket paths or arbitrary network failures.
  const reloadUrl=`${base.replace(/^http/,"ws")}/phoenix/live_reload/socket/websocket?vsn=2.0.0`
  const devReloadMessages=[`Firefox can’t establish a connection to the server at ${reloadUrl}.`,
    `The connection to ${reloadUrl} was interrupted while the page was loading.`]
  const devReloadErrors=errors.filter(e=>engine==="firefox" && devReloadMessages.includes(e))
  assert.deepEqual(errors.filter(e=>!devReloadErrors.includes(e)),[]);checks++
  console.log(JSON.stringify({status:"PASS",checks,browser:await browser.version(),puppeteer:require("puppeteer-core/package.json").version,
    features,focusDiagnostics,unresolvedDevReloadErrors:devReloadErrors,
    exclusions:["media-feature emulation","WebKit","true browser zoom","screen reader"]}))
} finally {
  try {if(browser) await browser.close()} finally {if(profile) await rm(profile,{recursive:true,force:true})}
}
