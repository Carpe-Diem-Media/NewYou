# Capability knowledge

Start with [identity.registration.json](identity.registration.json), the canonical registration map. Follow its `sources` entries to files/symbols, then inspect current code, migrations, tests, routed authority and live Plane before reuse. Its Git revision identifies the inspected snapshot; per-file SHA-256 values bind exact bytes. This is descriptive knowledge, not governing authority or delivery status.

Create or update one `<capability_id>.json` for a meaningful capability or material interface/lifecycle/schema change. Use [capability.schema.json](capability.schema.json). Capture real owner interfaces, Ash actions, persistence, flow, lifecycle, security, retry/recovery, tests, extension points and prohibited shortcuts. Explain non-applicable dimensions instead of inventing resources. Never include secrets, participant data or private proof payloads.

Run `python3 -m tools.capability_knowledge` and `python3 -m unittest tests.test_capability_knowledge -v`. The dependency-free validator implements the schema's documented keyword subset, rejects duplicate keys/unknown fields, and checks source bytes/symbols and reference closure. Material source changes require map review/update. Independent Master Gate verifies semantic claims; shape and locators alone cannot prove them.

The registration snapshot was inspected at `09812d6bb245fe9360af813f7590c9313ff5a851`. WELL-121 changes no application source. For future maps, record an implementation commit containing the source bytes; it may precede the documentation commit. Never invent the documentation's future self-referential SHA. See [the handoff standard](../implementation-handoff-standard.md).
