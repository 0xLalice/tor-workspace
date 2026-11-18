#!/usr/bin/env python3
"""Wait for an authenticated setup step in a visible desktop-user terminal."""
import argparse
import os
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def command(step, packages):
    if step == 'install':
        if packages: raise ValueError('The install step takes no package names')
        return ['/usr/bin/python3', '-B', str(ROOT/'install/setup-session.py')]
    if step == 'backend':
        if packages: raise ValueError('The backend step takes no package names')
        return ['sudo', '/usr/bin/python3', '-I', str(ROOT/'system/install.py')]
    if not packages or any(not re.fullmatch(r'[a-z0-9][a-z0-9@+_.-]*', p) for p in packages):
        raise ValueError('Specify missing package names, without command flags')
    return ['omarchy', 'pkg', 'add', *packages]


def run(step, packages):
    if os.geteuid() == 0: raise ValueError('Run setup as the desktop user')
    args = command(step, packages)
    # Outside the plugin tree: completion writes must not reload the panel.
    with tempfile.TemporaryDirectory(prefix='tor-setup-', dir=os.environ.get('XDG_RUNTIME_DIR')) as folder:
        result_file = Path(folder)/'status'
        print('Waiting for the '+step+' terminal. Enter administrator authentication there if requested.', flush=True)
        result = subprocess.run(['foot', '--app-id=org.omarchy.tor-setup',
            '--title=Tor Workspace '+step+' setup', 'bash',
            str(ROOT/'install/terminal-command.sh'), str(result_file), *args], cwd=ROOT)
        try: status = int(result_file.read_text().strip())
        except (OSError, ValueError): status = result.returncode or 1
        print(step+' terminal finished with status '+str(status), flush=True)
        return status


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('step', choices=('install', 'packages', 'backend'))
    parser.add_argument('packages', nargs='*')
    options = parser.parse_args()
    try: raise SystemExit(run(options.step, options.packages))
    except (ValueError, OSError) as error: raise SystemExit(str(error))
