# Copy system status — 2026-11-02

**Workspace:** v0.3.0 review candidate<br>
**Verified main:** `ec9deb9bc3f5e78b5041213c32698b226c6a6ceb`<br>
**Repository mutated:** no

## Registry totals

- Total registry records: **273**
- NOW: **49**
- SHARED_BASELINE: **152**
- JIT: **69**
- RELEASE: **3**
- Existing `development_approved` records mirrored: **2** (verification email subject/body only; production eligibility remains false)

## Current blockers

### Development blocker for WELL-52 / WELL-53

The new P8-05 browser copy in this workspace is still `candidate`. WELL-45 requires exact immutable bilingual browser-copy evidence plus scoped content/language approvals before it can be treated as development-approved exact browser copy. This workspace does **not** fake those approvals.

### Not development blockers

Final production legal/privacy approvals for the governing Terms/Privacy bodies are release gates, not a reason to block permitted bounded development using the current pinned development baselines.

### Release-only blockers

- final legally/privacy approved Terms and Privacy exact versions/evidence;
- runtime/release eligibility for exact verification-message locale versions;
- production approvals for new exact launch/safety/browser content;
- any later clinical/safety/commercial specialist approvals required by future surfaces.

## v0.3.0 legal UX integration status

- Source legal UX pack: reconciled and split into scoped Markdown files.
- Terms + Privacy combined checkbox: **SUPERSEDED**.
- Separate Terms acceptance: **CANDIDATE / OWNER + LEGAL/PRIVACY + LANGUAGE REVIEW REQUIRED**.
- Privacy presentation/acknowledgement: **CANDIDATE / LEGAL/PRIVACY DECISION REQUIRED**.
- Cookie Notice shell, special-PI consent shell and early-performance instruction: **HARD BLOCKED / REVIEW SHELLS ONLY**.
- Counsel-review Terms v0.3.3 / Privacy v0.3.2: **PRE-COUNSEL / UNTOUCHED / NOT PUBLICATION AUTHORITY**.
- WELL-45: remains open Planning; this workspace does not record the approvals needed to close the bounded-development browser-copy evidence gate.
