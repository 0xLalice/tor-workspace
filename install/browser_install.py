#!/usr/bin/env python3
"""Acquire signed Tor Browser as the desktop user; never execute a download as root."""
import fcntl
import json
import os
from pathlib import Path
import platform
import shutil
import signal
import subprocess
import tarfile
import tempfile
from urllib.parse import urlparse
from urllib.request import urlopen, Request
from http.client import HTTPException
import re
import time

FINGERPRINT='EF6E286DDA85EA2A4BA7DE684E2C6E8793298290'
BASE=Path.home()/'.local/share/omarchy-tor'


def fetch(url, target, limit):
    parsed=urlparse(url)
    if parsed.scheme!='https' or parsed.hostname not in ('aus1.torproject.org','dist.torproject.org','keys.openpgp.org'):
        raise ValueError('Untrusted browser download location')
    total=0;expected=None;validator=None
    target.write_bytes(b'')
    for attempt in range(8):
        headers={'Accept-Encoding':'identity'}
        if total:
            headers['Range']='bytes='+str(total)+'-'
            if validator:headers['If-Range']=validator
        try:
            with urlopen(Request(url,headers=headers),timeout=60) as source:
                if urlparse(source.url).scheme!='https':raise ValueError('Insecure redirect')
                if source.status==206:
                    match=re.fullmatch(r'bytes (\d+)-(\d+)/(\d+)',source.headers.get('Content-Range',''))
                    if not match or int(match[1])!=total:raise ValueError('Invalid resumed download range')
                    size=int(match[3])
                    if expected is not None and size!=expected:raise ValueError('Download changed while resuming')
                    expected=size
                elif source.status==200:
                    total=0
                    expected=int(source.headers['Content-Length']) if source.headers.get('Content-Length') else None
                    validator=source.headers.get('ETag') or source.headers.get('Last-Modified')
                else:raise ValueError('Unexpected download response')
                if expected is not None and expected>limit:raise ValueError('Download exceeds size limit')
                with target.open('ab' if total else 'wb') as output:
                    while chunk:=source.read(1024*1024):
                        total+=len(chunk)
                        if total>limit:raise ValueError('Download exceeds size limit')
                        output.write(chunk)
                if expected is None or total==expected:return
                if total>expected:raise ValueError('Download exceeds advertised length')
        except (OSError,HTTPException):
            if attempt==7:raise
        if attempt<7:
            print('Download interrupted; retrying ('+str(attempt+1)+'/7)',flush=True)
            time.sleep(min(attempt+1,3))
    raise ValueError('Incomplete browser download: received '+str(total)+' of '+str(expected)+' bytes')


def install():
    if os.geteuid()==0: raise RuntimeError('Browser acquisition must run as the desktop user')
    if platform.machine()!='x86_64': raise RuntimeError('This release supports x86_64 only')
    BASE.mkdir(parents=True,exist_ok=True,mode=0o700)
    with (BASE/'browser-install.lock').open('w') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        with tempfile.TemporaryDirectory(prefix='.browser-stage-',dir=BASE) as tmp:
            stage=Path(tmp)
            print('Downloading Tor Browser release metadata',flush=True)
            fetch('https://aus1.torproject.org/torbrowser/update_3/release/download-linux-x86_64.json',stage/'release.json',1024*1024)
            metadata=json.loads((stage/'release.json').read_text())
            print('Downloading signed Tor Browser '+metadata['version'],flush=True)
            fetch(metadata['binary'],stage/'browser.tar.xz',1024*1024*1024)
            fetch(metadata['sig'],stage/'browser.asc',1024*1024)
            fetch('https://keys.openpgp.org/vks/v1/by-fingerprint/'+FINGERPRINT,stage/'key',1024*1024)
            home=stage/'gnupg';home.mkdir(mode=0o700)
            command=['gpg','--batch','--homedir',str(home)]
            subprocess.run(command+['--import',str(stage/'key')],check=True,capture_output=True)
            result=subprocess.run(command+['--status-fd','1','--verify',str(stage/'browser.asc'),str(stage/'browser.tar.xz')],capture_output=True,text=True)
            if result.returncode:raise RuntimeError('Tor Browser signature verification failed; the existing browser was preserved. Retry the download later.')
            signatures=[line.split() for line in result.stdout.splitlines() if line.startswith('[GNUPG:] VALIDSIG ')]
            if not any(line[-1]==FINGERPRINT or line[2]==FINGERPRINT for line in signatures):
                raise RuntimeError('Unexpected browser signing key')
            print('Signature verified; extracting browser',flush=True)
            with tarfile.open(stage/'browser.tar.xz') as archive:
                archive.extractall(stage/'unpacked',filter='data')
            new=stage/'unpacked/tor-browser'
            if not (new/'Browser/firefox').is_file(): raise RuntimeError('Unexpected browser layout')
            current=BASE/'tor-browser';previous=BASE/'tor-browser.previous'
            if current.is_symlink() or previous.is_symlink(): raise RuntimeError('Refusing symlink browser destination')
            # Keep browser profiles stable and outside the replaceable application bundle.
            profile=BASE/'browser-profile'
            old_profile=current/'Browser/TorBrowser/Data/Browser/profile.default'
            if not profile.exists() and old_profile.is_dir(): shutil.copytree(old_profile,profile)
            if previous.exists(): shutil.rmtree(previous)
            if current.exists(): current.rename(previous)
            try: new.rename(current)
            except BaseException:
                if previous.exists(): previous.rename(current)
                raise
            (BASE/'browser-release.json').write_text(json.dumps(metadata)+'\n')
            print('Tor Browser ready',flush=True)


def main():
    def interrupted(number, _frame):
        # Unwind the staging context when the setup terminal closes or its
        # process is cancelled, instead of leaving a partial archive on disk.
        raise SystemExit(128 + number)
    for number in (signal.SIGHUP, signal.SIGTERM):
        signal.signal(number, interrupted)
    try: install()
    except KeyboardInterrupt: raise SystemExit(130)
    except Exception as error: raise SystemExit('Browser setup failed: '+str(error))


if __name__=='__main__': main()
