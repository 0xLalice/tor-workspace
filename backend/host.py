#!/usr/bin/env python3
"""One temporary onion host, independent of sharing and chat."""
import contextlib
import fcntl
import json
import os
from pathlib import Path
import queue
import re
import shutil
import signal
import socket
import subprocess
import sys
import threading
import time
sys.dont_write_bytecode = True
import backend
from share import read, write, require_available_tor

ROOT = backend.RUNTIME / 'host'
DATA = backend.DATA / 'host'
UNIT = 'omarchy-tor-host.service'
ACTIVE = ('starting', 'ready', 'stopping')
ONION = re.compile(r'[a-z2-7]{56}')
DEFAULT = dict(mode='folder', folder='', port=3000)


def strict_read(path):
    if not path.exists():
        return {}
    try:
        value = json.loads(path.read_text())
        if not isinstance(value, dict): raise ValueError()
        return value
    except (OSError, ValueError) as error:
        raise RuntimeError('Saved hosting data is unreadable. Restore it from backup; it has not been replaced.') from error


@contextlib.contextmanager
def locked():
    ROOT.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (ROOT / 'lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        yield


def save(value):
    write(ROOT / 'state.json', dict(value, heartbeat=time.time()))


def status():
    source = dict(DEFAULT)
    try:
        stored = strict_read(DATA / 'source.json')
        source.update({key: stored[key] for key in DEFAULT if key in stored})
        error = ''
    except RuntimeError as exc:
        error = str(exc)
    value = read(ROOT / 'state.json')
    phase = value.get('state', 'stopped')
    if phase in ACTIVE and time.time() - value.get('heartbeat', 0) > 10:
        phase, error = 'error', 'Hosting ended unexpectedly. Start again.'
    url = value.get('url', '') if phase == 'ready' else ''
    return dict(source=source, state=phase, url=url, error=error or value.get('error', ''),
                message=value.get('message', '') if phase in ACTIVE else '')


def validate(source):
    if not isinstance(source, dict): raise ValueError('Choose a website folder or local port.')
    mode = source.get('mode')
    result = dict(DEFAULT, mode=mode)
    if mode == 'folder':
        folder = source.get('folder', '')
        if not isinstance(folder, str) or not folder: raise ValueError('Choose a website folder.')
        path = Path(folder).expanduser().resolve()
        if not path.is_dir() or not (path / 'index.html').is_file():
            raise ValueError('Choose a website folder containing index.html.')
        if not os.access(path / 'index.html', os.R_OK): raise ValueError('Cannot read index.html.')
        result['folder'] = str(path)
    elif mode == 'app':
        port = source.get('port')
        if type(port) is not int or not 1 <= port <= 65535:
            raise ValueError('Enter a local port between 1 and 65535.')
        result['port'] = port
        try:
            with socket.create_connection(('127.0.0.1', port), timeout=2): pass
        except OSError as exc:
            raise ValueError('No app is listening on this local port. Start your app first.') from exc
    else:
        raise ValueError('Choose Website folder or Local app.')
    return result


def stop_service():
    result = subprocess.run(['systemctl', '--user', 'stop', UNIT], capture_output=True, text=True, timeout=15)
    if result.returncode and subprocess.run(['systemctl', '--user', 'is-active', '--quiet', UNIT],
                                          capture_output=True).returncode == 0:
        raise RuntimeError('Could not stop hosting. Retry Stop.')


def start(source):
    with locked():
        if status()['state'] in ACTIVE: return status()
        try:
            source = validate(source)
            strict_read(DATA / 'source.json')
            if source['mode'] == 'folder' and not shutil.which('onionshare-cli'):
                raise RuntimeError('OnionShare is missing. Install the onionshare package.')
            try:
                with backend.Controller() as control:
                    control.command('GETINFO status/bootstrap-phase')
            except (OSError, RuntimeError) as exc:
                raise RuntimeError('Start Tor before hosting.') from exc
            generation = require_available_tor()
            stop_service()
            write(DATA / 'source.json', source)
            write(ROOT / 'request.json', dict(source=source, generation=generation))
            save(dict(state='starting', message='Publishing onion address…'))
            script = str(Path(__file__).resolve())
            result = subprocess.run(['systemd-run', '--user', '--quiet', '--collect', '--unit=' + UNIT,
                '--property=KillMode=control-group', '--property=KillSignal=SIGINT', '--property=TimeoutStopSec=8',
                '--setenv=XDG_STATE_HOME=' + str(backend.DATA.parents[1]),
                '--property=UMask=0077', '--property=StandardOutput=null', '--property=StandardError=null',
                '--property=ExecStopPost=/usr/bin/python3 -B ' + script + ' cleanup',
                '/usr/bin/python3', '-B', script, 'worker'], capture_output=True, text=True, timeout=15)
            if result.returncode: raise RuntimeError('Could not start hosting. Retry.')
        except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as exc:
            save(dict(state='error', error=str(exc)))
        return status()


def stop():
    with locked():
        save(dict(state='stopping', message='Stopping hosting…'))
        try:
            stop_service()
            cleanup()
            save(dict(state='stopped'))
        except (OSError, RuntimeError, subprocess.SubprocessError) as exc:
            save(dict(state='stopping', error=str(exc)))
        return status()


def cleanup():
    shutil.rmtree(ROOT / 'work', ignore_errors=True)
    (ROOT / 'request.json').unlink(missing_ok=True)
    if read(ROOT / 'state.json').get('state') in ACTIVE:
        save(dict(state='error', error='Hosting ended. Start again.'))


def register(control, port):
    reply = control.command('ADD_ONION NEW:ED25519-V3 Port=80,127.0.0.1:' + str(port))
    fields = dict(line.split('=', 1) for line in reply.splitlines() if '=' in line)
    service_id = fields.get('ServiceID', '')
    if not ONION.fullmatch(service_id): raise RuntimeError('Tor did not return a valid onion address.')
    return service_id


def published(events, service_id, directories):
    # Tor may report UNKNOWN instead of the address on UPLOADED. Correlate
    # with this service's preceding UPLOAD event, as OnionShare/Stem do.
    done = False
    for event in events:
        parts = event.split()
        if len(parts) < 5 or parts[0] != 'HS_DESC': continue
        action, address, directory = parts[1], parts[2], parts[4]
        if action == 'UPLOAD' and address == service_id: directories.add(directory)
        if action == 'UPLOADED' and (address == service_id or directory in directories): done = True
    return done


def website_session(source):
    # OnionShare reads website settings from a session file kept only in runtime.
    # It is recreated for every launch and removed when hosting stops.
    # Pass directory children so index.html is served at /, not /folder/index.html.
    return dict(onion=dict(private_key=None),
                persistent=dict(mode='website', enabled=True), general=dict(public=True),
                website=dict(filenames=[str(p) for p in sorted(Path(source['folder']).iterdir())]))


class Reachability:
    """Check the new address through Tor without blocking worker heartbeats/Stop.

    Descriptor upload alone does not establish that a visitor can connect yet.
    HEAD avoids downloading the site or invoking a local app's GET handler.
    Any HTTP response establishes reachability, including authentication/405.
    """
    def __init__(self):
        self.process = None
        self.retry_at = 0

    def poll(self, url):
        if self.process is not None:
            if self.process.poll() is None: return False
            output, _ = self.process.communicate()
            reached = self.process.returncode == 0 and re.fullmatch(r'[1-5][0-9]{2}', output.strip()) is not None
            self.process = None
            self.retry_at = time.monotonic() + 2
            if reached: return True
        if time.monotonic() >= self.retry_at:
            self.process = subprocess.Popen([
                '/usr/bin/curl', '-q', '--silent', '--head', '--output', '/dev/null',
                '--write-out', '%{http_code}', '--max-time', '20', '--proto', '=http',
                '--proxy', 'socks5h://localhost' + str(backend.GATEWAY / 'socks'),
                '--noproxy', '', url], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        return False

    def close(self):
        if self.process is not None:
            if self.process.poll() is None:
                self.process.terminate()
                try: self.process.wait(timeout=2)
                except subprocess.TimeoutExpired: self.process.kill(); self.process.wait()
            self.process.communicate()
            self.process = None


def worker():
    request = strict_read(ROOT / 'request.json')
    ending = threading.Event()
    for sig in (signal.SIGINT, signal.SIGTERM): signal.signal(sig, lambda *_: ending.set())
    child = None
    reachability = Reachability()
    final = dict(state='stopped')
    work = ROOT / 'work'
    try:
        source = validate(request['source'])
        work.mkdir(mode=0o700, parents=True, exist_ok=True)
        with backend.Controller() as control:
            control.command('SETEVENTS HS_DESC')
            url = ''
            if source['mode'] == 'app':
                service_id = register(control, source['port'])
                url = 'http://' + service_id + '.onion'
            lines = queue.Queue(maxsize=512)
            if source['mode'] == 'folder':
                write(work / 'session.json', website_session(source))
                write(work / 'config.json', dict(connection_type='socket_file',
                    socket_file_path=str(backend.GATEWAY / 'control'), auth_type='no_auth',
                    use_autoupdate=False, locale='en'))
                env = dict(os.environ, XDG_CONFIG_HOME=str(work), TMPDIR=str(work),
                           PYTHONUNBUFFERED='1', LC_ALL='C.UTF-8')
                child = subprocess.Popen(['onionshare-cli', '--config', str(work / 'config.json'),
                    '--website', '--public', '--persistent', str(work / 'session.json'),
                    '--connect-timeout', '120', '--', source['folder']], env=env,
                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
                def collect():
                    for line in child.stdout:
                        try: lines.put_nowait(line.strip())
                        except queue.Full: pass
                threading.Thread(target=collect, daemon=True).start()
            value = dict(state='starting', message='Publishing onion address…')
            started = time.monotonic()
            deadline = started + 300
            directories = set()
            uploaded = False
            while not ending.wait(.25):
                if backend.gateway_generation() != request['generation']: break
                control.command('GETINFO version')
                if child is not None:
                    if child.poll() is not None: raise RuntimeError('Website server stopped. Check the folder and retry.')
                    while not lines.empty():
                        line = lines.get_nowait()
                        if re.fullmatch(r'http://[a-z2-7]{56}\.onion', line):
                            url = line
                            uploaded = True
                elif published(control.events, service_id, directories):
                    uploaded = True
                if uploaded and value['state'] != 'ready' and reachability.poll(url):
                    value = dict(state='ready', url=url, message='Hosting online')
                control.events.clear()
                if value['state'] != 'ready' and time.monotonic() > deadline:
                    raise RuntimeError('Onion publication timed out. Start again.')
                if value['state'] == 'starting' and time.monotonic() - started > 30:
                    value['message'] = ('Checking onion connection…' if uploaded else
                                        'Tor is still publishing… This can take a few minutes.')
                save(value)
    except Exception as exc:
        # Control errors intentionally omit protocol replies, which can contain keys.
        try: tor_stopped = backend.gateway_generation() != request.get('generation')
        except OSError: tor_stopped = True
        final = dict(state='stopped') if ending.is_set() or tor_stopped else dict(state='error', error=str(exc))
    finally:
        reachability.close()
        if child is not None:
            if child.poll() is None:
                child.send_signal(signal.SIGINT)
                try: child.wait(timeout=4)
                except subprocess.TimeoutExpired: child.kill(); child.wait()
            child.stdout.close()
        shutil.rmtree(work, ignore_errors=True)
        save(final)


def ready_url():
    value = status()
    if value['state'] != 'ready' or not re.fullmatch(r'http://[a-z2-7]{56}\.onion', value['url']):
        raise RuntimeError('Hosting is not online.')
    return value['url']


def main():
    os.umask(0o077)
    action = sys.argv[1] if len(sys.argv) > 1 else 'status'
    try:
        if action == 'worker': worker(); return
        if action == 'cleanup': cleanup(); return
        if action == 'start': result = start(json.loads(sys.stdin.readline(65537)))
        elif action == 'stop': result = stop()
        elif action == 'status': result = status()
        else: raise ValueError('Unknown hosting action.')
        print(json.dumps(result))
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as exc:
        print(json.dumps(dict(status(), error=str(exc))))
        sys.exit(1)


if __name__ == '__main__': main()
