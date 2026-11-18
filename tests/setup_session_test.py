"""One terminal authenticates once; privileged work never includes user builds."""
import importlib.util
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'install'))
spec = importlib.util.spec_from_file_location('setup_session', ROOT/'install/setup-session.py')
session = importlib.util.module_from_spec(spec); spec.loader.exec_module(session)


class SetupSessionTests(unittest.TestCase):
    def state(self, **updates):
        value = dict(missingRuntimePackages=['tor'], missingBuildPackages=['cmake'],
                     buildRequired=True, backendCompatible=False, backendCurrent=False,
                     enrolled=False, socketReady=False, browserReady=False, ready=False,
                     issues=['Incomplete'])
        value.update(updates)
        return value

    def exercise(self, initial, fail=None):
        calls = []
        def run(args, **kwargs):
            calls.append(args)
            if fail and any(fail in str(arg) for arg in args):
                raise subprocess.CalledProcessError(1, args)
            return subprocess.CompletedProcess(args, 0)
        with patch.object(session.os, 'geteuid', return_value=1000), \
             patch.object(session.setup_status, 'status', side_effect=[initial, self.state(ready=True, issues=[])]), \
             patch.object(session.setup_status, 'tor_version_status', return_value=('0.4.9.14', '')), \
             patch.object(session.subprocess, 'run', side_effect=run), \
             patch.object(session.subprocess, 'check_output', return_value=''):
            if fail:
                with self.assertRaises(subprocess.CalledProcessError): session.install()
            else: session.install()
        return calls

    def test_one_authentication_packages_then_user_build_then_backend(self):
        calls = self.exercise(self.state())
        self.assertEqual(calls.count(['sudo', '-v']), 1)
        self.assertIn(['omarchy', 'pkg', 'add', 'cmake', 'tor'], calls)
        build = [sys.executable, '-B', str(ROOT/'tools/build-native.py')]
        backend = ['sudo', '-n', '/usr/bin/python3', '-I', str(ROOT/'system/install.py')]
        browser = [sys.executable, '-B', str(ROOT/'install/browser_install.py')]
        self.assertLess(calls.index(build), calls.index(backend))
        self.assertLess(calls.index(backend), calls.index(['sudo', '-k']))
        self.assertLess(calls.index(['sudo', '-k']), calls.index(browser))
        self.assertFalse(any(c[0]=='sudo' and 'build-native.py' in ' '.join(c) for c in calls))

    def test_failure_releases_auth_and_stops_later_steps(self):
        calls = self.exercise(self.state(), fail='build-native.py')
        self.assertEqual(calls.count(['sudo', '-v']), 1)
        self.assertEqual(calls[-1], ['sudo', '-k'])
        self.assertFalse(any('system/install.py' in ' '.join(c) for c in calls))

    def test_browser_only_repair_needs_no_authentication(self):
        calls = self.exercise(self.state(missingRuntimePackages=[], buildRequired=False,
            backendCompatible=True, backendCurrent=True, enrolled=True, socketReady=True))
        self.assertFalse(any(c[0]=='sudo' for c in calls))
        self.assertTrue(any('browser_install.py' in ' '.join(c) for c in calls))

    def test_authentication_cancel_does_not_start_installation(self):
        calls = self.exercise(self.state(), fail='-v')
        self.assertEqual(calls[-1], ['sudo', '-v'])
        self.assertFalse(any(c[0]=='omarchy' for c in calls))

    def test_reject_root_and_ignore_unused_build_prerequisites(self):
        with patch.object(session.os, 'geteuid', return_value=0):
            with self.assertRaisesRegex(RuntimeError, 'desktop user'): session.install()
        self.assertEqual(session.prerequisites(self.state(buildRequired=False)), ['tor'])
