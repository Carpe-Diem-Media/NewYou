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


def main() -> int:
    """Reject the retired routine custody command without collecting or writing."""
    import sys
    print("Routine founder custody is retired. Use native GitHub review and the "
          "read-only tools.ci_attestation native-candidate/native-result commands.", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
