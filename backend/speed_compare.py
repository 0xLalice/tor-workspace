#!/usr/bin/env python3
"""Bounded, cancellable download comparison with explicit route preparation."""
import fcntl
import json
import os
from pathlib import Path
import selectors
import signal
import subprocess
import threading
import time
import tempfile
from urllib.parse import urlsplit

SIZE = 10485760
LIMIT = 30
# Same discovery service used by omarchy-network-speedtest.
FAST_API = 'https://api.fast.com/netflix/speedtest/v2?https=true&token=YXNkZmFzZGxmbnNkYWZoYXNkZmhrYWxm&urlCount=3'
TOR_URL = 'https://speed.cloudflare.com/__down?bytes=' + str(SIZE)
SOCKS = '/run/omarchy-tor-native/' + str(os.getuid()) + '-io/socks'
CURL = '/usr/bin/curl'


def command(route, url=None, limit=LIMIT):
    if route not in ('direct', 'tor'): raise KeyError(route)
    if route == 'tor': url = TOR_URL
    elif not url: raise ValueError('Fast.com target required')
    routing = ['--proxy', 'socks5h://localhost' + SOCKS, '--noproxy', ''] if route == 'tor' else ['--proxy', '', '--noproxy', '*']
    return [CURL, '-q', *routing, '--proto', '=https', '--fail', '--silent', '--show-error',
            '--connect-timeout', '15', '--max-time', str(limit), '--max-filesize', str(SIZE),
            '--header', 'Accept-Encoding: identity', '--header', 'Cache-Control: no-cache',
            '--output', '-', '--write-out', '%{stderr}\n%{json}\n', *(['--range', '0-' + str(SIZE - 1)] if route == 'direct' else []), url]


def result(code, metadata, received):
    base = dict(bytes=received, status='failed', message='Download failed')
    if code == 28:
        return dict(base, status='timeout', message='Timed out after 30 seconds')
    if code != 0:
        return dict(base, message='HTTP error' if code == 22 else 'Connection or transfer failed')
    if metadata.get('http_code') not in (200, 206) or received != SIZE or metadata.get('size_download') != SIZE:
        return dict(base, message='Unexpected or incomplete response')
    content = metadata.get('content_type', '') or ''
    if 'text/html' in content:
        return dict(base, message='Server returned a page instead of test data')
    first = metadata.get('time_starttransfer', 0)
    duration = metadata.get('time_total', 0) - first
    if first <= 0 or duration <= 0:
        return dict(base, message='Timing unavailable')
    return dict(status='complete', bytes=received, mbps=received * 8 / duration / 1e6,
                ttfb=first * 1000, brief=duration < 1, message='Brief sample' if duration < 1 else '')


def ready(cancelled=None):
    import backend
    from exit_controller import wait_ready
    if not backend.host_network():
        raise RuntimeError('Direct comparison must run outside the Tor namespace.')
    with backend.Controller() as control:
        if 'PROGRESS=100' not in control.command('GETINFO status/bootstrap-phase'):
            raise RuntimeError('Connect Tor before starting the comparison.')
    def progress(_):
        if cancelled is not None and cancelled.is_set():
            raise RuntimeError('Comparison cancelled.')
    wait_ready(on_progress=progress)


def stop(process):
    if process.poll() is None:
        process.terminate()
        try: process.wait(timeout=1)
        except subprocess.TimeoutExpired:
            process.kill(); process.wait()


def fast_target(cancelled, env, locations=None):
    process = subprocess.Popen([CURL, '-q', '--proxy', '', '--noproxy', '*',
        '--proto', '=https', '--fail', '--silent', '--show-error',
        '--max-time', '15', '--max-filesize', '65536', FAST_API],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env)
    try:
        while not cancelled.is_set():
            try: output, _ = process.communicate(timeout=.1)
            except subprocess.TimeoutExpired: continue
            if process.returncode: raise RuntimeError('Fast.com unavailable')
            try:
                payload = json.loads(output)
                targets = payload['targets']
                if locations is not None:
                    locations['origin'] = payload.get('client', {}).get('location', {}).get('country', '')
                for target in targets:
                    url = target['url']; parsed = urlsplit(url)
                    if (parsed.scheme == 'https' and parsed.hostname and
                            parsed.hostname.endswith('.nflxvideo.net') and
                            parsed.port in (None, 443) and not parsed.username and not parsed.password):
                        if locations is not None:
                            locations['directEndpoint'] = target.get('location', {}).get('country', '')
                        return url
            except (ValueError, KeyError, TypeError, AttributeError): pass
            raise RuntimeError('No valid Fast.com server')
        return None
    finally:
        stop(process)
        process.stdout.close(); process.stderr.close()


def measure_download(route, emit, cancelled, locations=None, watcher=None, headers=None):
    env = {k:v for k,v in os.environ.items() if not k.lower().endswith('_proxy')}
    started = time.monotonic()
    if route == 'direct':
        emit(dict(status='running', bytes=0, elapsed=0, message='Finding server'))
        try: url = fast_target(cancelled, env, locations)
        except RuntimeError as error: return dict(status='failed', bytes=0, message=str(error))
        if cancelled.is_set(): return dict(status='cancelled', bytes=0, message='Cancelled')
        args = command(route, url, max(.1, LIMIT - (time.monotonic() - started)))
    else:
        args = command(route)
    if watcher: args[2:2] = ['--proxy-user', watcher.tag + ':test']
    if headers: args[2:2] = ['--dump-header', headers]
    process = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env)
    received = 0
    last = 0
    try:
        with selectors.DefaultSelector() as selector:
            selector.register(process.stdout, selectors.EVENT_READ)
            while selector.get_map():
                if cancelled.is_set():
                    return dict(status='cancelled', bytes=received, message='Cancelled')
                if time.monotonic() - started > LIMIT + 3:
                    return dict(status='timeout', bytes=received, message='Timed out after 30 seconds')
                for key, _ in selector.select(.1):
                    block = os.read(key.fd, 65536)
                    if not block: selector.unregister(key.fileobj)
                    else: received += len(block)
                if received > SIZE:
                    return dict(status='failed', bytes=received, message='Response exceeded data limit')
                elapsed = time.monotonic() - started
                if elapsed - last >= .25:
                    emit(dict(status='running', bytes=received, elapsed=elapsed)); last = elapsed
        code = process.wait(timeout=2)
        lines = process.stderr.read().decode(errors='replace').splitlines()
        try: metadata = json.loads(next(line for line in reversed(lines) if line.startswith('{')))
        except (ValueError, StopIteration): metadata = {}
        return result(code, metadata, received)
    finally:
        stop(process)
        process.stdout.close(); process.stderr.close()


def measure(route, emit, cancelled, locations=None):
    # Tests of the transfer primitive can omit attribution; real sessions share locations.
    if locations is None:
        return measure_download(route, emit, cancelled)
    from speed_route import CircuitWatch, country, describe, endpoint, geography
    points, airports = geography()
    watcher = CircuitWatch() if route == 'tor' else None
    with tempfile.TemporaryDirectory(prefix='tor-speed-') as directory:
        headers = str(Path(directory) / 'headers')
        def enrich(value):
            origin = country(locations.get('origin', ''))
            if route == 'direct':
                path = [origin, locations.get('directEndpoint', '')]
            else:
                state = watcher.data
                try: text = Path(headers).read_text()
                except OSError: text = ''
                target = endpoint(text, airports)
                value = dict(value, **({'circuitId': state['circuitId']} if state.get('circuitId') else {}))
                if not state.get('relayPaths'):
                    return dict(value, countries=[origin or '?', '…', target or '?'])
                paths = [describe([origin] + relays + [target], points) for relays in state['relayPaths']]
                value = dict(value, circuitIds=state['circuitIds'], paths=paths, multipath=state['multipath'], sharedExitConfirmed=state.get('sharedExitConfirmed',False))
                if len(paths) == 1 and not state['multipath']:
                    return dict(value, **paths[0])
                if all('roundTripKm' in p or p.get('sameCountry') for p in paths):
                    distances = [p.get('roundTripKm', 0) for p in paths]
                    if all(p.get('sameCountry') for p in paths): value['sameCountry'] = True
                    elif all('roundTripKm' in p for p in paths):
                        value.update(minRoundTripKm=min(distances), maxRoundTripKm=max(distances))
                return value
            return dict(value, **describe(path, points))
        try:
            if watcher: watcher.start()
            value = measure_download(route, lambda value: emit(enrich(value)), cancelled, locations, watcher, headers)
            # Allow the observer to consume the final event from a very short transfer.
            if watcher: watcher.done.wait(.15)
            return enrich(value)
        finally:
            if watcher: watcher.close()


def run(emit, cancelled):
    state = dict(running=True, direct=dict(status='waiting'), tor=dict(status='waiting'))
    lock = None
    try:
        directory = Path(os.environ.get('XDG_RUNTIME_DIR', '/run/user/' + str(os.getuid()))) / 'tor-speed-compare'
        directory.mkdir(mode=0o700, exist_ok=True)
        lock = (directory / 'lock').open('a')
        try: fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError: raise RuntimeError('A comparison is already running.')
        try: ready(cancelled)
        except OSError: raise RuntimeError('Connect Tor before starting the comparison.')
        locations = {}
        for route in ('direct', 'tor'):
            if cancelled.is_set(): break
            def update(value, route=route):
                state[route] = value
                emit(dict(state))
            update(dict(status='running', bytes=0, elapsed=0))
            state[route] = measure(route, update, cancelled, locations)
            emit(dict(state))
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        state['error'] = str(error)
    finally:
        if cancelled.is_set():
            for route in ('direct', 'tor'):
                if state[route]['status'] in ('waiting', 'running'):
                    state[route] = dict(status='cancelled', message='Cancelled')
        state['running'] = False
        emit(state)
        if lock: lock.close()



if __name__ == '__main__':
    cancelled = threading.Event()
    signal.signal(signal.SIGTERM, lambda *_: cancelled.set())
    signal.signal(signal.SIGINT, lambda *_: cancelled.set())
    # Parent death closes the pipe; no orphaned download survives its UI owner.
    def watch():
        os.read(0, 1); cancelled.set()
    threading.Thread(target=watch, daemon=True).start()
    def emit(value):
        try: print(json.dumps(value), flush=True)
        except BrokenPipeError: cancelled.set()
    run(emit, cancelled)
