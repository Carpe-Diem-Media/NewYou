// Actual CSS proof. Expected arithmetic lives only in this test, never in the UI hook.
import assert from "node:assert/strict"
import {createRequire} from "node:module"
import {resolve} from "node:path"
import {pathToFileURL} from "node:url"

export const verifyTypeScale = () => {
  let checks=0
  const check=(ok,message)=>{if(!ok)throw new Error(message);checks++}
  const near=(actual,expected,message)=>check(Number.isFinite(actual) && Math.abs(actual-expected)<.1,
    `${message}: ${actual} != ${expected}`)
  const root=getComputedStyle(document.documentElement),rootPx=parseFloat(root.fontSize)
  const value=name=>root.getPropertyValue(name).trim()
  const length=name=>{
    const raw=value(name)
    check(/^[+]?(?:\d+(?:\.\d+)?|\.\d+)(?:e[+-]?\d+)?(?:px|rem)$/i.test(raw),`literal source length ${name}: ${raw}`)
    return parseFloat(raw)*(raw.endsWith("rem") ? rootPx : 1)
  }
  const read=id=>{
    const n=document.getElementById(id)
    check(!!n,`missing scale consumer ${id}`)
    return parseFloat(getComputedStyle(n).fontSize)
  }
  check(document.querySelector("#type-scale")?.dataset.status==="candidate","explicit candidate section")
  const lower=length("--fluid-vmin"),upper=length("--fluid-vmax")
  const method=value("--fluid-method")
  const p=method==="static" ? 0 : Math.max(0,Math.min(1,(innerWidth-lower)/(upper-lower)))
  const steps={xs:-2,s:-1,m:0,l:1,xl:2,xxl:3},sizes={}
  for(const family of ["body","heading"])for(const [step,power]of Object.entries(steps)) {
    const mobile=length(`--type-${family}-base-min`)*Number(value(`--type-${family}-ratio-min`))**power
    const desktop=length(`--type-${family}-base-max`)*Number(value(`--type-${family}-ratio-max`))**power
    const expected=mobile+p*(desktop-mobile)
    near(read(`scale-${family}-${step}-min`),mobile,`${family}/${step} mobile endpoint`)
    near(read(`scale-${family}-${step}-max`),desktop,`${family}/${step} desktop endpoint`)
    near(read(`scale-${family}-${step}-current`),expected,`${family}/${step} endpoint-first current`)
    sizes[`${family}-${step}`]=expected
  }
  const roles={"display-xl":"heading-xxl","display-lg":"heading-xl","display-md":"heading-l",
    "display-sm":"heading-m","heading-md":"heading-m","heading-sm":"heading-s",
    "body-lg":"body-l","body-md":"body-m","body-sm":"body-m","body-xs":"body-m"}
  for(const role of [...Object.keys(roles),"button-md","caption"]) {
    const fixed=length(`--text-${role}`)
    const expected=roles[role] ? (role.startsWith("body-") ? Math.max(length("--text-body-xs"),sizes[roles[role]]) : sizes[roles[role]]) : fixed
    near(read(`type-current-${role}`),fixed,`${role} production size unchanged`)
    near(read(`type-candidate-${role}`),expected,`${role} candidate semantic mapping`)
    const current=getComputedStyle(document.getElementById(`type-current-${role}`))
    const candidate=getComputedStyle(document.getElementById(`type-candidate-${role}`))
    near(parseFloat(candidate.lineHeight)/expected,Number(value(`--leading-${role}`)),`${role} unitless leading`)
    check(current.letterSpacing===candidate.letterSpacing,`${role} existing tracking retained`)
    check(current.fontFamily===candidate.fontFamily,`${role} canonical font family`)
  }
  const localMobile=length("--type-heading-base-min")*Number(value("--type-heading-ratio-min"))**3
  near(read("type-scale-local-sample"),localMobile+p*(length("--text-display-md")-localMobile),"local endpoint override")
  near(read("type-scale-default-sample"),sizes["heading-xxl"],"default sibling isolation")
  for(const locale of ["en","af"]) {
    const n=document.getElementById(`type-reading-${locale}`)
    check(n?.lang===locale && !!n.querySelector("ul li ul li"),`${locale} semantic long content`)
    near(parseFloat(getComputedStyle(n.querySelector("p")).fontSize),Math.max(length("--text-body-xs"),sizes["body-m"]),`${locale} candidate reading size`)
  }
  return {checks,method}
}

export const verifyTypeScaleOverrides = () => {
  let checks=0
  const check=(ok,message)=>{if(!ok)throw new Error(message);checks++}
  const near=(actual,expected,message)=>check(Math.abs(actual-expected)<.1,`${message}: ${actual} != ${expected}`)
  const root=document.documentElement,scope=document.getElementById("type-scale-local")
  const originals=[root,scope].map(n=>[n,n.getAttribute("style")])
  const size=id=>parseFloat(getComputedStyle(document.getElementById(id)).fontSize)
  const rootPx=parseFloat(getComputedStyle(root).fontSize)
  const heading=size("type-candidate-display-xl"),control=size("type-current-button-md")
  const siblingBody=size("type-scale-default-body")
  try {
    scope.style.setProperty("--type-body-base-min","1.25rem")
    scope.style.setProperty("--type-body-base-max","1.25rem")
    near(size("type-scale-local-body"),1.25*rootPx,"local base inputs rebind derived semantic sizes")
    near(size("type-scale-default-body"),siblingBody,"local base inputs isolate sibling")
    scope.removeAttribute("style")

    const adjacent=size("scale-body-m-current")
    root.style.setProperty("--design-type-body-s-min","2rem")
    root.style.setProperty("--design-type-body-s-max","2rem")
    near(size("scale-body-s-current"),2*rootPx,"equal per-step endpoint override")
    near(size("scale-body-m-current"),adjacent,"step override does not regenerate neighbors")
    root.style.removeProperty("--design-type-body-s-min")
    root.style.removeProperty("--design-type-body-s-max")

    for(const edge of ["min","max"]) {
      root.style.setProperty(`--type-body-base-${edge}`,"1.25rem")
      root.style.setProperty(`--type-body-ratio-${edge}`,"1")
    }
    for(const step of ["xs","s","m","l","xl","xxl"])near(size(`scale-body-${step}-current`),1.25*rootPx,"ratio-one scale")
    near(size("type-scale-default-body"),1.25*rootPx,"root edits reach explicit scope")
    near(size("type-scale-local-body"),1.25*rootPx,"root edits reach locally overridden heading scope")
    near(size("type-candidate-display-xl"),heading,"body inputs isolate heading family")
    near(size("type-current-button-md"),control,"candidate inputs do not change controls")

    root.style.setProperty("--type-body-base-min","0.5rem")
    root.style.setProperty("--type-body-base-max","0.5rem")
    near(size("type-candidate-body-xs"),parseFloat(getComputedStyle(root).getPropertyValue("--text-body-xs")),"semantic body floor")

    root.style.setProperty("--font-body","serif")
    for(const id of ["type-current-body-xs","type-candidate-body-xs","type-current-display-xl","type-candidate-display-xl"])
      check(getComputedStyle(document.getElementById(id)).fontFamily==="serif","one root font selection propagates")
    root.style.setProperty("--font-display","monospace")
    check(getComputedStyle(document.getElementById("type-candidate-display-xl")).fontFamily==="monospace","independent display font token")
    check(getComputedStyle(document.getElementById("type-candidate-body-xs")).fontFamily==="serif","display selection isolates body")
    check([...document.querySelectorAll("#type-scale p, #type-scale code, #type-scale dd")]
      .every(n=>n.scrollWidth<=n.clientWidth+1),"alternate font selection preserves reflow")
  } finally {
    for(const[n,style]of originals)style===null ? n.removeAttribute("style") : n.setAttribute("style",style)
  }
  return {checks}
}

async function main() {
  const require=createRequire(resolve(process.env.BROWSER_TOOLS_ROOT || ".","package.json"))
  const browser=await require("puppeteer-core").launch({executablePath:process.env.CHROME_PATH || "/usr/bin/google-chrome",headless:true})
  const base=process.env.DESIGN_SYSTEM_URL || "http://127.0.0.1:4237"
  let checks=0
  const check=(ok,message)=>{assert.ok(ok,message);checks++}
  try {
    const page=await browser.newPage(),errors=[]
    page.on("pageerror",e=>errors.push(e.message))
    await page.setViewport({width:1440,height:1000})
    await page.goto(`${base}/dev/design-system`,{waitUntil:"networkidle0"})
    await page.waitForSelector("#type-scale")
    await page.waitForFunction(()=>window.liveSocket?.isConnected())
    await page.evaluate(()=>document.fonts.ready)
    await page.waitForFunction(()=>[...document.querySelectorAll("#type-scale output[data-measure-target]")].every(n=>{
      const target=document.getElementById(n.dataset.measureTarget)
      return target && n.textContent===getComputedStyle(target).getPropertyValue(n.dataset.measureProperty).trim()
    }))
    check(true,"every new live measurement matches its actual CSS consumer")
    checks+=(await page.evaluate(verifyTypeScale)).checks
    checks+=(await page.evaluate(verifyTypeScaleOverrides)).checks
    check(await page.evaluate(()=>[...document.fonts].some(f=>f.family.replaceAll('"',"")==="Inter" && f.status==="loaded")),"self-hosted Inter loaded")
    for(const width of [320,390,744,840,1200,1440,1920]) {
      await page.setViewport({width,height:1000})
      check(await page.$eval("#type-scale",n=>[n,...n.querySelectorAll("article,.ds-scale-current,.ds-scale-candidate,p,dd,code")]
        .every(e=>e.scrollWidth<=e.clientWidth+1)),`candidate/current reflow at ${width}`)
    }
    await page.setViewport({width:320,height:1000})
    check(await page.evaluate(()=>{
      const nodes=[...document.querySelectorAll(".ds-scale-reading p,.ds-scale-reading li,.ds-scale-reading h3")]
      const styles=nodes.map(n=>[n,n.getAttribute("style")])
      try {
        for(const n of nodes) {
          n.style.lineHeight="1.5";n.style.letterSpacing="0.12em";n.style.wordSpacing="0.16em"
          if(n.tagName==="P")n.style.marginBlockEnd="2em"
        }
        return nodes.every(n=>n.scrollWidth<=n.clientWidth+1 && n.scrollHeight<=n.clientHeight+1)
      } finally {
        for(const[n,style]of styles)style===null ? n.removeAttribute("style") : n.setAttribute("style",style)
      }
    }),"user text spacing preserves long EN/AF content")
    check(await page.evaluate(()=>{
      const root=document.getElementById("type-scale")
      const nodes=[...root.querySelectorAll("p,h2,h3,li,code,dd,dt,output,summary,button")]
      const sizes=nodes.map(n=>[n,n.getAttribute("style"),parseFloat(getComputedStyle(n).fontSize)])
      const paras=["en","af"].map(l=>document.querySelector(`#type-reading-${l} > p`))
      const copies=paras.map(n=>[n,n.textContent])
      try {
        for(const[n,,size]of sizes)n.style.fontSize=`${size*2}px`
        for(const[n]of copies)n.textContent+=" "+"LongEnglishContentLangAfrikaanseBeskrywing".repeat(12)
        return sizes.every(([n,,size])=>Math.abs(parseFloat(getComputedStyle(n).fontSize)-size*2)<.1) &&
          [root,...root.querySelectorAll("article,p,li,code,dd")].every(n=>n.scrollWidth<=n.clientWidth+1)
      } finally {
        for(const[n,style]of sizes)style===null ? n.removeAttribute("style") : n.setAttribute("style",style)
        for(const[n,copy]of copies)n.textContent=copy
      }
    }),"exact 200% text and long EN/AF reflow without inherited compounding")
    check(await page.$eval("#type-scale-local",n=>{
      n.style.inlineSize="240px"
      try{return [n,...n.querySelectorAll("p,output")].every(e=>e.scrollWidth<=e.clientWidth+1)}finally{n.removeAttribute("style")}
    }),"narrow parent reflow")
    await page.$eval("#type-scale details summary",n=>n.focus())
    await page.keyboard.press("Enter")
    check(await page.$eval("#type-scale details",n=>n.open),"native keyboard disclosure")
    check(await page.evaluate(()=>{
      const c=getComputedStyle(document.activeElement)
      return c.outlineStyle==="solid" && parseFloat(c.outlineWidth)>=2
    }),"disclosure focus remains visible")
    await page.$eval("#type-scale",n=>n.scrollIntoView())
    await page.screenshot({path:"/tmp/newyou-type-scale-phone.png"})
    await page.setViewport({width:1440,height:1000})
    await page.$eval("#type-scale",n=>n.scrollIntoView())
    await page.screenshot({path:"/tmp/newyou-type-scale-desktop.png"})
    await page.$eval("#type-candidate-display-xl",n=>n.closest("article").scrollIntoView())
    await page.screenshot({path:"/tmp/newyou-type-scale-comparison.png"})

    await page.setRequestInterception(true)
    page.on("request",r=>r.url().includes("/fonts/inter/") ? r.abort() : r.continue())
    await page.setCacheEnabled(false)
    await page.reload({waitUntil:"networkidle0"})
    await page.evaluate(()=>document.fonts.ready)
    check(await page.evaluate(()=>![...document.fonts].some(f=>f.family.replaceAll('"',"")==="Inter" && f.status==="loaded") &&
      document.querySelector("#type-reading-af").getBoundingClientRect().height>0),"blocked font falls back to readable content")
    checks+=(await page.evaluate(verifyTypeScale)).checks
    await page.setViewport({width:320,height:1000})
    check(await page.$$eval("#type-scale article, #type-scale p",nodes=>nodes.every(n=>n.scrollWidth<=n.clientWidth+1)),"blocked-font narrow reflow")
    await page.setJavaScriptEnabled(false)
    await page.setViewport({width:320,height:1000})
    await page.goto(`${base}/dev/design-system`,{waitUntil:"networkidle0"})
    check(await page.$eval("#type-scale",n=>n.offsetHeight>0 && n.scrollWidth<=n.clientWidth+1),"candidate content reflows without scripting or font delivery")
    check(await page.$eval("#type-scale details",n=>{n.open=true;return n.querySelector("summary").offsetHeight>0}),"native no-script disclosure content")
    check(await page.evaluate(()=>typeof window.liveSocket==="undefined"),"guide scripts did not run")
    assert.deepEqual(errors,[])
    console.log(JSON.stringify({status:"PASS",checks,browser:await browser.version(),exclusions:["WebKit","true browser zoom","screen reader"]}))
  } finally {await browser.close()}
}

if(process.argv[1] && import.meta.url===pathToFileURL(resolve(process.argv[1])).href)await main()
