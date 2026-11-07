# Magic-login message approval package

WELL-97 records accountable Product and Content & Media owner approval of the exact PR #202 candidate at head `387d1f1ff30c4ddd8fb8b3b5f5e95758dfb07e78`. The v0.2.0 packet approves only bounded development use. The v0.1.0 packet and original proposals remain immutable candidate history. This branch routes the approved Product/Decision v1.14.0 successors; main remains v1.13.0 until authorised integration. Final independent Master Gate, new-head CI and merge authorisation remain required.

## Review entry points

- [Owner decisions and original user-message provenance](OWNER_APPROVALS_v1.json)
- [Development-approved evidence packet](MAGIC_LOGIN_MESSAGE_EVIDENCE_PACKET_v0.2.0.json)
- [Approved Product v1.14.0 successor](../../../../governance/product/00_PLATFORM_v1.14.0.md)
- [Approved Decision v1.14.0 successor](../../../../governance/product/01_DECISIONS_v1.14.0.md)

- [Proposed Product v1.14.0 amendment successor](../../../../governance/product/proposals/well-97/00_PLATFORM_v1.14.0_PROPOSED.md)
- [Proposed Decision v1.14.0 amendment successor](../../../../governance/product/proposals/well-97/01_DECISIONS_v1.14.0_PROPOSED.md)
- [Candidate evidence packet](MAGIC_LOGIN_MESSAGE_EVIDENCE_PACKET_v0.1.0.json)
- [English subject/body artifact](NEWYOU-MAGIC-LOGIN-MESSAGE-EMAIL-EN-V1.txt)
- [Afrikaans subject/body artifact](NEWYOU-MAGIC-LOGIN-MESSAGE-EMAIL-AF-V1.txt)
- [Retrieved source comment](WELL-12-candidate-comment.json), Plane WELL-12 comment `a8059c05-e55a-4802-9a29-5a1273257af1`

The proposed successors use incremental amendment form to keep the semantic diff small. Each depends on its complete, digest-pinned v1.13.0 predecessor. They add only Product §§21E.21–22 and proposed DEC-321, plus the catalogue addition stated in §21E.21. They preserve all other law. The governance router's `proposed_successors` index makes them discoverable without selecting them in `governing_documents`. The delivery router retains the candidate packet and adds its development-approved successor. The full approved law successors materialise only the accepted additions over the complete unchanged predecessor bodies. A regression test removes those additions and compares the remaining text verbatim.

## Why a Product extension is needed

Product §21E.19 explicitly excludes magic-login authentication from `verification_message`. None of the other controlled types in §21E.3 establishes optional existing-Account sign-in email content. §21E.3 requires an approved extension. The recommended type is `magic_login_message`; the recommended wording risk is `editorial_low_risk`. The accountable Product owner explicitly accepted both in the recorded user decision. Identity authentication/security remains HIGH. Class A exact-copy handling, Product wording risk and Identity security risk are distinct classifications.

Content & Media owns the exact locale content. Identity retains proof/Account/Session authority; Communications retains MessageIntent/DeliveryAttempt and delivery authority. Identity JIT §J.1 is unchanged. No optional-magic-login bearer retention, rematerialisation or authentication-input rebinding is authorised here. WELL-91's Assent disposition and exclusive `2026-11-18T00:00:00Z` expiry remain unchanged.

## Serialization discrepancy resolved

The Plane API exposes two representations of the same comment. `comment_html` preserves five blank lines inside each `<pre>` block. `comment_stripped` removes them. Extracting the HTML blocks without changing a character reproduces the originally reported hashes:

- EN is 278 bytes, SHA-256 `3527fcea7813b4348dd9c2ff06ed0c617c7a8eb6a356e16c4afa63c6b168707b`.
- AF is 327 bytes, SHA-256 `05c09bd18c805572f7bbc75717f5f6a09d3b5eca44f6bb08959ae2bd4fdc3f89`.

Removing exactly those five extra LF bytes produces the contiguous rendering:

- EN is 273 bytes, SHA-256 `3e29c7fc2e55a215875b35ba92cb7b81186cf21d8a470d4c564a9e623708b015`.
- AF is 322 bytes, SHA-256 `e45d82eca89e990b1c1f99ad2995bef09a848eeaa9cfb20859bbac493c522205`.

The proposed canonical artifacts preserve the HTML blocks, including the Afrikaans U+2019 apostrophe. There was no wording edit. The convention matches the verification packet's blank-line structure, but inherits none of its copy approval or eligibility. Each file has literal UTF-8 without BOM, LF line endings, one blank line between subject/body and body paragraphs, and exactly one terminal LF. The first line's `subject: ` prefix is serialization metadata. Subject hashes cover the subject value alone, without prefix or LF. Body hashes cover everything after the first blank line, including the terminal LF. The packet gives byte offsets, lengths and digests for both fields as well as each whole file.

## Accountable decisions required

The Product owner explicitly accepted both exact proposal digests, the `magic_login_message` purpose boundary, the proposed `editorial_low_risk` wording class, and bounded applicability. An approval must preserve Identity HIGH risk and every excluded purpose. Approval of implementation preparation does not satisfy this decision.

The Content & Media owner explicitly accepted the exact ContentItem, ContentVersion and both ContentTranslationVersion identities in the packet. The decision must bind the actual EN/AF whole-file and subject/body digests, byte counts, format ID, typed token contract digest and applicability. It must acknowledge that the HTML blank-line serialization resolves the source discrepancy. Any wording or byte revision needs a new immutable locale version and fresh approval.

Each decision needs a stable decision ID, accountable actor identity, evidence that the actor holds the applicable owner authority, retrievable decision reference, timestamp and explicit outcome. A name in JSON is not proof. An independent reviewer must verify the original accountable decision and its exact binding. The original user message explicitly answers as both accountable owners. OWNER_APPROVALS_v1.json retains the verbatim source with its T3 message identity and timestamp. Plane comment f1c1a5d8-c92b-4a36-8a7d-2313559e2864 records the two decisions. The candidate packet's original pending slots remain unchanged; the successor appends the actual decisions. The agent recorded and bound those decisions without acting as approver.

The owner decisions now support the separately versioned v0.2.0 evidence packet while retaining v0.1.0 as candidate history. It must bind the shared and locale identities, exact proposal and content digests, serialization, tokens and scope. Append all lifecycle events and reconcile conflicts through explicit owner evidence. Identical approval replay is idempotent only for the complete decision/version/digest/scope binding. A conflicting decision stops new use; it never overwrites history. `superseded` and `withdrawn` are terminal for new use. Restart/recovery must reconstruct the full reviewed history and fail closed if evidence is incomplete.

The checker validates immutable candidate history and the approved successor separately. Candidate promotion still fails. The development check requires both exact owner events, complete subject/token/scope bindings, original user-message provenance and approved law routes. Identical event replay is idempotent; changed or conflicting replay fails closed. Runtime/release eligibility always remains false. The checker verifies recorded evidence and digests; the independent reviewer must verify the original user decision and cannot infer an owner approval from nonempty JSON fields.

## Applicability and promotion

Development approval is limited to local development, automated tests, development environments and bounded P8-09 Phase-8 proof. Production, public release, paid pilot and real-participant delivery remain prohibited. This package supplies no runtime Content role approval, publication, release, sender/provider use or authentication implementation permission.

Owner decisions are recorded. Independent Master Gate review of the promoted exact head and CI, explicit unchanged-merge authorisation and resulting-main certification remain outstanding. WELL-97 must remain nonterminal and WELL-12 must remain Blocked. After those guards pass, request a fresh independent WELL-12 readiness review; never automatically move it to Ready.

## Reconnaissance and proof

Base `main` was independently fetched at `da9b745ae4dea95c84882c36c7413094d8dcaaad`. WELL-97 was Ready with no incoming dependencies. WELL-12 was Blocked. The review covered AGENTS.md, docs/README.md, both current routers, Product §§21E.3–4/19–20, DEC-317–320, Architecture §§8 and 10, Domain §§6.1/6.7/6.15, the governing Roadmap FP-001 boundary, Operating/Engineering/Delivery standards, Identity JIT §J.1, Communications JIT, TB-001, Content & Media pre-JIT and the existing verification packet.

Copy reconnaissance inspected COPY_REGISTRY.json, STYLE_GUIDE.md, GLOSSARY.md and the login journey/page inventory. There is no existing magic-email subject/body entry or approved magic-login content to reuse. The packet reserves `identity.login.magic_email.subject` and `identity.login.magic_email.body` as candidate semantic keys; it stores wording only in the immutable artifacts. No browser login text or existing registry wording changes. Detailed browser copy stays JIT.

Run from the repository root:

```sh
python3 tools/check_magic_login_evidence.py
python3 -m unittest discover -s tests -p 'test_magic_login_content_evidence.py' -v
python3 -m tools.foundation_integrity_smoke --json
python3 tools/run_foundation_full_tests.py
python3 tools/foundation_integrity_audit.py --manifest docs/history/CURRENT_AUTHORITY_MANIFEST_v1.0.0.json --json
devcore-project run test -- mix check
```

The focused tests reproduce both source representations and reject approval, identity, digest, token, locale, scope and binding mutations. Exact-head results belong in WELL-97 and the PR. This README states repeatable commands, not a claim that a future revision passed them.

Documentation-impact determination: this package is itself the source-linked governance/content review record. It creates no vertical slice or runtime capability, so the implementation-handoff standard's substantial-slice map is not applicable. Ash, Igniter, database migrations, Hallmark and frontend checks are not applicable because the ticket changes no application mechanism or rendered visual design.
