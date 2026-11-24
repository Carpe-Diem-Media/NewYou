"""GitHub account checks for PR authorship and independent review."""
from __future__ import annotations

from tools.ci_attestation import AttestationError, require

REPOSITORY = 'Carpe-Diem-Media/NewYou'
FOUNDER_LOGIN = 'JCSchoeman96'
FOUNDER_ID = 216185530
ORGANIZATION_ID = 352920747
REPOSITORY_ID = 1332946467
AGENT_LOGIN = 'JC-Agents'
AGENT_ID = 355419376
PR_ACCOUNTS = {AGENT_LOGIN: AGENT_ID, FOUNDER_LOGIN: FOUNDER_ID}
CODEOWNERS = f'* @{FOUNDER_LOGIN} @{AGENT_LOGIN}\n'


def pr_account(user: dict) -> str:
    login = user.get('login') if isinstance(user, dict) else None
    require(isinstance(login, str) and login in PR_ACCOUNTS and user.get('id') == PR_ACCOUNTS[login],
            'PR workflow requires authenticated JC-Agents or JCSchoeman96')
    return login


def counterpart(user: dict) -> str:
    return FOUNDER_LOGIN if pr_account(user) == AGENT_LOGIN else AGENT_LOGIN


def verify_pr_event(event: dict) -> None:
    """Validate PR authorship; native review rules govern the latest push."""
    # A synchronization event can be triggered by the other authorized account.
    # Do not conflate the event sender with the PR author or final reviewer.
    pr_account(event['pull_request']['user'])


def founder_account_id(repository: dict) -> int:
    """Resolve the founder account independently of the organization owner ID."""
    from tools import ci_attestation as ci
    owner = repository.get('owner', {})
    require(repository.get('id') == REPOSITORY_ID and repository.get('full_name') == REPOSITORY
            and owner.get('id') == ORGANIZATION_ID and owner.get('login') == 'Carpe-Diem-Media'
            and owner.get('type') == 'Organization', 'repository owner is unverifiable')
    membership = ci._api(f'orgs/Carpe-Diem-Media/memberships/{FOUNDER_LOGIN}')
    require(membership.get('state') == 'active' and membership.get('role') == 'admin'
            and membership.get('organization', {}).get('id') == ORGANIZATION_ID
            and membership.get('organization', {}).get('login') == 'Carpe-Diem-Media'
            and membership.get('user', {}).get('id') == FOUNDER_ID
            and membership.get('user', {}).get('login') == FOUNDER_LOGIN,
            'founder organization ownership is unverifiable')
    return FOUNDER_ID


def pr_preflight(pr_number: int | None = None) -> str:
    """Fail closed on actual authentication and the existing PR author, read-only."""
    from tools import ci_attestation as ci
    actor = pr_account(ci._api('user'))
    if pr_number is not None:
        pr = ci._api(f'repos/{REPOSITORY}/pulls/{pr_number}')
        require(pr_account(pr['user']) == actor, 'existing PR belongs to the other account')
    return actor


def main() -> int:
    """Run read-only PR preflight, or reject the retired custody command."""
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == 'pr-preflight':
        import argparse
        parser = argparse.ArgumentParser(description='Read-only routine PR identity preflight')
        parser.add_argument('phase', choices=['pr-preflight'])
        parser.add_argument('--pr', type=int)
        args = parser.parse_args()
        try:
            actor = pr_preflight(args.pr)
        except (AttestationError, KeyError, TypeError, ValueError, OSError) as error:
            print(f'PR preflight failed: {error}', file=sys.stderr)
            return 1
        print(f'PR identity preflight passed: {actor}')
        return 0
    print("Routine founder custody is retired. Use native GitHub review and the "
          "read-only tools.ci_attestation native-candidate/native-result commands.", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
