#!/usr/bin/env python3
"""One disposable OnionShare room, using the existing supervised worker."""
import contextlib
import fcntl
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
import json
# Runtime helpers live in a watched plugin directory: never write import caches.
sys.dont_write_bytecode = True
import backend
from share import read, write, run_worker, ensure_tor, ACTIVE

ROOT = backend.RUNTIME / 'chat'
UNIT = 'omarchy-tor-chat.service'


@contextlib.contextmanager
def locked():
    ROOT.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (ROOT / 'lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        yield


def save(value):
    write(ROOT / 'state.json', dict(value, heartbeat=time.time()))


def status():
    value = read(ROOT / 'state.json') or dict(state='idle', url='')
    if value.get('state') in ACTIVE and time.time() - value.get('heartbeat', 0) > 10:
        value.update(state='error', url='', message='Room ended. Start again.')
    if value.get('state') != 'ready' or time.time() - value.get('participantsAt', 0) > 5:
        value.pop('participants', None)
    value.pop('participantsAt', None)
    value.pop('heartbeat', None)
    return value


def stop_service():
    result = subprocess.run(['systemctl', '--user', 'stop', UNIT], capture_output=True, text=True, timeout=15)
    if result.returncode and subprocess.run(['systemctl', '--user', 'is-active', '--quiet', UNIT]).returncode == 0:
        raise RuntimeError('Could not stop the room. Retry.')


def start(colors=None):
    with locked():
        if status()['state'] in ACTIVE:
            return status()
        try:
            try:
                generation = ensure_tor()
            except RuntimeError as error:
                if str(error) == 'Start Tor before sharing.':
                    raise RuntimeError('Start Tor before starting a room.') from error
                raise
            stop_service()  # Reap a stale worker before creating a fresh onion identity.
            write(ROOT / 'request.json', dict(generation=generation, colors=colors or {}))
            save(dict(state='starting', url='', message='Starting room…'))
            script = str(Path(__file__).resolve())
            result = subprocess.run(['systemd-run', '--user', '--quiet', '--collect', '--unit=' + UNIT,
                '--property=KillMode=control-group', '--property=KillSignal=SIGINT', '--property=TimeoutStopSec=8',
                '--property=UMask=0077', '--property=StandardOutput=null', '--property=StandardError=null',
                '--property=ExecStopPost=/usr/bin/python3 -B ' + script + ' cleanup',
                '/usr/bin/python3', '-B', script, 'worker'], capture_output=True, text=True, timeout=15)
            if result.returncode: raise RuntimeError('Could not start the room. Retry.')
        except (OSError, RuntimeError, subprocess.SubprocessError) as error:
            save(dict(state='error', url='', message=str(error)))
        return status()


def stop():
    with locked():
        save(dict(state='stopping', url='', message='Stopping…'))
        try:
            stop_service()
        except (OSError, RuntimeError, subprocess.SubprocessError) as error:
            save(dict(state='stopping', url='', error=str(error), message='Retry Stop room.'))
            return status()
        cleanup()
        save(dict(state='stopped', url=''))
        return status()


def cleanup():
    shutil.rmtree(ROOT / 'work', ignore_errors=True)
    (ROOT / 'request.json').unlink(missing_ok=True)
    value = status()
    if value['state'] in ACTIVE:
        save(dict(state='error', url='', message='Room ended. Start again.'))


def ready_url():
    value = status()
    if value['state'] != 'ready' or not re.fullmatch(r'http://[a-z2-7]{56}\.onion/?', value.get('url', '')):
        raise RuntimeError('The room is not ready.')
    return value['url']


def main():
    os.umask(0o077)
    action = sys.argv[1] if len(sys.argv) > 1 else 'status'
    try:
        if action == 'worker': run_worker(ROOT, save, 'chat'); return
        if action == 'cleanup': cleanup(); return
        if action == 'start': result = start(json.loads(sys.stdin.readline(65537)).get('colors'))
        elif action == 'stop': result = stop()
        elif action == 'status': result = status()
        else: raise ValueError('Unknown room action.')
        print(json.dumps(result))
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(json.dumps(dict(status(), error=str(error))))
        sys.exit(1)


if __name__ == '__main__': main()
