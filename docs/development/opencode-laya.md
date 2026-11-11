# Project-scoped Laya classification

OpenCode 2.2.6 discovers `.opencode/plugins/laya.ts` when started in this project. The `laya_classify` tool sends one of a fixed set of generic English or Afrikaans summaries to `127.0.0.1:8000`. It does not accept arbitrary text, repository names, credentials or private evidence. Add a phrase only after reviewing that it carries no sensitive context. The allowlist prevents arbitrary input, but it does not authenticate callers or the service listening on loopback.

The result is advisory. It does not approve reviews, validate attestations or authorize merges. The model can return a wrong label or low confidence. If the endpoint fails, the request times out, or the response is invalid, continue without Laya. No Laya availability is required by WELL-117.

Run `node --test .opencode/tests/laya.test.mjs` for the local regression suite. These tests mock error responses and exercise a refused loopback connection; invoking the tool through OpenCode is a separate runtime check. The original `.opencode/tools/laya.ts` is not required by this V2 plugin.
