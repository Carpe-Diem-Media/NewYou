// Only generic phrases are sent to the local classifier. Never accept free-form
// project information, even when the caller says it is safe.
const summaries = new Set([
  'fix software bug', 'implement software feature', 'review code',
  'research a technical question', 'write documentation', 'other task',
]);
const endpoint = 'http://127.0.0.1:8000/v1/systemone';
const labels = new Set(['coding', 'research', 'writing', 'other']);

export async function classify(summary, send = fetch) {
  if (typeof summary !== 'string' || summary.length > 300 || !summaries.has(summary)) {
    return {status:'invalid_input', advisory_only:true};
  }
  try {
    const response = await send(endpoint, {
      method:'POST', redirect:'error', headers:{'Content-Type':'application/json'},
      signal:AbortSignal.timeout(12000),
      body:JSON.stringify({state:summary, questions:{task_type:{type:'choice',
        instructions:'Classify this development task.', criteria:{
          coding:'Software implementation or code review', research:'Research or investigation',
          writing:'Documentation or prose', other:'Other work',
        }}}}),
    });
    if (!response.ok) return {status:'unavailable', advisory_only:true};
    const data = await response.json();
    const answer = data?.answers?.task_type;
    if (!labels.has(answer?.choice) || typeof answer.answer_confidence !== 'number' ||
        !Number.isFinite(answer.answer_confidence) || answer.answer_confidence < 0 || answer.answer_confidence > 1) {
      return {status:'invalid_response', advisory_only:true};
    }
    // A conservative usability threshold, not a calibrated probability of correctness.
    if (answer.answer_confidence < 0.6) {
      return {status:'uncertain', confidence:answer.answer_confidence, advisory_only:true};
    }
    return {status:'ok', classification:answer.choice, confidence:answer.answer_confidence, advisory_only:true};
  } catch {
    return {status:'unavailable', advisory_only:true};
  }
}
