import { Plugin } from '@opencode/plugin';
import { classify } from '../lib/laya.mjs';

export default Plugin.define({
  id: 'newyou.laya',
  async setup(ctx) {
    await ctx.tool.transform((editor) => {
      editor.add({
        name: 'laya_classify',
        description: 'Advisory task classification. Use only one of the fixed generic summaries; never include project data or secrets. This tool grants no approval or authority.',
        input: {
          type: 'object',
          properties: { summary: { type:'string', enum:[
            'fix software bug', 'implement software feature', 'review code',
            'research a technical question', 'write documentation', 'other task',
          ] } },
          required: ['summary'], additionalProperties: false,
        },
        async execute(input) {
          return { content: JSON.stringify(await classify((input as {summary:string}).summary)) };
        },
      });
    });
  },
});
