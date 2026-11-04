# WELL-89 dependency security proof

## Scope and authority

This HIGH / `privileged_security` change updates only AshAuthentication 4.15.0 to
4.15.1 and ash_sql 0.8.4 to 0.8.6. Base main is
`481561b108f6c90152ffe94d407c40d387c5508f`, tree
`77d177568ba4a4dd112384ccefe2d562e3a8affa`.

Identity ownership, Ash interfaces, authorization and existing challenge semantics
are LOCKED. Package resolution and isolated test fixtures are JIT implementation
choices. No upstream governance contradiction was found. No production Resource,
schema, migration, route, session or password-reset feature changes.

## Authentication fix and executable regression

[CVE-2026-110826](https://cna.erlef.org/cves/CVE-2026-110826.html), also
[GHSA-j6f8-qcj9-gh4r](https://github.com/team-alembic/ash_authentication/security/advisories/GHSA-j6f8-qcj9-gh4r),
affects stable versions `>= 4.5.0, < 4.15.1` and separately 5.0 release candidates
before rc.16. The stable fix is
[2baef4e](https://github.com/team-alembic/ash_authentication/commit/2baef4eddeb604569d3564273d03eeef438e002c),
in tag v4.15.1 at `a5569b8c4db9c03be0b5ce1bd5e2ed4bc0cc37b3`.

The old transform evaluates `where: changing(hashed_password)` before the
non-atomic password hashing hook. The fix checks the changed hash after the
action instead. The
[tagged upstream regression](https://github.com/team-alembic/ash_authentication/blob/v4.15.1/test/ash_authentication/add_ons/log_out_everywhere_test.exs)
covers reset and atomic/non-atomic password changes.

`test/new_you/security/password_revocation_test.exs` uses isolated test-only ETS
Resources in `test/support/password_revocation_fixture.ex`. It exercises the real
package transformer, HashPasswordChange, token storage, revocation actions, JWT
verification and bearer token-presence helper. ETS is disposable test storage,
not NewYou business authority or production persistence evidence.

The regression requires all three prior target tokens to become unusable after a
non-atomic password update while another user's token remains usable. Invalid
password input and unrelated updates preserve tokens. Repeated global revocation
preserves isolation. A correctly signed but unstored token and a tampered bearer
cannot authenticate. JWT signature/claim verification alone does not establish
required token presence; the bearer helper supplies that check.

Run with `devcore-project run test -- mise exec -- mix test
 test/new_you/security/password_revocation_test.exs`. For before/after proof in a
disposable checkout, retain these tests, change only the AshAuthentication pin
and corresponding solver-generated lock between 4.15.0 and 4.15.1, fetch with
`mix deps.get --check-locked`, and rerun. The old version fails target revocation;
the patched version passes. Exact observed results are attached to Plane/PR.

The fixture does not add a production reset flow. Current Account has no reset
strategy, password update action or logout-everywhere add-on. The application
reachability test pins that boundary and the current password-only strategy,
reviewed routes and absence of authenticated Account assigns on the public path.

## SQL retirement and reachability

[Official 0.8.4 retirement](https://hex.pm/api/packages/ash_sql/releases/0.8.4)
recommends [0.8.6](https://hex.pm/api/packages/ash_sql/releases/0.8.6).
The query-planning fix is
[e25c921](https://github.com/ash-project/ash_sql/commit/e25c921a28fac1a03ea113de2a66e97ebdc589cd),
in v0.8.6 at `b00efd139cf5c217ac6e939af0db2c7d645653ed`.
Compare `lib/join.ex` between v0.8.5 and v0.8.6. Direct relationship joins that
would carry tenant-selected schema prefixes now use subqueries. The unrelated
nested aggregate test in that release is not evidence for this cache defect.

AshPostgres really uses ash_sql for registration, resend and expiry queries.
However, no current Resource has context multitenancy or a tenant-selected
schema. The compiled-resource guard tests every application AshPostgres Resource
for no multitenancy and the existing Repo. Source inspection must also check
future direct `set_tenant` callers or prefix configuration. Formatter section
ordering mentioning `:multitenancy` does not configure tenancy.

The registration orchestration regression alternates Account email and Token
Account/purpose queries, checks no-match results, and proves resend revocation
stays within the selected Account. This exercises actual PostgreSQL queries and
isolation. It is not a reproduction of the tenant-prefix cache defect. Direct
NewYou reproduction of that defect is not applicable without introducing an
absent tenancy model; the exact upstream fix plus the application boundary guard
is the scoped evidence. No production multitenancy is introduced.

0.8.7 is a newer stable same-package release with further many-to-many prefix
handling changes. This change retains the explicitly recommended 0.8.6 security
floor to minimize scope. Both meet existing AshPostgres/Ash/Ecto requirements.

## Dependency resolution and residual advisory

Igniter upgraded the direct exact authentication pin first. Its transitive
refresh also selected ash_sql 0.8.7, libgraph 0.17.1 and nimble_options 1.2.0.
Those unrelated refreshes were discarded. A disposable Mix resolver with the
existing lock and an exact ash_sql 0.8.6 constraint generated the SQL lock entry.
The final application has no new direct dependency or override. Locked fetches
must validate the final graph, including TEST and PROD. Only the two intended
lock entries differ; every other dependency remains byte-identical to base.

[Assent CVE-2026-117656](https://cna.erlef.org/cves/CVE-2026-117656.html) remains.
Locked 0.2.13 is affected; fixed 0.3.2 is outside AshAuthentication 4.15.1's
`> 0.2.0 and < 0.3.0` requirement. No unsupported override, prerelease migration,
audit ignore or policy suppression is included. An unsuppressed audit is expected
to exit nonzero for Assent. It must no longer report the two patched findings.

CVE-2026-118505 and CVE-2026-119215 concern 5.x release candidates, not 4.15.1.

WELL-91 owns independent revalidation against this candidate graph. The
authentication dependency change triggers reassessment immediately. The old
disposition cannot automatically authorize this new graph. Accountable owner
remains JC; the existing deadline is 2026-11-18, with earlier invalidation on new
Apple/OAuth callbacks, strategies, linking, direct Assent use, dependency changes
or new security evidence. An independent exact-head decision must be recorded in
Plane before merge. This document does not approve or extend any exception.
WELL-83 remains Blocked under its own acceptance criteria.

## HIGH proof applicability

- Positive/negative and revocation apply. The package fixture proves the changed
  hook and token rejection; actual registration/hash/challenge/resend tests prove
  application compatibility. These are distinct claims.
- Authorization applies. Ordinary callers cannot read private Account/Token
  actions. The existing framework interaction bypass is unchanged. Scope tests
  check control-Account isolation; no new capability or policy is introduced.
- Leakage applies. Existing registration primitives and request/controller tests
  cover passwords, hashes, bearer material, request binding and safe public
  results. Synthetic fixture credentials carry no production authority.
- Concurrency/idempotency apply to existing registration/resend SQL behavior.
  Existing race, same-ID replay, changed-input rejection and resend-reordering
  tests remain required. Repeated fixture revocation is tested. New production
  password-update/session-issuance races are not applicable because those
  production operations do not exist and are not introduced.
- Failure/recovery and persistence apply to existing PostgreSQL registration and
  resend transactions. Existing signing-key/envelope failure rollback, expiry,
  retained operation and replay tests remain required. Fixture ETS results do not
  prove crash durability. No new async executor or recovery mechanism changes.
- Migration safety requires an unchanged migration/snapshot diff and existing
  migration checks. New migration/backfill/reversal proof is not applicable
  because neither package patch requires schema changes.
- Provider reconciliation, new cross-Domain reactions, Signals and Temporal
  Resources are not applicable because no provider integration, new reaction or
  historical/effective-period requirement is introduced.
- Independent HIGH security review and WELL-91 disposition remain required.
  The implementation author cannot self-certify merge authority.

Required gates are focused tests, `mix check`, `mix check.deep`,
`mix check.architecture`, routing/Smoke tests, TEST/PROD locked compatibility and
unsuppressed advisory audit. Run database commands through DevCore, with both
roles NOCREATEDB and no Redis. Exact-head CI must include Foundation Smoke,
Application CI and Foundation Integrity. Routine Foundation Full is not required.
Plane/PR carries observed command results and exact-head review state.
