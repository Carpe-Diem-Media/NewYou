"""Organization-transfer identity verification retained for read-only CI checks."""
from __future__ import annotations

from tools.ci_attestation import AttestationError, require

REPOSITORY = 'Carpe-Diem-Media/NewYou'
FOUNDER_LOGIN = 'JCSchoeman96'
FOUNDER_ID = 216185530
ORGANIZATION_ID = 352920747
REPOSITORY_ID = 1332946467


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


def pr_preflight(pr_number: int | None = None) -> None:
    """Fail closed on actual authentication and the existing PR author, read-only."""
    from tools import ci_attestation as ci
    actor = ci._api('user')
    require(actor.get('login') == 'JC-Agents' and actor.get('id') == 355419376,
            'routine PR work requires authenticated JC-Agents; do not use founder credentials')
    if pr_number is not None:
        pr = ci._api(f'repos/{REPOSITORY}/pulls/{pr_number}')
        author = pr.get('user', {})
        require(author.get('login') == 'JC-Agents' and author.get('id') == 355419376,
                'existing PR is not agent-authored and is ineligible for the routine approval route')


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
            pr_preflight(args.pr)
        except (AttestationError, KeyError, TypeError, ValueError, OSError) as error:
            print(f'PR preflight failed: {error}', file=sys.stderr)
            return 1
        print('PR identity preflight passed: JC-Agents')
        return 0
    print("Routine founder custody is retired. Use native GitHub review and the "
          "read-only tools.ci_attestation native-candidate/native-result commands.", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
