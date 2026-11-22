# WELL-176 Hosted Redirect offline evidence

This directory preserves synthetic engineering evidence. The proof uses loopback HTTP and SQLite fixtures. Provider-connected execution, financial finality, EV-001B, production security and deployed-stack recovery still require their own evidence. The approval to preserve these files grants no authority to execute a Paystack operation, send the support inquiry, implement FP-002 or change Plane state.

- Reviewed NewYou base: `e7fc58167223be433d9ccc9d61d3aaeb2090a10c`.
- Store Blueprint Hardening source assessment: `949821ac589addb6e595f6333370ed65cf8d5ef7`.
- Original reviewed archive: `WELL-176-Hosted-Redirect-Proof.zip`.
- Original archive SHA-256: `73a6a637fc08fd18b67a464b3ce56ad2f476e7ac6c9c9cbf988a7cfa4a486711`.
- Original supplied Master Gate review SHA-256: `67af3eabfe3a84eb95912ed8a03443656e85370796c5c9dbe2dc9fc24cea704b`.

The original ZIP, loose proof files and supplied review were copied byte-for-byte to private persistent custody. The ZIP passed its CRC check, all 13 original manifest entries matched and all 14 archive members matched the original loose files. The independently supplied review records 22/22 offline tests and PASS WITH NON-BLOCKING CORRECTIONS for the original archive.

The Git copy preserves every proof file's bytes except for one local directory prefix removed from `redirect-red.txt`. The test name, line number, failure and output remain intact. `ORIGINAL-SHA256SUMS` is the unmodified manifest from the archive and describes the original red log. `SHA256SUMS` verifies the published copy, including its sanitized log, the original manifest and the supplied review. The Git copy of the review converts two Markdown hard line breaks to paragraph breaks and keeps the review wording intact. The unsanitized ZIP remains in private custody with its original digest because it includes the original local path.

[Reproduce the offline tests](README.md) · [Hosted Redirect design](WELL-176-HOSTED-REDIRECT.md) · [Store reuse assessment](STORE-REUSE-ASSESSMENT.md) · [Proposed Plane handoff](PLANE-HANDOFF-DRAFT.md) · [Unsent support inquiry](PAYSTACK-SUPPORT-DRAFT.md) · [Independent offline review](WELL-176-Master-Gate-Offline-Review.md)

WELL-176 remains Blocked. OQ-004 remains Open and EV-001B remains NOT_EXECUTED. [WELL-176](https://app.plane.so/symphony-development/browse/WELL-176)
