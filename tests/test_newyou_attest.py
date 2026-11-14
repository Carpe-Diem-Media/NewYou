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


class PRPreflightTests(unittest.TestCase):
    def test_agent_authentication_and_existing_agent_pr_pass(self):
        from unittest.mock import patch
        actor = {'login': 'JC-Agents', 'id': 355419376}
        with patch('tools.ci_attestation._api', side_effect=[actor, {'user': actor}]):
            attest.pr_preflight(237)
        with patch('tools.ci_attestation._api', return_value=actor):
            attest.pr_preflight()

    def test_founder_wrong_missing_or_unavailable_authentication_fails_closed(self):
        from unittest.mock import patch
        for actor in ({'login': 'JCSchoeman96', 'id': 216185530}, {},
                      {'login': 'JC-Agents', 'id': 1}, {'login': 'someone', 'id': 355419376}):
            with self.subTest(actor=actor), patch('tools.ci_attestation._api', return_value=actor):
                with self.assertRaises(attest.AttestationError):
                    attest.pr_preflight()
        with patch('tools.ci_attestation._api', side_effect=attest.AttestationError('authentication unavailable')):
            with self.assertRaises(attest.AttestationError):
                attest.pr_preflight()

    def test_founder_authored_pr_is_ineligible_even_with_agent_actor(self):
        from unittest.mock import patch
        actor = {'login': 'JC-Agents', 'id': 355419376}
        with patch('tools.ci_attestation._api', side_effect=[actor, {'user': {'login': 'JCSchoeman96', 'id': 216185530}}]):
            with self.assertRaises(attest.AttestationError):
                attest.pr_preflight(235)
