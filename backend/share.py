#!/usr/bin/env python3
"""Independent ephemeral file shares; all state is private and runtime-only."""
import contextlib
import fcntl
import json
import os
from pathlib import Path
import queue
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import threading
import time
import uuid
# Runtime helpers live in a watched plugin directory: never write import caches.
sys.dont_write_bytecode = True
import backend
from urllib.parse import unquote, urlsplit

ROOT = backend.RUNTIME / 'share'
ACTIVE = ('starting', 'preparing', 'ready', 'stopping', 'paused')
PUBLICATION_TIMEOUT = 300
def resume_enabled():
    return read(backend.DATA / 'sharing.json').get('autoResume') is True


def set_resume(enabled):
    if not isinstance(enabled, bool):
        raise ValueError('Expected an automatic resume preference.')
    backend.prepare()
    write(backend.DATA / 'sharing.json', dict(autoResume=enabled))
    return status()


def available_generation():
    """Read service availability; onion publication does not need an exit."""
    from exit_controller import client, available
    try:
        state = client('cached')
        if available(state) and 0 <= time.time() - state.get('heartbeat', 0) < 10:
            generation = backend.gateway_generation()
            if generation and state.get('gatewayGeneration') == generation:
                if read_stop_generation() != generation:
                    return generation
    except (OSError, RuntimeError, ValueError):
        pass
    return ''


def read_stop_generation():
    try:
        return (backend.RUNTIME / 'stopped-generation').read_text()
    except FileNotFoundError:
        return ''


def require_available_tor():
    generation = available_generation()
    if not generation:
        raise RuntimeError('Tor is not available. Start Tor and retry.')
    # This is actual user demand, unlike passive status/resume polling.
    # OnionShare/ADD_ONION will build the circuits needed for publication.
    with backend.Controller() as control:
        control.command('SIGNAL ACTIVE')
    return generation


def validate_files(values):
    if not isinstance(values, list) or not values or len(values) > 100:
        raise ValueError('Choose between 1 and 100 files.')
    files = []
    for value in values:
        if not isinstance(value, str) or '\0' in value:
            raise ValueError('Invalid file selection.')
        if value.startswith('file:'):
            url = urlsplit(value)
            if url.netloc not in ('', 'localhost'):
                raise ValueError('Only local files can be shared.')
            value = unquote(url.path)
        path = Path(value)
        if not path.is_absolute() or not path.is_file():
            raise ValueError('Choose existing files, not folders.')
        # Opening verifies actual read access, including ACLs.
        with path.open('rb'):
            pass
        if str(path) not in files:
            files.append(str(path))
    return files

def output_state(line, value):
    if line.strip() == 'WORKSPACE_PUBLISHING':
        return dict(value, state='starting', phase='publishing', message='Publishing onion link…')
    if line.strip() == 'Compressing files.':
        return dict(value, state='preparing', phase='preparing', message='Preparing files…')
    if re.fullmatch(r'http://[a-z2-7]{56}\.onion/?', line.strip()):
        return dict(value, state='ready', phase='ready', url=line.strip(), message='Sharing is active.')
    return value


def directory(identity):
    if not isinstance(identity, str) or not re.fullmatch('[a-f0-9]{32}', identity):
        raise ValueError('Invalid share ID.')
    return ROOT / 'items' / identity


def unit(identity):
    directory(identity)
    return 'omarchy-tor-share-' + identity + '.service'


def read(path):
    try:
        value = json.loads(path.read_text())
        return value if isinstance(value, dict) else {}
    except (OSError, ValueError):
        return {}


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    with tempfile.NamedTemporaryFile(mode='w', dir=path.parent, delete=False) as stream:
        json.dump(value, stream)
        temporary = Path(stream.name)
    temporary.replace(path)


@contextlib.contextmanager
def locked():
    ROOT.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (ROOT / 'list.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        yield


def save(identity, value):
    value = dict(value, id=identity, heartbeat=time.time())
    write(directory(identity) / 'state.json', value)
    return value


def status():
    shares = []
    for path in sorted((ROOT / 'items').glob('*/state.json')):
        item = read(path)
        if not item or item.get('state') == 'stopped':
            continue
        if item.get('state') in ACTIVE and time.time() - item.get('heartbeat', 0) > 10:
            item.update(state='error', url='', message='Sharing ended unexpectedly. Retry to create a new link.')
        shares.append(item)
    shares.sort(key=lambda item: item.get('createdAt', 0))
    for item in shares: item.pop('heartbeat', None)
    return dict(api=2, autoResume=resume_enabled(),
                resumeNeedsRestart=resume_enabled() and any(s.get('state') in ACTIVE and not s.get('resumeCapable') for s in shares),
                shares=shares, readyCount=sum(1 for s in shares if s.get('state') == 'ready' and s.get('url')))


def ensure_tor():
    if not shutil.which('onionshare-cli'):
        raise RuntimeError('OnionShare is missing. Install the onionshare package.')
    try:
        with backend.Controller() as control:
            control.command('GETINFO status/bootstrap-phase')
    except (OSError, RuntimeError) as error:
        raise RuntimeError('Start Tor before sharing.') from error
    return require_available_tor()


def launch(identity, path, generation, colors=None):
    folder = directory(identity)
    previous = read(folder / 'state.json')
    value = dict(id=identity, name=Path(path).name, size=Path(path).stat().st_size,
                 state='starting', url='', resumeCapable=True, message='Connecting…', createdAt=previous.get('createdAt', time.time()))
    write(folder / 'request.json', dict(file=path, generation=generation, colors=colors or {}))
    save(identity, value)
    script = str(Path(__file__).resolve())
    try:
        result = subprocess.run(['systemd-run', '--user', '--quiet', '--collect', '--unit=' + unit(identity),
            '--property=KillMode=control-group', '--property=KillSignal=SIGINT', '--property=TimeoutStopSec=8',
            '--property=UMask=0077', '--property=StandardOutput=null', '--property=StandardError=null',
            '--property=ExecStopPost=/usr/bin/python3 -B ' + script + ' cleanup ' + identity,
            '/usr/bin/python3', '-B', script, 'worker', identity], capture_output=True, text=True, timeout=15)
        if result.returncode:
            raise RuntimeError('Could not start sharing. Retry.')
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        save(identity, dict(value, state='error', message=str(error)))


def start(values, colors=None):
    files = [str(Path(f).resolve()) for f in validate_files(values)]
    with locked():
        generation = ensure_tor()
        existing = {read(directory(s['id']) / 'request.json').get('file'): s['id']
                    for s in status()['shares']}
        selected = []
        for path in dict.fromkeys(files):
            identity = existing.get(path)
            if identity is None:
                identity = uuid.uuid4().hex
                launch(identity, path, generation, colors)
            selected.append(identity)
        return dict(status(), selectedIds=selected)


def stop_unit(identity):
    result = subprocess.run(['systemctl', '--user', 'stop', unit(identity)], capture_output=True, text=True, timeout=15)
    if result.returncode and subprocess.run(['systemctl', '--user', 'is-active', '--quiet', unit(identity)]).returncode == 0:
        raise RuntimeError('Could not stop sharing. Retry Stop.')


def stop(identity):
    with locked():
        folder = directory(identity)
        current = read(folder / 'state.json')
        if current:
            save(identity, dict(current, state='stopping', url='', message='Stopping…'))
            try:
                stop_unit(identity)
            except (OSError, RuntimeError, subprocess.SubprocessError) as error:
                save(identity, dict(current, state='stopping', url='', stopFailed=True,
                                    message='Could not stop sharing. Retry Stop.'))
                return dict(status(), error=str(error))
            shutil.rmtree(folder, ignore_errors=True)
        return status()


def retry(identity):
    with locked():
        folder = directory(identity)
        current = read(folder / 'state.json')
        if current.get('state') in ACTIVE and time.time() - current.get('heartbeat', 0) <= 10:
            return status()
        request = read(folder / 'request.json')
        files = validate_files([request.get('file')])
        generation = ensure_tor()
        stop_unit(identity)  # Reap a stale worker before reusing its identity.
        launch(identity, files[0], generation, request.get('colors'))
        return status()


def dismiss(identity):
    with locked():
        item = read(directory(identity) / 'state.json')
        if item.get('state') in ACTIVE and time.time() - item.get('heartbeat', 0) <= 10:
            raise ValueError('Stop this share before dismissing it.')
        stop_unit(identity)
        shutil.rmtree(directory(identity), ignore_errors=True)
        return status()


def cleanup(identity):
    folder = directory(identity)
    shutil.rmtree(folder / 'work', ignore_errors=True)
    value = read(folder / 'state.json')
    if value.get('state') == 'stopped':
        shutil.rmtree(folder, ignore_errors=True)
        return
    if value.get('state') in ACTIVE:
        save(identity, dict(value, state='error', url='', message='Sharing ended unexpectedly. Retry.'))


def run_worker(folder, publish, mode='share', ending=None):
    request = read(folder / 'request.json')
    work = folder / 'work'
    work.mkdir(mode=0o700, exist_ok=True)
    child = None
    reader_thread = None
    if ending is None:
        ending = threading.Event()
        for sig in (signal.SIGINT, signal.SIGTERM):
            signal.signal(sig, lambda *_: ending.set())
    value = read(folder / 'state.json')
    try:
        files = [] if mode == 'chat' else validate_files([request['file']])
        write(work / 'config.json', dict(connection_type='socket_file', socket_file_path=str(backend.GATEWAY / 'control'),
              auth_type='no_auth', use_autoupdate=False, locale='en'))
        write(work / 'colors.json', request.get('colors', {}))
        env = dict(os.environ, XDG_CONFIG_HOME=str(work), TMPDIR=str(work), PYTHONUNBUFFERED='1', LC_ALL='C.UTF-8',
                   TOR_SHARE_COLORS=str(work / 'colors.json'))
        child = subprocess.Popen([sys.executable, '-B', str(Path(__file__).with_name('share_page.py')), '--config',
            str(work / 'config.json'), '--public', '--connect-timeout', '120',
            *(['--chat'] if mode == 'chat' else ['--no-autostop-sharing']), '--', *files],
            env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, start_new_session=True)
        lines = queue.Queue(maxsize=512)
        def reader():
            for line in child.stdout:
                try: lines.put_nowait(line)
                except queue.Full: pass
        reader_thread = threading.Thread(target=reader, daemon=True)
        reader_thread.start()
        deadline = time.monotonic() + 120
        while not ending.wait(.25):
            while True:
                try:
                    line = lines.get_nowait()
                    previous_phase = value.get('phase')
                    value = output_state(line, value)
                    if value.get('phase') != previous_phase:
                        deadline = time.monotonic() + (PUBLICATION_TIMEOUT if value.get('phase') == 'publishing' else 120)
                    if mode == 'chat':
                        match = re.fullmatch(r'WORKSPACE_ROOM_COUNT (\d+)', line.strip())
                        if match: value.update(participants=int(match[1]), participantsAt=time.time())
                        if value['state'] == 'ready': value['message'] = ''
                    if line.strip() == 'WORKSPACE_STYLE_UNAVAILABLE':
                        value['styleWarning'] = 'Custom styling unavailable; using the standard OnionShare page.'
                except queue.Empty: break
            try: generation = backend.gateway_generation()
            except OSError: generation = ''
            try: deliberately_stopped = (backend.RUNTIME / 'stopped-generation').read_text() == request['generation']
            except OSError: deliberately_stopped = False
            if generation != request['generation'] or deliberately_stopped:
                value = dict(value, state='stopped', url='', reason='tor-stopped', message='Tor stopped.')
                break
            if child.poll() is not None:
                raise RuntimeError('OnionShare stopped unexpectedly. Retry.')
            if value['state'] != 'ready' and time.monotonic() > deadline:
                if value.get('phase') == 'publishing':
                    raise RuntimeError('Tor could not publish the onion link within 5 minutes. Retry when the connection is stable.')
                raise RuntimeError(('Room' if mode == 'chat' else 'Share') + ' did not become ready within 120 seconds. Retry.')
            publish(value)
        if ending.is_set():
            value = dict(value, state='stopped', url='', message='Sharing stopped.')
    except Exception as error:
        value = dict(value, state='error', url='', message=str(error))
    finally:
        if child is not None and child.poll() is None:
            try: os.killpg(child.pid, signal.SIGINT)
            except ProcessLookupError: pass
            try: child.wait(timeout=4)
            except subprocess.TimeoutExpired:
                os.killpg(child.pid, signal.SIGKILL)
                child.wait()
        if reader_thread is not None: reader_thread.join(timeout=1)
        if child is not None and child.stdout:
            child.stdout.close()
        shutil.rmtree(work, ignore_errors=True)
        publish(value)


def worker(identity):
    folder = directory(identity)
    ending = threading.Event()
    for sig in (signal.SIGINT, signal.SIGTERM):
        signal.signal(sig, lambda *_: ending.set())
    while not ending.is_set():
        run_worker(folder, lambda value: save(identity, value), ending=ending)
        value = read(folder / 'state.json')
        if ending.is_set() or value.get('reason') != 'tor-stopped' or not resume_enabled():
            break
        previous_generation = read(folder / 'request.json').get('generation')
        while not ending.is_set() and resume_enabled():
            save(identity, dict(value, state='paused', url='', message='Waiting for Tor · resumes automatically'))
            generation = available_generation()
            if generation and generation != previous_generation:
                request = read(folder / 'request.json')
                try:
                    validate_files([request.get('file')])
                except (OSError, ValueError) as error:
                    save(identity, dict(value, state='error', url='', reason='', message=str(error)))
                    return
                write(folder / 'request.json', dict(request, generation=generation))
                save(identity, dict(value, state='starting', url='', reason='', message='Resuming with a new link…'))
                break
            ending.wait(1)
        else:
            save(identity, dict(value, state='stopped', url='', message='Sharing stopped.'))
            break



def failure(error):
    return dict(status(), error=str(error))


def main():
    os.umask(0o077)
    action = sys.argv[1] if len(sys.argv) > 1 else 'status'
    try:
        if action in ('worker', 'cleanup'):
            (worker if action == 'worker' else cleanup)(sys.argv[2]); return
        body = json.loads(sys.stdin.readline(65537)) if action != 'status' else {}
        if action == 'start': result = start(body['files'], body.get('colors'))
        elif action in ('stop', 'retry', 'dismiss'): result = globals()[action](body['id'])
        elif action == 'resume-option': result = set_resume(body['enabled'])
        elif action == 'status': result = status()
        else: raise ValueError('Unknown sharing action.')
        print(json.dumps(result))
    except (OSError, ValueError, KeyError, RuntimeError, subprocess.SubprocessError) as error:
        print(json.dumps(failure(error)))
        sys.exit(1)


if __name__ == '__main__': main()
