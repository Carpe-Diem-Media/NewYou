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
containers or token permissions. Guest-local Docker and PostgreSQL are subsequent
proof work, not provided by this initial controller.

`gh` obtains controller credentials on the host. The repository JIT API creates
one-job configuration with only the proving label. Only that short-lived payload
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
