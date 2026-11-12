from __future__ import annotations

import unittest
from tools import newyou_attest as attest


class FounderIdentityTests(unittest.TestCase):
    def test_founder_must_be_active_organization_owner(self):
        from unittest.mock import patch
        repository = {'id': 1332946467, 'full_name': 'Carpe-Diem-Media/NewYou',
                      'owner': {'id': 352920747, 'login': 'Carpe-Diem-Media', 'type': 'Organization'}}
        membership = {'state': 'active', 'role': 'admin',
                      'organization': {'id': 352920747, 'login': 'Carpe-Diem-Media'},
                      'user': {'id': 216185530, 'login': 'JCSchoeman96'}}
        with patch('tools.ci_attestation._api', return_value=membership):
            self.assertEqual(216185530, attest.founder_account_id(repository))
        for change in ({'state': 'pending'}, {'role': 'member'},
                       {'user': {'id': 1, 'login': 'JCSchoeman96'}},
                       {'organization': {'id': 1, 'login': 'Carpe-Diem-Media'}}):
            with self.subTest(change=change), patch('tools.ci_attestation._api', return_value=dict(membership, **change)):
                with self.assertRaises(attest.AttestationError):
                    attest.founder_account_id(repository)

    def test_organization_identity_cannot_replace_founder_account(self):
        from unittest.mock import patch
        repository = {'id': 1332946467, 'full_name': 'Carpe-Diem-Media/NewYou',
                      'owner': {'id': 352920747, 'login': 'Carpe-Diem-Media', 'type': 'Organization'}}
        membership = {'state': 'active', 'role': 'admin',
                      'organization': {'id': 352920747, 'login': 'Carpe-Diem-Media'},
                      'user': {'id': 352920747, 'login': 'Carpe-Diem-Media'}}
        with patch('tools.ci_attestation._api', return_value=membership), self.assertRaises(attest.AttestationError):
            attest.founder_account_id(repository)

    def test_retired_custody_command_fails_without_writing(self):
        from unittest.mock import patch
        with patch('builtins.print'), patch('builtins.open') as file:
            self.assertEqual(1, attest.main())
            file.assert_not_called()
