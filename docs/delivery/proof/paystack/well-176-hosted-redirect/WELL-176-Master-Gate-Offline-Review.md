# WELL-176 — Independent Master Gate offline review

**Review date:** 2026-11-22

**Disposition for the submitted offline research/prototype:** **PASS WITH NON-BLOCKING CORRECTIONS**

**Disposition for Paystack EV-001B provider PASS, FP-002 implementation readiness and provider-connected execution:** **BLOCKED / STOP**

## Exact inputs and verification

- Uploaded archive: `WELL-176-Hosted-Redirect-Proof.zip`.
- Archive SHA-256: `73a6a637fc08fd18b67a464b3ce56ad2f476e7ac6c9c9cbf988a7cfa4a486711`.
- ZIP CRC: PASS; regular flat-file entries inspected. Internal `SHA256SUMS`: **13/13** matched. Separately attached reports and SHA256 manifest matched the archived copies byte-for-byte.
- Independently extracted and ran: `python3 -B -m unittest -v test_hosted test_commerce test_evidence_gate`.
- Actual independent result: **22 tests, 0 failures, 0 errors, exit 0**. Suite includes synthetic loopback HTTP, SQLite restart, concurrent reservations, failure/late-success and fixture witness checks.
- Exact NewYou `main`: `e7fc58167223be433d9ccc9d61d3aaeb2090a10c`.
- Exact Store Blueprint Hardening `main`: `949821ac589addb6e595f6333370ed65cf8d5ef7` (correct reuse repository: `Carpe-Diem-Media/Store_Blueprint_Hardening`, not original `Store_Blueprint`).
- Live Plane: WELL-176 Blocked, WELL-171 Planning; WELL-22 has an FP-001 dependency. OQ-004 remains open and EV-001B remains NOT_EXECUTED.
- No repository diff/PR, no exact-head application CI and no production implementation are part of this submitted offline artifact.

## What is demonstrated

1. A SQLite transaction reserves one reference before the provider-like POST. Twelve concurrent synthetic HTTP callers admitted one Initialize into the loopback receiver, and a separate 16-way reservation test had one winner.
2. On receipt of a matching synthetic Initialize response, the original reference, access code and strict illustrative checkout URL persist before an HTTP 303 is emitted. An induced participant-response disconnect and a later new database connection recover the same URL, without another Initialize.
3. An induced upstream response-loss state retains the old attempt/reference and refuses repeat Initialize or speculative replacement. Later authenticated-*fixture* success can be applied.
4. Synthetic Verify observations are checked against known reference, integration, TEST mode, amount, currency and lossless transaction ID. Browser return and authenticated-*fixture* webhook signals are triggers rather than payment truth.
5. A durable SQLite outbox and deduplicated synthetic entitlement-effect row model one consequence, including lost-acknowledgment replay and reversal-before-issuance behavior.
6. `evidence_gate.py` correctly treats URL matching plus two Verify records without a fresh hosted-session witness as INCONCLUSIVE, and names successful fixture-only evidence `QUALIFIES_IN_FIXTURE`, not real-provider PASS.

## Important limitations and corrections

**Not blocking acceptance of the offline demonstration, but blocking broader certification:**

- **No real hosted Paystack session observed.** The HTTP test uses local merchant and provider fixtures, does not follow the Paystack `Location` to a browser, and cannot prove a resumed provider transaction or actual iframe/hosted page request list. The witness object and `from_provider_observation` flag in `evidence_gate.py` are synthetic input, not independent provider authentication.
- **No production authorization/security proof.** The synthetic payer header, boolean webhook-authentication parameter, unencrypted SQLite capability, hard-coded TEST observation data and URL pattern are explicit fixtures. Real actor authorization/CSRF, restricted receipt encryption, authentic Paystack webhook/Verify parsing and safe live URL shapes must be proven in NewYou implementation.
- **No actual cross-Domain convergence proof.** `commerce_model.py` writes `entitlement_effect` to the same SQLite database as a stand-in. The real design must use the owning Entitlements/Ash interface, with durable Commerce consequence, independent idempotency, acknowledgment recovery and cross-Domain failure tests.
- **No deployed-stack concurrency/failure certification.** SQLite locks and `http.client` prove this harness only. PostgreSQL/Ash admission and dispatch, exact HTTP client retry behavior, process crash windows, worker loss, repeated resume, multi-tab presentation and provider-session overlap need their appropriate later proofs.
- **No supported expiry/replacement rule.** Local timeout, `failed`, `abandoned`, `expired` or a Verify miss never releases the original fence, which is the safe current design. Provider-backed terminal nonpayability and in-flight settlement resolution remain open.
- **URL allowlist is deliberately narrower than an established provider contract.** Exact provider URL shapes, redirect behavior, asset origins/methods and host session-to-transaction binding require provider evidence before a browser test. Do not silently expand the allowlist.

## Store Blueprint Hardening assessment

Independent live source inspection confirms `Store.Payments.PaymentIntent` includes `correct_to_succeeded` from `failed`, and `Store.Payments.Interlocks` uses that action on an explicit verified-correction path. Store also has a `PaymentApplication` apply-once resource and checkout interlocks. These are candidate patterns, not NewYou implementation or acceptance of all lifecycle semantics. Store's `lib/store/payments/providers/paystack.ex` still has unimplemented `create_intent`, `observe_payment`, `verify_webhook` and `normalize_webhook`. Store's provider-readiness document classifies Paystack as scaffold-only. Do not port Store's entire application, subscription/renewal or infrastructure authority into NewYou.

## Decision / handoff

**PASS WITH NON-BLOCKING CORRECTIONS for the exact submitted offline research and proof artifact.** This is a credible, independently reproducible *synthetic* Hosted Redirect recovery design, suitable for bounded planning and next-provider-question formulation. It is **not** an EV-001B PASS, code review of a NewYou implementation, readiness for merge or authorization for provider execution.

Keep WELL-176 Blocked, OQ-004 Open and EV-001B NOT_EXECUTED. No change to the existing unresolved original transaction and no replacement admission. Keep FP-002 implementation governed by its own Ready ticket/dependency gates; WELL-171 may continue provider-independent planning.

**Next decision requiring owner approval:** send the supplied identifier-free `PAYSTACK-SUPPORT-DRAFT.md` to Paystack support, requesting documented retained-URL fresh-session identity, request inventory, capability reissue and terminal nonpayability behavior. Review any response and then request a distinct exact-scoped provider TEST experiment only if a compliant, preventively isolated runner is qualified. The user's earlier choice of Hosted Redirect is not permission to send this inquiry or run transactions.

**Review limitations:** inspected Store hardening source and relevant authority; Store's full Elixir/DB test suite was not executed. No PR exists to evaluate a complete diff and exact-head CI. No Paystack contact, repository changes or Plane changes were made.
