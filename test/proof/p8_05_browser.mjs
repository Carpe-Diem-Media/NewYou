// Dependency-free Chromium DevTools driver for the runner-owned P8-05 cases.
// No screenshots, traces, page bodies, credentials or raw browser diagnostics
// leave this process. Only fixed facts, allow-listed error codes and opaque
// operation IDs are returned.
import { boundedProtocol, createBrowserContext, completeNavigation, settleBrowserExit, settleContextLoss, protocolError, boundedFailureCode } from './browser_protocol.mjs';
import { createHash, randomUUID } from 'node:crypto';
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
let checkpoint;
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
  const loginUrl = new URL('/login', base);
  loginUrl.searchParams.set('locale', input.locale);
  const loginPath = `${loginUrl.pathname}${loginUrl.search}`;
  const loginPathLiteral = JSON.stringify(loginPath);
  if (input.mode === 'login') {
    await navigation(() => cdp('Page.navigate', {url: loginUrl.toString()}));
    checks.login_form = await evaluate(`document.documentElement.lang === ${JSON.stringify(input.locale)} && !!document.querySelector('form[action="/login"] [name="_csrf_token"]')`);
    await evaluate(`document.querySelector('[name="email"]').value=${JSON.stringify(input.email)}; document.querySelector('[name="password"]').value=${JSON.stringify(input.password)};`);
    await navigation(() => evaluate(`document.querySelector('form[action="/login"]').requestSubmit()`));
    checks.protected_access = await evaluate(`location.pathname === '/session/protected'`);
    checks.reloaded_access = await evaluate(`fetch('/session/protected').then(r => r.status === 200)`);
  } else if (input.mode === 'stale_session') {
    await navigation(() => cdp('Page.navigate', {url: loginUrl.toString()}));
    checks.login_form = await evaluate(`!!document.querySelector('form[action="/login"] [name="_csrf_token"]')`);
    await evaluate(`document.querySelector('[name="email"]').value=${JSON.stringify(input.email)}; document.querySelector('[name="password"]').value=${JSON.stringify(input.password)};`);
    await navigation(() => evaluate(`document.querySelector('form[action="/login"]').requestSubmit()`));
    checks.protected_page_loaded = await evaluate(`location.pathname === '/session/protected'`);
    checks.logout_completed = await evaluate(`(async () => { const html = await fetch(${loginPathLiteral}, {cache: 'no-store'}).then(r => r.text()); const form = new DOMParser().parseFromString(html, 'text/html'); const csrf = form.querySelector('form[action="/login"] [name="_csrf_token"]')?.value; if (!csrf) return false; const response = await fetch('/session/logout', {method: 'POST', headers: {'content-type': 'application/x-www-form-urlencoded'}, body: new URLSearchParams({_csrf_token: csrf})}); const doc = new DOMParser().parseFromString(await response.text(), 'text/html'); return response.status === 200 && doc.querySelector('h1')?.textContent.trim() === ${JSON.stringify(JSON.parse(readFileSync('docs/development/fixtures/well134-c01-v0.1.json', 'utf8')).entries['identity.session.logout.confirmed.title'][input.locale].text)}; })()`);
    checks.reconnect_denied = await evaluate(`fetch('/session/protected', {cache: 'no-store'}).then(r => r.status === 401)`);
    checks.stale_page_retained = await evaluate(`location.pathname === '/session/protected'`);
  } else if (input.mode === 'signin') {
    const approved = JSON.parse(readFileSync('docs/development/fixtures/well134-c01-v0.1.json', 'utf8'));
    const text = key => approved.entries[key][input.locale].text;
    const literal = key => JSON.stringify(text(key));
    const hasTitle = key => evaluate(`document.documentElement.lang === ${JSON.stringify(input.locale)} && document.querySelector('h1')?.textContent.trim() === ${literal(key)}`);
    const passwordSubmit = async password => {
      await evaluate(`document.querySelector('[name="email"]').value=${JSON.stringify(input.input.email)}; document.querySelector('[name="password"]').value=${JSON.stringify(password)};`);
      await navigation(() => evaluate(`document.querySelector('#password-login').requestSubmit()`));
    };
    await navigation(() => cdp('Page.navigate', {url: `${base}/?locale=${input.locale}`}));
    checks.normal_navigation = await evaluate(`!!document.querySelector('a[href="/login?locale=${input.locale}"]')`);
    await navigation(() => evaluate(`document.querySelector('a[href="/login?locale=${input.locale}"]').click()`));
    checks.locale = await hasTitle('identity.login.title');
    for (let tab = 0; tab < 5 && !(await evaluate(`document.activeElement.id === 'email'`)); tab++) {
      await cdp('Input.dispatchKeyEvent', {type: 'keyDown', key: 'Tab', code: 'Tab', windowsVirtualKeyCode: 9});
      await cdp('Input.dispatchKeyEvent', {type: 'keyUp', key: 'Tab', code: 'Tab', windowsVirtualKeyCode: 9});
    }
    checks.focus = await evaluate(`document.activeElement.id === 'email' && document.activeElement.matches(':focus-visible') && parseFloat(getComputedStyle(document.activeElement).outlineWidth) >= 2 && !!document.querySelector('label[for="email"]') && !!document.querySelector('label[for="password"]')`);
    checks.responsive = true;
    checks.text_resize = true;
    await cdp('Emulation.setEmulatedMedia', {features: [{name: 'prefers-reduced-motion', value: 'reduce'}]});
    checks.reduced_motion = await evaluate(`matchMedia('(prefers-reduced-motion: reduce)').matches && document.getAnimations().length === 0`);
    checks.stylesheet_loaded = await evaluate(`document.querySelector('link[rel="stylesheet"]')?.sheet?.cssRules.length > 0`);
    for (const width of [320, 375, 768, 1280, 1920]) {
      await cdp('Emulation.setDeviceMetricsOverride', {width, height: 900, deviceScaleFactor: 1, mobile: width < 768});
      checks.responsive = checks.responsive && await evaluate(`document.documentElement.scrollWidth <= innerWidth && document.querySelector('button').getBoundingClientRect().width > 0`);
      const resized = await evaluate(`(async () => {
        const nodes = [...document.querySelectorAll('h1,p,a,button,input:not([type="hidden"]),label')];
        const original = nodes.map(el => ({el, style: el.getAttribute('style'), size: parseFloat(getComputedStyle(el).fontSize), height: parseFloat(getComputedStyle(el).lineHeight)}));
        try {
          for (const {el, size, height} of original) {
            el.style.fontSize = (size * 2) + 'px';
            if (Number.isFinite(height)) el.style.lineHeight = (height * 2) + 'px';
          }
          await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
          return nodes.length > 0 && document.documentElement.scrollWidth <= innerWidth && nodes.every(el => {
            const rect = el.getBoundingClientRect();
            return rect.width === 0 || (rect.left >= -0.5 && rect.right <= innerWidth + 0.5 && el.scrollWidth <= el.clientWidth + 1);
          });
        } finally {
          for (const {el, style} of original) {
            if (style === null) el.removeAttribute('style'); else el.setAttribute('style', style);
          }
        }
      })()`);
      checks.text_resize = checks.text_resize && resized;
    }
    await passwordSubmit('incorrect-test-password');
    checks.invalid_correction = await evaluate(`document.querySelector('#sign-in-error')?.textContent.trim() === ${literal('identity.login.credential_failure')} && document.querySelector('#password').value === ''`);
    await passwordSubmit(input.input.password);
    checks.password = await hasTitle('identity.session.protected.title');
    await navigation(() => cdp('Page.reload'));
    checks.protected_reload = await hasTitle('identity.session.protected.title') && await evaluate(`fetch('/session/protected').then(r => r.status === 200)`);
    checks.unfinished = await evaluate(`Promise.all(['/checkout','/assessment','/health','/support'].map(path => fetch(path).then(r => [401,404].includes(r.status)))).then(values => values.every(Boolean))`);
    const {cookies: priorCookies} = await cdp('Network.getCookies', {urls: [base]});
    await navigation(() => evaluate(`document.querySelector('#session-logout').requestSubmit()`));
    checks.logout = await hasTitle('identity.session.logout.confirmed.title');
    await cdp('Network.setCookies', {cookies: priorCookies.map(cookie => ({name: cookie.name, value: cookie.value, url: base, path: cookie.path, secure: cookie.secure, httpOnly: cookie.httpOnly, sameSite: cookie.sameSite, ...(cookie.expires > 0 ? {expires: cookie.expires} : {})}))});
    await navigation(() => cdp('Page.navigate', {url: `${base}/session/protected?locale=${input.locale}`}));
    checks.stale_cookie = await evaluate(`document.querySelector('#sign-in-error')?.textContent.trim() === ${literal('identity.session.reauthentication_required')} && !!document.querySelector('#password-login')`);
    await navigation(() => evaluate(`document.querySelector('a[href="/login/magic?locale=${input.locale}"]').click()`));
    const operation = await evaluate(`document.querySelector('[name="operation_id"]').value`);
    operations.push(operation);
    await evaluate(`document.querySelector('[name="email"]').value=${JSON.stringify(input.input.email)}`);
    await navigation(() => evaluate(`document.querySelector('#magic-login-request').requestSubmit()`));
    checks.magic_request = await hasTitle('identity.magic.request.result.title');
    const response = await fetch(`${base}/__well134/delivery?${new URLSearchParams({operation})}`);
    if (!response.ok) throw new Error('browser.protocol');
    const {proof} = await response.json();
    const confirmation = `${base}/login/magic/confirm?${new URLSearchParams({proof, locale: input.locale})}`;
    const head = await fetch(confirmation, {method: 'HEAD'});
    await navigation(() => cdp('Page.navigate', {url: confirmation}));
    checks.passive_confirmation = head.status === 200 && await hasTitle('identity.magic.confirm.title');
    await navigation(() => evaluate(`document.querySelector('#magic-login-confirmation').requestSubmit()`));
    checks.magic_sign_in = await hasTitle('identity.session.protected.title');
    await navigation(() => evaluate(`document.querySelector('#session-logout').requestSubmit()`));
    await navigation(() => cdp('Page.navigate', {url: confirmation}));
    await navigation(() => evaluate(`document.querySelector('#magic-login-confirmation').requestSubmit()`));
    checks.magic_replay = await hasTitle('identity.magic.confirm.unavailable.title');
    await navigation(() => evaluate(`document.querySelector('a[href="/login/magic?locale=${input.locale}"]').click()`));
    await navigation(() => evaluate(`document.querySelector('a[href="/login?locale=${input.locale}"]').click()`));
    await passwordSubmit(input.input.password);
    checks.recovery = await hasTitle('identity.session.protected.title');
  } else if (input.mode === 'ordinary_email_change') {
    const packet = JSON.parse(readFileSync('docs/delivery/content-evidence/copy/evidence/FP001_PRIMARY_EMAIL_CHANGE_PHASE9_BROWSER_COPY_APPROVED_v0.1.1.json', 'utf8'));
    const copy = key => JSON.stringify(packet.copy_items.find(item => item.semantic_key === `identity.change_email.${key}`)[input.locale]);
    const title = key => evaluate(`document.querySelector('h1')?.textContent.trim() === ${copy(key)}`);
    const path = `/primary-email-change?locale=${input.locale}`;
    const submit = selector => navigation(() => evaluate(`document.querySelector(${JSON.stringify(selector)}).requestSubmit()`));
    const signIn = async email => {
      await evaluate(`document.querySelector('#email').value=${JSON.stringify(email)}; document.querySelector('#password').value=${JSON.stringify(input.password)};`);
      await submit('#password-login');
    };

    await navigation(() => cdp('Page.navigate', {url: loginUrl.toString()}));
    await signIn(input.email);
    await navigation(() => evaluate(`document.querySelector('a[href="${path}"]').click()`));
    checks.entry = await title('start.title') && await evaluate(`document.documentElement.lang === ${JSON.stringify(input.locale)}`);
    checks.stylesheet = await evaluate(`document.querySelector('link[rel="stylesheet"]')?.sheet?.cssRules.length > 0`);
    checks.accessible_form = await evaluate(`!!document.querySelector('main section[aria-labelledby="primary-email-change-heading"]') && !!document.querySelector('label[for="email-change-target"]') && !!document.querySelector('input[name="_csrf_token"]')`);
    for (let tab = 0; tab < 6 && !(await evaluate(`document.activeElement.id === 'email-change-target'`)); tab++) {
      await cdp('Input.dispatchKeyEvent', {type: 'keyDown', key: 'Tab', code: 'Tab', windowsVirtualKeyCode: 9});
      await cdp('Input.dispatchKeyEvent', {type: 'keyUp', key: 'Tab', code: 'Tab', windowsVirtualKeyCode: 9});
    }
    checks.keyboard_focus = await evaluate(`document.activeElement.id === 'email-change-target' && document.activeElement.matches(':focus-visible') && parseFloat(getComputedStyle(document.activeElement).outlineWidth) >= 2`);
    await cdp('Emulation.setEmulatedMedia', {features: [{name: 'prefers-reduced-motion', value: 'reduce'}]});
    checks.reduced_motion = await evaluate(`matchMedia('(prefers-reduced-motion: reduce)').matches && document.getAnimations().length === 0`);
    await cdp('Emulation.setDeviceMetricsOverride', {width: 320, height: 900, deviceScaleFactor: 1, mobile: true});
    checks.reflow = await evaluate(`document.documentElement.scrollWidth <= innerWidth`);
    checks.text_resize = await evaluate(`(() => {
      const nodes = [...document.querySelectorAll('h1, p, a, label, button, dd, dt')];
      const styles = nodes.map(node => ({node, size: parseFloat(getComputedStyle(node).fontSize), line: parseFloat(getComputedStyle(node).lineHeight)}));
      try {
        for (const {node, size, line} of styles) {
          node.style.fontSize = (size * 2) + 'px';
          if (Number.isFinite(line)) node.style.lineHeight = (line * 2) + 'px';
        }
        return document.documentElement.scrollWidth <= innerWidth && nodes.every(node => node.scrollHeight <= node.clientHeight + 1);
      } finally { for (const {node} of styles) node.removeAttribute('style'); }
    })()`);
    await cdp('Emulation.clearDeviceMetricsOverride');
    await evaluate(`document.querySelector('#email-change-target').value=${JSON.stringify(input.target)}; document.querySelector('[name="operation_id"]').value=${JSON.stringify(input.operation_id)};`);
    await submit('#email-change-request');
    checks.requested = await evaluate(`document.querySelector('[role="status"]')?.textContent.trim() === ${copy('request.neutral')}`);
    await evaluate(`document.querySelector('#email-change-password').value=${JSON.stringify(input.password)};`);
    await submit('#email-change-advance');
    checks.pending = await title('pending.title');
    const response = await fetch(`${base}/__well156/${input.operation_id}`);
    const {proof} = await response.json();
    const query = new URLSearchParams({locale: input.locale, proof});
    await navigation(() => cdp('Page.navigate', {url: `${base}/primary-email-change/confirmation?${query}`}));
    checks.confirm = await title('confirm.title');
    await submit('#phase9-email-change-confirmation');
    checks.confirmed = await title('confirmed.title') && await evaluate(`!document.querySelector('input[name="proof"]')`);
    await navigation(() => evaluate(`document.querySelector('a[href="${path}"]').click()`));
    await evaluate(`document.querySelector('#email-change-password').value=${JSON.stringify(input.password)};`);
    await submit('#email-change-advance');
    checks.applied = await title('applied.title');
    await navigation(() => evaluate(`document.querySelector('a[href="/login?locale=${input.locale}"]').click()`));
    await signIn(input.target);
    checks.fresh_sign_in = await evaluate(`location.pathname === '/session/protected'`);
  } else if (input.mode === 'ordinary_reset') {
    const approved = JSON.parse(readFileSync('docs/development/fixtures/well136-c02-v0.1.json', 'utf8'));
    const text = key => approved.entries[key][input.locale].text;
    const literal = key => JSON.stringify(text(key));
    const title = key => evaluate(`document.documentElement.lang === ${JSON.stringify(input.locale)} && document.querySelector('h1')?.textContent.trim() === ${literal(key)}`);
    const snapshot = () => fetch(`${base}/__well136/snapshot`).then(r => r.json());
    const login = async password => {
      await evaluate(`document.querySelector('#email').value=${JSON.stringify(input.email)}; document.querySelector('#password').value=${JSON.stringify(password)};`);
      await navigation(() => evaluate(`document.querySelector('#password-login').requestSubmit()`));
    };
    checkpoint = 'reset.public_entry';
    await navigation(() => cdp('Page.navigate', {url: `${base}/?locale=${input.locale}`}));
    checks.public_entry = await evaluate(`!!document.querySelector('a[href="/login?locale=${input.locale}"]')`);
    await navigation(() => evaluate(`document.querySelector('a[href="/login?locale=${input.locale}"]').click()`));
    checkpoint = 'reset.prior_login';
    await login(input.password);
    checks.prior_session = await evaluate(`location.pathname === '/session/protected'`);
    const {cookies: oldCookies} = await cdp('Network.getCookies', {urls: [base]});
    checkpoint = 'reset.request_entry';
    await navigation(() => cdp('Page.navigate', {url: loginUrl.toString()}));
    checks.forgot_password = await evaluate(`document.querySelector('a[href="/password/reset?locale=${input.locale}"]')?.textContent.trim() === ${literal('identity.login.forgot_password')}`);
    await navigation(() => evaluate(`document.querySelector('a[href="/password/reset?locale=${input.locale}"]').click()`));
    checkpoint = 'reset.request_layout';
    checks.approved_request = await title('identity.password_reset.request.title');
    checks.labels = await evaluate(`document.querySelector('label[for="email"]')?.textContent.trim() === ${literal('identity.login.email.label')} && !!document.querySelector('[name="_csrf_token"]') && document.querySelector('#email').autocomplete === 'email'`);
    checks.stylesheet = await evaluate(`document.querySelector('link[rel="stylesheet"]')?.sheet?.cssRules.length > 0`);
    checks.responsive = true;
    checks.text_resize = true;
    await cdp('Emulation.setEmulatedMedia', {features: [{name: 'prefers-reduced-motion', value: 'reduce'}]});
    checks.reduced_motion = await evaluate(`matchMedia('(prefers-reduced-motion: reduce)').matches && document.getAnimations().length === 0`);
    for (const width of [320, 375, 768, 1280, 1920]) {
      await cdp('Emulation.setDeviceMetricsOverride', {width, height: 900, deviceScaleFactor: 1, mobile: width < 768});
      checks.responsive &&= await evaluate(`document.documentElement.scrollWidth <= innerWidth`);
      checks.text_resize &&= await evaluate(`(async () => {
        const nodes = [...document.querySelectorAll('h1,p,a,button,input:not([type="hidden"]),label')];
        const original = nodes.map(el => ({el, font: el.style.fontSize, line: el.style.lineHeight, size: parseFloat(getComputedStyle(el).fontSize), height: parseFloat(getComputedStyle(el).lineHeight)}));
        try {
          for (const {el, size, height} of original) { el.style.fontSize = (size * 2) + 'px'; if (Number.isFinite(height)) el.style.lineHeight = (height * 2) + 'px'; }
          await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
          globalThis.resetResizeFailures = nodes.filter(el => { const r=el.getBoundingClientRect(); return r.width > 0 && !(r.left >= -0.5 && r.right <= innerWidth + 0.5 && el.scrollWidth <= el.clientWidth + 1 && el.scrollHeight <= el.clientHeight + 1); }).map(el=>({tag:el.tagName,id:el.id,width:innerWidth,clientWidth:el.clientWidth,scrollWidth:el.scrollWidth,clientHeight:el.clientHeight,scrollHeight:el.scrollHeight}));
          return document.documentElement.scrollWidth <= innerWidth && globalThis.resetResizeFailures.length === 0;
        } finally { for (const {el, font, line} of original) { el.style.fontSize = font; el.style.lineHeight = line; } }
      })()`);
      if (!checks.text_resize) checks.resize_diagnostics = await evaluate(`globalThis.resetResizeFailures`);
    }
    for (let tab = 0; tab < 6 && !(await evaluate(`document.activeElement.id === 'email'`)); tab++) {
      await cdp('Input.dispatchKeyEvent', {type: 'keyDown', key: 'Tab', code: 'Tab', windowsVirtualKeyCode: 9});
      await cdp('Input.dispatchKeyEvent', {type: 'keyUp', key: 'Tab', code: 'Tab', windowsVirtualKeyCode: 9});
    }
    checks.keyboard_focus = await evaluate(`document.activeElement.id === 'email' && document.activeElement.matches(':focus-visible') && parseFloat(getComputedStyle(document.activeElement).outlineWidth) >= 2`);
    checkpoint = 'reset.request_csrf';
    checks.csrf = await evaluate(`fetch('/password/reset', {method:'POST', headers:{'content-type':'application/x-www-form-urlencoded'}, body:new URLSearchParams({locale:${JSON.stringify(input.locale)}, email:${JSON.stringify(input.email)}, operation_id:crypto.randomUUID()})}).then(r=>r.status===403)`);
    let neutral;
    for (const email of [`unknown-${randomUUID()}@example.test`, input.email]) {
      checkpoint = 'reset.request_submit';
      if (neutral) await navigation(() => cdp('Page.navigate', {url:`${base}/password/reset?locale=${input.locale}`}));
      operations.push(await evaluate(`document.querySelector('[name="operation_id"]').value`));
      await evaluate(`document.querySelector('#email').value=${JSON.stringify(email)}`);
      await navigation(() => evaluate(`document.querySelector('#password-reset-request').requestSubmit()`));
      const result = await evaluate(`JSON.stringify([document.querySelector('h1')?.textContent.trim(),document.querySelector('[role="status"]')?.textContent.trim()])`);
      checks.neutral_request = !neutral || neutral === result;
      neutral = result;
      checks.accepted_copy = await title('identity.password_reset.request.accepted.title') && await evaluate(`document.querySelector('[role="status"]')?.textContent.trim() === ${literal('identity.password_reset.request.accepted.body')}`);
    }
    checkpoint = 'reset.delivery';
    const delivered = await fetch(`${base}/__well136/delivery?${new URLSearchParams({operation:operations.at(-1)})}`).then(r=>r.json());
    checks.real_delivery = typeof delivered.proof === 'string';
    checkpoint = 'reset.confirm_entry';
    const url = `${base}/password/reset/confirm?${new URLSearchParams({proof:delivered.proof,locale:input.locale})}`;
    const before = JSON.stringify(await snapshot());
    const head = await fetch(url,{method:'HEAD'});
    await fetch(url,{headers:{purpose:'prefetch'}});
    await navigation(() => cdp('Page.navigate',{url}));
    checks.scanner_safe = head.status === 200 && JSON.stringify(await snapshot()) === before;
    checks.confirmation_copy = await title('identity.password_reset.confirm.title') && await evaluate(`document.querySelector('#reset-instructions')?.textContent.trim() === ${literal('identity.password_reset.confirm.body')} && document.querySelector('label[for="password"]')?.textContent.trim() === ${literal('identity.password_reset.confirm.password.label')}`);
    checkpoint = 'reset.confirm_submit';
    operations.push(await evaluate(`document.querySelector('[name="operation_id"]').value`));
    await evaluate(`document.querySelector('#password').value=${JSON.stringify(input.replacement)}`);
    await navigation(() => evaluate(`document.querySelector('#password-reset-confirmation').requestSubmit()`));
    checks.completed_copy = await title('identity.password_reset.confirm.complete.title') && await evaluate(`document.querySelector('[role="status"]')?.textContent.trim() === ${literal('identity.password_reset.confirm.complete.body')}`);
    checks.no_automatic_login = await evaluate(`fetch('/session/protected').then(r=>r.status===401)`);
    checks.proof_not_rendered = await evaluate(`!document.querySelector('[name="proof"]') && !document.body.textContent.includes(${JSON.stringify(delivered.proof)})`);
    const reset = await snapshot();
    checks.persisted_reset = reset.credential_version === 2 && reset.current_proofs === 0 && reset.active_sessions === 0;
    checkpoint = 'reset.session_revocation';
    await cdp('Network.setCookies',{cookies:oldCookies.map(cookie=>({name:cookie.name,value:cookie.value,url:base,path:cookie.path,secure:cookie.secure,httpOnly:cookie.httpOnly,sameSite:cookie.sameSite,...(cookie.expires>0?{expires:cookie.expires}:{})}))});
    checks.stale_session_denied = await evaluate(`fetch('/session/protected').then(r=>r.status===401)`);
    checkpoint = 'reset.replay_submit';
    await navigation(() => cdp('Page.navigate',{url}));
    operations.push(await evaluate(`document.querySelector('[name="operation_id"]').value`));
    await evaluate(`document.querySelector('#password').value=${JSON.stringify(input.replacement)}`);
    await navigation(() => evaluate(`document.querySelector('#password-reset-confirmation').requestSubmit()`));
    checks.replay_denied = await title('identity.password_reset.confirm.unavailable.title');
    checkpoint = 'reset.retry_navigation';
    await navigation(() => evaluate(`document.querySelector('a[href="/password/reset?locale=${input.locale}"]').click()`));
    checks.retry_navigation = await title('identity.password_reset.request.title');
    await navigation(() => evaluate(`document.querySelector('a[href="/login?locale=${input.locale}"]').click()`));
    checkpoint = 'reset.old_login';
    await login(input.password);
    checks.old_password_denied = await evaluate(`!!document.querySelector('#sign-in-error')`);
    checkpoint = 'reset.fresh_login';
    await login(input.replacement);
    checks.fresh_sign_in = await evaluate(`location.pathname==='/session/protected' && fetch('/session/protected').then(r=>r.status===200)`);
    const newRequest = async () => {
      checkpoint = 'reset.new_request';
      await navigation(() => cdp('Page.navigate',{url:`${base}/password/reset?locale=${input.locale}`}));
      const operation = await evaluate(`document.querySelector('[name="operation_id"]').value`);
      operations.push(operation);
      await evaluate(`document.querySelector('#email').value=${JSON.stringify(input.email)}`);
      await navigation(() => evaluate(`document.querySelector('#password-reset-request').requestSubmit()`));
      return operation;
    };
    const expiringOperation = await newRequest();
    checkpoint = 'reset.expired_link';
    const expiring = await fetch(`${base}/__well136/delivery?${new URLSearchParams({operation:expiringOperation})}`).then(r=>r.json());
    await fetch(`${base}/__well136/expire?${new URLSearchParams({operation:expiringOperation})}`);
    await navigation(() => cdp('Page.navigate',{url:`${base}/password/reset/confirm?${new URLSearchParams({proof:expiring.proof,locale:input.locale})}`}));
    operations.push(await evaluate(`document.querySelector('[name="operation_id"]').value`));
    await evaluate(`document.querySelector('#password').value='expired attempt replacement'`);
    await navigation(() => evaluate(`document.querySelector('#password-reset-confirmation').requestSubmit()`));
    checks.expired_link = await title('identity.password_reset.confirm.unavailable.title');
    const withdrawnOperation = await newRequest();
    checkpoint = 'reset.withdrawal';
    await fetch(`${base}/__well136/withdraw`);
    const held = await fetch(`${base}/__well136/delivery?${new URLSearchParams({operation:withdrawnOperation})}`).then(r=>r.json());
    checks.withdrawal_blocks_delivery = held.held === true && !held.proof;
    checks.failed_attempts_preserve_credential = (await snapshot()).credential_version === 2;
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
  const entry = input.mode === 'entry';
  await navigation(() => cdp('Page.navigate', { url: `${base}${entry ? '/' : '/register'}?locale=${input.locale}` }));
  if (entry) {
    checks.root_entry = await evaluate(`location.pathname === '/' && document.documentElement.lang === ${JSON.stringify(input.locale)} && !!document.querySelector('#registration-form')`);
    const other = input.locale === 'af' ? 'en' : 'af';
    await navigation(() => evaluate(`document.querySelector('nav a[lang="${other}"]').click()`));
    checks.locale_switch = await evaluate(`document.documentElement.lang === ${JSON.stringify(other)}`);
    await navigation(() => evaluate(`document.querySelector('nav a[lang="${input.locale}"]').click()`));
    checks.locale_switch &&= await evaluate(`document.documentElement.lang === ${JSON.stringify(input.locale)}`);
    await cdp('Emulation.setEmulatedMedia', {features: [{name: 'prefers-reduced-motion', value: 'reduce'}]});
    checks.responsive = true;
    for (const width of [320, 375, 768, 1280, 1920]) {
      await cdp('Emulation.setDeviceMetricsOverride', {width, height: 800, deviceScaleFactor: 1, mobile: false});
      checks.responsive &&= await evaluate('document.documentElement.scrollWidth <= innerWidth');
    }
    await cdp('Emulation.setDeviceMetricsOverride', {width: 1280, height: 800, deviceScaleFactor: 1, mobile: false});
    checks.reduced_motion = await evaluate(`matchMedia('(prefers-reduced-motion: reduce)').matches && document.getAnimations().length === 0`);
    checks.stylesheet_loaded = await evaluate(`document.querySelector('link[rel="stylesheet"]')?.sheet?.cssRules.length > 0`);
    checks.associated_labels = await evaluate(`Array.from(document.querySelectorAll('#registration-form input:not([type="hidden"])')).every(input => input.labels.length > 0)`);
    await evaluate(`document.querySelector('nav a:last-child').focus()`);
    await cdp('Input.dispatchKeyEvent', {type: 'keyDown', key: 'Tab', code: 'Tab', windowsVirtualKeyCode: 9});
    await cdp('Input.dispatchKeyEvent', {type: 'keyUp', key: 'Tab', code: 'Tab', windowsVirtualKeyCode: 9});
    checks.keyboard_focus = await evaluate(`document.activeElement.name === 'registration[first_name]' && document.activeElement.matches(':focus-visible') && parseFloat(getComputedStyle(document.activeElement).outlineWidth) >= 2`);
    await evaluate(`document.querySelector('#registration-form').noValidate = true`);
    await navigation(() => evaluate(`document.querySelector('#registration-form').requestSubmit()`));
    checks.validation_errors = await evaluate(`document.documentElement.lang === ${JSON.stringify(input.locale)} && document.querySelector('[name="registration[first_name]"]').getAttribute('aria-invalid') === 'true' && document.querySelector('[name="registration[first_name]"]').getAttribute('aria-describedby') === 'registration-first-name-error' && document.querySelector('[name="registration[password]"]').value === '' && !!document.querySelector('[role="alert"]')`);
  }
  const registry = JSON.parse(readFileSync('docs/delivery/content-evidence/copy/COPY_REGISTRY.json', 'utf8'));
  const text = (key, locale) => registry.entries.find(entry => entry.key === key)[locale].text.replaceAll('{{platform_name}}', input.platform_name);
  const registrationKeys = ['public.entry.launch.title', 'public.entry.launch.body', 'public.entry.safety.body', 'identity.registration.title', 'identity.registration.intro', 'identity.registration.first_name.label', 'identity.registration.surname.label', 'identity.registration.email.label', 'identity.registration.password.label', 'identity.registration.preferred_language.label', 'identity.registration.preferred_language.help', 'identity.registration.age_confirmation', 'legal.shared.document_language_disclosure', 'identity.registration.terms_acceptance', 'identity.registration.terms_link', 'identity.registration.privacy_presentation', 'identity.registration.privacy_link', 'identity.registration.privacy_acceptance', 'identity.registration.submit'];
  const pendingKeys = ['identity.verification.pending.title', 'identity.verification.pending.explanation', 'identity.verification.pending.check_inbox', 'identity.verification.pending.address_label', 'identity.verification.pending.not_arrived.title', 'identity.verification.pending.not_arrived.body', 'identity.verification.resend.action', 'identity.verification.pending.access_limitation', 'identity.verification.pending.browse_public', 'identity.verification.pending.home'];
  const hasCopy = async (keys, locale) => evaluate(`(${JSON.stringify(keys.map(key => text(key, locale)))}).every(text => document.body.innerText.includes(text))`);
  const noFallback = async keys => {
    const other = input.locale === 'af' ? 'en' : 'af';
    const alternatives = keys.filter(key => text(key, other) !== text(key, input.locale)).map(key => text(key, other));
    // Exact rendered text nodes keep a short AF label such as "Van" from
    // matching part of another word or an opaque CSRF/attribute value.
    return evaluate(`(() => { const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT); const texts = []; while (walker.nextNode()) { const node = walker.currentNode; if (!['SCRIPT', 'STYLE'].includes(node.parentElement.tagName)) texts.push(node.textContent.trim()); } return document.documentElement.lang === ${JSON.stringify(input.locale)} && (${JSON.stringify(alternatives)}).every(text => !texts.includes(text)); })()`);
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
  if (input.mode === 'spine' || entry) {
    checks['spine.registration'] = true;
    const delivered = await evaluate(`fetch('/__proof/delivery?' + new URLSearchParams({operation: ${JSON.stringify(resendOperation)}})).then(r => { if (!r.ok) throw new Error('delivery'); return r.json(); })`);
    checks['spine.delivery'] = true;
    const verifyUrl = `${base}/verification/confirm?${new URLSearchParams({proof: delivered.proof, locale: input.locale})}`;
    await navigation(() => cdp('Page.navigate', {url: verifyUrl}));
    checks.explicit_verification = await evaluate(`!!document.querySelector('form[action="/verification/confirm"] [name="_csrf_token"]')`);
    checks['spine.verification_form'] = checks.explicit_verification;
    await navigation(() => evaluate(`document.querySelector('form[action="/verification/confirm"]').requestSubmit()`));
    checks['spine.verification_submitted'] = true;
    if (entry) {
      const fixture = JSON.parse(readFileSync('docs/development/fixtures/p8-07-copy-v1.json', 'utf8'));
      const resultText = state => fixture.entries[`identity.verification.result.${state}.title`][input.locale].text;
      const hasResult = state => evaluate(`document.documentElement.lang === ${JSON.stringify(input.locale)} && document.querySelector('h1').textContent.trim() === ${JSON.stringify(resultText(state))} && !document.querySelector('[name="proof"]') && !document.body.textContent.includes(${JSON.stringify(delivered.proof)})`);
      checks.verified_result = await hasResult('verified');
      await navigation(() => cdp('Page.navigate', {url: verifyUrl}));
      await navigation(() => evaluate(`document.querySelector('form[action="/verification/confirm"]').requestSubmit()`));
      checks.safe_replay = await hasResult('unavailable');
      await navigation(() => evaluate(`document.querySelector('a[href="/register?locale=${input.locale}"]').click()`));
      checks.return_locale = await evaluate(`location.pathname === '/register' && document.documentElement.lang === ${JSON.stringify(input.locale)}`);
      checks.protected_access_denied = await evaluate(`fetch('/session/protected').then(r => r.status === 401)`);
    } else {
    await navigation(() => cdp('Page.navigate', {url: loginUrl.toString()}));
    checks.login_form = await evaluate(`!!document.querySelector('form[action="/login"] [name="_csrf_token"]')`);
    await evaluate(`document.querySelector('[name="email"]').value=${JSON.stringify(input.input.email)}; document.querySelector('[name="password"]').value=${JSON.stringify(input.input.password)};`);
    await navigation(() => evaluate(`document.querySelector('form[action="/login"]').requestSubmit()`));
    checks.protected_access = await evaluate(`location.pathname === '/session/protected'`);
    checks['spine.login_submitted'] = true;
    await navigation(() => cdp('Page.reload'));
    checks.reloaded_access = await evaluate(`location.pathname === '/session/protected' && fetch('/session/protected').then(r => r.status === 200)`);
    }
  }

  }
  checkpoint = undefined;
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
process.stdout.write(JSON.stringify({checks, operations, cleanup, failure, checkpoint}));
process.exit(0);
