// Independent computed-style proof shared by browser engines. All edits are restored.
export const verifyBorderContracts = () => {
  let checks=0
  const check=(ok,message)=>{if(!ok)throw new Error(message);checks++}
  const near=(a,b,message)=>check(Number.isFinite(a) && Math.abs(a-b)<.5,`${message}: ${a} != ${b}`)
  const find=s=>{const n=document.querySelector(s);check(!!n,`missing ${s}`);return n}
  const css=n=>getComputedStyle(n),px=(n,p)=>parseFloat(css(n)[p])
  const root=document.documentElement,flat=find("#border-card-decorative"),lit=find("#border-card-lit")
  const field=find("#border-field-control"),invalid=find("#border-field-invalid")
  const separator=find("#border-divider-default"),local=find("#border-divider-local")
  const button=find("#border-action-ready"),icon=find('.ds-design-icon[data-treatment="boxed"]')
  const outer=find("#border-divided-outer"),frame=find("#border-divided-frame"),inner=find("#border-divided-inner")
  const snapshot=new Map()
  const set=(n,name,value)=>{if(!snapshot.has(n))snapshot.set(n,n.getAttribute("style"));n.style.setProperty(name,value)}
  const restore=()=>{for(const [n,s] of snapshot)s===null?n.removeAttribute("style"):n.setAttribute("style",s);snapshot.clear()}
  const width=(n,v,message)=>near(px(n,"borderTopWidth"),v,message)
  const separation=n=>{
    const [a,b]=n.children
    return b.firstElementChild.getBoundingClientRect().top-a.getBoundingClientRect().bottom
  }
  const radius=(n,border)=>{
    const inset=n.querySelector(":scope > .ds-design-card-inset"),r=css(inset).borderTopLeftRadius.split(" ").map(parseFloat)
    near(r[0],Math.max(0,px(n,"borderTopLeftRadius")-border-px(n,"paddingInlineStart")),"inset x subtracts actual selected border")
    near(r[1] ?? r[0],Math.max(0,px(n,"borderTopLeftRadius")-border-px(n,"paddingBlockStart")),"inset y subtracts actual selected border")
  }
  try {
    for(const role of ["decorative","control","separator"])
      check(!!css(root).getPropertyValue(`--border-${role}`).trim(),`missing root border role ${role}`)
    for(const n of [flat,lit,field,invalid,separator,local,button,icon])
      check(css(n).borderTopStyle===(n===local?"dashed":"solid"),"default border styles")
    for(const n of [flat,lit,field,separator,button,icon])width(n,1,"default 1px borders preserved")
    width(invalid,2,"invalid uses doubled control border");width(local,2,"labelled local separator")
    check(css(field).borderTopColor!==css(flat).borderTopColor,"control boundary differs from decorative hairline")
    check(css(flat).borderTopColor===css(separator).borderTopColor,"decorative and separator share approved default ink")
    check(separator.tagName==="HR" && !separator.hasAttribute("role"),"native thematic break semantics")
    check(!outer.querySelector("hr") && frame.parentElement===outer && inner.parentElement===frame,"decorative nesting retains neutral frame")
    near(px(outer,"gap"),0,"no doubled layout gap")
    near(separation(outer),25,"outer 2*12+1 separator distance")
    near(separation(inner),17,"inner 2*8+1 separator distance")
    set(root,"--content-gap","40px")
    near(separation(outer),41,"root content role updates outer distance")
    near(separation(inner),17,"inner explicit gap remains isolated")
    set(inner,"--divider-gap","4px")
    near(separation(inner),9,"local inner distance follows 2*d+b")
    near(separation(outer),41,"inner override leaves outer boundary unchanged")
    set(inner,"--divider-gap","0px")
    near(separation(inner),1,"zero internal gap leaves only border")
    restore()
    set(root,"--border-decorative-width","3px");set(root,"--border-decorative-style","dashed")
    set(root,"--border-decorative-color","var(--secondary)")
    width(flat,3,"root decorative width propagates")
    check(css(flat).borderTopStyle==="dashed" && css(flat).borderTopColor===css(local).borderTopColor,"decorative style and ink propagate")
    for(const n of [lit,field,separator,button,icon])width(n,1,"decorative role isolates other purposes")
    set(flat,"--border-decorative-width","4px");width(flat,4,"local purpose overrides root")
    check(px(find("#content-card-default"),"borderTopWidth")===3,"local decorative override isolates sibling")
    restore()
    set(root,"--border-control-width","2px");set(root,"--border-control-style","dashed")
    set(root,"--border-control-color","var(--secondary)")
    width(field,2,"root control width propagates");width(invalid,4,"invalid doubles selected control width")
    check(css(field).borderTopStyle==="dashed" && css(field).borderTopColor===css(local).borderTopColor,"control style and ink propagate")
    for(const n of [flat,lit,separator,button,icon])width(n,1,"control role isolates other purposes")
    set(field,"--border-control-width","4px");width(field,4,"local control width")
    width(invalid,4,"local field override does not change other invalid field")
    restore()
    set(root,"--border-separator-width","3px");set(root,"--border-separator-style","dotted")
    set(root,"--border-separator-color","var(--secondary)")
    width(separator,3,"root separator width propagates");width(local,2,"legacy local divider input wins")
    check(css(separator).borderTopStyle==="dotted" && css(separator).borderTopColor===css(local).borderTopColor,"separator style and color")
    near(separation(outer),27,"group includes selected separator width")
    near(separation(inner),19,"nested group inherits separator purpose")
    set(inner,"--divider-width","4px")
    near(separation(inner),20,"local divider width selects inner border")
    near(separation(outer),27,"inner border override cannot change outer frame")
    for(const n of [flat,lit,field,button,icon])width(n,1,"separator isolates unrelated consumers")
    restore()
    set(root,"--border-lit-width","3px");set(root,"--border-lit-style","dashed")
    for(const n of [lit,button,icon]){width(n,3,"lit role reaches raised components");check(css(n).borderTopStyle==="dashed","lit style propagates")}
    for(const n of [flat,field,separator])width(n,1,"lit role isolates flat/control/separator")
    for(const n of [flat,lit]) {
      set(n,"--radius","32px");set(n,"--design-card-padding-inline","8px");set(n,"--design-card-padding-block","12px")
      radius(n,n===lit?3:1)
      check(css(n).overflow==="visible" && css(n).zIndex==="auto","focus remains unclipped with no extra stacking")
    }
    restore()
    for(const n of [flat,lit,field,separator,button,icon]) {
      set(n,"--design-border-width","4px");width(n,4,"legacy local base-width override remains compatible")
    }
    restore()
    // Resolve colors with the browser, then calculate WCAG luminance independently.
    const canvas=document.createElement("canvas"),context=canvas.getContext("2d")
    canvas.width=canvas.height=1
    const luminance=color=>{
      context.clearRect(0,0,1,1);context.fillStyle=color;context.fillRect(0,0,1,1)
      const channels=[...context.getImageData(0,0,1,1).data].slice(0,3).map(v=>{const c=v/255;return c<=.04045?c/12.92:((c+.055)/1.055)**2.4})
      return channels[0]*.2126+channels[1]*.7152+channels[2]*.0722
    }
    const a=luminance(css(field).borderTopColor),b=luminance(css(field).backgroundColor)
    const fieldContrast=(Math.max(a,b)+.05)/(Math.min(a,b)+.05)
    check(fieldContrast>=3,`authored field boundary contrast ${fieldContrast}`)
    return {checks,fieldContrast}
  } finally {restore()}
}

export const verifyBorderReflow = () => {
  let checks=0
  const check=(ok,message)=>{if(!ok)throw new Error(message);checks++}
  const section=document.querySelector("#borders"),nodes=[...section.querySelectorAll("p,h3,label,button,input,code,output")]
  const saved=nodes.map(n=>[n,n.getAttribute("style")]),original=section.getAttribute("style")
  const long=section.querySelector('[lang="af"]'),copy=long.textContent
  const restore=()=>{for(const [n,s] of saved)s===null?n.removeAttribute("style"):n.setAttribute("style",s);long.textContent=copy}
  const fits=()=>[section,...section.querySelectorAll("article,p,.ds-divided,.ds-design-field,button,dd")].every(n=>n.scrollWidth<=n.clientWidth+1)
  try {
    check(fits(),"border lab fits viewport allocation")
    const sizes=nodes.map(n=>[n,parseFloat(getComputedStyle(n).fontSize)])
    for(const [n,size] of sizes)n.style.fontSize=`${size*2}px`
    long.textContent+=" "+"LangAfrikaanseBeskrywingLongEnglishContent".repeat(10)
    check(sizes.every(([n,size])=>Math.abs(parseFloat(getComputedStyle(n).fontSize)-size*2)<.1),"all specimen text exactly doubled")
    check(fits(),"doubled long border text reflows")
    restore()
    section.style.inlineSize="240px"
    check(fits(),"border lab fits 240px component allocation")
    return {checks}
  } finally {restore();original===null?section.removeAttribute("style"):section.setAttribute("style",original)}
}
