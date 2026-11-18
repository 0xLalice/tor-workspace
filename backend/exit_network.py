"""Sample real running exit relays; assign illustrative in-country coordinates."""
import bisect
import importlib.util
import ipaddress
import json
import math
from pathlib import Path
import random
import re
import time

PLUGIN = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('tor_network_backend', PLUGIN / 'backend.py')
backend = importlib.util.module_from_spec(spec)
spec.loader.exec_module(backend)


def inventory():
    with backend.Controller() as control:
        relays = {}
        identity = address = None
        for line in control.command('GETINFO ns/all').splitlines():
            fields = line.split()
            if fields[:1] == ['r']:
                identity = address = None
                if len(fields) >= 8:
                    identity, address = fields[2], str(ipaddress.ip_address(fields[-3]))
            elif fields[:1] == ['s'] and identity:
                flags = set(fields[1:])
                if {'Running', 'Valid', 'Exit'} <= flags and 'BadExit' not in flags:
                    relays[identity] = address
        addresses = sorted(set(relays.values()))
        countries = {}
        for start in range(0, len(addresses), 128):
            reply = control.command('GETINFO ' + ' '.join('ip-to-country/' + a for a in addresses[start:start+128]))
            for line in reply.splitlines():
                match = re.fullmatch(r'ip-to-country/([^=]+)=([a-zA-Z]{2})', line)
                if match:
                    countries[match[1]] = match[2].upper()
        return [{'id': identity, 'country': countries.get(address, '')} for identity, address in sorted(relays.items())]


def in_ring(x, y, ring):
    inside = False
    for i in range(len(ring)):
        a, b = ring[i-1], ring[i]
        if (a[1] > y) != (b[1] > y) and x < (b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0]:
            inside = not inside
    return inside


def in_polygon(x, y, polygon):
    return in_ring(x, y, polygon[0]) and not any(in_ring(x, y, hole) for hole in polygon[1:])


def geometry_index():
    result = {}
    for feature in json.loads((PLUGIN.parent/'assets/maps/countries.geojson').read_text())['features']:
        code = feature['properties']['code']
        if not code:
            continue
        geometry = feature['geometry']
        polygons = [geometry['coordinates']] if geometry['type'] == 'Polygon' else geometry['coordinates']
        result.setdefault(code, []).extend(polygons)
    return result


def placement(polygons, rng):
    # Weight each polygon's spherical bounding box, then reject holes/ocean.
    boxes, cumulative, total = [], [], 0
    for polygon in polygons:
        xs, ys = zip(*polygon[0])
        left, right, bottom, top = min(xs), max(xs), min(ys), max(ys)
        low, high = math.sin(math.radians(bottom)), math.sin(math.radians(top))
        area = (right-left)*(high-low)
        if area > 0:
            boxes.append((polygon, left, right, low, high)); total += area; cumulative.append(total)
    if not boxes:
        raise ValueError('Country has no usable geometry')
    for _ in range(100000):
        polygon, left, right, low, high = boxes[bisect.bisect(cumulative, rng.random()*total)]
        x = rng.uniform(left, right)
        y = math.degrees(math.asin(rng.uniform(low, high)))
        if in_polygon(x, y, polygon):
            return x, y
    raise ValueError('Could not place a light inside country boundaries')


def sample_network(relays=None, limit=600, seed=2718):
    relays = inventory() if relays is None else relays
    if not relays:
        raise ValueError('No running exit relays in the local Tor directory. Open the Tor workspace and retry.')
    geometry = geometry_index()
    groups = {}
    for relay in relays:
        if relay['country'] in geometry:
            groups.setdefault(relay['country'], []).append(relay)
    if not groups:
        raise ValueError('Country data is unavailable for this Tor directory.')
    rng = random.Random(seed)
    selected, remainder = [], []
    for code in sorted(groups):
        group = list(groups[code]); rng.shuffle(group)
        selected.append(group[0]); remainder.extend(group[1:])
    rng.shuffle(remainder)
    selected = selected[:limit] + remainder[:max(0,limit-len(selected))]
    rng.shuffle(selected)
    points = []
    for relay in selected:
        x, y = placement(geometry[relay['country']], rng)
        points.append(dict(relay, longitude=x, latitude=y, phase=rng.random()))
    return dict(source='Local Tor directory + Tor GeoIP', sampledAt=int(time.time()), total=len(relays),
                count=len(points), countries=len(set(p['country'] for p in points)),
                unplaced=sum(1 for r in relays if r['country'] not in geometry),
                countryCounts={code:len(rows) for code,rows in groups.items()}, points=points, seed=seed)


if __name__ == '__main__':
    try:
        print(json.dumps(sample_network(limit=100000)))
    except (OSError, ValueError, RuntimeError) as error:
        print(json.dumps({'error': str(error)}))
