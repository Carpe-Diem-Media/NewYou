// Read-only DEV guide proof. Browser tooling stays outside app dependencies.
import assert from "node:assert/strict"
import {createRequire} from "node:module"
import {resolve} from "node:path"
import {verifyBorderContracts,verifyBorderReflow} from "./design_border_contract.mjs"
const require=createRequire(resolve(process.env.BROWSER_TOOLS_ROOT || ".","package.json"))
const browser=await require("puppeteer-core").launch({executablePath:process.env.CHROME_PATH || "/usr/bin/google-chrome",headless:true,
  args:["--blink-settings=primaryHoverType=2,availableHoverTypes=2,primaryPointerType=4,availablePointerTypes=4"]})
let checks=0,fieldContrast
const check=(ok,message)=>{assert.ok(ok,message);checks++}
try {
  let page=await browser.newPage()
  const errors=[]
  page.on("pageerror",e=>errors.push(e.message))
  const base=process.env.DESIGN_SYSTEM_URL || "http://127.0.0.1:4237"
  await page.setViewport({width:1440,height:1000})
  await page.goto(`${base}/dev/design-system`,{waitUntil:"networkidle0"})
  await page.evaluate(()=>document.fonts.ready)
  await page.waitForFunction(()=>document.querySelector('[data-measure-target="border-field-control"]')?.textContent.trim()==="1px")
  check(await page.$$eval("#borders [data-measure-target]",nodes=>nodes.length===5 && nodes.every(n=>n.textContent.trim()===getComputedStyle(document.getElementById(n.dataset.measureTarget)).getPropertyValue(n.dataset.measureProperty))),"guide readouts use actual computed borders")
  for(const width of [320,744,1440]) {
    await page.setViewport({width,height:1000})
    const result=await page.evaluate(verifyBorderContracts)
    checks+=result.checks;fieldContrast=result.fieldContrast
    checks+=(await page.evaluate(verifyBorderReflow)).checks
    check(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),"document fits viewport")
  }
  // Repeated CDP viewport emulation clears Chromium pointer/hover capabilities.
  // Use a fresh document with one desktop viewport for native pointer proof.
  await page.close()
  page=await browser.newPage()
  page.on("pageerror",e=>errors.push(e.message))
  await page.setViewport({width:1440,height:1000})
  await page.goto(`${base}/dev/design-system`,{waitUntil:"networkidle0"})
  check(await page.evaluate(()=>matchMedia("(hover: hover)").matches),"desktop hover capability active")
  check(await page.evaluate(()=>{
    const a=document.getElementById("border-action-ready"),b=document.getElementById("border-action-pending")
    return a.textContent.trim()===b.textContent.trim() && Math.abs(a.getBoundingClientRect().width-b.getBoundingClientRect().width)<.5 &&
      a.getBoundingClientRect().height===b.getBoundingClientRect().height && b.disabled && b.getAttribute("aria-busy")==="true"
  }),"pending comparison retains native disabled and identical label/dimensions")
  const ready=await page.$("#border-action-ready"),pending=await page.$("#border-action-pending")
  const state=()=>ready.evaluate(n=>{const s=getComputedStyle(n);return{gradient:s.backgroundImage,shadow:s.boxShadow,top:s.borderTopColor,bottom:s.borderBottomColor}})
  await ready.evaluate(n=>n.scrollIntoView({block:"center"}))
  await page.mouse.move(0,0)
  await page.waitForFunction(()=>!document.getElementById("border-action-ready").matches(":hover"))
  const rest=await state()
  check(rest.gradient.includes("linear-gradient") && rest.top!==rest.bottom,"premium shine and directional border")
  await ready.hover()
  await page.waitForFunction(()=>document.getElementById("border-action-ready").matches(":hover"))
  const hovered=await state()
  check(hovered.gradient!==rest.gradient,`hover gradient retained ${JSON.stringify({rest,hovered,hover:await ready.evaluate(n=>n.matches(":hover"))})}`)
  await page.mouse.down();check(((await state()).shadow.match(/inset/g)||[]).length===2,"pressed inset shadow retained")
  await page.mouse.up()
  check(await pending.evaluate(n=>getComputedStyle(n).boxShadow==="none"),"disabled button has no elevated shadow")
  check(await page.evaluate(()=>{
    const n=document.getElementById("border-action-ready")
    n.setAttribute("aria-busy","true")
    const active=!n.disabled && n.matches(":enabled")
    n.removeAttribute("aria-busy");return active
  }),"aria-busy alone leaves native control enabled")
  // Enter keyboard modality and Tab through the two fields to the enabled CTA.
  await page.bringToFront()
  await page.focus("#border-field-control")
  await page.keyboard.press("Tab")
  check(await page.evaluate(()=>{
    const n=document.activeElement,s=getComputedStyle(n)
    return n.id==="border-field-invalid" && n.matches(":focus-visible") && s.outlineWidth==="2px" && s.outlineOffset==="2px" && s.borderTopWidth==="2px"
  }),"invalid boundary and separate keyboard focus coexist")
  await page.keyboard.press("Tab")
  check(await page.evaluate(()=>document.activeElement.id==="border-action-ready" && document.activeElement.matches(":focus-visible")),"keyboard reaches enabled CTA")
  await page.keyboard.press("Tab")
  check(await page.evaluate(()=>document.activeElement.id!=="border-action-pending"),"disabled pending CTA excluded from keyboard order")
  await page.emulateMediaFeatures([{name:"prefers-reduced-motion",value:"reduce"}])
  check(await ready.evaluate(n=>{const s=getComputedStyle(n);return s.animationName==="none" && s.transitionDuration==="0s"}),"static treatment under reduced motion")
  await page.emulateMediaFeatures([{name:"forced-colors",value:"active"}])
  for(const id of ["border-action-ready","border-action-pending","border-card-lit"]) {
    check(await page.$eval(`#${id}`,n=>{const s=getComputedStyle(n);return s.backgroundImage==="none" && s.boxShadow==="none" && s.borderTopStyle!=="none" && parseFloat(s.borderTopWidth)>=1}),`forced colors retains native boundary ${id}`)
  }
  await page.focus("#border-field-control");await page.keyboard.press("Tab")
  check(await page.$eval("#border-field-invalid",n=>{const s=getComputedStyle(n);return n.matches(":focus-visible") && s.outlineStyle!=="none" && parseFloat(s.outlineWidth)>0}),"forced colors preserves field keyboard outline")
  await page.emulateMediaFeatures([])
  await page.setViewport({width:320,height:1000})
  await page.$eval("#borders",n=>n.scrollIntoView())
  await page.screenshot({path:"/tmp/newyou-borders-320.png",fullPage:false})
  await page.setViewport({width:1440,height:1000})
  await page.$eval("#borders",n=>n.scrollIntoView())
  await page.screenshot({path:"/tmp/newyou-borders-1440.png",fullPage:false})
  await ready.evaluate(n=>n.scrollIntoView({block:"center"}))
  await page.screenshot({path:"/tmp/newyou-borders-divider-actions.png",fullPage:false})
  assert.deepEqual(errors,[]);checks++
  await page.setJavaScriptEnabled(false)
  await page.goto(`${base}/dev/design-system`,{waitUntil:"networkidle0"})
  check(await page.$eval("#border-field-control",n=>parseFloat(getComputedStyle(n).borderTopWidth)===1),"server-rendered boundary works without JavaScript")
  check(await page.$eval("#border-action-pending",n=>n.disabled && n.getAttribute("aria-busy")==="true"),"no-JavaScript pending comparison retains native semantics")
  console.log(`PASS: ${checks} border assertions; field boundary ${fieldContrast.toFixed(2)}:1; ${await browser.version()}`)
} finally {await browser.close()}
