# Reproduce the Hosted Redirect proof

From the extracted proof archive, on Python 3.11 or newer:

```sh
sha256sum -c SHA256SUMS
python3 -B -m unittest -v test_hosted test_commerce test_evidence_gate
```

The tests were run on Python 3.15.2. The receipt repository is temporary SQLite. A synthetic merchant and a synthetic provider HTTP fixture bind only to loopback. The HTTP client never follows the retained illustrative Paystack checkout URL. Synthetic payer headers and webhook triggers stand in for authenticated application boundaries. No socket or service configuration for real Paystack is included. The fixtures do not operate real Commerce resources or grant real access.

`redirect-red.txt` records the initial failure where the stub produced 202 instead of the expected secure 303. `test-results.txt` records the complete suite. The prior recovery prototype contributed the Commerce model and nine tests, which were adapted and rerun here. The Store assessment links exact source and test assertions. It makes no claim that Store's application suite was freshly executed.
