# Wellness Platform bilingual voice and style guide

## 1. Voice

The platform voice is warm, human, clear, calm, practical, non-judgmental and quietly encouraging. It is feminine without stereotypical beauty/spa language. Safety precision outranks warmth where the two conflict. Operator language may be denser and more functional.

The book foundation adds a useful principle: **help the woman work wisely with who she already is, rather than speaking as if health requires becoming a different person.** Product copy should preserve that dignity while being much shorter than editorial/book prose.

## 2. Core writing principles

1. Say what happened, what is known and what the person can safely do next.
2. Do not fabricate success. Pending, verifying, unavailable and ambiguous states must remain visibly distinct.
3. Use plain verbs and short sentences. Put the action first on buttons.
4. Do not shame, moralise, threaten or imply perfection is required.
5. Do not overpromise weight loss, clinical outcomes, continuous monitoring or instant results.
6. Do not expose internal Domain/resource/provider names in participant copy.
7. Ask only for information relevant to the current journey; copy must not make a minimal form feel like a future health intake.
8. Use contextual CTAs. Do not turn public content into a generic forced-signup funnel.

## 3. English

- Use South African/British product English where natural: `programme` rather than `program` for participant programmes.
- Use sentence case for headings/buttons unless the brand/design system later specifies otherwise.
- Prefer `email` in English and `e-pos` in Afrikaans.
- Prefer contractions in ordinary participant copy when they improve warmth (`We’ll`, `couldn’t`, `isn’t`). Avoid them in legal/safety text where precision benefits from full forms.
- Avoid medical certainty unless approved clinical authority supports it.

## 4. Afrikaans

- Use natural South African Afrikaans, not word-for-word English structure.
- Default participant address is `jy/jou`, not formal `u`, unless a future brand decision changes this.
- Prefer concise native verbs: `Meld aan`, `Stoor`, `Wysig`, `Skrap`, `Hervat`, `Dien in`.
- Use `e-pos`, `e-posadres`, `wagwoord`, `rekening`, `instellings`, `vordering`.
- Avoid Dutch vocabulary/spelling such as `vergelijking`; use Afrikaans `vergelyking`.
- Do not overuse bureaucratic nominalisations. Example: prefer `Gaan jou e-pos na` over a noun-heavy equivalent.
- Preserve semantic distinctions even where Afrikaans would allow one generic word: `onbekend`, `nie getoets nie`, and `verkies om nie te antwoord nie` are not interchangeable.

## 5. Safety and health

- Use calm, specific risk language. Never soften a safety boundary until it becomes ambiguous.
- Do not add emergency/urgent-support boilerplate to unrelated screens. Only show it where the applicable safety outcome actually requires it.
- Never imply journal free text or ordinary app activity is continuously clinically monitored.
- Temperament may shape presentation/behaviour support; copy must never present it as medical/psychological diagnosis or as overriding clinical truth.
- For setbacks, prefer recovery language: one missed day does not erase progress; avoid “failed”, “cheated”, “bad”, “start over from zero” framing unless the domain state genuinely is failure.

## 6. Legal/privacy/consent

- Governing Terms and Privacy bodies are English-only under current authority. Afrikaans UI uses `Privaatheidsbeleid` as the participant-facing descriptor for the English Privacy Notice; this must not be mistaken for an official translated governing legal body.
- Keep purpose-specific permissions separate. Marketing preference is not health-data consent; notification preference is not legal consent.
- A single participant-facing Terms + Privacy checkbox is permitted by the current owner decision only if the implementation still records the exact accepted Terms version and exact accepted Privacy version independently. Do not collapse the underlying evidence into one undifferentiated legal fact.

## 7. Errors and ambiguity

A recoverable error should answer, where known:

- What went wrong in user terms?
- Was work saved?
- What is the safest next action?
- Is the current result unknown rather than failed?
- Is a support/reference ID useful?

Never expose stack traces, provider internals, secrets or security-sensitive details.

## 8. Accessibility copy

- Every icon-only action needs an accessible name using the same semantic key family.
- Alt text describes the purpose/information of an image, not “image of…”, unless that wording is necessary.
- Charts require a concise text summary of the meaningful trend; do not rely on colour alone.
- Loading, errors and success changes that matter to task completion need appropriate live announcements.
- Dialog titles must identify the action/consequence; destructive confirmation buttons use explicit verbs.

## 9. Placeholders

Use placeholders only where they demonstrate format or reduce uncertainty. Do not duplicate a visible label as placeholder text. Never use a placeholder as the only accessible label.

## 10. UI length hierarchy

- Button: usually 1–4 words.
- Field help: one short sentence.
- Error: one sentence + next action where needed.
- Empty state: title + one useful sentence/action when appropriate.
- Safety/legal: as long as required for precision, but no longer.
- Editorial/public marketing: may be more expressive, but should still stay honest and evidence-aligned.

## Legal-interaction wording rule

Do not combine distinct legal events merely to make a form shorter. Terms acceptance, Privacy Notice presentation/acknowledgement, age confirmation, purpose-specific consent, marketing permission, cookie choices, practitioner sharing and SKU-specific early-performance instructions stay semantically distinct. A Privacy Notice explains processing; an acknowledgement that it was made available is not blanket consent.

The English governing artifact may be titled **Privacy Notice** while Afrikaans participant-facing UI uses the owner-selected term **Privaatheidsbeleid**.
