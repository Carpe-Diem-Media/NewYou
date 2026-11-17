// Read-only DEV guide proof. This script never submits data or changes server state.
import assert from 'node:assert/strict'
import {createRequire} from 'node:module'
import {resolve,join} from 'node:path'
import {mkdtemp,rm} from 'node:fs/promises'
import {verifyFloatingBorders,verifyFloatingSurfaceFocus} from './design_floating_composition_contract.mjs'
const require=createRequire(resolve(process.env.BROWSER_TOOLS_ROOT || '.', 'package.json'))
const base=process.env.DESIGN_SYSTEM_URL || 'http://127.0.0.1:4237'
const engine=process.env.DESIGN_BROWSER || 'chrome'
assert.ok(['chrome','firefox'].includes(engine))
let browser,profile,checks=0
const posts=[],errors=[],boundaries=[]
const check=(ok,message)=>{assert.ok(ok,message);checks++}
const state=id=>{
  const input=document.getElementById(id),frame=input.closest('.ds-floating-control')
  const label=frame.querySelector('.ds-floating-label'),s=getComputedStyle(label)
  const r=n=>{const b=n.getBoundingClientRect();return {top:b.top,bottom:b.bottom,left:b.left,right:b.right,height:b.height}}
  const transform=new DOMMatrixReadOnly(s.transform)
  const canvas=document.createElement('canvas');canvas.width=canvas.height=1
  const painter=canvas.getContext('2d')
  const rgba=color=>{painter.clearRect(0,0,1,1);painter.fillStyle=color;painter.fillRect(0,0,1,1);return [...painter.getImageData(0,0,1,1).data].map(c=>c/255)}
  const luminance=rgb=>{const c=rgb.slice(0,3).map(c=>c<=.04045?c/12.92:((c+.055)/1.055)**2.4);return .2126*c[0]+.7152*c[1]+.0722*c[2]}
  const lum=color=>luminance(rgba(color))
  const fs=getComputedStyle(frame),light=lum(fs.backgroundColor),edge=lum(fs.borderTopColor),ink=lum(s.color)
  const ratio=(a,b)=>(Math.max(a,b)+.05)/(Math.min(a,b)+.05)
  // Only score opaque, solid surroundings. Do not invent a backdrop for image,
  // translucent, filtered or opacity-bearing ancestors that need pixel proof.
  let outside=null,outsideSupported=true
  for(let node=frame;node;node=node.parentElement){
    const cs=getComputedStyle(node)
    if(parseFloat(cs.opacity)!==1 || cs.filter!=='none' || cs.mixBlendMode!=='normal' || (cs.backdropFilter && cs.backdropFilter!=='none'))outsideSupported=false
    if(node!==frame && !outside){
      if(cs.backgroundImage!=='none')outsideSupported=false
      const color=rgba(cs.backgroundColor)
      if(color[3]===1)outside=color
      else if(color[3]>0)outsideSupported=false
    }
  }
  const outsideEdges=outside && outsideSupported?['Top','Right','Bottom','Left'].map(side=>{
    if(parseFloat(fs[`border${side}Width`])<1 || fs[`border${side}Style`]!=='solid')return 0
    const edge=rgba(fs[`border${side}Color`])
    // Alpha border paint also depends on background-clip beneath the border.
    // This solid-border contract refuses that case instead of guessing it.
    if(edge[3]!==1){outsideSupported=false;return 0}
    return ratio(luminance(edge),luminance(outside))
  }):null
  return {input:r(input),frame:r(frame),label:r(label),scale:transform.a,offset:transform.f,
    edgeContrast:ratio(light,edge),labelContrast:ratio(light,ink),borderWidth:parseFloat(fs.borderTopWidth),
    outsideEdgeContrast:outsideEdges && outsideSupported?Math.min(...outsideEdges):null,outsideBackground:outside,outsideSupported:!!outsideEdges && outsideSupported,
    value:input.value,disabled:input.matches(':disabled'),readonly:input.readOnly,
    outline:getComputedStyle(frame).outlineWidth,outlineStyle:getComputedStyle(frame).outlineStyle,
    focused:input===document.activeElement,focusVisible:input.matches(':focus-visible'),
    duration:s.transitionDuration,placeholder:input.getAttribute('placeholder'),
    name:input.labels[0].querySelector('.ds-floating-label').textContent.trim()}
}
const settle=page=>page.waitForFunction(()=>[...document.querySelectorAll('#floating-labels .ds-floating-label')].every(n=>n.getAnimations().every(a=>a.playState==='finished')))
const raised=s=>s.offset===0 && s.scale>0 && s.scale<1 && s.label.bottom<=s.input.top+1
// Single-line inputs scroll their value internally; their boxes must fit the control.
const fits=()=>{
  const section=document.getElementById('floating-labels')
  return [section,...section.querySelectorAll('fieldset,.ds-form-example,.ds-design-field,label,span,p')]
    .every(n=>n.scrollWidth<=n.clientWidth+1) && [...section.querySelectorAll('input')].every(n=>{const a=n.getBoundingClientRect(),b=n.closest('label').getBoundingClientRect();return a.left>=b.left && a.right<=b.right}) && document.documentElement.scrollWidth<=innerWidth+1
}
const observe=async page=>{
  page.on('pageerror',e=>errors.push(e.stack || e.message))
  await page.setRequestInterception(true)
  page.on('request',r=>{if(r.method()==='POST'){posts.push(new URL(r.url()).pathname);r.abort()}else r.continue()})
}
try {
  if(engine==='firefox')profile=await mkdtemp(join(process.env.FIREFOX_PROFILE_ROOT,'newyou-floating-'))
  browser=await require('puppeteer-core').launch({browser:engine,headless:true,executablePath:engine==='firefox'?(process.env.FIREFOX_PATH || '/usr/bin/firefox'):(process.env.CHROME_PATH || '/usr/bin/google-chrome'),...(profile?{userDataDir:profile}:{})})
  const page=await browser.newPage();await observe(page)
  await page.goto(`${base}/dev/design-system`,{waitUntil:'networkidle0'})
  await page.evaluate(()=>document.fonts.ready)
  check(await page.$('#floating-labels label.ds-floating-control'),'shared floating specimens exist')
  checks+=(await page.evaluate(verifyFloatingBorders)).checks
  const scrollBefore=await page.evaluate(()=>({x:scrollX,y:scrollY}))
  await verifyFloatingSurfaceFocus(page,check)
  await settle(page)
  check(await page.evaluate(({x,y})=>scrollX===x && scrollY===y,scrollBefore),'composition proof restores the original viewport position')
  const rest=await page.evaluate(state,'floating-name')
  check(rest.offset>0 && rest.scale===1,'empty unfocused label rests inside')
  check(rest.edgeContrast>=3 && rest.borderWidth>=1,'the actual full control boundary has measured contrast and a visible border')
  check(rest.labelContrast>=4.5,'the resting label has measured text contrast')
  check(rest.name==='Full name' && rest.placeholder===' ','real label supplies the name')
  // A border can contrast with its inside fill while disappearing outside.
  // Prove the outside measurement rejects that defect, then restore the DOM.
  const oldBackground=await page.$eval('#floating-name',n=>{
    const frame=n.closest('.ds-floating-control'),parent=frame.parentElement
    const old=parent.getAttribute('style')
    parent.style.backgroundColor=getComputedStyle(frame).borderTopColor
    return old
  })
  try {
    const weak=await page.evaluate(state,'floating-name')
    check(weak.edgeContrast>=3 && weak.outsideEdgeContrast<1.01,'outside-edge measurement rejects a boundary invisible against its surroundings')
  } finally {
    await page.$eval('#floating-name',(n,old)=>{const p=n.closest('.ds-floating-control').parentElement;old===null?p.removeAttribute('style'):p.setAttribute('style',old)},oldBackground)
  }
  check((await page.evaluate(state,'floating-name')).outsideEdgeContrast>=3,'restored boundary contrasts with its actual surroundings')
  const oldBorder=await page.$eval('#floating-name',n=>{const f=n.closest('label'),old=f.getAttribute('style');f.style.borderTopColor='transparent';return old})
  try {
    const unsupported=await page.evaluate(state,'floating-name')
    check(!unsupported.outsideSupported && unsupported.outsideEdgeContrast===null,'translucent border paint is explicitly unscored')
  } finally {
    await page.$eval('#floating-name',(n,old)=>{const f=n.closest('label');old===null?f.removeAttribute('style'):f.setAttribute('style',old)},oldBorder)
  }
  // Clicking the actual label text focuses the native input across its full control.
  await page.click('label[for=floating-name] .ds-floating-label')
  await settle(page)
  const focus=await page.evaluate(state,'floating-name')
  check(focus.focused && raised(focus),'clicking the label raises it and focuses input')
  check(focus.label.top<rest.label.top,'focused label physically moves upward')
  await page.type('#floating-name','A longer example name')
  await page.keyboard.press('Tab');await settle(page)
  check(raised(await page.evaluate(state,'floating-name')),'filled label remains raised after blur')
  await page.focus('#floating-name');await page.keyboard.down('Control');await page.keyboard.press('A');await page.keyboard.up('Control');await page.keyboard.press('Backspace')
  await page.keyboard.press('Tab');await settle(page)
  check((await page.evaluate(state,'floating-name')).offset>0,'cleared and blurred field returns to rest')
  check(raised(await page.evaluate(state,'floating-email')),'server-filled email begins raised')
  await page.type('#floating-password','Synthetic browser-only value');await page.keyboard.press('Tab');await settle(page)
  check(raised(await page.evaluate(state,'floating-password')),'typed password remains raised without server echo')
  check(await page.$eval('#floating-password',n=>!n.hasAttribute('value')),'password has no rendered value attribute')
  check(await page.$eval('#floating-error',n=>n.getAttribute('aria-invalid')==='true' && n.getAttribute('aria-describedby')==='floating-error-help floating-error-error'),'error and help associations remain native')
  check((await page.evaluate(state,'floating-readonly')).readonly,'readonly state retained')
  for(const id of ['floating-disabled-empty','floating-disabled-filled'])check((await page.evaluate(state,id)).disabled,'fieldset disables floating controls')
  check(raised(await page.evaluate(state,'floating-disabled-filled')),'disabled value label remains raised')
  await page.focus('#floating-name');await page.keyboard.press('Tab');await settle(page)
  const keyboard=await page.evaluate(state,'floating-email')
  check(keyboard.focusVisible && parseFloat(keyboard.outline)>=2 && keyboard.outlineStyle==='solid','native Tab shows the full control focus outline')
  // A value restored by a browser/password manager needs no input/change event mirror.
  await page.$eval('#floating-name',n=>{n.value='Restored value'})
  await settle(page);check(raised(await page.evaluate(state,'floating-name')),'programmatic value without events raises the label')
  // Exercise Chromium native autofill using CDP, not a fabricated class.
  if(engine==='chrome') {
  const cdp=await page.createCDPSession();await cdp.send('DOM.enable');await cdp.send('Autofill.enable')
  await page.$eval('#floating-name',n=>{n.value='';n.blur()})
  const {root}=await cdp.send('DOM.getDocument')
  const {nodeId}=await cdp.send('DOM.querySelector',{nodeId:root.nodeId,selector:'#floating-name'})
  const {node}=await cdp.send('DOM.describeNode',{nodeId})
  await cdp.send('Autofill.trigger',{fieldId:node.backendNodeId,address:{fields:[{name:'NAME_FULL',value:'Autofill Example'},{name:'EMAIL_ADDRESS',value:'autofill@example.com'}]}})
  await page.waitForFunction(()=>document.getElementById('floating-name').matches(':autofill'))
  await page.keyboard.press('Tab');await settle(page)
  check(raised(await page.evaluate(state,'floating-name')),'genuine browser autofill raises the label after blur')
  await cdp.detach()
  }
  for(const width of [320,390,744,1440]) {
    await page.setViewport({width,height:1000});await settle(page)
    check(await page.evaluate(fits),`all floating fields fit at ${width}`)
    for(const id of ['floating-name','floating-email','floating-password','floating-long','floating-error','floating-readonly','floating-disabled-empty','floating-disabled-filled']){
      const actual=await page.evaluate(state,id)
      check(actual.outsideSupported && actual.outsideEdgeContrast>=3,`${id} full boundary contrasts with the outside surface at ${width}`)
      boundaries.push({id,width,contrast:actual.outsideEdgeContrast,background:actual.outsideBackground,inputHeight:actual.input.height,wrapperHeight:actual.frame.height,hallmarkCanReachWrapper:actual.frame.height<=actual.input.height+48})
    }
    for(const id of ['floating-email','floating-long','floating-readonly','floating-disabled-filled'])check(raised(await page.evaluate(state,id)),`${id} value and label do not overlap at ${width}`)
    await page.evaluate(()=>{
      window.floatingSizes=[...document.querySelectorAll('#floating-labels span,#floating-labels input,#floating-labels p,#floating-labels legend')]
        .map(n=>[n,n.getAttribute('style'),parseFloat(getComputedStyle(n).fontSize)])
      for(const[n,,size]of window.floatingSizes)n.style.fontSize=`${size*2}px`
    })
    await settle(page)
    check(await page.evaluate(fits),`200 percent text fits at ${width}`)
    const enlarged=await page.evaluate(state,'floating-long')
    check(enlarged.outsideSupported && enlarged.outsideEdgeContrast>=3,`long label boundary contrasts outside with 200 percent text at ${width}`)
    boundaries.push({id:'floating-long',width,textScale:2,contrast:enlarged.outsideEdgeContrast,background:enlarged.outsideBackground,inputHeight:enlarged.input.height,wrapperHeight:enlarged.frame.height,hallmarkCanReachWrapper:enlarged.frame.height<=enlarged.input.height+48})
    for(const id of ['floating-email','floating-long'])check(raised(await page.evaluate(state,id)),`enlarged ${id} label stays above value at ${width}`)
    await page.evaluate(()=>{for(const[n,s]of window.floatingSizes)s===null?n.removeAttribute('style'):n.setAttribute('style',s);delete window.floatingSizes})
  }
  await page.setViewport({width:1440,height:1000})
  // Local token editing changes every intended consumer, without changing legacy fields.
  const legacyBefore=await page.$eval('#forms-email',n=>n.getBoundingClientRect().height)
  await page.evaluate(()=>document.getElementById('floating-labels').style.setProperty('--field-label-size','var(--text-body-xs)'))
  await settle(page);check((await page.evaluate(state,'floating-email')).scale===1,'local label size token propagates to the actual label')
  check(await page.$eval('#forms-email',n=>n.getBoundingClientRect().height)===legacyBefore,'floating token does not change stacked control geometry')
  await page.$eval('#floating-labels',n=>n.removeAttribute('style'));await settle(page)
  if(engine==='chrome') {
  await page.emulateMediaFeatures([{name:'prefers-reduced-motion',value:'reduce'}])
  check((await page.evaluate(state,'floating-name')).duration==='0s','reduced motion removes label transitions')
  await page.emulateMediaFeatures([])
  }
  await page.type('#floating-name',' retained')
  await page.evaluate(()=>{
    window.floatingBeforePatch=document.getElementById('floating-name')
    const n=document.getElementById('grid-count');n.value='7';n.dispatchEvent(new Event('change',{bubbles:true}))
  })
  await page.waitForFunction(()=>new URL(location.href).searchParams.get('count')==='7')
  check(await page.$eval('#floating-name',n=>n===window.floatingBeforePatch && n.value.includes('retained')),'unrelated LiveView patch preserves native value and node')
  await page.evaluate(()=>window.liveSocket.disconnect());await page.waitForFunction(()=>!window.liveSocket.isConnected())
  await page.evaluate(()=>window.liveSocket.connect());await page.waitForFunction(()=>window.liveSocket.isConnected());await settle(page)
  check(raised(await page.evaluate(state,'floating-name')),'reconnection preserves the floating filled presentation')
  for(const width of [1440,320]) {
    await page.setViewport({width,height:1100});await page.$eval('#floating-labels',n=>n.scrollIntoView())
    await page.screenshot({path:`/tmp/newyou-floating-${engine}-${width}.png`})
  }
  // Firefox 160 lacks BiDi emulation.setScriptingEnabled. Its supported launch
  // preference disables document scripts for this separate, disposable profile.
  if(engine==='firefox') {
    await browser.close();await rm(profile,{recursive:true,force:true})
    profile=await mkdtemp(join(process.env.FIREFOX_PROFILE_ROOT,'newyou-floating-noscript-'))
    browser=await require('puppeteer-core').launch({browser:'firefox',headless:true,executablePath:process.env.FIREFOX_PATH || '/usr/bin/firefox',userDataDir:profile,extraPrefsFirefox:{'javascript.enabled':false}})
  }
  const noScript=await browser.newPage();await observe(noScript)
  if(engine==='chrome')await noScript.setJavaScriptEnabled(false)
  await noScript.goto(`${base}/dev/design-system`,{waitUntil:'networkidle0'});await noScript.evaluate(()=>document.fonts.ready)
  await noScript.type('#floating-name','No script example');await noScript.keyboard.press('Tab')
  // Page-side RAF pollers do not run with script execution disabled. Wait only
  // for the authored CSS transition, using a Node timer outside the document.
  const transition=await noScript.$eval('#floating-name',n=>parseFloat(getComputedStyle(n.closest('label').querySelector('span')).transitionDuration)*1000)
  await new Promise(resolve=>setTimeout(resolve,transition+50))
  check(await noScript.evaluate(()=>typeof window.liveSocket==='undefined'),'site JavaScript remains disabled')
  check(raised(await noScript.evaluate(state,'floating-name')),'native typing and floating labels work without site JavaScript')
  // Native autofill also reproduces this exact DEV toolbar error on the
  // unchanged stacked #forms-email control. Report it separately, never hide it.
  const toolbarError=s=>s.startsWith("TypeError: Cannot read properties of undefined (reading 'toLowerCase')") && s.includes('https://tidewave.ai/tc/assets/toolbar-') && !s.includes(new URL(base).origin)
  const productErrors=errors.filter(s=>!toolbarError(s))
  check(productErrors.length===0,`no product browser errors: ${productErrors.join(', ')}`)
  check(posts.length===0,'no POST or form submission')
  console.log(JSON.stringify({status:'PASS',checks,browser:await browser.version(),nativeAutofill:engine==='chrome',posts:posts.length,productPageErrors:productErrors.length,devToolbarErrors:errors.filter(toolbarError).length,boundaries}))
} finally {if(browser)await browser.close();if(profile)await rm(profile,{recursive:true,force:true})}
