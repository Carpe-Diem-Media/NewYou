import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { boundedFailureCode } from './browser_protocol.mjs';

const driver = readFileSync(new URL('./p8_05_browser.mjs', import.meta.url), 'utf8');
const wrapper = readFileSync(new URL('../support/proof/p8_05_browser.ex', import.meta.url), 'utf8');
const start = "    checkpoint = 'reset.request_layout';";
const end = "    checkpoint = 'reset.request_csrf';";
const block = driver.slice(driver.indexOf(start), driver.indexOf(end, driver.indexOf(start)));
const stages = [
  [0, 'reset.request_layout'], [1, 'reset.request_labels'],
  [2, 'reset.request_stylesheet'], [3, 'reset.request_reduced_motion'],
  [4, 'reset.request_responsive'], [5, 'reset.request_text_resize'],
  [14, 'reset.request_keyboard_focus']
];
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;

// Execute the actual request checks with synthetic evaluators. No browser,
// page content, fixture credentials or application dependencies are needed.
async function failureAt(source, failureIndex) {
  let calls = 0;
  const evaluate = async () => {
    if (calls++ === failureIndex) throw new Error('browser.evaluation');
    return true;
  };
  const result = await new AsyncFunction('evaluate', 'title', 'literal', 'boundedFailureCode', 'cdp', `
    let checkpoint;
    const checks = {};
    try {
      ${source}
      return {checks};
    } catch (error) {
      return {failure: boundedFailureCode(error), checkpoint};
    }
  `)(evaluate, evaluate, () => '"synthetic-label"', boundedFailureCode, async () => ({}));
  assert.equal(calls, failureIndex < 0 ? 16 : failureIndex + 1);
  return result;
}

for (const [index, stage] of stages) {
  test(`evaluation failure identifies ${stage} and stops subsequent checks`, async () => {
    assert.deepEqual(await failureAt(block, index), {
      failure: 'browser.evaluation', checkpoint: stage
    });
  });

  test(`${stage} is accepted by the Elixir diagnostic allowlist`, () => {
    const allowlist = wrapper.match(/@failure_checkpoints ~w\(([\s\S]*?)\)/)[1].trim().split(/\s+/);
    assert.ok(allowlist.includes(stage));
  });
}

test('successful evaluations preserve all existing layout check results', async () => {
  assert.deepEqual(await failureAt(block, -1), {
    checks: {approved_request: true, labels: true, stylesheet: true, responsive: true, text_resize: true, reduced_motion: true, keyboard_focus: true}
  });
});

test('removing any new checkpoint loses failure precision', async () => {
  for (const [index, stage] of stages.slice(1)) {
    const mutant = block.replace(`    checkpoint = '${stage}';\n`, '');
    assert.notEqual(mutant, block, 'checkpoint mutation must change the executed source');
    assert.notEqual((await failureAt(mutant, index)).checkpoint, stage);
  }
});
