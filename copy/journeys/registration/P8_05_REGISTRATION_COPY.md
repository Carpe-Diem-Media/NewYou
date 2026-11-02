# P8-05 registration browser copy — candidate review pack

**Status:** WORKING CANDIDATE / NOT DEVELOPMENT-APPROVED BY THIS FILE / NOT PRODUCTION-APPROVED<br>
**Legal UX reconciliation:** 2026-11-02, derived from `NEWYOU_LEGAL_UX_COPY_PACK_WORKING_v0.1.0` and the current counsel-review Terms v0.3.3 / Privacy v0.3.2 sources.

The combined Terms + Privacy checkbox from workspace v0.2.0 is **superseded**. The current candidate uses separate legal interactions:

1. age confirmation;
2. Terms acceptance;
3. Privacy Notice presentation plus a separate acknowledgement candidate;
4. purpose-specific consent, marketing permission and other legal events remain separate and are not inferred from registration.

The governing Terms and Privacy document bodies remain exact English-only artifacts. Afrikaans and English UI both link to the same selected English versions. The English legal artifact is titled **Privacy Notice**; participant-facing Afrikaans terminology uses **Privaatheidsbeleid** by owner decision.

The underlying P8-05 evidence must still preserve the exact selected Terms version, exact selected Privacy version, acceptance/evidence time and participant interaction/preferred locale. This copy pack does not itself settle legal sufficiency or production treatment.

| Key | Class | English | Afrikaans | Status | Review flag |
| --- | --- | --- | --- | --- | --- |
| public.entry.launch.title | A | Health and lifestyle support built around real life | Gesondheids- en leefstylondersteuning vir die werklike lewe | candidate | OWNER REVIEW REQUIRED |
| public.entry.launch.body | A | {{platform_name}} is a Christian, temperament-guided health and lifestyle platform for adult women. It is designed to help you understand your patterns, build sustainable habits and make practical health choices. | {{platform_name}} is ’n Christelike, temperamentgerigte gesondheids- en leefstylplatform vir volwasse vroue. Dit is ontwerp om jou te help om jou patrone beter te verstaan, volhoubare gewoontes te bou en praktiese gesondheidskeuses te maak. | candidate | OWNER REVIEW REQUIRED |
| public.entry.safety.body | A | {{platform_name}} supports general wellness and guided self-management. Our guidance is based on the information you choose to provide and can only be as relevant as the information available to us. It does not replace medical, psychological or individual dietetic care. Where personalised guidance is not appropriate, {{platform_name}} may limit automated guidance and direct you to a safer or more appropriate next step. | {{platform_name}} ondersteun algemene welstand en begeleide selfbestuur. Ons leiding is gebaseer op die inligting wat jy kies om met ons te deel en kan net so relevant wees soos die inligting wat tot ons beskikking is. Dit vervang nie mediese, sielkundige of individuele dieetkundige sorg nie. Waar persoonlike leiding nie gepas is nie, kan {{platform_name}} outomatiese leiding beperk en jou na ’n veiliger of meer gepaste volgende stap lei. | candidate | OWNER REVIEW REQUIRED |
| identity.registration.title | B | Create your {{platform_name}} account | Skep jou {{platform_name}}-rekening | candidate | OWNER REVIEW REQUIRED |
| identity.registration.intro | B | Create a free account to unlock more of {{platform_name}}, including personalised experiences and additional content as it becomes available. We’ll only ask for the information needed to set up your account. | Skep ’n gratis rekening om meer van {{platform_name}} te ontsluit, insluitend persoonlike ervarings en bykomende inhoud soos dit beskikbaar word. Ons vra net die inligting wat nodig is om jou rekening op te stel. | candidate | OWNER REVIEW REQUIRED |
| identity.registration.existing_account_prompt | B | Already have an account? | Het jy reeds ’n rekening? | candidate |  |
| identity.registration.first_name.label | B | First name | Voornaam | candidate |  |
| identity.registration.surname.label | B | Surname | Van | candidate |  |
| identity.registration.email.label | B | Email address | E-posadres | candidate |  |
| identity.registration.password.label | B | Password | Wagwoord | candidate |  |
| identity.registration.preferred_language.label | B | Preferred language | Voorkeurtaal | candidate |  |
| identity.registration.preferred_language.help | B | Choose the language you want to use on {{platform_name}}. | Kies die taal waarin jy {{platform_name}} wil gebruik. | candidate |  |
| identity.registration.age_confirmation | A | I confirm that I am 18 years or older. | Ek bevestig dat ek 18 jaar of ouer is. | candidate | OWNER REVIEW REQUIRED |
| legal.shared.document_language_disclosure | A | The governing Terms and Conditions and Privacy Notice are provided in English. | Die geldende Bepalings en Voorwaardes en Privaatheidsbeleid word in Engels verskaf. | candidate | OWNER REVIEW REQUIRED |
| identity.registration.terms_acceptance | A | I accept the Terms and Conditions for {{platform_name}}. | Ek aanvaar die Bepalings en Voorwaardes vir {{platform_name}}. | candidate | OWNER REVIEW REQUIRED |
| identity.registration.terms_link | A | Read the Terms and Conditions (English) | Lees die Bepalings en Voorwaardes (Engels) | candidate | OWNER REVIEW REQUIRED |
| identity.registration.privacy_presentation | A | We process personal information as explained in the {{platform_name}} Privacy Notice. The Privacy Notice explains how your information is used and is not consent to every processing purpose. | Ons verwerk persoonlike inligting soos in {{platform_name}} se Privaatheidsbeleid verduidelik. Die Privaatheidsbeleid verduidelik hoe jou inligting gebruik word en is nie toestemming vir elke verwerkingsdoel nie. | candidate | OWNER REVIEW REQUIRED |
| identity.registration.privacy_link | A | Read the Privacy Notice (English) | Lees die Privaatheidsbeleid (Engels) | candidate | OWNER REVIEW REQUIRED |
| identity.registration.privacy_acknowledgement | A | I acknowledge that the {{platform_name}} Privacy Notice has been made available to me. | Ek erken dat {{platform_name}} se Privaatheidsbeleid aan my beskikbaar gestel is. | candidate | OWNER REVIEW REQUIRED |
| identity.registration.submit | B | Create account | Skep rekening | candidate |  |
| identity.registration.processing | B | Creating your account… | Besig om jou rekening te skep… | candidate |  |
| identity.registration.first_name.required | B | Enter your first name. | Voer jou voornaam in. | candidate |  |
| identity.registration.surname.required | B | Enter your surname. | Voer jou van in. | candidate |  |
| identity.registration.email.required | B | Enter your email address. | Voer jou e-posadres in. | candidate |  |
| identity.registration.password.required | B | Enter a password. | Voer ’n wagwoord in. | candidate |  |
| identity.registration.language.required | B | Choose Afrikaans or English. | Kies Afrikaans of Engels. | candidate |  |
| identity.registration.age.required | A | Confirm that you are 18 years or older to create an account. | Bevestig dat jy 18 jaar of ouer is om ’n rekening te skep. | candidate | OWNER REVIEW REQUIRED |
| identity.registration.terms.required | A | Accept the Terms and Conditions to continue. | Aanvaar die Bepalings en Voorwaardes om voort te gaan. | candidate | OWNER REVIEW REQUIRED |
| identity.registration.privacy_acknowledgement.required | A | Acknowledge the Privacy Notice to continue. | Bevestig dat die Privaatheidsbeleid aan jou beskikbaar gestel is om voort te gaan. | candidate | OWNER REVIEW REQUIRED |
| identity.registration.failure | B | We couldn’t complete your registration. Check your details and try again. | Ons kon nie jou registrasie voltooi nie. Kontroleer jou besonderhede en probeer weer. | candidate |  |
| identity.registration.accepted_neutral | A | Almost there. Check your email for the next step and follow the instructions there. If you don’t see the email, check your spam or junk folder too. | Amper klaar. Gaan jou e-pos na vir die volgende stap en volg die instruksies daarin. As jy nie die e-pos sien nie, kyk ook in jou strooipos- of gemorsposvouer. | candidate | OWNER REVIEW REQUIRED |
| legal.terms.development_baseline | A | [external exact artifact] | [English-only governing document] | candidate |  |
| legal.privacy.development_baseline | A | [external exact artifact] | [English-only governing document] | candidate |  |

## Superseded registration legal keys

- `identity.registration.legal_acceptance` — superseded combined checkbox; do not compose into new pages.
- `identity.registration.legal.required` — superseded combined validation.
- `identity.registration.privacy_acceptance` — superseded wording that framed the Privacy Notice as an acceptance/consent event.
- `identity.registration.privacy.required` — superseded by the narrower acknowledgement validation key.

## Security boundary

The neutral registration outcome remains intentionally non-enumerating. Do not change it to “registered successfully” or “a verification email was sent” unless the underlying authority changes, because duplicate-email requests must not reveal whether an Account exists.
