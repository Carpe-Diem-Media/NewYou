// Test-only coordination for the existing Chromium proof driver. No page data
// or raw protocol errors cross this boundary.
export async function completeNavigation(action, loaded) {
  // A load can fail before the action settles. Observe rejection immediately,
  // then propagate it below rather than creating an unhandled rejection.
  loaded.catch(() => {});
  try {
    await action();
  } catch (error) {
    if (error.message !== 'browser.context_lost') throw error;
  }
  // Context loss alone never proves navigation. Destination checks still run
  // after the required load event, and all other action failures propagate.
  await loaded;
}

export function settleBrowserExit(pending) {
  for (const waiter of pending.values()) {
    clearTimeout(waiter.timer);
    waiter.reject(new Error('browser.stopped'));
  }
  pending.clear();
}

export function protocolError(error) {
  const lostContext = error.code === -32000 && [
    'Execution context was destroyed.',
    'Cannot find context with specified id'
  ].includes(error.message);
  return new Error(lostContext ? 'browser.context_lost' : 'browser.protocol');
}

export function boundedFailureCode(error) {
  const codes = new Set([
    'browser.unavailable', 'browser.protocol', 'browser.protocol_timeout',
    'browser.context_lost', 'browser.evaluation', 'browser.navigation_timeout',
    'browser.stopped'
  ]);
  const methods = [
    'Target.createBrowserContext', 'Target.createTarget', 'Target.attachToTarget',
    'Page.enable', 'Runtime.enable', 'Runtime.evaluate', 'Page.navigate',
    'Target.disposeBrowserContext', 'Browser.close'
  ];
  for (const method of methods) codes.add(`browser.protocol_timeout.${method}`);
  return codes.has(error?.message) ? error.message : 'browser.unclassified';
}

export function settleContextLoss(pending, sessionId) {
  for (const [id, waiter] of pending) {
    if (waiter.method === 'Runtime.evaluate' && waiter.sessionId === sessionId) {
      clearTimeout(waiter.timer);
      pending.delete(id);
      waiter.reject(new Error('browser.context_lost'));
    }
  }
}
