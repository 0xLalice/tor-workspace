#!/usr/bin/env python3
"""Validate the plugin source tree; refresh source hashes only for intentional edits."""
import argparse
import ast
import hashlib
import json
from pathlib import Path
import re
from urllib.parse import unquote


def check(root, refresh=False):
    root = Path(root).resolve()
    inventory = root/'source-hashes.json'
    hashes = json.loads(inventory.read_text())
    manifest = json.loads((root/'manifest.json').read_text())
    assert manifest['schemaVersion'] == 1
    assert re.fullmatch(r'[a-z0-9][a-z0-9._-]*', manifest['id'])
    assert not manifest['id'].startswith('omarchy.') and '..' not in manifest['id']
    for name in ('name','version','author','description'):
        assert isinstance(manifest[name], str) and manifest[name].strip(), name
    assert len(manifest['version']) <= 64
    releases = json.loads((root/'docs/releases.json').read_text())
    assert releases and releases[0]['version'] == manifest['version'], 'Latest changelog entry must match the manifest version'
    assert manifest['kinds'] == ['bar-widget']
    assert manifest['barWidget']['defaultSection'] in ('left','center','right')
    assert 'barWidget' in manifest['entryPoints']
    for value in manifest['entryPoints'].values():
        path = Path(value)
        assert not path.is_absolute() and '..' not in value and (root/path).is_file(), value
    for name in ('README.md','LICENSE','docs/INSTALL.md','SECURITY.md','THIRD_PARTY_NOTICES.md'):
        assert name in hashes and (root/name).is_file(), name
    allowed_roots = {'.github', 'ui', 'backend', 'system', 'install', 'native',
                     'assets', 'integration', 'tests', 'tools', 'docs'}
    allowed_files = {'.gitignore', 'manifest.json', 'source-hashes.json', 'README.md',
                     'LICENSE', 'CONTRIBUTING.md', 'SECURITY.md', 'THIRD_PARTY_NOTICES.md'}
    for entry in root.iterdir():
        if entry.name in ('.git', 'build', '__pycache__'): continue
        assert entry.name in (allowed_roots if entry.is_dir() else allowed_files), 'Unexpected root entry: '+entry.name
    # The catalog and style contract must match their single JSON authoring source.
    from sync_themes import sync
    sync(root,check=True)
    forbidden = {'builder','preview-settings.ini','auth.json','.env','id_ed25519'}
    # All distributable sources must appear in the inventory: catch forgotten files.
    source_files = {str(p.relative_to(root)) for p in root.rglob('*') if p.is_file()
                    and not any(part in ('.git', '__pycache__', 'build') for part in p.relative_to(root).parts)
                    and p.name != 'source-hashes.json'}
    if refresh: hashes = dict.fromkeys(sorted(source_files), '')
    else: assert set(hashes) == source_files, 'Inventory omits files or contains retired paths'
    actual = {}
    for name in hashes:
        path = Path(name)
        assert not path.is_absolute() and '..' not in path.parts, name
        assert not (set(path.parts) & forbidden), name
        source = root/path
        assert source.is_file() and not source.is_symlink(), name
        actual[name] = hashlib.sha256(source.read_bytes()).hexdigest()
        if source.suffix in ('.py','.qml','.js','.cpp','.lua'):
            assert source.stat().st_size < 512*1024, 'Source exceeds marketplace limit: '+name
        if source.suffix == '.py': ast.parse(source.read_text(), filename=name)
        if source.suffix == '.md':
            for target in re.findall(r'\[[^\]]*\]\(([^)]+)\)', source.read_text()):
                if re.match(r'[a-z]+:', target) or target.startswith('#'): continue
                target = unquote(target.split('#',1)[0])
                assert (source.parent/target).exists(), f'{name}: broken link {target}'
    for path in root.rglob('*'):
        relative = path.relative_to(root)
        if '.git' in relative.parts or '__pycache__' in relative.parts: continue
        assert not path.is_symlink(), 'Symlink in plugin: '+str(relative)
    if refresh:
        inventory.write_text(json.dumps(actual, indent=2)+'\n')
    else:
        assert actual == hashes, 'Source hashes differ; inspect changes before refreshing as a maintainer'
    print(f'Validated {manifest["id"]} {manifest["version"]}: {len(hashes)} inventoried files')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', nargs='?', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--refresh-hashes', action='store_true')
    args = parser.parse_args()
    check(args.root, args.refresh_hashes)
