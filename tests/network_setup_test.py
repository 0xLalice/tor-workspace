"""Unprivileged regressions for the native setup and fail-closed launch ordering."""
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('native', ROOT / 'system/tor_workspace.py')
native = importlib.util.module_from_spec(spec)
spec.loader.exec_module(native)


class NativeTests(unittest.TestCase):
    def setup_attempt(self, fail_firewall=False):
        calls = []
        def call(args, **kw):
            args = list(map(str, args))
            calls.append((args, kw))
            if args[:3] == ['/usr/bin/nft', '-f', '-'] and fail_firewall:
                raise subprocess.CalledProcessError(1, args)
            output = '[]' if 'route' in args else ''
            missing = ('link' in args and 'show' in args) or args[:3] == ['/usr/bin/nft', 'list', 'table']
            return subprocess.CompletedProcess(args, 1 if missing else 0, output, '')
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            with patch.multiple(native, UID=os.getuid(), NS='test-tor-unprivileged',
                                STATE=base / 'runtime/state.json', CONFIG=base / 'resolver'), \
                 patch.object(native, 'call', side_effect=call), \
                 patch.object(native, 'gateway_item', return_value={'State':{'Running':False}}), \
                 patch.object(native.os, 'chown'):
                if fail_firewall:
                    with self.assertRaises(subprocess.CalledProcessError):
                        native.up()
                else:
                    native.up()
                    self.assertEqual((base / 'resolver/resolv.conf').read_text().splitlines()[0], 'nameserver 10.77.0.1')
                    self.assertIn('hosts: files dns', (base / 'resolver/nsswitch.conf').read_text())
        return calls

    def test_firewall_precedes_link_and_setup_never_starts_tor(self):
        calls = self.setup_attempt()
        commands = [args for args, _ in calls]
        guard = next(i for i, a in enumerate(commands) if a[:3] == ['/usr/bin/nft','-f','-'])
        link = next(i for i, a in enumerate(commands) if a[:4] == ['/usr/bin/ip','link','add', 'ot'+str(os.getuid())])
        self.assertLess(guard, link)
        self.assertFalse(any(a[0] in ('/usr/bin/systemd-run', '/usr/bin/tor') or
                             (a[0] == '/usr/bin/systemctl' and 'start' in a) for a in commands))
        self.assertFalse(any('docker' in a for command in commands for a in command))

    def test_failed_guard_never_exposes_link_or_starts_tor(self):
        calls = self.setup_attempt(fail_firewall=True)
        self.assertFalse(any(args[:3] == ['/usr/bin/ip','link','add'] for args, _ in calls))
        self.assertFalse(any(args[0] == '/usr/bin/systemd-run' for args, _ in calls))

    def test_exit_country_cannot_inject_tor_directives(self):
        for country in ('DE\nDisableNetwork 1', '{de}', 'xx', 'DE,US', None):
            with self.assertRaises(RuntimeError):
                native.tor_config(1000, country)
        self.assertIn('ExitNodes {de}\n', native.tor_config(1000, 'DE'))
        self.assertNotIn('ExitNodes', native.tor_config(1000))
        self.assertNotIn('0.0.0.0:', native.tor_config(1000))

    def test_old_build_command_does_not_authenticate(self):
        result = subprocess.run(['python3', str(ROOT/'system/tor_workspace.py'), 'build'], capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn('no standalone actions', result.stderr)

    def test_help_never_authenticates(self):
        result = subprocess.run(['python3', str(ROOT/'system/tor_workspace.py'), '--help'], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0)
        self.assertIn('install/setup-session.py', result.stdout)


if __name__ == '__main__':
    unittest.main()
