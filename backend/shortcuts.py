#!/usr/bin/env python3
"""Conflict-aware, user-owned Tor shortcuts. Never unbind another application."""
import fcntl
import json
import os
from pathlib import Path
import re
import subprocess
import sys

CONFIG = Path(os.environ.get('XDG_CONFIG_HOME', Path.home()/'.config'))/'omarchy/tor-workspace'
CANDIDATES = ('U', 'I', 'H', 'Q', 'R', 'Z')
LABELS = {'open': 'Tor Workspace: Open', 'move': 'Tor Workspace: Move window'}
MODS = {'SUPER':64, 'CTRL':4, 'ALT':8, 'SHIFT':1}


def normalize(value):
    if not value: return ''
    parts = [p.strip().upper() for p in value.split('+')]
    key = parts.pop()
    if not parts or len(set(parts)) != len(parts) or any(p not in MODS for p in parts):
        raise ValueError('Use a modifier and a letter, number or function key.')
    if not re.fullmatch(r'[A-Z0-9]|F(?:[1-9]|1[0-9]|2[0-4])', key):
        raise ValueError('Use a letter, number or function key.')
    return ' + '.join([m for m in MODS if m in parts]+[key])


def identity(value):
    parts = normalize(value).split(' + ')
    return sum(MODS[m] for m in parts[:-1]), parts[-1]


def hypr(*args):
    result = subprocess.run(['hyprctl', *args], text=True, capture_output=True, timeout=10, check=True)
    return result.stdout


def bindings():
    value = json.loads(hypr('-j', 'binds'))
    if not isinstance(value, list): raise ValueError('Could not read shortcuts.')
    return value


def conflict(combo, registered):
    if not combo: return ''
    mask, key = identity(combo)
    # Check all submaps conservatively; symbol bindings are the UI's supported form.
    for b in registered:
        if b.get('description') in LABELS.values(): continue
        if b.get('modmask') == mask and (str(b.get('key','')).upper() == key or b.get('catch_all') or b.get('keycode',0)):
            return b.get('description') or 'another action'
    return ''


def load():
    try:
        value = json.loads((CONFIG/'keybindings.json').read_text())
        if not isinstance(value, dict): raise ValueError('Invalid shortcut settings.')
        return {k:normalize(value[k]) for k in LABELS if k in value}
    except FileNotFoundError: return {}


def pair(key):
    key = key.strip().upper()
    if not key: return {'open':'', 'move':''}
    if not re.fullmatch('[A-Z]', key): raise ValueError('Choose one letter.')
    return {'open':'SUPER + '+key, 'move':'SUPER + SHIFT + '+key}


def select(saved, registered):
    # Migrate only the previous generated O/U defaults, not custom user choices.
    old = [{'open':'SUPER + ALT + '+k,'move':'SUPER + ALT + SHIFT + '+k} for k in ('O','U')]
    if saved and saved not in old: return dict(saved)
    for key in CANDIDATES:
        chosen = pair(key)
        if not any(conflict(c,registered) for c in chosen.values()): return chosen
    return pair('')


def apply(chosen, registered):
    # Keep handles for precisely removing only bindings made by this module.
    lines = ['_torWorkspaceBindings = _torWorkspaceBindings or {}',
             'for _, h in pairs(_torWorkspaceBindings) do h:remove() end',
             '_torWorkspaceBindings = {}']
    for action, combo in chosen.items():
        if not combo or conflict(combo, registered): continue
        dispatcher = ('hl.dsp.exec_cmd("omarchy-shell tor.workspace activate")' if action == 'open'
                      else 'hl.dsp.window.move({workspace="name:Tor",follow=true})')
        lines.append('_torWorkspaceBindings.'+action+' = hl.bind('+json.dumps(combo)+','+dispatcher+
                     ',{description='+json.dumps(LABELS[action])+'})')
    result = hypr('eval', '\n'.join(lines))
    if result.strip() not in ('','ok'): raise RuntimeError('Could not apply shortcuts: '+result.strip())


def save(chosen):
    temp = CONFIG/'keybindings.json.tmp'
    temp.write_text(json.dumps(chosen, indent=2)+'\n')
    temp.replace(CONFIG/'keybindings.json')


def status(chosen, registered):
    return {action:{'key':combo, 'conflict':conflict(combo, registered),
                    'active':any(b.get('description') == LABELS[action] and
                                 (b.get('modmask'),str(b.get('key','')).upper()) == identity(combo)
                                 for b in registered) if combo else False}
            for action,combo in chosen.items()}


def execute(command='status', action='', combo=''):
    CONFIG.mkdir(parents=True, exist_ok=True)
    with (CONFIG/'keybindings.lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        registered = bindings()
        saved = load()
        chosen = select(saved, registered)
        if command == 'set':
            if action != 'pair': raise ValueError('Unknown shortcut action.')
            chosen = pair(combo)
            for value in chosen.values():
                occupied = conflict(value, registered)
                if occupied: raise ValueError(value+' is used by '+occupied+'.')
        if command == 'remove':
            apply({}, registered)
            return {'removed':True}
        if command in ('sync','set'):
            try:
                apply(chosen, registered)
                save(chosen)
            except Exception:
                apply(saved, registered)
                raise
            registered = bindings()
        elif command != 'status': raise ValueError('Unknown shortcut command.')
        return {'bindings':status(chosen, registered), 'error':''}


if __name__ == '__main__':
    try: result = execute(*sys.argv[1:])
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        result = {'error':str(error)}
    print(json.dumps(result))
