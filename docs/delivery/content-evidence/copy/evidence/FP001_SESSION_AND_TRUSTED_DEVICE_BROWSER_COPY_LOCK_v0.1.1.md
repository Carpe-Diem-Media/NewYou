# FP-001 — Session and trusted-device copy approval lock v0.1.1

**Decision:** Owner approved the complete candidate without text changes on 2026-11-16.
**Status:** OWNER-APPROVED EXACT COPY — not yet integrated; implementation/release not authorised.
**Exact approved JSON SHA-256:** `db49143d725bc09a16ca31490e438370377393632ebba5850ded318e67a381ef`
**Unchanged source candidate SHA-256:** `a696d3a780ef64d843bbfd30830291d2d89a801679c378a246eece0d3ed91aee`
**Baseline main:** `d35e7ecaff85fda7fe1e8a2155929538e33718f0`

## Approval scope and provenance

- Source decision: one owner instruction in the current conversation, **“Approved as is. Open PR”**.
- All 29 session keys and 18 trusted-device keys are approved, representing **94 exact locale strings**.
- Every EN and AF string, semantic key, family assignment and per-string SHA-256 is identical to candidate v0.1.0.
- This does not claim five independent human decisions, grant a runtime Content & Media role, or independently certify implementation.
- Effective canonical consumption requires exact approved GitHub integration and a separate dependency-cleared Plane Ready ticket.
- Lifecycle is governed by copy governance: candidate → development-approved (only after approved integration), then production approval separately, or supersession/withdrawal. Changed bytes need a fresh immutable successor.

## A. Session management (29 semantic keys)

| Semantic key | English | Afrikaans |
|---|---|---|
| `identity.sessions.page.title` | Where you're signed in | Waar jy aangemeld is |
| `identity.sessions.page.body` | Review your active sign-in sessions and sign out of any you no longer want to use. | Gaan jou aktiewe aanmeldsessies na en meld enige sessie af wat jy nie meer wil gebruik nie. |
| `identity.sessions.active.title` | Active sessions | Aktiewe sessies |
| `identity.sessions.active.empty` | You have no active sessions to show. | Daar is geen aktiewe sessies om te wys nie. |
| `identity.sessions.active.loading` | Loading your sessions… | Besig om jou sessies te laai… |
| `identity.sessions.active.unavailable` | We couldn't load your sessions. Try again. | Ons kon nie jou sessies laai nie. Probeer weer. |
| `identity.sessions.active.refresh.action` | Refresh sessions | Verfris sessies |
| `identity.sessions.item.current.label` | This session | Hierdie sessie |
| `identity.sessions.item.other.label` | Another session | Nog ’n sessie |
| `identity.sessions.item.created.label` | Signed in | Aangemeld |
| `identity.sessions.item.last_seen.label` | Last active | Laas aktief |
| `identity.sessions.item.details_unavailable` | Session details unavailable | Sessiebesonderhede nie beskikbaar nie |
| `identity.sessions.revoke.action` | Sign out this session | Meld hierdie sessie af |
| `identity.sessions.revoke.confirm.title` | Sign out this session? | Meld hierdie sessie af? |
| `identity.sessions.revoke.confirm.body` | This will end the selected session. Any browser using it will need to sign in again. | Dit sal die gekose sessie beëindig. Enige blaaier wat dit gebruik, sal weer moet aanmeld. |
| `identity.sessions.revoke.confirm.action` | Sign out session | Meld sessie af |
| `identity.sessions.revoke.processing` | Signing out this session… | Besig om hierdie sessie af te meld… |
| `identity.sessions.revoke.completed` | This session has been signed out. | Hierdie sessie is afgemeld. |
| `identity.sessions.revoke.already_ended` | This session is no longer active. | Hierdie sessie is nie meer aktief nie. |
| `identity.sessions.revoke.failed` | We couldn't sign out this session. Refresh the list and try again. | Ons kon nie hierdie sessie afmeld nie. Verfris die lys en probeer weer. |
| `identity.sessions.revoke.uncertain` | We couldn't confirm whether this session was signed out. Refresh the list to check. | Ons kon nie bevestig of hierdie sessie afgemeld is nie. Verfris die lys om dit na te gaan. |
| `identity.sessions.revoke.stale` | Your sessions have changed. Refresh the list before continuing. | Jou sessies het verander. Verfris die lys voordat jy voortgaan. |
| `identity.sessions.all.action` | Sign out all devices | Meld op alle toestelle af |
| `identity.sessions.all.confirm.title` | Sign out on all devices? | Meld op alle toestelle af? |
| `identity.sessions.all.confirm.body` | This will end all active sessions on your account, including this one. You'll need to sign in again to continue. | Dit sal alle aktiewe sessies op jou rekening beëindig, insluitend hierdie een. Jy sal weer moet aanmeld om voort te gaan. |
| `identity.sessions.all.processing` | Signing out on all devices… | Besig om op alle toestelle af te meld… |
| `identity.sessions.all.completed` | All sessions have been signed out. | Alle sessies is afgemeld. |
| `identity.sessions.all.failed` | We couldn't sign out all sessions. Sign in again to check, or try again. | Ons kon nie alle sessies afmeld nie. Meld weer aan om dit na te gaan, of probeer weer. |
| `identity.sessions.all.uncertain` | We couldn't confirm whether all sessions ended. Sign in again and check your sessions. | Ons kon nie bevestig of alle sessies beëindig is nie. Meld weer aan en gaan jou sessies na. |

## B. Trusted devices (18 semantic keys)

| Semantic key | English | Afrikaans |
|---|---|---|
| `identity.trusted_devices.page.title` | Trusted devices | Vertroude toestelle |
| `identity.trusted_devices.page.body` | Review devices you've chosen to trust. Trust does not replace additional security checks for sensitive actions. | Gaan die toestelle na wat jy gekies het om te vertrou. Vertroue vervang nie bykomende sekuriteitskontroles vir sensitiewe handelinge nie. |
| `identity.trusted_devices.active.empty` | You haven't marked any devices as trusted. | Jy het nog geen toestelle as vertroud gemerk nie. |
| `identity.trusted_devices.consent.title` | Trust this device? | Vertrou hierdie toestel? |
| `identity.trusted_devices.consent.body` | Choose this only on a device you control. You can remove trust later. Sensitive actions may still require extra verification. | Kies dit net op ’n toestel waaroor jy beheer het. Jy kan die vertroue later verwyder. Sensitiewe handelinge kan steeds ekstra verifikasie vereis. |
| `identity.trusted_devices.consent.action` | Trust this device | Vertrou hierdie toestel |
| `identity.trusted_devices.consent.failed` | We couldn't mark this device as trusted. Try again. | Ons kon nie hierdie toestel as vertroud merk nie. Probeer weer. |
| `identity.trusted_devices.consent.uncertain` | We couldn't confirm whether this device was trusted. Check your trusted-device list. | Ons kon nie bevestig of hierdie toestel as vertroud gemerk is nie. Gaan jou lys van vertroude toestelle na. |
| `identity.trusted_devices.item.name.label` | Device name | Toestelnaam |
| `identity.trusted_devices.item.name.action` | Save device name | Stoor toestelnaam |
| `identity.trusted_devices.item.name.failed` | We couldn't save the device name. Try again. | Ons kon nie die toestelnaam stoor nie. Probeer weer. |
| `identity.trusted_devices.revoke.action` | Remove trust | Verwyder vertroue |
| `identity.trusted_devices.revoke.confirm.title` | Remove trust from this device? | Verwyder vertroue vir hierdie toestel? |
| `identity.trusted_devices.revoke.confirm.body` | This removes trusted status. It does not necessarily sign the device out. | Dit verwyder die toestel se vertroude status. Dit meld nie noodwendig die toestel af nie. |
| `identity.trusted_devices.revoke.completed` | Trust removed from this device. | Vertroue vir hierdie toestel is verwyder. |
| `identity.trusted_devices.revoke.already_ended` | This device is no longer trusted. | Hierdie toestel word nie meer vertrou nie. |
| `identity.trusted_devices.revoke.failed` | We couldn't remove trust. Try again. | Ons kon nie die vertroue verwyder nie. Probeer weer. |
| `identity.trusted_devices.revoke.uncertain` | We couldn't confirm whether trust was removed. Refresh the list before trying again. | Ons kon nie bevestig of die vertroue verwyder is nie. Verfris die lys voordat jy weer probeer. |

## Binding and safety boundaries

1. Product §21J.5 and DEC-248 govern sessions, including active listing, individual revocation and global sign-out. Identity JIT assigns `active → expired | revoked | logged_out`; the browser reports authoritative outcomes only.
2. Product §21J.6 and DEC-249 govern distinct consented, expiring, revocable, nameable device trust. Identity JIT assigns `pending → trusted → expired | revoked` and prohibits device trust from bypassing sensitive-action step-up.
3. Session expiry, concurrent revocation, ambiguous network failures and retry/recovery must not create success claims without Identity confirmation.
4. Existing registry keys `shared.action.cancel`, `shared.action.retry` and `identity.login.session_expired` are not promoted by this approval and must not be duplicated casually.
5. Do not create a new Plane ticket, dispatch implementation, send emails, grant production authority or alter governance as a consequence of this approval.
6. Canonical GitHub authorship/preflight, exact-head review, CI and explicit merge authorisation are separate from content approval.

## Exact-hash lock

- Approved JSON: `FP001_SESSION_AND_TRUSTED_DEVICE_BROWSER_COPY_APPROVED_v0.1.1.json`
- Approved complete-file SHA-256: `db49143d725bc09a16ca31490e438370377393632ebba5850ded318e67a381ef` (UTF-8; LF; one terminal LF)
- Historical candidate complete-file SHA-256: `a696d3a780ef64d843bbfd30830291d2d89a801679c378a246eece0d3ed91aee`
- Every copy item includes separate string-level SHA-256 hashes.
- The approval metadata is a successor file, not a modification of the original candidate. Content differences: **zero**.
