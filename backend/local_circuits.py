"""Read-only BUILT circuit snapshot. Never resolve or publish private hops."""
import base64
import ipaddress
import json
import os
import tempfile
from pathlib import Path
import re
import random
import time
import backend


def parse_built(reply):
    rows=[]
    for line in reply.splitlines():
        fields=line.split()
        if len(fields)<2 or not fields[0].isdigit() or fields[1]!='BUILT':
            continue
        path=[]
        if len(fields)>2 and fields[2].startswith('$'):
            for token in fields[2].split(','):
                match=re.fullmatch(r'\$([A-Fa-f0-9]{40})(?:[~=].*)?',token)
                path.append(match[1].upper() if match else None)
        rows.append((fields[0],path))
    return rows


def public_directory(reply):
    relays={}
    for line in reply.splitlines():
        fields=line.split()
        if fields[:1]!=['r'] or len(fields)<9:continue
        try:
            fingerprint=base64.b64decode(fields[2]+'='*(-len(fields[2])%4),validate=True).hex().upper()
            address=ipaddress.ip_address(fields[6])
            if len(fingerprint)==40 and address.is_global:
                relays[fingerprint]=str(address)
        except ValueError:continue
    return relays


def place_relays(circuits):
    # Distinct, stable illustrative positions within the known country polygon.
    # Fingerprint identity, not country, determines a relay's point.
    from exit_network import geometry_index, placement
    geometry=geometry_index()
    points={}
    for circuit in circuits:
        for hop in circuit['route']:
            fingerprint=hop.get('fingerprint')
            country=hop.get('country')
            if not fingerprint or country not in geometry:continue
            key=(fingerprint,country)
            if key not in points:
                try:points[key]=placement(geometry[country],random.Random(int(fingerprint,16)))
                except ValueError:continue
            hop['longitude'],hop['latitude']=points[key]
            hop['positionKind']='illustrative-in-country'


def snapshot():
    unavailable=dict(available=False,count=None,circuits=[])
    try:
        generation=backend.gateway_generation()
        with backend.Controller() as control:
            rows=parse_built(control.command('GETINFO circuit-status'))
            observed_at=time.time()
            # Only public consensus addresses are cached; circuit paths never are.
            cache_path=backend.RUNTIME/'public-circuit-directory.json'
            try:cache=json.loads(cache_path.read_text())
            except (OSError,ValueError):cache={}
            if not isinstance(cache,dict):cache={}
            directory={}
            try:
                if cache.get('generation')==generation and isinstance(cache.get('relays'),dict) and time.time()-cache.get('at',0)<60:
                    directory=cache['relays']
                else:
                    directory=public_directory(control.command('GETINFO ns/all'))
                    backend.prepare()
                    with tempfile.NamedTemporaryFile(mode='w',dir=backend.RUNTIME,prefix='public-directory-',delete=False) as file:
                        temporary=file.name
                        json.dump(dict(generation=generation,at=time.time(),relays=directory),file)
                    try:os.replace(temporary,cache_path)
                    finally:Path(temporary).unlink(missing_ok=True)
            except (OSError,ValueError,KeyError,RuntimeError):pass
            addresses=sorted({directory[fp] for _,path in rows for fp in path if fp in directory})
            countries={}
            for start in range(0,len(addresses),128):
                try:
                    reply=control.command('GETINFO '+' '.join('ip-to-country/'+a for a in addresses[start:start+128]))
                    for line in reply.splitlines():
                        match=re.fullmatch(r'ip-to-country/([^=]+)=([a-zA-Z]{2})',line)
                        if match:countries[match[1]]=match[2].upper()
                except (OSError,RuntimeError):pass
            circuits=[]
            for cid,path in rows:
                # Keep unknown hops as gaps, with no fingerprint, IP or location.
                route=[dict(fingerprint=fp,country=countries.get(directory[fp],''))
                       if fp in directory else {} for fp in path]
                circuits.append(dict(id=cid,route=route))
            place_relays(circuits)
            if generation!=backend.gateway_generation():return unavailable
            return dict(available=True,count=len(rows),circuits=circuits,
                        generation=generation,observedAt=observed_at,positionSource='Tor GeoIP countries; illustrative fingerprint-stable positions')
    except (OSError,ValueError,RuntimeError):return unavailable
