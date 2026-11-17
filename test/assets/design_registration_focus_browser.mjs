// Read-only registration focus regression. Never submit the form or hide DEV tools.
import assert from 'node:assert/strict'
import {createRequire} from 'node:module'
import {resolve} from 'node:path'

const require=createRequire(resolve(process.env.BROWSER_TOOLS_ROOT || '.', 'package.json'))
const base=process.env.DESIGN_SYSTEM_URL || 'http://127.0.0.1:4237'
const selectors=locale=>[
  `.ds-registration-header a[href="/login?locale=${locale}"]`,
  '.ds-registration-header a[lang="af"]',
  '.ds-registration-header a[lang="en"]',
  '#registration-first-name', '#registration-surname', '#registration-email',
  '#registration-password', '#registration-age', '#registration-terms',
  '#registration-form a[href="/legal/terms"]',
  '#registration-form a[href="/legal/privacy"]',
  '#registration-privacy', '#registration-submit'
]
let browser,checks=0
const posts=[],errors=[],observations=[]
const check=(ok,message)=>{assert.ok(ok,message);checks++}
// Inspect the focused element itself. A shadow host's dimensions say nothing
// about the visible focus indicator on its active descendant.
const focused=()=>{
  const host=document.activeElement
  let node=host,depth=0
  while(node?.shadowRoot?.activeElement){node=node.shadowRoot.activeElement;depth++}
  const style=getComputedStyle(node),box=node.getBoundingClientRect()
  const canvas=document.createElement('canvas');canvas.width=canvas.height=1
  const painter=canvas.getContext('2d');painter.fillStyle=style.outlineColor;painter.fillRect(0,0,1,1)
  return {hostId:host.id,tag:node.tagName.toLowerCase(),id:node.id,shadowDepth:depth,
    outlineStyle:style.outlineStyle,outlineWidth:parseFloat(style.outlineWidth),
    outlineColor:style.outlineColor,outlineAlpha:painter.getImageData(0,0,1,1).data[3]/255,
    focusVisible:node.matches(':focus-visible'),
    width:box.width,height:box.height}
}
const productRing=state=>state.focusVisible && state.width>0 && state.height>0 &&
  state.outlineStyle!=='none' && state.outlineStyle!=='hidden' && state.outlineWidth>=2 && state.outlineAlpha>=0.5

try {
  browser=await require('puppeteer-core').launch({headless:true,
    executablePath:process.env.CHROME_PATH || '/usr/bin/google-chrome'})
  const page=await browser.newPage()
  page.on('pageerror',error=>errors.push(error.message))
  await page.setRequestInterception(true)
  page.on('request',request=>{
    if(request.method()==='POST'){posts.push(new URL(request.url()).pathname);request.abort()}
    else request.continue()
  })
  for(const locale of ['en','af'])for(const width of [320,744,1440]) {
    await page.setViewport({width,height:1000})
    await page.goto(`${base}/register?locale=${locale}`,{waitUntil:'networkidle0'})
    await page.evaluate(()=>document.fonts.ready)
    const order=selectors(locale),steps=[]
    // Keep the explicit order and the full product tab-stop inventory in sync.
    // This catches newly added controls as well as missing existing controls.
    check(await page.evaluate(order=>{
      const expected=order.map(s=>document.querySelector(s))
      const actual=[...document.querySelectorAll('#main a[href],#main button,#main input,#main select,#main textarea,#main [tabindex]')]
        .filter(n=>n.tabIndex>=0 && !n.matches(':disabled') && n.getClientRects().length)
      return expected.every(Boolean) && new Set(expected).size===expected.length &&
        actual.length===expected.length && actual.every((n,i)=>n===expected[i])
    },order),`${locale}/${width} complete product focus inventory`)
    for(const selector of order) {
      await page.keyboard.press('Tab')
      check(await page.$eval(selector,n=>n===document.activeElement),`${locale}/${width} forward order ${selector}`)
      const state=await page.evaluate(focused)
      check(productRing(state),`${locale}/${width} visible forward focus ${selector}`)
      steps.push({selector,...state})
    }
    for(const selector of order.slice(0,-1).reverse()) {
      await page.keyboard.down('Shift');await page.keyboard.press('Tab');await page.keyboard.up('Shift')
      check(await page.$eval(selector,n=>n===document.activeElement),`${locale}/${width} reverse order ${selector}`)
      check(productRing(await page.evaluate(focused)),`${locale}/${width} visible reverse focus ${selector}`)
    }
    // Negative controls prove this runner rejects a missing focus indicator on
    // each product control family. Restore styles before any further assertion.
    for(const selector of [order[0],'#registration-email','#registration-age','#registration-submit']) {
      await page.focus(selector)
      for(const [property,value] of [['outline-style','none'],['outline-color','transparent']]) {
        check(productRing(await page.evaluate(focused)),`visible baseline before ${property} mutation for ${selector}`)
        const before=await page.$eval(selector,(n,{property,value})=>{const s=n.getAttribute('style');n.style.setProperty(property,value,'important');return s},{property,value})
        try {check(!productRing(await page.evaluate(focused)),`${property} defect is rejected for ${selector}`)}
        finally {await page.$eval(selector,(n,s)=>s===null?n.removeAttribute('style'):n.setAttribute('style',s),before)}
        check(productRing(await page.evaluate(focused)),`restored ring passes for ${selector}`)
      }
    }
    // Follow actual native Tab stops beyond the product. Report the toolbar and
    // document boundary separately; neither is silently treated as app evidence.
    await page.focus('#registration-submit')
    const boundary=[]
    let exited=false
    for(let i=0;i<12;i++) {
      await page.keyboard.press('Tab')
      const state=await page.evaluate(focused);boundary.push(state)
      const returned=await page.$eval(order[0],n=>n===document.activeElement)
      if(state.tag==='body' || state.tag==='html' || returned){exited=true;break}
    }
    check(exited,`${locale}/${width} no focus trap after submit: ${JSON.stringify(boundary)}`)
    observations.push({locale,width,productStops:steps.length,boundary})
  }
  assert.deepEqual(posts,[]);checks++
  assert.deepEqual(errors,[]);checks++
  console.log(JSON.stringify({status:'PASS',checks,browser:await browser.version(),posts:posts.length,observations,
    exclusions:['Hallmark gate closure','focus contrast measurement','Firefox','WebKit','screen reader','submission states']}))
} finally {if(browser)await browser.close()}
