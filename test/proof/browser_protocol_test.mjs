import test from 'node:test';
import assert from 'node:assert/strict';
import { completeNavigation } from './browser_protocol.mjs';

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
