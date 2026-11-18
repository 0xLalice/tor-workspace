#!/usr/bin/env python3
"""Explicit Tor application launch paths. Never substitute a normal app after failure."""
import importlib.util
import tempfile
import json
import os
from pathlib import Path
import subprocess
import sys

# Omarchy watches the plugin tree. Imported helper caches would reload the UI
# while an application or file picker is opening.
sys.dont_write_bytecode = True

BACKEND = Path('/usr/local/lib/omarchy-tor/client.py')
BROWSER = Path.home() / '.local/share/omarchy-tor/tor-browser/Browser'
GATEWAY = Path('/run/omarchy-tor-native') / (str(os.getuid()) + '-io')


def run(argv, **kw):
    return subprocess.run(argv, check=True, **kw)


def prepare_profile():
    profile = Path.home() / '.local/share/omarchy-tor/browser-profile'
    if not profile.exists():
        import shutil
        original=BROWSER / 'TorBrowser/Data/Browser/profile.default'
        if original.is_dir(): shutil.copytree(original,profile)
        else: profile.mkdir(mode=0o700,parents=True)
    return profile


def terminal_client():
    spec = importlib.util.spec_from_file_location('tor_terminal_client', BACKEND)
    client = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(client)
    return client


def terminal_session():
    # Import the installed client API so a shell's nonzero exit is distinguishable
    # from a transport failure, without changing the privileged backend.
    import backend
    client = terminal_client()
    from terminal_info import ExitDisplay, local_state, render
    from exit_controller import wait_ready
    print(render(local_state(), sys.stdout.isatty()), end='', flush=True)
    display = ExitDisplay(cancel_label='cancel')
    generation = None
    with tempfile.TemporaryDirectory(prefix='tor-terminal-') as directory:
        ready = Path(directory) / 'ready'
        previous = {key: os.environ.get(key) for key in ('TOR_TERMINAL_READY', 'TOR_TERMINAL_HEADER_SHOWN')}
        os.environ.update(TOR_TERMINAL_READY=str(ready), TOR_TERMINAL_HEADER_SHOWN='1')
        try:
            display.tick('Checking Tor route…')
            wait_ready(timeout=60, on_progress=display.tick)
            generation = backend.gateway_generation()
            display.clear()
            return client.request('run', ['/bin/bash', '--rcfile',
                str(Path(__file__).resolve().parents[1]/'integration/tor-bashrc'), '-i'])
        except KeyboardInterrupt:
            display.result_line('Tor terminal cancelled.')
            return 130
        except (OSError, ValueError, RuntimeError) as error:
            if ready.exists():
                message = terminal_end_message(generation)
            else:
                message = 'Tor terminal could not start. ' + str(error)
            display.result_line(message)
            try: input('Press Enter to close. ')
            except (EOFError, KeyboardInterrupt): pass
            return 1
        finally:
            display.clear()
            for key, value in previous.items():
                if value is None: os.environ.pop(key, None)
                else: os.environ[key] = value


def terminal_end_message(generation):
    import backend
    try:
        deliberate = (backend.RUNTIME / 'stopped-generation').read_text() == generation
    except OSError:
        deliberate = False
    return ('Tor stopped.' if deliberate else 'Tor connection lost.') + ' This terminal session has ended.'


def browser_environment():
    env = dict(os.environ)
    for key in list(env):
        if key.startswith('TOR_'):
            del env[key]
    env.update(TOR_SKIP_LAUNCH='1', TOR_SOCKS_IPC_PATH=str(GATEWAY / 'socks'),
               TOR_CONTROL_IPC_PATH=str(GATEWAY / 'control'),
               TOR_CONTROL_COOKIE_AUTH_FILE=str(GATEWAY / 'cookie'),
               MOZ_ENABLE_WAYLAND='1', MOZ_APP_REMOTINGNAME='org.omarchy.tor-browser',
               LD_LIBRARY_PATH=str(BROWSER), GSETTINGS_BACKEND='memory')
    return env


def chat_browser(hosting=False):
    import chat
    import backend
    if hosting:
        import host
    url = host.ready_url() if hosting else chat.ready_url()
    window_class = ('org.omarchy.tor-host-' if hosting else 'org.omarchy.tor-chat-') + url.split('//')[1][:12]
    clients = json.loads(run(['hyprctl', '-j', 'clients'], capture_output=True, text=True).stdout)
    existing = next((w for w in clients if w.get('class') == window_class), None)
    if existing:
        run(['hyprctl', 'dispatch', 'hl.dsp.focus({window=' + json.dumps('address:' + existing['address']) + '})'])
        return 0
    if not (BROWSER / 'firefox').is_file():
        raise RuntimeError('Tor Browser is missing.')
    backend.prepare()
    with tempfile.TemporaryDirectory(prefix='chat-browser-', dir=backend.RUNTIME) as profile:
        env = browser_environment()
        env['MOZ_APP_REMOTINGNAME'] = window_class
        return subprocess.run(['python3', str(BACKEND), 'browser', str(BROWSER / 'firefox'),
            '--no-remote', '--class', window_class, '--name', window_class,
            '--profile', profile, url], env=env, cwd=BROWSER).returncode


def darknet_browser():
    """Always open the fixed search page in its own Tor-routed browser window."""
    import backend
    if not (BROWSER / 'firefox').is_file():
        raise RuntimeError('Tor Browser is missing.')
    backend.prepare()
    with tempfile.TemporaryDirectory(prefix='search-browser-', dir=backend.RUNTIME) as profile:
        env = browser_environment()
        window_class = 'org.omarchy.tor-search'
        env['MOZ_APP_REMOTINGNAME'] = window_class
        return subprocess.run(['python3', str(BACKEND), 'browser', str(BROWSER / 'firefox'),
            '--no-remote', '--class', window_class, '--name', window_class,
            '--profile', profile, 'http://juhanurmihxlp77nkq76byazcldy2hlmovfu2epvl5ankdibsot4csyd.onion/'], env=env, cwd=BROWSER).returncode


def main(args):
    action = args[0]
    if action == 'terminal':
        os.execvp('foot', ['foot', '--app-id=org.omarchy.tor-terminal', '--title=Tor Terminal',
                          'python3', str(Path(__file__).resolve()), 'shell-session'])
    if action == 'shell-session':
        return terminal_session()
    if action in ('browser','chat-browser','host-browser','darknet-browser'):
        from backend import Controller
        try:
            with Controller() as control:control.command('GETINFO status/bootstrap-phase')
        except (OSError,RuntimeError) as error:
            raise RuntimeError('Tor is off. Open Tor Workspace and choose Start Tor first.') from error
        from exit_controller import wait_ready
        wait_ready()
    if action == 'darknet-browser':
        return darknet_browser()
    if action in ('chat-browser', 'host-browser'):
        return chat_browser(action == 'host-browser')
    if action == 'browser':

        if not (BROWSER / 'firefox').is_file():
            raise RuntimeError('Tor Browser is missing from ' + str(BROWSER))
        # Focus only our dedicated instance, never a normal Firefox/Tor session.
        clients = json.loads(run(['hyprctl', '-j', 'clients'], capture_output=True, text=True).stdout)
        existing = next((w for w in clients if w.get('class') == 'org.omarchy.tor-browser'), None)
        if existing:
            run(['hyprctl', 'dispatch', 'hl.dsp.focus({window=' + json.dumps('address:' + existing['address']) + '})'])
            return 0
        env = browser_environment()
        profile = prepare_profile()
        return subprocess.run(['python3', str(BACKEND), 'browser', str(BROWSER / 'firefox'),
                               '--no-remote', '--class', 'org.omarchy.tor-browser',
                               '--name', 'org.omarchy.tor-browser', '--profile', str(profile),
                               'https://check.torproject.org/'], env=env, cwd=BROWSER).returncode
    raise ValueError('Unknown launch action')


if __name__ == '__main__':
    try:
        sys.exit(main(sys.argv[1:]))
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(str(error), file=sys.stderr)
        subprocess.run(['notify-send', 'Tor workspace', str(error)])
        sys.exit(1)
