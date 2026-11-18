#!/usr/bin/python3
"""One authenticated installation of root-owned code and per-user activation units."""
import os
import json
import fcntl
import signal
import select
from pathlib import Path
import pwd
import shutil
import subprocess


def unit_text(uid,gid,home):
    name=str(uid)
    network='omarchy-tor-setup-'+name+'.service'
    tor='omarchy-tor-native-'+name+'.service'
    session='omarchy-tor-session-'+name
    # Paths with systemd syntax characters are refused by installer below.
    return {
      network:f'''[Unit]
Description=Tor workspace network for UID {uid}
Before={tor} {session}.service
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/python3 -I /usr/local/lib/omarchy-tor/setup.py {uid}
''',
      tor:f'''[Unit]
Description=Native Tor gateway for UID {uid}
Requires={network}
After={network} network-online.target
Wants=network-online.target
[Service]
Type=exec
User={uid}
Group={gid}
ExecStart=/usr/bin/tor -f /run/omarchy-tor-native/{uid}.torrc
StateDirectory=omarchy-tor-native-{uid}
StateDirectoryMode=0700
NoNewPrivileges=yes
CapabilityBoundingSet=
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
ReadWritePaths=/run/omarchy-tor-native/{uid}-io
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
UMask=0077
''',
      session+'.socket':f'''[Unit]
Description=Password-free Tor application launcher for UID {uid}
[Socket]
ListenSequentialPacket=/run/{session}/launch.sock
SocketUser={uid}
SocketGroup={gid}
SocketMode=0600
DirectoryMode=0755
RemoveOnStop=yes
[Install]
WantedBy=sockets.target
''',
      session+'.service':f'''[Unit]
Description=Unprivileged isolated Tor app launcher for UID {uid}
Requires={network} {tor}
After={network} {tor}
BindsTo={tor}
[Service]
Type=exec
User={uid}
Group={gid}
ExecStart=/usr/bin/python3 -I /usr/local/lib/omarchy-tor/session.py
NetworkNamespacePath=/run/netns/omarchy-tor-{uid}
# Keep resolved's symlink targets private. Host resolver file replacement must
# not remove the terminal's DNS override after a network change or resume.
TemporaryFileSystem=/run/systemd/resolve:ro
BindReadOnlyPaths=/etc/netns/omarchy-tor-{uid}/resolv.conf:/run/systemd/resolve/stub-resolv.conf
BindReadOnlyPaths=/etc/netns/omarchy-tor-{uid}/resolv.conf:/run/systemd/resolve/resolv.conf
BindReadOnlyPaths=/etc/netns/omarchy-tor-{uid}/resolv.conf:/etc/resolv.conf
BindReadOnlyPaths=/etc/netns/omarchy-tor-{uid}/nsswitch.conf:/etc/nsswitch.conf
NoNewPrivileges=yes
CapabilityBoundingSet=
UMask=0077
'''}


def pause_supervisor(uid):
    """Stop only this project's supervisor/controller, retaining app handlers.

    A temporary systemd override is removed before installation returns. Tor,
    its namespace/firewall and application processes are never restarted.
    """
    unit = f'omarchy-tor-session-{uid}.service'
    active = subprocess.run(['systemctl', 'is-active', '--quiet', unit]).returncode == 0
    if not active:
        return False
    main_pid = int(subprocess.check_output(['systemctl', 'show', '-p', 'MainPID', '--value', unit], text=True))
    controllers = []
    for process in Path('/proc').glob('[0-9]*'):
        try:
            arguments = (process/'cmdline').read_bytes().split(b'\0')
            parent = int((process/'stat').read_text().rsplit(')', 1)[1].split()[1])
            if parent == main_pid and process.stat().st_uid == uid and b'/usr/local/lib/omarchy-tor/exit_controller.py' in arguments:
                controllers.append(os.pidfd_open(int(process.name)))
        except (OSError, ValueError):
            continue
    override = Path('/run/systemd/system') / (unit+'.d') / '90-tor-controller-upgrade.conf'
    if override.exists():
        raise RuntimeError('An unfinished controller upgrade needs inspection: '+str(override))
    override.parent.mkdir(parents=True, exist_ok=True)
    override.write_text('[Service]\nKillMode=process\n')
    try:
        subprocess.run(['systemctl', 'daemon-reload'], check=True)
        subprocess.run(['systemctl', 'stop', unit], check=True)
        for descriptor in controllers:
            try: signal.pidfd_send_signal(descriptor, signal.SIGTERM)
            except ProcessLookupError: pass
        for descriptor in controllers:
            if not select.select([descriptor], [], [], 5)[0]:
                raise RuntimeError('Old controller did not stop')
    finally:
        for descriptor in controllers: os.close(descriptor)
        override.unlink()
        subprocess.run(['systemctl', 'daemon-reload'], check=True)
    return True


def main():
    if os.geteuid()!=0:
        raise SystemExit('Run installer once with administrator authentication')
    # The authentication terminal deliberately uses 077 for its private result.
    # Installed code, metadata and parent directories must remain user-readable.
    os.umask(0o022)
    uid=int(os.environ.get('PKEXEC_UID',os.environ.get('SUDO_UID','0')))
    if uid<1000: raise SystemExit('Invoke as the desktop user')
    account=pwd.getpwuid(uid)
    if any(c in account.pw_dir for c in '\n\r%\\ '):
        raise SystemExit('Unsupported home path')
    lock=open('/run/omarchy-tor-install.lock','w')
    fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
    print('Checking system dependencies',flush=True)
    requirements={'/usr/bin/gpg':'gnupg','/usr/bin/curl':'curl','/usr/share/iso-codes/json/iso_3166-1.json':'iso-codes','/usr/bin/tor':'tor','/usr/bin/ip':'iproute2','/usr/bin/nft':'nftables','/usr/bin/foot':'foot','/usr/bin/onionshare-cli':'onionshare'}
    missing=[package for file,package in requirements.items() if not Path(file).exists()]
    if missing:
        raise SystemExit('Missing runtime packages: '+', '.join(missing)+'. Run omarchy pkg add '+ ' '.join(missing)+' as the desktop user, then retry this installer.')
    source=Path(__file__).resolve().parent
    destination=Path('/usr/local/lib/omarchy-tor')
    destination.mkdir(parents=True,exist_ok=True,mode=0o755)
    if destination.is_symlink() or destination.stat().st_uid!=0:
        raise SystemExit('Unsafe installation destination')
    resume_session = pause_supervisor(uid)
    (destination/'version.json').unlink(missing_ok=True)
    print('Installing gateway code and activation units',flush=True)
    for name in ('session.py','client.py','setup.py'):
        target=destination/name
        if target.is_symlink(): raise SystemExit('Unsafe installation file')
        shutil.copyfile(source/name,target);os.chown(target,0,0);target.chmod(0o644)
    runtime_source = source.parent/'backend'
    for name in ('backend.py', 'exit_controller.py', 'circuit_recovery.py', 'country_migration.py', 'countries.geojson'):
        target = destination/name
        if target.is_symlink(): raise SystemExit('Unsafe controller destination')
        shutil.copyfile(source.parent/'assets/maps'/name if name=='countries.geojson' else runtime_source/name, target)
        os.chown(target, 0, 0); target.chmod(0o644)
    if (destination/'network.py').is_symlink(): raise SystemExit('Unsafe network file')
    shutil.copyfile(source/'tor_workspace.py',destination/'network.py')
    os.chown(destination/'network.py',0,0);(destination/'network.py').chmod(0o644)
    enrollment=Path('/etc/omarchy-tor/users');enrollment.mkdir(parents=True,exist_ok=True,mode=0o755)
    (enrollment/str(uid)).write_text(account.pw_name+'\n')
    units=unit_text(uid,account.pw_gid,account.pw_dir)
    for name,text in units.items():
        path=Path('/etc/systemd/system')/name
        if path.is_symlink(): raise SystemExit('Refusing symlink unit '+name)
        path.write_text(text);path.chmod(0o644)
    subprocess.run(['systemd-analyze','verify',*[str(Path('/etc/systemd/system')/n) for n in units]],check=True)
    subprocess.run(['systemctl','daemon-reload'],check=True)
    subprocess.run(['systemctl','enable','--now','omarchy-tor-session-'+str(uid)+'.socket'],check=True)
    if resume_session:
        subprocess.run(['systemctl', 'start', f'omarchy-tor-session-{uid}.service'], check=True)
    # Enable only the idle launcher socket. Tor starts on an explicit user request.
    (destination/'version.json').write_text(json.dumps({'api':3,'version':'0.12.0'})+'\n')
    (destination/'version.json').chmod(0o644)
    print('Installed root-owned native setup and password-free session socket for UID',uid)


if __name__=='__main__': main()
