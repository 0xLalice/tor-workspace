#!/usr/bin/python3
"""API 3: country configuration and observation of Tor-managed circuits."""
import base64
import fcntl
import hashlib
import ipaddress
import json
import os
from pathlib import Path
import re
import select
import socket
import struct
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parent))
import backend

API = 3
ACTIONS = ('status', 'cached', 'set-country', 'new-circuits', 'launch-ready', 'observe-exit')


def atomic(path, value):
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(value) + '\n')
    temporary.chmod(0o600)
    temporary.replace(path)


def preferences():
    value = json.loads((backend.DATA / 'country-policy.json').read_text())
    if value.get('api') != API:
        raise RuntimeError('Incompatible country preferences')
    return dict(api=API, country=backend.validate_country(value['country']))


def rpc(action='status', value=None, timeout=8):
    with socket.socket(socket.AF_UNIX, socket.SOCK_SEQPACKET) as connection:
        connection.settimeout(timeout)
        connection.connect(str(backend.RUNTIME / 'controller.sock'))
        connection.send(json.dumps(dict(api=API, action=action, value=value)).encode())
        reply = json.loads(connection.recv(262144))
        if reply.get('api') != API:
            raise RuntimeError('Incompatible exit controller; update the backend')
        if 'error' in reply:
            raise RuntimeError(reply['error'])
        return reply


def client(action, value=None):
    if action not in ACTIONS:
        raise ValueError('Unknown controller action')
    if action == 'set-country':
        backend.validate_country(value)
    backend.prepare()
    try:
        return rpc(action, value)
    except (FileNotFoundError, ConnectionRefusedError):
        with (backend.DATA / 'policy.lock').open('a') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            if (backend.GATEWAY / 'control').exists():
                return dict(api=API, state='error', running=True, route=[],
                            message='Country controller unavailable. Update the backend.')
            from country_migration import migrate
            migrate()
            prefs = preferences()
            if action == 'set-country':
                prefs['country'] = value
                atomic(backend.DATA / 'country-policy.json', prefs)
            return dict(api=API, state='offline', running=False, route=[],
                        exitCountry=prefs['country'], message='Tor is off.')


def parse_directory(text):
    relays = {}
    relay = None
    for line in text.splitlines():
        f = line.split()
        if f[:1] == ['r'] and len(f) >= 9:
            fingerprint = base64.b64decode(f[2] + '=' * (-len(f[2]) % 4)).hex().upper()
            relay = dict(fingerprint=fingerprint, name=f[1], ip=f[6], flags=[])
            relays[fingerprint] = relay
        elif relay and f[:1] == ['s']:
            relay['flags'] = f[1:]
    return {fp: r for fp, r in relays.items()
            if {'Exit', 'Running', 'Valid'} <= set(r['flags']) and 'BadExit' not in r['flags']}


def built_circuits(text):
    result = {}
    for line in text.splitlines():
        f = line.split()
        if len(f) < 4 or f[1] != 'BUILT' or not f[2].startswith('$'): continue
        if not any(p in f for p in ('PURPOSE=GENERAL', 'PURPOSE=CONFLUX_LINKED')): continue
        if any(field.startswith('BUILD_FLAGS=') and 'IS_INTERNAL' in field.split('=',1)[1].split(',') for field in f): continue
        path = [re.split('[~=]', n)[0].lstrip('$').upper() for n in f[2].split(',')]
        if len(path) >= 3: result[f[0]] = path
    return result


def exit_circuits(text):
    """Include unfinished exits and every Conflux leg; leave onion circuits alone."""
    result = {}
    for line in text.splitlines():
        fields = line.split()
        if len(fields) < 3 or not fields[0].isdigit():
            continue
        options = dict(field.split('=', 1) for field in fields[2:] if '=' in field)
        if options.get('PURPOSE') not in ('GENERAL', 'CONFLUX_LINKED', 'CONFLUX_UNLINKED'):
            continue
        if 'IS_INTERNAL' in options.get('BUILD_FLAGS', '').split(','):
            continue
        path = ([re.split('[~=]', n)[0].lstrip('$').upper() for n in fields[2].split(',')]
                if fields[2].startswith('$') else [])
        result[fields[0]] = dict(path=path, status=fields[1], group=options.get('CONFLUX_ID', ''))
    return result


def ready(state, country):
    return (state.get('api') == API and state.get('running') is True
            and state.get('state') == 'ready' and state.get('policyReady') is True
            and state.get('exitCountry') == country and state.get('appliedCountry') == country
            and (not country or state.get('verifiedCountry') == country))


def available(state):
    """Tor can accept work; an unused exit circuit is not required.

    This is not permission to launch an exit-routed application: ready() and
    the privileged launch boundary still verify its actual circuit separately.
    """
    return (state.get('api') == API and state.get('running') is True and state.get('serviceReady') is True
            and state.get('state') in ('ready', 'starting')
            and state.get('exitCountry') == state.get('appliedCountry'))


def wait_ready(timeout=20, on_progress=None):
    """Explicit application demand; cached observations never wake Tor."""
    from circuit_recovery import recover
    deadline = time.monotonic() + timeout
    while True:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise RuntimeError('No verified Tor route became available. Retry from Tor Workspace.')
        try:
            state = rpc('launch-ready', timeout=min(4, remaining))
        except (FileNotFoundError, ConnectionRefusedError, TimeoutError):
            if not (backend.GATEWAY / 'control').exists():
                raise RuntimeError('Tor is off. Start Tor in the plugin.') from None
            state = dict(state='starting', running=True, message='Waiting for the Tor controller…')
        if ready(state, state.get('exitCountry')):
            recover(state)  # Clear completed demand without creating another circuit.
            return state
        if state.get('state') in ('unavailable', 'error') or not state.get('running'):
            raise RuntimeError(state.get('message') or 'Tor country policy is unavailable.')
        # Explicit demand can build a route when an idle Tor has no circuits.
        # It respects the current policy and lets Tor select the path.
        if state.get('api') == API:
            state = recover(state)
        if on_progress:
            on_progress(state.get('message') or 'Waiting for a verified Tor route…')
        time.sleep(min(.2, max(0, deadline - time.monotonic())))


class Gateway:
    def __init__(self, control):
        self.control = control
        self.prefs = preferences()
        self.relays = {}
        self.directory_hash = ''
        self.directory_at = 0
        self.successful = set()
        self.circuits = {}
        self.replacement_requested = False
        self.stream_observations = []
        self.bootstrapped = False
        self.state = dict(api=API, exitCountry=self.prefs['country'], route=[], circuitId='',
                          appliedCountry=None, verifiedCountry='', policyReady=False, serviceReady=False,
                          state='starting', running=True, gateway='native',
                          gatewayGeneration=backend.gateway_generation(),
                          revision=time.time_ns()//1000, transition='building', message='', nextChangeAt=0)
        self.control.command('SETEVENTS STREAM NEWCONSENSUS')

    def publish(self, **changes):
        if any(self.state.get(k) != v for k, v in changes.items()):
            self.state.update(changes)
            self.state['revision'] += 1
            atomic(backend.RUNTIME / 'controller-state.json', self.state)

    def directory(self):
        text = self.control.command('GETINFO ns/all')
        digest = hashlib.sha256(text.encode()).hexdigest()
        if digest != self.directory_hash:
            relays = parse_directory(text)
            addresses = sorted({r['ip'] for r in relays.values()})
            countries = {}
            for offset in range(0, len(addresses), 128):
                reply = self.control.command('GETINFO ' + ' '.join('ip-to-country/' + ip for ip in addresses[offset:offset+128]))
                for line in reply.splitlines():
                    m = re.fullmatch('ip-to-country/([^=]+)=([a-zA-Z]{2})', line)
                    if m: countries[m[1]] = m[2].upper()
            for r in relays.values(): r['country'] = countries.get(r['ip'], '')
            self.relays, self.directory_hash = relays, digest
        self.directory_at = time.monotonic()

    def eligible(self, fingerprint):
        relay = self.relays.get(fingerprint)
        return bool(relay and (not self.prefs['country'] or relay['country'] == self.prefs['country']))

    def configure(self, country):
        restriction = '{' + country.lower() + '}' if country else '""'
        self.control.command('SETCONF ExitNodes=' + restriction + ' StrictNodes=1')
        if not self.policy_matches(country):
            raise RuntimeError('Tor did not confirm the requested country policy.')
        self.publish(appliedCountry=country)

    def policy_matches(self, country):
        reply = self.control.command('GETCONF ExitNodes StrictNodes')
        values = dict(line.split('=', 1) if '=' in line else (line, '')
                      for line in reply.splitlines() if line != 'OK')
        expected = '{' + country.lower() + '}' if country else ''
        return values.get('ExitNodes', '').strip('"').lower() == expected and values.get('StrictNodes') == '1'

    def close_incompatible(self, raw, drain_partial=False):
        circuits = exit_circuits(raw)
        country = self.prefs['country']
        rejected = {cid for cid, circuit in circuits.items()
                    if country and ((len(circuit['path']) < 3 and drain_partial)
                        or (len(circuit['path']) >= 3 and not self.eligible(circuit['path'][-1])))}
        groups = {circuits[cid]['group'] for cid in rejected if circuits[cid]['group']}
        rejected.update(cid for cid, c in circuits.items() if c['group'] and c['group'] in groups)
        if not rejected:
            return raw
        self.publish(policyReady=False, verifiedCountry='', state='starting')
        if self.state['circuitId'] in rejected:
            self.publish(route=[], circuitId='')
        # CLOSECIRCUIT without IfUnused tears down existing streams as well.
        for cid in sorted(rejected):
            try:
                self.control.command('CLOSECIRCUIT ' + cid)
            except backend.ControlReplyError:
                # A previous Conflux leg closure can already have removed it.
                if cid in exit_circuits(self.control.command('GETINFO circuit-status')):
                    raise
        self.successful.difference_update(rejected)
        # Read back closure before readiness can be published.
        raw = self.control.command('GETINFO circuit-status')
        if rejected.intersection(exit_circuits(raw)):
            raise RuntimeError('Tor has not closed incompatible exit circuits.')
        self.publish(disconnectedCircuits=sorted(rejected))
        return raw

    def restore(self):
        self.publish(exitCountry=self.prefs['country'], policyReady=False, state='starting', route=[], circuitId='', verifiedCountry='')
        self.configure(self.prefs['country'])
        self.directory()
        self.close_incompatible(self.control.command('GETINFO circuit-status'), drain_partial=True)

    def tick(self):
        with (backend.DATA / 'policy.lock').open('a') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            self._tick()

    def _tick(self):
        if not self.policy_matches(self.prefs['country']):
            self.publish(policyReady=False, serviceReady=False, state='starting', route=[], circuitId='', verifiedCountry='',
                         message='Restoring the requested country policy.')
            self.configure(self.prefs['country'])
        if time.monotonic() - self.directory_at > 60: self.directory()
        if not self.bootstrapped:
            progress = re.search(r'\bPROGRESS=(\d+)', self.control.command('GETINFO status/bootstrap-phase'))
            self.bootstrapped = bool(progress and int(progress[1]) == 100)
            self.publish(progress=int(progress[1]) if progress else 0)
        has_eligible_exit = any(self.eligible(fp) for fp in self.relays)
        self.publish(serviceReady=self.bootstrapped and has_eligible_exit)
        raw = self.control.command('GETINFO circuit-status')
        raw = self.close_incompatible(raw)
        self.circuits = built_circuits(raw)
        events, self.control.events = self.control.events, []
        for event in events:
            fields = event.split()
            if fields[:1] == ['NEWCONSENSUS']: self.directory_at = 0
            if len(fields) >= 4 and fields[0] == 'STREAM' and fields[2] == 'SUCCEEDED':
                self.successful.add(fields[3])
                path = self.circuits.get(fields[3], [])
                relay = self.relays.get(path[-1], {}) if path else {}
                observation = dict(streamId=fields[1], circuitId=fields[3],
                                   exitIp=relay.get('ip', ''), country=relay.get('country', ''),
                                   requestedCountry=self.prefs['country'])
                self.stream_observations = (self.stream_observations + [observation])[-16:]
        if self.stream_observations:
            self.publish(recentStreams=self.stream_observations)
        self.successful.intersection_update(self.circuits)
        allowed = {cid:path for cid,path in self.circuits.items() if self.eligible(path[-1])}
        previous = self.state['circuitId']
        cid = previous
        if self.replacement_requested and cid in allowed:
            alternatives = [c for c in allowed if c != cid]
            different = [c for c in alternatives if allowed[c] != allowed[cid]]
            choices = different or alternatives
            if choices:
                cid = next((c for c in choices if c in self.successful), choices[0])
        if cid not in allowed:
            cid = next((c for c in allowed if c in self.successful), next(iter(allowed), ''))
        candidates = ([cid] if cid else []) + [c for c in allowed if c != cid]
        for cid in candidates:
            route = self.state['route']
            if cid != self.state['circuitId']:
                route = backend.circuit_route(self.control, cid, raw)
                for hop in route:
                    try:
                        country = self.control.command('GETINFO ip-to-country/' + hop['ip']).split('=',1)[-1].splitlines()[0].upper()
                    except (backend.ControlReplyError, IndexError):
                        route = []
                        break
                    hop.update(country=country, countryName=backend.country_names().get(country, country))
                route = backend.add_map_points(dict(route=route))['route']
            if route:
                verified = route[-1].get('country', '')
                if self.prefs['country'] and verified != self.prefs['country']:
                    continue
                if cid != previous:
                    self.replacement_requested = False
                self.publish(state='ready', policyReady=True, verifiedCountry=verified,
                             transition='stable', route=route, circuitId=cid, mapVersion=1, message='')
                return
        country_unavailable = self.bootstrapped and self.prefs['country'] and self.relays and not has_eligible_exit
        self.publish(route=[], circuitId='', policyReady=False, verifiedCountry='',
                     state='unavailable' if country_unavailable else 'starting',
                     transition='unavailable' if country_unavailable else 'building',
                     message=('No exits available under the country restriction. Choose another country or wait for directory updates.'
                              if country_unavailable else 'Waiting for Tor circuits.'))

    def request(self, action, value):
        if action in ('status', 'cached'): return self.state
        if action == 'launch-ready':
            self.tick()
            return self.state
        if action == 'observe-exit':
            address = ipaddress.ip_address(value)
            if not address.is_global:
                raise ValueError('Expected a public exit IP')
            key = 'ip-to-country/' + str(address)
            reply = self.control.command('GETINFO ' + key)
            country = next((line.split('=', 1)[1].upper() for line in reply.splitlines()
                            if line.startswith(key + '=')), '')
            if country not in backend.country_names():
                raise RuntimeError('Tor country lookup unavailable')
            return dict(api=API, ip=str(address), country=country,
                        requestedCountry=self.prefs['country'], appliedCountry=self.state['appliedCountry'])
        if action == 'set-country':
            country = backend.validate_country(value)
            with (backend.DATA / 'policy.lock').open('a') as lock:
                fcntl.flock(lock, fcntl.LOCK_EX)
                if country != self.prefs['country']:
                    self.publish(policyReady=False, serviceReady=False, verifiedCountry='', state='starting', route=[], circuitId='')
                    try:
                        self.configure(country)
                        prefs = dict(api=API, country=country)
                        atomic(backend.DATA / 'country-policy.json', prefs)
                    except (OSError, RuntimeError):
                        self.configure(self.prefs['country'])
                        raise
                    self.prefs = prefs
                    self.replacement_requested = False
                    self.publish(exitCountry=country, transition='building')
                    self.close_incompatible(self.control.command('GETINFO circuit-status'), drain_partial=True)
                self._tick()
        elif action == 'new-circuits':
            if time.time() < self.state['nextChangeAt']:
                return dict(self.state, message='Please wait before requesting fresh circuits again.')
            self.control.command('SIGNAL NEWNYM')
            self.replacement_requested = True
            self.publish(nextChangeAt=time.time()+12,
                         message='Fresh circuits requested. Tor may reuse an exit; existing connections keep their routes.')
        else:
            raise ValueError('Unknown controller action')
        return self.state


def serve():
    backend.prepare()
    lock = (backend.RUNTIME / 'controller.lock').open('a')
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    path = backend.RUNTIME / 'controller.sock'
    path.unlink(missing_ok=True)
    with socket.socket(socket.AF_UNIX, socket.SOCK_SEQPACKET) as listener:
        listener.bind(str(path)); path.chmod(0o600); listener.listen(16)
        with backend.Controller() as control:
            with (backend.DATA / 'policy.lock').open('a') as preference_lock:
                fcntl.flock(preference_lock, fcntl.LOCK_EX)
                from country_migration import migrate
                migrate(control)
                gateway = Gateway(control)
                gateway.restore()
            while True:
                gateway.tick()
                if time.time()-gateway.state.get("heartbeat", 0)>=1:
                    gateway.state["heartbeat"] = time.time()
                    atomic(backend.RUNTIME / "controller-state.json", gateway.state)
                if not select.select([listener], [], [], 0.25)[0]: continue
                connection, _ = listener.accept()
                with connection:
                    connection.settimeout(1)
                    try:
                        _, uid, _ = struct.unpack('3i', connection.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, 12))
                        if uid != os.getuid(): raise PermissionError('Controller belongs to another user')
                        request = json.loads(connection.recv(65536))
                        if request.get('api') != API: raise ValueError('Incompatible controller API')
                        reply = gateway.request(request['action'], request.get('value'))
                    except (OSError, ValueError, KeyError, TypeError, RuntimeError) as error:
                        reply = dict(api=API, error=str(error))
                    try: connection.send(json.dumps(reply).encode())
                    except OSError: pass


if __name__ == '__main__':
    serve()
