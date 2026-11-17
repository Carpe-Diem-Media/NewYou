// Independent CSS/contrast proof shared by both browser engines. Mutations are restored.
export const verifySurfaceContracts = () => {
  let checks=0
  const check=(ok,message)=>{if(!ok)throw new Error(message);checks++}
  const find=s=>{const n=document.querySelector(s);check(!!n,`missing surface ${s}`);return n}
  const css=n=>getComputedStyle(n),root=document.documentElement
  const roles=["heading","body","muted","link","link-hover","focus"]
  const profiles=["plain","canvas","panel","raised"]
  const canvas=document.createElement("canvas");canvas.width=canvas.height=1
  const ctx=canvas.getContext("2d")
  const rgb=color=>{ctx.clearRect(0,0,1,1);ctx.fillStyle=color;ctx.fillRect(0,0,1,1);const rgba=[...ctx.getImageData(0,0,1,1).data];check(rgba[3]===255,`opaque color required: ${color}`);return rgba.slice(0,3)}
  const same=(a,b,message)=>check(JSON.stringify(rgb(a))===JSON.stringify(rgb(b)),message)
  const luminance=rgb=>rgb.map(v=>{const c=v/255;return c<=.04045?c/12.92:((c+.055)/1.055)**2.4}).reduce((sum,n,i)=>sum+n*[.2126,.7152,.0722][i],0)
  const contrast=(fg,bg)=>{const a=luminance(rgb(fg)),b=luminance(rgb(bg));return(Math.max(a,b)+.05)/(Math.min(a,b)+.05)}
  const token=(n,name)=>css(n).getPropertyValue(name).trim()
  const snapshot=new Map(),temporary=[]
  const set=(n,name,value)=>{if(!snapshot.has(n))snapshot.set(n,n.getAttribute("style"));n.style.setProperty(name,value)}
  const restore=()=>{for(const[n,s]of snapshot)s===null?n.removeAttribute("style"):n.setAttribute("style",s);snapshot.clear()}
  const pairs=profiles.map(p=>find(`#pair-${p}.ds-surface[data-surface="${p}"]`))
  const minimum={text:Infinity,focus:Infinity}
  const resolved=n=>["background",...roles].map(r=>token(n,`--context-${r}`))
  const baseline=pairs.map(resolved)
  const nested=find("#pair-nested"),local=find("#pair-local"),parent=find("#pair-card-parent")
  const flat=find("#pair-card-plain"),raised=find("#pair-card-raised")
  try {
    for(const [i,n]of pairs.entries()) {
      const profile=profiles[i],ground=css(n).backgroundColor
      check(css(n).backgroundImage==="none","supported profiles remain opaque solids")
      check(baseline[i].every(Boolean),"every boundary assigns all seven outputs")
      for(const role of roles) {
        const probe=find(`#pair-${profile}-probe-${role}`),color=css(probe).color
        same(color,token(root,role==="focus"?"--primary":role==="muted"?"--ink-meta":"--secondary"),`${profile}/${role} preserves default role`)
        const ratio=contrast(color,ground)
        check(ratio>=(role==="focus"?3:4.5),`${profile}/${role} contrast ${ratio}`)
        minimum[role==="focus"?"focus":"text"]=Math.min(minimum[role==="focus"?"focus":"text"],ratio)
        if(["heading","body","muted","link"].includes(role))same(css(find(`#pair-${profile}-${role}`)).color,color,"actual content matches role probe")
      }
      if(profile!=="plain")same(ground,css(find(`.ds-lighting-level[data-level="${profile}"]`)).backgroundColor,"pair uses the existing lighting background")
    }
    same(css(flat).backgroundColor,token(root,"--surface"),"flat card preserves white background")
    same(css(raised).backgroundColor,token(root,"--surface"),"raised card preserves existing background")
    check(flat.dataset.surface==="plain" && raised.dataset.surface==="raised","cards own their surface assignments")
    set(root,"--surface-plain-body","var(--primary)")
    same(css(find("#pair-plain-body")).color,token(root,"--primary"),"root profile body reaches actual content")
    same(css(flat).color,token(root,"--primary"),"root profile reaches production card consumer")
    same(css(find("#pair-panel-body")).color,token(root,"--secondary"),"profile edit does not change another profile")
    restore()
    set(pairs[0],"--surface-plain-link","var(--primary)")
    same(css(find("#pair-plain-link")).color,token(root,"--primary"),"local link input reaches shared link")
    same(css(find("#pair-panel-link")).color,token(root,"--secondary"),"local link input isolates siblings")
    const matching=document.createElement("div")
    matching.className="ds-surface";matching.dataset.surface="plain"
    pairs[0].append(matching);temporary.push(matching)
    set(pairs[0],"--context-link","var(--secondary)")
    same(token(matching,"--context-link"),token(root,"--primary"),"nested matching profile inherits named input and recomputes output")
    matching.remove()
    restore()
    // Deliberately contaminate every resolved output on parent boundaries.
    // Nested components must recompute from their own profile inputs.
    for(const n of [local,parent]) {
      for(const role of ["background",...roles])set(n,`--context-${role}`,"var(--primary)")
    }
    for(const n of [nested,flat,raised]) {
      const expected=n===raised?baseline[3]:baseline[0]
      resolved(n).forEach((v,i)=>same(v,expected[i],"nested surface resets every resolved output"))
    }
    same(css(find("#pair-nested-link")).color,token(root,"--secondary"),"nested link consumes reset role")
    same(css(find("#pair-card-link")).color,token(root,"--secondary"),"nested card link consumes reset role")
    restore()
    const before=css(pairs[1]).backgroundColor
    set(pairs[1],"--canvas","var(--orb-saffron)")
    check(css(pairs[1]).backgroundColor!==before,"local primitive recomputes lighting at surface boundary")
    check(css(pairs[2]).backgroundColor===css(find('.ds-lighting-level[data-level="panel"]')).backgroundColor,"local source edit isolates other surfaces")
    restore()
    set(root,"--surface-canvas-muted","var(--primary)")
    same(css(find("#pair-canvas-muted")).color,token(root,"--primary"),"root named profile input propagates")
    same(css(local.querySelector(".ds-context-muted")).color,token(root,"--secondary"),"canonical local input wins over root profile input")
    same(css(find("#pair-nested-muted")).color,token(root,"--ink-meta"),"other nested profile retains its own muted input")
    restore()
    for(const n of pairs)check(css(n).overflow==="visible" && css(n).zIndex==="auto","boundary adds no clipping or stacking")
    return {checks,minimum}
  } finally {restore();for(const n of temporary)n.remove()}
}

export const verifySurfaceReflow = () => {
  let checks=0
  const check=(ok,message)=>{if(!ok)throw new Error(message);checks++}
  const section=document.querySelector("#surface-pairings")
  const nodes=[...section.querySelectorAll("p,h3,a,summary,dt,dd,span,output,code")]
  const saved=nodes.map(n=>[n,n.getAttribute("style")]),original=section.getAttribute("style")
  const details=[...section.querySelectorAll("details")].map(n=>[n,n.open])
  const long=section.querySelector('[lang="af"]'),copy=long.textContent
  const restore=()=>{for(const[n,s]of saved)s===null?n.removeAttribute("style"):n.setAttribute("style",s);long.textContent=copy}
  const fits=()=>[section,...section.querySelectorAll(".ds-surface,.ds-pair-example,p,h3,dd,summary")].every(n=>n.scrollWidth<=n.clientWidth+1)
  try {
    for(const[n]of details)n.open=true
    check(fits(),"open pairing inspectors fit their allocation")
    const sizes=nodes.map(n=>[n,parseFloat(getComputedStyle(n).fontSize)])
    for(const[n,size]of sizes)n.style.fontSize=`${size*2}px`
    long.textContent+=" "+"LangAfrikaanseBeskrywingLongEnglishContent".repeat(10)
    check(sizes.every(([n,size])=>Math.abs(parseFloat(getComputedStyle(n).fontSize)-size*2)<.1),"pair text exactly doubled")
    check(fits(),"long doubled EN/AF pairing content fits")
    restore();section.style.inlineSize="240px"
    check(fits(),"pairings fit 240px parent allocation")
    return {checks}
  } finally {restore();for(const[n,open]of details)n.open=open;original===null?section.removeAttribute("style"):section.setAttribute("style",original)}
}
