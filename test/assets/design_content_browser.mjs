// Read-only shared content/spacing proof; no account submissions or app dependency.
import assert from "node:assert/strict"
import {createRequire} from "node:module"
import {resolve} from "node:path"
const require=createRequire(resolve(process.env.BROWSER_TOOLS_ROOT || ".", "package.json"))
const browser=await require("puppeteer-core").launch({executablePath:process.env.CHROME_PATH || "/usr/bin/google-chrome",headless:true})
const page=await browser.newPage()
const base=process.env.DESIGN_SYSTEM_URL || "http://127.0.0.1:4237"
let checks=0
const errors=[]
page.on("pageerror",e=>errors.push(e.message))
const check=(v,m)=>{assert.ok(v,m);checks++}
const near=(a,b,m)=>check(Math.abs(a-b)<1,`${m}: ${a} != ${b}`)
const rhythm=selector=>page.$eval(selector,n=>{
  const c=getComputedStyle(n), p=[...n.children].filter(x=>x.tagName==="P")
  return {first:parseFloat(getComputedStyle(n.firstElementChild).marginBlockStart),last:parseFloat(getComputedStyle(n.lastElementChild).marginBlockEnd),
    paragraph:parseFloat(getComputedStyle(p[1]).marginBlockStart),heading:parseFloat(getComputedStyle(n.querySelector("h4") || n.firstElementChild).marginBlockStart),
    list:n.querySelector("ul") && getComputedStyle(n.querySelector("ul")).listStyleType,
    ordered:n.querySelector("ol") && getComputedStyle(n.querySelector("ol")).listStyleType,
    nested:n.querySelector("li ul") && parseFloat(getComputedStyle(n.querySelector("li ul")).marginBlockStart),
    display:c.display,family:c.fontFamily,fits:n.scrollWidth<=n.clientWidth+1}
})
const divided=()=>page.$eval("#content-divided",n=>{
  const [a,b]=n.children,c=getComputedStyle(b)
  return {gap:getComputedStyle(n).gap,margin:parseFloat(c.marginBlockStart),padding:parseFloat(c.paddingBlockStart),border:parseFloat(c.borderBlockStartWidth),
    distance:b.firstElementChild.getBoundingClientRect().top-a.getBoundingClientRect().bottom}
})
try {
  await page.setViewport({width:1440,height:1000})
  await page.goto(`${base}/dev/design-system#content`,{waitUntil:"networkidle0"})
  await page.waitForSelector("#prose-en",{timeout:5000})
  await page.waitForFunction(()=>document.querySelector('#content [data-token="--content-gap"]').textContent.trim()==="24px")
  for(const locale of ["en","af"]) {
    const r=await rhythm(`#prose-${locale}`)
    near(r.first,0,"first child has no leading margin");near(r.last,0,"last child has no trailing margin")
    near(r.paragraph,24,"content role owns paragraph spacing");near(r.heading,32,"heading pause")
    near(await page.$eval(`#prose-${locale} li > p + p`,n=>parseFloat(getComputedStyle(n).marginBlockStart)),8,"paragraphs inside list items keep list rhythm")
    near(await page.$eval(`#prose-${locale} blockquote > p + p`,n=>parseFloat(getComputedStyle(n).marginBlockStart)),24,"quotation paragraph flow")
    near(await page.$eval(`#prose-${locale}-divider`,n=>parseFloat(getComputedStyle(n).marginBlockStart)),24,"prose owns its internal separator margin")
    near(r.nested,8,"nested list spacing");check(r.list==="disc" && r.ordered==="decimal","native list markers")
    check(r.display==="flow-root" && r.fits,"bounded block prose")
    near(await page.$eval(`#prose-${locale} ul`,n=>parseFloat(getComputedStyle(n).paddingInlineStart)),24,"logical list indent")
  }
  near((await rhythm("#prose-local")).paragraph,8,"labelled local prose override")
  const d=await divided();check(d.gap==="0px","divided group has no flex gap")
  near(d.margin,12,"space before divider");near(d.padding,12,"space after divider");near(d.border,1,"separator width")
  near(d.distance,25,"two spaces plus border, without double gap")
  check(await page.$eval("#content-divider",n=>n.tagName==="HR" && !n.hasAttribute("role") && getComputedStyle(n).borderBottomWidth==="0px"),"native thematic break with one border")
  check(await page.evaluate(()=>{
    const n=document.querySelector("#prose-en"), sibling=document.querySelector("#prose-af")
    n.style.setProperty("--content-gap","40px");n.style.setProperty("--space-xl","48px")
    const p=n.querySelectorAll(":scope > p")[1]
    const ok=getComputedStyle(p).marginBlockStart==="40px" && getComputedStyle(n.querySelector("h4")).marginBlockStart==="48px" && getComputedStyle(sibling.querySelectorAll(":scope > p")[1]).marginBlockStart==="24px"
    n.removeAttribute("style");return ok
  }),"local role and consumer-local primitive override isolate siblings")
  check(await page.evaluate(()=>{
    const n=document.querySelector("#content-divided")
    n.style.setProperty("--content-gap","40px");n.style.setProperty("--design-border-width","3px")
    const c=getComputedStyle(n.children[1]), oldColor=c.borderBlockStartColor
    const ok=c.marginBlockStart==="20px" && c.paddingBlockStart==="20px" && c.borderBlockStartWidth==="3px"
    n.style.setProperty("--divider-gap","8px");n.style.setProperty("--divider-width","2px");n.style.setProperty("--divider-style","dashed");n.style.setProperty("--divider-color","var(--secondary)")
    const local=getComputedStyle(n.children[1]);const overridden=local.marginBlockStart==="8px" && local.borderBlockStartWidth==="2px" && local.borderBlockStartStyle==="dashed" && local.borderBlockStartColor!==oldColor
    n.removeAttribute("style");return ok&&overridden
  }),"divider formula and optional inputs resolve at the consuming group")
  check(await page.evaluate(()=>{
    const root=document.documentElement;root.style.setProperty("--content-gap","32px");root.style.setProperty("--font-body","serif")
    const p=document.querySelectorAll("#prose-en > p")[1], n=document.querySelector("#content-divided").children[1]
    const ok=getComputedStyle(p).marginBlockStart==="32px" && getComputedStyle(n).paddingBlockStart==="16px" && getComputedStyle(p).fontFamily==="serif"
    root.removeAttribute("style");return ok
  }),"root content and font changes reach both prose and dividers")
  check(await page.$eval("#prose-en",n=>{const before=n.getBoundingClientRect().width;n.style.setProperty("--measure","20ch");const ok=n.getBoundingClientRect().width<before && n.scrollWidth<=n.clientWidth+1;n.removeAttribute("style");return ok}),"readable measure is a live local input")
  await page.$eval("#prose-en a",n=>n.focus());await page.keyboard.press("Tab")
  check(await page.evaluate(()=>document.activeElement.closest("#prose-af") && getComputedStyle(document.activeElement).outlineStyle!=="none"),"native links retain visible keyboard focus")
  await page.$eval("#content",n=>n.scrollIntoView())
  await (await page.$("#content")).screenshot({path:"/tmp/newyou-phase5-content-desktop.png"})
  for(const width of [320,390,744,1440,1920]) {
    await page.setViewport({width,height:1000})
    const fits=()=>page.$eval("#content",n=>[n,...n.querySelectorAll("article, p, li, blockquote, .ds-divided")].every(x=>x.scrollWidth<=x.clientWidth+1))
    check(await fits(),`content reflows at ${width}`)
    check(await page.$eval("#content",n=>{
      const originals=[...n.querySelectorAll("h3,h4,p,li,a,blockquote")].map(x=>[x,parseFloat(getComputedStyle(x).fontSize)])
      // Snapshot every computed size before changing ancestors.
      for(const [x,size] of originals) {x.dataset.pilotStyle=x.getAttribute("style") || "";x.style.fontSize=`${size*2}px`}
      const p=n.querySelector("#prose-af > p");p.dataset.original=p.textContent;p.textContent+=" "+"LangAfrikaanseBeskrywingLongEnglishContent".repeat(10)
      return [n,...n.querySelectorAll("article,p,li,blockquote,.ds-divided")].every(x=>x.scrollWidth<=x.clientWidth+1)
    }),`doubled long EN/AF content at ${width}`)
    await page.$eval("#content",n=>{for(const x of n.querySelectorAll("[data-pilot-style]")){x.setAttribute("style",x.dataset.pilotStyle);delete x.dataset.pilotStyle}const p=n.querySelector("[data-original]");p.textContent=p.dataset.original;delete p.dataset.original})
    if(width===320){await page.$eval("#content",n=>n.scrollIntoView());await page.screenshot({path:"/tmp/newyou-phase5-content-phone.png"})}
  }
  await page.setViewport({width:1440,height:1000})
  check(await page.$eval("#content",n=>{n.style.inlineSize="240px";const ok=n.scrollWidth<=n.clientWidth+1 && [...n.querySelectorAll(".ds-prose")].every(x=>x.scrollWidth<=x.clientWidth+1);n.removeAttribute("style");return ok}),"narrow allocation independent of viewport")
  for(const locale of ["en","af"]) {
    await page.goto(`${base}/register?locale=${locale}`,{waitUntil:"networkidle0"})
    check(await page.$eval("#registration-privacy-copy",n=>n.classList.contains("ds-prose") && n.children.length===2 && n.querySelector("a").getAttribute("href")==="/legal/privacy"),"actual registration prose and legal link")
    near(await page.evaluate(()=>{const hr=document.querySelector("#registration-safety-divider");return hr.nextElementSibling.getBoundingClientRect().top-hr.previousElementSibling.getBoundingClientRect().bottom}),49,"safety aggregate retains old 24px gap + 1px border + 24px padding")
    near(await page.$eval("#registration-legal-items",n=>n.children[1].firstElementChild.getBoundingClientRect().top-n.children[0].getBoundingClientRect().bottom),49,"legal aggregate retains old 24px gap + 1px border + 24px padding")
    near(await page.$eval("#registration-privacy-copy > p + p",n=>parseFloat(getComputedStyle(n).marginBlockStart)),24,"actual default copy rhythm")
    near(await page.$eval("#registration-legal-items > div + div",n=>parseFloat(getComputedStyle(n).marginBlockStart)),24,"actual preserved pre-divider spacing")
    near(await page.$eval("#registration-legal-items > div + div",n=>parseFloat(getComputedStyle(n).paddingBlockStart)),24,"actual preserved post-divider spacing")
    for(const width of [320,744,1440]) {
      await page.setViewport({width,height:1000})
      check(await page.$eval("main",n=>n.scrollWidth<=n.clientWidth+1 && [...n.querySelectorAll(".ds-prose,.ds-divided")].every(x=>x.scrollWidth<=x.clientWidth+1)),`${locale} actual page reflow ${width}`)
    }
    check(await page.evaluate(()=>{
      const root=document.documentElement;root.style.setProperty("--content-gap","32px");root.style.setProperty("--section-space","40px");root.style.setProperty("--control-gap","20px")
      const ok=getComputedStyle(document.querySelector("#registration-privacy-copy > p + p")).marginBlockStart==="32px" && getComputedStyle(document.querySelector(".ds-registration-content")).paddingBlockStart==="40px" && getComputedStyle(document.querySelector("nav.ds-row")).gap==="20px"
      root.removeAttribute("style");return ok
    }),"actual page consumes each contextual role")
  }
  await page.emulateMediaFeatures([{name:"prefers-reduced-motion",value:"reduce"},{name:"forced-colors",value:"active"}])
  check(await page.$eval(".ds-divider",n=>parseFloat(getComputedStyle(n).borderBlockStartWidth)>0 && getComputedStyle(n).animationName==="none"),"forced-color separator survives without motion")
  await page.setJavaScriptEnabled(false)
  await page.goto(`${base}/dev/design-system#content`,{waitUntil:"networkidle0"});await page.reload({waitUntil:"networkidle0"})
  check(await page.$eval("#prose-en",n=>n.offsetHeight>0 && n.textContent.includes("Grouped content")),"prose remains visible without scripting")
  check(await page.$eval("#content-divider",n=>getComputedStyle(n).borderBlockStartWidth==="1px"),"no-JavaScript separator")
  assert.deepEqual(errors,[]);checks++
  console.log(`PASS: ${checks} content-rhythm assertions; ${await browser.version()}`)
} finally {await browser.close()}
