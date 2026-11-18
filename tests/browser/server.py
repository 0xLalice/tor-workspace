"""Loopback-only real OnionShare web server for development integration tests.

Replace only the CLI entry point that would publish to Tor. Templates, script
loading, Socket.IO, download preparation and HTTP serving are the real code.
"""
import sys
from pathlib import Path
from types import SimpleNamespace

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'backend'))
import onionshare_cli
import share_page

mode, port, fixture = sys.argv[1:]
if Path('/usr/share/anon-ws-base-files/workstation').exists():
    raise SystemExit('This harness requires OnionShare to bind only to loopback.')


def serve():
    settings = SimpleNamespace(get=lambda *keys: False)
    web = onionshare_cli.Web(onionshare_cli.Common(), False, settings, mode=mode)
    if mode == 'share':
        web.share_mode.set_file_info([fixture])
    elif mode == 'website':
        web.website_mode.set_file_info([str(p) for p in Path(fixture).iterdir()])
    web.start(int(port))


onionshare_cli.main = serve
if mode == 'website':
    serve()  # Folder hosting deliberately uses the upstream website UI.
else:
    sys.argv = ['browser-test'] + (['--chat'] if mode == 'chat' else [])
    share_page.main()
