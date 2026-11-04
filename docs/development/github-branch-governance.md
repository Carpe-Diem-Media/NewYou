# GitHub branch governance

NewYou is a private repository on GitHub Free. GitHub does not enforce branch
protection or a required status check on `main` under this plan. The owner has
accepted the risk that a person or compromised credential with write access can
push directly, force-push, or merge without review and passing CI. A procedural
gate cannot prevent those actions.

The independent Master Gate must review the exact PR head and complete diff,
verify the current base and successful Foundation Integrity CI on the tested
merge candidate, and record its review and evidence before an authorised merge.
After merge it must independently verify the resulting main tree and ancestry.
The detailed procedure and failure handling are in [Foundation Integrity merge
gate](foundation-integrity-merge-gate.md). The required CI is a procedural
requirement, not a GitHub-enforced status rule.

The collector supports only the explicitly selected `private-procedural` mode.
It checks repository identity, private visibility and the reported unprotected
`main` branch. Unknown, inconsistent or unavailable evidence fails closed.
This check does not prove that platform protection exists or prevent a bypass.

Historically, Pass 1 established the `Protect main` ruleset for the public
repository. That historical configuration is not the current private-Free
control and must not be represented as enforced.
