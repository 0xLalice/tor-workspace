#!/usr/bin/env python3
"""Apply the selected release as the desktop user, or open its privileged review."""
import contextlib
import fcntl
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'backend'))
from updates import git, handoff_status, pending_update
import setup_status

PYTHON = '/usr/bin/python3'


def readiness(root):
    return json.loads(subprocess.check_output([PYTHON, '-B', root/'install/setup_status.py'], cwd=root))


def needs_admin(state):
    version = tuple(map(int, state['torVersion'].split('.'))) if state['torVersion'] else ()
    minimum = tuple(map(int, state['minimumTorVersion'].split('.')))
    return (bool(state['missingRuntimePackages']) or version < minimum
            or (state['buildRequired'] and bool(state['missingBuildPackages']))
            or not all(state[key] for key in ('backendCompatible', 'backendCurrent', 'enrolled', 'socketReady')))


@contextlib.contextmanager
def candidate(root, revision):
    # Validate the selected Git tree before touching the running plugin.
    with tempfile.TemporaryDirectory(prefix='tor-workspace-update-') as folder:
        stage = Path(folder)
        git(root, 'worktree', 'add', '--quiet', '--detach', str(stage), revision)
        try:
            subprocess.run(['omarchy', 'plugin', 'validate', stage], check=True)
            builds = root/'build/qml'
            if builds.is_dir():
                shutil.copytree(builds, stage/'build/qml')
            yield stage
        finally:
            git(root, 'worktree', 'remove', '--force', str(stage))


def finish(root, previous, state):
    if needs_admin(state):
        raise RuntimeError('System setup changed. Check for updates again.')
    if state['buildRequired']:
        subprocess.run([PYTHON, '-B', root/'tools/build-native.py'], cwd=root, check=True)
    if not state['browserReady']:
        subprocess.run([PYTHON, '-B', root/'install/browser_install.py'], cwd=root, check=True)
    if not state['workspaceReady']:
        subprocess.run([PYTHON, '-B', root/'install/install-user.py', '--no-reload'], cwd=root, check=True)
    if not state['workspaceReady'] or git(root, 'diff', '--name-only', previous, 'HEAD', '--', 'integration/workspace.lua'):
        subprocess.run(['hyprctl', 'reload'], check=True)
        errors = subprocess.check_output(['hyprctl', 'configerrors'], text=True).strip()
        if errors not in ('', 'ok'):
            raise RuntimeError(errors)
    final = readiness(root)
    if not final['ready']:
        raise RuntimeError(' '.join(final['issues']))
    marker = root/'.git/tor-workspace-update.json'
    saved = marker.read_bytes()
    marker.unlink()
    try:
        subprocess.run(['omarchy', 'restart', 'shell'], check=True)
    except (OSError, subprocess.SubprocessError):
        marker.write_bytes(saved)
        raise


def run(root, revision, prompt):
    if os.geteuid() == 0:
        raise RuntimeError('Update as the desktop user.')
    # Omarchy installs normal Git clones. Keep retry state outside the source inventory.
    with (root/'.git/tor-workspace-update.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        marker = root/'.git/tor-workspace-update.json'
        pending = pending_update(root)
        head = git(root, 'rev-parse', 'HEAD')
        if git(root, 'status', '--porcelain'):
            raise RuntimeError('Local changes need attention before updating.')
        if pending and head == revision:
            previous = pending['previous']
            admin = needs_admin(readiness(root))
        else:
            checked = handoff_status(root, revision)
            if not checked.get('canUpdate'):
                raise RuntimeError(checked.get('error') or 'Check for updates again.')
            previous = head
            with candidate(root, revision) as stage:
                probe_path = 'install/setup_status.py'
                if (stage/probe_path).read_bytes() == (root/probe_path).read_bytes():
                    target_state = setup_status.status(root=stage)
                else:
                    target_state = readiness(stage)
                admin = needs_admin(target_state)
                if not admin:
                    subprocess.run([PYTHON, '-B', stage/'tools/check_package.py'], cwd=stage, check=True)
            if head != git(root, 'rev-parse', 'HEAD') or git(root, 'status', '--porcelain'):
                raise RuntimeError('The checkout changed. Check for updates again.')
        if admin:
            # The existing reviewed installation path owns any authentication.
            subprocess.run(['omarchy', 'launch', 'tui', 'bash', root/'install/agent-session.sh',
                            prompt, 'updateFailed'], cwd=root, check=True)
            # Some terminal launchers return before the terminal finishes.
            # Keep a pending direct-update marker until readiness is verified.
            if pending and git(root, 'rev-parse', 'HEAD') == revision and readiness(root)['ready']:
                finish(root, previous, readiness(root))
            return
        if head != revision:
            temporary = marker.with_suffix('.tmp')
            temporary.write_text(json.dumps(dict(revision=revision, previous=previous)))
            temporary.replace(marker)
            git(root, 'merge', '--ff-only', '--no-autostash', '--no-overwrite-ignore', revision)
        finish(root, previous, readiness(root))


if __name__ == '__main__':
    if len(sys.argv) != 3:
        raise SystemExit('Expected the selected revision and its review prompt.')
    try:
        run(ROOT, *sys.argv[1:])
    except (OSError, ValueError, KeyError, RuntimeError, subprocess.SubprocessError) as error:
        print('Update incomplete:', error, file=sys.stderr)
        subprocess.run(['notify-send', 'Tor Workspace update', str(error)], check=False)
        raise SystemExit(1)
