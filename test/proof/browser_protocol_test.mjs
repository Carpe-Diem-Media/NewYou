import test from 'node:test';
import assert from 'node:assert/strict';
import { completeNavigation } from './browser_protocol.mjs';

test('a slow browser boot completes before the context command gets its normal deadline', async t => {
  const { createBrowserContext } = await import('./browser_protocol.mjs');
  t.mock.timers.enable({apis: ['setTimeout']});
  const requests = [];
  let ready = false;
  let outcome;
  const call = (method, _params, _session, timeout = 20000) => {
    requests.push({method, timeout});
    if (ready) return Promise.resolve({browserContextId: 'synthetic-context'});
    return new Promise((resolve, reject) => {
      const deadline = setTimeout(() => reject(new Error(`browser.protocol_timeout.${method}`)), timeout);
      setTimeout(() => { clearTimeout(deadline); ready = true; resolve({}); }, 30000);
    });
  };
  const context = createBrowserContext(call);
  context.then(value => { outcome = value; }, error => { outcome = error.message; });
  t.mock.timers.tick(20000);
  await Promise.resolve();
  assert.equal(outcome, undefined, 'cold startup consumed the context command deadline');
  t.mock.timers.tick(10000);
  assert.deepEqual(await context, {browserContextId: 'synthetic-context'});
  assert.deepEqual(requests, [
    {method: 'Browser.getVersion', timeout: 40000},
    {method: 'Target.createBrowserContext', timeout: 20000}
  ]);
});

test('an unresponsive startup fails within its bound and never creates a context', async t => {
  const { createBrowserContext } = await import('./browser_protocol.mjs');
  t.mock.timers.enable({apis: ['setTimeout']});
  const methods = [];
  const context = createBrowserContext((method, _params, _session, timeout) => {
    methods.push(method);
    return new Promise((_, reject) => {
      setTimeout(() => reject(new Error(`browser.protocol_timeout.${method}`)), timeout);
    });
  });
  const rejected = assert.rejects(context, {message: 'browser.protocol_timeout.Browser.getVersion'});
  t.mock.timers.tick(40000);
  await rejected;
  assert.deepEqual(methods, ['Browser.getVersion']);
});

test('late readiness leaves a bounded context deadline and reserves shutdown time', async t => {
  const { boundedProtocol, createBrowserContext } = await import('./browser_protocol.mjs');
  t.mock.timers.enable({apis: ['setTimeout', 'Date']});
  const requests = [];
  const call = boundedProtocol((method, _params, _session, timeout = 20000) => {
    requests.push({method, timeout});
    if (method === 'Browser.close') return Promise.resolve();
    return new Promise((resolve, reject) => {
      const deadline = setTimeout(() => reject(new Error(`browser.protocol_timeout.${method}`)), timeout);
      if (method === 'Browser.getVersion') {
        setTimeout(() => { clearTimeout(deadline); resolve({}); }, 39000);
      }
    });
  }, {now: () => Date.now()});
  let failed = false;
  const context = createBrowserContext(call);
  const rejected = assert.rejects(context, {message: 'browser.protocol_timeout.Target.createBrowserContext'})
    .then(() => { failed = true; });
  t.mock.timers.tick(39000);
  await Promise.resolve();
  t.mock.timers.tick(1000);
  await new Promise(setImmediate);
  assert.equal(failed, true, 'context creation outlived the shared browser-work deadline');
  await rejected;
  await call('Browser.close', {}, undefined, 20000);
  assert.deepEqual(requests, [
    {method: 'Browser.getVersion', timeout: 40000},
    {method: 'Target.createBrowserContext', timeout: 1000},
    {method: 'Browser.close', timeout: 4000}
  ]);
});

test('readiness never hides a failed context command', async () => {
  const { createBrowserContext } = await import('./browser_protocol.mjs');
  await assert.rejects(createBrowserContext(method => {
    if (method === 'Browser.getVersion') return Promise.resolve({});
    return Promise.reject(new Error('browser.protocol'));
  }), {message: 'browser.protocol'});
});

test('completed navigation tolerates only execution-context loss from submission', async () => {
  await assert.doesNotReject(completeNavigation(
    async () => { throw new Error('browser.context_lost'); },
    Promise.resolve()
  ));
});

test('a failed submission is not hidden by a load event', async () => {
  await assert.rejects(
    completeNavigation(async () => { throw new Error('browser.evaluation'); }, Promise.resolve()),
    { message: 'browser.evaluation' }
  );
});

test('context loss without navigation still fails', async () => {
  const loaded = Promise.reject(new Error('browser.navigation_timeout'));
  loaded.catch(() => {});
  await assert.rejects(
    completeNavigation(async () => { throw new Error('browser.context_lost'); }, loaded),
    { message: 'browser.navigation_timeout' }
  );
});

test('browser exit settles a close request whose protocol reply was lost', async () => {
  const { settleBrowserExit } = await import('./browser_protocol.mjs');
  const pending = new Map();
  let rejectClose;
  const close = new Promise((_, reject) => { rejectClose = reject; });
  close.catch(() => {});
  const timer = setTimeout(() => rejectClose(new Error('browser.protocol_timeout')), 20000);
  timer.unref();
  pending.set(7, { reject: rejectClose, timer });
  try {
    settleBrowserExit(pending);
    assert.equal(pending.size, 0);
    await assert.rejects(close, { message: 'browser.stopped' });
  } finally {
    clearTimeout(timer);
  }
});

test('context loss is classified without exposing raw protocol diagnostics', async () => {
  const { protocolError } = await import('./browser_protocol.mjs');
  assert.equal(protocolError({code: -32000, message: 'Execution context was destroyed.'}).message,
    'browser.context_lost');
  assert.equal(protocolError({code: -32000, message: 'Cannot find context with specified id'}).message,
    'browser.context_lost');
  assert.equal(protocolError({code: -32000, message: 'synthetic-secret-canary'}).message,
    'browser.protocol');
});

test('context loss waits for the destination load rather than granting success', async () => {
  let release;
  const loaded = new Promise(resolve => { release = resolve; });
  let completed = false;
  const navigation = completeNavigation(
    async () => { throw new Error('browser.context_lost'); }, loaded
  ).then(() => { completed = true; });
  await new Promise(setImmediate);
  assert.equal(completed, false);
  release();
  await navigation;
  assert.equal(completed, true);
});

test('failure diagnostics expose only fixed codes', async () => {
  const { boundedFailureCode } = await import('./browser_protocol.mjs');
  assert.equal(boundedFailureCode(new Error('browser.protocol_timeout')), 'browser.protocol_timeout');
  assert.equal(boundedFailureCode(new Error('synthetic-secret-canary')), 'browser.unclassified');
});

test('cleared execution contexts settle only evaluations in the affected session', async () => {
  const { settleContextLoss } = await import('./browser_protocol.mjs');
  const rejected = [];
  const pending = new Map([
    [1, {method: 'Runtime.evaluate', sessionId: 'page-a', reject: error => rejected.push(error.message)}],
    [2, {method: 'Page.navigate', sessionId: 'page-a', reject: () => assert.fail('navigation rejected')}],
    [3, {method: 'Runtime.evaluate', sessionId: 'page-b', reject: () => assert.fail('other page rejected')}]
  ]);
  settleContextLoss(pending, 'page-a');
  assert.deepEqual(rejected, ['browser.context_lost']);
  assert.deepEqual([...pending.keys()], [2, 3]);
});

test('method-level timeout diagnostics remain bounded', async () => {
  const { boundedFailureCode } = await import('./browser_protocol.mjs');
  assert.equal(boundedFailureCode(new Error('browser.protocol_timeout.Runtime.evaluate')),
    'browser.protocol_timeout.Runtime.evaluate');
  assert.equal(boundedFailureCode(new Error('browser.protocol_timeout.Browser.getVersion')),
    'browser.protocol_timeout.Browser.getVersion');
  assert.equal(boundedFailureCode(new Error('browser.protocol_timeout.synthetic-secret-canary')),
    'browser.unclassified');
});
