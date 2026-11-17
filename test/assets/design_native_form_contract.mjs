// Browser-owned native controls and computed geometry. Every mutation is restored.
export const verifyNativeFormContracts = () => {
  let checks=0
  const check=(ok,message)=>{if(!ok)throw new Error(message);checks++}
  const find=s=>{const n=document.querySelector(s);check(!!n,`missing native form ${s}`);return n}
  const css=n=>getComputedStyle(n),root=document.documentElement
  const input=find('#forms-choice'),checked=find('#forms-choice-checked'),invalid=find('#forms-choice-invalid')
  for(const n of [input,checked,invalid]) {
    const field=find(`#${n.id}-field`),label=field.querySelector(`label[for="${n.id}"]`)
    check(n.type==='checkbox' && n.classList.contains('ds-design-checkbox'),'shared native checkbox')
    check(field.querySelectorAll('input').length===1 && !field.querySelector('input[type=hidden]'),'unchecked control has no hidden companion')
    check(n.labels.length===1 && label.contains(n),'one native containing label')
    check(label.getBoundingClientRect().height>=parseFloat(css(root).getPropertyValue('--space-button-height')),'existing label hit-area height')
    check(n.getBoundingClientRect().width===parseFloat(css(root).getPropertyValue('--space-base')),'existing native checkbox size')
    check(css(n).appearance==='auto','native checkbox appearance retained')
    check(!n.hasAttribute('role') && !n.hasAttribute('tabindex'),'native checkbox interaction semantics')
  }
  check(!input.checked && checked.checked,'separate unchecked and checked examples')
  check(input.required && input.getAttribute('aria-required')==='true','native required state and explicit association')
  check(invalid.getAttribute('aria-invalid')==='true','invalid state belongs to the real input')
  check(invalid.getAttribute('aria-describedby')==='forms-choice-invalid-help forms-choice-invalid-error','help precedes error in native description')
  check(find('#forms-choice-invalid-error').getAttribute('role')==='alert','associated error alert')
  const action=find('#forms-choice-action')
  check(action.closest('.ds-design-choice')===input.closest('.ds-design-choice') && !action.closest('label'),'related link stays outside the checkbox label')
  const group=find('#forms-ready')
  check(group.tagName==='FIELDSET' && group.firstElementChild.tagName==='LEGEND','native fieldset begins with legend')
  check(group.getAttribute('aria-describedby')==='forms-ready-help','native group help association')
  check(find('#forms-email').getAttribute('aria-describedby')==='forms-email-help','shared text field uses associated help')
  const busy=find('#forms-busy')
  check(busy.disabled && busy.getAttribute('aria-busy')==='true','caller supplies native disabled group and busy projection')
  check([...busy.querySelectorAll('input')].every(n=>n.matches(':disabled')),'fieldset disables descendants natively')
  check([...busy.querySelectorAll('input')].every(n=>!n.disabled),'disabled propagation needs no duplicated per-input flag')
  const regular=input.closest('.ds-design-choice'),local=find('#forms-local-choice').closest('.ds-design-choice')
  const saved=root.getAttribute('style')
  try {
    const sibling=css(find('.ds-row')).gap
    root.style.setProperty('--field-gap','var(--space-md)')
    check(css(regular).gap===css(root).getPropertyValue('--space-md').trim(),'root field role propagates to checkbox descriptions')
    check(css(find('#forms-email').parentElement).gap===css(regular).gap,'same field role reaches text-field help')
    check(css(find('.ds-row')).gap===sibling,'field gap does not change control-row spacing')
    root.style.setProperty('--choice-gap','var(--space-lg)')
    check(css(regular).gap===css(root).getPropertyValue('--space-lg').trim(),'choice input overrides the general field input')
    check(css(local).gap===css(root).getPropertyValue('--space-md').trim(),'canonical local choice input wins over root')
    check(css(group).gap===css(root).getPropertyValue('--space-md').trim(),'choice input does not change fieldset separation')
    check(css(find('#forms-local')).gap===css(root).getPropertyValue('--space-base').trim(),'local fieldset gap stays independent')
  } finally {saved===null?root.removeAttribute('style'):root.setAttribute('style',saved)}
  return {checks}
}

export const verifyNativeFormReflow = () => {
  let checks=0
  const check=(ok,message)=>{if(!ok)throw new Error(message);checks++}
  const section=document.querySelector('#native-forms')
  const nodes=[...section.querySelectorAll('p,label,span,legend,a,input,dt,dd,code,output')]
  const saved=nodes.map(n=>[n,n.getAttribute('style')]),original=section.getAttribute('style')
  const label=section.querySelector('label span'),copy=label.textContent
  const fits=()=>[section,...section.querySelectorAll('.ds-form-example,fieldset,.ds-design-field,.ds-row,label,p,dt,dd')].every(n=>n.scrollWidth<=n.clientWidth+1)
  const restore=()=>{for(const[n,s]of saved)s===null?n.removeAttribute('style'):n.setAttribute('style',s);label.textContent=copy}
  try {
    check(fits(),'native form specimens fit their allocation')
    const sizes=nodes.map(n=>[n,parseFloat(getComputedStyle(n).fontSize)])
    for(const[n,size]of sizes)n.style.fontSize=`${size*2}px`
    label.textContent+=' '+'LongEnglishLabelLangAfrikaanseBeskrywing'.repeat(8)
    check(sizes.every(([n,size])=>Math.abs(parseFloat(getComputedStyle(n).fontSize)-size*2)<.1),'native form text exactly doubled')
    check(fits(),'long doubled native-form text reflows')
    restore();section.style.inlineSize='240px'
    check(fits(),'native forms fit a 240px parent')
    return {checks}
  } finally {restore();original===null?section.removeAttribute('style'):section.setAttribute('style',original)}
}
