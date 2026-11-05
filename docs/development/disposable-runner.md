# Disposable runner proving

WELL-93 adds a proving-only controller. Required Foundation Integrity,
Application CI, Hex security audit and nightly jobs continue on GitHub-hosted
runners. This is not a CI cutover or release certification.

Run-specific results, resource measurements and blockers belong in Plane WELL-93
and the implementation PR. A successful harmless job proves only that bounded
execution and cleanup path. Application checks, failure recovery and CI cutover
need their own evidence and independent review.

## Trust boundary

Treat any workflow, collaborator branch and guest as potentially hostile.
A private repository does not make workflow code trusted. The controller runs
only on the trusted workstation. Never execute this controller in CI or from an
unreviewed checkout. No job can mount the controller checkout or host paths.

The guest has two accounts. Root handles trusted preparation over host-initiated
SSH with a fresh pinned host key. `runner` executes the workflow without sudo,
Docker membership or host credentials. SSH agent and port forwarding are disabled.
The initial harmless job has no checkout, actions, repository secrets, service
containers or token permissions. The separate opt-in application profile adds
guest-local rootless Docker and PostgreSQL TEST for application proof.

`gh` obtains controller credentials on the host. The repository JIT API creates
one-job configuration with only the selected profile label. Only that short-lived payload
passes through SSH stdin. No controller credential enters the guest, shell argv,
state, logs, Plane or GitHub. A lost registration response leaves a durable unresolved request. One empty
lookup never discharges it. Recovery must observe and delete the late runner by
its persisted unique name or known ID before another guest can be provisioned.
The controller never retries an uncertain registration POST. Do not copy a PAT into the guest or chat.

The host account's existing GitHub credential may have broader privileges than
runner administration. It remains outside this isolation boundary. Before any
sustained operation, replace it with an appropriately scoped controller identity
and verify rotation/revocation. The initial proof uses the owner's authenticated
controller account and makes no claim that it is repository-limited as a credential.

## Host requirements and resource limits

Use Linux KVM, system libvirt, `cloud-localds`, `qemu-img`, SSH, Python 3.12 or
newer, `gh`, and a functioning systemd user manager. Existing libvirt `ci` storage
and `ci-nat` are inspected; NAT alone is never isolation. The controller does not
manage shared DevCore services or expose the host Docker socket.

One controller holds an exclusive workstation lock. Each guest has two vCPUs,
2 GiB RAM by default, and a standalone 12 GiB disk. The controller requires
6 GiB available host RAM beyond the guest reservation, 1 GiB free swap, at least
32 GiB free storage and memory full-stall `avg10` below 1 percent. Guest memory
is bounded to 2–4 GiB. These are conservative proving limits, not an uptime SLA
or application benchmark. No automatic threshold override exists. Close unrelated
workloads if a resource check fails; do not stop another project's services.

The systemd wrapper imposes a 20-minute total deadline and runs a separate
`ExecStopPost` recovery process. Normal interruption also attempts cleanup.
A second controller fails rather than sharing the static guest address.

## Base image provenance

The existing `ubuntu-24.04-base.qcow2` is not used. The initial source is
`https://cloud-images.ubuntu.com/releases/noble/release/ubuntu-24.04-server-cloudimg-amd64.img`.
The fetched Ubuntu-signed `SHA256SUMS` was verified with the installed
`/usr/share/keyrings/ubuntu-cloudimage-keyring.gpg`. Signing fingerprint:
`D2EB44626FDDC30B513D5BB71A5D6C4C7DB87C81`.
The manifest signature was dated 2026-10-17. The controller pins this image hash:

```text
04e8f2461a16a44e78a370284471f29616cdd9baf1893df25807b71f985b6c94
```

Retain the signed manifest beside the image under
`~/.local/share/newyou-ci/images/`. The controller rehashes the image before every
use and rejects unexpected formats or a backing chain. Never overwrite the pin
to accept an unverified image. Image refresh requires signature verification,
reviewed pin update and repeated live proof.

Trusted guest preparation applies distribution updates before registration.
Repository update errors, package failures or a required kernel reboot stop
registration. A patched boot/reboot path still needs live verification. There is
no claim that a signed base image is already fully patched.

## Network enforcement

Libvirt applies the filter on the host before the guest starts. The filter denies
non-public IPv4 ranges, all current host IPv4 addresses and every explicit host
route prefix, including publicly numbered local networks. It rejects IPv6 and
other Ethernet protocols. MAC, ARP and IP spoofing filters are also attached.
Only gateway ARP, host-initiated administrative SSH, public TCP ports 80/443 and
DNS to 1.1.1.1 are permitted. No guest-initiated connection to the host, LAN,
sibling guests, metadata, Tailscale or DevCore is permitted.

Ethernet filtering precedes IP filtering in libvirt. IPv4 must reach the IP
filter, whose final deny remains independent of the Ethernet default deny.
The controller compares libvirt's stored rule attributes and priorities against
its requested rules before boot. This detects silently discarded attributes and
priority resets. Keep the workstation's routing/network configuration stable
through a proving run. Revalidate isolation after network changes.

Before registration, host-side inspection rejects guest filesystem mounts,
host devices, channels or additional interfaces. Root-level guest probes attempt
host/LAN/DevCore connections and verify public HTTPS. Testing as root ensures
that the non-privileged runner is not the only boundary. A probe timeout alone
cannot prove every possible service is unreachable; host-enforced rules and
negative/positive controls must be independently reviewed together.

## Lifecycle and recovery

The persisted journal lives in `~/.local/state/newyou-ci/` with private directory
and file modes. It records resource UUID/name, image digest, timings, bounded
probe results, GitHub run/job identity and cleanup errors. It contains no token,
private SSH key or raw guest output. Writes use replace and fsync.

The normal sequence is `provisioning`, `isolated`, `registered`, `executing`,
`succeeded`, `teardown`, `cleaned`. Failures and cancellations enter teardown.
Failed cleanup records `cleanup_failed`, and later recovery retries it. A cleaned
guest cannot register again. The journal is written before resource creation and
before the JIT request, covering controller crash and lost API responses.

Cleanup destroys and undefines the owned UUID-bound domain, cancels an incomplete
owned proving run, removes its registration, deletes only its two named volumes,
removes its filter and deletes temporary disks, seed data and SSH keys. Every
cleanup category is attempted even if another category fails. A surviving domain
prevents volume deletion. Recovery never declares success with unresolved errors.
Cancellation requires observed GitHub completion. If ordinary cancellation remains
unacknowledged after three bounded checks, recovery requests the documented
`force-cancel` endpoint and checks completion again. An accepted request alone
cannot release a busy registration. If GitHub still reports the run active,
recovery retains `cleanup_failed` and blocks provisioning until reconciliation.
See [GitHub's workflow-run API](https://docs.github.com/en/rest/actions/workflow-runs#force-cancel-a-workflow-run).

After a workstation crash or reboot, run recovery before another guest. The
controller also does this at startup. There is no always-on host-boot recovery
service in this proving phase. The workstation being offline stops jobs; no
required lane depends on this PC. Systemd and journal failures require manual
reconciliation using the recorded resource identities. Never delete unrelated
libvirt resources to make a proof pass.

The journal's successful result requires GitHub to report a successful run and
job bound to this exact runner ID/name and requested SHA. Runner exit alone is
insufficient. GitHub runner deregistration alone is insufficient teardown.
Disk deletion removes reusable guest files; it is not a claim of forensic SSD
erasure. No guest is reused, including after cancellation or an unknown outcome.

## Commands

Run from the trusted implementation checkout:

```sh
python3 -m unittest tests.test_disposable_runner -v
python3 tools/disposable_runner.py supervise
python3 tools/disposable_runner.py recover
```

`supervise` without a run ID performs isolated guest preparation/probes and
teardown without registration. Direct `probe`/`prove` invocation is rejected
outside systemd. Use `systemctl --user stop newyou-w93-controller` to cancel.
Inspect bounded controller events with
`journalctl --user -u newyou-w93-controller`.

Only after isolation proof passes, push the reviewed harmless workflow to the
explicit `well-93-proving-run` branch. It queues a single opt-in job. Obtain its
run ID and exact SHA from GitHub, then run:

```sh
python3 tools/disposable_runner.py supervise --run-id RUN_ID --sha EXACT_SHA
```

The controller accepts only a queued push run of
`.github/workflows/disposable-runner-proof.yml` on a `well-93-` branch in
`JCSchoeman96/NewYou`. The workflow itself requires the repository owner actor.
If capacity fails, cancel that queued proving run. Do not route normal PR work
onto this label. The separate controller-tests workflow runs on GitHub-hosted
Linux and has no provisioning credentials.

## Proof required before cutover

Verify live DNS/HTTPS and host/LAN/DevCore deny probes, patched boot, actual
one-job registration, GitHub runner/result binding and guest-file absence for
the reviewed controller and image. Exercise cancellation during a job, controller SIGKILL, guest crash,
lost provider response, teardown failure and host restart reconciliation. Repeat
recovery and verify no owned domain, filter, volume or registration remains.

The controller exports a strict diagnostic projection every five seconds during
execution and once more before teardown. It retains only counts of allow-listed
levels, components, known exception types and lifecycle event classes. It never
retains raw log messages, paths, filenames, environments or credential values.
The guest reducer refuses symlinks/non-regular files and caps file count/read
size. The host caps SSH output and validates the JSON schema independently.
Snapshots live in the private `~/.local/state/newyou-ci/evidence/<runner-name>/`
directory. A failed final export records an unavailable observation and preserves
prior snapshots. A sudden crash can lose the interval after the last successful
snapshot; this is not full raw-log recovery. Diagnostics never establish PASS.
Inspect and retain the projection for review; remove it after review when no
longer needed. No diagnostic upload to GitHub or third parties occurs.

After the first harmless proof, verify pinned Elixir/OTP, guest-local PostgreSQL
18 TEST isolation with NOCREATEDB, Foundation/Application checks, concurrency and
wall time, memory/swap/storage use and failure recovery. Guest services must never
connect to workstation DevCore or use its credentials. No shared caches exist in
this phase. Plan offline alerting and bounded hosted fallback before cutover.

This infrastructure tool holds no Domain business truth and changes no Ash
Resources, persistence, Product, Architecture or Domain law. Ash mechanisms are
not applicable to VM orchestration. Independent Master Gate review remains
required for each implementation PR. Never merge automatically.

Primary API references: [libvirt filters](https://libvirt.org/formatnwfilter.html),
[GitHub repository runner APIs](https://docs.github.com/en/rest/actions/self-hosted-runners),
and [ephemeral runner behavior](https://docs.github.com/en/actions/reference/runners/self-hosted-runners).

## Failure drills

The opt-in proof workflow adds a two-minute cancellation window only when the
owner's dedicated-branch commit message contains `[well93-drill]`. Confirm the
job is executing on the owned runner before cancellation, controller SIGKILL or
an owned-domain power-off. Never terminate unrelated workloads or reboot the PC.

`tools/disposable_runner_drills.py` provides trusted-host injection only. Its
`lost-response` mode performs one real JIT POST, discards its reply, and makes the
first lookup appear empty. The controller must preserve `cleanup_failed` and the
unknown request; independent ExecStopPost recovery then sees and deletes the
registration. This simulates response/visibility loss, not measured provider lag.

The `orphan` mode exits after isolated preparation without cleanup, leaving a
journal and a guest for an independently started recovery command. It requires
a bounded systemd user unit. Run recovery immediately, repeat it, and inspect all
owned resources. This tests process restart reconciliation, not workstation reboot.
Neither drill is an ordinary CI action or an application interface.


## Opt-in application trial

The `application` profile accepts only the separate disposable application
workflow and registers the distinct `newyou-well93-application` label. It requires
a 4096 MiB guest and the unchanged host reserves, a 24 GiB disposable disk,
a 60-minute runner deadline and an independent 80-minute supervisor deadline.
It never changes the required hosted workflows. Start only one reviewed owner
push on `well-93-application-run`, then invoke the trusted controller:

```bash
python3 tools/disposable_runner.py supervise --profile application --run-id RUN_ID --sha EXACT_SOURCE_SHA
```

Before registration, trusted guest bootstrap installs signed Ubuntu packages and
Docker's signed stable Ubuntu repository packages. A package service policy
prevents rootful Docker/containerd startup; those system services are masked.
Only the runner user's rootless Docker service is enabled, with a socket beneath
`/run/user/UID/`. The runner receives neither sudo nor docker-group membership.
There is no host socket, shared filesystem, host cache or DevCore environment.
See Docker's [rootless installation](https://docs.docker.com/engine/security/rootless/)
and [Ubuntu package instructions](https://docs.docker.com/engine/install/ubuntu/).

The one-job workflow pulls PostgreSQL 18 into that guest-local daemon and binds
its TEST port to guest loopback only. It creates a fresh restricted TEST role,
masks the generated password and uses the existing application TEST variables.
It verifies the pinned Elixir/OTP runtime, fetches locked dependencies without
shared caches, and runs fast and deep checks. `ImageOS: ubuntu24` selects the
matching prebuilt runtime on the custom runner. Diagnostic projections remain
bounded across the longer deadline. Live outcomes and performance belong in
Plane; adding this route does not certify its execution or authorize cutover.


Preparation records fixed stage/status values before and after package updates,
runner libraries, the reboot-required guard, isolation probes and application
bootstrap. A failure reports the stage while preserving the existing teardown.
Guest command text, package output and exception messages are not retained in
that journal. A pending-reboot result still prevents runner registration.

Isolation preparation records separate `guest_privilege`, `guest_socket`,
`guest_credentials`, `forbidden_connectivity` and `public_https` stages. Every
stage must pass, after host attachment/filter inspection, before `isolated`.
The journal retains fixed stage/status values and, on failure, one of
`ssh_transport`, `timeout`, `guest_command`, `output_limit` or `unknown`.
A fixed remote shell wrapper normalizes guest failures, including exit 255,
to exit 1 before OpenSSH returns. OpenSSH exit 255 or a local signal is
classified as transport failure; normalized remote failure is `guest_command`.
Transport failure cannot establish which network component failed. A deadline
expiry records `timeout`; output
beyond the fixed transport cap records `output_limit`. Neither means an
isolation check passed. Unclassified exceptions remain `unknown`.

At most ten latest preparation stages are retained, one per stage. The isolation
summary contains only passed category values, without target addresses, ports,
command output or exception text. Host/LAN/metadata targets still receive every
original forbidden-port probe. No failed category permits registration. These
diagnostics identify the failed boundary; they do not retroactively explain an
earlier destroyed guest or establish new live isolation proof.

The privilege stage rejects UID zero and privileged group membership. Its
root-owned Python proof inspects a deliberately narrow local sudo policy subset,
without interpreting sudo query exit status. Only enumerated stock Defaults,
root-only rules, non-member sudo/admin group rules, and one fixed includedir are
supported. Numeric UID rules, aliases, other user grants, custom plugins,
remote/duplicate policy sources, unknown syntax, symlinks, non-regular or writable
files, missing files and inspection failures stop registration. This may reject
otherwise valid unfamiliar policy; it never edits policy to obtain a pass.
Policy files are bounded to 64 KiB and the included directory to 32 entries.
Raw policy and inspection errors stay in the guest and are never exported.

Bounded SSH transport uses nonblocking stdin/stdout readiness under one
monotonic deadline. A child that does not read input cannot hold the controller
in a synchronous pipe write beyond the stage deadline. Output limits and final
process termination/reaping remain enforced, including timeout and pipe errors.


## Network proof correction and current execution interlock

A connection refusal does not establish silent DROP enforcement. Forbidden
probes now classify explicit outcomes: `connected`, `refused`, `timeout`,
`route_denied`, `permission_denied`, `probe_error`. Only timeout observations
complete the guest negative probe; every other result stops preparation.
Socket construction/setup and unexpected exceptions are execution errors.

The host independently validates a maximum of six target-class/outcome records.
Classes are `host`, `gateway`, `lan`, `metadata`, `container`, `overlay`.
No address, port, error text or raw command output enters that projection.
An invalid projection fails closed. A `timeouts_only` result is an observation,
not proof that host firewall DROP rules caused it.

**Execution is currently interlocked.** Even if all guest observations and
public HTTPS complete, `effective_firewall_proof_required` prevents transition
to `isolated` and runner registration. There is no bypass switch. Effective
interface-bound host rule ordering and before/after DROP counters still require
privileged read-only inspection and a reviewed enforcement-verification path.
The current host denies nftables, iptables and ebtables reads, including
noninteractive sudo attempts. XML round-trip matching cannot replace that proof.
No new VM is authorized to work around this limitation. Do not remove the
interlock or weaken outcome classification merely to obtain a passing trial.


## Proposed read-only host inspector, not installed

`tools/runner_firewall_inspector.py` is a standalone root-installable discovery
helper. Its isolated Python shebang prevents caller Python environment/import
injection. It accepts no arguments or stdin configuration. It invokes only
fixed nft/iptables-save/ebtables-save read commands, with a clean environment,
8-second per-command deadlines and 8 MiB transient output caps. It rejects
non-root/writable executables and parents. Raw rules are never printed or stored.

Only fixed frontend/readability/table/chain-candidate/counter-presence metadata
is exported. Generic counter presence is not an owned-VM counter delta. Candidate
chain presence is not ownership or rule-order verification. The report always
states `enforcement: unverified`; it cannot discharge the controller interlock.
This first capability step does not implement interface-bound runtime proof.

`tools/runner_firewall_inspector.sudoers` is a candidate single-command rule for
this workstation account. The empty argument specification denies arguments.
It grants neither a shell nor direct firewall commands. Do not install either
file until independent exact-head review and explicit owner approval. No helper,
sudo rule or host privilege is installed by repository tests or CI.

After that approval, installation must copy the reviewed helper into the fixed
`/usr/local/libexec/newyou-ci-firewall-inspect` path, owned root:root mode0755,
under a root-owned directory that is not writable by the invoking user. Validate
the candidate with `visudo -c -f` before installing the root:root mode0440 rule
at `/etc/sudoers.d/newyou-ci-firewall-inspect`. Stop if either destination already
exists unexpectedly; do not overwrite unrelated configuration. No daemon restart
or firewall mutation is required. Invoke only the installed helper through
`sudo -n /usr/local/libexec/newyou-ci-firewall-inspect`, never the user-writable
repository copy as root. Retain only its bounded JSON metadata.

Host inspection found libvirt12.0.0, iptables1.8.11 and nftables1.1.6, with both
iptables and ebtables pointing to xtables-nft-multi. The version-matched libvirt
[nwfilter driver source](https://github.com/libvirt/libvirt/blob/v12.0.0/src/nwfilter/nwfilter_ebiptables_driver.c)
uses ebtables/iptables. This identifies the expected compatibility stack, not
actual active per-VM enforcement. The virtual-network backend setting and
nwfilter driver must not be conflated. Root inspection remains pending.

### Offline firewall-verifier primitives

`tools/runner_firewall_proof.py` is an offline evaluator, not an installed
privileged collector or registration authority. It binds an exact journal UUID,
name and MAC to the sole expected network/filter attachment, traces a supported
explicit rule graph in order, and compares bounded counter observations with
unchanged binding, graph, probe and rule identities. Counter resets, stale
observations, unrelated chains, earlier accepts, opaque expressions on the traversed path and
unsupported predicates fail closed. Counters must follow predicates. Ownership
uses the full family/table/chain identity.

The narrow native-save adapter keeps physical bridge-port predicates separate
from logical interface predicates and preserves goto semantics;
it is not yet a complete adapter for libvirt's generated rules. In particular,
conntrack, UDP ports, bridge protocol/spoofing predicates, effective hook coverage and
native-save/kernel correspondence, including independently observed physical
bridge-port facts, still need implementation and regression
proof. Synthetic fixtures are not host attestations. Exact counter deltas remain
correlation and cannot establish controlled-probe exclusivity. Every comparison
still reports `enforcement: unverified`. Nothing invokes this module from
`isolate()` or removes the existing registration interlock.

The discovery source candidate now explicitly reads ebtables `nat` with counters
and recognizes persistent I/O and temporary J/P interface roots, plus the IP
roots. Libvirt's pinned driver uses bridge `nat`, not bridge `filter`, for this
path. The candidate adds `bridge_nat_table` to its bounded metadata. These source
changes do not replace any installed helper. Replacing installed bytes requires
fresh security review and separate owner approval. No tests invoke the installed
helper, inspect the host firewall, install privileges or provision a guest.
