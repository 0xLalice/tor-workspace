"""Read-only test-stream attribution and illustrative country distances."""
import json
import math
from pathlib import Path
import re
import shlex
import threading
import time
import uuid


def country(value):
    return value if isinstance(value, str) and re.fullmatch('[A-Z]{2}', value) else ''


def geography():
    data = json.loads((Path(__file__).resolve().parents[1]/'assets/maps/speed-geography.json').read_text())
    return data['countries'], data['airports']


def describe(countries, points):
    countries = [country(c) for c in countries]
    value = {'countries': [c or '?' for c in countries]}
    if not countries or any(c not in points for c in countries):
        return value
    if len(set(countries)) == 1:
        return dict(value, sameCountry=True)
    distance = 0
    for first, second in zip(countries, countries[1:]):
        lon1, lat1 = map(math.radians, points[first])
        lon2, lat2 = map(math.radians, points[second])
        a = math.sin((lat2-lat1)/2)**2 + math.cos(lat1)*math.cos(lat2)*math.sin((lon2-lon1)/2)**2
        distance += 6371.0088 * 2 * math.asin(math.sqrt(min(1, max(0, a))))
    return dict(value, roundTripKm=max(100, round(distance * 2 / 100) * 100))


def endpoint(headers, airports):
    codes = re.findall(r'^cf-ray:\s*[^\r\n]*-([A-Z]{3})\s*$', headers, re.I | re.M)
    return airports.get(codes[-1].upper(), '') if codes else ''


class CircuitWatch:
    """Subscribe before curl starts. A unique SOCKS tag identifies only this test."""
    def __init__(self):
        self.tag = 'speed-' + uuid.uuid4().hex
        self.done = threading.Event()
        self.ready = threading.Event()
        self.data = {}
        self.stream_id = None
        self.circuit_id = None
        self.closed = False
        self.last_refresh = 0
        self.country_cache = {}
        self.thread = threading.Thread(target=self.listen, daemon=True)

    def start(self):
        self.thread.start()
        self.ready.wait(1)

    def close(self):
        self.done.set()
        self.thread.join(timeout=1)

    def event(self, line, control):
        fields = shlex.split(line)
        if len(fields) < 5 or fields[0] != 'STREAM': return
        options = dict(f.split('=', 1) for f in fields[5:] if '=' in f)
        if options.get('SOCKS_USERNAME') == self.tag:
            self.stream_id = fields[1]
        if fields[1] != self.stream_id: return
        status, cid = fields[2:4]
        if status in ('DETACHED', 'FAILED'):
            self.circuit_id = None; self.data = {}; return
        if status == 'CLOSED': self.closed = True; return
        if status not in ('SENTCONNECT', 'SUCCEEDED') or cid == '0': return
        self.circuit_id = cid
        self.resolve(control)

    def resolve(self, control):
        import backend
        cid = self.circuit_id
        circuits = control.command('GETINFO circuit-status')
        selected = next((l for l in circuits.splitlines() if l.startswith(cid + ' ')), '')
        bundle = re.search(r'CONFLUX_ID=([A-Fa-f0-9]+)', selected)
        ids = [cid]
        if bundle:
            ids = [l.split()[0] for l in circuits.splitlines()
                   if ' BUILT ' in l and re.search(r'(?:^|\s)CONFLUX_ID='+re.escape(bundle[1])+r'(?:\s|$)',l)]
        paths = []
        exits = []
        for circuit in ids:
            route = backend.circuit_route(control, circuit, circuits)
            countries = []
            for hop in route:
                address = hop['ip']
                if address not in self.country_cache:
                    reply = control.command('GETINFO ip-to-country/' + address)
                    match = re.search(r'ip-to-country/[^=]+=([a-zA-Z]{2})', reply)
                    self.country_cache[address] = country(match[1].upper()) if match else ''
                countries.append(self.country_cache[address])
            if not route:
                self.data = {}; return
            paths.append(countries)
            exits.append(route[-1].get("fingerprint", ""))
        self.data = {'circuitId': cid, 'circuitIds': ids, 'relayPaths': paths, 'multipath': bool(bundle), 'sharedExitConfirmed': bool(bundle) and len(exits)>1 and all(exits) and len(set(exits))==1} if paths else {}
        self.last_refresh = time.monotonic()

    def listen(self):
        try:
            import backend
            with backend.Controller() as control:
                control.sock.settimeout(.5)
                control.command('SETEVENTS STREAM')
                self.ready.set()
                while not self.done.is_set():
                    control.command('GETINFO version')
                    pending, control.events = control.events, []
                    for event in pending:
                        self.event(event, control)
                    if self.circuit_id and not self.closed and time.monotonic() - self.last_refresh >= 1:
                        self.resolve(control)
                    self.done.wait(.1)
        except (OSError, RuntimeError, ValueError):
            self.data = {}  # Attribution failure must never prevent or redirect the download.
        finally:
            self.ready.set()
