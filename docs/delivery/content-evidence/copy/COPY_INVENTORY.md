# Wellness Platform complete copy inventory

This is a family-level inventory. Exact semantic items for NOW/SHARED_BASELINE are in `COPY_REGISTRY.json`; JIT/RELEASE families remain stubs until their feature context is sufficient.

| Copy family | Class | Readiness | Likely owner | Approval needs | Notes |
| --- | --- | --- | --- | --- | --- |
| GLOBAL / language | B | SHARED_BASELINE | Content & Media | Content + language review | Selector, saved language, unavailable translation, no-fallback and legal-language disclosure. |
| GLOBAL / public navigation | B | SHARED_BASELINE | Content & Media | Normal copy review | Home, Content, Programmes, Products, About, Help, Contact, Search, Create account, Log in. |
| GLOBAL / participant navigation | B | SHARED_BASELINE | Content & Media | Normal copy review | Home, Plan, Programmes, Progress, Content, Profile, Settings, Help, Log out. |
| GLOBAL / actions | B | SHARED_BASELINE | Content & Media | Normal copy review | Continue, Back, Next, Previous, Save, Submit, Confirm, Cancel, Delete, Retry, Search, Upload, Start, Resume, Complete, support. |
| GLOBAL / forms | B | SHARED_BASELINE | Content & Media | Normal copy review | Required/optional, selection, character count, password reveal, saved/unsaved/saving. |
| GLOBAL / validation | B | SHARED_BASELINE | Content & Media | Normal copy review | Required, email/phone/date/number, length, mismatch, selection, file, generic form errors. |
| GLOBAL / success-pending-failure-degraded states | B | SHARED_BASELINE | Content & Media | Normal copy review | Honest authoritative, pending, unavailable, connection, unknown and safe-next-action states. |
| GLOBAL / empty states | B | SHARED_BASELINE | Content & Media | Normal copy review | No results/notifications/programmes/plan/content/progress/events/transactions/messages/work/attention. |
| GLOBAL / confirmations | B | SHARED_BASELINE | Content & Media | Normal copy review; domain review when destructive | Delete/remove/cancel/leave/revoke/publish/approve/send. |
| GLOBAL / accessibility | B | SHARED_BASELINE | Content & Media | Accessibility + language review | Skip, labels, expand/collapse, loading/error/success announcements, dialogs, charts, tables; alt text patterns. |
| GLOBAL / file handling | B | SHARED_BASELINE | Content & Media | Normal copy review | Choose/drag/replace/remove/upload/download/size/type/error. |
| GLOBAL / dates and time | B | SHARED_BASELINE | Content & Media | Normal copy review | Today/yesterday/tomorrow/ago/updated/created/due/overdue/scheduled/effective/expires/never. |
| PUBLIC / shell | B | JIT | Content & Media | Normal copy review | Header/footer/account access/language/search/support/legal/social/copyright. |
| PUBLIC / homepage | B | JIT | Content & Media | Brand/content review | Hero, supporting statement, CTAs, proposition, benefits, how it works, trust, FAQs. Do not freeze mature marketing prematurely. |
| PUBLIC / about | B | JIT | Content & Media | Brand/content review | Mission, philosophy, approach, differentiators, team, credibility, CTA. |
| PUBLIC / content discovery | B | JIT | Content & Media | Normal copy review | Landing/search/filters/categories/topics/featured/latest/related/reading metadata/share/save/newsletter/no results. |
| IDENTITY / create account and registration | A+B | NOW | Content & Media + Identity | Content/language; legal/privacy for gates | P8-05 bilingual candidate: fields, instructions, age confirmation, acceptance of both exact Terms and Privacy versions, Privacy Notice presentation, submit, pending/failure/neutral response. The v0.3 candidate uses separate acceptance controls; Product Law does not set control count. |
| IDENTITY / verification pending and resend | B | NOW | Content & Media + Identity | Content/language | P8-05 pending explanation, address, resend, neutral result, access limitation, safe public actions. No change-email in current slice. |
| IDENTITY / verification result | B | JIT | Content & Media + Identity | Content/language | Verifying/verified/already/expired/invalid/superseded/unavailable/new request/continue. Do not invent lifecycle semantics. |
| IDENTITY / login | B | JIT | Content & Media + Identity | Content/language + security review for sensitive states | Email/password, submit, recovery, create account, generic failure, unverified, processing, session expired. |
| IDENTITY / password recovery | A+B | JIT | Content & Media + Identity | Security/content/language | Neutral submission, check email, reset, invalid link, new password, success, return. |
| IDENTITY / change email | A | JIT | Identity + Content & Media | Security/content/language | Current/new email, reauth, pending verification, old-address notice, cancel, failure. Excluded from P8-05 pending slice. |
| LEGAL / Terms governing body | A | RELEASE | Content & Media + Legal | Legal approval | English-only immutable governing document. Existing development baseline is non-production only. |
| LEGAL / Privacy governing body | A | RELEASE | Content & Media + Privacy/Legal | Privacy/legal approval | English-only immutable governing document. Existing development baseline is non-production only. |
| LEGAL / consent permissions | A | JIT | Privacy & Consent | Privacy/legal + specialist + language | Health, programme, marketing, sharing, professional, research if applicable, withdrawal. Never bundle unrelated purposes. |
| PRIVACY / data rights | A | JIT | Privacy & Consent | Privacy/legal + language | Access/export/correction/deletion/restriction/withdrawal/verification/pending/completion/retained-record limits. |
| PRIVACY / cookies and tracking | A | JIT | Privacy & Consent | Privacy/legal + language | Essential/analytics/marketing/preferences; accept/reject/manage/save. |
| SAFETY / launch framing | A | NOW | Content & Media + Safety | Health content + language | Only current P8-05 launch-facing boundary; no generic emergency wording. |
| SAFETY / general and professional-care limitations | A | JIT | Safety & Eligibility | Health/clinical/legal + language | General wellness scope and care limitations on applicable surfaces. |
| SAFETY / eligibility and warnings | A | JIT | Safety & Eligibility | Clinical/safety + language | Rapid-loss, eating-disorder, pregnancy, contraindication, medication, severe symptoms, professional review, insufficient information. |
| SAFETY / urgent support | A | RELEASE | Safety & Eligibility | Clinical + legal + second safety approval + language | Only where a governed urgent-safety outcome exists. |
| PARTICIPANT / onboarding | B | JIT | Content & Media | Content/language | Welcome, orientation, how it works, next steps, privacy reassurance, first journey, optional skip. |
| PARTICIPANT / Home | B | JIT | Content & Media + owning Domains | Content/language | Welcome, next action/resume, plan/programmes/upcoming/progress/recommendations/notifications/no active items/locked discovery. |
| PARTICIPANT / Profile | B | JIT | Identity + Content & Media | Content/language | Personal details, preferred name where applicable, email, language, verification status, edit/save. |
| PARTICIPANT / Settings | A+B | JIT | Owning Domains | Domain/content/language + privacy/security where relevant | Account/language/communications/privacy/security/password/sessions/export/closure/notifications/marketing. |
| HEALTH / intake | A | JIT | Health Records + Safety/Privacy | Health/privacy/clinical as applicable + language | Purpose, why ask, sensitive-data, sections, conditions, medication, allergies, pregnancy, symptoms, measurements, lifestyle, missing meanings, review/submit. |
| ASSESSMENTS | A | JIT | Temperament / applicable owner | Methodology/content/language + safety where applicable | Title/purpose/duration/instructions/questions/choices/help/progress/review/submit/results/limitations/next/safety escalation. |
| MEASUREMENTS | A+B | JIT | Health Records | Health content + language | Names/units/instructions/value/date/trend/history/missing/insufficient/out-of-range/correction. |
| PLANS / lifecycle | A | JIT | Plans & Nutrition | Health/clinical/content/language | Generating/review/pending/professional review/insufficient/ready/updated/why changed/next action. |
| PLANS / content | A | JIT | Plans & Nutrition + Content & Media | Health/clinical/content/language | Goals/recommendations/meals/activity/habits/reminders/explanations/warnings/substitutions/progress. |
| PROGRAMMES / discovery | B+A where safety/commercial | JIT | Programmes & Challenges | Content/language + commerce/safety as applicable | Name/description/audience/benefits/duration/requirements/price/eligibility/included/safety/FAQ/CTA. |
| PROGRAMMES / participation | B | JIT | Programmes & Challenges | Content/language | Welcome/module/week/day/objectives/lessons/activities/completion/next/missed/resume/complete. |
| HABITS | B | JIT | Habits, Journals & Progress | Content/language | Name/description/frequency/reminder/complete/skip/missed/progress; non-shaming. |
| PROGRESS | B+A where interpretation is health-significant | JIT | Habits, Journals & Progress | Content/language + health where applicable | Period/trends/achievements/no data/insufficient/goal status/interpretation/encouragement/caveats. |
| JOURNAL | A+B | JIT | Habits, Journals & Progress | Privacy/content/language + safety where notice applies | Add/prompt/privacy/save/draft/edit/delete/attachment/empty/non-monitoring notice. |
| CONTENT LIBRARY / article framework | B+A by content risk | JIT | Content & Media | Risk-based content approvals + language | Title/subtitle/summary/body/takeaways/warnings/author/reviewer/dates/categories/topics/related/sources/CTA/disclaimer/metadata. Bodies stay JIT. |
| FOOD / recipe / nutrition terminology | A+B | SHARED_BASELINE/JIT | Content & Media + Plans & Nutrition | Content/health/language | Ingredients/meals/preparation/measurements/servings/portions/nutrition/allergens/substitutions/dietary/actions. Recipe bodies JIT. |
| COMMERCE / products | B+A | JIT | Commerce + Content & Media | Commerce/content/language | Name/description/pricing/billing/included/eligibility/benefits/CTA/FAQ. |
| COMMERCE / checkout | A+B | JIT | Commerce | Commerce/legal/privacy/language | Cart/quantity/subtotal/total/discount/promo/billing/payment method/confirm/terms/processing/retry. |
| COMMERCE / payment states | A | SHARED_BASELINE/JIT | Commerce | Commerce/content/language | Processing/success/failed/pending/verifying/do-not-pay-again/safe-next-action/receipt. Never fabricate success. |
| COMMERCE / subscription | A | JIT | Commerce + Entitlements | Commerce/legal/language | Active/pending/renewed/expires/cancel/consequence/reactivate/access. |
| COMMERCE / refunds | A | JIT | Commerce | Commerce/legal/language | Request/eligibility/pending/approved/declined/processing/completed. |
| COMMUNICATIONS / verification email | A | NOW | Content & Media + Communications | Existing dev-approved exact bytes; runtime approvals pending | Reuse current EN/AF evidence packet; do not rewrite casually. |
| COMMUNICATIONS / security and identity | A | JIT | Communications + Identity | Security/content/language | Password reset/changed/email change/recovery/suspicious activity/closure. |
| COMMUNICATIONS / commerce | A | JIT | Communications + Commerce | Commerce/content/language | Receipt/purchase/pending/failed/refund/subscription/cancellation. |
| COMMUNICATIONS / programme | B | JIT | Communications + Programmes | Content/language | Welcome/reminder/milestone/event/completion. |
| COMMUNICATIONS / marketing | A | JIT | Communications + Privacy | Privacy/content/language | Subscribe/confirm/newsletter/preference/unsubscribe/withdrawal; purpose permission separate from preference. |
| SUPPORT / help centre | B | JIT | Support + Content & Media | Content/language | Landing/search/categories/FAQs/account/payment/programmes/health/privacy/contact. |
| SUPPORT / contact | A+B | JIT | Support | Support/privacy/content/language | Category/description/attachment/sensitive-info warning/submit/confirmation/failure/reference. |
| SUPPORT / states | B | JIT | Support | Operations/content/language | Received/assigned/in progress/waiting for participant/resolved/closed. |
| NOTIFICATIONS | B | JIT | Communications | Content/language | Title/body/action/timestamp/read/unread/mark read/all read/empty/preferences. |
| SEARCH | B | JIT | Content & Media | Content/language | Placeholder/results/no results/recent/filter/clear/suggestions/unavailable. |
| SEO / social | B | JIT | Content & Media | Content + language | SEO title/description/OpenGraph/share/alt/structured-data textual values per public page. |
| OPERATOR / Command Centre | B | JIT | Operations | Owner/operator review | Attention/summaries/pending/overdue/alerts. |
| OPERATOR / Work | B | JIT | Operations | Owner/operator review | Unassigned/assigned/in progress/changes requested/resolved/claim/assign/reassign/release/priority/due. |
| OPERATOR / Approval | A+B | JIT | Relevant Domain + Operations | Domain/policy review | Approve/request changes/reject if allowed/reviewer/reason/history/separation of duty. |
| OPERATOR / Content operations | B | JIT | Content & Media | Content owner | Draft/review/approved/translation/language review/scheduled/published/superseded/withdrawn. |
| OPERATOR / Audit and activity | B | JIT | Audit & Evidence | Audit owner | Human-readable created/changed/approved/verified/revoked/superseded/reconciled/assigned/sent. |

## Anti-over-governance rule

Mechanical labels, ordinary navigation, low-risk component copy and developer/internal text do **not** automatically become Class A. Class A is reserved for wording whose exact semantics/version/approval materially affect safety, legal/privacy/consent, security/identity, commercial truth or an explicit governed exact-copy requirement.

## Detailed surface checklist

The family table above carries the default class/readiness/owner/review route. This checklist makes the known surface coverage explicit so later JIT work does not rediscover it.

### A. Global / shared
- **Language:** selector, Afrikaans, English, change language, saved language, unavailable translation, explicit fallback offer for optional low-risk content, no-fallback blocked state, legal-document-language disclosure.
- **Navigation — public:** Home, Content/articles, Programmes, Products, About, Help, Contact, Search, Create account, Log in.
- **Navigation — participant:** Home, Plan, Programmes, Progress, Content, Profile, Settings, Help, Log out.
- **Actions:** Continue, Back, Next, Previous, Save, Save changes, Submit, Confirm, Cancel, Close, Delete, Remove, Edit, Update, Retry, Search, Filter, Sort, Clear, Reset, Add, Upload, Download, Start, Resume, Pause, Complete, Contact support.
- **Forms:** Required, Optional, guidance, placeholders where useful, character count, select one/many, date format, password requirements only when authoritative, show/hide password, unsaved changes, saved, saving.
- **Validation:** required, invalid email/phone/date/number, too short/long, mismatch, invalid selection, unsupported file, upload failure, generic form error.
- **States:** saved, updated, submitted, completed, sent; saving, processing, verifying, waiting, pending review, checking status; action failed/retry/unavailable; connection lost/reconnecting/service unavailable/status unknown/safe next action/do-not-repeat-yet.
- **Empty states:** no results, notifications, programmes, plan, content, progress, events, transactions, messages, work, nothing requiring attention.
- **Confirmations:** delete, remove, cancel, leave without saving, revoke, publish, approve, send.
- **Accessibility:** skip navigation, screen-reader action labels, image-alt patterns, expand/collapse, loading announcements, error summary, success announcement, dialogs, charts, tables.
- **Files:** upload, choose, drag/drop, replace, remove, download, uploading, complete, failed, too large, invalid type.
- **Date/time:** Today, Yesterday, Tomorrow, ago, last updated, created, due, overdue, scheduled, effective, expires, never.

### B. Public website
- **Shell:** header, footer, account access, language, search, support, legal links, copyright, social links.
- **Homepage:** hero, support statement, primary/secondary CTA, what NewYou is, benefits, how it works, programmes/products, content discovery, trust, safety, newsletter relationship, FAQ, final CTA. Marketing positioning remains JIT unless required by the current bounded launch path.
- **About:** mission, philosophy, approach, differentiators, wellness/safety positioning, team, credibility, CTA.
- **Content discovery:** landing, search, filters, categories, topics, featured, latest, related, reading time, byline, dates, share, save, newsletter CTA, no results.

### C. Identity & account
- **Create account:** heading, intro, reason to create, existing-account prompt, Log in, eligibility framing if applicable, what happens next.
- **Registration NOW:** title, intro, DEC-027 labels, genuinely needed field help, required/optional, validation, 18+ gate, acceptance of both exact Terms and Privacy versions, links, Privacy Notice presentation, submit, processing, generic failure, neutral accepted result, transition to pending. The current copy candidate uses separate acceptance controls, a UX choice rather than a Product Law requirement.
- **Verification pending NOW:** title, registration result explanation, inbox instruction, safely/masked displayed email, verification explanation, email-not-arrived guidance, resend, resend processing, neutral accepted result, failure, unverified access limitation, safe public actions. **No change email in current P8-05.**
- **Verification result JIT:** verifying, verified, already verified, expired, invalid, superseded, unavailable, request another verification, continue — only once actual Identity lifecycle semantics support them.
- **Login JIT:** title, email, password, show/hide, submit, forgot password, create account, generic credential failure, unverified state, processing, session expired.
- **Password recovery JIT:** forgot password, neutral submission, check email, reset password, expired/invalid link, new password, success, return to login.
- **Change email JIT:** current/new email, confirm, reauthentication, pending verification, old-address notice, cancel, failure, security wording.

### D. Legal / privacy / consent
- **Terms:** exact body, title, version, effective date, acceptance UI, applicability, supersession.
- **Privacy:** exact body, title, version, effective date, acceptance UI, applicability, supersession.
- **Consent:** health information, programme consent, marketing, optional sharing, professional sharing, research if ever applicable, withdrawal. Each permission remains purpose-specific.
- **Data rights:** access, export, correction, deletion, restriction, withdrawal, pending request, identity verification, completion, records that cannot be deleted where applicable.
- **Cookies/tracking if applicable:** essential, analytics, marketing, preferences, accept, reject, manage, save preferences.

### E. Safety
- General wellness scope; professional-care limitations; emergency limitations only where applicable; eligibility; rapid-loss risk; eating-disorder risk; pregnancy; contraindications; medication risk; severe symptoms; professional review required; insufficient information; urgent support. Exact high-risk wording remains Class A and JIT/RELEASE as applicable.

### F. Participant onboarding
- Welcome, orientation, how NewYou works, what happens next, Home explanation, privacy reassurance, first journey, continue, skip where allowed.

### G. Participant Home
- Welcome, next action, resume, plan, programmes, upcoming, progress, recommended content, notifications, no active programme, no plan, locked/unavailable, contextual discovery/purchase CTA.

### H. Profile & settings
- **Profile:** personal details, preferred name where applicable, email, preferred language, verification status, edit, save.
- **Settings:** account, language, communications, privacy, security, password, sessions/devices if supported, export, account closure, notifications, marketing preferences.

### I. Health intake
- Intro, purpose, why we ask, sensitive-data explanation, medical limitations, section titles, health conditions, medications, allergies, pregnancy, symptoms, measurements, lifestyle, sleep, nutrition, activity, family history, unknown, not tested, prefer not to answer, save/resume, progress, review, submit, professional review, insufficient information. Detailed clinical questions stay JIT.

### J. Assessments
- Per assessment: title, purpose, duration, instructions, questions, choices, help, progress, review, submit, results, limitations, next actions, safety escalation.

### K. Measurements
- Names, units, instructions, enter value, date, trend, history, missing, insufficient data, out-of-range handling, correction.

### L. Plans
- **Lifecycle:** generating, reviewing, pending, professional review required, insufficient information, ready, updated, why changed, next action.
- **Content:** goals, recommendations, meals, activity, habits, reminders, explanation, warnings, substitutions, progress.

### M. Programmes
- **Discovery:** name, description, audience, benefits, duration, requirements, price, eligibility, included, safety, FAQ, CTA.
- **Participation:** welcome, module/week/day, objectives, lessons, activities, completion, next, missed, resume, programme complete.

### N. Habits
- Name, description, frequency, reminder, mark complete, skip, missed, progress, streaks only where appropriate, encouragement and recovery language.

### O. Progress
- Progress, period, trends, achievements, no data, insufficient data, goal status, interpretation, encouragement, caveats.

### P. Journal
- Add entry, prompt, privacy, save, draft, edit, delete, delete confirmation, attachment, empty state, applicable non-monitoring notice.

### Q. Content library
- Article/content title, subtitle, summary, body, key takeaways, warnings, author, reviewer, published, updated, categories, topics, related, sources, CTA, disclaimer, metadata. Future article bodies are not pre-translated here.

### R. Food / recipe / nutrition
- Ingredients, meal names, preparation, measurements, servings, portions, nutrition terms, allergens, substitutions, dietary terms, recipe actions. Content bodies remain JIT.

### S. Commerce
- **Products:** name, description, pricing, billing, included, eligibility, benefits, CTA, FAQ.
- **Checkout:** cart, quantity, subtotal, total, discount, promo, billing, payment method, confirm, terms, processing, retry.
- **Payment:** processing, success, failed, pending, verifying, do-not-pay-again, safe next action, receipt. Ambiguity never becomes false success.
- **Subscription:** active, pending, renewed, expires, cancel, cancellation consequence, reactivate, access.
- **Refund:** request, eligibility, pending, approved, declined, processing, completed.

### T. Communications
- **Verification email NOW:** exact current EN/AF source evidence; preserve existing development baseline.
- **Security/identity:** reset password, password changed, email change, recovery, suspicious activity, account closure.
- **Commerce:** receipt, purchase, pending payment, failed payment, refund, subscription, cancellation.
- **Programme:** welcome, reminder, milestone, event, completion.
- **Marketing:** subscribe, confirm, newsletter, preference, unsubscribe, permission withdrawal. Preferences and purpose-level permission stay distinct.

### U. Support
- **Help centre:** landing, search, categories, FAQs, account, payment, programmes, health, privacy, contact.
- **Contact support:** title, category, description, attachment, sensitive-info warning, submit, confirmation, failure, reference.
- **Support states:** received, assigned, in progress, waiting for participant, resolved, closed.

### V. Notifications
- Title, body, action, timestamp, read/unread, mark read, mark all read, empty state, preferences.

### W. Search
- Placeholder, results, no results, recent, filter, clear filters, suggestions, unavailable.

### X. File handling
- Upload, choose file, drag/drop, replace, remove, download, uploading, complete, failed, too large, invalid type.

### Y. Dates / time
- Today, Yesterday, Tomorrow, ago, last updated, created, due, overdue, scheduled, effective, expires, never.

### Z. SEO / social
- SEO title, meta description, OpenGraph title/body, share copy, alt text, structured-data textual values, locale alternates/canonicals where applicable. Write per page JIT.

### AA. Operator experience
- **Command Centre:** work requiring attention, summaries, pending, overdue, alerts.
- **Work:** unassigned, assigned, in progress, changes requested, resolved, claim, assign, reassign, release, priority, due.
- **Approval:** approve, request changes, reject only where semantics permit, approval required, reviewer, reason, history, separation of duty.
- **Content operations:** draft, review, approved, translation, language review, scheduled, published, superseded, withdrawn.
- **Audit/activity:** human-readable created, changed, approved, verified, revoked, superseded, reconciled, assigned, sent. Raw internal event names are not participant/operator copy by default.

## Legal UX working-candidate surfaces added in v0.3.0

The legal UX pack adds reviewable Class-A candidate/template coverage for contextual disclaimers, marketing-purpose permission, marketing channel preferences, cookie banner/preferences/notice shell, health-data JIT disclosure, special-PI consent review shell, practitioner-sharing permission and SKU-specific early-performance instruction. These are JIT/RELEASE candidates only; they do not move their production gates.
