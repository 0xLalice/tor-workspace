#!/usr/bin/env python3
"""Read complete Omarchy palettes; watch stable full-content changes."""
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import time
import ctypes
import select
import tomllib

ANSI = ['black', 'red', 'green', 'yellow', 'blue', 'magenta', 'cyan', 'white',
        'bright_black', 'bright_red', 'bright_green', 'bright_yellow', 'bright_blue',
        'bright_magenta', 'bright_cyan', 'bright_white']
HEX = re.compile(r'^#[0-9a-fA-F]{6}$')


def palette(data):
    raw = tomllib.loads(data)
    colors = {k: v for k, v in raw.items() if isinstance(v, str) and HEX.fullmatch(v)}
    for i, role in enumerate(ANSI):
        if f'color{i}' in colors: colors.setdefault(role, colors[f'color{i}'])
    if 'background' not in colors or 'foreground' not in colors:
        raise ValueError('Palette needs background and foreground')
    def role(name, *fallbacks):
        colors.setdefault(name, next(colors[k] for k in fallbacks if k in colors))
    role('accent', 'blue', 'foreground')
    role('muted', 'bright_black', 'foreground')
    role('selection', 'bright_black', 'background')
    for name in ('dark_background', 'darker_background', 'lighter_background'):
        role(name, 'background')
    for name, candidates in {'dark_foreground':('cyan','foreground'),
         'light_foreground':('white','foreground'), 'bright_foreground':('bright_white','foreground'),
         'orange':('yellow','accent'), 'brown':('red','accent')}.items(): role(name,*candidates)
    for name in ANSI: role(name, 'accent')
    mode = raw.get('mode')
    if mode not in ('dark', 'light'):
        rgb = [int(colors['background'][i:i+2],16)/255 for i in (1,3,5)]
        mode = 'light' if sum(v*w for v,w in zip(rgb,(.2126,.7152,.0722))) > .5 else 'dark'
    return dict(colors, mode=mode)


def read_palette(path):
    data = path.read_text()
    value = palette(data)
    name_file = path.parent.parent / 'theme.name'
    name = name_file.read_text().strip() if name_file.exists() else path.parent.resolve().name
    if name == 'theme':
        name = next((p.parent.name for p in Path('/usr/share/omarchy/themes').glob('*/colors.toml')
                     if p.read_text() == data), 'custom')
    signature = hashlib.sha256((name+data).encode()).hexdigest()
    return dict(value, themeId=name.lower().replace(' ', '-'), themeName=name, revision=signature)


class PaletteNotifications:
    """Watch containing directories, including both sides of theme symlinks.

    Parent watches survive atomic file replacement and theme-directory swaps.
    Re-arm after events to follow new symlink targets or recreated directories.
    """
    def __init__(self, path):
        self.path = path
        self.libc = ctypes.CDLL(None, use_errno=True)
        self.fd = self.libc.inotify_init1(os.O_NONBLOCK | os.O_CLOEXEC)
        if self.fd < 0: raise OSError(ctypes.get_errno(), 'inotify_init1')
        self.watches = {}
        self.refresh()

    def refresh(self):
        desired = set()
        for directory in (self.path.parent, self.path.parent.parent,
                          self.path.parent.parent.parent, self.path.parent.resolve()):
            while not directory.is_dir() and directory != directory.parent:
                directory = directory.parent
            desired.add(directory)
        for directory in set(self.watches)-desired:
            self.libc.inotify_rm_watch(self.fd, self.watches.pop(directory))
        for directory in desired:
            # Re-adding is harmless, and repairs watches invalidated by IN_IGNORED.
            watch = self.libc.inotify_add_watch(self.fd, os.fsencode(directory),
                     0x2 | 0x4 | 0x8 | 0x40 | 0x80 | 0x100 | 0x200 | 0x400 | 0x800)
            if watch >= 0: self.watches[directory] = watch

    def changed(self, timeout=None):
        if not select.select([self.fd], [], [], timeout)[0]: return False
        while True:
            try:
                if not os.read(self.fd, 65536): break
            except BlockingIOError: break
        self.refresh()
        return True

    def close(self):
        os.close(self.fd)


def watch(path, emit, stabilization=.150):
    notifications = PaletteNotifications(path)
    emitted = None
    try:
        # Startup is immediate. Invalid/incomplete writes keep the last good value.
        while True:
            try:
                value = read_palette(path)
                if value['revision'] != emitted:
                    emit(value)
                    emitted = value['revision']
            except (OSError, ValueError, tomllib.TOMLDecodeError):
                pass
            notifications.changed()
            deadline = time.monotonic()+stabilization
            while notifications.changed(max(0, deadline-time.monotonic())):
                deadline = time.monotonic()+stabilization
    finally:
        notifications.close()


def main():
    path = Path(os.environ.get('XDG_STATE_HOME', str(Path.home()/'.local/state'))) / 'omarchy/current/theme/colors.toml'
    emit = lambda value: print(json.dumps(value), flush=True)
    if '--watch' in sys.argv: watch(path, emit)
    else:
        try: emit(read_palette(path))
        except (OSError, ValueError) as error: raise SystemExit(str(error))


if __name__ == '__main__': main()
