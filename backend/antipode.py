#!/usr/bin/env python3
"""Country-level exit search using Illuminate's local Tor inventory."""
import sys
sys.dont_write_bytecode = True
import fcntl
import json
import math
import os
import tempfile
import time
from datetime import datetime, timezone
import backend
import exit_network

CACHE = backend.RUNTIME / 'antipode'


def country_snapshot(relays, features, names, now):
    """Count all running exits by country; positions are country label points."""
    counts, seen = {}, set()
    for relay in relays:
        identity, country = relay.get('id'), relay.get('country')
        if not identity or identity in seen:
            continue
        seen.add(identity)
        if isinstance(country, str) and len(country) == 2:
            country = country.upper()
            counts[country] = counts.get(country, 0) + 1
    countries = {}
    for feature in features:
        props = feature.get('properties', {})
        code, point = props.get('code'), props.get('label_point')
        if code not in counts or not isinstance(point, list) or len(point) != 2:
            continue
        lon, lat = point
        if (type(lat) not in (int, float) or type(lon) not in (int, float)
                or not math.isfinite(lat) or not math.isfinite(lon)
                or abs(lat) > 90 or abs(lon) > 180):
            continue
        countries[code] = dict(country=code, countryName=names.get(code, code),
                               latitude=lat, longitude=lon, exitCount=counts[code])
    if not countries:
        raise ValueError('No countries with running exits are available in the local Tor directory.')
    return dict(schema=2, countries=[countries[c] for c in sorted(countries)],
                totalExits=len(seen), mappedExits=sum(c['exitCount'] for c in countries.values()),
                publishedAt=datetime.fromtimestamp(now, timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC'),
                fetchedAt=now, source='Local Tor directory · country reference points')


def fetch():
    relays = exit_network.inventory()
    features = json.loads((exit_network.PLUGIN.parent / 'assets/maps/countries.geojson').read_text())['features']
    return country_snapshot(relays, features, backend.country_names(), time.time())


def snapshot(refresh=False):
    # Every explicit search reads current local consensus; only Replay reuses a snapshot.
    CACHE.mkdir(parents=True, exist_ok=True, mode=0o700)
    CACHE.chmod(0o700)
    with (CACHE / 'country.lock').open('a') as lock:
        os.chmod(CACHE / 'country.lock', 0o600)
        fcntl.flock(lock, fcntl.LOCK_EX)
        path = CACHE / 'country-snapshot.json'
        try:
            cached = json.loads(path.read_text())
            if cached.get('schema') != 2 or not cached.get('countries'):
                cached = None
        except (OSError, ValueError, AttributeError):
            cached = None
        try:
            data = fetch()
            with tempfile.NamedTemporaryFile(mode='w', dir=CACHE, delete=False) as stream:
                json.dump(data, stream)
                temporary = stream.name
            os.replace(temporary, path)
            return dict(data, cached=False, stale=False)
        except (OSError, RuntimeError, ValueError, TypeError, KeyError) as exc:
            error = str(exc) if isinstance(exc, ValueError) else 'Could not read the local Tor exit directory. Connect Tor and retry.'
            return dict(cached, cached=True, stale=True, error=error) if cached else dict(error=error)


if __name__ == '__main__':
    os.umask(0o077)
    print(json.dumps(snapshot('--refresh' in sys.argv[1:])), flush=True)
