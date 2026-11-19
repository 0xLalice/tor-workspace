#!/usr/bin/env python3
"""Run approved setup in one desktop-user terminal with one sudo session."""
import os
from pathlib import Path
import signal
import subprocess
import sys
import threading

import setup_status

ROOT = Path(__file__).resolve().parents[1]


def run(args):
    return subprocess.run(args, cwd=ROOT, check=True)


class Authentication:
    """Keep this terminal's normal sudo timestamp alive only for privileged setup.

    No password handling, sudoers edits, elevated builds, or background root shell.
    Later privileged commands are noninteractive: expired authorization fails.
    """
    def __init__(self):
        self.stopped = threading.Event()
        self.worker = None

    def refresh(self):
        while not self.stopped.wait(30):
            try:
                subprocess.run(['sudo', '-n', '-v'], check=True, timeout=5,
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            except (OSError, subprocess.SubprocessError):
                return

    def __enter__(self):
        print('Administrator authentication is needed to install missing system packages '
              'and the root-owned Tor backend. Enter your desktop-user password here once. '
              'Builds and browser downloads remain unprivileged.', flush=True)
        run(['sudo', '-v'])
        self.worker = threading.Thread(target=self.refresh, daemon=True)
        self.worker.start()
        return self

    def __exit__(self, *_):
        self.stopped.set()
        if self.worker: self.worker.join(timeout=6)
        subprocess.run(['sudo', '-k'], check=False)


def prerequisites(state):
    packages = list(state['missingRuntimePackages'])
    if state['buildRequired']: packages += state['missingBuildPackages']
    return sorted(set(packages))


def build_and_backend(state, backend_needed):
    version, issue = setup_status.tor_version_status()
    if issue:
        subprocess.run(['pacman', '-Si', 'tor'], check=False)
        raise RuntimeError(issue)
    print('Tor version: '+version, flush=True)
    if state['buildRequired']:
        run([sys.executable, '-B', str(ROOT/'tools/build-native.py')])
    if backend_needed:
        run(['sudo', '-n', '/usr/bin/python3', '-I', str(ROOT/'system/install.py')])


def install():
    if os.geteuid() == 0: raise RuntimeError('Run setup as the desktop user, not root.')
    run([sys.executable, '-B', str(ROOT/'tools/check_package.py')])
    state = setup_status.status()
    packages = prerequisites(state)
    backend_needed = not all(state[key] for key in
                            ('backendCompatible', 'backendCurrent', 'enrolled', 'socketReady'))
    if packages or backend_needed:
        with Authentication():
            if packages:
                # Omarchy's package wrapper runs as the user and shares this TTY's
                # sudo timestamp. Its package policy/signature checks stay intact.
                run(['omarchy', 'pkg', 'add', *packages])
            build_and_backend(state, backend_needed)
    else:
        build_and_backend(state, False)
    # The authorization session is already closed before network downloads.
    if not state['browserReady']:
        run([sys.executable, '-B', str(ROOT/'install/browser_install.py')])
    run([sys.executable, '-B', str(ROOT/'install/install-user.py'), '--no-reload'])
    run(['hyprctl', 'reload'])
    errors = subprocess.check_output(['hyprctl', 'configerrors'], text=True).strip()
    if errors not in ('', 'ok'): raise RuntimeError('Hyprland configuration errors: '+errors)
    ready = setup_status.status()
    if not ready['ready']: raise RuntimeError('; '.join(ready['issues']))
    print('Setup readiness passed. Restart the shell and verify the panel visually. '
          'This setup did not start Tor.', flush=True)


if __name__ == '__main__':
    def interrupted(number, _frame):
        raise SystemExit(128+number)
    for number in (signal.SIGHUP, signal.SIGTERM): signal.signal(number, interrupted)
    try: install()
    except KeyboardInterrupt: raise SystemExit(130)
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        raise SystemExit('Setup incomplete: '+str(error))
