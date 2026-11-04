# WELL-95 Ecto remediation

Risk is HIGH with the `privileged_security` consequence tag.

## Dependency and regression evidence

The upstream [advisory](https://github.com/elixir-ecto/ecto/security/advisories/GHSA-cxjx-vmm2-qr8r), published November 4, 2026, identifies Ecto >= 3.4.0 and < 3.14.3 as affected by CVE-2026-118391. The upstream v3.14.3 changelog disables caching for interpolated JSON paths, `splice/1` and `constant/1`.

Hex published stable Ecto 3.14.3 on November 4, 2026, with no retirement. Its Elixir requirement is `~> 1.14`. NewYou uses pinned Elixir 1.20.5 and OTP 29.1.2.

`mix igniter.upgrade ecto --yes` resolved and compiled the upgrade. Igniter reported no Ecto upgrade tasks. Only Ecto changed in `mix.lock`, from 3.14.2 to 3.14.3. Existing Ash 3.37.2, AshPostgres 2.15.2, AshSql 0.8.6 and EctoSQL 3.14.0 constraints permit it. No direct dependency, override, migration or application behavior change was required.

`test/new_you/security/query_cache_test.exs` exercises the actual Ecto planner with the PostgreSQL adapter. On 3.14.2, all three dangerous query shapes produced cache keys and failed the assertions. The ordinary parameter control passed. On 3.14.3, all four tests passed. The focused security run passed all 15 tests, including authentication reachability guards. These tests prove planner behavior, not an HTTP exploit or a memory load test.

## Reachability assessment

The public router exposes home, registration, resend and legal pages. The registration controller constructs explicit Identity requests. Identity queries use fixed expressions with email, IDs and operation IDs as bound values. Application source has no `json_extract_path`, `splice` or `constant` query construction, and exposes no generic request-controlled Ash filter/sort endpoint.

AshSql 0.8.6 constructs JSON extraction fragments in `AshSql.Expr.do_get_path`, with path components and expression structure selected by the Ash expression. Its dynamic field construction and generic fragment support mean application-only text searches cannot establish universal adapter safety. No current request path into attacker-selected JSON paths or splice lengths was found. Future generic filters, dynamic query builders or JSON querying require reassessment. Remediation relies on patched Ecto, not a non-reachability exception.

## Assent approval binding

Assent remains vulnerable at 0.2.13 through AshAuthentication 4.15.1. Account authentication is password-only with sign-in and framework registration disabled. Current routes contain no Apple/OAuth callback or identity linking, and production source/config contains no direct Assent calls. An independent read-only assessment confirmed these findings against the resulting lock graph. That technical assessment does not grant owner approval.

The accountable owner accepted exact input digest `09dd14cb9d31fc9441767f8219224f9474e09eb6721291285d1e40dec16424a9` in WELL-95 comment `2804a409-64f4-4571-8df3-0da8c37da9ca`, coordinated in WELL-91 comment `1dc47a21-e216-4cca-b7e3-e43ba77a0feb`. The audit approval reference and input binding now record that decision. The November 18, 2026 expiry and all other exception conditions remain unchanged.

Before reauthorization, a fresh isolated Hex 2.6.0 scan found only EEF-CVE-2026-117656 for Assent, with no Ecto advisory. The wrapper exited 1 with `Exception invalidated by changed dependency/source/config inputs`. The 24 audit regression tests likewise failed with four failures and four errors because their approved-input assumptions no longer hold. Neither result is a passing security gate.

The earlier failed gate above records the pre-approval state. After owner reauthorization, all 27 audit tests pass, including rejection of the superseded approval and real changed-input invalidation tests. WELL-91 retains the Assent follow-up obligation. The vulnerability remains present. Independent exact-head Master Gate review and required CI are still mandatory before any separately authorized merge.

## Proof scope

Applicable proof includes failing-then-passing cache regression tests, the cacheable parameter control, authentication guards, actual dependency resolution/compilation, fresh unsuppressed advisory evidence, audit invalidation checks, application checks and independent security review. No business lifecycle, authorization policy, durable writes or migrations change, so new lifecycle/concurrency/retry/migration tests are not applicable. Independent Master Gate must review that scope and the exact final diff and CI.
