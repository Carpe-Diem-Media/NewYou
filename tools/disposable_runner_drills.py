"""Trusted-host failure injection. Never invoke this from a workflow.

These drills deliberately create a lost response or an orphan. Run only after
resource preflight, with immediate controller recovery and residue inspection.
They never reboot the workstation or operate on an unrelated libvirt resource.
"""
import argparse
import fcntl
import json
import os
import sys
import time
import uuid

try:
    from tools import disposable_runner as runner
except ModuleNotFoundError:
    import disposable_runner as runner


class LostResponse:
    """Real create, discarded reply, then one simulated stale empty lookup."""
    def __init__(self, provider):
        self.provider = provider
        self.created = False
        self.hidden = False

    def __call__(self, path, method='GET', body=None):
        if path == 'actions/runners/generate-jitconfig' and method == 'POST':
            self.provider(path, method, body)
            self.created = True
            raise RuntimeError('drill_lost_registration_response')
        if self.created and not self.hidden and path.startswith('actions/runners?'):
            self.hidden = True
            return {'runners': []}
        return self.provider(path, method, body)


def orphan(memory):
    """Crash after isolated provisioning, deliberately bypassing finally."""
    os.umask(0o077)
    runner.ROOT.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (runner.ROOT / 'controller.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        pending = [p for p in runner.ROOT.glob('newyou-w93-*.json')
                   if json.loads(p.read_text())['phase'] != 'cleaned']
        if pending:
            raise RuntimeError('recover_pending_resources_first')
        capacity = runner.preflight(memory)
        identity = uuid.uuid4()
        state = {'name': 'newyou-w93-' + identity.hex[:12], 'uuid': str(identity),
                 'mac': '52:54:00:' + ':'.join(f'{n:02x}' for n in identity.bytes[:3]),
                 'phase': 'provisioning', 'created_at': int(time.time()),
                 'capacity': capacity, 'drill': 'orphan_restart'}
        runner.save(state)
        try:
            runner.provision(state, memory)
            runner.isolate(state)
        except BaseException:
            runner.cleanup(state)
            raise
        # The next independently started recover command must reclaim this VM.
        os._exit(71)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=['lost-response', 'orphan'])
    parser.add_argument('--run-id', type=int)
    parser.add_argument('--sha')
    parser.add_argument('--memory', type=int, default=2048)
    args = parser.parse_args()
    if not os.environ.get('INVOCATION_ID'):
        parser.error('drills require a bounded systemd user unit')
    if args.mode == 'orphan':
        orphan(args.memory)
    else:
        if not args.run_id or not args.sha:
            parser.error('lost-response requires --run-id and --sha')
        runner.github = LostResponse(runner.github)
        sys.argv = ['disposable_runner', 'prove', '--run-id', str(args.run_id),
                    '--sha', args.sha, '--memory', str(args.memory)]
        runner.main()


if __name__ == '__main__':
    try:
        main()
    except RuntimeError as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(1)
