#!/usr/bin/env python3
"""Process-local OnionShare presentation adapter; never edits installed packages."""
import importlib.metadata
import json
import os
from pathlib import Path
import re
import shutil
import tempfile
import threading

ASSETS = Path(__file__).resolve().parents[1]/'assets/web/share'
DEFAULTS = dict(background='#101713', foreground='#e1e4d0', accent='#c0bd83')


def colors():
    try:
        value = json.loads(Path(os.environ['TOR_SHARE_COLORS']).read_text())
    except (OSError, ValueError, KeyError):
        value = {}
    if not isinstance(value, dict): value = {}
    return {key: value.get(key) if isinstance(value.get(key), str) and re.fullmatch(r'#[0-9a-fA-F]{6}', value[key]) else default
            for key, default in DEFAULTS.items()}


def prepare_overlay(common, destination, mode="share"):
    if importlib.metadata.version('onionshare_cli') != '2.6.5':
        raise RuntimeError('Untested OnionShare template interface')
    destination = Path(destination)
    for kind in ('templates', 'static'):
        shutil.copytree(common.get_resource_path(kind), destination / kind)
    source = (destination / 'templates/send.html').read_text()
    if not all(field in source for field in ('info.link', 'filesize_human', 'static_url_path')):
        raise RuntimeError('Incompatible download template')
    assets = ASSETS if mode == 'share' else ASSETS.parent/'chat'
    template = 'send.html' if mode == 'share' else 'chat.html'
    markup = (assets / template).read_text()
    if mode == 'chat':
        upstream = (destination / 'templates/chat.html').read_text()
        scripts = re.findall(r'<script\b[^>]*\bsrc="\{\{ static_url_path \}\}/(js/[\w.-]+\.js)"', upstream)
        if (len(scripts) != 3 or not re.fullmatch(r'js/jquery-[\w.-]+\.js', scripts[0])
                or scripts[1:] != ['js/socket.io.min.js', 'js/chat.js']
                or any(not (destination / 'static' / script).is_file() for script in scripts)):
            raise RuntimeError('Incompatible chat scripts')
        markup = markup.replace('<!-- WORKSPACE_CHAT_SCRIPTS -->', '\n'.join(
            '<script src="{{ static_url_path }}/' + script + '"></script>' for script in scripts))
    (destination / 'templates' / template).write_text(markup)
    for code in ('403', '404', '405', '500'):
        text = (ASSETS / 'error.html').read_text().replace('ERROR_CODE', code)
        (destination / ('templates/' + code + '.html')).write_text(text)
    palette = colors()
    css = ':root{' + ''.join('--' + k + ':' + v + ';' for k, v in palette.items()) + '}\n'
    (destination / 'static/workspace.css').write_text(css + (assets / 'style.css').read_text())
    return destination


def main():
    import onionshare_cli
    original = onionshare_cli.Common
    original_onion = onionshare_cli.Onion
    original_web = onionshare_cli.Web
    class WorkspaceWeb(original_web):
        def start(self, port):
            if self.mode != 'chat': return super().start(port)
            stopped = threading.Event()
            def report():
                while not stopped.is_set():
                    print('WORKSPACE_ROOM_COUNT ' + str(len(self.chat_mode.connected_users)), flush=True)
                    stopped.wait(1)
            reporter = threading.Thread(target=report, daemon=True)
            reporter.start()
            try: return super().start(port)
            finally:
                stopped.set()
                reporter.join(timeout=2)
    class WorkspaceOnion(original_onion):
        def start_onion_service(self, *args, **kwargs):
            print('WORKSPACE_PUBLISHING', flush=True)
            return super().start_onion_service(*args, **kwargs)
    with tempfile.TemporaryDirectory(prefix='share-page-') as temporary:
        try:
            import sys
            overlay = prepare_overlay(original(), Path(temporary) / 'resources', 'chat' if '--chat' in sys.argv else 'share')
        except Exception:
            print('WORKSPACE_STYLE_UNAVAILABLE', flush=True)
        else:
            class StyledCommon(original):
                def get_resource_path(self, filename):
                    if filename in ('templates', 'static'):
                        return str(overlay / filename)
                    return super().get_resource_path(filename)
            onionshare_cli.Common = StyledCommon
        onionshare_cli.Onion = WorkspaceOnion
        onionshare_cli.Web = WorkspaceWeb
        try:
            return onionshare_cli.main()
        finally:
            onionshare_cli.Common = original
            onionshare_cli.Onion = original_onion
            onionshare_cli.Web = original_web


if __name__ == '__main__':
    raise SystemExit(main())
