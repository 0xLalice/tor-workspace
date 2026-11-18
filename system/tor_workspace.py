#!/usr/bin/env python3
"""Network provisioning imported by the root-owned systemd setup helper.

Applications enter through client.py/session.py. Provisioning never starts Tor.
"""
import json
import os
from pathlib import Path
import pwd
import re
import subprocess
import sys

IP_CLIENT = '10.77.0.2'
IP_GATEWAY = '10.77.0.1'
UID = None
NS = None
CONFIG = None
STATE = None


def call(args, **kwargs):
    kwargs.setdefault('check', True)
    kwargs.setdefault('text', True)
    return subprocess.run([str(x) for x in args], **kwargs)


def ns(*args, **kwargs):
    return call(['/usr/bin/ip', 'netns', 'exec', NS, *args], **kwargs)


def service_name():
    return 'omarchy-tor-native-' + str(UID) + '.service'


def gateway_item():
    result = call(['/usr/bin/systemctl', 'show', service_name(),
                   '--property=ActiveState', '--property=MainPID'], capture_output=True)
    values = dict(line.split('=', 1) for line in result.stdout.splitlines() if '=' in line)
    return {'State': {'Running': values.get('ActiveState') == 'active',
                      'Pid': int(values.get('MainPID', '0'))}}


def checked_state():
    if not STATE.exists() or STATE.stat().st_uid != 0:
        raise RuntimeError('Native backend is not set up. Run the documented installer.')
    state = json.loads(STATE.read_text())
    if state.get('uid') != UID or state.get('backend') != 'systemd-native-v1':
        raise RuntimeError('Unexpected namespace owner or legacy backend; refusing reuse')
    return state


def firewall_rules(uid):
    # Host rules scope to this veth or its reserved endpoint. No masquerade,
    # forwarding switch, default-route changes, or flush-ruleset operation.
    interface = 'ot' + str(uid)
    return f'''table inet omarchy_tor_{uid} {{
 chain guard {{
  type filter hook prerouting priority -150; policy accept;
  iifname "{interface}" meta nfproto != ipv4 drop
  iifname "{interface}" ip saddr != 10.77.0.2 drop
  iifname "{interface}" udp dport 53 accept
  iifname "{interface}" ip daddr 10.192.0.0/10 meta l4proto tcp accept
  iifname "{interface}" ip daddr {{ 0.0.0.0/8, 10.0.0.0/8, 127.0.0.0/8, 169.254.0.0/16, 172.16.0.0/12, 192.168.0.0/16, 224.0.0.0/4, 240.0.0.0/4 }} drop
 }}
 chain nat_prerouting {{
  type nat hook prerouting priority dstnat; policy accept;
  iifname "{interface}" udp dport 53 redirect to :5353
  iifname "{interface}" meta nfproto ipv4 meta l4proto tcp redirect to :9040
 }}
 chain input {{
  type filter hook input priority -10; policy accept;
  iifname != "{interface}" ip daddr 10.77.0.1 drop
  iifname "{interface}" ct status dnat ip daddr 10.77.0.1 tcp dport 9040 accept
  iifname "{interface}" ct status dnat ip daddr 10.77.0.1 udp dport 5353 accept
  iifname "{interface}" reject with icmpx type admin-prohibited
 }}
 chain forward {{
  type filter hook forward priority -10; policy accept;
  iifname "{interface}" reject with icmpx type admin-prohibited
 }}
}}
'''


def tor_config(uid, country=''):
    if not isinstance(country, str) or (country and not re.fullmatch(r'[A-Z]{2}', country)):
        raise RuntimeError('Invalid exit country')
    shared = '/run/omarchy-tor-native/' + str(uid) + '-io'
    lines = [
        'ClientOnly 1', 'DataDirectory /var/lib/omarchy-tor-native-' + str(uid),
        'SocksPort unix:' + shared + '/socks',
        'ControlSocket ' + shared + '/control', 'CookieAuthentication 1',
        'CookieAuthFile ' + shared + '/cookie',
        'TransPort 10.77.0.1:9040', 'DNSPort 10.77.0.1:5353',
        'VirtualAddrNetworkIPv4 10.192.0.0/10', 'AutomapHostsOnResolve 1',
        'AutomapHostsSuffixes .onion', 'ClientRejectInternalAddresses 1',
        'ClientDNSRejectInternalAddresses 1', 'GeoIPFile /usr/share/tor/geoip',
        'AvoidDiskWrites 1', 'Log notice stdout',
    ]
    if country:
        lines.append('ExitNodes {' + country.lower() + '}')
    return '\n'.join(lines) + '\n'


def up():
    for executable in ('tor', 'ip', 'nft', 'systemctl'):
        if not Path('/usr/bin', executable).exists():
            raise RuntimeError('Missing native dependency: ' + executable)
    account = pwd.getpwuid(UID)
    interface = 'ot' + str(UID)
    ns_path = Path('/run/netns') / NS
    if STATE.exists():
        checked_state()
    else:
        # Do not adopt another namespace, interface, firewall table, or service.
        interface_exists = call(['/usr/bin/ip', 'link', 'show', interface], check=False, capture_output=True).returncode == 0
        table_exists = call(['/usr/bin/nft', 'list', 'table', 'inet', 'omarchy_tor_' + str(UID)], check=False, capture_output=True).returncode == 0
        if ns_path.exists() or interface_exists or table_exists or gateway_item()['State']['Running']:
            raise RuntimeError('Refusing to reuse unowned native networking resources')
        import ipaddress
        routes = json.loads(call(['/usr/bin/ip', '-j', '-4', 'route', 'show', 'table', 'all'], capture_output=True).stdout)
        subnet = ipaddress.ip_network('10.77.0.0/30')
        for route in routes:
            destination = route.get('dst', 'default')
            if destination != 'default' and subnet.overlaps(ipaddress.ip_network(destination, strict=False)):
                raise RuntimeError('10.77.0.0/30 conflicts with an existing host route')
        STATE.parent.mkdir(mode=0o755, parents=True, exist_ok=True)
        STATE.write_text(json.dumps({'uid': UID, 'backend': 'systemd-native-v1'}) + '\n')
        STATE.chmod(0o600)
    if not ns_path.exists():
        call(['/usr/bin/ip', 'netns', 'add', NS])
    CONFIG.mkdir(mode=0o755, parents=True, exist_ok=True)
    (CONFIG / 'resolv.conf').write_text('nameserver ' + IP_GATEWAY + '\noptions timeout:3 attempts:2\n')
    nss = re.sub(r'^hosts:.*$', 'hosts: files dns', Path('/etc/nsswitch.conf').read_text(), flags=re.MULTILINE)
    (CONFIG / 'nsswitch.conf').write_text(nss)
    ns('/usr/bin/ip', 'link', 'set', 'lo', 'up')
    ns('/usr/bin/sysctl', '-q', '-w', 'net.ipv4.ping_group_range=0 2147483647',
       'net.ipv6.conf.all.disable_ipv6=1', 'net.ipv6.conf.default.disable_ipv6=1')
    # Install the host guard BEFORE creating or enabling any external interface.
    table = 'omarchy_tor_' + str(UID)
    old = call(['/usr/bin/nft', 'list', 'table', 'inet', table], check=False, capture_output=True)
    call(['/usr/bin/nft', '-f', '-'], input=('delete table inet ' + table + '\n' if old.returncode == 0 else '') + firewall_rules(UID))
    # An accept in our nftables table cannot override UFW's later input drop.
    # Open only the two Tor listeners, on this interface and from its sole peer.
    ufw_config = Path('/etc/ufw/ufw.conf')
    if ufw_config.exists() and re.search(r'^ENABLED=yes$', ufw_config.read_text(), re.MULTILINE):
        for protocol, port in (('tcp', '9040'), ('udp', '5353')):
            call(['/usr/bin/ufw', 'allow', 'in', 'on', interface, 'from', IP_CLIENT,
                  'to', IP_GATEWAY, 'port', port, 'proto', protocol,
                  'comment', 'Omarchy Tor namespace ' + str(UID)])
    link = ns('/usr/bin/ip', 'link', 'show', 'tor0', check=False, capture_output=True)
    peer = call(['/usr/bin/ip', 'link', 'show', interface], check=False, capture_output=True)
    if link.returncode or peer.returncode:
        if link.returncode == 0:
            ns('/usr/bin/ip', 'link', 'delete', 'tor0')
        if peer.returncode == 0:
            call(['/usr/bin/ip', 'link', 'delete', interface])
        call(['/usr/bin/ip', 'link', 'add', interface, 'type', 'veth', 'peer', 'name', 'tor0', 'netns', NS])
    call(['/usr/bin/sysctl', '-q', '-w', 'net.ipv6.conf.' + interface + '.disable_ipv6=1'])
    call(['/usr/bin/ip', 'addr', 'replace', IP_GATEWAY + '/30', 'dev', interface])
    call(['/usr/bin/ip', 'link', 'set', interface, 'up'])
    ns('/usr/bin/ip', 'addr', 'replace', IP_CLIENT + '/30', 'dev', 'tor0')
    ns('/usr/bin/ip', 'link', 'set', 'tor0', 'up')
    ns('/usr/bin/ip', 'route', 'replace', 'default', 'via', IP_GATEWAY, 'dev', 'tor0')
    shared = STATE.parent / (str(UID) + '-io')
    # Reuse only a real directory, never follow a caller-controlled symlink.
    if shared.is_symlink() or (shared.exists() and not shared.is_dir()):
        raise RuntimeError('Unsafe gateway socket directory')
    shared.mkdir(mode=0o700, exist_ok=True)
    os.chown(shared, UID, account.pw_gid)
    shared.chmod(0o700)
    config_file = STATE.parent / (str(UID) + '.torrc')
    config_file.write_text(tor_config(UID))
    config_file.chmod(0o644)


if __name__ == '__main__':
    message = 'Use install/setup-session.py for setup and the widget to start Tor.'
    if sys.argv[1:] in ([], ['--help'], ['-h']):
        print(message)
    else:
        raise SystemExit('This module has no standalone actions. ' + message)
