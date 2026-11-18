#!/usr/bin/env python3
"""Register the plugin and migrate development installs without losing Git or settings."""
import argparse
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

PLUGIN_ID = 'tor.workspace'
# Compatibility only: pre-release installations used the developer's personal ID.
LEGACY_ID = 'lolo.tor-workspace'


def verify_source(source):
    hashes = json.loads((source/'source-hashes.json').read_text())
    for name, digest in hashes.items():
        path = Path(name)
        if path.is_absolute() or '..' in path.parts or (source/path).is_symlink():
            raise ValueError('Unsafe release path')
        if hashlib.sha256((source/path).read_bytes()).hexdigest() != digest:
            raise ValueError('Release integrity mismatch: '+name)
    return hashes


def migrate_bar(settings):
    layout = settings.setdefault('bar', {}).setdefault('layout', {})
    sections = ('left', 'center', 'right')
    legacy_present = any(entry.get('id') == LEGACY_ID
                         for section in sections for entry in layout.get(section, []))
    found = False
    for section in sections:
        if section not in layout: continue
        entries = []
        for entry in layout[section]:
            if legacy_present and entry.get('id') == PLUGIN_ID: continue
            if entry.get('id') in (LEGACY_ID, PLUGIN_ID):
                if found: continue
                entry = dict(entry, id=PLUGIN_ID)
                found = True
            entries.append(entry)
        layout[section] = entries
    if not found: layout.setdefault('left', []).append({'id': PLUGIN_ID})


def install(source, config, reload=True):
    source = Path(source).resolve()
    config = Path(config)
    hashes = verify_source(source)
    target = config/'omarchy/plugins'/PLUGIN_ID
    legacy_plugin = config/'omarchy/plugins'/LEGACY_ID
    if target.is_symlink() or legacy_plugin.is_symlink():
        raise ValueError('Refusing symlink plugin destination')
    migrating_checkout = source == legacy_plugin.resolve() and (source/'.git').is_dir()
    in_place = source == target.resolve()
    if migrating_checkout and target.exists():
        raise ValueError('Both plugin IDs exist. Run setup from the new tor.workspace checkout.')
    if not in_place and (target/'.git').exists():
        raise ValueError('This plugin is Git-managed. Update it with omarchy plugin update tor.workspace, then run setup from its installed directory.')

    shell = config/'omarchy/shell.json'
    hypr = config/'hypr/hyprland.lua'
    backup = config/'omarchy/tor-workspace-backups'/datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    backup.mkdir(parents=True, mode=0o700)
    retired = [config/'omarchy/tor-workspace'/name for name in ('shortcuts', 'shortcuts.lock')]
    retired = [path for path in retired if path.is_file() and not path.is_symlink()]
    saved = [shell, hypr, *retired]
    if not in_place and target.exists(): saved.append(target)
    if legacy_plugin.exists(): saved.append(legacy_plugin)
    for path in saved:
        if not path.exists(): continue
        destination = backup/path.relative_to(config)
        destination.parent.mkdir(parents=True, exist_ok=True)
        if path.is_dir(): shutil.copytree(path, destination)
        else: shutil.copy2(path, destination)

    target.parent.mkdir(parents=True, exist_ok=True)
    if migrating_checkout:
        legacy_plugin.rename(target)
        source = target
        in_place = True
    if not in_place:
        # Assemble outside the watched plugin tree, then swap complete directories.
        with tempfile.TemporaryDirectory(prefix='.tor-workspace-install-', dir=config/'omarchy') as temporary:
            stage = Path(temporary)
            next_plugin = stage/'plugin'
            next_plugin.mkdir()
            for name in hashes:
                destination = next_plugin/name
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source/name, destination)
            shutil.copy2(source/'source-hashes.json', next_plugin/'source-hashes.json')
            previous = stage/'previous'
            if target.exists(): target.rename(previous)
            try: next_plugin.rename(target)
            except BaseException:
                if previous.exists(): previous.rename(target)
                raise

    for path in retired: path.unlink()
    old_service = config/'systemd/user/omarchy-tor-panel.service'
    old_command = f'ExecStart=/usr/bin/python3 %h/.config/omarchy/plugins/{LEGACY_ID}/backend.py serve'
    if old_service.is_file() and old_command in old_service.read_text():
        destination = backup/'systemd/user/omarchy-tor-panel.service'
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(old_service, destination)
        if reload: subprocess.run(['systemctl', '--user', 'disable', '--now', 'omarchy-tor-panel.service'], check=True)
        old_service.unlink()
        if reload: subprocess.run(['systemctl', '--user', 'daemon-reload'], check=True)

    settings = json.loads(shell.read_text()) if shell.exists() else {}
    migrate_bar(settings)
    shell.write_text(json.dumps(settings, indent=2)+'\n')
    if hypr.exists():
        include = f'/omarchy/plugins/{PLUGIN_ID}/integration/workspace.lua'
        content = hypr.read_text().replace(LEGACY_ID, PLUGIN_ID)
        content = content.replace(f'{PLUGIN_ID}/workspace.lua', f'{PLUGIN_ID}/integration/workspace.lua')
        guarded = ('local tor_workspace = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "'+include+'"\n'
                   'local tor_file = io.open(tor_workspace)\n'
                   'if tor_file then tor_file:close(); dofile(tor_workspace) end')
        direct = 'dofile(os.getenv("HOME") .. "/.config'+include+'")'
        if direct in content: content = content.replace(direct, guarded)
        elif include not in content: content += '\n-- Tor Workspace: safely optional after plugin removal.\n'+guarded+'\n'
        hypr.write_text(content)

    # The complete old tree is already backed up outside the shell's plugin search path.
    if legacy_plugin.exists(): shutil.rmtree(legacy_plugin)
    if reload:
        if hypr.exists():
            subprocess.run(['hyprctl', 'reload'], check=True)
            result = subprocess.run(['hyprctl', 'configerrors'], check=True, capture_output=True, text=True)
            if result.stdout.strip() not in ('', 'ok'): raise RuntimeError('Hyprland reported: '+result.stdout)
        subprocess.run(['omarchy', 'restart', 'shell'], check=True)
    print('Installed:', target, '\nBackup:', backup, '\nOpen Tor Workspace and choose Installation if required.')
    return target


if __name__ == '__main__':
    if os.geteuid() == 0: raise SystemExit('Run the plugin installer as the desktop user')
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config-dir', type=Path, default=Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home()/'.config'))))
    parser.add_argument('--no-reload', action='store_true')
    args = parser.parse_args()
    install(Path(__file__).resolve().parents[1], args.config_dir, not args.no_reload)
