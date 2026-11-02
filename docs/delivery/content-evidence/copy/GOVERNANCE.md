# Wellness Platform copy governance

## 1. Authority boundary

This workspace is review material. Durable Product → Architecture → Domain → Roadmap → supporting authority → applicable Feature/JIT/proof contracts remain above it. Plane remains live execution authority. Content & Media owns governed content/version truth; other Domains own the business facts that copy describes.

## 2. Copy classes

### Class A — governed exact copy

Use when exact wording/version/approval materially matters: governing legal/privacy/consent; safety/clinical; commercial ambiguity; identity/security; or any participant-facing copy current authority explicitly requires to be approved/immutable. Implementation agents must not invent or silently rewrite it.

### Class B — shared product/UX copy

Stable semantic identities for reusable UI/journey language. It can evolve through controlled copy revision. It should not be elevated into Product Law merely because a button was polished.

### Class C — ordinary implementation copy

Developer/internal/mechanical text with no material participant, safety, legal, security or commercial semantics. Keep it JIT and proportionate.

## 3. Content-risk taxonomy is separate

The A/B/C copy-risk class is **not** the Product content-risk taxonomy. Where relevant the registry additionally records Product-style risk such as `editorial_low_risk`, `health_education`, `personalisation_guidance`, `clinical_guidance`, `safety_critical`, `legal_or_consent`, or a narrow governed type such as `verification_message`.

## 4. Readiness

- `NOW` — required at the current execution frontier; write complete candidate EN/AF now.
- `SHARED_BASELINE` — reusable language worth establishing now.
- `JIT` — known future surface; inventory/keys now, substantive copy when feature context is executable.
- `RELEASE` — final specialist/legal/privacy/clinical/commercial production wording/evidence that must not be fabricated to unblock bounded development.

## 5. Stable semantic key convention

Pattern: `<area>.<journey_or_surface>.<concept>[.<variant>]`.

Examples: `identity.registration.submit`, `identity.verification.pending.title`, `shared.validation.required`, `commerce.payment.pending.body`.

Rules:

1. Keys identify meaning, never visual position (`page1.button2` is forbidden).
2. Use lowercase ASCII dot-separated segments.
3. `.title`, `.body`, `.action`, `.help`, `.label`, `.error`, `.processing` are semantic variants, not arbitrary component names.
4. A visual redesign must normally keep the same key.
5. If meaning materially changes, create a new semantic key/version rather than reusing an old key deceptively.
6. Page manifests reference keys only; they never contain source translations.

## 6. Ordinary Class A/B lifecycle

### States

`draft → candidate → development_approved → production_approved → superseded | withdrawn`

Not every item must pass every state. A bounded development baseline may stop at `development_approved`; release-only content may remain candidate until specialist approval exists.

### Transitions and guards

**draft → candidate**
- EN/AF scope is known or missing locales are explicitly marked.
- semantic key/purpose/owner/class/readiness are set.
- no claim of approval is made.

**candidate → development_approved**
- exact candidate version identity is pinned;
- exact locale bytes/digests are pinned where exactness matters;
- required owner/content/language reviews for the bounded development use are recorded;
- applicability is explicitly non-production if release evidence is incomplete;
- no required locale silently falls back.

**development_approved → production_approved**
- exact version is unchanged;
- all required release specialist/legal/privacy/clinical/commercial approvals exist;
- runtime/release eligibility decision exists where governance requires it;
- production applicability is explicit.

**development_approved|production_approved → superseded**
- a successor immutable version exists;
- successor has the appropriate approvals for new use;
- old exact bytes/history remain intact.

**candidate|development_approved|production_approved → withdrawn**
- authorised owner records a withdrawal decision and reason;
- new consumption stops for the affected applicability;
- history remains.

### Side effects

- Approval never edits historical exact bytes in place.
- Supersession updates current-use selection to the successor but preserves the old version for evidence/history.
- Withdrawal removes new-use eligibility; it does not erase evidence.
- A content approval does not create business authority in Identity, Commerce, Safety, etc.

### Terminal states

For **new consumption**, `superseded` and `withdrawn` are terminal. Historical display/evidence remains permitted only where the governing context allows it.

### Authorization

- Content & Media controls governed content/version lifecycle.
- Required specialist approvals are separate facts; one human may hold multiple roles but each approval is recorded separately.
- Legal/privacy/clinical/safety/commercial approvers do not transfer Domain business ownership.

### Concurrency, idempotency, retries and reconciliation

- Repeating the same exact transition for the same version/digest/decision is idempotent.
- Competing approval/supersession/withdrawal decisions for the same immutable version must not use last-write-wins; stop and reconcile.
- A failed approval recording does not partially promote one locale while pretending the pair is complete where both are required.
- After interruption/retry, re-read current version state and exact digest before applying a transition.
- If source bytes differ from the recorded digest, fail closed and cut/reconcile a new candidate version.

## 7. Class C lifecycle

Class C may use `draft → active → obsolete`. It does not require content-specialist approval unless its meaning changes enough to become Class A/B. If an internal string becomes participant-visible or materially security/commercial/safety relevant, reclassify it before release.

## 8. No-fallback policy

No silent locale fallback for required bilingual registration/authentication, participant-facing privacy/consent notices, assessments, plans, clinical/safety copy, core onboarding, verification UI or other governed content where both locales are required. Optional low-risk editorial content may explicitly say the selected translation is unavailable and offer the available language. Governing Terms and Privacy bodies are the narrow English-only exception under current authority.

## 9. Development versus production

`development_approved` is not `production_approved`. The existing verification email is the clearest example: exact EN/AF bytes are development-approved for bounded non-production P8-05 use, while runtime/release approval remains pending. Legal development baselines are pinned and development-eligible but are **not legally approved**.

## 10. Implementation rule

Implementation agents may choose normal Class C/JIT wording only within the current ticket's allowed ordinary implementation boundary. They must not invent Class A wording and should reuse Class B semantic keys rather than creating near-duplicate translations.

## Legal UX event separation

The split legal UX candidates add no Product or Domain authority. Current Product Law requires acceptance of both the exact applicable Terms version and the exact applicable Privacy version before registration, with the required acceptance evidence. These are distinct durable acceptance facts. Product Law and P8-05 do not prescribe the number or visual arrangement of participant-facing controls. The v0.3.0 copy candidate represents the facts with separate Terms and Privacy controls, as a UX/legal-review choice.

Page manifests preserve distinct Terms and Privacy acceptance keys and must not collapse their evidence into a generic `accepted_legal` fact. A Privacy Notice presentation is a separate disclosure and does not replace Privacy acceptance. Keep both acceptance facts distinct from age confirmation, purpose-specific consent, marketing permission, cookie choices, special-PI authorisation, practitioner sharing and early-performance instructions. Privacy acceptance is not consent to every processing purpose.

The governing Terms and Privacy bodies are English-only under current Product Law. Afrikaans and English product experiences link to the same English documents, while participant-facing UI remains bilingual. The pre-counsel source candidates are historical inputs; current Product Law overrides their conflicting assumptions.

Lifecycle semantics for these working candidates are documented in `legal/LEGAL_UX_LIFECYCLE_CONTRACTS_WORKING_v0.1.0.md`; production/release gates are in `legal/LEGAL_UX_RELEASE_GATES_WORKING_v0.1.0.md`.
