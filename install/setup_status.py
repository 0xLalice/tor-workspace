#!/usr/bin/env python3
"""Read-only readiness gate; safe to run before dependencies or renderers exist."""
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
BACKEND_API = 3
MIN_TOR_VERSION = (0, 4, 9, 14)
REQUIRED = ('tor', 'ip', 'nft', 'foot', 'curl', 'gpg', 'onionshare-cli')
RUNTIME_PACKAGES = dict(zip(REQUIRED, ('tor', 'iproute2', 'nftables', 'foot', 'curl', 'gnupg', 'onionshare')))
BUILD_TOOLS = {'cmake':'cmake', 'c++':'gcc', 'make':'make', '/usr/lib/qt6/bin/qsb':'qt6-shadertools'}
MODULES = {'circuit':'libtorcircuit.so', 'gpu':'libtorsparks.so', 'performance':'libtorperformance.so'}


def tor_version_status():
    minimum = '.'.join(map(str, MIN_TOR_VERSION))
    try:
        output = subprocess.check_output(['tor', '--version'], text=True,
                                         stderr=subprocess.DEVNULL, timeout=5)
        match = re.search(r'\bTor version (\d+\.\d+\.\d+\.\d+)(?:\.|\s|$)', output)
        if not match: raise ValueError('Unrecognized Tor version')
        version = match.group(1)
    except (OSError, ValueError, subprocess.SubprocessError):
        return '', 'Could not verify Tor version. Tor '+minimum+' or newer is required.'
    if tuple(map(int, version.split('.'))) < MIN_TOR_VERSION:
        return version, 'Update Tor to '+minimum+' or newer for reliable onion sharing (installed: '+version+').'
    return version, ''


def native_source_hash(root=ROOT):
    """Bind local binaries to all native sources as well as the local Qt ABI."""
    native = root/'native'
    files = [native/name for name in ('CMakeLists.txt', 'build-info.json.in',
             'circuit/circuit.cpp', 'performance/frameprobe.cpp')]
    files += [native/'gpu'/name for name in ('Sparks.cpp', 'sparks.vert', 'sparks.frag')]
    digest = hashlib.sha256()
    for path in files: digest.update(hashlib.sha256(path.read_bytes()).digest())
    return digest.hexdigest()


def native_issues(root=ROOT, qt=None, architecture=None):
    if qt is None:
        try: qt = subprocess.check_output(['pacman','-Q','qt6-base'], text=True, stderr=subprocess.DEVNULL, timeout=5).split()[1].split('-')[0]
        except (OSError, ValueError, IndexError, subprocess.SubprocessError): qt = ''
    architecture = architecture or platform.machine()
    issues = []
    try: source_hash = native_source_hash(root)
    except OSError: source_hash = ''
    for module, binary in MODULES.items():
        try:
            build = json.loads((root/'build/qml'/module/'build-info.json').read_text())
            compatible = (root/'build/qml'/module/binary).is_file() and build['api']==1 and build['architecture']==architecture and bool(qt) and build['qt'].split('.')[:2]==qt.split('.')[:2] and bool(source_hash) and build.get('sources')==source_hash
        except (OSError, ValueError, KeyError, TypeError, AttributeError): compatible = False
        if not compatible: issues.append('Build or rebuild the '+module+' renderer for this Qt version and architecture.')
    return issues


def status(root=ROOT, system=Path('/'), home=None, uid=None):
    home = home or Path.home()
    uid = os.getuid() if uid is None else uid
    missing = [name for name in REQUIRED if not shutil.which(name)]
    issues = ['Missing packages: '+', '.join(missing)] if missing else []
    tor_version = ''
    if 'tor' not in missing:
        tor_version, tor_issue = tor_version_status()
        if tor_issue: issues.append(tor_issue)
    if not (system/'usr/share/iso-codes/json/iso_3166-1.json').is_file():
        issues.append('Install the iso-codes package.')
    native = native_issues(root)
    build_missing = sorted({package for tool, package in BUILD_TOOLS.items() if not shutil.which(tool)})
    for package in ('qt6-base', 'qt6-declarative'):
        try:
            present = subprocess.run(['pacman', '-Q', package], timeout=5, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0
        except (OSError, subprocess.SubprocessError): present = False
        if not present: build_missing.append(package)
    # Build tools are only a setup requirement while renderers need rebuilding.
    if native and build_missing: issues.append('Missing build prerequisites: '+', '.join(build_missing))
    issues.extend(native)
    installed_dir = system/'usr/local/lib/omarchy-tor'
    try: installed = json.loads((installed_dir/'version.json').read_text()).get('api')
    except (OSError, ValueError, AttributeError): installed = None
    compatible = installed == BACKEND_API
    # API compatibility alone cannot detect stale installed controllers after an update.
    sources = {'system/session.py':'session.py','system/client.py':'client.py','system/setup.py':'setup.py',
               'system/tor_workspace.py':'network.py','backend/backend.py':'backend.py','backend/exit_controller.py':'exit_controller.py',
               'backend/circuit_recovery.py':'circuit_recovery.py','backend/country_migration.py':'country_migration.py','assets/maps/countries.geojson':'countries.geojson'}
    try:
        current = all(hashlib.sha256((root/src).read_bytes()).digest()==hashlib.sha256((installed_dir/dst).read_bytes()).digest() for src,dst in sources.items())
    except OSError: current = False
    try:
        unit = (system/'etc/systemd/system'/f'omarchy-tor-session-{uid}.service').read_text()
        resolver_current = ('TemporaryFileSystem=/run/systemd/resolve:ro' in unit and all(
            f'BindReadOnlyPaths=/etc/netns/omarchy-tor-{uid}/resolv.conf:{target}' in unit
            for target in ('/etc/resolv.conf', '/run/systemd/resolve/stub-resolv.conf', '/run/systemd/resolve/resolv.conf')))
    except OSError: resolver_current = False
    current = current and resolver_current
    if not compatible or not current: issues.append('Install or update the system backend.')
    enrolled = (system/'etc/omarchy-tor/users'/str(uid)).is_file()
    if not enrolled: issues.append('Enroll this desktop user in the Tor launcher.')
    browser = (home/'.local/share/omarchy-tor/tor-browser/Browser/firefox').is_file()
    if not browser: issues.append('Install the signature-verified Tor Browser.')
    config = Path(os.environ.get('XDG_CONFIG_HOME', home/'.config'))
    try: workspace = 'tor.workspace/integration/workspace.lua' in (config/'hypr/hyprland.lua').read_text()
    except OSError: workspace = False
    if not workspace: issues.append('Register the Tor workspace in Hyprland.')
    try:
        socket_ready = subprocess.run(['systemctl','is-active','--quiet',f'omarchy-tor-session-{uid}.socket'], timeout=5, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0
    except (OSError, subprocess.SubprocessError): socket_ready = False
    if not socket_ready: issues.append('Enable the Tor application launcher socket.')
    return dict(schema=1, pythonAvailable=True, ready=not issues, issues=issues, missing=missing,
                missingRuntimePackages=[RUNTIME_PACKAGES[name] for name in missing]+([] if (system/'usr/share/iso-codes/json/iso_3166-1.json').is_file() else ['iso-codes']),
                missingBuildPackages=build_missing, buildRequired=bool(native),
                backendCompatible=compatible, backendCurrent=current, backendApi=installed,
                requiredApi=BACKEND_API, nativeReady=not native, enrolled=enrolled,
                browserReady=browser, workspaceReady=workspace,
                socketReady=socket_ready, torVersion=tor_version,
                minimumTorVersion='.'.join(map(str, MIN_TOR_VERSION)))


if __name__ == '__main__':
    print(json.dumps(status()))
