// Read-only native-form proof against existing DEV. POSTs are prohibited.
import assert from "node:assert/strict"
import {createRequire} from "node:module"
import {resolve} from "node:path"
import {mkdtemp,rm,readFile} from "node:fs/promises"
import {join} from "node:path"
import {verifyNativeFormContracts,verifyNativeFormReflow} from "./design_native_form_contract.mjs"
const require=createRequire(resolve(process.env.BROWSER_TOOLS_ROOT || ".","package.json"))
const engine=process.env.DESIGN_BROWSER || "chrome"
assert.ok(["chrome","firefox"].includes(engine))
let profile,browser,checks=0
const launch=async(noScript=false)=>{
  if(engine==="firefox")profile=await mkdtemp(join(process.env.FIREFOX_PROFILE_ROOT,"newyou-native-form-"))
  return require("puppeteer-core").launch({browser:engine,headless:true,
    executablePath:engine==="firefox"?process.env.FIREFOX_PATH:process.env.CHROME_PATH || "/usr/bin/google-chrome",
    ...(profile?{userDataDir:profile}:{}),...(engine==="firefox"&&noScript?{extraPrefsFirefox:{"javascript.enabled":false}}:{})})
}
const base=process.env.DESIGN_SYSTEM_URL || "http://127.0.0.1:4237"
const check=(ok,message)=>{assert.ok(ok,message);checks++}
const stage=message=>{if(process.env.NATIVE_FORM_DEBUG)console.error(`native-forms: ${message}`)}
const baselines=process.env.NATIVE_FORM_BASELINE?JSON.parse(await readFile(process.env.NATIVE_FORM_BASELINE,"utf8")):[]
const registry=JSON.parse(await readFile("docs/delivery/content-evidence/copy/COPY_REGISTRY.json","utf8"))
const errors=[],posts=[]
const observe=async page=>{
  page.on("pageerror",e=>errors.push(e.message))
  await page.setRequestInterception(true)
  page.on("request",r=>{
    if(r.method()==="POST"){posts.push(new URL(r.url()).pathname);r.abort()}else r.continue()
  })
}
try {
  browser=await launch()
  stage('browser launched')
  let page=await browser.newPage();await observe(page)
  await page.goto(`${base}/dev/design-system`,{waitUntil:"networkidle0"})
  check(await page.$("#native-forms .ds-design-choice"),"missing shared native-form specimens")
  await page.waitForFunction(()=>window.liveSocket?.isConnected())
  await page.evaluate(()=>document.fonts.ready)
  for(const width of [320,390,744,1128,1920]) {
    await page.setViewport({width,height:1000})
    checks+=(await page.evaluate(verifyNativeFormContracts)).checks
    checks+=(await page.evaluate(verifyNativeFormReflow)).checks
    check(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),`guide fits ${width}`)
  }
  stage('guide geometry passed')
  await page.bringToFront();await page.focus('#forms-choice')
  await page.keyboard.press('Space')
  check(await page.$eval('#forms-choice',n=>n.checked && n.matches(':focus-visible') && parseFloat(getComputedStyle(n).outlineWidth)>=2),'Space toggles the native checkbox with keyboard focus')
  await page.keyboard.press('Tab')
  check(await page.$eval('#forms-choice-action',n=>n===document.activeElement),'related action follows checkbox in native tab order')
  await page.focus('#forms-choice')
  await page.evaluate(()=>{
    window.nativeChoiceBeforePatch=document.getElementById('forms-choice')
    const select=document.getElementById('grid-count');select.value='7';select.dispatchEvent(new Event('change',{bubbles:true}))
  })
  await page.waitForFunction(()=>new URL(location.href).searchParams.get('count')==='7')
  check(await page.$eval('#forms-choice',n=>n===window.nativeChoiceBeforePatch && n.checked && n===document.activeElement),'unrelated LiveView patch preserves control identity, native choice and focus')
  await page.evaluate(()=>window.liveSocket.disconnect())
  await page.waitForFunction(()=>!window.liveSocket.isConnected())
  await page.evaluate(()=>window.liveSocket.connect())
  await page.waitForFunction(()=>window.liveSocket.isConnected())
  check(await page.$eval('#forms-busy-choice',n=>n.matches(':disabled') && n.closest('fieldset').getAttribute('aria-busy')==='true'),'reconnection retains caller-owned disabled/busy markup')
  stage('guide native state and reconnection passed')
  const focusIds=await page.$$eval('#native-forms input:not(:disabled), #native-forms a[href]',nodes=>nodes.map(n=>n.id))
  await page.focus(`#${focusIds[0]}`)
  for(const id of focusIds.slice(1)) {
    await page.keyboard.press('Tab')
    check(await page.evaluate(id=>document.activeElement.id===id,id),`native Tab order skips disabled fieldset before ${id}`)
  }
  if(engine==='chrome') {
    for(const feature of ['prefers-reduced-motion','forced-colors']) {
      await page.emulateMediaFeatures([{name:feature,value:feature==='forced-colors'?'active':'reduce'}])
      check(await page.$eval('#forms-choice',n=>getComputedStyle(n).appearance==='auto' && getComputedStyle(n).animationName==='none'),`${feature} retains static native checkbox`)
      await page.focus('#forms-choice');await page.keyboard.press('Space')
      check(await page.$eval('#forms-choice',n=>n.matches(':focus-visible') && parseFloat(getComputedStyle(n).outlineWidth)>=2),`${feature} retains actual keyboard focus`)
    }
    await page.emulateMediaFeatures([])
    for(const width of [1440,320]) {
      await page.setViewport({width,height:1000});await page.$eval('#native-forms',n=>n.scrollIntoView())
      await page.screenshot({path:`/tmp/newyou-native-forms-${width}.png`})
    }
  }
  let compared=0
  stage('registration checks start')
  for(const locale of ['en','af'])for(const width of [320,744,1440]) {
    await page.setViewport({width,height:1000})
    await page.goto(`${base}/register?locale=${locale}`,{waitUntil:'networkidle0'})
    await page.evaluate(()=>document.fonts.ready)
    const actual=await page.evaluate(()=>({
      text:document.querySelector('main').textContent.replace(/\s+/g,' ').trim(),
      geometry:['#registration-form','#registration-age','#registration-terms','#registration-privacy','#registration-submit','label[for=registration-age]','label[for=registration-terms]','label[for=registration-privacy]','#preferred-language-help'].map(selector=>{
        const r=document.querySelector(selector).getBoundingClientRect();return {selector,x:r.x,y:r.y,width:r.width,height:r.height}
      }),
      controls:[...document.querySelectorAll('#registration-form input:not([type=hidden])')].map(n=>({id:n.id,name:n.name,type:n.type,required:n.required,checked:n.checked,label:[...n.labels].map(l=>l.textContent.replace(/\s+/g,' ').trim()).join(' ')}))
    }))
    const before=baselines.find(b=>b.locale===locale && b.width===width)
    if(before){assert.equal(actual.text,before.text,'exact normalized participant copy unchanged');checks++;assert.deepEqual(actual.controls,before.controls);checks++
      for(const [i,n]of actual.geometry.entries())for(const key of ['x','y','width','height'])check(Math.abs(n[key]-before.geometry[i][key])<=1,`${locale}/${width} unchanged ${n.selector} ${key}: ${n[key]} / ${before.geometry[i][key]}`)
      compared++
    }
    for(const [id,key]of [['registration-age','identity.registration.age_confirmation'],['registration-terms','identity.registration.terms_acceptance'],['registration-privacy','identity.registration.privacy_acceptance']]) {
      const expected=registry.entries.find(e=>e.key===key)[locale].text
      check(await page.$eval(`#${id}`, (n,{expected})=>{
        const name=document.querySelector('.ds-registration-header > p').textContent.trim()
        return n.classList.contains('ds-design-checkbox') && n.labels[0].textContent.replace(/\s+/g,' ').trim()===expected.replace('{{platform_name}}',name)
      },{expected}),'consumer retains exact registry label through shared checkbox')
    }
    check(await page.$eval('#preferred-language',n=>n.tagName==='FIELDSET' && n.getAttribute('aria-describedby')==='preferred-language-help'),'actual consumer uses associated shared fieldset')
    check(await page.evaluate(()=>{
      const form=document.getElementById('registration-form'),data=new FormData(form)
      return ['confirmed_age_18','terms_accepted','privacy_accepted'].every(k=>!data.has(`registration[${k}]`))
    }),'unchecked registration choices are absent from native FormData')
    if(width===1440) {
      await page.evaluate(()=>{
        for(const id of ['registration-first-name','registration-surname'])document.getElementById(id).value='Example'
        document.getElementById('registration-email').value='example@invalid.test'
        document.getElementById('registration-password').value='SyntheticNativeExample123'
      })
      for(const id of ['registration-age','registration-terms','registration-privacy']) {
        check(await page.evaluate(id=>!document.getElementById('registration-form').reportValidity() && document.activeElement.id===id,id),'native constraint error focuses the next required choice')
        await page.keyboard.press('Space')
      }
      check(await page.evaluate(()=>{
        const f=document.getElementById('registration-form'),d=new FormData(f)
        return ['confirmed_age_18','terms_accepted','privacy_accepted'].every(k=>d.getAll(`registration[${k}]`).length===1 && d.get(`registration[${k}]`)==='true')
      }),'checked choices submit exactly one literal true each')
      check(await page.evaluate(()=>{
        const box=document.getElementById('registration-age'),f=document.getElementById('registration-form');box.disabled=true
        const omitted=!new FormData(f).has(box.name);box.disabled=false;f.reset();return omitted
      }),'disabled native choice is omitted without a hidden fallback')
    }
  }
  if(engine==='firefox') {
    stage('launching no-script Firefox')
    await browser.close();await rm(profile,{recursive:true,force:true});profile=null
    browser=await launch(true);page=await browser.newPage();await observe(page)
  }else await page.setJavaScriptEnabled(false)
  await page.goto('data:text/html,<script>window.nativeFormScriptRan=true</script>')
  check(await page.evaluate(()=>window.nativeFormScriptRan!==true),'page scripts are actually disabled')
  stage('no-script guide navigation')
  await page.goto(`${base}/dev/design-system`,{waitUntil:'networkidle0'})
  check(await page.$eval('#forms-choice',n=>n.type==='checkbox' && n.offsetHeight>0),'no-script guide retains native shared control')
  check(await page.$eval('#forms-busy-choice',n=>n.matches(':disabled')),'no-script native disabled propagation')
  stage('no-script guide checked')
  await page.goto(`${base}/register?locale=af`,{waitUntil:'networkidle0'})
  // Firefox 160's BiDi $$eval utility times out with page scripting disabled.
  // One direct form query proves the same native DOM without that utility.
  check(await page.$eval('#registration-form',form=>{
    const nodes=[...form.querySelectorAll('input.ds-design-checkbox')]
    return nodes.length===3 && nodes.every(n=>n.required)
  }),'no-script AF consumer retains required native choices')
  assert.deepEqual(posts,[]);checks++
  // Retain only the two exact, inherited Firefox DEV reload messages as diagnostics.
  // Other socket paths and all application/LiveView errors still fail this proof.
  const reloadUrl=`${base.replace(/^http/,"ws")}/phoenix/live_reload/socket/websocket?vsn=2.0.0`
  const reloadMessages=[`Firefox can’t establish a connection to the server at ${reloadUrl}.`,
    `The connection to ${reloadUrl} was interrupted while the page was loading.`]
  const devReloadErrors=errors.filter(e=>engine==='firefox' && reloadMessages.includes(e))
  assert.deepEqual(errors.filter(e=>!devReloadErrors.includes(e)),[]);checks++
  console.log(JSON.stringify({status:'PASS',checks,browser:await browser.version(),baselinesCompared:compared,posts:posts.length,
    unresolvedDevReloadErrors:devReloadErrors,exclusions:['WebKit','true browser zoom','screen reader',...(engine==='firefox'?['Firefox media emulation']:[])]}))
} catch(error) {console.error(error);throw error}
finally {if(browser)await browser.close();if(profile)await rm(profile,{recursive:true,force:true})}
