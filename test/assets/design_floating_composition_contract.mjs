// Computed paint-owner contracts. All temporary DOM/style changes are restored.
export const verifyFloatingBorders = () => {
  let checks=0
  const check=(ok,message)=>{if(!ok)throw new Error(message);checks++}
  const input=document.getElementById('floating-name')
  const frame=input.closest('.ds-floating-control'),field=frame.parentElement
  const sibling=document.getElementById('floating-email').closest('.ds-floating-control')
  const stacked=document.getElementById('forms-email'),root=document.documentElement
  const saved=new Map(),invalid=input.getAttribute('aria-invalid')
  const set=(node,name,value)=>{if(!saved.has(node))saved.set(node,node.getAttribute('style'));node.style.setProperty(name,value)}
  const restore=()=>{
    for(const[node,style]of saved)style===null?node.removeAttribute('style'):node.setAttribute('style',style)
    saved.clear()
    invalid===null?input.removeAttribute('aria-invalid'):input.setAttribute('aria-invalid',invalid)
  }
  const color=(node,token)=>{
    const probe=document.createElement('span')
    probe.style.color=getComputedStyle(node).getPropertyValue(token);document.body.append(probe)
    try{return getComputedStyle(probe).color}finally{probe.remove()}
  }
  const read=node=>{
    const css=getComputedStyle(node)
    return ['Top','Right','Bottom','Left'].map(side=>[parseFloat(css[`border${side}Width`]),css[`border${side}Style`],css[`border${side}Color`]])
  }
  const border=(node,width,style,ink,message)=>{
    const expected=color(node,ink)
    const actual=read(node)
    check(actual.every(([w,s,c])=>Math.abs(w-width)<.05 && s===style && c===expected),`${message}: ${node.id || node.className} ${JSON.stringify(actual)} != ${width}px ${style} ${expected}`)
  }
  const siblingBefore=read(sibling),stackedBefore=read(stacked)
  try {
    set(frame,'--border-control-width','4px');set(frame,'--border-control-style','dashed')
    set(frame,'--border-control-color','var(--primary)')
    border(frame,4,'dashed','--primary','floating label paints local width, style and color on every side')
    input.setAttribute('aria-invalid','true')
    border(frame,8,'dashed','--primary','floating invalid border doubles its locally selected width')
    check(JSON.stringify(read(sibling))===JSON.stringify(siblingBefore),'local floating border isolates its sibling')
    check(JSON.stringify(read(stacked))===JSON.stringify(stackedBefore),'local floating border isolates stacked fields')
    restore()
    set(field,'--border-control-width','3px');set(field,'--border-control-style','dotted')
    set(field,'--border-control-color','var(--secondary)')
    border(frame,3,'dotted','--secondary','floating label resolves ancestor border inputs locally')
    input.setAttribute('aria-invalid','true')
    border(frame,6,'dotted','--secondary','invalid width follows inherited border input')
    restore()
    set(frame,'--design-border-width','3px')
    border(frame,3,'solid','--ink-meta','legacy local base-border input remains supported')
    input.setAttribute('aria-invalid','true')
    border(frame,6,'solid','--ink-meta','invalid width follows the legacy local base input')
    restore()
    set(root,'--border-control-width','2px');set(root,'--border-control-style','dashed')
    set(root,'--border-control-color','var(--secondary)')
    for(const node of [frame,sibling,stacked])border(node,2,'dashed','--secondary','root control inputs reach floating and stacked consumers')
    set(frame,'--border-control-width','4px')
    border(frame,4,'dashed','--secondary','local floating width wins over root input')
    border(sibling,2,'dashed','--secondary','local width leaves root-edited sibling unchanged')
    input.setAttribute('aria-invalid','true')
    border(frame,8,'dashed','--secondary','local invalid width remains independent of root input')
    return {checks}
  } finally {restore()}
}

// Use actual Tab navigation so focus-visible and the visible label outline are
// exercised together. Surfaces wrap real rendered fields, never mocked controls.
export const verifyFloatingSurfaceFocus = async (page,check) => {
  await page.evaluate(()=>{
    const input=document.getElementById('floating-name'),field=input.closest('.ds-design-field')
    const marker=document.createComment('floating composition restoration point');field.before(marker)
    const fixture=document.createElement('div'),outer=document.createElement('div'),inner=document.createElement('div')
    const sentinel=document.createElement('button');sentinel.type='button';sentinel.textContent='Focus test start'
    outer.className=inner.className='ds-surface';outer.dataset.surface='canvas';inner.dataset.surface='plain'
    fixture.append(outer);outer.append(inner);inner.append(sentinel,field);document.body.append(fixture)
    window.floatingCompositionProof={field,marker,fixture,outer,inner,sentinel,x:scrollX,y:scrollY}
  })
  const focus=async (expected,message)=>{
    await page.evaluate(()=>window.floatingCompositionProof.sentinel.focus())
    await page.keyboard.press('Tab')
    const actual=await page.evaluate(()=>{
      const input=document.getElementById('floating-name'),frame=input.closest('.ds-floating-control')
      const css=getComputedStyle(frame),surface=window.floatingCompositionProof.inner
      const probe=document.createElement('span');probe.style.color='var(--context-focus)';surface.append(probe)
      try{return {native:document.activeElement===input && input.matches(':focus-visible'),width:parseFloat(css.outlineWidth),style:css.outlineStyle,color:css.outlineColor,context:getComputedStyle(probe).color}}
      finally{probe.remove()}
    })
    check(actual.native && actual.width>=2 && actual.style==='solid',`${message}: native Tab paints the wrapper outline`)
    check(actual.color===actual.context,`${message}: painted outline matches the nearest surface role`)
    const selected=await page.evaluate(value=>{
      const probe=document.createElement('span');probe.style.color=value;document.body.append(probe)
      try{return getComputedStyle(probe).color}finally{probe.remove()}
    },expected)
    check(actual.color===selected,`${message}: selected profile input reaches the outline`)
  }
  try {
    await page.evaluate(()=>{
      const {outer}=window.floatingCompositionProof
      outer.style.setProperty('--surface-canvas-focus','var(--secondary)')
    })
    await focus('var(--primary)','nested plain resets the canvas focus role')
    await page.evaluate(()=>{window.floatingCompositionProof.inner.dataset.surface='canvas'})
    await focus('var(--secondary)','nested matching profile inherits its focus input')
    await page.evaluate(()=>{window.floatingCompositionProof.inner.style.setProperty('--surface-canvas-focus','var(--primary-hover)')})
    await focus('var(--primary-hover)','local nested profile overrides the parent input')
    check(await page.evaluate(()=>{
      const {outer,inner}=window.floatingCompositionProof
      return getComputedStyle(outer).getPropertyValue('--context-focus')!==getComputedStyle(inner).getPropertyValue('--context-focus')
    }),'nested local focus input leaves the parent context unchanged')
    for(const profile of ['plain','canvas','panel','raised']) {
      await page.evaluate(profile=>{
        const {outer,inner}=window.floatingCompositionProof
        outer.removeAttribute('style');inner.removeAttribute('style');inner.dataset.surface=profile
        inner.style.setProperty(`--surface-${profile}-focus`,'var(--secondary)')
      },profile)
      await focus('var(--secondary)',`local ${profile} surface`)
    }
  } finally {
    await page.evaluate(()=>{
      const {field,marker,fixture,x,y}=window.floatingCompositionProof
      field.querySelector('input').blur();marker.replaceWith(field);fixture.remove()
      window.scrollTo(x,y)
      delete window.floatingCompositionProof
    })
  }
}
