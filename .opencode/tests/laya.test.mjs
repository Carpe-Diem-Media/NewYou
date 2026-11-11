import test from 'node:test';
import assert from 'node:assert/strict';
import { classify } from '../lib/laya.mjs';

const reply = (choice, confidence = 0.8) => ({ ok: true, json: async () => ({answers: {task_type: {choice, answer_confidence: confidence}}}) });

test('accepts an allowlisted English task and only returns allowed fields', async () => {
  for (const summary of ['fix software bug', 'review code']) {
    const result = await classify(summary, async (url, options) => {
      assert.equal(url, 'http://127.0.0.1:8000/v1/systemone');
      assert.equal(options.redirect, 'error');
      assert.equal(JSON.parse(options.body).state, summary);
      return reply('coding');
    });
    assert.deepEqual(result, {status:'ok', classification:'coding', confidence:0.8, advisory_only:true});
  }
});

test('rejects arbitrary or potentially sensitive text before any request', async () => {
  for (const summary of ['maak sagteware fout reg', 'token=secret', 'a'.repeat(301), '', 'fix bug for alice@example.com']) {
    let sent = false;
    const result = await classify(summary, async () => { sent = true; });
    assert.equal(result.status, 'invalid_input');
    assert.equal(sent, false);
  }
});

test('rejects invalid model labels and confidence', async () => {
  for (const data of [reply('READY'), reply('coding', 9), reply('coding', 'high')]) {
    assert.equal((await classify('fix software bug', async () => data)).status, 'invalid_response');
  }
});

test('handles refusal, timeout and HTTP errors as unavailable', async () => {
  for (const fetcher of [async () => { throw Error('ECONNREFUSED'); }, async () => { throw DOMException('timeout','TimeoutError'); }, async () => ({ok:false})]) {
    assert.deepEqual(await classify('fix software bug', fetcher), {status:'unavailable', advisory_only:true});
  }
});

test('cancels a delayed request when its timeout signal fires', async () => {
  const original = AbortSignal.timeout;
  AbortSignal.timeout = () => original(10);
  try {
    const result = await classify('fix software bug', async (_url, {signal}) => {
      await new Promise((_, reject) => signal.addEventListener('abort', () => reject(signal.reason)));
    });
    assert.equal(result.status, 'unavailable');
  } finally {
    AbortSignal.timeout = original;
  }
});

test('handles malformed JSON and omits unexpected response fields', async () => {
  assert.equal((await classify('review code', async () => ({ok:true, json:async () => {throw Error('bad json')}}))).status, 'unavailable');
  const result = await classify('review code', async () => ({ok:true,json:async () => ({answers:{task_type:{choice:'coding',answer_confidence:0.8,extra:'ignored'}},extra:'ignored'})}));
  assert.deepEqual(result,{status:'ok',classification:'coding',confidence:0.8,advisory_only:true});
});

test('handles a real refused loopback connection', async () => {
  const { createServer } = await import('node:net');
  const server = createServer();
  await new Promise((resolve, reject) => server.once('error', reject).listen(0, '127.0.0.1', resolve));
  const port = server.address().port;
  await new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
  const result = await classify('fix software bug', (_endpoint, options) => fetch(`http://127.0.0.1:${port}/`, options));
  assert.deepEqual(result, {status:'unavailable', advisory_only:true});
});

test('abstains below the confidence threshold and accepts the boundary', async () => {
  assert.deepEqual(await classify('fix software bug', async () => reply('coding', 0.5999)),
    {status:'uncertain', confidence:0.5999, advisory_only:true});
  assert.deepEqual(await classify('fix software bug', async () => reply('coding', 0.6)),
    {status:'ok', classification:'coding', confidence:0.6, advisory_only:true});
});
