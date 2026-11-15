// Read-only DEV proof. Browser tooling stays outside application dependencies.
import assert from "node:assert/strict"
import {createRequire} from "node:module"
import {resolve} from "node:path"
import {verifySurfaceContracts,verifySurfaceReflow} from "./design_surface_contract.mjs"
const require=createRequire(resolve(process.env.BROWSER_TOOLS_ROOT || ".","package.json"))
const browser=await require("puppeteer-core").launch({executablePath:process.env.CHROME_PATH || "/usr/bin/google-chrome",headless:true,
  args:["--blink-settings=primaryHoverType=2,availableHoverTypes=2,primaryPointerType=4,availablePointerTypes=4"]})
const base=process.env.DESIGN_SYSTEM_URL || "http://127.0.0.1:4237"
let checks=0,minimum
const check=(ok,message)=>{assert.ok(ok,message);checks++}
const backTab=async page=>{await page.keyboard.down("Shift");await page.keyboard.press("Tab");await page.keyboard.up("Shift")}
try {
  let page=await browser.newPage()
  const errors=[]
  page.on("pageerror",e=>errors.push(e.message))
  await page.setViewport({width:1440,height:1000})
  await page.goto(`${base}/dev/design-system`,{waitUntil:"networkidle0"})
  await page.evaluate(()=>document.fonts.ready)
  await page.waitForFunction(()=>[...document.querySelectorAll("#surface-pairings [data-contrast-result]")].length===24 &&
    [...document.querySelectorAll("#surface-pairings [data-contrast-result]")].every(n=>n.textContent.includes(":1")))
  check(await page.$$eval('#surface-pairings [data-contrast-kind="focus"]',nodes=>nodes.length===4 && nodes.every(n=>
    n.textContent.trim()==="" && n.getAttribute("aria-hidden")==="true" && n.parentElement.querySelector("output").textContent.includes("Focus colour meets 3:1"))),"focus readout uses non-text swatch and 3:1 grading")
  for(const width of [320,390,744,1128,1920]) {
    await page.setViewport({width,height:1000})
    const result=await page.evaluate(verifySurfaceContracts)
    checks+=result.checks;minimum=result.minimum
    checks+=(await page.evaluate(verifySurfaceReflow)).checks
    check(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),"pairing page fits viewport")
  }
  // A fresh desktop page retains real hover capability after CDP viewport runs.
  await page.close();page=await browser.newPage()
  page.on("pageerror",e=>errors.push(e.message))
  await page.setViewport({width:1440,height:1000})
  await page.goto(`${base}/dev/design-system`,{waitUntil:"networkidle0"})
  check(await page.evaluate(()=>matchMedia("(hover: hover)").matches),"desktop hover capability")
  const link=await page.$("#pair-local-link")
  await link.evaluate(n=>n.scrollIntoView({block:"center"}));await page.mouse.move(0,0)
  const rest=await link.evaluate(n=>getComputedStyle(n).color)
  await link.hover()
  await page.waitForFunction(()=>document.getElementById("pair-local-link").matches(":hover"))
  check(await link.evaluate((n,rest)=>getComputedStyle(n).color!==rest && getComputedStyle(n).textDecorationLine.includes("underline"),rest),"local shared link hover follows its role and retains underline")
  await page.bringToFront();await page.focus("#pair-nested-link");await backTab(page);await page.keyboard.press("Tab")
  check(await page.$eval("#pair-nested-link",n=>{
    const s=getComputedStyle(n)
    return n===document.activeElement && n.matches(":focus-visible") && s.outlineStyle==="solid" && s.outlineWidth==="2px" &&
      s.outlineOffset==="4px" && s.outlineColor===getComputedStyle(document.querySelector("#pair-plain-probe-focus")).color
  }),"nested link keyboard outline consumes its reset focus role")
  // Mutate only the outer profile's focus input, then verify native focus color.
  await page.$eval("#pair-local",n=>n.style.setProperty("--surface-canvas-focus","var(--secondary)"))
  await page.focus("#pair-nested-link");await backTab(page)
  check(await page.$eval("#pair-local-link",n=>n===document.activeElement && n.matches(":focus-visible") &&
    getComputedStyle(n).outlineColor===getComputedStyle(document.getElementById("pair-nested-body")).color),`outer local focus input reaches actual keyboard outline ${JSON.stringify(await page.$eval("#pair-local-link",n=>({active:document.activeElement.id,visible:n.matches(":focus-visible"),outline:getComputedStyle(n).outlineColor,expected:getComputedStyle(document.getElementById("pair-nested-body")).color,context:getComputedStyle(n).getPropertyValue("--context-focus")})))}`)
  await page.$eval("#pair-local",n=>n.removeAttribute("style"))
  // Named backgrounds must refuse missing, translucent or image-bearing grounds.
  const measurement=()=>page.$eval('#pair-plain-probe-body',n=>n.parentElement.querySelector("output").textContent)
  await page.waitForFunction(()=>document.querySelector('#pair-plain-probe-body + output').textContent.includes(":1"))
  for(const mode of ["missing","transparent","gradient"]) {
    await page.evaluate(mode=>{
      const probe=document.getElementById("pair-plain-probe-body"),ground=document.getElementById("pair-plain")
      if(mode==="missing")probe.dataset.contrastBackground="absent-ground"
      if(mode==="transparent")ground.style.setProperty("--surface-plain-bg","transparent")
      if(mode==="gradient")ground.style.backgroundImage="var(--design-gradient-soft)"
      dispatchEvent(new Event("resize"))
    },mode)
    await page.waitForFunction(()=>document.querySelector('#pair-plain-probe-body + output').textContent.startsWith("Not measured"))
    check((await measurement()).startsWith("Not measured"),`${mode} ground is not falsely scored`)
    await page.evaluate(()=>{
      document.getElementById("pair-plain-probe-body").dataset.contrastBackground="pair-plain"
      document.getElementById("pair-plain").removeAttribute("style");dispatchEvent(new Event("resize"))
    })
    await page.waitForFunction(()=>document.querySelector('#pair-plain-probe-body + output').textContent.includes(":1"))
  }
  await page.emulateMediaFeatures([{name:"prefers-reduced-motion",value:"reduce"}])
  check(await page.$$eval("#surface-pairings .ds-surface",nodes=>nodes.every(n=>{const s=getComputedStyle(n);return s.animationName==="none" && s.transitionDuration==="0s"})),"surface boundaries remain static under reduced motion")
  await page.emulateMediaFeatures([{name:"forced-colors",value:"active"}])
  check(await page.$$eval("#surface-pairings .ds-surface",nodes=>nodes.every(n=>{
    const s=getComputedStyle(n),canvas=document.createElement("div")
    canvas.style.backgroundColor="Canvas";canvas.style.color="CanvasText";document.body.append(canvas)
    const expected=getComputedStyle(canvas),ok=s.backgroundColor===expected.backgroundColor && s.color===expected.color && s.backgroundImage==="none"
    canvas.remove();return ok
  })),"forced colors resets all nested surfaces to system canvas/text")
  await page.focus("#pair-nested-link");await backTab(page);await page.keyboard.press("Tab")
  check(await page.$eval("#pair-nested-link",n=>n.matches(":focus-visible") && parseFloat(getComputedStyle(n).outlineWidth)>=2),"forced colors retains actual keyboard focus")
  check(await page.$$eval("#surface-pairings .ds-design-card",nodes=>nodes.every(n=>getComputedStyle(n).boxShadow==="none")),"forced colors retains existing card shadow removal")
  await page.emulateMediaFeatures([])
  const removed=await page.evaluate(()=>{
    const trim=container=>{let count=0;for(let i=container.cssRules.length-1;i>=0;i--){const r=container.cssRules[i];if((r.conditionText||"").includes("color-mix(")){container.deleteRule(i);count++}else if(r.cssRules)count+=trim(r)}return count}
    return [...document.styleSheets].reduce((n,s)=>n+trim(s),0)
  })
  check(removed>0,"shipped color-mix enhancement selected for fallback proof")
  checks+=(await page.evaluate(verifySurfaceContracts)).checks
  await page.reload({waitUntil:"networkidle0"})
  await page.$eval("#surface-pairings",n=>n.scrollIntoView())
  await page.screenshot({path:"/tmp/newyou-surfaces-1440.png",fullPage:false})
  await page.$eval("#pair-local",n=>n.scrollIntoView({block:"center"}))
  await page.screenshot({path:"/tmp/newyou-surfaces-nested.png",fullPage:false})
  await page.setViewport({width:320,height:1000});await page.$eval("#surface-pairings",n=>n.scrollIntoView())
  await page.screenshot({path:"/tmp/newyou-surfaces-320.png",fullPage:false})
  assert.deepEqual(errors,[]);checks++
  await page.setJavaScriptEnabled(false);await page.reload({waitUntil:"networkidle0"})
  check(await page.$$eval("#surface-pairings .ds-surface",nodes=>nodes.length>=8 && nodes.every(n=>getComputedStyle(n).backgroundColor!=="rgba(0, 0, 0, 0)")),"server-rendered surfaces work without JavaScript")
  check(await page.$eval('#pair-plain-probe-body + output',n=>n.textContent==="Measured in browser"),"no-script readout makes no computed contrast claim")
  console.log(JSON.stringify({status:"PASS",checks,browser:await browser.version(),minimum,exclusions:["WebKit","true browser zoom","screen reader"]}))
} finally {await browser.close()}
