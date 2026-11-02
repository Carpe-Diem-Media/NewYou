# Review report

## 1. Owner decisions incorporated on 2026-11-02

### Brand and dynamic copy

- Public brand is not locked. Participant-facing copy uses `{{platform_name}}` everywhere the brand appears.
- `public.entry.launch.title` and `public.entry.launch.body` remain stable semantic copy keys so their values can change without page-code changes.
- Current launch heading and description were owner-accepted as candidate text; normal scoped development approval still applies before implementation treats them as governed exact bytes.

### Safety / scope

- Owner accepted the launch safety boundary and asked that information limits be explicit. The revised candidate says guidance depends on information the person chooses to provide and distinguishes platform guidance from individual medical, psychological and dietetic care.
- Dietetic expertise on the team does not by itself mean every automated interaction is individual dietetic care.

### Registration and legal UI

- Registration heading accepted; brand token is dynamic.
- Registration introduction expanded to explain free registration may unlock additional/personalised experiences without promising a specific future feature.
- Age confirmation and age validation accepted; no Afrikaans comma is required in `Bevestig dat jy 18 jaar of ouer is om ’n rekening te skep.`
- The v0.2.0 owner decision used one participant-facing checkbox for Terms and Privacy. That historical decision is superseded and is not current guidance.
- Afrikaans UI term is `Privaatheidsbeleid`. The governing English artifact remains the English `Privacy Notice`; the UI choice does not rename that legal artifact.

### Identity/security wording

- Registration/pending wording is made positive, but must remain neutral enough not to reveal whether an email address already had an account.
- The workspace therefore does **not** say `A verification email has been sent` or `Registered successfully` on the neutral public path, because those statements are not true for every anti-enumeration-equivalent request.
- `inkassie` is prohibited in Afrikaans participant copy; use `e-pos` (or `inbox` only if a later deliberate product-language decision explicitly requires the loanword).
- Pending access language uses `gratis inhoud` and `eksklusiewe funksionaliteit`. It deliberately does not claim registration itself granted public content. Revisit `exclusive` if that word later becomes a paid-entitlement term.

### Afrikaans terminology now owner-selected

- `Journal → Joernaal`.
- `Professional review → professionele hersiening`.
- Participant-facing entitlement/access → `toegang`.
- `Privacy Notice` UI term → `Privaatheidsbeleid`.
- `Required → verpligtend`.
- `Wellness → welstand` or `gesondheid en welstand`, depending context.
- `Serving/portion → porsie`; size → `porsiegrootte`.
- `Receipt → Betalingsbewys` remains **OWNER REVIEW REQUIRED** because no explicit owner choice was recorded for that term in the latest decision set.

### Remaining exact-copy review

- The revised expanded safety body and expanded registration introduction are incorporated as candidates from the owner discussion, but should receive a final exact-byte read before they are cut as immutable development-approved evidence.
- All normal Class A specialist/content/language approvals remain separate from owner preference.

## 2. Existing approved/development evidence reused

### Verification email

Reused without rewriting:

- `VERIFICATION_MESSAGE_EVIDENCE_PACKET_v0.2.0.json`
- EN exact artifact digest `a8ceecc466497bd3d79ae9255a7f004b18461a2d6a1791028a68bcb1efd2a072`
- AF exact artifact digest `c3212222fdcd878af6bdc2b17895d4d6cab44e162814e2a8deee10b7fd916494`
- status: development-approved for bounded non-production P8-05 contexts only; runtime/release pending.

### Legal development baselines

Referenced, not rewritten:

- Terms `NEWYOU-TERMS-EN-DEV-2026-10-27-001` / SHA-256 `8d54af7ac0c2a68d3d100cca987551877f4f89ca231ae95254cd1903a2eca062`.
- Privacy `NEWYOU-PRIVACY-EN-DEV-2026-10-27-001` / SHA-256 `21aecdf9fafe95f513de2ce04a266e8e7726efb406aabae0bbd4d0e19f6ba333`.
- both development-only current baselines; not legally/privacy approved for production or real-participant release.

## 3. Candidate copy created in this workspace

- Shared EN/AF navigation, actions, form mechanics, validation, state, error, empty-state, confirmation, file, date/time and accessibility copy.
- P8-05 launch/product framing candidate.
- P8-05 bounded safety framing candidate.
- P8-05 registration field/gate/instruction/processing/failure/neutral copy.
- P8-05 verification-pending/resend/access-limitation/public-next-action copy.
- Shared payment-ambiguity pattern candidates.

All newly drafted wording remains `candidate` unless explicitly mirrored from existing development-approved verification-message evidence.

## 4. Deferred / JIT copy

Detailed substantive copy is intentionally deferred for login/recovery beyond generic keys, health intake, assessments, measurements, plans, programmes, habits, progress, journal, most public marketing pages, product/checkout/subscription/refund journeys, support, notifications, SEO and operator workflows. The platform knows these surfaces exist, but exact wording should be written against executable lifecycle/feature context rather than guessed now.

## 5. Release-only blockers (separate from development blockers)

- Production legally/privacy approved governing Terms and Privacy exact versions/evidence.
- Runtime/release eligibility and required scoped approvals for verification-message locale versions.
- Production release approval for the exact P8-05 launch/safety/browser copy that is eventually selected.
- Future clinical/safety/commercial/legal approvals required by later features.

These do not justify pretending the current candidate browser strings are approved, and they also do not convert WELL-45 into a blanket blocker for permitted bounded development once its exact browser development evidence is actually approved.

## 6. Current development blocker

The current blocker is narrower: exact immutable EN/AF browser-copy evidence for the P8-05 journey plus the required scoped content/language approvals. This workspace supplies reviewable candidate wording and stable identities; **it does not close WELL-45**.

## v0.3.0 legal UX candidate

- The v0.2.0 combined participant-facing Terms + Privacy checkbox is superseded.
- The current candidate uses age confirmation, separate Terms and Privacy acceptance controls, with Privacy Notice presentation before acceptance. Presentation alone does not satisfy the governed Privacy acceptance requirement. Product Law requires both exact acceptance facts and their evidence, but does not prescribe two controls; this layout is a candidate UX/legal-review choice.
- Privacy acceptance records acceptance of the applicable exact Privacy version for registration. It is not blanket consent to every processing purpose. Purpose-specific consent remains separate and appears only where applicable.
- Product v1.13.0, DEC-027 and DEC-316 govern. Governing Terms and Privacy documents are English-only; Afrikaans and English product experiences link to the same English documents, while participant interaction/preferred locale is recorded separately.
- Terms v0.3.3 and Privacy v0.3.2 are unchanged pre-counsel source inputs. Their older Product v1.9.0 language assumptions, including a requirement for bilingual governing legal documents, are stale and subordinate to current Product Law. Reconcile them against current authority before any later legal or counsel successor can become production authority. The source pack does not amend Product semantics.
- **RETAINED:** existing owner-reviewed verification-pending/resend copy; LUX-VER-001/002 did not replace it because the existing copy is clearer while remaining anti-enumeration safe.
- **RETAINED:** existing P8-05 launch/safety wording; generic legal disclaimer candidates are contextual future/JIT copy, not replacements for the P8-05 launch safety candidate.
- **ADDED:** split working legal UX candidates/templates for disclaimers, marketing, cookies, health JIT disclosure, special-PI review shell, practitioner sharing and early-performance instruction.
- **UNCHANGED:** `NEWYOU_PLATFORM_DIGITAL_PRODUCTS_SUBSCRIPTION_TERMS_COUNSEL_REVIEW_CANDIDATE_v0.3.3.md` and `NEWYOU_PRIVACY_NOTICE_COUNSEL_REVIEW_CANDIDATE_v0.3.2.md` retain their exact pre-counsel source bytes; this workspace references but does not edit them.
