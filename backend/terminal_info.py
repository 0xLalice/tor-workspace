#!/usr/bin/env python3
"""Tor terminal header, bounded exit observation, and local prompt notices."""
import ipaddress
import os
from pathlib import Path
import sys
sys.dont_write_bytecode = True
import json
import shutil
import subprocess
import time
from exit_controller import API, preferences, rpc
import backend


def accent():
    # Refer to Foot's palette, rather than embedding RGB in each printed cell.
    # Omarchy updates slot 4 in open terminals, including existing scrollback.
    return '\033[38;5;4m'


def render(value, colored=True):
    ink, reset = (accent(), '\033[0m') if colored else ('', '')
    artwork = (
        '████████╗ ██████╗ ██████╗',
        '╚══██╔══╝██╔═══██╗██╔══██╗',
        '   ██║   ██║   ██║██████╔╝',
        '   ██║   ██║   ██║██╔══██╗',
        '   ██║   ╚██████╔╝██║  ██║',
        '   ╚═╝    ╚═════╝ ╚═╝  ╚═╝',
    )
    lines = [''] + [ink + line + reset for line in artwork]
    lock = value.get('exitCountry', '')
    lines += ['T E R M I N A L' + (' · Requested country: ' + lock if lock else ''), '']
    return '\n'.join(lines) + '\n'


class ExitDisplay:
    """Animate the current step, leaving each completed step in scrollback."""
    def __init__(self, cancel_label="skip"):
        self.cancel_label = cancel_label
        self.last_label = ""
        self.animated = sys.stdout.isatty() and os.environ.get('TERM') != 'dumb'
        self.ink = accent() if self.animated else ''
        self.frame = 0

    def tick(self, label):
        if not self.animated:
            if label != self.last_label:
                print('  ' + label, flush=True)
                self.last_label = label
            return
        glyph = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'[self.frame % 10]
        self.frame += 1
        width = max(1, shutil.get_terminal_size().columns - 1)
        line = ('  ' + glyph + ' ' + label + ' · Ctrl+C ' + self.cancel_label)[:width]
        print('\r\033[2K' + self.ink + line + '\033[0m', end='', flush=True)

    def clear(self):
        if self.animated:
            print('\r\033[2K', end='', flush=True)

    def result_line(self, title):
        self.clear()
        reset = '\033[0m' if self.animated else ''
        print('  ' + self.ink + title + reset, flush=True)

    def complete_ip(self, address):
        self.result_line('● Exit · ' + address)
        self.frame = 0

    def finish(self, country='', message='', requested=''):
        if country:
            name = backend.country_names()[country]
            title = '● Country · ' + name
            if requested and country != requested:
                title += ' · MISMATCH: requested ' + requested
        else:
            title = '○ ' + (message or 'Country lookup unavailable')
        self.result_line(title)
        print(flush=True)


def fetch_exit_data(url, deadline, display, label):
    remaining = deadline - time.monotonic()
    if remaining <= 0:
        raise TimeoutError
    # Ignore personal curl config/proxies. Namespace routing is authoritative.
    command = ['curl', '-q', '-4', '-fsS', '--noproxy', '*', '--proto', '=https',
               '--connect-timeout', str(min(10, remaining)), '--max-time', str(remaining), '--max-filesize', '16384', url]
    with subprocess.Popen(command, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                          stderr=subprocess.DEVNULL, start_new_session=True) as process:
        try:
            while True:
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    raise TimeoutError
                display.tick(label)
                try:
                    output, _ = process.communicate(timeout=min(.08, remaining))
                    break
                except subprocess.TimeoutExpired:
                    continue
            if process.returncode:
                raise ExitLookupError(curl_failure(process.returncode))
            return output.decode('utf-8')
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()


# Two independent HTTPS services, each allowed time to build a Tor stream.
# A response is an observation of that connection, never a persistent exit ID.
EXIT_SOURCES = ('https://icanhazip.com', 'https://check.torproject.org/api/ip')
EXIT_ATTEMPT_SECONDS = 12


class ExitLookupError(ValueError):
    pass


def curl_failure(code):
    return {5: 'DNS lookup failed', 6: 'DNS lookup failed',
            7: 'connection failed', 22: 'lookup service rejected the request',
            28: 'request timed out', 35: 'TLS connection failed',
            60: 'TLS certificate verification failed',
            63: 'lookup response too large'}.get(code, 'request failed')


def parse_exit(raw, source):
    if source.endswith('/api/ip'):
        value = json.loads(raw)
        if not isinstance(value, dict) or value.get('IsTor') is not True:
            raise ExitLookupError('service did not confirm a Tor exit')
        raw = value.get('IP', '')
    try:
        address = ipaddress.ip_address(raw.strip())
    except (ValueError, AttributeError):
        raise ExitLookupError('invalid lookup response') from None
    if address.version != 4 or not address.is_global:
        raise ExitLookupError('invalid exit address')
    return str(address)


def inside_tor_terminal():
    # An environment variable alone is not evidence of network isolation.
    try:
        return bool(os.environ.get('TOR_WORKSPACE')) and os.path.samefile(
            '/proc/self/ns/net', '/run/netns/omarchy-tor-' + str(os.getuid()))
    except OSError:
        return False


def observe_exit():
    display = ExitDisplay()
    if not inside_tor_terminal():
        display.finish(message='Exit lookup requires a Tor terminal')
        return
    address = ''
    try:
        for index, source in enumerate(EXIT_SOURCES):
            label = 'Checking exit IP…' if index == 0 else 'Trying another exit lookup service…'
            try:
                raw = fetch_exit_data(source, time.monotonic() + EXIT_ATTEMPT_SECONDS, display, label)
                address = parse_exit(raw, source)
                break
            except (OSError, ValueError, TypeError, TimeoutError) as error:
                reason = ('request timed out' if isinstance(error, TimeoutError) else
                          str(error) if isinstance(error, ExitLookupError) else
                          'curl is unavailable' if isinstance(error, FileNotFoundError) else
                          'invalid lookup response' if isinstance(error, (ValueError, TypeError)) else
                          'request could not start')
                display.result_line('○ Exit check · ' + reason)
        if not address:
            display.finish(message='Exit not verified · run tor-info to retry')
            return
        display.complete_ip(address)
        display.tick('Checking exit country…')
        # Tor GeoIP is local and is also the authority used for ExitNodes.
        value = rpc('observe-exit', address, timeout=4)
        if (not isinstance(value, dict) or value.get('ip') != address
                or value.get('country') not in backend.country_names()):
            raise ValueError('Invalid country response')
        requested = value.get('requestedCountry', '')
        if requested and requested not in backend.country_names():
            raise ValueError('Invalid requested country')
        display.finish(value['country'], requested=requested)
    except KeyboardInterrupt:
        display.finish(message=('Country lookup skipped' if address else 'Exit lookup skipped') + ' · run tor-info to retry')
    except (OSError, ValueError, TypeError, RuntimeError, TimeoutError):
        display.finish(message='Country not verified · local Tor lookup unavailable · run tor-info to retry')


def status_line(value):
    active = value.get('running') and value.get('state') == 'ready'
    label = 'Traffic routed through Tor' if active else 'Tor routing unavailable'
    country = value.get('exitCountry', '')
    if country:
        name = backend.country_names().get(country, country)
        label += ' · Requested country: ' + name
    return label


def local_state():
    value = {}
    try:
        value = json.loads((backend.RUNTIME / 'controller-state.json').read_text())
        if (value.get('api') != API or value.get('gatewayGeneration') != backend.gateway_generation()
                or not 0 <= time.time()-value.get('heartbeat', 0) <= 5):
            value = dict(value, running=False)
    except (OSError, ValueError, TypeError):
        value = dict(value, running=False)
    try:
        value['exitCountry'] = preferences()['country']
    except (OSError, ValueError, RuntimeError, KeyError):
        value = dict(value, running=False)
    return value


def notice_key(value):
    return value.get('exitCountry', '')


def main():
    if '--accent' in sys.argv:
        print(accent(), end=''); return
    marker = os.environ.get('TOR_TERMINAL_READY')
    notice = Path(marker + '.notice') if marker else None
    if '--notice' in sys.argv:
        if notice is None: return
        value = local_state()
        key = notice_key(value)
        try: previous = json.loads(notice.read_text())
        except (OSError, ValueError): previous = key
        if previous != key:
            print('Tor country restriction changed · ' + status_line(value))
        notice.write_text(json.dumps(key)); notice.chmod(0o600)
        return
    if '--startup' in sys.argv and marker:
        Path(marker).touch(mode=0o600)
    value = local_state()
    if notice:
        notice.write_text(json.dumps(notice_key(value))); notice.chmod(0o600)
    if '--startup' in sys.argv and not os.environ.get('TOR_TERMINAL_HEADER_SHOWN'):
        print(render(value, sys.stdout.isatty()), end='', flush=True)
    observe_exit()


if __name__ == '__main__':
    main()
