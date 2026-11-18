#!/usr/bin/env python3
"""Read-only public relay metadata. No runtime writes in the plugin directory."""
import sys
sys.dont_write_bytecode = True
import fcntl
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time
import backend

CACHE = backend.RUNTIME / 'relay-info'
FIELDS = ('nickname','fingerprint','country_name','running','last_seen','first_seen',
          'advertised_bandwidth','or_addresses','as','as_name','version','flags')

def identity(value):
    if not isinstance(value,str) or not re.fullmatch('[a-fA-F0-9]{40}',value):
        raise ValueError('Invalid relay fingerprint')
    return value.upper()

def read(path):
    try:
        value=json.loads(path.read_text())
        return value if isinstance(value,dict) else {}
    except (OSError,ValueError):return {}

def save(path,value):
    with tempfile.NamedTemporaryFile(mode='w',dir=path.parent,delete=False) as stream:
        json.dump(value,stream);temporary=Path(stream.name)
    temporary.replace(path)

def local(fp):
    fp=identity(fp)
    result={'fingerprint':identity(fp),'loading':True,'local':{}}
    try:
        with backend.Controller() as control:
            reply=control.command('GETINFO ns/id/'+fp)
            router=next((line.split() for line in reply.splitlines() if line.startswith('r ')),None)
            if not router:return dict(result,loading=False,unavailable=True)
            # ns/id is a public-consensus lookup. Never enrich unknown/private hops.
            import base64
            if base64.b64decode(router[2]+'='*(-len(router[2])%4)).hex().upper()!=fp:
                return dict(result,loading=False,unavailable=True)
            data={'nickname':router[1],'or_addresses':[router[6]+':'+router[7]],'observedAt':time.time()}
            for line in reply.splitlines():
                if line.startswith('s '):data['flags']=line.split()[1:];data['running']='Running' in data['flags']
                if line.startswith('a '):data['or_addresses'].append(line[2:])
            try:
                desc=control.command('GETINFO desc/id/'+fp)
                for line in desc.splitlines():
                    if line.startswith('bandwidth '):data['advertised_bandwidth']=min(map(int,line.split()[1:4]))
                    if line.startswith('platform Tor '):data['version']=line.split()[2]
            except (OSError,RuntimeError,ValueError):pass
            result.update(local=data,public=True)
    except (OSError,RuntimeError,ValueError,IndexError):result.update(loading=False,unavailable=True)
    cached=read(CACHE/(fp+'.json'))
    if cached.get('data'):result.update(remote=cached['data'],cached=True)
    return result

def normalize(payload,fp):
    rows=payload.get('relays',[])
    relay=next((r for r in rows if r.get('fingerprint')==fp),None)
    if not relay:raise ValueError('Relay unavailable')
    data={key:relay[key] for key in FIELDS if key in relay}
    for key in ('nickname','country_name','last_seen','first_seen','as','as_name','version'):
        if key in data and not isinstance(data[key],str):raise ValueError('Invalid relay data')
    for key in ('or_addresses','flags'):
        if key in data and (not isinstance(data[key],list) or not all(isinstance(v,str) for v in data[key])):raise ValueError('Invalid relay data')
    if 'running' in data and not isinstance(data['running'],bool):raise ValueError('Invalid relay data')
    if 'advertised_bandwidth' in data and (type(data['advertised_bandwidth']) not in (int,float) or data['advertised_bandwidth']<0):raise ValueError('Invalid bandwidth')
    data['publishedAt']=payload.get('relays_published')
    return data

def enrich(fp):
    fp=identity(fp)
    initial=local(fp)
    if not initial.get('public'):return initial
    CACHE.mkdir(parents=True,exist_ok=True,mode=0o700)
    with (CACHE/(fp+'.lock')).open('a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        path=CACHE/(fp+'.json');cached=read(path);now=time.time()
        if cached.get('data') and now-cached.get('fetchedAt',0)<3600:
            return dict(initial,remote=cached['data'],cached=True,loading=False)
        if now-cached.get('failedAt',0)<60:
            return dict(initial,loading=False,unavailable=True)
        try:
            url='https://onionoo.torproject.org/details?lookup='+fp+'&fields='+','.join(FIELDS)
            response=subprocess.run(['/usr/bin/curl','-q','--proxy','socks5h://localhost'+str(backend.GATEWAY/'socks'),
                '--proxy-user','tor-relay-inspector:metadata','--noproxy','','--proto','=https','--fail','--silent',
                '--connect-timeout','5','--max-time','15','--max-filesize','1048576',url],capture_output=True,text=True,timeout=18,check=True)
            data=normalize(json.loads(response.stdout),fp)
            save(path,dict(data=data,fetchedAt=now))
            return dict(initial,remote=data,cached=False,loading=False,unavailable=False)
        except (OSError,ValueError,TypeError,AttributeError,subprocess.SubprocessError):
            save(path,dict(cached,failedAt=now))
            return dict(initial,loading=False,unavailable=True)

if __name__=='__main__':
    os.umask(0o077)
    try:
        fp=identity(sys.argv[1]);print(json.dumps(local(fp)),flush=True)
        print(json.dumps(enrich(fp)),flush=True)
    except (ValueError,IndexError):sys.exit(1)
