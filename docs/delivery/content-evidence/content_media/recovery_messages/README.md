# Recovery-message candidates for owner review

Status: `CANDIDATE_NOT_APPROVED`. Four complete message drafts are available for review. The owner authorised drafting; missing approval is not a drafting blocker. Every development, test-delivery, publication, runtime and production eligibility flag remains false. This packet is not selected by a current authority router or consumed by runtime code.

## Exact review subjects

- [Account-recovery proof, English V1](NEWYOU-ACCOUNT-RECOVERY-PROOF-MESSAGE-EMAIL-EN-V1.txt).
- [Account-recovery proof, Afrikaans V1](NEWYOU-ACCOUNT-RECOVERY-PROOF-MESSAGE-EMAIL-AF-V1.txt).
- [Recovery-completion notice, English V1](NEWYOU-ACCOUNT-RECOVERY-COMPLETION-NOTICE-EMAIL-EN-V1.txt).
- [Recovery-completion notice, Afrikaans V1](NEWYOU-ACCOUNT-RECOVERY-COMPLETION-NOTICE-EMAIL-AF-V1.txt).

[The candidate evidence packet](RECOVERY_MESSAGE_CANDIDATE_EVIDENCE_PACKET_v0.1.0.json) records proposed immutable identities, file/subject/body byte lengths, offsets and SHA-256 digests, typed literal-token contracts, proposed semantic copy keys and all approval/eligibility gaps. All IDs are candidate proposals, not Content-owned issued identities. No real participant, contact, URL, bearer, credential or rendered message appears in these source artifacts.

The exact files use UTF-8 without a BOM, LF line endings, `subject: ` followed by the subject, a blank line before the body and exactly one terminal LF. File digests cover all source bytes. Subject digests exclude the prefix and LF; body digests cover all bytes after the first blank line, including the terminal LF. Token-contract digests cover UTF-8 JSON with sorted keys, compact separators and no ASCII escaping. No normalization is applied to the message bytes.

The proposed semantic keys extend the existing `identity.recovery.family` namespace. No exact message keys already exist in COPY_REGISTRY.json. As with earlier purpose-specific message packets, these drafts remain outside that pinned runtime registry. Existing approved verification, magic-login and password-reset files and their approval histories are unchanged.

## Decisions requested

[The narrow Product proposals](PRODUCT_CLASSIFICATION_PROPOSALS_v0.1.0.md) separate proof delivery from completion notices, specify exclusions and request only bounded development eligibility. They do not amend current Product Law, Decisions, a semantic contract or an authority router.

Product must decide each proposed type, wording risk and applicability. Content & Media must decide the exact proposed identities, EN/AF versions, bytes, token contracts and bounded eligibility. English and Afrikaans reviewers must review each exact locale version. The `support_contact` token also needs an exact approved non-secret contact binding. No owner, reviewer, decision ID, timestamp, approval event or runtime grant is supplied on their behalf.

## Security and implementation fit

The proof email says that the request alone changes no password or Account restriction. This matches the corrected anonymous-request boundary. It requires explicit confirmation, describes a time-limited single-use step and allows further verification. It does not promise that ordinary proof is enough for every recovery. The confirmation route and render binding must be verified before activation; this candidate packet implements neither.

The notice applies only after committed recovery completion. It describes the password and prior-access consequences without promising immediate sign-in or hold release. Both ordinary E2 and manual E1 completion establish the existing notice obligation through Identity. The wording is neutral about who completed the recovery and does not expose staff, grants, case IDs, review evidence or other Account details.

The literal support token lets owners choose a valid contact rather than the author inventing a URL or email address. The message does not promise a particular response time or an alternative identity-verification method. Language review should specifically confirm `rekeningherstel`, `gemagtig`, and the remembered-device wording against the existing glossary and the actual product interaction.

Communications roles `account_recovery` and `recovery_security_notice` remain held and content-unbound. Provider admission remains disabled. Candidate files, hashes, author review and CI do not confer delivery authority. After accountable approvals, activation requires current routed authority, an owning render/binding implementation and actual delivery/ambiguity/security-notice proof. Proof-independent manual verification and real WELL-17 integration remain separate acceptance gaps.

## Verification

Validate the four exact file/subject/body digests and the two typed token contracts against the packet before review. Also check LF/BOM/terminal-LF format, exact locale pairing, empty approval histories, false eligibility flags, literal-token placement, no rendered URLs or bearer values, and the proposed classification-file digest. Observed commands and results are recorded in PR #217 and WELL-16. Byte validation is evidence integrity, not owner or language approval.

From the repository root:

```sh
python3 - <<'PY'
import hashlib, json, re
from pathlib import Path

folder = Path('docs/delivery/content-evidence/content_media/recovery_messages')
packet = json.loads((folder / 'RECOVERY_MESSAGE_CANDIDATE_EVIDENCE_PACKET_v0.1.0.json').read_text())
sha = lambda value: hashlib.sha256(value).hexdigest()
assert packet['status'] == 'CANDIDATE_NOT_APPROVED'
assert packet['candidate_ids_are_proposals'] is True
assert packet['content_identity_authority_established'] is False
assert all(value is False for value in packet['eligibility'].values())
assert not any(packet[key] for key in ['owner_decisions', 'locale_reviews', 'approval_events'])
assert all(packet['binding'][key] is False for key in ['runtime_binding_established', 'support_contact_binding_approved', 'provider_admission_enabled', 'latest_alias', 'silent_locale_fallback'])
subjects = [packet['product_proposal'], *packet['authority_refs']]
for item in subjects:
    assert sha(Path(item['path']).read_bytes()) == item['sha256']
count = 0
for message in packet['messages']:
    contract = json.dumps(message['token_allowlist'], sort_keys=True, separators=(',', ':'), ensure_ascii=False).encode()
    assert sha(contract) == message['token_contract_sha256']
    assert [item['locale'] for item in message['locale_versions']] == ['en', 'af']
    for version in message['locale_versions']:
        data = Path(version['artifact']['path']).read_bytes()
        data.decode('utf-8')
        assert not data.startswith(b'\xef\xbb\xbf') and b'\r' not in data
        assert data.endswith(b'\n') and not data.endswith(b'\n\n')
        first, body = data.split(b'\n\n', 1)
        assert first.startswith(b'subject: ') and b'\n' not in first
        subject = first[9:]
        for key, value, offset in [('artifact', data, None), ('subject', subject, 9), ('body', body, len(first) + 2)]:
            evidence = version[key]
            assert len(value) == evidence['bytes'] and sha(value) == evidence['sha256']
            assert offset is None or evidence['offset'] == offset
        found = set(re.findall(rb'\{\{[^{}]+\}\}', data))
        assert found == {token['literal'].encode() for token in message['token_allowlist']}
        for token in message['token_allowlist']:
            if 'subject' not in token['allowed_fields']:
                assert token['literal'].encode() not in subject
        assert not re.search(rb'https?://|eyJ[A-Za-z0-9_-]+\.', data)
        count += 1
assert count == 4
print('PASS: four exact candidate artifacts; no approval or delivery eligibility')
PY
```

The implementation/harness tree at `0d8da094f80ee9f8487dfbe8ffc009b88503e6c3` has clean hosted 653/653 evidence in run 42870890178 attempt 1. Adding these review artifacts changes the PR head; that prior run remains evidence for its recorded SHA, not an exact-head CI pass for a later commit. No suite rerun is warranted solely by the differing local shared-database result. Required CI routing for a new head is preserved.
