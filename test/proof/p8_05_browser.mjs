// Dependency-free Chromium DevTools driver for the runner-owned P8-05 cases.
// No screenshots, traces, page bodies, credentials or raw browser diagnostics
// leave this process. Only fixed facts, allow-listed error codes and opaque
// operation IDs are returned.
import { boundedProtocol, createBrowserContext, completeNavigation, settleBrowserExit, settleContextLoss, protocolError, boundedFailureCode } from './browser_protocol.mjs';
import { createHash } from 'node:crypto';
import { spawn } from 'node:child_process';
import { existsSync, readFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir, homedir } from 'node:os';
import { join } from 'node:path';
import { createInterface } from 'node:readline';

const input = await new Promise(resolve => createInterface({ input: process.stdin }).once('line', line => resolve(JSON.parse(line))));
const candidates = ['/usr/bin/google-chrome', '/opt/google/chrome/chrome', '/usr/bin/chromium', '/usr/bin/chromium-browser', join(homedir(), '.cache/ms-playwright/chromium-1234/chrome-linux64/chrome')];
const executable = candidates.find(existsSync);
const profile = mkdtempSync(join(tmpdir(), 'p805-browser-'));
let browser;
let browserStopped;
let closeBrowser;
let browserReady = false;
let cleanup = false;
let failure;
// A closed runner pipe or cancellation also terminates the browser child.
const cancel = () => { browser?.kill('SIGTERM'); try { rmSync(profile, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 }); } catch {} process.exit(2); };
process.stdin.on('end', cancel);
process.on('SIGTERM', cancel);
process.on('SIGHUP', cancel);
const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');
const operations = [];
const checks = {};
try {
  if (!executable) throw new Error('browser.unavailable');
  browser = spawn(executable, ['--headless=new', '--no-sandbox', '--disable-gpu', '--disable-background-networking', '--disable-component-update', '--no-first-run', '--remote-debugging-pipe', `--user-data-dir=${profile}`, 'about:blank'], { stdio: ['ignore', 'ignore', 'ignore', 'pipe', 'pipe'] });
  let sequence = 0;
  let buffer = '';
  const pending = new Map();
  const events = new Map();
  browserStopped = new Promise(resolve => browser.once('exit', () => { settleBrowserExit(pending); resolve(); }));
  browser.stdio[4].on('data', chunk => {
    buffer += chunk.toString();
    let end;
    while ((end = buffer.indexOf('\0')) >= 0) {
      const message = JSON.parse(buffer.slice(0, end));
      buffer = buffer.slice(end + 1);
      if (message.id) {
        const waiter = pending.get(message.id);
        if (waiter) {
          clearTimeout(waiter.timer);
          pending.delete(message.id);
          if (message.error) waiter.reject(protocolError(message.error));
          else waiter.resolve(message.result);
        }
      } else if (message.method) {
        if (message.method === 'Runtime.executionContextsCleared') {
          settleContextLoss(pending, message.sessionId);
        }
        const key = `${message.sessionId}:${message.method}`;
        const waiter = events.get(key);
        if (waiter) { clearTimeout(waiter.timer); events.delete(key); waiter.resolve(message.params); }
      }
    }
  });
  function requestProtocol(method, params = {}, sessionId, timeout = 20000) {
    return new Promise((resolve, reject) => {
      const id = ++sequence;
      const timer = setTimeout(() => { pending.delete(id); reject(new Error(`browser.protocol_timeout.${method}`)); }, timeout);
      pending.set(id, { resolve, reject, timer, method, sessionId });
      browser.stdio[3].write(JSON.stringify({ id, method, params, ...(sessionId ? { sessionId } : {}) }) + '\0');
    });
  }
  const call = boundedProtocol(requestProtocol);
  // Leave shutdown time inside the outer 45-second browser-process deadline,
  // even when the bounded cold-start readiness check has failed.
  closeBrowser = () => call('Browser.close', {}, undefined, browserReady ? 20000 : 1000);
  const context = await createBrowserContext(call);
  browserReady = true;
  const { targetId } = await call('Target.createTarget', { url: 'about:blank', browserContextId: context.browserContextId });
  const { sessionId } = await call('Target.attachToTarget', { targetId, flatten: true });
  const cdp = (method, params) => call(method, params, sessionId);
  await cdp('Page.enable');
  await cdp('Runtime.enable');
  const evaluate = async expression => {
    const value = await cdp('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
    if (value.exceptionDetails) throw new Error('browser.evaluation');
    return value.result.value;
  };
  const navigation = async action => {
    const key = `${sessionId}:Page.loadEventFired`;
    let timer;
    const loaded = new Promise((resolve, reject) => {
      timer = setTimeout(() => { events.delete(key); reject(new Error('browser.navigation_timeout')); }, 20000);
      events.set(key, { resolve, timer });
    });
    try { await completeNavigation(action, loaded); }
    finally { clearTimeout(timer); events.delete(key); }
  };
  const base = `http://127.0.0.1:${input.port}`;
  if (input.mode === 'login') {
    await navigation(() => cdp('Page.navigate', {url: `${base}/login?locale=${input.locale}`}));
    checks.login_form = await evaluate(`document.documentElement.lang === ${JSON.stringify(input.locale)} && !!document.querySelector('form[action="/login"] [name="_csrf_token"]')`);
    await evaluate(`document.querySelector('[name="email"]').value=${JSON.stringify(input.email)}; document.querySelector('[name="password"]').value=${JSON.stringify(input.password)};`);
    await navigation(() => evaluate(`document.querySelector('form[action="/login"]').requestSubmit()`));
    checks.protected_access = await evaluate(`location.pathname === '/session/protected'`);
    checks.reloaded_access = await evaluate(`fetch('/session/protected').then(r => r.status === 200)`);
  } else if (input.mode === 'password_reset') {
    await cdp('Emulation.setDeviceMetricsOverride', {width: 375, height: 800, deviceScaleFactor: 1, mobile: true});
    await cdp('Emulation.setEmulatedMedia', {features: [{name: 'prefers-reduced-motion', value: 'reduce'}]});
    const url = `${base}/password/reset/confirm?${new URLSearchParams({proof: input.proof, locale: input.locale})}`;
    await navigation(() => cdp('Page.navigate', {url}));
    checks.explicit_form = await evaluate(`document.documentElement.lang === ${JSON.stringify(input.locale)} && !!document.querySelector('#password-reset-confirmation [name="_csrf_token"]') && document.querySelector('[name="password"]').autocomplete === 'new-password'`);
    checks.stylesheet_loaded = await evaluate(`document.querySelector('link[rel="stylesheet"]')?.sheet?.cssRules.length > 0`);
    operations.push(await evaluate(`document.querySelector('[name="operation_id"]').value`));
    await cdp('Input.dispatchKeyEvent', {type: 'keyDown', key: 'Tab', code: 'Tab', windowsVirtualKeyCode: 9});
    await cdp('Input.dispatchKeyEvent', {type: 'keyUp', key: 'Tab', code: 'Tab', windowsVirtualKeyCode: 9});
    checks.keyboard_focus = await evaluate(`document.activeElement.name === 'password' && document.activeElement.matches(':focus-visible') && parseFloat(getComputedStyle(document.activeElement).outlineWidth) >= 2`);
    checks.responsive = await evaluate(`document.documentElement.scrollWidth <= innerWidth`);
    checks.reduced_motion = await evaluate(`matchMedia('(prefers-reduced-motion: reduce)').matches && document.getAnimations().length === 0`);
    await evaluate(`document.querySelector('[name="password"]').value=${JSON.stringify(input.password)}`);
    await navigation(() => evaluate(`document.querySelector('#password-reset-confirmation').requestSubmit()`));
    checks.reset_complete = await evaluate(`document.querySelector('h1').textContent.trim() === ${JSON.stringify(input.complete_title)} && !!document.querySelector('a[href="/login?locale=${input.locale}"]') && !document.querySelector('[name="proof"]') && !document.body.textContent.includes(${JSON.stringify(input.proof)}) && !document.body.textContent.includes(${JSON.stringify(input.password)})`);
    await navigation(() => cdp('Page.navigate', {url}));
    operations.push(await evaluate(`document.querySelector('[name="operation_id"]').value`));
    await evaluate(`document.querySelector('[name="password"]').value=${JSON.stringify(input.password)}`);
    await navigation(() => evaluate(`document.querySelector('#password-reset-confirmation').requestSubmit()`));
    checks.replay_denied = await evaluate(`document.querySelector('h1').textContent.trim() === ${JSON.stringify(input.unavailable_title)} && !document.querySelector('[name="proof"]')`);
  } else if (input.mode === 'verification') {
    const file = 'docs/development/fixtures/p8-07-copy-v1.json';
    const fixture = JSON.parse(readFileSync(file, 'utf8'));
    const text = (state, part) => fixture.entries[`identity.verification.result.${state}.${part}`][input.locale].text;
    const hasState = state => evaluate(`document.documentElement.lang === ${JSON.stringify(input.locale)} && document.querySelector('h1').textContent.trim() === ${JSON.stringify(text(state, 'title'))} && document.body.textContent.includes(${JSON.stringify(text(state, 'body'))})`);
    const url = `${base}/verification/confirm?${new URLSearchParams({proof: input.proof, locale: input.locale})}`;
    await navigation(() => cdp('Page.navigate', {url}));
    checks.temporary_copy = sha256(readFileSync(file)) === '146eeb3399c96fd0bc995fc905161a4a70f90bbf21fa77f395b2e427e840b1fa' && await hasState('confirm');
    checks.explicit_form = await evaluate(`(() => { const form = document.querySelector('#email-confirmation'); return form?.method === 'post' && !!form.querySelector('[name="_csrf_token"]').value && form.querySelector('button').textContent.trim() === ${JSON.stringify(text('confirm', 'action'))}; })()`);
    await navigation(() => evaluate(`document.querySelector('#email-confirmation button').click()`));
    checks.verified_result = await hasState('verified') && await evaluate(`!document.querySelector('[name="proof"]') && !document.body.textContent.includes(${JSON.stringify(input.proof)})`);
    await navigation(() => cdp('Page.navigate', {url}));
    await navigation(() => evaluate(`document.querySelector('#email-confirmation button').click()`));
    checks.safe_replay = await hasState('unavailable') && await evaluate(`!document.querySelector('[name="proof"]') && !document.body.textContent.includes(${JSON.stringify(input.proof)})`);
  } else {
  await navigation(() => cdp('Page.navigate', { url: `${base}/register?locale=${input.locale}` }));
  const registry = JSON.parse(readFileSync('docs/delivery/content-evidence/copy/COPY_REGISTRY.json', 'utf8'));
  const text = (key, locale) => registry.entries.find(entry => entry.key === key)[locale].text.replaceAll('{{platform_name}}', input.platform_name);
  const registrationKeys = ['public.entry.launch.title', 'public.entry.launch.body', 'public.entry.safety.body', 'identity.registration.title', 'identity.registration.intro', 'identity.registration.first_name.label', 'identity.registration.surname.label', 'identity.registration.email.label', 'identity.registration.password.label', 'identity.registration.preferred_language.label', 'identity.registration.preferred_language.help', 'identity.registration.age_confirmation', 'legal.shared.document_language_disclosure', 'identity.registration.terms_acceptance', 'identity.registration.terms_link', 'identity.registration.privacy_presentation', 'identity.registration.privacy_link', 'identity.registration.privacy_acceptance', 'identity.registration.submit'];
  const pendingKeys = ['identity.verification.pending.title', 'identity.verification.pending.explanation', 'identity.verification.pending.check_inbox', 'identity.verification.pending.address_label', 'identity.verification.pending.not_arrived.title', 'identity.verification.pending.not_arrived.body', 'identity.verification.resend.action', 'identity.verification.pending.access_limitation', 'identity.verification.pending.browse_public', 'identity.verification.pending.home'];
  const hasCopy = async (keys, locale) => evaluate(`(${JSON.stringify(keys.map(key => text(key, locale)))}).every(text => document.body.innerText.includes(text))`);
  const noFallback = async keys => {
    const other = input.locale === 'af' ? 'en' : 'af';
    const alternatives = keys.filter(key => text(key, other) !== text(key, input.locale)).map(key => text(key, other));
    return evaluate(`document.documentElement.lang === ${JSON.stringify(input.locale)} && (${JSON.stringify(alternatives)}).every(text => !document.body.textContent.includes(text))`);
  };
  checks.approved_copy = sha256(readFileSync('docs/delivery/content-evidence/copy/COPY_REGISTRY.json')) === '744f1a34ad80c0158c86395f3f66227622714969526f5e9d69ee62314fd48635' && await hasCopy(registrationKeys, input.locale);
  checks.approved_copy &&= await evaluate(`document.body.innerText.indexOf(${JSON.stringify(text('public.entry.safety.body', input.locale))}) < document.body.innerText.indexOf(${JSON.stringify(text('identity.registration.title', input.locale))})`);
  const registrationLocale = await noFallback(registrationKeys);
  const form = await evaluate(`(() => { const form = document.querySelector('form[action="/register"]'); return { action: form?.getAttribute('action'), fields: [...form.elements].filter(el => el.name).map(el => ({ name: el.name, type: el.type, required: el.required, value: el.type === 'hidden' ? el.value : null })) }; })()`);
  const fieldNames = ['first_name', 'surname', 'email', 'password', 'confirmed_age_18', 'terms_accepted', 'privacy_accepted'];
  checks.required_form = fieldNames.every(name => form.fields.some(field => field.name === `registration[${name}]` && field.required));
  operations.push(form.fields.find(field => field.name === 'registration[operation_id]').value);
  checks.legal_artifacts = await evaluate(`Promise.all(['/legal/terms', '/legal/privacy'].map(async path => { const link = document.querySelector('a[href=\"'+path+'\"]'); if (!link) return {status: 0, body: ''}; const response = await fetch(link.href); return {status: response.status, body: await response.text()}; }))`)
    .then(pages => pages.every((page, index) => page.status === 200 && sha256(page.body) === ['6feb2d016f30e889c08995990a863429db0034af49fc6b6bd3467b90cda03937', 'ac603377eaafce20bf5e425f64cfc97fbc855b20bd66deca481401f0f6efd43e'][index] && page.body === readFileSync(`docs/delivery/content-evidence/content_media/legal_baselines/NEWYOU-${index === 0 ? 'TERMS' : 'PRIVACY'}-EN-DEV-BASELINE-2026-10-27-001.html`, 'utf8')));
  await evaluate(`(() => { const values = ${JSON.stringify({first_name: input.input.first_name, surname: input.input.surname, email: input.input.email, password: input.input.password, preferred_language: input.locale})}; for (const [name,value] of Object.entries(values)) document.querySelector('[name="registration['+name+']"]').value=value; for (const name of ['confirmed_age_18','terms_accepted','privacy_accepted']) document.querySelector('[name="registration['+name+']"]').checked=true; })()`);
  checks.submitted_acceptances = await evaluate(`(() => { const form = document.querySelector('form[action="/register"]'); const data = new FormData(form); return form.checkValidity() && ['confirmed_age_18','terms_accepted','privacy_accepted'].every(name => data.get('registration['+name+']') === 'true') && data.get('registration[preferred_language]') === ${JSON.stringify(input.locale)}; })()`);
  await navigation(() => evaluate(`document.querySelector('form[action="/register"]').requestSubmit()`));
  checks.pending_copy = await hasCopy([...pendingKeys, 'identity.registration.accepted_neutral'], input.locale);
  const pendingLocale = await noFallback(pendingKeys);
  const resendOperation = await evaluate(`document.querySelector('[name="resend[operation_id]"]')?.value`);
  if (resendOperation) operations.push(resendOperation);
  await navigation(() => evaluate(`document.querySelector('form[action="/verification/resend"]').requestSubmit()`));
  const nextOperation = await evaluate(`document.querySelector('[name="resend[operation_id]"]')?.value`);
  checks.explicit_resend = operations[0] !== resendOperation && nextOperation !== resendOperation && await hasCopy([...pendingKeys, 'identity.verification.resend.accepted_neutral'], input.locale);
  checks.locale_no_fallback = registrationLocale && pendingLocale && await noFallback(pendingKeys);
  checks.no_session = await evaluate(`!document.body.textContent.includes(${JSON.stringify(input.input.password)}) && !document.querySelector('a[href*="consume"]')`);
  }
  await call('Target.disposeBrowserContext', { browserContextId: context.browserContextId });
} catch (error) {
  failure = boundedFailureCode(error);
  checks.browser_completed = false;
} finally {
  try {
    if (browser && browser.exitCode === null) {
      // Browser.close completes the normal Chromium shutdown path before the
      // profile is removed. Abrupt parent termination races child profile writes.
      try { await closeBrowser(); } catch { browser.kill('SIGTERM'); }
      await browserStopped;
    }
    rmSync(profile, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 });
    cleanup = !existsSync(profile) && (!browser || browser.exitCode !== null);
  } catch {
    cleanup = false;
  }
}
process.stdout.write(JSON.stringify({checks, operations, cleanup, failure}));
process.exit(0);
