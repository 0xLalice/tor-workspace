#!/usr/bin/python3
"""Explicit administrative removal of this user's gateway resources."""
import fcntl
import json
import os
from pathlib import Path
import shutil
import subprocess


def run(*args, check=True):
    return subprocess.run(args,check=check,capture_output=True,text=True)


def remove_backend_files(code):
    names = ('session.py','client.py','setup.py','network.py','version.json',
             'backend.py','exit_controller.py','circuit_recovery.py',
             'country_migration.py','countries.geojson')
    cache = code/'__pycache__'
    for name in names:
        (code/name).unlink(missing_ok=True)
        if name.endswith('.py') and cache.is_dir() and not cache.is_symlink():
            for compiled in cache.glob(Path(name).stem+'.*.pyc'):
                compiled.unlink()
    if cache.is_dir() and not cache.is_symlink() and not any(cache.iterdir()): cache.rmdir()
    if code.exists() and not any(code.iterdir()): code.rmdir()


def main():
    if os.geteuid()!=0: raise SystemExit('Backend cleanup needs administrator authentication')
    uid=int(os.environ.get('PKEXEC_UID',os.environ.get('SUDO_UID','0')))
    if uid<1000: raise SystemExit('Invoke as the desktop user')
    enrolled=Path('/etc/omarchy-tor/users')/str(uid)
    if not enrolled.is_file(): raise SystemExit('This user is not enrolled')
    lock=open('/run/omarchy-tor-install.lock','w');fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
    ns='omarchy-tor-'+str(uid)
    units=[f'omarchy-tor-session-{uid}.socket',f'omarchy-tor-session-{uid}.service',
           f'omarchy-tor-native-{uid}.service',f'omarchy-tor-setup-{uid}.service']
    run('systemctl','disable','--now',units[0])
    run('systemctl','stop',*units[1:])
    if Path('/run/netns',ns).exists():
        pids=run('ip','netns','pids',ns).stdout.strip()
        if pids: raise SystemExit('Close remaining Tor applications before cleanup; network guard retained')
    state=Path('/run/omarchy-tor-native')/(str(uid)+'.json')
    if state.exists():
        data=json.loads(state.read_text())
        if data.get('uid')!=uid or data.get('backend')!='systemd-native-v1':
            raise SystemExit('Networking ownership mismatch; network guard retained')
    elif (Path('/run/netns',ns).exists()
          or run('ip','link','show','ot'+str(uid),check=False).returncode==0
          or run('nft','list','table','inet','omarchy_tor_'+str(uid),check=False).returncode==0):
        raise SystemExit('Networking ownership record missing; refusing existing network cleanup')
    # Remove the workload's interface before removing its firewall guard.
    if run('ip','link','show','ot'+str(uid),check=False).returncode==0:
        run('ip','link','delete','ot'+str(uid))
    if Path('/run/netns',ns).exists(): run('ip','netns','delete',ns)
    if run('nft','list','table','inet','omarchy_tor_'+str(uid),check=False).returncode==0:
        run('nft','delete','table','inet','omarchy_tor_'+str(uid))
    if shutil.which('ufw'):
        for protocol,port in (('tcp','9040'),('udp','5353')):
            run('ufw','--force','delete','allow','in','on','ot'+str(uid),'from','10.77.0.2',
                'to','10.77.0.1','port',port,'proto',protocol,check=False)
    config=Path('/etc/netns')/ns
    for name in ('resolv.conf','nsswitch.conf'): (config/name).unlink(missing_ok=True)
    if config.exists(): config.rmdir()
    for name in units: (Path('/etc/systemd/system')/name).unlink(missing_ok=True)
    run('systemctl','daemon-reload')
    enrolled.unlink();state.unlink(missing_ok=True)
    Path('/run/omarchy-tor-native',str(uid)+'.torrc').unlink(missing_ok=True)
    if not any(enrolled.parent.iterdir()):
        native=Path('/usr/lib/qt6/qml/TorSparks')
        if (native/'tor-workspace-owned').is_file():
            for name in ('qmldir','libtorsparks.so','build-info.json','tor-workspace-owned'):(native/name).unlink(missing_ok=True)
            if not any(native.iterdir()):native.rmdir()
        code=Path('/usr/local/lib/omarchy-tor')
        remove_backend_files(code)
    print('Backend removed. Private Tor state and browser profiles retained. Remove the plugin with Omarchy next.')


if __name__=='__main__': main()
