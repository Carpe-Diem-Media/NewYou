# WELL-72 dependency security evidence

Assessment date: 2026-11-04. Source baseline: main
`be184ab74c483c90ccd38d31038a6ddaa7f3e157`, tree
`08c1fe5665c338cc96c9868f20a6e2fe8130f05a`. The PR head and exact verification
results belong in Plane WELL-72 and the PR. This record is engineering evidence,
not Product/Architecture/Domain law or permission to suppress an advisory.

## Phoenix.HTML

[EEF-CVE-2026-117645](https://cna.erlef.org/cves/CVE-2026-117645.html)
affects 4.x before 4.4.0. The
[Hex package API](https://hex.pm/api/packages/phoenix_html) lists 4.4.0 as the latest
stable release. Its Elixir requirement is `~> 1.7`, compatible with this project's
Elixir 1.20.5. Phoenix LiveView 1.2.13 and Phoenix Ecto 4.7.0 accept
this dependency line. The committed solver result and TEST/PROD compilation verify
the actual graph. Only the Phoenix.HTML lock entry changes. Igniter performs the
upgrade and reports no package upgrade tasks. The direct exact requirement
`== 4.4.0` excludes vulnerable releases and matches the project's exact security
package pinning pattern.

[Tagged upstream source](https://github.com/phoenixframework/phoenix_html/blob/v4.4.0/lib/phoenix_html.ex)
validates binary/iodata names. It deliberately trusts atom and explicit
`{:safe, name}` keys. This upgrade cannot sanitize attacker-created atoms or safe
names. Nor does syntactic name validation make an attacker-selected valid event
handler such as `onmouseover` safe. Attribute names must remain application-owned.

`html_attributes_test.exs` covers empty names, whitespace, quotes, slash, equals,
closing delimiter, all C0 bytes and DEL as binary and iodata keys, including
nested data/aria/phx names and boolean attributes. Iodata quotes and closing
delimiters may instead render as safe encoded name bytes through the Safe
protocol, which the tests check explicitly. It checks normal rendering,
hostile value escaping and the actual trusted-name bypass. The malformed-name
test fails on locked 4.3.0 because no ArgumentError is raised.

### Request-to-rendering review

The source review covers `lib/` and `config/`, including router, endpoint,
controllers, HTML modules, templates, component callers and helpers.

- PageController ignores request parameters. Its template and Layouts supply
  literal component attributes. Flash content is a value, not an attribute map.
- RegistrationController selects a fixed set of string field keys in
  `safe_form_values/1`, constructs fixed assigns and uses `to_form/2`. Registration
  templates choose fields and attribute names literally. Request keys never feed
  a component spread. Locale is restricted to `en`/`af`.
- The pending page receives email as an escaped value. Its form attributes are
  literals. Terms/privacy responses use fixed repository paths and exact digest
  checks, never request-provided HTML or paths.
- CoreComponents flash/button/input and Design.Button have global `rest` spreads.
  Their callers do not pass request maps. The design button has no production
  caller; registration uses literal native buttons/fields. No application HTML
  helper calls `attributes_escape/1` or `raw/1` directly.
- There is no request-to-atom conversion, atom-key JSON decoder or construction of
  safe attribute-name tuples in application/config source. Test/proof-only
  `String.to_existing_atom/1` calls do not feed production rendering.

`request_rendering_test.exs` sends hostile query and form keys, nested attribute
maps and hostile retained values through real router/controller rendering in both
locales. It checks the selected assigns and rendered output. This complements
source review; it is not a claim of general taint-analysis coverage. Revalidate
on any new dynamic spread/helper, atom conversion, safe-name construction or
request-to-component mapping.

## Assent proposed time-bounded disposition

[EEF-CVE-2026-117656](https://cna.erlef.org/cves/CVE-2026-117656.html), also
GHSA-9fr5-g44g-9526, affects Assent 0.1.25 through releases before 0.3.2. Assent
0.2.13 remains locked and vulnerable. The critical defect merges unsigned Apple
callback `user` input over verified identity claims. It can impersonate another
identity where an Apple flow consumes those claims.

The [Assent API](https://hex.pm/api/packages/assent) lists 0.3.2 as latest stable.
The [AshAuthentication API](https://hex.pm/api/packages/ash_authentication) lists
4.15.1 as latest stable, alongside 5.0.0 release candidates. Both
[4.15.0](https://hex.pm/api/packages/ash_authentication/releases/4.15.0) and
[4.15.1](https://hex.pm/api/packages/ash_authentication/releases/4.15.1) require
Assent `> 0.2.0 and < 0.3.0`. Thus no current stable AshAuthentication release
permits the fixed Assent release. No override, fork, prerelease migration or
unrelated authentication upgrade is included.

Current non-reachability evidence:

- `NewYou.Identity.Account` is the sole AshAuthentication Resource and configures
  only password, with strategy registration/sign-in disabled. Custom registration
  uses the owning Identity interface and password hashing, not an OAuth callback.
- The router exposes home, bounded registration/resend and fixed legal pages.
  There is no Apple/OAuth callback or external identity-linking endpoint.
- Application/config source contains no direct Assent calls, Apple strategy,
  OAuth claims consumption or external-provider identity-linking Resource/action.
  The vulnerable dependency code is present but has no application caller.
- `authentication_reachability_test.exs` pins the current authentication Resource,
  password-only strategy configuration and complete route inventory. A change
  requires explicit reassessment. Source review remains necessary for direct
  calls and linking additions outside that inventory.

Proposed responsible owner: NewYou engineering/security maintenance, currently
JC as developer/operator under DEC-320. Remediation and revalidation remain in
WELL-72, with the downstream gate in WELL-83. Ownership here assigns engineering
follow-up, not a production capability or specialist runtime role.

Proposed expiry: 2026-11-18, or earlier upon any Apple/OAuth strategy, callback,
external identity linking, direct Assent use, authentication dependency change,
new advisory evidence or compatible stable fix release. Before that date, the
owner must recheck stable compatibility and either upgrade through supported
constraints with tests or obtain a fresh independent disposition. Enabling any
Apple path requires remediation and renewed security review first.

Residual risk: vulnerable code remains in the dependency graph. New callers or
configuration can invalidate this bounded non-reachability finding. A full clean
Hex audit is not claimed. No ignore entry or audit-policy change is introduced.

Approval status: proposed for independent HIGH / privileged_security review.
This author does not approve the exception. WELL-79's prior source assessment is
supporting evidence, not approval of this exception. WELL-83 must retain its
blocker until advisory resolution or a formally approved, accountable exception
satisfies its own acceptance criteria. Reviewer verdict and exact reviewed head
must be recorded in Plane/PR; this document alone never activates an exception.

## HIGH proof applicability

Positive/negative rendering, malformed and nested keys, hostile-value escaping,
request trust boundaries, dependency compatibility and independent security review
apply. Authentication strategy/route regression evidence applies to the retained
Assent exposure. Lifecycle/state transitions, policy grants, migrations,
concurrency/idempotency, duplicate/retry/provider reconciliation and durable
recovery are not changed by this dependency-only fix and have no new mechanism to
exercise. Existing business tests still run through `mix check`. No business
writes, schema, secrets, token semantics, authorization policy or CI routing change.
