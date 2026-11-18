"""Bounded circuit demand for explicit route requests and application launches.

The native controller remains the authority for observed routes and country policy.
No relay is selected here, and no website request is needed to prime Tor.
"""
import fcntl
import json
import os
import re
import time
import backend

WAIT_SECONDS = 45
RETRY_SECONDS = 60
MAX_ATTEMPTS = 3
IDLE_SECONDS = 60
BACKOFF_SECONDS = 300
FAILURE = 'Tor has not built a usable circuit. Retry or choose another exit country.'


def pending_general(reply):
    for line in reply.splitlines():
        fields = line.split()
        if len(fields) > 1 and fields[0].isdigit() and fields[1] in ('LAUNCHED', 'EXTENDED', 'GUARD_WAIT'):
            if any(f.startswith('BUILD_FLAGS=') and 'IS_INTERNAL' in f.split('=', 1)[1].split(',') for f in fields):
                continue
            if any(p in fields for p in ('PURPOSE=GENERAL', 'PURPOSE=CONFLUX_LINKED', 'PURPOSE=CONFLUX_UNLINKED')):
                return True
    return False


def recover(value, refresh=False):
    # Cached/bar reads and offline state must never initiate network activity.
    if not value.get('running') or value.get('state') not in ('ready', 'starting', 'unavailable'):
        return value
    path = backend.RUNTIME / 'circuit-recovery.json'
    if value['state'] == 'ready' and not refresh and not path.exists():
        return value
    backend.RUNTIME.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (backend.RUNTIME / 'circuit-recovery.lock').open('a') as lock:
        os.fchmod(lock.fileno(), 0o600)
        fcntl.flock(lock, fcntl.LOCK_EX)
        if value['state'] == 'ready' and not refresh:
            path.unlink(missing_ok=True)
            return value
        try:
            saved = json.loads(path.read_text())
        except (OSError, ValueError):
            saved = {}
        identity = [value.get('gatewayGeneration', ''), value.get('exitCountry', '')]
        data = saved if isinstance(saved, dict) and saved.get('identity') == identity and not refresh else dict(identity=identity, attempts=0)
        now = time.monotonic()
        # A panel reopened after idle gets a new recovery window. Continuous
        # polling backs off after three attempts, but never latches forever.
        last_seen = data.get('lastSeen', data.get('startedAt', data.get('nextAttemptAt', now)))
        exhausted = data.get('attempts', 0) >= MAX_ATTEMPTS and now >= data.get('nextAttemptAt', 0) + BACKOFF_SECONDS
        if now - last_seen >= IDLE_SECONDS or exhausted:
            data = dict(identity=identity, attempts=0)
        data['lastSeen'] = now

        def save():
            from exit_controller import atomic
            atomic(path, data)

        def waiting():
            return dict(value, state='ready' if value.get('route') else 'starting',
                        transition='building',
                        message='Building a replacement Tor circuit…' if value.get('route') else 'Building a Tor circuit…')

        def failed():
            # A still-usable old route stays usable during an explicit renewal.
            return dict(value, message=FAILURE) if value.get('route') else dict(value, state='error', transition='failed', message=FAILURE)

        save()
        if data.get('startedAt') is not None:
            if now - data['startedAt'] < WAIT_SECONDS:
                return waiting()
            data.pop('startedAt');data['error'] = True;save()
            return failed()
        if data.get('attempts', 0) >= MAX_ATTEMPTS or now < data.get('nextAttemptAt', 0):
            return failed()
        try:
            with backend.Controller() as control:
                # Wake before bootstrap/directory checks: both can be stale
                # precisely because Tor has stopped network work while idle.
                # GETINFO dormant can report 0 even while a dormant startup
                # waits for user activity. Opening the panel is that activity.
                if now - data.get('lastWakeAt', now - RETRY_SECONDS) >= RETRY_SECONDS:
                    control.command('SIGNAL ACTIVE')
                    data['lastWakeAt'] = now
                    save()
                bootstrap = control.command('GETINFO status/bootstrap-phase')
                progress = re.search(r'\bPROGRESS=(\d+)', bootstrap)
                if not progress:
                    raise RuntimeError('Missing bootstrap status')
                if int(progress[1]) < 100:
                    return dict(value, state='starting', transition='building',
                                progress=int(progress[1]), message='Connecting to Tor…')
                pending = pending_general(control.command('GETINFO circuit-status'))
                # The directory/country observer may be waiting on an existing build.
                # Do not launch another circuit every three-second UI poll.
                if not pending or refresh or data.get('attempts', 0) > 0:
                    reply = control.command('EXTENDCIRCUIT 0 purpose=general')
                    circuit = re.search(r'\bEXTENDED (\d+)', reply)
                    if not circuit:
                        raise RuntimeError('Circuit request not acknowledged')
                    data['requestedId'] = circuit[1]
            data.update(attempts=data.get('attempts', 0)+1, startedAt=now, nextAttemptAt=now+RETRY_SECONDS)
            data.pop('error', None);save()
            return waiting()
        except (OSError, RuntimeError):
            data.update(attempts=data.get('attempts', 0)+1, error=True, nextAttemptAt=now+RETRY_SECONDS)
            save()
            return failed()
