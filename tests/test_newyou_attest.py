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
    def test_either_account_can_open_and_update_its_own_pr(self):
        from unittest.mock import patch
        for login, account_id in attest.PR_ACCOUNTS.items():
            actor = {'login': login, 'id': account_id}
            with self.subTest(login=login):
                with patch('tools.ci_attestation._api', side_effect=[actor, {'user': actor}]):
                    self.assertEqual(login, attest.pr_preflight(237))
                with patch('tools.ci_attestation._api', return_value=actor):
                    self.assertEqual(login, attest.pr_preflight())

    def test_pr_events_accept_either_account_and_cross_account_sync(self):
        for login, account_id in attest.PR_ACCOUNTS.items():
            author = {'login': login, 'id': account_id}
            other = attest.counterpart(author)
            opened = {'action': 'opened', 'pull_request': {'user': author}}
            with self.subTest(author=login):
                attest.verify_pr_event(opened)
                attest.verify_pr_event(dict(opened, action='synchronize', sender=author))
                attest.verify_pr_event(dict(opened, action='synchronize',
                                            sender={'login': other, 'id': attest.PR_ACCOUNTS[other]}))

    def test_pr_events_reject_invalid_author_even_with_valid_sender(self):
        sender = {'login': attest.AGENT_LOGIN, 'id': attest.AGENT_ID}
        for author in ({}, {'login': attest.AGENT_LOGIN, 'id': 1},
                       {'login': 'someone', 'id': attest.AGENT_ID}):
            for action in ('opened', 'synchronize'):
                with self.subTest(author=author, action=action):
                    with self.assertRaises(attest.AttestationError):
                        attest.verify_pr_event({'action': action, 'sender': sender,
                                                'pull_request': {'user': author}})

    def test_wrong_missing_or_unavailable_authentication_fails_closed(self):
        from unittest.mock import patch
        for actor in ({},
                      {'login': 'JC-Agents', 'id': 1}, {'login': 'someone', 'id': 355419376}):
            with self.subTest(actor=actor), patch('tools.ci_attestation._api', return_value=actor):
                with self.assertRaises(attest.AttestationError):
                    attest.pr_preflight()
        with patch('tools.ci_attestation._api', side_effect=attest.AttestationError('authentication unavailable')):
            with self.assertRaises(attest.AttestationError):
                attest.pr_preflight()

    def test_other_accounts_pr_cannot_be_updated(self):
        from unittest.mock import patch
        actor = {'login': 'JC-Agents', 'id': 355419376}
        with patch('tools.ci_attestation._api', side_effect=[actor, {'user': {'login': 'JCSchoeman96', 'id': 216185530}}]):
            with self.assertRaises(attest.AttestationError):
                attest.pr_preflight(235)
