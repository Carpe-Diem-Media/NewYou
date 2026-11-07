# 01_DECISIONS_v1.14.0.md

- **Document status:** FROZEN PRODUCT DECISION REGISTER v1.14.0
- **Document version:** v1.14.0
- **Predecessor:** `docs/governance/product/01_DECISIONS_v1.13.0.md`
- **SemVer transition:** `v1.13.0 → v1.14.0`
- **Authoritative for:** Locked, provisional and externally gated platform decisions
- **Decision coverage:** GQ-001 through GQ-012 plus GQ-NY-001 and approved post-freeze DEC-292–DEC-321 decisions
- **Last updated:** 2026-11-07
- **Related documents:** `00_PLATFORM_v1.14.0.md`, `05_ROADMAP_v1.2.5.md`, `PROJECT_NORTH_STAR_AND_MVP_v1.3.0.md`
- **v1.2 amendment scope:** Preserve DEC-001 through DEC-291 history; append DEC-292 and DEC-293 for the approved Paystack launch-gateway promotion and first-party experimentation capability. DEC-047's historical provisional wording is superseded by DEC-292. Existing expert/vendor validation gates remain in force.

## v1.14.0 amendment scope

This owner-approved successor adds only the magic_login_message classification and bounded P8-09 development content eligibility under DEC-321. Product and Content & Media decisions bind PR #202 head 387d1f1ff30c4ddd8fb8b3b5f5e95758dfb07e78 and its exact proposal/content subjects. See docs/delivery/content-evidence/content_media/magic_login_messages/OWNER_APPROVALS_v1.json. This PR still requires independent review, CI and explicit merge authorisation before integration. No runtime or release authority is granted.

## v1.13.0 Amendment Scope

This successor updates DEC-319 so development-only verification-message eligibility is independent of runtime Content grants and appends DEC-320, a project-wide rule separating implementation permission from runtime role/grant authority. It preserves governed production and release gates.

## v1.12.0 Amendment Scope

This successor records DEC-319 for the narrow verification-message classification, bounded proof eligibility and Content & Media lifecycle role/scope. It consumes, and does not duplicate, DEC-317 and DEC-318.

## v1.11.0 Amendment Scope

This successor clarifies DEC-022 and adds DEC-317 and DEC-318 for role-based capabilities, operational delegation and governed bootstrap. DEC-021 remains unchanged.

## v1.2.2 Patch Scope

This non-semantic governance correction formalises `OQ-040`, an already-consumed architecture/proof gate tied to `DEC-293`. It introduces no new Product Law semantics, changes no existing DEC status, meaning or numbering, and does not reopen Product Law.

## v1.3.0 Amendment Scope

This amendment preserves DEC-001 through DEC-293 history and appends DEC-294 through DEC-298 for the approved Targeted Product Amendment Stage 2 capability set: Research & Feedback, Voting / Balloting / Competitions, Interactive Tools / Calculators / Decision Aids, Platform Member Reference and cross-capability interaction rules. It introduces no Architecture, Domain, Roadmap or implementation semantics.


## v1.4.0 Amendment Scope

This amendment preserves DEC-001 through DEC-298 and appends DEC-299 through DEC-303 for paid-plan entitlement outcomes, commercial reversal consequences, consent withdrawal, temperament-result provenance and assessment purchase limits. These decisions do not create Domains, Feature Packs, Architecture or implementation choices.

## v1.4.1 Patch Scope

This routing-only successor updates version metadata and related-document paths. It changes no DEC or OQ identifier, status, meaning or gate, and creates no new decision.

## v1.5.0 Amendment Scope

This substantive successor preserves DEC-001 through DEC-303 and appends DEC-304 for the approved scope and ownership of marketing unsubscribe actions. DEC-304 composes with, and does not replace, DEC-301's general consent-withdrawal rule. It does not make a legal-sufficiency finding or specify implementation mechanics.

## v1.6.0 Amendment Scope

This substantive successor preserves prior decision history, marks DEC-051's role-based methodology-authority assignment superseded in part by DEC-309, and appends DEC-305 through DEC-312 for the accepted Pass 2 Product decisions. It adds no Architecture or Domain decisions and does not resolve methodology, legal, clinical, provider, retention or other expert gates.

## v1.9.0 Amendment Scope

This substantive successor preserves prior decision history, marks DEC-039 and DEC-045 superseded in part by DEC-315, and appends DEC-315 for statutory consumer cancellation, renewal, refund and credit behaviour. It adds no Domain, Architecture, provider, schema, resource or implementation decision.

## v1.10.0 Amendment Scope

This substantive successor preserves prior decision history, marks DEC-124 superseded in part by DEC-316 for governing Terms and Privacy document bodies only, and appends DEC-316 for English-only governing legal documents and separate development and release readiness. DEC-028's bilingual platform requirement and DEC-027's Terms/Privacy acceptance requirement remain unchanged. This amendment makes no legal-sufficiency finding and adds no Architecture, Domain, schema, API, dependency or runtime implementation decision.

## v1.8.0 Amendment Scope

This narrow substantive successor preserves prior decisions, leaves DEC-300 unchanged, and appends DEC-314 to promote only the distinction between duplicate provider evidence and multiple genuine collections for one intended obligation. It establishes one exact make-whole result for verified excess, preserves distinct intended purchases, and requires immutable accepted-order allocation for component attribution. It adds no Architecture, Domain ownership, shared-write authority, provider mechanics, API, idempotency-key design, schema, resource, job, service, UI workflow, Feature Pack or implementation decision.

## v1.7.0 Amendment Scope

This substantive successor preserves prior decision history, narrows DEC-055 for paid Assessment-credit consumption semantics and adds DEC-313. DEC-313 governs claim/hold, complete-delivery consumption and same-credit release after nontechnical expiry. It clarifies the reference event for DEC-034 without changing the one-retake-per-year limit or purchase policy. It adds no Architecture, Domain, Roadmap-sequencing or implementation decision.

## v1.2.3 Patch Scope

This patch records the explicit OQ-034 architecture/security resolution from the merged FP-001 Identity & Access JIT Domain Dossier. It adds no Product Law semantics, changes no existing DEC status, meaning or numbering, does not resolve OQ-035 or OQ-036, and does not claim executable authentication proof.

## v1.2.1 Patch Scope

This patch changes no DEC status, meaning, numbering or gate. It only synchronises active-version metadata/related-document references with the v1.2.1 hygiene pack. DEC-292 and DEC-293 remain the only v1.2 semantic additions.

Statuses:

- `LOCKED`: approved for product and architecture planning;
- `PROVISIONAL`: current direction pending validation;
- `EXPERT REVIEW`: requires legal, clinical, accounting or other professional approval;
- `SUPERSEDED`: replaced by a later decision.
- `ARCHITECTURE REVIEW`: product direction is locked but implementation design is intentionally deferred.
- `VALIDATION REQUIRED`: provider or operational behaviour must be tested before implementation is fixed.

---

# GQ-001 — Ultimate Goal and Commercial Foundation

## DEC-001 — Platform category
**Status:** LOCKED
Build a Christian, temperament-guided holistic health, wellness, lifestyle and community ecosystem, initially for women.

## DEC-002 — Initial customer
**Status:** LOCKED
The initial commercial customer is an individual adult woman reached through the book, events, existing media platforms and public educational content.

## DEC-003 — Primary outcome
**Status:** LOCKED
Health, consistency and sustainable whole-person wellbeing take priority over weight loss.

## DEC-004 — Faith position
**Status:** LOCKED
The platform is openly Christian and available to everyone. It will not provide a configurable faith-free variant.

## DEC-005 — Future men’s product
**Status:** LOCKED
Men may later use the same technical platform through a separate product and content experience.

## DEC-006 — Public and paid access
**Status:** LOCKED
Generic educational content is public. Assessments, plans, selected content and recurring personalised benefits may require payment or entitlement.

## DEC-007 — Assessment product
**Status:** LOCKED
The digital assessment is paid, independently purchasable and includes a report plus introductory personalised guidance.

## DEC-008 — Book entitlements
**Status:** LOCKED
The standard physical book grants no automatic digital access. Selected bundles may grant named entitlements.

## DEC-009 — Standard plan
**Status:** LOCKED
The initial plan is a repeatable seven-day self-guided plan whose structure varies by temperament.

## DEC-010 — Programme expansion
**Status:** LOCKED
A longer foundation programme will launch incrementally after the initial plan is validated.

## DEC-011 — Clinical service levels
**Status:** LOCKED
Separate automated self-guided, premium automated and practitioner-reviewed pathways.

## DEC-012 — Clinical authority
**Status:** LOCKED
Venessa is the primary dietetic and nutrition authority. Doctors may be involved when matters exceed the dietetic boundary.

## DEC-013 — Community launch
**Status:** LOCKED
Validate community through Facebook first, then build a first-party community when product and moderation needs are proven.

## DEC-014 — Revenue milestones
**Status:** LOCKED
Use 500 paying members at R200 as the initial R100,000 gross MRR milestone and 5,000 members at R200 as the five-year R1,000,000 gross MRR target.

## DEC-015 — Operating entity
**Status:** PROVISIONAL / EXPERT REVIEW
Voelgoed Media is the provisional operating entity. A new dedicated company may be created.

## DEC-016 — Intellectual property
**Status:** EXPERT REVIEW
Lynette contributes the temperament model; Venessa contributes most health, nutrition and programme knowledge. Exact ownership and licences require formal agreement.

---

# GQ-002 — Users, Roles and Data Ownership

## DEC-017 — Public access and free accounts
**Status:** LOCKED
Public content may be read without an account. A person may create a free account or join the mailing list without purchasing.

## DEC-018 — Minimum age
**Status:** LOCKED
The initial platform is restricted to users aged 18 and older.

## DEC-019 — Account model
**Status:** LOCKED
Support individual accounts only at launch.

## DEC-020 — Purchaser separation
**Status:** LOCKED
Purchaser, recipient, participant and account holder are separate concepts.

## DEC-021 — Multiple roles
**Status:** LOCKED
One identity may hold multiple explicit, assignable, removable and auditable roles.

## DEC-022 — Staff roles
**Status:** LOCKED
Initial staff categories include Support, Finance, Platform Administrator, Super Admin, Content, Moderator, Data Analyst, Event Admin and Developer. Platform Administrator is the broad day-to-day platform administration role and ordinary operational role; Super Admin is exceptional break-glass and Developer is separate.

## DEC-023 — Founder access
**Status:** LOCKED
Venessa may hold separately scoped clinical, content and administrative roles. Lynette initially has a verified community-facing account without routine backend or health-data access.

## DEC-024 — Practitioner types
**Status:** LOCKED
Distinguish employed practitioners, contracted practitioners and external referral partners.

## DEC-025 — Practitioner data access
**Status:** LOCKED
Practitioner access requires explicit participant consent, an active relationship, defined scope and expiry, complete auditing and revocable future access.

## DEC-026 — Participant data principle
**Status:** LOCKED
The participant controls her personal health journey and may access, correct and export appropriate records.

## DEC-027 — Registration fields
**Status:** LOCKED
Require first name, surname, email, authentication credential, preferred language, 18+ confirmation and terms/privacy acceptance. Phone and city are optional. Preferred name is not required.

## DEC-028 — Multilingual launch
**Status:** LOCKED
Support Afrikaans and English from launch, ask for language on first entry, save it to the profile and allow switching from the header.

---

# GQ-003 — Products, Purchases, Memberships and Entitlements

## DEC-029 — Incremental delivery
**Status:** LOCKED
Model the approved long-term catalogue but implement products incrementally.

## DEC-030 — Product lifecycle
**Status:** LOCKED
Use `draft → internal → pilot → public → paused → retired`.

## DEC-031 — Existing temperament onboarding
**Status:** LOCKED
A qualifying plan purchase may include an assessment credit. A user may onboard with a self-reported or book-derived result and complete the online assessment later.

## DEC-032 — Temperament provenance
**Status:** LOCKED
Distinguish `self_reported`, `book_derived` and `digitally_assessed`.

## DEC-033 — Assessment history
**Status:** LOCKED
One paid attempt includes permanent report access. Preserve historical results and explicitly select one current profile.

## DEC-034 — Retake interval
**Status:** LOCKED
Permit no more than one assessment retake per year when a valid entitlement exists.

## DEC-035 — Premium reassessment
**Status:** LOCKED
One annual entitlement becomes available after 12 continuous premium months or annual renewal, does not accumulate and expires unused when membership ends.

## DEC-036 — Plan regeneration
**Status:** LOCKED
When the plan included the assessment credit, a materially different digital result permits one complimentary regeneration within 90 days.

## DEC-037 — Once-off plan access
**Status:** LOCKED
A once-off purchaser retains permanent access to the delivered plan and receives corrections and safety replacements.

## DEC-038 — Ongoing re-personalisation
**Status:** LOCKED
Preference- or progress-based re-personalisation, including macro and portion recalculation, requires a new purchase or active qualifying membership/add-on.

## DEC-039 — Membership billing
**Status:** SUPERSEDED IN PART BY DEC-315
Historical DEC-039 wording: "Support monthly and annual billing, no default free trial and cancellation at the end of the paid period." DEC-315 supersedes only the unconditional cancellation timing where an applicable non-waivable statutory consumer right requires another effective date. Monthly Membership remains a genuine month-to-month product without a minimum term; ordinary cancellation stops future renewal under the applicable monthly model, with paid-period access governed separately.

## DEC-040 — Membership and add-ons
**Status:** LOCKED
Basic membership is the base subscription. Add-ons grant recurring entitlements. Premium is a named bundle of basic membership plus add-ons.

## DEC-041 — Access after cancellation
**Status:** LOCKED
Purchased assessments, once-off plans and historical check-ins remain. Membership content, community and new adjustments end.

## DEC-042 — Monthly premium review
**Status:** LOCKED
A complete check-in is required. Reviews do not accumulate indefinitely. No-change counts as a review. Approved minor changes may be automated. Professional review remains separate.

## DEC-043 — Failed-payment lifecycle
**Status:** LOCKED / IMPLEMENTATION PROVISIONAL
Use a 72-hour grace period, clear communication, provider-safe retries and suspension after final failure. Final retry calls depend on Paystack testing.

## DEC-044 — Gifts and sponsored access
**Status:** LOCKED
The purchaser sees redemption status only. Codes expire after 12 months by default. Redeemed access is non-transferable.

## DEC-045 — Refund boundaries
**Status:** SUPERSEDED IN PART BY DEC-315
Historical DEC-045 wording: "Assessment refunds end after the first answer except technical failure; plan refunds end after generation; membership has no ordinary partial-period refund; event rules are versioned per event." DEC-315 supersedes only Membership's ordinary partial-period boundary to the extent an applicable non-waivable statutory right provides a cancellation, refund or credit. Assessment, Plan and Event rules remain unchanged as ordinary commercial boundaries and remain subject to any stronger applicable statutory right.

## DEC-046 — Upgrades and downgrades
**Status:** LOCKED
Upgrades are immediate with provider-supported proration. Downgrades take effect at renewal. Historical records remain accessible.

## DEC-047 — Payment provider and market
**Status:** SUPERSEDED BY DEC-292
Use Paystack initially, launch in South Africa and bill in ZAR.

**Historical note:** This provisional decision is retained verbatim as the pre-v1.2 position. DEC-292 promotes Paystack to the locked first/launch gateway while preserving provider-behaviour validation gates.

## DEC-048 — International cards and currencies
**Status:** LOCKED
Accept international cards when enabled. Do not assume true multi-currency charging through the initial South African Paystack integration.

## DEC-049 — Manual payments
**Status:** LOCKED
Manual EFT may be supported separately but does not create automatic renewal. Grant access only after payment verification.

## DEC-050 — Promotions and grants
**Status:** LOCKED
Support fixed and percentage discounts, event-linked discounts, promotional pricing, book and gift codes, complimentary access, sponsored access and explicitly scoped lifetime access.

---


# GQ-004 — Temperament Assessment, Scoring and Reports

## DEC-051 — Methodology authority
**Status:** SUPERSEDED IN PART BY DEC-309
Historical DEC-051 wording, superseded in part by DEC-309: “Only Venessa and Super Admin, acting under the intellectual-property agreement, may approve or alter assessment methodology.” Current methodology authority is established by DEC-309 and the governing IP agreement, not by this former role assignment.

## DEC-052 — Initial assessment fidelity
**Status:** LOCKED
Launch with a faithful, versioned digital representation of the approved book assessment.

## DEC-053 — Required answers and feedback
**Status:** LOCKED
All scored questions are required. Optional feedback questions remain separate from scoring.

## DEC-054 — Save, resume and attempt limit
**Status:** LOCKED
Support save and resume, one active attempt at a time and controlled recovery for genuine technical failure.

## DEC-055 — Entitlement consumption
**Status:** SUPERSEDED IN PART BY DEC-313
Historical DEC-055 wording: "Do not consume the entitlement until the first answer is saved. Mark it used once the attempt begins." For paid digital Assessment credits governed by Product Law §21R.6, DEC-313 supersedes this first-answer consumption meaning. Other right types remain governed by their applicable current Product authority.

## DEC-056 — Attempt expiry
**Status:** LOCKED
Unfinished attempts expire after 30 days with advance warning.

## DEC-057 — Launch scoring
**Status:** LOCKED
Use equal weighting initially while permitting future versioned question and answer weights.

## DEC-058 — Primary and secondary results
**Status:** SUPERSEDED IN PART BY DEC-306
Historical rule: Highest score is primary, second-highest is secondary and exact colour scores are shown. DEC-306 supersedes the fixed highest/second-highest ordering and clarifies score display. Current digital result representation and ordering follow DEC-306 and Product Law §21B.5.

## DEC-059 — Tie workflow
**Status:** LOCKED
Use approved tie-break questions and rules first. Preserve an equal mixed result when unresolved. Record participant preference separately. Manual review is exceptional.

## DEC-060 — Score-distance labels
**Status:** LOCKED / METHODOLOGY GATE
Do not enable dominance-strength, balanced, close-result or mixed-distance labels until exact thresholds are approved.

## DEC-061 — Immutable raw result
**Status:** LOCKED
Submitted answers, calculated scores and assessment version are immutable.

## DEC-062 — Reviewed interpretation
**Status:** LOCKED
An exceptional change creates a separate audited reviewed interpretation and never overwrites the raw result.

## DEC-063 — Current profile selection
**Status:** LOCKED
The participant selects the current eligible profile. Staff may assist only with consent and audit. New digital results do not become current automatically.

## DEC-064 — Self-reported result use
**Status:** LOCKED
Self-reported and book-derived results may drive presentation and low-risk temperament adjustments but must be clearly labelled.

## DEC-065 — Assessment report scope
**Status:** LOCKED
The paid report covers scores, strengths, vulnerabilities, stress, health patterns, communication, practical strategies, faith reflection, next product and limitations.

## DEC-066 — Historical reports
**Status:** LOCKED
Preserve the original delivered report and provide the latest approved interpretation where wording improves.

## DEC-067 — Version immutability
**Status:** LOCKED
Completed results remain immutable. Active short-lived attempts may finish on the original version. Retired versions cannot start new attempts.

## DEC-068 — Language versions
**Status:** LOCKED
Afrikaans and English are separately governed language variants of one methodological version.

## DEC-069 — Assessment publication workflow
**Status:** LOCKED
Use draft, methodology approval, health review where affected, language review, admin publication, active and retired states.

## DEC-070 — Submitted-answer retention
**Status:** LOCKED
Retain submitted answers immutably for reproducibility. Participants may view their answers. Staff access is restricted and audited.

## DEC-071 — Cross-product reuse
**Status:** LOCKED
The underlying temperament result may be reused across approved product families, each with its own interpretations and recommendations.

## DEC-072 — Assessment analytics
**Status:** LOCKED
Permit privacy-controlled aggregated assessment analytics without identifiable public disclosure.



# GQ-005 — Health Onboarding, Eligibility and Safety

## DEC-073 — Progressive health onboarding
**Status:** LOCKED
Collect health information progressively by product purpose rather than during account registration.

## DEC-074 — Required plan intake
**Status:** LOCKED
Require a safety-focused structured health and lifestyle intake before automated personalised-plan generation.

## DEC-075 — Full date of birth
**Status:** LOCKED
Require full date of birth during plan onboarding, not ordinary registration.

## DEC-076 — Health-data provenance
**Status:** LOCKED
Record member-reported, document-uploaded, practitioner-entered, practitioner-verified and laboratory-verified provenance.

## DEC-077 — Missing and withheld information
**Status:** LOCKED
Support `unknown`, `not_tested` and `prefer_not_to_answer` where safe. Missing safety-critical information produces `insufficient_information`.

## DEC-078 — Eligibility outcomes
**Status:** LOCKED
Use `eligible_automated`, `general_wellness_only`, `professional_review_required` and `insufficient_information`.

## DEC-079 — High-risk blockers
**Status:** LOCKED / CLINICAL GATE
Approved high-risk rules block automated personalised plans. The final blocker matrix requires clinical approval before launch.

## DEC-080 — Moderate-risk routing
**Status:** LOCKED / CLINICAL GATE
Use approved automated routing with General Wellness support, clarification and manual escalation.

## DEC-081 — Eating-disorder boundary
**Status:** LOCKED
Active or recent cases block automated plans. Older stable history requires professional review.

## DEC-082 — Pregnancy and breastfeeding
**Status:** LOCKED
Require professional review before personalised eating plans while permitting the General Wellness Starter Pathway.

## DEC-083 — Food-exclusion classification
**Status:** LOCKED
Separate medical allergies, intolerances, religious exclusions, ethical exclusions, dislikes and preferences.

## DEC-084 — Medication boundary
**Status:** LOCKED
Collect the structured minimum required for safety, automate only professionally approved rules and route unclear or complex cases to review.

## DEC-085 — Supplement boundary
**Status:** LOCKED
Manage supplements separately. Dosage, deficiency, interaction, pregnancy and complex-use guidance require approved rules or professional review.

## DEC-086 — Laboratory-result validity
**Status:** LOCKED / CLINICAL GATE
Keep results historically while applying clinically approved test-specific validity periods for current decisions.

## DEC-087 — Progress-entry frequency
**Status:** LOCKED
Permit daily or weekly progress entries, but ordinary plan adjustments occur monthly using trends rather than fluctuations or isolated measurements.

## DEC-088 — Progress photographs
**Status:** LOCKED
Progress photographs are optional and require separate privacy controls.

## DEC-089 — Automatic safety suspension
**Status:** LOCKED
Approved new high-risk information places an active plan into `safety_paused`; history remains visible while new adjustments stop.

## DEC-090 — Safety-case lifecycle
**Status:** LOCKED
Use `detected`, `awaiting_information`, `participant_action_required`, `professional_review_required`, `under_professional_review`, `cleared`, `restricted` and `resolved`.

## DEC-091 — Clinical override
**Status:** LOCKED
Create a scoped, time-bound and audited override without replacing the original automated outcome.

## DEC-092 — High-risk downgrade approval
**Status:** LOCKED
Lowering high-risk status to automated eligibility requires a second authorised clinical approval or an approved single-practitioner protocol.

## DEC-093 — Practitioner-review outcomes
**Status:** LOCKED
Record structured outcomes for approval, modification, practitioner-authored plans, restrictions, follow-up, decline and external referral.

## DEC-094 — Purpose-specific permissions
**Status:** LOCKED
Separate service delivery, health storage, personalisation, automated recommendations, uploads, practitioner sharing, analytics, marketing and community permissions.

## DEC-095 — Emergency boundary
**Status:** LOCKED / EXPERT REVIEW
Stop unsafe automation, display approved urgent-help instructions and never imply continuous clinical monitoring. Final wording and protocols require professional and legal review.



# GQ-006 — Plan Generation, Lifecycle and Adjustments

## DEC-096 — Deterministic plan engine
**Status:** LOCKED
Use a deterministic, versioned rule engine built from approved calculations, templates, substitutions and content.

## DEC-097 — Extensible goal catalogue
**Status:** LOCKED
Launch with health foundation, weight reduction and weight maintenance while allowing future approved pathways without redesign.

## DEC-098 — Weight gain distinction
**Status:** LOCKED
General weight gain may later be automated; clinical weight restoration remains separately governed.

## DEC-099 — Versioned calculation protocols
**Status:** LOCKED / CLINICAL GATE
Use explicit approved formulas, limits, rounding, allocation, exclusions and escalation rules.

## DEC-100 — Energy units
**Status:** LOCKED
Display kilojoules by default and support a saved Calories/kilocalories toggle from launch using one authoritative underlying value.

## DEC-101 — Numerical presentation
**Status:** LOCKED
Vary participant-facing numerical detail according to product and safety rules while retaining exact internal targets.

## DEC-102 — Weight-reduction limits
**Status:** LOCKED / CLINICAL GATE
Use approved bounded deficits, minimum energy limits, rate guardrails and trend-based adjustment.

## DEC-103 — Meal frequency
**Status:** LOCKED
Support approved three- or four-meal structures and exclude fasting from ordinary automated plans.

## DEC-104 — Modular plan composition
**Status:** LOCKED
Use approved modular meal slots, portions, recipes, alternatives, preparation and shopping support.

## DEC-105 — Substitution groups
**Status:** LOCKED
Permit only approved, versioned equivalence substitutions that enforce exclusions.

## DEC-106 — Temperament boundary
**Status:** LOCKED
Temperament affects behavioural delivery and presentation, not safety or nutritional truth.

## DEC-107 — Immutable plan snapshots
**Status:** LOCKED
Every generation and adjustment creates an immutable, reproducible, linked plan version.

## DEC-108 — Layered explainability
**Status:** LOCKED
Provide participant-facing reasons and retain exact internal rule and input traces.

## DEC-109 — Generation failure
**Status:** LOCKED
Fail closed, preserve entitlements and prevent partial plans, duplicate generation and double charging.

## DEC-110 — Plan lifecycle
**Status:** LOCKED
Use pending, generated, review, approval, scheduled, active, safety-paused, completed, superseded and withdrawn states.

## DEC-111 — Activation
**Status:** LOCKED
Permit immediate or approved near-term start with revalidation when information or timing becomes stale.

## DEC-112 — Formal review entitlement
**Status:** LOCKED
Allow one review per qualifying entitlement period after minimum plan exposure and a complete check-in.

## DEC-113 — Missed review
**Status:** LOCKED
Do not adjust from incomplete data; continue the safe current plan and let the unused review expire after a defined grace period.

## DEC-114 — Structured review outcomes
**Status:** LOCKED
Use explicit outcomes for unchanged, presentation, substitutions, portions, macros, meal frequency, simplification, variety, safety pause and professional review.

## DEC-115 — Trend-based recalculation
**Status:** LOCKED / CLINICAL GATE
Adjust only from sufficient trends beyond approved fluctuation tolerance and within protocol limits.

## DEC-116 — Conflicting participant requests
**Status:** LOCKED
Record and explain requests that conflict with safety, offer approved alternatives and escalate where needed.

## DEC-117 — Practitioner-derived plans
**Status:** LOCKED
Professional changes create a new immutable practitioner-derived version rather than editing the automated source.

## DEC-118 — Shared bilingual plan logic
**Status:** LOCKED
Share calculations and logic while using separately approved Afrikaans and English content variants.

## DEC-119 — Layered translation architecture
**Status:** LOCKED / ARCHITECTURE DETAIL PENDING
Use Gettext for fixed UI and system strings, Ash-backed resources for governed runtime content and immutable references to delivered translation versions.

## DEC-120 — Recipes and shopping lists
**Status:** LOCKED
Use approved reusable recipes and generate shopping lists from the immutable plan snapshot.

## DEC-121 — Corrections and withdrawal
**Status:** LOCKED
Preserve history while issuing governed corrections, replacements and safety withdrawals without consuming a new entitlement.

## DEC-122 — Plan analytics
**Status:** LOCKED
Use governed events and precomputed aggregates, with Redis for suitable operational counters and PostgreSQL for durable truth.



# GQ-007 — Content, Translation and Personalised Feeds

## DEC-123 — Source-language strategy
**Status:** LOCKED
Content may originate in Afrikaans or English while recording the source locale and version relationship.

## DEC-124 — Risk-based bilingual publication
**Status:** LOCKED; SUPERSEDED IN PART BY DEC-316 FOR GOVERNING TERMS AND PRIVACY DOCUMENT BODIES ONLY
Require both languages for paid, contractual, assessment, plan, clinical, safety and core-onboarding content; permit explicit single-language availability for optional low-risk editorial content.

Historical DEC-124 remains in force except for the governing Terms and Privacy document bodies. DEC-316 supersedes it in part only to the extent DEC-124 would require an Afrikaans version of those governing legal document bodies. All other DEC-124 bilingual publication requirements remain unchanged.

## DEC-125 — Translation lifecycle
**Status:** LOCKED
Use independently governed missing, draft, machine-draft, review, approval, publication, superseded and withdrawn states.

## DEC-126 — Machine translation
**Status:** LOCKED
Machine translation may create drafts only and never publishes without required human and clinical review.

## DEC-127 — Multilingual content structure
**Status:** LOCKED
Use shared conceptual content with immutable content and translation versions rather than unrelated records or one JSON translation blob.

## DEC-128 — Controlled content types
**Status:** LOCKED
Use an approved extensible catalogue for articles, lessons, devotionals, recipes, instructions, interpretations, safety notices, FAQs, product pages, event pages, sessions and downloads.

## DEC-129 — Content risk classes
**Status:** LOCKED
Use editorial, health-education, personalisation, clinical, safety-critical and legal-or-consent risk classes.

## DEC-130 — Scoped approval matrix
**Status:** LOCKED
Approval authority follows content risk, language and professional scope, with each approval recorded separately.

## DEC-131 — Explainable feed ranking
**Status:** LOCKED
Use deterministic ranking from approved signals while allowing broader browsing.

## DEC-132 — Derived relevance flags
**Status:** LOCKED
Use minimum derived relevance flags rather than copying full diagnoses or clinical details into feed infrastructure.

## DEC-133 — Feed controls
**Status:** LOCKED
Provide explanation, save, dismiss, topic controls, full browsing and reset while preventing permanent hiding of applicable safety content.

## DEC-134 — Translation fallback
**Status:** LOCKED
Permit explicit fallback for optional low-risk content and block delivery of paid or safety-sensitive content without approved required translations.

## DEC-135 — Immutable content versions
**Status:** LOCKED
Every material edit creates a new immutable and traceable content version.

## DEC-136 — Scheduled automatic publication
**Status:** LOCKED
Permit reliable future auto-publication with pre-publication revalidation, idempotency, observability and failure alerts.

## DEC-137 — Correction classes
**Status:** LOCKED
Use minor, material, safety, legal-or-consent and full-withdrawal correction classes with proportional handling.

## DEC-138 — Attribution
**Status:** LOCKED
Separate internal authorship and approval responsibility from selected public attribution.

## DEC-139 — Governed taxonomy
**Status:** LOCKED
Use controlled, versioned taxonomy groups with aliases and reviewed changes.

## DEC-140 — Search ranking
**Status:** LOCKED
Use access-controlled layered deterministic search; semantic ranking may later act only as a governed secondary signal.

## DEC-141 — Bilingual SEO
**Status:** LOCKED
Use explicit locale-specific public URLs, language alternates, per-language canonicals and permanent redirects for slug changes.

## DEC-142 — Reusable content blocks
**Status:** LOCKED
Reuse approved versioned blocks while preserving exact immutable delivery snapshots.

## DEC-143 — Governed media
**Status:** LOCKED
Store media metadata, rights, accessibility, versions, checksums and publication state separately from text content.

## DEC-144 — Protected asset delivery
**Status:** LOCKED
Use entitlement checks and short-lived signed access for protected downloads, reports and recordings.

## DEC-145 — Minimum content analytics
**Status:** LOCKED
Collect governed minimum events without creating a shadow health record or ingesting journals by default.

## DEC-146 — Cloudflare and layered caching
**Status:** LOCKED / ARCHITECTURE DETAIL PENDING
Use Cloudflare for suitable edge delivery together with ETS or Cachex, Redis and PostgreSQL; optimise Ash and PostgreSQL queries while prohibiting unsafe public caching of private or personalised content.



# GQ-008 — Programmes, Habits, Journals and Progress

## DEC-147 — Reusable programme structure
**Status:** LOCKED
Use Programme, ProgrammeVersion, Module, Lesson and Activity as the reusable conceptual hierarchy.

## DEC-148 — Programme catalogue and lifecycle
**Status:** LOCKED
Use an approved extensible programme catalogue with draft, internal, pilot, public, paused and retired states.

## DEC-149 — Delivery modes
**Status:** LOCKED
Support evergreen self-paced, scheduled cohort and facilitated cohort delivery, launching primarily evergreen.

## DEC-150 — Programme entitlements
**Status:** LOCKED
Access follows explicit public, free, membership, add-on, purchase, bundle, sponsored or practitioner-assigned entitlements.

## DEC-151 — Guided progression and pacing
**Status:** LOCKED
Use explicit prerequisites and recommended pacing without punitive failure for ordinary delay.

## DEC-152 — Enrolment history
**Status:** LOCKED
Preserve enrolment attempts, pauses, restarts and completions without deleting progress or silently consuming entitlements.

## DEC-153 — Activity requirement types
**Status:** LOCKED
Use required-for-progression, required-for-completion, required-for-safety, recommended, optional and conditional activity types.

## DEC-154 — Recovery model
**Status:** LOCKED
Preserve progress and provide catch-up, rescheduling, simplification and supportive recovery rather than resets.

## DEC-155 — Completion rules
**Status:** LOCKED
Use versioned participation-based completion rules that do not require weight loss, perfect adherence or uninterrupted streaks.

## DEC-156 — Programme-version migration
**Status:** LOCKED
Keep active enrolments on their version unless governed migration or safety correction applies.

## DEC-157 — Programme temperament boundary
**Status:** LOCKED
Temperament changes behavioural delivery, not health facts, safety or professional restrictions.

## DEC-158 — Habit catalogue
**Status:** LOCKED
Use approved habits plus participant-created low-risk habits and distinguish practitioner-assigned habits.

## DEC-159 — Habit schedules
**Status:** LOCKED
Use controlled daily, weekday, weekly, times-per-week, date-specific and programme-relative schedules.

## DEC-160 — Habit occurrence states
**Status:** LOCKED
Use pending, completed, partial, intentional skip, missed, not applicable and safety blocked.

## DEC-161 — Compassionate consistency
**Status:** LOCKED
Use trend and recovery indicators rather than streaks that reset after one missed day.

## DEC-162 — Reminder controls
**Status:** LOCKED
Use participant-controlled, timezone-aware reminders with quiet hours, caps, pause and supportive language.

## DEC-163 — Accountability sharing
**Status:** LOCKED
Allow optional scoped, expiring and revocable sharing of selected progress without default journal or health access.

## DEC-164 — Journal entry types
**Status:** LOCKED
Support free, guided, programme, gratitude, faith, hunger, setback and practitioner-shared entry types.

## DEC-165 — Journal privacy
**Status:** LOCKED
Keep journals private by default and permit entry-specific practitioner sharing with consent, scope, expiry and audit.

## DEC-166 — Journal monitoring boundary
**Status:** LOCKED
Do not promise continuous free-text monitoring; use explicit structured safety pathways.

## DEC-167 — AI journal assistance
**Status:** LOCKED / DEFERRED
Any future AI summary is participant-initiated, scoped, labelled, non-diagnostic and outside the MVP.

## DEC-168 — Progress recognition
**Status:** LOCKED
Use private, health-aligned milestones, optional badges and completion certificates without weight rankings or shame.

## DEC-169 — Programme analytics
**Status:** LOCKED
Collect governed behavioural events and aggregates while excluding journal text and unnecessary health detail.

# GQ-009 — Community, Challenges, Live Sessions and Events

## DEC-170 — Community rollout
**Status:** LOCKED
Launch through a governed Facebook group and migrate to first-party community only when explicit readiness criteria are met.

## DEC-171 — Community entitlement
**Status:** LOCKED
Grant community access through an explicit qualifying membership, bundle, sponsored, pilot, staff or practitioner entitlement.

## DEC-172 — Community identity
**Status:** LOCKED
Maintain private account identity while permitting a controlled public display name and verified staff/practitioner badges.

## DEC-173 — Profile privacy
**Status:** LOCKED
Expose only participant-selected community fields and keep health, plan, journal, practitioner and purchase data private by default.

## DEC-174 — Participation policies
**Status:** LOCKED
Use group-specific read-only, staff-post/member-comment, moderated member-post, immediate member-post and facilitated-discussion permissions.

## DEC-175 — Sensitive disclosures
**Status:** LOCKED
Permit general wellbeing discussion while warning, redirecting or moderating highly sensitive health and personal disclosures.

## DEC-176 — Peer health-advice boundary
**Status:** LOCKED
Allow personal experience but prohibit diagnosis, medication changes, dosing, dangerous restriction and presenting unverified claims as platform advice.

## DEC-177 — Moderation lifecycle
**Status:** LOCKED
Use structured report, triage, review, action, appeal and closure states with secure evidence retention.

## DEC-178 — Member reporting
**Status:** LOCKED
Use structured report categories, protect reporter identity and prioritise urgent safety/privacy categories.

## DEC-179 — Severity-based sanctions
**Status:** LOCKED
Use education, warning, posting restriction, suspension and ban, with immediate severe-action capability.

## DEC-180 — Moderation appeals
**Status:** LOCKED
Permit one governed appeal per eligible decision, independently reviewed where possible.

## DEC-181 — Direct messaging
**Status:** LOCKED
Exclude unrestricted member messaging initially and require consent, safety, reporting and moderation controls before any future release.

## DEC-182 — Former-member content
**Status:** LOCKED
End active participation when entitlement ends while preserving governed discussion/moderation history subject to deletion and anonymisation rules.

## DEC-183 — Challenge definitions
**Status:** LOCKED
Use governed reusable challenge modes with explicit eligibility, privacy, safety, completion, facilitation and entitlement.

## DEC-184 — Challenge metrics
**Status:** LOCKED
Use private progress and safe optional group recognition; prohibit public weight, calorie-restriction and body-measurement competition.

## DEC-185 — Challenge safety
**Status:** LOCKED
Pause or restrict unsafe activities privately, offer safe alternatives and allow exit without penalty.

## DEC-186 — Live-session access
**Status:** LOCKED
Use entitlement-aware registration, capacity, waitlists, protected joining instructions and privacy-preserving attendance.

## DEC-187 — Group Q&A
**Status:** LOCKED
Use moderated educational Q&A and redirect private diagnosis, prescription and treatment requests to professional pathways.

## DEC-188 — Recording governance
**Status:** LOCKED
Require explicit recording notice, participant controls, governed editing, replay entitlements, versioning, correction and clip approval.

## DEC-189 — Restream launch direction
**Status:** PROVISIONAL / VALIDATION REQUIRED
Use Restream provisionally for production and multistream distribution, subject to plan, reliability and operational validation.

## DEC-190 — Platform live-video path
**Status:** LOCKED / ARCHITECTURE DETAIL PENDING
Prefer Restream → custom RTMPS → Cloudflare Stream → entitlement-controlled platform player with governed automatic replay records.

## DEC-191 — Event structure
**Status:** LOCKED
Use Event → EventVersion → EventOccurrence → TicketType → TicketEntitlement as the reusable conceptual model.

## DEC-192 — Capacity reservations
**Status:** LOCKED
Use short-lived idempotent transactional reservations, verified payment confirmation, expiry and waitlists to prevent confirmed overselling.

## DEC-193 — Ticket identity and states
**Status:** LOCKED
Separate purchaser, ticket holder and attendee and use governed reservation, payment, issue, transfer, check-in, cancellation, refund, credit, expiry and void states.

## DEC-194 — Event policy
**Status:** LOCKED
Use versioned event-specific cancellation, transfer, credit, postponement, format-change, force-majeure and bundled-entitlement rules accepted before checkout.

## DEC-195 — Community/event analytics
**Status:** LOCKED
Collect minimum operational events and aggregates without duplicating sensitive post or health content; durable moderation, ticket and entitlement truth remains authoritative.



# GQ-NY-001 — Nuwe Jy Flagship Product

## DEC-196 — Nuwe Jy product definition
**Status:** LOCKED
Nuwe Jy is a guided transformation programme delivered through a 60-day challenge experience, not a conventional LMS course.

## DEC-197 — Release priority
**Status:** LOCKED
Build Nuwe Jy as the first flagship vertical expansion after the core account, assessment, safety, payment, entitlement and plan foundation.

## DEC-198 — Delivery mode
**Status:** LOCKED
Use scheduled cohorts as the flagship mode and support a later evergreen edition.

## DEC-199 — Sixty-day meaning
**Status:** LOCKED
Use a 60-calendar-day guided rhythm with catch-up and recovery rather than punitive reset or false automatic completion.

## DEC-200 — Today experience
**Status:** LOCKED
Provide a dedicated Today view for focus, lesson, action, habit, reflection, live/community activity, progress and recovery.

## DEC-201 — Daily drip release
**Status:** LOCKED
Prepare all 60 days in advance and release content automatically by edition schedule with timezone awareness, idempotency, observability and recovery.

## DEC-202 — Day composition
**Status:** LOCKED
Use controlled composable day components rather than one generic lesson or an unrestricted page builder.

## DEC-203 — Temperament delivery
**Status:** LOCKED
Use temperament to adapt behavioural delivery while preserving shared health, faith, safety and programme truth.

## DEC-204 — Nuwe Jy progress
**Status:** LOCKED
Use private multi-dimensional progress and prohibit weight-led or fastest-completion competition.

## DEC-205 — Cohort community
**Status:** LOCKED
Give each flagship edition a governed cohort community, initially through Facebook and later through the first-party platform.

## DEC-206 — Live sessions
**Status:** LOCKED
Link sessions, registration, attendance and governed replays directly to the challenge edition and cohort.

## DEC-207 — Build-from-scratch boundary
**Status:** LOCKED
Do not build a LearnDash importer, converter or compatibility layer and do not preserve LearnDash structures as domain truth.

## DEC-208 — Progressive challenge onboarding
**Status:** LOCKED
Require account, age, consent, essential safety screening, language and temperament provenance before participation, with deeper plan intake separately.

## DEC-209 — Nuwe Jy safety routing
**Status:** LOCKED
Use full-challenge, safe-modification, general-wellness-only, professional-review and insufficient-information outcomes.

## DEC-210 — Purchaser/participant separation
**Status:** LOCKED
Keep purchaser, intended recipient, redeemed participant and enrolment separate, with no purchaser access to the participant’s private journey.

## DEC-211 — Edition creation
**Status:** LOCKED
Create each edition from an approved programme version and validate content, translations, schedules, sessions, safety, facilitation, products, community and communications before activation.

## DEC-212 — Late enrolment
**Status:** LOCKED
Use an edition-specific late-enrolment policy and guided catch-up while keeping participants on the shared cohort schedule.

## DEC-213 — Scoped Nuwe Jy roles
**Status:** LOCKED
Separate challenge owner, programme admin, cohort manager, facilitator, moderator, host, support, clinical reviewer and analyst access.

## DEC-214 — Nuwe Jy check-ins
**Status:** LOCKED
Use lightweight daily interactions with deeper versioned milestone check-ins and keep journals separate.

## DEC-215 — Support routing
**Status:** LOCKED
Use deterministic self-service, recovery, support, professional-review and safety outcomes without implying unlimited coaching.

## DEC-216 — Central plan integration
**Status:** LOCKED
Use the platform’s authoritative safety and plan system and never create a separate Nuwe Jy nutrition engine.

## DEC-217 — Completion and certification
**Status:** LOCKED
Use versioned compassionate completion outcomes and certificates that state participation or completion only.

## DEC-218 — Edition communications/operations
**Status:** LOCKED
Use preconfigured language- and timezone-aware deduplicated communications and role-scoped operational dashboards.

## DEC-219 — Analytics and clean cutover
**Status:** LOCKED
Use health-aligned analytics, preserve repeat-enrolment history and move from LearnDash through a clean future-edition cutover rather than technical migration.



# GQ-010 — Privacy, Records and Data Lifecycle

## DEC-220 — Shared lifecycle vocabulary
**Status:** LOCKED
Use shared active, archived, restricted, deletion, anonymisation, retained-obligation and legal-hold states with category-specific applicability.

## DEC-221 — Account closure versus deletion
**Status:** LOCKED
Provide recoverable account closure separately from irreversible full deletion.

## DEC-222 — Destructive-action verification
**Status:** LOCKED
Use risk-based step-up verification for closure, deletion and sensitive exports without collecting unnecessary health or identity-document data.

## DEC-223 — Recovery and cancellation windows
**Status:** LOCKED
Use a 30-day recoverable account-closure window and a 14-day full-deletion cancellation window; completed deletion has no recovery or reconstruction path.

## DEC-224 — Assessment deletion
**Status:** LOCKED
Preserve immutability while records exist, then delete or irreversibly anonymise eligible identifiable answers, scores and reports during full deletion.

## DEC-225 — Purchased-access consequence
**Status:** LOCKED
Full deletion permanently ends participant access to reports, plans, programmes, progress and entitlements; retained financial records cannot restore them.

## DEC-226 — Health-record separation
**Status:** LOCKED
Delete or anonymise self-guided health records while restricting formal professional records only for approved professional retention.

## DEC-227 — Journal deletion
**Status:** LOCKED
Prioritise deletion of private journal content, attachments and derived artefacts while separately governing professional copies.

## DEC-228 — Complete asset deletion
**Status:** LOCKED
Delete original files, derivatives, previews, extracted values, indexes, cached links and temporary processing artefacts.

## DEC-229 — Professional record governance
**Status:** LOCKED
Make professional records participant-accessible but correction- and retention-controlled by authorised professional recordkeeping authority.

## DEC-230 — Community deletion/anonymisation
**Status:** LOCKED
Use content-sensitive deletion or anonymisation while preserving restricted moderation evidence and independently authored context.

## DEC-231 — Restricted commercial retention
**Status:** LOCKED
Retain only required financial and dispute evidence, isolated from product use and unusable for account reconstruction.

## DEC-232 — Consent withdrawal
**Status:** LOCKED
Stop affected processing, recalculate dependent access and invalidate caches, permissions and derived signals.

## DEC-233 — Audit retention
**Status:** LOCKED
Use immutable, minimised, restricted and category-specific audit retention without copying full sensitive payloads.

## DEC-234 — Security-event retention
**Status:** LOCKED
Retain minimised security/fraud evidence under security-specific identifiers for an approved period.

## DEC-235 — Analytics deletion
**Status:** LOCKED
Remove identifiable participant-level analytics and retain only irreversibly aggregated statistics with suppression controls.

## DEC-236 — Inactive-account lifecycle
**Status:** LOCKED
Use warning, dormancy, restricted archive and eventual deletion/anonymisation stages with entitlement-aware notices.

## DEC-237 — Deceased-participant process
**Status:** LOCKED
Require verified authority, freeze access and provide no automatic relative access to private records.

## DEC-238 — Scoped legal holds
**Status:** LOCKED
Hold only necessary records, restrict ordinary use, review regularly and resume deletion when the hold ends.

## DEC-239 — Backup deletion boundary
**Status:** LOCKED
Allow deleted data only until normal encrypted backup expiry and require replay of deletion events after restoration; backups cannot recover accounts.

## DEC-240 — Participant export
**Status:** LOCKED
Provide secure, verified, asynchronous human-readable and structured exports with expiring delivery.

## DEC-241 — Record corrections
**Status:** LOCKED
Use direct updates only where appropriate and additive or superseding corrections for immutable, professional and financial records.

## DEC-242 — Incident records
**Status:** LOCKED
Maintain minimised, restricted incident records with linked evidence rather than duplicated sensitive datasets.

## DEC-243 — Retention governance/deletion completion
**Status:** LOCKED
Use approved versioned per-category retention policies and consider deletion complete only after live, derived, cached, external and access paths are processed and no recovery remains.



# GQ-011 — Identity, Security, Notifications and Operations

## DEC-244 — Participant authentication
**Status:** LOCKED
Launch with email/password plus optional magic-link sign-in; defer social login and keep passkeys as a future extension.

## DEC-245 — Email verification gates
**Status:** LOCKED
Permit limited onboarding before verification and require verified email before paid, assessment, health, plan, community, export and deletion capabilities.

## DEC-246 — Participant MFA
**Status:** LOCKED
Make MFA optional for participants while requiring step-up authentication for high-risk actions.

## DEC-247 — Staff/practitioner MFA
**Status:** LOCKED
Require MFA for every privileged user, prohibit shared accounts and govern resets.

## DEC-248 — Session policy
**Status:** LOCKED
Use role- and risk-based inactivity and absolute expiry with user-visible session revocation.

## DEC-249 — Trusted devices
**Status:** LOCKED
Use consented, expiring and revocable device trust that never bypasses high-risk step-up checks.

## DEC-250 — Account recovery
**Status:** LOCKED
Use graduated automated and manual recovery with holds, notifications and stronger privileged-user review.

## DEC-251 — Primary-email change
**Status:** LOCKED
Require reauthentication, new-address confirmation, old-address notice, audit and risk-based delay/session handling.

## DEC-252 — Duplicate-account merge
**Status:** LOCKED
Use verified domain-aware merging that preserves immutable history and original commercial/professional provenance.

## DEC-253 — Compromise containment
**Status:** LOCKED
Use active session/device revocation, sensitive-action freezing, verified recovery and minimised incident evidence.

## DEC-254 — Privileged grants
**Status:** LOCKED
Use scoped, reasoned, approved, reviewable and revocable grants under least privilege.

## DEC-255 — Break-glass access
**Status:** LOCKED
Use named, MFA-protected, time-limited, alerted and post-reviewed emergency access with no shared credentials.

## DEC-256 — Authentication abuse controls
**Status:** LOCKED
Use Cloudflare, application limits, Redis velocity counters and risk signals across registration, login and recovery paths.

## DEC-257 — Redemption abuse
**Status:** LOCKED
Use strong codes, distributed throttling, explicit usage limits, idempotent redemption and fraud escalation.

## DEC-258 — Payment abuse
**Status:** LOCKED
Use verified idempotent provider webhooks, platform risk controls and one-time entitlement granting.

## DEC-259 — Upload security
**Status:** LOCKED
Use restricted temporary upload, content validation, malware scanning, sanitisation and governed durable access.

## DEC-260 — Scraping controls
**Status:** LOCKED
Protect authenticated and paid data while preserving intended public crawlability and SEO.

## DEC-261 — Notification channels
**Status:** LOCKED
Use channel-capable architecture with email and in-app first; activate SMS/WhatsApp later and defer native push.

## DEC-262 — Notification preferences
**Status:** LOCKED
Use category/channel preferences, quiet hours, frequency caps, marketing-consent separation and governed mandatory notices.

## DEC-263 — Notification delivery
**Status:** LOCKED
Use durable Oban-backed idempotent, deduplicated, retryable and observable delivery.

## DEC-264 — Graceful degradation
**Status:** LOCKED
Use read-only, limited-capability and full-maintenance modes while never guessing health, entitlement or payment truth.

## DEC-265 — Backup tiers
**Status:** LOCKED
Use criticality-based backup/restore classes with later architecture-defined RPO/RTO and mandatory restore testing.

## DEC-266 — Incident severity
**Status:** LOCKED
Use SEV-1 through SEV-4 with named ownership, containment, communication, remediation and review.

## DEC-267 — Operational observability
**Status:** LOCKED
Monitor infrastructure, application and domain outcomes, use priority Oban queues, bounded retries and explicit provider-outage handling.

# GQ-012 — Launch Scope, Product Spaces, Pilot, Pricing and Go/No-Go

## DEC-268 — Controlled product spaces
**Status:** LOCKED
Use one operating platform with controlled product spaces rather than a permanent women-only codebase, unrestricted generic SaaS tenancy or fully separate applications.

## DEC-269 — Launch-facing product space
**Status:** LOCKED
Expose only the women’s health and lifestyle product space at first launch; future men’s, specialist, professional or partner spaces remain invisible until deliberately activated.

## DEC-270 — South Africa first
**Status:** LOCKED
Launch South Africa first with ZAR, Afrikaans/English and Africa/Johannesburg defaults while keeping reusable domain logic suitable for controlled future market activation.

## DEC-271 — Core MVP loop
**Status:** LOCKED
The first commercially usable MVP proves public discovery → account → checkout → temperament → report → safety intake → eligibility → personalised seven-day plan or General Wellness → purchased library → lightweight progress/support.

## DEC-272 — MVP temperament provenance
**Status:** LOCKED
Support self_reported, book_derived and digitally_assessed provenance in the MVP, clearly labelled, with the digital assessment remaining the authoritative platform assessment product.

## DEC-273 — Initial commercial catalogue
**Status:** LOCKED
Launch with only Digital Temperament Assessment, 7-Day Personalised Plan and Assessment + Plan Bundle.

## DEC-274 — Nuwe Jy first flagship expansion
**Status:** LOCKED
Launch the first native Nuwe Jy edition after the core paid MVP is proven and hardened while ensuring the core architecture already supports its reusable programme primitives.

## DEC-275 — Basic Membership readiness gate
**Status:** LOCKED
Do not sell Basic Membership until moderated community, monthly approved content, monthly live value, group Q&A, entitlement and cancellation behaviour are reliably operational.

## DEC-276 — Adjustment capability before Premium
**Status:** LOCKED
Prove stable plan delivery, useful check-ins and recurring adjustment capability before packaging the plan-adjustment add-on and then Premium.

## DEC-277 — Practitioner service pilot
**Status:** LOCKED
Introduce practitioner-reviewed service through a limited explicitly priced, capacity-controlled pilot only after automated plan delivery is stable.

## DEC-278 — Community release sequence
**Status:** LOCKED
Use governed Facebook communities for early Nuwe Jy/Membership validation, then pilot and migrate to first-party community when evidence justifies it.

## DEC-279 — Live first, full event commerce later
**Status:** LOCKED
Integrate governed live-session registration, entitlements, Restream/Cloudflare playback and replay early; defer complete paid event commerce/ticketing until later.

## DEC-280 — Staged paid release
**Status:** LOCKED
Use internal validation → controlled paid pilot → expanded paid pilot → limited public release → general public release, with explicit gates between stages.

## DEC-281 — First paid-pilot capacity
**Status:** LOCKED
Limit the first paid pilot to 50 participants, expanding deliberately through approximately 10 → 25 → 50 only after safety, payment, entitlement, generation and support review.

## DEC-282 — MVP South African launch list prices
**Status:** LOCKED / VERSIONED BUSINESS CONFIGURATION
Set initial list prices to R249 Digital Temperament Assessment, R399 7-Day Personalised Plan and R549 Assessment + Plan Bundle. Store prices as versioned configuration, preserve accepted historical prices and keep promotions separate.

## DEC-283 — Basic Membership commercial anchor
**Status:** PROVISIONAL / COMMERCIAL CONFIGURATION
Use R199/month and R1,990/year as the future Basic Membership planning anchor, approximately two months free annually, subject to evidence before the product publicly launches.

## DEC-284 — Small explicit bundle catalogue
**Status:** LOCKED
Keep bundles intentionally small and grant explicit underlying component entitlements rather than creating a parallel bundle-entitlement system.

## DEC-285 — Governed complimentary and sponsored grants
**Status:** LOCKED
Grant free/sponsored access only through explicit scoped, reasoned, auditable authority with elevated approval for high-value, long-duration or lifetime grants.

## DEC-286 — Nuwe Jy edition activation gate
**Status:** LOCKED
Require core platform, programme, operations, safety, live/community and technical readiness before any native Nuwe Jy edition activates.

## DEC-287 — Practitioner saleable-capacity model
**Status:** LOCKED
Model practitioner saleable capacity from authorised practitioners × safe cases per practitioner per period, track turnaround/workload and stop selling before capacity is exceeded.

## DEC-288 — Paid-pilot cross-functional readiness gate
**Status:** LOCKED
The first paid pilot is a NO-GO until required Product, Clinical, Content, Commerce, Legal/Privacy, Security and Operations owners have signed off their mandatory launch conditions.

## DEC-289 — Progressive performance/load gates
**Status:** LOCKED
Use progressive near-term load gates while preserving an architecture that can scale horizontally toward 100k-concurrent-user assumptions without rebuilding authoritative domain truth.

## DEC-290 — Paid-pilot success criteria
**Status:** LOCKED
Require zero critical platform-caused safety failures, duplicate charges/entitlements, unreproducible plans and unauthorised sensitive-data exposures, plus defined operational/product/value targets to decide proceed, iterate, repeat or pause.

## DEC-291 — Release and rollback authority
**Status:** LOCKED
Require separate product/commercial, clinical/safety and technical/operations authority for stage expansion; permit immediate scoped safety or technical stop actions and record every launch/rollback decision with evidence and re-entry criteria.


## DEC-292 — Paystack first / launch payment gateway
**Status:** LOCKED
Paystack is the first and launch payment gateway for the initial South African/ZAR platform release. Durable platform payment truth remains provider-independent and authoritative in PostgreSQL. Exact Paystack retry, recurring billing, webhook, proration, refund, dispute/chargeback, settlement and related provider behaviour must still pass the existing validation gate before implementation details are fixed. Future additional gateways may be introduced behind a provider boundary without redefining core payment, entitlement, refund, reconciliation or analytics semantics.

## DEC-293 — First-party A/B/n experimentation capability
**Status:** LOCKED
Build first-party governed A/B/n experimentation for approved web/page experiences and eligible email/message experiences. Experiments must support stable randomised/sticky allocation, clean/canonical public URLs, governed exposure and metric semantics, statistically valid decision rules, authoritative downstream conversion/income reconciliation, privacy/deletion constraints, protected-invariant exclusions, durable immutable/auditable aggregate results and searchable historical learning. Exact assignment, cache and statistical implementation mechanisms remain Architecture decisions.

## DEC-294 — Mature Research & Feedback capability
**Status:** LOCKED
The mature platform supports bounded lightweight interaction/feedback and governed structured research campaigns. Each instrument declares an explicit participation identity mode (Account-linked, pseudonymous or anonymous where appropriate). Identity mode and uniqueness guarantee are separate Product promises. Research/Feedback responses remain Research/Feedback truth and do not directly mutate Health Records, Safety & Eligibility, Plans, Temperament, Commerce or Entitlements. Persisted governed instruments are version-bound and published versions are immutable in meaning. Sensitive research, cohort targeting, longitudinal research, publication, incentives, correction/withdrawal, staff annotations and explicit follow-up/escalation are permitted only under the approved rules in `docs/history/platform/archive/00_PLATFORM_v1.3.0.md` §21M. The capability is not a generic survey-platform commitment.

## DEC-295 — Mature Voting, Balloting and Competitions capability
**Status:** LOCKED
The mature platform supports lightweight opinion polls, Research-governed polls and contextual governed voting/balloting including competition voting. Public unauthenticated voting is a legitimate governed mode and no Account is required merely for approved Nuwe Jy-style public voting. Public unauthenticated voting does not promise verified one-human-one-vote. Vote rules, configurable tally/leaderboard visibility, proportionate anti-abuse controls, prohibited automated/manipulated voting, governed finalisation, tie/disqualification/cancellation rules, legitimate campaigning, operator adjudication and separation of tally, official result and reward fulfilment apply as defined in `docs/history/platform/archive/00_PLATFORM_v1.3.0.md` §21N. Existing wellness/competition safety restrictions remain controlling. The platform is not a general-purpose civic election system.

## DEC-296 — Mature Interactive Tools, Calculators and Decision Aids capability
**Status:** LOCKED
The mature platform supports approved interactive educational tools, calculators, visualisations, decision aids, personalised tools and dashboards under the rules in `docs/history/platform/archive/00_PLATFORM_v1.3.0.md` §21O. Calculation is not authority: interactive output does not automatically become authoritative truth in another owning capability. Public/anonymous inputs and results are ephemeral by default; persistence and version-binding apply only where purpose and consequence require them. Public, Account-gated and entitlement-gated access models are legitimate. Tools may initiate downstream workflows without owning the resulting authoritative truth. Dashboards and visualisations remain derived presentations. Staff may configure approved bounded tool content/parameters but arbitrary executable CMS formulas/scripts are not a Product promise.

## DEC-297 — Platform Member Reference
**Status:** LOCKED
Every successfully created individual Account receives a stable human-facing Platform Member Reference under `docs/history/platform/archive/00_PLATFORM_v1.3.0.md` §21P. The reference identifies the Account for human-facing use; it does not represent paid membership, subscription, entitlement, authentication, authorisation or identity-verification assurance. It is non-secret but private-by-default, normally immutable, never reused and confers no Account authority. It may support staff lookup, participant communication, events, checkout/gifting and beneficiary identification with minimum-disclosure lookup. Beneficiary-linked benefits may be honoured when another purchaser pays specifically for that beneficiary, but the reference itself never proves benefit/discount/entitlement eligibility and must not become a pseudo-coupon. Product Law specifies human usability and non-semantic requirements, not exact encoding; brand-specific prefixes such as `VG` are not frozen as durable Product Law.

## DEC-298 — Cross-capability mature engagement interaction rules
**Status:** LOCKED
Research polls and governed votes are classified by approved purpose and consequence, not UI widget alone. Truthful anonymity/uniqueness claims apply consistently across Research/Feedback and Voting. Research responses and interactive-tool results do not silently become Health/Safety or cross-purpose authoritative truth. A Platform Member Reference must not be required for approved anonymous/public voting or research unless Account-linked participation is genuinely required. Account deletion does not automatically invalidate historically legitimate research responses or votes. Analytics, dashboards, leaderboards and reports remain derived presentation, not underlying business authority. Research incentives and competition rewards flow through owning commercial/entitlement capabilities. Shared interaction primitives do not create a universal Engagement authority or Domain.

## DEC-299 — Paid plan entitlement outcomes
**Status:** LOCKED
A paid plan entitlement remains held, unconsumed and unavailable for reuse or silent conversion while required onboarding information is incomplete or governed professional review is pending. Incomplete information or a pending review does not itself expire the paid right. An `eligible_automated` pathway consumes the right only after successful governed plan delivery; technical generation failure preserves it. `general_wellness_only` does not fulfil a personalised plan entitlement. DEC-308 and §21T.4 govern its retain/refund choice and no-response closeout. If a final outcome (`declined_no_plan`, `restricted_pathway` or `referred_externally`) cannot fulfil the purchased plan, Commerce refunds the checkout-recorded and pre-disclosed allocated plan-component amount, and Entitlements ends that component right. Under §21R.1, a versioned deterministic allocation rule and component amounts are selected before sale; component allocations sum exactly to the accepted bundle amount after governed discounts and promotions, in currency minor units. The allocation is disclosed before checkout and snapshotted immutably on the order with its currency, accepted amount, rule version and component/discount allocations. A component refund must use that snapshot and never recompute from current prices. A bundle is unavailable for sale without a complete valid allocation and disclosure. The launch prices reconcile as R249 assessment + R399 plan − R99 bundle discount = R549 accepted bundle amount; this decision does not choose the component split, which belongs to versioned offer configuration. Safety & Eligibility owns pathway outcome, Plans owns delivery truth, Commerce owns refund truth and Entitlements owns current access.

## DEC-300 — Commercial reversal and entitlement effects
**Status:** LOCKED
Provider callbacks are evidence and do not directly grant, remove or restore access. Commerce verifies and records a refund, duplicate payment, duplicate membership bill, dispute, restoration or final reversal; Entitlements applies the resulting component-level access consequence idempotently. Refund of an unused component ends that component right; duplicate-payment correction leaves one valid right; a confirmed disputed chargeback may temporarily suspend affected access; restored payment restores access idempotently; a final lost chargeback revokes affected current access. A post-delivery full reversal is exceptional and ends current access while preserving historical delivery and reversal records. Commercial history and current access are distinct.

## DEC-301 — Consent withdrawal and delivered access
**Status:** LOCKED
Withdrawal stops future processing for the withdrawn purpose and invalidates dependent future processing authority. Withdrawal alone does not delete delivered plan history or end an otherwise valid paid right. Health-storage consent withdrawal requires an independent lawful basis for continued storage or processing and may restrict access where rendering or use of health information lacks that basis. Full deletion is a separate governed event that ends ordinary report, plan and entitlement recovery while preserving only lawfully required minimal commercial evidence. This decision sets no statutory retention or deletion duration.

## DEC-302 — Temperament provenance and digital outputs
**Status:** LOCKED
Self-reported and book-derived profiles are clearly labelled declared results. They may support low-risk guidance where safety rules permit, but do not provide exact digital assessment scores or the paid digital assessment report, and do not consume an included digital assessment credit. A completed digital assessment has its own provenance and report. Later digital completion appends a new result and preserves earlier provenance; it does not rewrite the earlier result. Current-profile selection and a qualifying one-time 90-day plan regeneration follow existing Product Law.

## DEC-303 — Repeat assessment purchase limits
**Status:** LOCKED
A participant may have at most one active unused ordinary paid assessment credit. A second standalone assessment sale is blocked while that credit is unused, including where the annual use interval would strand another credit. A bundle sale is blocked while an ordinary paid credit is unused and the participant is routed to the approved plan-only offer. A plan-only purchase is independent of an assessment credit. Purchase eligibility, paid entitlement, completed attempts, annual retake interval and the Premium annual reassessment credit are distinct. Premium retains one eligible annual credit that does not accumulate and expires when membership ends.

## DEC-304 — Marketing unsubscribe scope and consent ownership
**Status:** LOCKED
Marketing actions must communicate which durable state they change. A scoped channel/category opt-out changes only the applicable Communications-owned preference and leaves Privacy & Consent-owned purpose-level marketing permission unchanged. A participant action explicitly presented as “Withdraw marketing permission” or “Unsubscribe from all marketing” requests withdrawal of the marketing purpose through Privacy & Consent, which alone commits that purpose-level change. Once withdrawn, purpose permission suppresses all optional marketing across channels regardless of Communications preferences. Preference changes cannot grant or restore purpose permission; restoration requires a new explicit participant grant through Privacy & Consent. The same ownership boundary applies to accountless contacts, and linking one to an Account does not create, transfer, broaden, or restore permission. Provider subscription state or callback evidence cannot independently establish or restore platform permission. This decision composes with DEC-094, DEC-232, DEC-262 and DEC-301; it does not rewrite or supersede DEC-301. It does not establish legal sufficiency under any regime and leaves existing legal/expert gates in force.

## DEC-305 — Temperament-informed behavioural personalisation
**Status:** LOCKED
Temperament is a first-class input to low-risk behavioural strategy and delivery. Clinical/safety truth, nutritional/health truth and participant context/constraints take precedence. Personalisation uses likely strengths and compensates for likely traps. Historical assessment result, current profile interpretation, active personalisation preferences and learned behavioural preferences remain distinct; feedback does not rewrite assessment history. Explicit participant preference may refine low-risk delivery but may not override protected health or safety rules. NewYou Product authority may version low-risk behavioural application rules without methodology approval for each application change, provided that those rules do not redefine Four-Colour methodology or violate health/safety authority.

## DEC-306 — Mixed profiles, ambiguity and possible-mask boundary
**Status:** LOCKED / METHODOLOGY GATE
Preserve all four underlying governed scores and expose their approved percentage/proportion result across all four colours as the assessment-result distribution or alignment. Do not describe a participant as a percentage of a colour. Score normalization and percentage/proportion calculation remain methodology-owned and require applicable rights and approval before production encoding. Assign primary, secondary, tertiary and fourth only when the approved methodology resolves that ordering. Preserve unresolved exact ties or other ambiguity visibly as tied or ambiguous; do not assign an arbitrary total order. Keep V1 behavioural weighting intentionally coarse. Tie and near-tie questions and deterministic consequences remain methodology-defined. Opposite pairs may be genuine combinations and are possible-mask review signals, not automatic masks. The platform must not infer trauma from assessment results. Methodology authority must define any mask behaviour before it is implemented. DEC-306 supersedes DEC-058's fixed highest-score ordering and clarifies its score-display rule through the four-colour result representation stated here.

## DEC-307 — Paid-pilot commercial validation contract
**Status:** LOCKED
NewYou remains intentionally a platform. The first commercial pilot validates its first proposition within the approved platform; it does not require a preliminary assessment-only business to prove that the platform should exist. The pilot evaluates demand, offer, perceived value and operational economics, not scalable acquisition. Count actual payments as paid demand and distinguish list price, promotion and actual amount paid. Invited-pilot conversion is not public-funnel conversion. Classify refunds by reason, separate dissatisfaction from technical/payment and safety/eligibility outcomes, and apply the first-10 dissatisfaction stop signal: 0–1 is not strong negative evidence, 2 requires review before expansion, and 3 or more pauses expansion pending investigation. Measure support burden without an invented first-10 time threshold. Ask the separate paid-value question and treat stated normal-price intent as weaker evidence than purchase.

## DEC-308 — General Wellness paid-plan choice and 14-day refund
**Status:** LOCKED
`general_wellness_only` does not fulfil a purchased personalised plan. Keep its plan-component entitlement unconsumed while the participant chooses to retain it or receive a refund of the original snapshotted plan-component allocation. Once she explicitly chooses retention, it remains `held_unconsumed` and does not expire solely because she remains `general_wellness_only`. Any future expiry or forced closure requires separately governed and versioned Product Law and applicable pre-purchase disclosure. Retention does not guarantee later eligibility; a later plan needs a new governed eligibility evaluation. The participant receives one 14-day choice window when NewYou communicates the governed decision and the retain-or-refund choice. Any reminders occur within that same window. If no choice is recorded by its end, automatically refund the original snapshotted plan-component allocation and close that component entitlement. Preserve a separately valid assessment entitlement/report. Changing the 14-day Product configuration requires governed re-versioning and applicable customer disclosure.

## DEC-309 — Four-Colour IP, methodology and authority boundary
**Status:** LOCKED / RIGHTS AND METHODOLOGY GATE
Methodology authority comes from the governing IP agreement, not technical administrator power. Material Four-Colour methodology changes require Lynette Beer or another authority explicitly delegated by that agreement. The agreement must establish applicable digital/commercial assessment, scoring, question, interpretation, tie/mask, report, derivative/adaptive use, temperament-personalisation, plan/bundle, membership/programme, translation, historical retention, economic and methodology-approval rights. Book reproduction rights remain separate; the full book is not presumed licensed. Block production-intended encoding of proprietary questions, answer structure, scoring, result ranking, tie/mask rules, reports, translations and methodology-sensitive mappings until rights are established. Methodology-neutral infrastructure, including assessment attempts, methodology-version identifiers, result history, immutable report snapshots, audit and entitlement interaction, may be designed or implemented where separately authorised. The platform operator publishes approved methodology versions; Product authority governs product application; Health/Clinical authority governs health and safety. NewYou Product authority may version low-risk behavioural application rules without methodology approval for each application change, provided those rules do not redefine methodology or violate health/safety authority. A Super Admin role alone grants no methodology authority. DEC-309 supersedes only DEC-051's earlier fixed role assignment.

## DEC-310 — First paid cohort and metric contracts
**Status:** LOCKED
The first 10 are genuine self-paying adult women from the approved South African launch audience, primarily from existing book/event/media reach, using the real bilingual product and catalogue without engineered temperament or eligibility outcomes. Include at least two Afrikaans-first and two English-first participants as a cohort target. Before first paid participation, every gate metric defines numerator, denominator, qualifying event, window, exclusions, missing-data treatment, cohort and definition version. Do not change definitions retroactively. Use the approved assessment-completion, health-onboarding-completion, plan-activation and meaningful-seven-day-usage definitions. Retain the 70% positive-value/relevance target and require at least 70% survey response for controlled-pilot interpretation. Show counts with percentages and keep non-response visible.

## DEC-311 — North Star evidence maturity
**Status:** LOCKED
Day 7 supports early usability, safety, relevance, activation, initial usage and perceived-value conclusions, not proof of sustainable habit formation. Collect lightweight Day 30 and directional Day 90 evidence, including recovery only for real interruptions. The mature directional measure remains at least three personally appropriate health behaviours 90 days later. MVP success does not prove the North Star. Cohorts may expand under existing gates while Day 30/90 evidence matures in parallel; do not impose 90-day waits between cohort expansions.

## DEC-312 — Progressive economics gate
**Status:** LOCKED
First 10/25/50 economics are measurement-oriented and have no invented CAC, LTV, profit-margin or gross-margin thresholds. Track once-off contribution before fixed overhead, actual founder/staff effort and fixed overhead separately. Start channel CAC measurement at limited public release. Evaluate retention, churn, failed payments, refunds, fees, support, moderation, live/content delivery, member-serving cost and recurring contribution before recurring scale. The existing 500 × approximately R200 target is gross MRR, not proof of healthy economics. Practitioner services require separate time, capacity, turnaround, follow-up, cost and contribution evidence.

## DEC-313 — Assessment-credit claim, hold, delivery and release
**Status:** LOCKED
For each existing paid digital Assessment credit/right governed by Product Law §21R.6, the first valid saved answer claims/holds the same credit in `held_unconsumed`; only successful complete paid digital Assessment delivery with durable authorised-participant availability to the governed result and the full paid output required by §§7.4 and 21B.5–21B.12 consumes it. Terminal nontechnical expiry before that delivery releases the same credit to `available_unused`, with no consumption, expiry-only refund, duplicate/replacement credit or `close_unconsumed` outcome. Genuine technical failure and any separately governed technical-failure refund remain separate. This supersedes DEC-055 only for the affected paid Assessment-credit consumption semantics. DEC-034's one-retake-per-year limit is unchanged; its prior-event reference is successful digital Assessment delivery. Ownership and implementation representation do not change.

## DEC-314 — Duplicate collections, make-whole and component attribution
**Status:** LOCKED
DEC-314 composes with and narrowly extends DEC-300; it does not rewrite or supersede DEC-300. Duplicate provider evidence alone does not establish multiple genuine financial collections. For one intended commercial obligation with multiple verified genuine collections, Commerce retains only the lawful amount, records one make-whole obligation equal to the verified excess and satisfies that claim exactly once, making the authoritative payer/payment relationship whole for the verified excess. Commerce owes this correction to that relationship, established from authoritative commercial and payment truth; an account holder, entitlement recipient or beneficiary does not become the monetary claimant merely because they receive or use the purchased right. Provider evidence cannot redefine that claimant. Replayed, stale or out-of-order provider evidence cannot create or satisfy another make-whole claim. Two independently intended and accepted purchases remain distinct obligations even when the payer, product and amount match or the purchases occur close together; amount or timing similarity alone does not collapse them.

A partial refund, reversal or excess amount identifies a component only through the immutable accepted order allocation governed by Product Law §21R.1 and DEC-299. Amount coincidence with a current Assessment price, current Plan price or another catalogue price, a provider fragment, and callback arrival order are not component-attribution authority. The accepted order allocation remains authoritative after catalogue prices change and when bundle allocation differs from current standalone prices.

Provider state remains evidence. Commerce owns monetary truth and the make-whole obligation; Entitlements owns the resulting right/access truth and applies at most one valid entitlement consequence for that obligation. If the consequential monetary outcome, collection count, intended obligation or component attribution is unknown, Commerce fails closed into reconciliation. Do not blindly repeat a refund or grant another entitlement while the outcome remains unresolved. Preserve legitimate historical collection, payment, delivery, refund and reversal records. This decision adds no provider mechanics, API, idempotency-key design, shared-write authority, schema, resource, job, service, UI workflow, Architecture, Domain ownership, North Star or Feature Pack change. It does not freeze any provider-specific execution mechanism.

## DEC-315 — Statutory consumer cancellation and refund rights
**Status:** LOCKED
NewYou's ordinary commercial cancellation, renewal and refund rules apply except to the extent that a non-waivable statutory consumer right provides otherwise. Where applicable law classifies a Membership agreement as fixed-term, NewYou accepts legally sufficient recorded notice and supports the legally effective mid-term cancellation lifecycle, lawful amounts owing, only a legally permitted reasonable penalty, and any required credit or refund. Applicable expiry notice and continuation rules govern; a further fixed term requires the consumer's express agreement where law requires, and month-to-month continuation is supported where law makes it the default.

A cancellation penalty must be evidence-based, reasonable under the applicable legal factors and calculated under a deterministic, versioned and auditable policy after legal approval. It must not negate or effectively destroy the statutory cancellation right. The policy may set a more consumer-favourable cap or zero penalty. An unsupported penalty cannot delay or deny cancellation. Provider behaviour, provider pricing and future lost revenue do not establish a lawful penalty. No percentage or formula is selected; any detailed formula requires separate legal and Product approval.

DEC-315 supersedes only DEC-039's absolute end-of-paid-period cancellation timing and DEC-045's Membership ordinary partial-period refund boundary. It does not change monthly Membership into a minimum-term product, alter Assessment, Plan, gift, Event or payment-reversal rules, change DEC-313 Assessment-credit semantics, alter Entitlement or Account-deletion rules, or change Domain ownership. Commerce remains authoritative for the Membership contract and commercial cancellation/refund truth; Entitlements remains authoritative for current access and grants. Provider state remains evidence.

## DEC-316 — English-only governing legal documents and development baseline gate
**Status:** LOCKED
NewYou's governing Terms and Conditions and Privacy Policy / Privacy Notice are maintained and published in English only as the single authoritative legal documents. Both Afrikaans and English product experiences link to the same English documents. No official Afrikaans governing legal translation is required or maintained, and legal content is not translated at runtime. DEC-124 is superseded in part only for the governing Terms and Privacy document bodies; DEC-028's bilingual platform requirement and DEC-027's required Terms/Privacy acceptance are unchanged. Other applicable participant-facing UI and content remains bilingual, including consent notices, assessments, plans, clinical and safety content, core onboarding, verification UI and general paid content.

Immutable English `DEVELOPMENT BASELINE / NOT LEGALLY APPROVED` Terms and Privacy versions may be used only in explicitly permitted non-production development, tests, development environments and bounded Phase-8 architectural proof. Baselines are not legally approved production authority and cannot be used for public release, paid pilot or real-participant use where approved legal documents are required. Each content version preserves its immutable ID, document type, locale `en`, exact content, applicability/effective status, approval state and any approval reference/date, plus supersession/withdrawal relationship. Any later approved legal version receives a separate immutable ID; approval does not mutate the baseline.

Acceptance binds the exact Terms version, exact Privacy version, acceptance time and participant interaction/preferred locale; interaction locale is independent from each legal document's `en` locale. Production-class, public-release, paid-pilot and applicable real-participant flows fail closed unless the exact selected Terms and Privacy versions have required legal/privacy approval evidence. No baseline fallback, `latest` lookup, default unapproved version, runtime translation or pending-review bypass is permitted. This DEC does not find the source text legally sufficient, resolve external legal/privacy approval, or authorize P8-05 implementation.

# Open Gates

## OQ-001 — Final operating entity
**Status:** EXPERT REVIEW
Resolve before production subscriptions, large-scale sensitive health-data processing or practitioner contracting.

## OQ-002 — Exact launch pricing
**Status:** RESOLVED BY DEC-282 / DEC-283
MVP list prices are locked as versioned business configuration. Basic Membership uses a provisional planning anchor until that product’s pre-launch commercial review.
## OQ-003 — Monthly review contract
**Status:** PRODUCT REVIEW
Define exact check-in deadline, grace period and incomplete-check-in behaviour before recurring adjustment launches.

## OQ-004 — Paystack retry implementation
**Status:** VALIDATION REQUIRED
Test failed-payment, subscription, webhook, proration, refund and chargeback behaviour before implementation is locked.

## OQ-005 — Clinical eligibility matrix
**Status:** CLINICAL REVIEW
Approve the exact low-, moderate- and high-risk routing matrix before automated plans launch.

## OQ-006 — Score-distance thresholds
**Status:** METHODOLOGY REVIEW
Approve dominance, close-result, balanced and mixed-profile thresholds before those labels are enabled.

## OQ-007 — Laboratory validity matrix
**Status:** CLINICAL REVIEW
Define test-specific current-validity and superseding rules.

## OQ-008 — Emergency and urgent-support wording
**Status:** CLINICAL / LEGAL REVIEW
Approve country-specific urgent-help wording, acknowledgements and escalation boundaries.

## OQ-009 — Early retention categories
**Status:** LEGAL / PROFESSIONAL REVIEW
Ensure required health and professional record categories are included in the formal retention schedule.

## OQ-010 — Calculation values
**Status:** CLINICAL REVIEW
Approve exact calculation formulas, minimums, ranges and bounded weight-reduction values.

## OQ-011 — Adjustment thresholds
**Status:** CLINICAL / PRODUCT REVIEW
Approve trend windows, tolerances, adherence requirements and recalculation thresholds.

## OQ-012 — Review timing
**Status:** PRODUCT REVIEW
Approve minimum plan-use period, monthly review window and grace behaviour.

## OQ-013 — Translation resource design
**Status:** ARCHITECTURE REVIEW
Define exact Ash resource boundaries, approval relationships, locale/version indexes and immutable delivery references.

## OQ-014 — Cloudflare and edge-cache design
**Status:** ARCHITECTURE REVIEW
Define public-cache eligibility, cache rules, signed delivery, purge paths, security controls and immediate safety-withdrawal invalidation.

## OQ-015 — Search configuration
**Status:** ARCHITECTURE REVIEW
Define PostgreSQL full-text search, approved synonyms, ranking weights, indexes, pagination and any future semantic-search boundary.

## OQ-016 — Content publication operations
**Status:** OPERATIONS / ARCHITECTURE REVIEW
Define scheduler reliability, retry policy, alert ownership, stale-approval checks and recovery.

## OQ-017 — Reminder delivery design
**Status:** ARCHITECTURE / OPERATIONS REVIEW
Define channels, scheduling, retries, quiet-hour behaviour, observability and rate limits.

## OQ-018 — Journal encryption and retention
**Status:** SECURITY / LEGAL REVIEW
Define encryption, field-policy boundaries, retention, export, deletion and professional-record handling for journal data.

## OQ-019 — Programme completion metrics
**Status:** PRODUCT REVIEW
Define programme-specific minimum participation, final check-ins and completion thresholds before each programme is published.

## OQ-020 — Restream and Cloudflare live-video validation
**Status:** VENDOR / ARCHITECTURE REVIEW
Validate Restream plan requirements, custom RTMPS output, recording limits, failure handling and Cloudflare Stream live-input integration.

## OQ-021 — Video consent and retention
**Status:** LEGAL / OPERATIONS REVIEW
Define speaker, attendee, recording, editing, replay, clip, retention and withdrawal rules.

## OQ-022 — Event reservation architecture
**Status:** ARCHITECTURE / PERFORMANCE REVIEW
Define locking, reservation expiry, Redis acceleration, payment idempotency, waiting-list allocation and flash-sale protection.

## OQ-023 — Facebook community operating policy
**Status:** OPERATIONS / PRIVACY REVIEW
Define moderator staffing, escalation, member notices, disclosure warnings, evidence handling and migration-readiness measures.

## OQ-024 — Nuwe Jy source-content inventory
**Status:** CONTENT REVIEW
Inventory current Nuwe Jy lessons, videos, downloads, live-session assets, rights, duplicated material, missing translations and outdated content.

## OQ-025 — Nuwe Jy safety and completion thresholds
**Status:** CLINICAL / PRODUCT REVIEW
Approve exact challenge safety routing, milestone check-ins, required activities and completion rules.

## OQ-026 — Nuwe Jy edition operations
**Status:** OPERATIONS REVIEW
Define cohort capacity, facilitator coverage, moderator coverage, support ownership, live-session ownership, escalation and archive responsibilities.

## OQ-027 — Nuwe Jy communication channels
**Status:** OPERATIONS / ARCHITECTURE REVIEW
Select launch channels and define delivery caps, templates, retries, quiet hours, deduplication and failure ownership.

## OQ-028 — LearnDash retirement obligations
**Status:** COMMERCIAL / LEGAL REVIEW
Document current participant promises, access obligations, record retention and exact retirement conditions for the legacy system.

## OQ-029 — Retention schedule matrix
**Status:** LEGAL / FINANCE / PROFESSIONAL REVIEW
Define approved durations, owners, purposes, archive periods, deletion actions and exceptions for every record category.

## OQ-030 — External processor deletion inventory
**Status:** PRIVACY / ARCHITECTURE REVIEW
Inventory payment, messaging, analytics, storage, video, support and future AI processors and define deletion/export/evidence behaviour.

## OQ-031 — Backup restore and deletion replay
**Status:** ARCHITECTURE / OPERATIONS REVIEW
Define backup expiry, restore isolation, deletion-ledger replay, verification and go-live gates so deleted participants never reappear.

## OQ-032 — Export and deletion operations
**Status:** SECURITY / OPERATIONS REVIEW
Define verification levels, job deadlines, processor retries, pending states, participant notices, failure alerts and completion evidence.

## OQ-033 — Professional record authority
**Status:** CLINICAL / LEGAL REVIEW
Define responsible record authority, participant-access boundary, addendum process and final disposition for practitioner records.

## OQ-034 — Authentication implementation architecture
**Status:** RESOLVED / ARCHITECTURE SELECTION

The architecture selection is resolved from the merged FP-001 Identity & Access JIT Domain Dossier. The approved planning contract is:

- stable Ash Authentication v4 and stable Ash Authentication Phoenix v2;
- email/password authentication with optional magic-link capability;
- Argon2id password hashing;
- an Identity-owned Token Resource configured using the `AshAuthentication.TokenResource` Resource extension;
- secure first-party browser-session architecture with CSRF protection and LiveView actor reconstruction;
- participant-optional MFA, mandatory privileged MFA and high-risk participant step-up;
- NimbleTOTP architecture with Account-owned encrypted TOTP state;
- AshCloak v0.4.0 as the security floor; any later compatible stable release requires explicit review;
- DeviceAssurance and RecoveryCase concepts;
- fail-closed Session + Token + Account/security validity composition;
- no public or external API bearer authentication for FP-001; internal first-party framework token mechanisms remain permitted.

This resolves architecture selection only. Executable authentication proof is not complete and remains a Phase 8 proof obligation. The proof boundary includes:

- pinned compatible versions;
- Argon2id cost/resource envelope;
- confirmation, reset and magic-link replay/expiry;
- token hashing/presence/revocation;
- cookie/session fixation;
- CSRF;
- LiveView disconnected/connected reconstruction;
- multi-node shared PostgreSQL behaviour;
- restart/reconnect;
- global/session-specific revocation;
- manual recovery/hold races;
- privileged MFA/step-up;
- secret rotation;
- failure injection;
- no-enumeration tests.

## OQ-035 — Abuse-control thresholds
**Status:** SECURITY / OPERATIONS REVIEW
Define Cloudflare, application and Redis rate-limit thresholds, escalation rules and false-positive recovery.

## OQ-036 — Notification providers and channel policy
**Status:** VENDOR / OPERATIONS REVIEW
Select launch email/in-app implementation and later SMS/WhatsApp providers, costs, consent rules, retries and delivery evidence.

## OQ-037 — RPO/RTO targets
**Status:** ARCHITECTURE / BUSINESS CONTINUITY REVIEW
Assign exact recovery-point and recovery-time targets by criticality tier and validate them through restore exercises.

## OQ-038 — Incident response ownership
**Status:** OPERATIONS / SECURITY REVIEW
Define named on-call ownership, escalation tree, after-hours handling, customer communication and post-incident cadence.

## OQ-039 — Performance and scaling domain mapping
**Status:** ARCHITECTURE / PERFORMANCE REVIEW
Maintain two levels of performance/scaling definition:

1. **Platform-wide domain architecture baseline before Roadmap:** for every approved domain, establish enough architecture-level information to identify authoritative state ownership, broad hot/warm/cold classification, concurrency sensitivity, major scaling risks, and whether Redis, ETS/Cachex, GenServer, PubSub, Oban, replicas and streaming/pagination are potentially applicable or explicitly `NONE`/not justified. This baseline exists to make domain ownership and delivery sequencing safe without forcing speculative implementation detail.
2. **Implementation-grade mapping before affected slices are issued:** for every domain/action touched by the Feature Pack or implementation slice, define the concrete indexes, Redis structures or `NONE`, TTL/invalidation or `NONE`, GenServer ownership or `NONE`, PubSub behaviour or `NONE`, Oban priority/behaviour or `NONE`, replica use, streaming/pagination, concurrency/idempotency behaviour and relevant 100k-concurrency characteristics before that slice may be implemented.

Future domains or actions not touched by the current delivery scope do not require speculative implementation-grade mapping before development begins. This clarification changes planning timing and granularity only; it does not weaken the platform-wide performance, correctness, privacy, safety, financial-integrity or horizontal-scaling requirements.

## OQ-040 — First-party experimentation proof
**Status:** ARCHITECTURE / EXPERIMENTATION PROOF
**Source decision:** DEC-293
Prove the first-party governed A/B/n architecture before the first governed activation. The proof must cover deterministic/sticky assignment, anonymous-to-known continuity, concurrent-experiment isolation, exposure logging, authoritative conversion attribution, statistical validity, immutable aggregate learning evidence, privacy/deletion handling, variant-safe delivery/caching and failure/recovery. Exact assignment, cache and statistical mechanisms remain downstream Architecture and Feature Pack decisions.


# Decision Interpretation Notes

## Permanent-access decisions versus full deletion

DEC-033 and DEC-037 grant durable purchased access during the account relationship.

DEC-223 and DEC-225 later define the explicit full-deletion boundary.

Therefore:

```text
ordinary account / closed-but-recoverable account
→ purchased-access rules apply

completed full deletion
→ no report/plan/entitlement recovery or reconstruction
```

This is a later constraint, not permission to rebuild a deleted account from retained commercial records.

## Product-space model

DEC-268 now locks one operating platform with controlled product spaces.

DEC-269 locks the women’s health and lifestyle product as the only customer-facing launch space.

This is not unrestricted generic multi-tenancy.


## DEC-317 — Role-based capabilities and operational delegation
**Status:** LOCKED
Capabilities belong to governed roles/scopes and applicable relationships, never a named person. No ordinary direct user-to-capability grant is permitted. Platform Administrator delegates ordinary non-sensitive operational roles/scopes only within its governed catalogue. Sensitivity is role-and-scope based. Domain owners define their business capability and specialist approval requirements; Identity & Access owns grants. DEC-021 remains unchanged. Super Admin is break-glass and no universal bypass. Product Law §15.1A governs the boundaries and privileged authentication policy.

## DEC-318 — Governed bootstrap and privileged approval
**Status:** LOCKED
GOVERNED BOOTSTRAP AUTHORITY is the exceptional root-of-trust transition for initial explicit role/scope grants and is sealed after successful bootstrap. It is not a person, runtime role or business capability holder. Recovery is a separately governed exceptional ceremony. After bootstrap Super Admin independently approves classified platform-operational privileged grants to another identity; Domain-sensitive grants require their designated owner approval. Sensitive self-approval is prohibited. Product Law §15.1B governs evidence and bootstrap limits; §15.1A governs delegation, succession and expert boundaries.

## DEC-319 — Verification-message classification and bounded P8-05 eligibility
**Status:** LOCKED
`verification_message` is a narrow controlled Product content type for participant-facing address or comparable identity-claim verification only; it does not classify other transactional messages. The exact locale-specific immutable `ContentTranslationVersion` is delivery content, while an authoring template is not delivery authority. Development-only fixture eligibility is separate from runtime/release eligibility: `development_approved != runtime_approved != published != latest != production_eligible`. Existing exact EN/AF bytes and JC's exact-wording owner approval remain valid development-baseline provenance for local development, automated tests, development environments and bounded P8-05 Phase-8 proof; this does not require a materialised Account, IdentityGrant, real Content role or lifecycle actor. The bounded development lifecycle is `candidate → development_approved → superseded | withdrawn`; it pins exact immutable identity/digest, requires an owner/governance decision and bounded non-production applicability, preserves append-only history, makes repeated identical decisions idempotent and stops conflicting same-version decisions for reconciliation. It creates no runtime role, publication or production authority. Before production, public release, paid-pilot or real-participant use, the exact locale versions still require all four exact-byte Content/locale approvals, a current Identity & Access `Content` + `verification_message_lifecycle` grant and an explicit Content & Media release/eligibility decision. Actual governed actors, scopes and evidence remain mandatory; DEC-317 controls delegation, §15.1B governs durable grants and DEC-318 continues to govern bootstrap and privileged/sensitive approval. Development fixtures and synthetic grants confer no production authority and must fail closed or be impossible in production/release contexts. Content & Media ownership, Communications current-send/rebinding authority and Identity challenge authority remain separate. Broader OQ-013/OQ-016 questions remain open.

## DEC-320 — Development execution authority separate from runtime role grants
**Status:** LOCKED
Durable authority plus a dependency-cleared Plane `Ready` ticket is sufficient permission to implement. Ordinary authorised software development does not require a real runtime Account, IdentityGrant, role assignment or production capability grant. A runtime authorization mechanism, real operator identity, runtime role grant or production capability assignment must not be required to exist before development of that mechanism or its dependent feature may proceed. An exception is permitted only where an external real-world requirement is intrinsically necessary even for the bounded development action; it must be explicit, narrowly scoped and justified by governing authority, and cannot be inferred from a future production role requirement.

Runtime roles and capabilities must still be designed and tested during development, including authorized and denied actions, missing grants, wrong scopes, expired and revoked grants, sensitive-role boundaries and relevant audit behavior. Isolated local/test/bounded-development environments may create deterministic synthetic Accounts, identities, roles, grants, relationships and fixtures to prove every authorization path. Those constructs are development/test evidence only and confer no production authority; every development-only shortcut must be impossible or fail closed in production/release contexts. `NewYou.Identity.Account` remains the canonical runtime platform identity. JC is currently the sole developer/operator and may perform all authorised non-production engineering/admin actions required for delivery; this grants no automatic production, public-release, paid-pilot, real-participant, Content publication, clinical, safety, legal/privacy, financial, Domain-business or Super Admin production-bypass authority. Actual runtime/release operations remain subject to their governed Accounts, roles, scopes, grants, approvals and release gates.

## DEC-321 Magic-login message classification and bounded development eligibility

**Status:** LOCKED

Under approved Product §§21E.21–21E.22, add the narrow `magic_login_message` content type for optional existing-Account email sign-in. Approve `editorial_low_risk` for wording only; Identity authentication/security remains HIGH. Preserve DEC-319 and verification_message exclusion, DEC-317/318 role boundaries and DEC-320 development/runtime separation.

Content & Media owns exact immutable EN/AF versions and development eligibility. Product classification approval and exact-byte Content & Media approval are separate accountable decisions. Until both exist, the versions remain candidate and ineligible. The lifecycle, exact binding, idempotency, conflict reconciliation, historical immutability and fail-closed rules are Product §21E.22.

Applicability is local development, automated tests, development environments and bounded P8-09 Phase-8 proof only. Production, public release, paid pilot and real-participant delivery are prohibited. This decision grants no runtime Content role, publication, sender/provider approval, authentication implementation or protected bearer retention. WELL-91's Assent disposition and exclusive `2026-11-18T00:00:00Z` expiry remain unchanged. No authentication-input rebinding is authorised.
