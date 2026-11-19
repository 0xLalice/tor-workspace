#!/usr/bin/env python3
"""Cached update discovery using the same origin/HEAD as Omarchy's updater.

Only Git objects and our cache change. Never check out or execute remote files.
"""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
REF = 'refs/tor-workspace/update'
FEATURE_ICONS = ('browser', 'terminal', 'share', 'chat', 'options', 'refresh', 'website', 'host')


def git(root, *args):
    # Terminal prompt suppression alone does not stop helpers such as gh from
    # opening a desktop keyring unlock dialog. Discovery must never invoke them.
    env = dict(os.environ, GIT_OPTIONAL_LOCKS='0', GIT_TERMINAL_PROMPT='0', GCM_INTERACTIVE='never',
               GIT_ASKPASS='/bin/false', SSH_ASKPASS='/bin/false', SSH_ASKPASS_REQUIRE='never',
               GIT_SSH_COMMAND='ssh -oBatchMode=yes -oConnectTimeout=10')
    return subprocess.check_output(['git', '-c', 'credential.helper=', '-c', 'core.askPass=/bin/false',
                                    '-C', str(root), *args], env=env,
                                   stderr=subprocess.DEVNULL, text=True, timeout=30).strip()


def parse_releases(raw):
    if len(raw) > 65536: raise ValueError('Release notes too large')
    values = json.loads(raw)
    if not isinstance(values, list): raise ValueError('Expected release entries')
    releases = []
    for value in values[:8]:
        if not isinstance(value, dict) or not isinstance(value.get('version'), str):
            raise ValueError('Invalid release version')
        changes = value.get('changes')
        if not isinstance(changes, list) or not all(isinstance(item, str) for item in changes):
            raise ValueError('Invalid release notes')
        entry = dict(version=value['version'][:40], changes=[])
        icons = value.get('icons', [])
        if not isinstance(icons, list):
            icons = []
        feature_icons = []
        for index, text in enumerate(changes[:8]):
            if not text.strip():
                continue
            entry['changes'].append(text.strip()[:240])
            icon = icons[index] if index < len(icons) else ''
            feature_icons.append(icon if icon in FEATURE_ICONS else '')
        if any(feature_icons):
            entry['icons'] = feature_icons
        releases.append(entry)
    return releases


def pending_update(root):
    try:
        marker = json.loads((root/'.git/tor-workspace-update.json').read_text())
        if marker['revision'] == git(root, 'rev-parse', 'HEAD') and isinstance(marker['previous'], str):
            return marker
    except (OSError, ValueError, TypeError, KeyError, subprocess.SubprocessError):
        pass
    return None


def local_status(root=ROOT):
    result = dict(available=False, canUpdate=False, currentVersion='', latestVersion='',
                  releases=[], error='', managed=(root/'.git').exists(), checked=False)
    try:
        version = str(json.loads((root/'manifest.json').read_text())['version'])[:40]
        result['currentVersion'] = version
        try: releases = parse_releases((root/'docs/releases.json').read_text())
        except (OSError, ValueError): releases = []
        result['releases'] = [dict(entry, kind='installed' if entry['version']==version else 'previous')
                              for entry in releases]
        if not any(entry['version']==version for entry in releases):
            result['releases'].insert(0, dict(version=version, changes=[], kind='installed'))
    except (OSError, ValueError, KeyError, TypeError):
        result['error'] = 'Could not read the installed version.'
    return result


def pending_releases(root, head, remote, current_version, latest_version):
    pending = []
    try:
        for entry in parse_releases(git(root, 'show', remote+':docs/releases.json')):
            if entry['version'] == current_version: break
            pending.append(dict(entry, kind='available'))
    except (OSError, subprocess.SubprocessError, ValueError): pass
    if pending and pending[0]['version']==latest_version: return pending
    changes = [line[:240] for line in git(root, 'log', '--format=%s', '-8', head+'..'+remote).splitlines()]
    return [dict(version=latest_version, changes=changes, kind='available')]


def check(root=ROOT, cache_dir=None, force=False):
    result = local_status(root)
    try:
        if result['error'] or not result['managed']: return result
        pending = pending_update(root)
        if pending:
            clean = not git(root, 'status', '--porcelain')
            result.update(available=True, canUpdate=clean, checked=True, revision=pending['revision'],
                          latestVersion=result['currentVersion'],
                          error='Finish the interrupted update.' if clean else 'Local changes need attention before updating.')
            return result
        head = git(root, 'rev-parse', 'HEAD')
        origin = git(root, 'remote', 'get-url', 'origin')
        key = hashlib.sha256(('2'+str(root.resolve())+origin+head).encode()).hexdigest()
        cache_dir = cache_dir or Path(os.environ.get('XDG_CACHE_HOME', Path.home()/'.cache'))/'omarchy-tor/updates'
        cache_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
        with (cache_dir/'check.lock').open('w') as lock:
            # Other widget instances/processes can reuse the completed result.
            fcntl.flock(lock, fcntl.LOCK_EX)
            cache = cache_dir/(key+'.json')
            previous = {}
            try:
                previous = json.loads(cache.read_text())
                ttl = 300 if previous.get('error') else 3600
                if not force and 0 <= time.time()-previous['checkedAt'] < ttl:
                    # Remote discovery may be cached; local edit safety may not.
                    if previous.get('available') and previous.get('checked'):
                        base = git(root, 'merge-base', head, previous['revision'])
                        previous['canUpdate'] = base == head and not git(root, 'status', '--porcelain')
                        previous['error'] = ('' if previous['canUpdate'] else
                            'Local changes need attention before updating. Your checkout has been preserved.')
                    return previous
            except (OSError, ValueError, KeyError, TypeError): pass
            result['managed'] = True
            try:
                git(root, 'fetch', '--quiet', '--no-tags', '--no-write-fetch-head', 'origin', '+HEAD:'+REF)
                remote = git(root, 'rev-parse', REF)
                result['revision'] = remote
                result['checked'] = True
                if head != remote:
                    # Local commits ahead of upstream are not an available update.
                    base = git(root, 'merge-base', head, remote)
                    if base != remote:
                        result['available'] = True
                        result['latestVersion'] = str(json.loads(git(root, 'show', remote+':manifest.json'))['version'])[:40]
                        result['releases'] = (pending_releases(root, head, remote, result['currentVersion'], result['latestVersion']) + result['releases'])[:8]
                        result['canUpdate'] = base == head and not git(root, 'status', '--porcelain')
                        if not result['canUpdate']:
                            result['error'] = 'Local changes need attention before updating. Your checkout has been preserved.'
            except (OSError, subprocess.SubprocessError, ValueError, KeyError, TypeError):
                if previous.get('available'):
                    result = dict(previous, checked=False)
                result['error'] = 'Could not check without prompting. Check your connection or update manually.'
                result['canUpdate'] = False
            result['checkedAt'] = time.time()
            temporary = cache.with_suffix('.tmp')
            temporary.write_text(json.dumps(result)); temporary.replace(cache)
            # One result per checkout; do not accumulate an entry per release.
            for old in cache_dir.glob('*.json'):
                if old != cache and time.time()-old.stat().st_mtime > 86400: old.unlink()
    except (OSError, subprocess.SubprocessError, ValueError, KeyError, TypeError):
        result['error'] = 'Could not inspect the installed Git checkout.'
    return result


def handoff_status(root, expected_revision, cache_dir=None):
    """Recheck mutable checkout/remote state immediately before agent handoff."""
    result = check(root, cache_dir, force=True)
    if result.get('canUpdate') and result.get('revision') != expected_revision:
        result['canUpdate'] = False
        result['error'] = 'The remote changed after discovery. Check for updates and review the new changes.'
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--force', action='store_true')
    args = parser.parse_args()
    # Render installed history immediately, including when the network is offline.
    print(json.dumps(dict(local_status(), local=True)), flush=True)
    print(json.dumps(check(force=args.force)), flush=True)
