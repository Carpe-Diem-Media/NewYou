// Independent computed-style proof shared by both browser engines. No app sizing code.
export const verifyContentContracts = () => {
  let checks=0
  const check=(ok,message)=>{if(!ok)throw new Error(message);checks++}
  const near=(a,b,message)=>check(Number.isFinite(a) && Math.abs(a-b)<.5,`${message}: ${a} != ${b}`)
  const find=selector=>{const n=document.querySelector(selector);check(!!n,`missing consumer ${selector}`);return n}
  const px=(n,property)=>parseFloat(getComputedStyle(n)[property])
  const root=document.documentElement,card=find("#content-card-default"),local=find("#content-card-local")
  const actions=n=>n.querySelector(":scope > .ds-design-card-actions")
  const paragraph=n=>n.querySelector(".ds-prose > p + p")
  const snapshot=new Map()
  const save=n=>{if(!snapshot.has(n))snapshot.set(n,n.getAttribute("style"));return n}
  const set=(n,name,value)=>save(n).style.setProperty(name,value)
  const restore=()=>{for(const [n,style] of snapshot){if(style===null)n.removeAttribute("style");else n.setAttribute("style",style)}snapshot.clear()}
  const shape=n=>[px(n,"paddingInlineStart"),px(n,"paddingBlockStart"),px(n,"borderTopLeftRadius"),px(n,"borderTopWidth")]
  const fitsNode=n=>{
    // Inline elements have zero clientWidth; Firefox can still report a nonzero
    // scrollWidth. Test their actual line fragments against the containing box.
    if(getComputedStyle(n).display==="inline") {
      const parent=n.parentElement.getBoundingClientRect()
      return [...n.getClientRects()].every(r=>r.left>=parent.left-1 && r.right<=parent.right+1)
    }
    return n.scrollWidth<=n.clientWidth+1
  }
  const fits=n=>[n,...n.querySelectorAll("p,li,blockquote,figure,figcaption,.ds-prose,.ds-design-card-actions,a")].every(fitsNode)
  const baselineShape=shape(card)
  const inset=find("#contract-card-local > .ds-design-card-inset")
  const insetRadius=getComputedStyle(inset).borderTopLeftRadius
  try {
    near(px(card,"rowGap"),16,"card content default preserves 16px")
    near(px(actions(card),"gap"),16,"card action default preserves 16px")
    near(px(local,"rowGap"),8,"labelled local content override")
    near(px(actions(local),"gap"),24,"labelled local action override")
    for(const n of [card,local]) {
      check(getComputedStyle(actions(n)).flexWrap==="wrap","actions retain native wrapping")
      check(n.tagName==="ARTICLE" && !n.hasAttribute("tabindex"),"card remains noninteractive")
      near(px(paragraph(n),"marginBlockStart"),24,"prose inside card owns its paragraph flow")
      const [heading,body]=n.children
      near(body.getBoundingClientRect().top-heading.getBoundingClientRect().bottom,px(n,"rowGap"),"one gap between heading and body")
      near(n.getBoundingClientRect().bottom-px(n,"borderBottomWidth")-px(n,"paddingBlockEnd")-actions(n).getBoundingClientRect().bottom,0,"actions stay at inner bottom when stretched")
      check(fits(n),"card content/actions fit their allocation")
    }
    set(root,"--card-content-gap","32px");set(root,"--card-action-gap","12px")
    near(px(card,"rowGap"),32,"root card content role propagates")
    near(px(actions(card),"gap"),12,"root card action role propagates")
    near(px(local,"rowGap"),8,"local content role wins over root")
    near(px(actions(local),"gap"),24,"local action role wins over root")
    near(px(paragraph(card),"marginBlockStart"),24,"card roles do not change prose flow")
    near(px(find("#content .ds-content-tokens > div"),"gap"),16,"card roles do not change control spacing")
    shape(card).forEach((n,i)=>near(n,baselineShape[i],"card roles preserve padding, radius and border"))
    check(getComputedStyle(inset).borderTopLeftRadius===insetRadius,"root card roles preserve per-axis inset radii")
    restore()
    set(card,"--card-content-gap","0px");set(card,"--card-action-gap","0px")
    near(px(card,"rowGap"),0,"zero local card content gap is valid")
    near(px(actions(card),"gap"),0,"zero local action gap is valid")
    near(px(paragraph(card),"marginBlockStart"),24,"zero card gap preserves paragraph flow")
    set(inset.parentElement,"--card-content-gap","0px");set(inset.parentElement,"--card-action-gap","32px")
    check(getComputedStyle(inset).borderTopLeftRadius===insetRadius,"local card roles preserve per-axis inset radii")
    restore()
    set(root,"--content-gap","36px");set(root,"--control-gap","20px")
    near(px(card,"rowGap"),16,"content/control changes do not move card children")
    near(px(actions(card),"gap"),16,"content/control changes do not move card actions")
    near(px(paragraph(card),"marginBlockStart"),36,"content role reaches prose inside card")
    near(px(find("#content .ds-content-tokens > div"),"gap"),20,"control role owns separate control row")
    restore()
    for(const locale of ["en","af"]) {
      const prose=find(`#prose-${locale}`),figure=find(`#prose-${locale}-figure`),caption=figure.querySelector("figcaption")
      const quote=figure.querySelector("blockquote"),nested=find(`#prose-${locale}-nested`)
      near(px(figure,"marginInlineStart"),0,"figure has no UA inline margin")
      near(px(figure,"marginInlineEnd"),0,"figure has no UA inline end margin")
      near(px(figure,"marginBlockStart"),24,"outer prose owns figure separation")
      near(px(quote,"marginBlockStart"),0,"figure first child has no leading margin")
      near(px(caption,"marginBlockEnd"),0,"figure last child has no trailing margin")
      near(caption.getBoundingClientRect().top-quote.getBoundingClientRect().bottom,8,"caption has exactly one gap")
      near(px(caption,"fontSize"),12,"caption keeps approved size")
      near(px(find(`#prose-${locale}-nested-frame`),"marginBlockStart"),24,"outer flow owns gap before nested frame")
      near(px(nested,"marginBlockStart"),0,"nested scope starts inside its outer flow wrapper")
      near(px(nested.firstElementChild,"marginBlockStart"),0,"nested first child has no leading margin")
      near(px(nested.lastElementChild,"marginBlockEnd"),0,"nested last child has no trailing margin")
      near(px(nested.querySelector("p + p"),"marginBlockStart"),8,"nested scope owns internal flow")
      near(px(prose.querySelector("hr"),"marginBlockStart"),24,"outer flow resumes after nested scope")
      set(prose,"--prose-flow-space","40px");set(prose,"--prose-caption-space","12px")
      near(px(figure,"marginBlockStart"),40,"local flow reaches figure")
      near(px(caption,"marginBlockStart"),12,"caption input resolves on prose scope")
      near(px(quote.querySelector("p + p"),"marginBlockStart"),40,"figure quote retains local paragraph flow")
      near(px(nested.querySelector("p + p"),"marginBlockStart"),8,"explicit nested flow remains isolated")
      near(px(find(`#prose-${locale==="en"?"af":"en"}-figure figcaption`),"marginBlockStart"),8,"local caption input does not reach sibling prose")
      set(prose,"--prose-caption-space","0px")
      near(px(caption,"marginBlockStart"),0,"zero caption gap is valid")
      restore()
      check(fits(prose),`${locale} figures and nested prose fit: ${JSON.stringify([prose,...prose.querySelectorAll("p,li,blockquote,figure,figcaption,.ds-prose,a")].filter(n=>!fitsNode(n)).map(n=>({tag:n.tagName,id:n.id,scroll:n.scrollWidth,client:n.clientWidth,display:getComputedStyle(n).display})))}`)
    }
    near(px(find("#prose-local figcaption"),"marginBlockStart"),4,"labelled caption override uses existing 4px scale")
    return {checks}
  } finally {restore()}
}

// Stress the actual figure/nested specimens in each engine, independently of
// root-font simulation. Restore all temporary content, classes and styles.
export const verifyContentReflow = () => {
  let checks=0
  const check=(ok,message)=>{if(!ok)throw new Error(message);checks++}
  const content=document.querySelector("#content")
  const prose=[...content.querySelectorAll("#prose-en,#prose-af")]
  const classes=prose.map(n=>[n,n.className])
  const nodes=[...content.querySelectorAll("h3,h4,h5,p,li,a,blockquote,figcaption")]
  const styles=nodes.map(n=>[n,n.getAttribute("style")])
  const originalWidth=content.getAttribute("style")
  const long=content.querySelector("#prose-af > p"),copy=long.textContent
  const textSpacing=document.createElement("style")
  const restoreType=()=>{for(const [n,s] of styles)s===null?n.removeAttribute("style"):n.setAttribute("style",s);long.textContent=copy}
  const fits=()=>[content,...content.querySelectorAll("article,p,li,blockquote,figure,figcaption,.ds-prose,.ds-design-card-actions")]
    .every(n=>n.scrollWidth<=n.clientWidth+1)
  try {
    for(const candidate of [false,true]) {
      for(const n of prose)n.classList.toggle("ds-scale-reading",candidate)
      check(fits(),`${candidate?"candidate":"production"} figure/nested normal reflow`)
      const sizes=nodes.map(n=>[n,parseFloat(getComputedStyle(n).fontSize)])
      for(const [n,size] of sizes)n.style.fontSize=`${size*2}px`
      long.textContent+=" "+"LangAfrikaanseBeskrywingLongEnglishContent".repeat(10)
      check(sizes.every(([n,size])=>Math.abs(parseFloat(getComputedStyle(n).fontSize)-size*2)<.1),"new specimens use exact doubled text")
      check(fits(),`${candidate?"candidate":"production"} figure/nested doubled long-text reflow`)
      restoreType()
      textSpacing.textContent="#content p { margin-block-end: 2em !important; } #content :is(h3,h4,h5,p,li,a,blockquote,figcaption) { line-height: 1.5 !important; letter-spacing: .12em !important; word-spacing: .16em !important; }"
      document.head.append(textSpacing)
      check(fits(),`${candidate?"candidate":"production"} figure/nested user text-spacing reflow`)
      textSpacing.remove()
      content.style.inlineSize="240px"
      check(fits(),`${candidate?"candidate":"production"} figure/nested 240px parent reflow`)
      originalWidth===null?content.removeAttribute("style"):content.setAttribute("style",originalWidth)
    }
    return {checks}
  } finally {
    restoreType();textSpacing.remove()
    for(const [n,c] of classes)n.className=c
    originalWidth===null?content.removeAttribute("style"):content.setAttribute("style",originalWidth)
  }
}
