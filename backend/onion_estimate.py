#!/usr/bin/env python3
"""Public Tor Metrics v3 address estimate; shared daily cache, no Tor control."""
import csv
from datetime import date, datetime, timezone
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
import fcntl
import io
import json
import os
from pathlib import Path
import tempfile
import time
import urllib.request

SOURCE = 'https://metrics.torproject.org/hidserv-dir-v3-onions-seen.html'
CSV_URL = 'https://metrics.torproject.org/hidserv-dir-v3-onions-seen.csv'
CACHE = Path(os.environ.get('XDG_CACHE_HOME') or Path.home() / '.cache') / 'tor-workspace' / 'onion-estimate.json'
DAY = 86400


def observation(value):
    """Validate stored and downloaded observations with the same rules."""
    day = date.fromisoformat(value['date'])
    count = Decimal(str(value['onions']))
    if day > datetime.now(timezone.utc).date() or not count.is_finite() or count < 1:
        raise ValueError('Invalid observation')
    return {'date': day.isoformat(), 'onions': str(count)}


def parse(text):
    rows = csv.DictReader(line for line in io.StringIO(text) if not line.startswith('#'))
    if not {'date', 'onions'}.issubset(rows.fieldnames or []):
        raise ValueError('Missing estimate columns')
    valid = []
    for row in rows:
        try:
            valid.append(observation(row))
        except (ValueError, TypeError, KeyError, InvalidOperation):
            continue
    if not valid:
        raise ValueError('No valid observations')
    return max(valid, key=lambda row: row['date'])


def display(value):
    value = observation(value)
    count = Decimal(value['onions'])
    rounded = count.quantize(Decimal(1).scaleb(max(0, count.adjusted() - 2)), rounding=ROUND_HALF_UP)
    day = date.fromisoformat(value['date'])
    month = 'Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec'.split()[day.month - 1]
    return dict(value, text=f'Tor Metrics estimates {rounded:,.0f} .onion addresses for {day.day} {month} {day.year}.')


def read(path=CACHE):
    try:
        value = json.loads(path.read_text())
        return value if isinstance(value, dict) else {}
    except (OSError, ValueError):
        return {}


def cached(path=CACHE):
    try:
        return display(read(path)['observation'])
    except (ValueError, TypeError, KeyError, InvalidOperation):
        return None


def save(path, value):
    with tempfile.NamedTemporaryFile(mode='w', dir=path.parent, delete=False) as stream:
        temporary = Path(stream.name)
        json.dump(value, stream)
    try:
        temporary.replace(path)
    finally:
        temporary.unlink(missing_ok=True)


def fetch():
    request = urllib.request.Request(CSV_URL, headers={'User-Agent': 'Tor-Workspace/0.13.1'})
    with urllib.request.urlopen(request, timeout=20) as response:
        data = response.read(2_000_001)
    if len(data) > 2_000_000:
        raise ValueError('CSV too large')
    return data.decode('utf-8-sig')


def refresh(path=CACHE, downloader=fetch, now=None):
    """Persist attempts before fetching, including failures and interrupted calls."""
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.with_suffix('.lock').open('a') as lock:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                return cached(path)
            state = read(path)
            timestamp = time.time() if now is None else now
            attempt = state.get('lastAttempt')
            if isinstance(attempt, (int, float)) and timestamp - attempt < DAY:
                return cached(path)
            state.update(version=1, source=SOURCE, csv=CSV_URL, lastAttempt=timestamp)
            save(path, state)
            try:
                value = parse(downloader())
                previous = cached(path)
                if not previous or value['date'] >= previous['date']:
                    state['observation'] = value
                    save(path, state)
            except (OSError, ValueError, InvalidOperation):
                pass
    except OSError:
        pass  # A read-only cache must not cause unthrottled remote requests.
    return cached(path)


if __name__ == '__main__':
    import sys
    print(json.dumps(cached() if '--cached' in sys.argv else refresh()))
