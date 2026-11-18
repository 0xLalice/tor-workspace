#!/usr/bin/env python3
"""Controller for the shared workspace Tor gateway."""
import fcntl
import ipaddress
import json
import os
from pathlib import Path
import re
import socket
import subprocess
import sys
import time

RUNTIME = Path(os.environ.get('XDG_RUNTIME_DIR', '/run/user/' + str(os.getuid()))) / 'omarchy-tor-panel'
DATA = Path(os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state'))) / 'omarchy/tor-panel'
GATEWAY = Path('/run/omarchy-tor-native') / (str(os.getuid()) + '-io')


def prepare():
    for path in (RUNTIME, DATA):
        path.mkdir(parents=True, exist_ok=True, mode=0o700)
        path.chmod(0o700)


class ControlReplyError(RuntimeError):
    """Tor replied with an error; the control connection is still usable."""


class Controller:
    def __enter__(self):
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.settimeout(4)
        try:
            self.sock.connect(str(GATEWAY / 'control'))
            self.stream = self.sock.makefile('rwb', buffering=0)
            self.events = []
            self.command('AUTHENTICATE ' + (GATEWAY / 'cookie').read_bytes().hex())
        except BaseException:
            if hasattr(self,'stream'):self.stream.close()
            self.sock.close()
            raise
        return self

    def command(self, message):
        self.stream.write((message + '\r\n').encode())
        lines = []
        while True:
            line = self.readline()
            # Asynchronous Tor events can arrive between command replies.
            if line.startswith(('650 ', '650-', '650+')):
                self.events.append(line[4:])
                if line[3:4] == '+':
                    while self.readline() != '.':
                        pass
                continue
            if not line.startswith('250') or len(line) < 4:
                raise ControlReplyError('Tor rejected the control request')
            payload = line[4:]
            # GETINFO uses key=value for a single circuit, but a data block
            # for multiple circuits. Give every circuit reader the same rows;
            # otherwise the lone circuit's ID becomes "circuit-status=33".
            status_key = message.removeprefix('GETINFO ') + '='
            if message in ('GETINFO circuit-status', 'GETINFO stream-status') and payload.startswith(status_key):
                lines.append(status_key)
                if payload[len(status_key):]:
                    lines.append(payload[len(status_key):])
            else:
                lines.append(payload)
            if line[3:4] == '+':
                while True:
                    data = self.readline()
                    if data == '.':
                        break
                    lines.append(data[1:] if data.startswith('..') else data)
            if line[3:4] == ' ':
                return '\n'.join(lines)

    def readline(self):
        raw = self.stream.readline(65536)
        if not raw:
            raise RuntimeError('Tor control connection closed')
        return raw.decode().rstrip('\r\n')

    def __exit__(self, *_):
        self.stream.close()
        self.sock.close()


def query_origin():
    """Discover the normal connection separately; never substitute it for Tor."""
    origin = {'role': 'You', 'name': 'Clearnet origin', 'ip': '', 'country': '',
              'countryName': 'Unknown'}
    try:
        result = subprocess.run([
            '/usr/bin/curl', '-q', '--noproxy', '*', '--proto', '=https',
            '--fail', '--silent', '--show-error', '--connect-timeout', '5',
            '--max-time', '8', 'https://api.country.is/',
        ], capture_output=True, text=True, timeout=10)
        if result.returncode:
            return origin
        address = str(ipaddress.ip_address(json.loads(result.stdout).get('ip', '')))
        # As with every relay, country attribution uses the explicit-IP URL.
        country = query_country(address)
        origin.update(ip=address, country=country,
                      countryName=country_names().get(country, country or 'Unknown'))
    except (OSError, ValueError, TypeError, AttributeError, subprocess.SubprocessError):
        pass
    return origin


def add_map_points(value):
    """Use country label points, not invented precise relay coordinates."""
    try:
        features = json.loads((Path(__file__).with_name('countries.geojson') if Path(__file__).with_name('countries.geojson').exists() else Path(__file__).resolve().parents[1]/'assets/maps/countries.geojson').read_text())['features']
        points = {f['properties']['code']: f['properties']['label_point']
                  for f in features if f['properties'].get('code')}
    except (OSError, ValueError, KeyError, TypeError):
        points = {}
    for hop in [value.get('origin', {})] + value.get('route', []):
        hop.pop('longitude', None)
        hop.pop('latitude', None)
        point = points.get(hop.get('country'))
        if point:
            hop.update(longitude=point[0], latitude=point[1])
    value['mapVersion'] = 1
    return value


def query_country(address):
    # The country lookup is the user's explicit-IP command on the normal
    # connection. It does not discover the IP or change application routing.
    address = str(ipaddress.ip_address(address))
    try:
        result = subprocess.run([
            '/usr/bin/curl', '-q', '--noproxy', '*', '--proto', '=https',
            '--fail', '--silent', '--show-error', '--connect-timeout', '5',
            '--max-time', '8', 'https://api.country.is/' + address,
        ], capture_output=True, text=True, timeout=10)
        if result.returncode:
            return ''
        payload = json.loads(result.stdout)
        if str(ipaddress.ip_address(payload.get('ip', ''))) != address:
            return ''
        country = payload.get('country', '')
        return country if isinstance(country, str) and re.fullmatch(r'[A-Z]{2}', country) else ''
    except (OSError, ValueError, TypeError, AttributeError, subprocess.SubprocessError):
        return ''


def circuit_route(control, circuit_id, circuits):
    if not circuit_id:
        return []
    circuit = next((line.split() for line in circuits.splitlines()
                    if line.startswith(circuit_id + ' BUILT ')), None)
    if not circuit or len(circuit) < 3 or not circuit[2].startswith('$'):
        return []
    nodes = circuit[2].split(',')
    route = []
    for index, node in enumerate(nodes):
        fingerprint = re.split(r'[~=]', node)[0].lstrip('$')
        if not re.fullmatch(r'[A-Fa-f0-9]{40}', fingerprint):
            return []
        try:
            status = control.command('GETINFO ns/id/' + fingerprint)
        except ControlReplyError:
            # A built circuit can outlive a relay's consensus record. It is
            # usable by Tor but cannot currently be represented on our map.
            return []
        router = next((line.split() for line in status.splitlines() if line.startswith('r ')), None)
        if router is None or len(router) < 9:
            return []
        try:
            address = str(ipaddress.ip_address(router[6]))
        except ValueError:
            return []
        route.append({
            'role': 'Guard' if index == 0 else 'Exit' if index == len(nodes) - 1 else 'Middle',
            'name': router[1], 'ip': address,
            'fingerprint': fingerprint,
        })
    return route


def country_names():
    try:
        data = json.loads(Path('/usr/share/iso-codes/json/iso_3166-1.json').read_text())
        return {item['alpha_2']: item.get('common_name', item['name']) for item in data['3166-1']}
    except (OSError, ValueError, KeyError, TypeError):
        return {}


def exit_countries():
    """Count public running exits from Tor's local directory and GeoIP data."""
    try:
        with Controller() as control:
            directory = control.command('GETINFO ns/all')
            relays = {}
            identity = address = None
            for line in directory.splitlines():
                fields = line.split()
                if fields[:1] == ['r']:
                    identity = address = None
                    if len(fields) >= 8:
                        identity = fields[2]
                        address = str(ipaddress.ip_address(fields[-3]))
                elif fields[:1] == ['s'] and identity:
                    flags = set(fields[1:])
                    if {'Exit', 'Running', 'Valid'} <= flags and 'BadExit' not in flags:
                        relays[identity] = address
            addresses = sorted(set(relays.values()))
            countries = {}
            for offset in range(0, len(addresses), 128):
                reply = control.command('GETINFO ' + ' '.join(
                    'ip-to-country/' + address for address in addresses[offset:offset + 128]))
                for line in reply.splitlines():
                    match = re.fullmatch(r'ip-to-country/([^=]+)=([a-zA-Z]{2})', line)
                    if match:
                        countries[match[1]] = match[2].upper()
            counts = {}
            names = country_names()
            for address in relays.values():
                code = countries.get(address)
                if code in names:
                    counts[code] = counts.get(code, 0) + 1
            total = len(relays)
            return [{'code': '', 'name': f'Any country ({total:,} exits)', 'count': total}] + [
                {'code': code, 'name': f'{names[code]} ({count:,} ' + ('exit)' if count == 1 else 'exits)'),
                 'count': count}
                for code, count in sorted(counts.items(), key=lambda item: (-item[1], names[item[0]]))]
    except (OSError, ValueError, RuntimeError):
        return [{'code': '', 'name': 'Any country (directory unavailable)', 'count': None}] + [
            dict(code=code, name=name+' (availability unknown)', count=None)
            for code, name in sorted(country_names().items(), key=lambda item: item[1])]


def validate_country(country):
    if not isinstance(country, str) or (country and (not re.fullmatch(r'[A-Z]{2}', country) or country not in country_names())):
        raise ValueError('Choose a valid exit country')
    return country


def offline():
    from exit_controller import API, preferences
    try:
        country = preferences()['country']
    except FileNotFoundError:
        country = ''
    return dict(api=API, state='offline', running=False, route=[], exitCountry=country, message='Tor is off.')


def gateway_generation():
    stat=(GATEWAY/'control').stat()
    return f'{stat.st_ino}:{stat.st_ctime_ns}'


def host_network():
    # The launcher/controller runs in Tor's namespace. Probing there would
    # mistake an exit address for the user's normal connection.
    try:
        return not os.path.samefile('/proc/self/ns/net', '/run/netns/omarchy-tor-' + str(os.getuid()))
    except OSError:
        return False


def origin_observation():
    try:
        value = json.loads((RUNTIME / 'origin.json').read_text())
        return value if isinstance(value, dict) else {}
    except (OSError, ValueError):
        return {}


def refresh_origin():
    """Bounded host-only observation; never starts or changes Tor."""
    if not host_network() or not (GATEWAY / 'control').exists():
        return
    prepare()
    from exit_controller import atomic
    with (RUNTIME / 'origin.lock').open('a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        now = time.time()
        previous = origin_observation()
        if previous.get('retryAfter', 0) > now:
            return
        keep = previous.get('state') == 'ready' and now - previous.get('retryAfter', 0) < 30
        atomic(RUNTIME / 'origin.json', dict(state='ready' if keep else 'checking',
               origin=previous.get('origin', {}) if keep else {}, retryAfter=now + 30))
        origin = query_origin()
        mapped = add_map_points(dict(origin=origin))['origin']
        ready = 'longitude' in mapped and 'latitude' in mapped
        atomic(RUNTIME / 'origin.json', dict(state='ready' if ready else 'unavailable',
               origin=mapped, retryAfter=time.time() + (300 if ready else 30)))


def with_origin(value):
    if not value.get('running'):
        return dict(value, origin={}, originState='offline')
    observation = origin_observation()
    stale = observation.get('retryAfter', 0) <= time.time()
    if stale and host_network():
        subprocess.Popen([sys.executable, '-B', str(Path(__file__).resolve()), 'refresh-origin'],
                         stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL, start_new_session=True)
    expired = time.time() - observation.get('retryAfter', 0) >= 30
    return dict(value, origin=observation.get('origin', {}) if not expired else {},
                originState=observation.get('state', 'checking') if not expired else 'checking')


def request(action, country=None):
    from exit_controller import client
    previous = client('cached') if action == 'new-circuits' else {}
    value = client(action, country)
    # Observing an idle Tor must not continually manufacture unused circuits.
    # Only explicit route/country requests and application launches create demand.
    if action in ('set-country', 'new-circuits') or (action == 'status' and value.get('state') == 'ready'):
        from circuit_recovery import recover
        accepted = action == 'new-circuits' and value.get('nextChangeAt', 0) > previous.get('nextChangeAt', 0)
        # Ready status only clears completed recovery bookkeeping. recover()
        # returns before any control command in this case.
        value = recover(value, refresh=accepted)
    value = with_origin(value)
    if action in ('status','cached') and value.get('running'):
        from local_circuits import snapshot
        value['localCircuits']=snapshot()
    return value


if __name__ == '__main__':
    action = sys.argv[1] if len(sys.argv) > 1 else 'status'
    try:
        if action == 'refresh-origin':
            refresh_origin()
        elif action == 'countries':
            print(json.dumps(exit_countries()))
        elif action in ('cached', 'status', 'new-circuits', 'set-country'):
            print(json.dumps(request(action, sys.argv[2] if len(sys.argv) > 2 else None)))
        else:
            raise ValueError('Unknown action')
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(json.dumps(dict(state='error',route=[],running=False,
                              message=str(error))))
        sys.exit(1)
