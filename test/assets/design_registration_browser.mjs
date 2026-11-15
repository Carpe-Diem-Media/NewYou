// Actual registration route proof. Only deliberately invalid POSTs are submitted.
import assert from "node:assert/strict"
import {createRequire} from "node:module"
import {resolve} from "node:path"
const require=createRequire(resolve(process.env.BROWSER_TOOLS_ROOT || ".", "package.json"))
const browser=await require("puppeteer-core").launch({executablePath:process.env.CHROME_PATH || "/usr/bin/google-chrome",headless:true})
const page=await browser.newPage()
const base=process.env.DESIGN_SYSTEM_URL || "http://127.0.0.1:4237"
const errors=[]
page.on("pageerror",e=>errors.push(e.message))
let checks=0
const check=(v,message)=>{assert.ok(v,message);checks++}
const geometry=()=>page.evaluate(()=>{
  const form=document.querySelector("#registration-form"), fields=[...form.querySelectorAll(".ds-design-field-input")]
  const container=document.querySelector(".ds-registration-content"), c=getComputedStyle(container)
  return {columns:getComputedStyle(form).gridTemplateColumns.split(" ").length,
    fits:[...document.querySelectorAll("main, article, form, label, .ds-design-field, .ds-field-error, button")].every(n=>n.scrollWidth<=n.clientWidth+1 && n.scrollHeight<=n.clientHeight+1),
    pageFits:document.documentElement.scrollWidth<=innerWidth+1,
    container:{width:container.getBoundingClientRect().width,padding:parseFloat(c.paddingLeft),cap:parseFloat(c.maxWidth)},
    widths:fields.map(n=>n.getBoundingClientRect().width)}
})
try {
  for (const locale of ["en","af"]) {
    await page.setViewport({width:1440,height:1000})
    await page.goto(`${base}/register?locale=${locale}`,{waitUntil:"networkidle0"})
    await page.waitForSelector("#registration .ds-design-field-input")
    check(await page.evaluate(locale=>document.documentElement.lang===locale && document.querySelector(`nav a[lang=${locale}]`).getAttribute("aria-current")==="page",locale),`${locale} document and selected navigation`)
    check(await page.$eval("#registration",n=>n.tagName==="ARTICLE" && n.getAttribute("aria-labelledby")==="registration-heading" && !n.hasAttribute("tabindex")),"native named card")
    check(await page.$eval("#registration-submit",n=>n.type==="submit" && n.dataset.treatment==="lit" && n.dataset.variant==="primary"),"real shared CTA")
    check(await page.$eval("#registration-form",n=>!n.checkValidity()),"native required constraints remain enabled")
    for (const width of [320,390,744,1128,1440,1920]) {
      await page.setViewport({width,height:1000})
      const g=await geometry()
      check(g.fits && g.pageFits,`${locale} reflow ${width}`)
      check(g.columns===(width<=390?1:2),`${locale} intrinsic field columns ${width}`)
      check(g.container.width<=g.container.cap+1 && g.container.padding===24,"cap and single gutter")
    }
    await page.setViewport({width:1440,height:1000})
    check(await page.evaluate(()=>{
      const root=document.querySelector("main");root.style.inlineSize="320px"
      const narrow=getComputedStyle(document.querySelector("#registration-form")).gridTemplateColumns.split(" ").length
      root.removeAttribute("style");return narrow===1
    }),"allocation drives form independently of viewport")
    for(const offset of [-1,0,1]) {
      check(await page.evaluate(offset=>{
        const form=document.querySelector("#registration-form"), c=getComputedStyle(form)
        const minimum=parseFloat(c.getPropertyValue("--design-layout-min"))*parseFloat(getComputedStyle(document.documentElement).fontSize)
        const threshold=2*minimum+parseFloat(c.columnGap)
        form.style.inlineSize=`${threshold+offset}px`
        const columns=getComputedStyle(form).gridTemplateColumns.split(" ").length
        form.removeAttribute("style")
        return columns===(offset<0?1:2)
      },offset),`actual form threshold ${offset}`)
    }
    // Test local inputs on the real elements, not a duplicate layout fixture.
    check(await page.evaluate(()=>{
      const container=document.querySelector(".ds-registration-content"), form=document.querySelector("#registration-form")
      container.style.setProperty("--gutter","32px")
      form.style.setProperty("--design-grid-columns","1")
      const changed=getComputedStyle(container).paddingLeft==="32px" && getComputedStyle(form).gridTemplateColumns.split(" ").length===1
      const header=getComputedStyle(document.querySelector(".ds-registration-header")).paddingLeft==="24px"
      container.removeAttribute("style");form.removeAttribute("style");return changed&&header
    }),"local overrides do not alter sibling header")
    check(await page.evaluate(()=>{
      const root=document.documentElement, button=document.querySelector("#registration-submit")
      const before=getComputedStyle(button).backgroundImage
      root.style.setProperty("--primary","#004fbf");root.style.setProperty("--font-body","serif");root.style.setProperty("--radius","24px")
      const result=getComputedStyle(button).backgroundImage!==before && getComputedStyle(document.querySelector(".ds-design-field-input")).fontFamily==="serif" && getComputedStyle(document.querySelector("#registration")).borderRadius==="24px"
      root.removeAttribute("style");return result
    }),"root font, action and radius tokens propagate")
    const palette=[]
    for (const theme of ["light","dark"]) {
      check(await page.evaluate(theme=>{
        document.documentElement.dataset.theme=theme
        const main=getComputedStyle(document.querySelector("main")), input=getComputedStyle(document.querySelector(".ds-design-field-input"))
        return main.colorScheme==="light" && input.colorScheme==="light" && main.backgroundColor!=="rgba(0, 0, 0, 0)"
      },theme),`canonical light pilot under legacy ${theme} preference`)
      palette.push(await page.evaluate(()=>["main",".ds-design-field-input","#registration-submit"].map(s=>{const c=getComputedStyle(document.querySelector(s));return [c.color,c.backgroundColor,c.borderTopColor,c.backgroundImage]})))
    }
    assert.deepEqual(palette[0],palette[1]);checks++
    // Traverse all twelve application controls. Tidewave toolbar controls are
    // development tooling outside main and do not belong to this contract.
    await page.$eval('nav a[lang=af]',n=>n.focus())
    await page.keyboard.press("Tab")
    check(await page.evaluate(()=>document.activeElement.lang==="en" && getComputedStyle(document.activeElement).outlineStyle!=="none"),"native language focus")
    await page.keyboard.press("Tab")
    check(await page.evaluate(()=>document.activeElement.id==="registration-first-name" && getComputedStyle(document.activeElement).outlineStyle!=="none"),"field focus order")
    if(locale==="en") {
      await page.screenshot({path:"/tmp/newyou-phase4-registration-desktop.png",fullPage:true})
      await page.setViewport({width:390,height:1000})
      await page.$eval("#registration",n=>n.scrollIntoView())
      await page.screenshot({path:"/tmp/newyou-phase4-registration-phone.png"})
    }
    const focus=[]
    await page.$eval('nav a[lang=af]',n=>n.focus())
    for(let i=0;i<11;i++) {
      await page.keyboard.press("Tab")
      focus.push(await page.evaluate(()=>{
        const n=document.activeElement,c=getComputedStyle(n)
        return {inside:!!n.closest("main"),id:n.id,ring:c.outlineStyle!=="none" && parseFloat(c.outlineWidth)>=2}
      }))
    }
    check(focus.every(n=>n.inside&&n.ring) && focus.at(-1).id==="registration-submit","all application controls have visible keyboard focus")
    check(await page.evaluate(()=>{
      const cv=document.createElement("canvas"),ctx=cv.getContext("2d")
      const y=s=>{ctx.fillStyle=s;ctx.fillRect(0,0,1,1);const rgb=[...ctx.getImageData(0,0,1,1).data].slice(0,3).map(x=>x/255).map(x=>x<=.04045?x/12.92:((x+.055)/1.055)**2.4);return rgb.reduce((sum,x,i)=>sum+x*[.2126,.7152,.0722][i],0)}
      const ratio=(a,b)=>{const x=y(a),z=y(b);return(Math.max(x,z)+.05)/(Math.min(x,z)+.05)}
      const field=getComputedStyle(document.querySelector(".ds-design-field-input")), main=getComputedStyle(document.querySelector("main"))
      return ratio(field.color,field.backgroundColor)>=4.5 && ratio(field.borderTopColor,field.backgroundColor)>=3 && ratio(main.color,main.backgroundColor)>=4.5
    }),"actual text and field boundary contrast")
    // First prove the browser's native constraint validation without bypassing it.
    const invalidPosts=[]
    const trackRequest=r=>{if(r.method()==="POST" && new URL(r.url()).pathname==="/register")invalidPosts.push(r.url())}
    page.on("request",trackRequest)
    await page.evaluate(()=>{
      window.pilotInvalidEvents=0
      document.querySelector("#registration-first-name").addEventListener("invalid",()=>window.pilotInvalidEvents++,{once:true})
    })
    await page.click("#registration-submit")
    check(await page.evaluate(()=>window.pilotInvalidEvents===1 && document.activeElement.id==="registration-first-name" && !document.querySelector("#registration-first-name-error")),"native invalid submit focuses required field")
    check(invalidPosts.length===0,"native invalid submit sends no registration POST")
    page.off("request",trackRequest)
    // One deliberately invalid POST per locale, bypassing browser validation
    // only to prove the existing server rejection and localized error markup.
    // Empty required name/email and absent
    // age/legal acceptance force rejection before the Identity boundary.
    await page.evaluate(()=>{
      const form=document.querySelector("#registration-form");form.noValidate=true
      document.querySelector("#registration-surname").value="LongEnglishNameEnAfrikaanseBeskrywing".repeat(5)
      document.querySelector("#registration-password").value="SyntheticPilotOnly123"
    })
    await Promise.all([page.waitForNavigation({waitUntil:"networkidle0"}),page.click("#registration-submit")])
    check(await page.$eval("#registration-first-name",n=>n.getAttribute("aria-invalid")==="true" && n.getAttribute("aria-describedby")==="registration-first-name-error"),"real server error association")
    check(await page.$eval("#registration-first-name-error",n=>n.getAttribute("role")==="alert" && n.textContent.trim().length>0),"localized server alert")
    check(await page.$eval("#registration-surname",n=>n.value.startsWith("LongEnglishNameEnAfrikaanseBeskrywing")),"safe value retained")
    check(await page.$eval("#registration-password",n=>n.value==="" && !n.hasAttribute("value")),"password never redisplayed")
    check(await page.evaluate(locale=>document.documentElement.lang===locale,locale),"error locale preserved")
    if(locale==="af") {await page.setViewport({width:390,height:1000});await page.$eval("#registration",n=>n.scrollIntoView());await page.screenshot({path:"/tmp/newyou-phase4-registration-af-errors.png"})}
    const safetyCopy=await page.$eval(".ds-registration-safety p",n=>n.textContent)
    for (const width of [320,744,1440]) {
      await page.setViewport({width,height:1000})
      check((await geometry()).fits,"actual errors fit")
      const fits=await page.evaluate(()=>{
        const nodes=[...document.querySelectorAll("main h1, main h2, main p, main a, main label, main legend, main input, main button")]
        for(const n of nodes) {n.style.fontSize=`${parseFloat(getComputedStyle(n).fontSize)*2}px`}
        const copy=document.querySelector(".ds-registration-safety p");copy.textContent+=" "+"LongEnglishContentLangAfrikaanseBeskrywing".repeat(10)
        return [...document.querySelectorAll("main, article, form, label, button, .ds-design-field, .ds-field-error")].every(n=>n.scrollWidth<=n.clientWidth+1 && n.scrollHeight<=n.clientHeight+1)
      })
      check(fits,`${locale} errors/long text 200% at ${width}`)
      // Restore the actual server error response without a new POST.
      await page.evaluate(copy=>{for(const n of document.querySelectorAll("main [style]"))n.removeAttribute("style");document.querySelector(".ds-registration-safety p").textContent=copy},safetyCopy)
    }
    await page.emulateMediaFeatures([{name:"prefers-reduced-motion",value:"reduce"}])
    check(await page.$eval("#registration-submit",n=>getComputedStyle(n).animationName==="none"),"no required motion")
    const session=await page.createCDPSession()
    await session.send("Emulation.setEmulatedMedia",{features:[{name:"forced-colors",value:"active"}]})
    check(await page.$eval(".ds-design-field-input",n=>parseFloat(getComputedStyle(n).borderWidth)>0),"forced field boundary")
    check(await page.$eval("#registration-submit",n=>getComputedStyle(n).backgroundImage==="none" && getComputedStyle(n).boxShadow==="none"),"forced action fallback")
    await session.send("Emulation.setEmulatedMedia",{features:[]});await session.detach()
  }
  await page.setJavaScriptEnabled(false)
  await page.goto(`${base}/register?locale=af`,{waitUntil:"networkidle0"})
  await page.reload({waitUntil:"networkidle0"})
  check(await page.$eval("#registration-form",n=>n.offsetHeight>0 && n.method==="post"),"actual no-JavaScript form")
  check(await page.$eval('nav a[lang=en]',n=>n.href.endsWith("/register?locale=en")),"no-JavaScript language choice")
  assert.deepEqual(errors,[]);checks++
  console.log(`PASS: ${checks} actual registration assertions; Chromium ${await browser.version()}`)
} finally {await browser.close()}
