#!/usr/bin/env python3
"""Terminal-side update preflight; preserve the checkout on failure/cancellation."""
import sys
sys.dont_write_bytecode = True
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'backend'))
from updates import handoff_status


def run(revision, prompt):
    state = handoff_status(ROOT, revision)
    if not state.get('canUpdate'):
        print(state.get('error') or 'No update is pending. Check for updates again.', flush=True)
        subprocess.run(['omarchy-shell', 'tor.workspace', 'updateFailed'], check=False)
        return 1
    return subprocess.call(['bash', str(ROOT/'install/agent-session.sh'), prompt, 'updateFailed'], cwd=ROOT)


if __name__ == '__main__':
    if len(sys.argv) != 3:
        raise SystemExit('Expected the reviewed revision and update prompt.')
    try:
        raise SystemExit(run(*sys.argv[1:]))
    except KeyboardInterrupt:
        raise SystemExit(130)
