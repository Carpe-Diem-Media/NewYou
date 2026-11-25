# PROJECT_NORTH_STAR_AND_MVP_v1.4.0.md

- **Document status:** FROZEN PRODUCT NORTH STAR / MVP BASELINE v1.4.0
- **Document version:** v1.4.0
- **Predecessor:** `docs/governance/product/PROJECT_NORTH_STAR_AND_MVP_v1.3.0.md`
- **SemVer transition:** `v1.3.0 → v1.4.0`
- **Authoritative for:** The absolute long-term outcome, the smallest viable product slice, the intended product journey, MVP boundaries, and handoff context
- **Not authoritative for:** Final launch pricing, legal conclusions, clinical thresholds, Ash Resources, database schemas, technical architecture, or implementation sequencing
- **Related documents:**
  - `00_PLATFORM_v1.6.0.md`
  - `01_DECISIONS_v1.6.0.md`
  - `02_OPEN_WORK_v1.2.51.md`
  - `05_ROADMAP_v1.2.0.md`
- **Source foundation:** The approved book source documents, including the temperament assessment, health, sleep, stress, trauma, self-talk, faith, four temperament chapters, and conclusion
- **Last updated:** 2026-11-25
- **Decision coverage:** GQ-001 through GQ-012 plus GQ-NY-001 and approved post-freeze DEC-292–DEC-328 amendments

## v1.4.0 Amendment Scope

This successor changes only the South African price presentation. The R249, R399 and R549 amounts and the R99 saving are synthetic development fixtures, not launch prices. Final launch prices, promotions, bundle savings and component allocations are governed Commerce configuration selected before launch under Product Law v1.21.0 and DEC-328. The North Star, MVP boundary, paid-cohort contract, metric definitions and evidence ladder are otherwise unchanged. This successor grants no launch-price approval, provider operation, production activation or release.

## v1.3.0 Amendment Scope

This substantive successor preserves the one-sentence North Star and records the Pass 2 paid-cohort contract, metric definitions, commercial validation meaning and Day 7/30/90 evidence ladder. MVP success does not prove the long-term North Star. The current Product, Decision, Open Work and Roadmap successors carry the governing detail. No Architecture or Domain ownership changes, implementation authorization or downstream stage advancement are made.

## v1.2.2 Patch Scope

This patch corrects Step 5 so assessment outputs follow temperament provenance, and synchronises current-authority references. A self-reported or book-derived temperament is a declared profile, not a completed paid digital assessment. Historical v1.0/v1.1/v1.2 amendment text remains preserved where it describes earlier states.

## v1.2.4 Patch Scope

This non-semantic PATCH repairs current-authority routing and North Star self-state. It preserves the v1.2.3 North Star, MVP, catalogue, journeys, pricing, product boundaries and Phase 7/8 meaning.

## v1.2.3 Patch Scope

This routing-only patch updates current-authority paths and §23 to the current successor set. It preserves the v1.2.2 North Star, MVP, journey, catalogue, boundaries and product meaning. This document does not authorise HARDEN-02 execution, implementation or Phase 8; current programme routing belongs to README and current Open Work.

## v1.2 Amendment Scope

This v1.2 amendment does **not** change the North Star, participant journey, MVP outcome, launch catalogue, clinical/safety boundary or staged delivery doctrine. It only synchronises the North Star handoff with two approved post-freeze Product Law amendments:

- Paystack is now locked as the first/launch payment gateway rather than provisional;
- first-party governed A/B/n experimentation is an approved platform capability for learning/optimisation, without making experimentation part of authoritative payment, entitlement, clinical/safety or accounting truth.

These additions do not expand the smallest MVP unless/when Roadmap/Feature Pack sequencing explicitly schedules the experimentation capability. The v1.1 planning-governance amendment remains in force.

## v1.1 Amendment Scope (preserved historical text)

This v1.1 amendment aligns the North Star handoff and implementation stop condition with the approved post-freeze planning method.

It does **not** reopen or alter the ultimate outcome, participant journey, MVP definition or boundary, product catalogue, pricing, pilot progression, release sequence, clinical/product policy, or DEC-001 through DEC-291.

The governance changes are limited to:

- recognising `AR-000` Architecture Requirement Extraction before architecture decision work;
- recognising architecture reference-flow pressure testing before architecture freeze;
- separating platform-wide Domain Architecture Profiles from JIT implementation-grade Domain Dossiers;
- placing `05_ROADMAP.md` after the complete Domain Map and Domain Architecture Profile baseline;
- recognising Feature Packs as the delivery-planning container;
- recognising Architectural Proof as the first authorised executable development stage;
- keeping TOON as a just-in-time execution projection rather than planning authority.

---

# 1. Read This Document First

This document is the shortest complete explanation of:

- what we are ultimately building;
- why it exists;
- who it serves;
- what the smallest viable first product must prove;
- what the MVP includes;
- what the MVP deliberately excludes;
- and which documents contain the deeper rules.

Use the core documents in this order:

```text
PROJECT_NORTH_STAR_AND_MVP
→ ultimate direction and MVP boundary

00_PLATFORM
→ current platform truth and governing product principles

01_DECISIONS
→ locked decisions and formal open gates

02_OPEN_WORK
→ unanswered questions, expert gates and remaining planning sequence

BOOK SOURCE DOCUMENTS
→ source material, terminology, health framing, temperament model and content foundation
```

A new chat, planner or coding agent must not infer missing policy from general knowledge.

When a rule is absent:

1. check `01_DECISIONS`;
2. check `02_OPEN_WORK`;
3. ask for a decision;
4. do not invent it in implementation.

---

# 2. One-Sentence North Star

> Build the leading Christian, temperament-guided holistic health and lifestyle ecosystem that helps women understand how they are wired, receive safe and relevant guidance, build sustainable habits around real life, and return to those habits after setbacks.

---

# 3. Absolute Ultimate End Goal

The ultimate goal is not a single application, diet plan, assessment or membership site.

The end goal is a complete, trusted and scalable **temperament-guided health, wellness, behaviour-change and community ecosystem**, initially designed for adult women.

At maturity, the platform should support a woman from first discovery through long-term maintenance:

```text
discover
→ understand herself
→ identify barriers
→ receive safe guidance
→ follow a practical plan
→ build habits
→ recover after setbacks
→ track meaningful progress
→ join programmes and community
→ participate in challenges and events
→ receive professional support when required
→ maintain long-term health and consistency
```

The platform should combine:

- the Four-Colour Temperament Model™;
- evidence-informed nutrition and lifestyle guidance;
- physical, emotional, behavioural and spiritual health;
- Christian faith, identity and grace;
- personalised eating and lifestyle plans;
- structured programmes;
- habits and reflective practice;
- progress tracking;
- member content;
- moderated community;
- challenges;
- live sessions;
- events;
- professional dietetic and medical escalation;
- and long-term support.

The platform must become a coherent ecosystem rather than a loose collection of features.

Every future capability must strengthen the same core outcome:

> Help each participant understand herself, make appropriate health decisions, build sustainable behaviour, and recover without shame when life disrupts progress.

---

# 4. Ultimate Product Position

The platform should ultimately be recognised as:

> A Christian, temperament-guided women’s health and lifestyle ecosystem that combines self-awareness, safe personalisation, practical plans, behaviour-change support, community and professional escalation.

It must not become merely:

- a calorie tracker;
- a meal-plan generator;
- a personality quiz;
- an AI health chatbot;
- a generic content subscription;
- a social network;
- an event ticketing system;
- or a practitioner directory.

Those may exist as supporting capabilities, but they are not the product’s identity.

---

# 5. Ultimate Participant Experience

At maturity, a participant should be able to:

## 5.1 Discover and understand

- read public content;
- choose Afrikaans or English;
- complete the temperament assessment;
- view primary and secondary results;
- understand strengths, vulnerabilities and likely patterns;
- see how temperament affects behaviour, not clinical truth.

## 5.2 Build a safe health foundation

- complete progressive health onboarding;
- receive transparent eligibility routing;
- understand whether she qualifies for automated guidance;
- receive a General Wellness Starter Pathway when deeper personalisation is not yet appropriate;
- be routed to professional review when required.

## 5.3 Receive practical personalised guidance

- receive an explainable seven-day eating and lifestyle plan;
- see kilojoules by default and switch to Calories;
- use approved recipes and substitutions;
- receive more or less structure according to temperament;
- understand why plan decisions were made;
- keep immutable historical versions.

## 5.4 Build sustainable behaviour

- complete a multi-week foundation programme;
- build personally appropriate habits;
- record daily or weekly progress;
- receive monthly trend-based reviews when entitled;
- continue after missed days;
- recover from setbacks without losing all progress.

## 5.5 Belong and participate

- join a moderated member community;
- participate in safe challenges;
- attend live sessions;
- submit questions;
- access event benefits;
- celebrate progress without public weight rankings or shame.

## 5.6 Receive professional support

- purchase practitioner review when needed;
- share information through explicit scoped consent;
- receive approved, modified or practitioner-authored plans;
- maintain a complete review and plan history;
- be referred externally when the platform is not the right care setting.

## 5.7 Maintain long-term health

- review progress over months and years;
- retain purchased reports and plans;
- receive updated approved interpretations;
- adjust safely as goals and life circumstances change;
- remain connected to relevant content and community.

---

# 6. Ultimate Platform Capabilities

The mature platform may contain:

## Public and acquisition

- bilingual public website;
- articles and educational content;
- book and event information;
- assessment and product sales;
- mailing-list signup;
- referrals and campaigns.

## Identity and access

- individual accounts;
- multiple explicit roles;
- purchaser and participant separation;
- scoped staff and practitioner access;
- consent and audit history.

## Temperament

- versioned assessments;
- self-reported, book-derived and digital results;
- immutable scoring;
- report generation;
- mixed-profile interpretation;
- product-family reuse.

## Health and safety

- progressive health profiles;
- safety screening;
- eligibility routing;
- clinical flags;
- laboratory records;
- safety pauses;
- professional escalation.

## Plans and recommendations

- deterministic generation;
- approved calculation protocols;
- modular meals and recipes;
- substitutions;
- bilingual delivery;
- monthly adjustments;
- immutable plan versions;
- practitioner-derived versions.

## Programmes and behaviour change

- modules and lessons;
- habits;
- reminders;
- reflections;
- journals;
- milestones;
- recovery after missed days;
- completion and continuation.

## Content and personalisation

- governed bilingual content;
- approval workflows;
- personalised feed ranking;
- derived relevance flags;
- search and discovery;
- corrections and withdrawals.

## Commerce and membership

- assessments;
- once-off plans;
- bundles;
- memberships;
- add-ons;
- gifts;
- sponsored access;
- promotions;
- events;
- refunds and entitlements.

## Community and events

- moderated groups;
- challenges;
- live sessions;
- Q&A;
- events;
- tickets;
- attendance;
- member benefits.

## Professional services

- practitioner relationships;
- scoped data access;
- review workflows;
- follow-up;
- referrals;
- professional records.

## Operations and analytics

- notifications;
- audit;
- support;
- incident handling;
- product analytics;
- safety analytics;
- performance monitoring;
- backups and recovery.

---

# 7. Ultimate Business Model

The long-term commercial ladder is:

```text
public visitor
→ registered free user
→ assessment customer
→ standard-plan customer
→ basic member
→ member with add-ons
→ premium bundle
→ practitioner-reviewed customer
→ recurring programme, event and community participation
```

Revenue may come from:

- physical books;
- digital assessments;
- once-off plans;
- bundles;
- memberships;
- add-ons;
- foundation programmes;
- events;
- practitioner-reviewed services;
- sponsored access;
- future specialist products.

The platform should create recurring value without promising unlimited individual access to Venessa or other professionals.

---

# 8. Absolute Non-Negotiables

1. Temperament is not a medical or psychological diagnosis.
2. Medical and clinical safety always override temperament preferences.
3. The platform must not promise universal weight loss.
4. Weight is not the sole measure of success.
5. High-risk participants do not receive automated personalised weight-loss plans.
6. AI may assist but may not independently diagnose, prescribe or create unapproved plans.
7. Personalisation must be deterministic, versioned and explainable.
8. Submitted assessment answers and generated plan snapshots remain immutable.
9. Historical records are preserved when corrections or replacements are issued.
10. A missed day must not erase progress.
11. The platform must not use shame, fear or perfectionism as its main behaviour-change mechanism.
12. Participant health data must remain private, scoped and auditable.
13. Paying for another person never grants access to that person’s private health journey.
14. Practitioner access requires explicit consent, active relationship, scope, expiry and audit.
15. The platform is openly Christian and available to everyone.
16. Afrikaans and English are supported from launch.
17. Safety-critical and paid content requires approved bilingual variants.
18. Professional capacity must be protected.
19. Product growth must remain incremental.
20. No coding agent may invent unresolved product, clinical, legal or entitlement rules.

---

# 9. Definition of the MVP

The MVP is not the smallest amount of software that can be deployed.

The MVP is:

> The smallest safe, commercially usable end-to-end slice that proves a woman will pay to understand her temperament, complete appropriate safety onboarding, receive a useful personalised seven-day plan, and engage with the result.

The MVP must prove the core value loop:

```text
discover
→ purchase
→ assess or self-report temperament
→ complete safety intake
→ receive eligibility outcome
→ receive report
→ receive safe plan
→ use plan
→ record feedback and progress
```

The MVP is a **commercial validation product**, not a prototype with fake safety, fake payments or throwaway architecture.

---

# 10. MVP Target Customer

The MVP serves:

- an adult woman aged 18 or older;
- primarily in South Africa;
- comfortable using Afrikaans or English;
- reached through the book, events, existing media or public content;
- interested in understanding her temperament;
- seeking a practical health and eating starting point;
- eligible for a low-risk automated plan or safe general wellness pathway.

The MVP does not initially serve:

- minors;
- household accounts;
- complex clinical cases through automation;
- employers or generic tenants;
- men through the women’s product experience;
- large practitioner networks.

---

# 11. MVP Product Offer

The provisional MVP offer is:

## Public layer

- bilingual landing pages;
- language selection on first visit;
- a small approved public content library;
- clear product information;
- terms, privacy and safety boundaries.

## Paid core offer

A primary paid bundle containing:

- one digital temperament assessment credit;
- low-friction self-reported or book-derived temperament onboarding;
- durable temperament report access while the account relationship exists; completed full deletion permanently ends that access;
- one safe seven-day personalised plan when eligible;
- one complimentary plan regeneration within 90 days when the later digital result materially changes the selected temperament profile.

The digital assessment may also be sold separately.

The South African MVP amounts below are synthetic development fixtures, not launch prices. Final launch list prices, bundle savings and component allocations are governed Commerce configuration selected before launch (Product Law §21L.15 and DEC-328):

```text
Digital Temperament Assessment  R249
7-Day Personalised Plan         R399
Assessment + Plan Bundle        R549
```

The bundle is the expected main marketed offer.

Pricing remains versioned configuration, not hard-coded software behaviour.

---

# 12. MVP End-to-End Journey

## Step 1 — First visit

The participant:

- chooses Afrikaans or English;
- browses public content;
- sees clear Christian positioning;
- views product and safety boundaries.

## Step 2 — Account creation

The participant creates an individual account using:

- first name;
- surname;
- email;
- authentication credential;
- language;
- 18+ confirmation;
- terms and privacy acceptance.

Phone and city remain optional.

## Step 3 — Purchase

The participant purchases:

- the digital assessment;
- or the qualifying assessment-and-plan bundle.

The launch payment direction is:

- South Africa first;
- ZAR billing;
- Paystack as the locked first/launch payment gateway;
- international cards when enabled;
- no assumed true multi-currency billing.

## Step 4 — Temperament onboarding

The participant may:

- complete the digital assessment immediately;
- or declare a self-reported or book-derived primary and optional secondary temperament.

A qualifying bundle preserves the unused digital assessment credit for later use.

## Step 5 — Assessment result

If the participant declared a self-reported or book-derived profile, the participant receives clearly labelled, low-risk guidance based on that declared profile where safety rules permit. The participant does **not** receive exact digital colour scores or the paid digital assessment report, and an included digital assessment credit remains unused.

After the participant completes the digital assessment, the participant receives the digital result and report allowed by current Product Law, including exact scores. The digital result is appended with its own provenance; it does not rewrite the earlier declared profile. The participant may select a current profile under current assessment rules, and a qualifying bundle may permit the existing one-time plan regeneration within 90 days.

Digitally assessed participants receive:

- primary temperament;
- secondary temperament;
- exact colour scores;
- concise strengths and vulnerabilities;
- stress and health patterns;
- communication guidance;
- practical strategies;
- faith reflection;
- limitations;
- next-step guidance.

## Step 6 — Safety-focused plan onboarding

The participant completes the required structured health and lifestyle intake.

The platform produces one of:

```text
eligible_automated
general_wellness_only
professional_review_required
insufficient_information
```

## Step 7 — Plan generation

An eligible participant receives an immutable, explainable, bilingual seven-day plan using:

- approved calculation protocol;
- approved three- or four-meal structure;
- approved modular meals;
- approved recipes;
- approved substitutions;
- temperament-based presentation;
- kilojoules by default;
- optional Calories display.

## Step 8 — Delivery and use

The participant can:

- view the plan;
- view explanations;
- switch language where approved content exists;
- switch between kilojoules and Calories;
- retain purchased report and plan access during the account relationship; completed full deletion permanently ends recovery/access;
- record basic daily or weekly progress.

## Step 9 — Feedback and validation

The MVP collects:

- assessment completion;
- onboarding completion;
- eligibility outcome;
- generation success;
- time to plan;
- plan activation;
- basic progress entries;
- participant feedback;
- safety pauses;
- support issues;
- refund requests.

---

# 13. MVP Included Capabilities

## Accounts

- individual account;
- email/password authentication with optional magic-link sign-in;
- email-verification gates;
- optional participant MFA with step-up for high-risk actions;
- language preference;
- age confirmation;
- terms and privacy acceptance;
- account recovery;
- basic security and audit.

## Language

- Afrikaans and English interface;
- first-entry chooser;
- header language toggle;
- approved bilingual paid and safety content;
- Gettext-style fixed strings later defined in architecture;
- governed runtime content translations later defined in architecture.

## Commerce

- product catalogue;
- product release state;
- ZAR checkout;
- verified payment result;
- assessment and bundle entitlement;
- refund-state handling;
- gift or book code only if required by the chosen launch bundle.

## Assessment

- faithful approved book assessment;
- save and resume;
- one active attempt;
- 30-day expiry;
- equal scoring;
- exact score display;
- primary and secondary result;
- immutable answers;
- immutable historical assessment records while retained; full deletion follows the GQ-010 deletion rules;
- self-reported and book-derived provenance.

## Health and safety

- progressive intake;
- required safety questions;
- provenance;
- four eligibility outcomes;
- high-risk blockers;
- moderate-risk routing;
- eating-disorder boundary;
- pregnancy and breastfeeding boundary;
- allergy and medication boundary;
- General Wellness Starter Pathway;
- urgent-safety message handling.

## Plan

- deterministic generation;
- immutable snapshot;
- seven-day structure;
- three- or four-meal options;
- modular meals;
- approved substitutions;
- approved recipes where required;
- shopping support where included;
- kilojoule and Calorie display;
- participant explanation;
- fail-closed generation;
- corrections and safety replacement.

## Progress and feedback

- basic daily or weekly entries;
- no automatic monthly adjustment in the smallest once-off MVP;
- trend capture for product validation;
- participant feedback;
- basic support workflow.

## Administration

- controlled assessment and content publication;
- product visibility;
- payment and entitlement support;
- safe plan correction and withdrawal;
- audit of sensitive actions;
- operational visibility into generation failure.

---

# 14. MVP Explicit Exclusions

The MVP does not include:

- native iOS or Android applications;
- an AI health chatbot;
- unrestricted AI-generated plans, recipes or translations;
- first-party community;
- complex social feeds;
- direct messaging;
- challenges;
- badges and advanced gamification;
- live-session platform;
- event-management platform;
- practitioner marketplace;
- broad practitioner network;
- automated complex clinical plans;
- pregnancy-specific automated plans;
- eating-disorder treatment pathways;
- laboratory integration;
- automatic document interpretation;
- wearables;
- continuous glucose-monitor integrations;
- detailed calorie-tracking diary;
- true multi-currency billing;
- household accounts;
- minors;
- men’s product;
- generic multi-tenant SaaS;
- corporate dashboards;
- read replicas unless scale requires them;
- advanced monthly premium adjustment unless included in a later pilot;
- full foundation programme.

These exclusions prevent the MVP from becoming the entire five-year platform before the core offer has been validated.

---

# 15. MVP Safety Release Gates

The MVP must not become publicly available until:

1. the IP and operating authority are sufficiently resolved for launch;
2. the assessment methodology version is approved;
3. required Afrikaans and English assessment content is approved;
4. the clinical eligibility matrix is approved;
5. calculation protocols and limits are approved;
6. high-risk and urgent-safety wording is approved;
7. paid and safety-critical translations are complete;
8. payment verification and refund behaviour are tested;
9. no partial or duplicate plan can be delivered;
10. assessment answers and plan snapshots are reproducible;
11. sensitive access is scoped and audited;
12. backup and restore are tested;
13. critical end-to-end tests pass;
14. support and incident ownership are assigned;
15. pilot capacity is defined.

---

# 16. MVP Success Criteria

The MVP succeeds when it proves all of the following.

## Commercial

- participants are willing to pay for the assessment and plan offer;
- checkout completion is acceptable;
- refunds and support requests remain manageable;
- acquisition from the book, events or current media can be measured.

## Product

- participants complete the assessment or self-reported onboarding;
- the report provides clear perceived value;
- eligible participants activate the plan;
- participants understand why the plan fits them;
- language switching and energy-unit switching are understandable.

## Safety

- all participants receive a deterministic eligibility outcome;
- high-risk cases are blocked correctly;
- no partial plan is delivered;
- safety issues can pause or replace plans;
- all generated plans remain traceable to approved inputs and versions.

## Behaviour

- participants can use the seven-day plan in real life;
- participants report acceptable clarity and practicality;
- participants record basic progress;
- participants identify temperament-specific presentation as useful;
- participants can continue after imperfect adherence.

## Operations

- generation failures are visible;
- support can resolve entitlement and access problems;
- corrections can be issued safely;
- audit history is available;
- the system remains stable under the pilot load.

---

# 17. MVP Metrics

Initial MVP metrics should include:

```text
visitor-to-purchase conversion
checkout success
assessment start
assessment completion
self-reported versus digital onboarding
health-intake completion
eligibility-outcome distribution
plan-generation success
plan-generation latency
plan activation
seven-day usage or completion
progress-entry rate
support contacts
refund requests
safety pauses
professional-review recommendations
participant satisfaction
```

Do not define MVP success primarily through weight loss.

Before the first paid participant, define each gate metric's numerator, denominator, qualifying event, measurement window, exclusions, missing-data treatment, cohort and metric-definition version. Do not rewrite a definition retroactively to make an earlier cohort pass.

The initial metric contracts are:

- assessment starter: the first answer is persisted or submitted; completion requires a valid submission and a successfully produced governed result;
- health-onboarding completion: the denominator includes paid participants entitled to a personalised-plan pathway who reach required onboarding; assessment-only customers are excluded;
- plan activation: the denominator is successfully delivered personalised plans, and activation requires a post-delivery participant action, not generation or notification alone;
- meaningful seven-day use: engagement occurs on at least three distinct days in the first seven, with at least one engagement after Day 1.

The controlled-pilot interpretation retains the 70% positive value/relevance target and also requires at least 70% survey response. Show non-response. Report small cohorts as both count and percentage, such as `8 / 10 (80%)`. The full metric contract is in `00_PLATFORM_v1.6.0.md` §21T.7.

The strongest validation question is:

> Did the participant understand herself better, receive safe useful guidance, use the plan, and feel able to continue after ordinary setbacks?

---

# 17A. Locked Launch and Pilot Boundary

The initial customer-facing product space is the women’s health and lifestyle experience.

South Africa launches first.

The initial paid catalogue is configured by Commerce before launch. Development and proof use these synthetic fixture amounts, which are not launch prices (DEC-328):

```text
Digital Temperament Assessment   R249
7-Day Personalised Plan          R399
Assessment + Plan Bundle         R549
```

The core MVP must prove:

```text
public bilingual discovery
→ secure account
→ checkout
→ temperament assessment/provenance
→ report
→ health/safety intake
→ eligibility
→ personalised 7-day plan OR General Wellness
→ purchased library
→ lightweight progress
→ support/admin
```

Rollout is staged:

```text
internal validation
→ first 10 paid participants
→ review
→ expand toward 25
→ review
→ maximum 50 in first paid pilot
→ expanded pilot
→ limited public
→ general public
```

The first pilot has zero-tolerance integrity criteria for:

- platform-caused critical safety failures;
- duplicate charges;
- duplicate entitlement grants;
- unreproducible delivered plans;
- unauthorised sensitive-data exposure.

Expansion requires explicit product/commercial, clinical/safety and technical/operations authority.

The first 10 are genuine self-paying adult women from the approved South African launch audience, primarily recruited through existing book/event/media reach, using the real bilingual product and catalogue. Do not select only easy-to-automate cases or engineer temperament or eligibility outcomes. Target at least two Afrikaans-first and two English-first participants to exercise both launch languages; this is not a representativeness claim. Record invitation/exposure, eligibility to purchase, checkout and payment events, product, list price, promotion, actual amount paid, acquisition source, language, temperament provenance, eligibility outcome and relevant familiarity/context.

The first 10, 25 and 50 evaluate demand, offer, value and operational economics. Invited-pilot conversion is not ordinary visitor-to-purchase conversion. The pilot validates the offer and delivery; limited public release begins ordinary acquisition-funnel measurement. Product-value refunds use the existing first-10 stop signal. Keep safety/eligibility and technical/payment refunds separate from dissatisfaction evidence. Measure support burden before setting any time threshold.

### Evidence maturity

Day 7 may support conclusions about comprehension, safety, relevance, practicality, activation, initial usage, early perceived value and recovery after an ordinary miss that occurred naturally. It does not prove sustainable long-term habit formation.

Do not manufacture a setback. Count recovery only for participants who experienced or reported a relevant interruption, and report participants with no interruption separately. Collect lightweight Day 30 evidence on useful behaviour continuation, guidance reuse, interruptions, return after interruption and continuing usefulness of personalisation. Collect directional Day 90 evidence on personally appropriate behaviours, recovery and durability beyond initial novelty. The mature directional measure remains at least three personally appropriate health behaviours 90 days later.

The first 10-to-25-to-50 sequence may proceed under existing safety, product, commercial and operational gates while Day 30/90 evidence matures in parallel. Do not wait 90 days between cohort expansions. Claims must match the evidence available. MVP success does not prove the long-term North Star.

Targeted safety or technical rollback may occur immediately when required.

Basic Membership launches only when its promised recurring value exists.

Premium follows proven recurring adjustment capability.

Practitioner review begins through a capacity-controlled pilot.

Nuwe Jy is the first native flagship expansion after core MVP hardening.

# 18. What Comes Immediately After the MVP

The first flagship vertical expansion is now explicitly **Nuwe Jy – 60 Dag Uitdaging**.

Recommended progression:

```text
core platform foundation
→ assessment
→ safety
→ plan and entitlement foundation
→ core paid MVP pilot
→ hardening
→ first Nuwe Jy edition on the new platform
→ Basic Membership once minimum recurring value is operationally ready
→ plan-adjustment add-on
→ Premium bundle
→ controlled practitioner-review pilot
→ wider programmes / first-party community / full event commerce
```

The launch sequence, MVP catalogue and product-space direction are now locked by GQ-012.

Basic Membership uses a future planning anchor of R199/month or R1,990/year, but its final public price may still be commercially re-versioned before that product launches.

Nuwe Jy must influence architecture from the beginning so that the flagship does not require redesign of Accounts, Programmes, Content, Safety, Plans, Entitlements, Notifications, Community, Live or Analytics.
# 18A. Nuwe Jy Flagship Acceptance Test

Nuwe Jy is not an LMS clone and is not a LearnDash migration project.

It must prove the platform can support:

- approved programme versions;
- editions and cohorts;
- 60 preconfigured daily releases;
- a useful Today experience;
- daily actions, habits, reflections and check-ins;
- recovery after missed days;
- facilitator boundaries;
- cohort community;
- live sessions and governed replays;
- central safety and plan integration;
- role-scoped operations;
- repeat participation;
- compassionate completion/certification.

No general LearnDash importer, converter or compatibility subsystem is required.

The clean-cutover rule is:

```text
complete current legacy obligations
→ configure a future named Nuwe Jy edition natively
→ run that edition entirely on the new platform
→ retire LearnDash when contractual/support/retention obligations permit
```

# 19. Long-Term Expansion

After the women’s product is proven, the platform may expand through controlled product spaces:

```text
women’s product
→ specialist women’s programmes
→ professional services
→ future men’s product
→ selected partner or sponsored programmes
```

This should use one operating platform with separated product experiences, not an unrestricted generic multi-tenant SaaS product.

---

# 19A. Privacy, Security and Operational Trust Boundary

The platform makes a clear distinction:

```text
account closure
→ 30-day recovery

full deletion request
→ immediate normal-access revocation
→ 14-day cancellation window
→ irreversible deletion execution
```

Completed full deletion has no account, entitlement, plan, journal or health-profile reconstruction path.

Financial, professional, security or legal records retained by obligation are isolated from product recovery and personalisation.

Backups exist for disaster recovery only. Any restore must replay deletion and consent-withdrawal events before normal service resumes.

Security principles:

- participant email/password + optional magic link;
- email verification before sensitive capability;
- optional participant MFA + risk-based step-up;
- mandatory MFA for staff/practitioners;
- expiring/revocable sessions and trusted devices;
- governed account recovery;
- least-privilege scoped role grants;
- named short-lived break-glass access;
- no shared privileged accounts;
- no routine developer access to health records;
- no production participant-data copies in local development.

Operational principles:

- Cloudflare/application/Redis layered abuse control;
- malware-scanned governed uploads;
- durable Oban notification delivery;
- graceful degradation instead of unsafe guessing;
- SEV-1 through SEV-4 incidents;
- backup/restore tests;
- infrastructure, application and domain observability.

# 19B. Performance and Scaling Handoff

All later architecture and implementation work must preserve the mandated performance model:

```text
hot → ETS / GenServer / Cachex
warm → Redis
cold → PostgreSQL
public static/media → Cloudflare CDN/object storage
```

Use PubSub/LiveView push for real-time experiences and Oban for heavy work.

High-concurrency flows require idempotency, locking/invariants, indexes and distributed rate controls.

Event flash-sale paths must support expiring holds, queue/rate protection and anti-stampede behaviour.

Analytics uses cached/materialised aggregates and read replicas when scale warrants them, never peak-time full scans.

Targets include:

- sub-100 ms common API paths where practical;
- checkout p99 below 5 seconds where provider latency permits;
- zero confirmed oversell;
- zero duplicate entitlement grant;
- safe horizontal multi-node operation.

Correctness, clinical safety, privacy and financial integrity outrank latency.

# 20. Agent Handoff Rules

A new planner or coding agent must:

1. read this document first;
2. read the Platform document;
3. read the Decision Register;
4. read Open Work;
5. consult the relevant book source documents;
6. identify whether the requested work is planning or implementation;
7. stop when a required decision is unresolved;
8. never replace locked rules with generic best practice;
9. never infer clinical thresholds;
10. never weaken safety for speed;
11. never build deferred capabilities into the MVP;
12. preserve bilingual and audit requirements;
13. keep changes incremental and traceable.

---

# 21. Agent Tool Boundary

During remaining Grill-Me and product planning:

Use only:

- read access to the core Markdown documents;
- read access to the approved book sources;
- Markdown editing;
- official current documentation when external behaviour must be verified.

Do not use:

- code generators;
- migrations;
- package installation;
- deployment tools;
- implementation agents.

During implementation later, the exact tool list must be stated in the current tracer-bullet or vertical-slice document.

---

# 22. Agent Stop Conditions

An agent must stop and report the blocker when:

- a required decision is absent;
- two authoritative documents conflict;
- a clinical threshold is not approved;
- a legal or IP gate blocks production;
- a required translation is missing;
- a safety-critical content version is not approved;
- payment delivery cannot be verified;
- implementation would expose private health data;
- a task expands beyond the current slice;
- a requested feature belongs to the explicit MVP exclusions;
- a change would alter product policy rather than implement it.

An agent must not continue by making a plausible assumption.

---

# 23. Current Planning Position

The general Product Grill and earlier targeted amendment programme are closed for the approved product direction. Named expert, clinical, operational and release gates remain governed by current Open Work and Roadmap.

```text
GQ-001 through GQ-012
GQ-NY-001
```

Current Product/Decision/Roadmap authority is routed by README and CURRENT_AUTHORITY_MANIFEST. README and current Open Work own the active programme stage and NEXT route. This North Star does not authorise HARDEN-02 execution, implementation or Phase 8 proof.

Use the current routing in README and Open Work for the active next stage. The downstream planning order remains:

```text
AR-000 Architecture Requirement Extraction
→ architecture decision workstreams
→ reference-flow pressure testing
→ 03_ARCHITECTURE.md
→ 04_DOMAIN_MAP.md
→ Domain Architecture Profiles
→ 05_ROADMAP.md
→ Feature Packs
→ JIT implementation-grade Domain Dossiers
→ Architectural Proof (reuse existing proof or execute a tracer bullet)
→ vertical slices
→ horizontal hardening
→ release/readiness evidence
→ JIT TOON execution instructions
```

The next role remains planner/architect, not implementation coder. Architectural Proof is the first authorised executable development stage and begins only after its upstream planning authority is complete.

# 24. Document Stop Condition

**Current Product Law / governance-alignment condition: MET (v1.3.0).**

This document remains the frozen product North Star/MVP baseline because:

- GQ-001 through GQ-012 and GQ-NY-001 are complete;
- exact MVP launch catalogue is locked;
- initial list pricing is locked as versioned business configuration;
- pilot capacity and stages are locked;
- controlled product-space direction is locked;
- Nuwe Jy release position is locked;
- membership/premium/practitioner sequence is locked;
- launch go/no-go, performance, safety and rollback gates are locked;
- remaining named product, clinical, legal, vendor, architecture and operations gates remain open at their stated scope.

This North Star successor does not claim that the long-term North Star has been proven by MVP success.

Do not reopen product Grill-Me without a genuine contradiction, expert finding or new business direction.

**Implementation STOP:** do not begin executable development — including Architectural Proof/tracer-bullet code, coding-agent vertical slices, Ash resource implementation, migrations or production infrastructure — until the governing architecture is approved, the complete Domain Map and Domain Architecture Profile baseline are approved, the selected Feature Pack and its dependencies are explicit, every affected implementation-grade Domain Dossier is approved, and every gate required by that executable task is resolved or explicitly excluded.
