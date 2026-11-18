import fcntl
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'backend'))
import backend
import exit_controller


class OriginTests(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        for name in ('RUNTIME', 'DATA', 'GATEWAY'):
            p = patch.object(backend, name, Path(tmp.name) / name)
            p.start()
            self.addCleanup(p.stop)
        backend.prepare()
        backend.GATEWAY.mkdir()
        (backend.GATEWAY / 'control').touch()
        for name, value in [('host_network', True), ('query_origin',
                dict(role='You', country='TH', ip='198.51.100.1'))]:
            p = patch.object(backend, name, return_value=value)
            setattr(self, name, p.start())
            self.addCleanup(p.stop)

    def test_cold_boot_returns_promptly_then_maps_real_origin(self):
        with patch.object(backend.subprocess, 'Popen') as spawn:
            first = backend.with_origin(dict(running=True, origin={}))
        self.assertEqual(first['originState'], 'checking')
        spawn.assert_called_once()
        backend.refresh_origin()
        value = backend.with_origin(dict(running=True, origin={}))
        self.assertEqual(value['originState'], 'ready')
        self.assertEqual(value['origin']['country'], 'TH')
        self.assertIn('longitude', value['origin'])
        backend.refresh_origin()
        self.query_origin.assert_called_once()

    def test_offline_reads_and_preferences_never_start_any_process(self):
        (backend.GATEWAY / 'control').unlink()
        with patch.object(exit_controller, 'rpc', side_effect=FileNotFoundError), \
             patch.object(backend.subprocess, 'Popen') as spawn:
            for action, value in [('cached', None), ('status', None), ('set-country', 'TH')]:
                self.assertFalse(backend.request(action, value)['running'])
            backend.refresh_origin()
        spawn.assert_not_called()
        self.query_origin.assert_not_called()

    def test_namespace_never_probes_exit_as_origin(self):
        self.host_network.return_value = False
        with patch.object(backend.subprocess, 'Popen') as spawn:
            backend.with_origin(dict(running=True))
            backend.refresh_origin()
        spawn.assert_not_called()
        self.query_origin.assert_not_called()

    def test_failure_is_explicit_and_retries_after_cooldown(self):
        self.query_origin.return_value = dict(role='You', country='', ip='')
        with patch.object(backend.time, 'time', return_value=100):
            backend.refresh_origin()
            failed = backend.with_origin(dict(running=True))
            backend.refresh_origin()
        self.assertEqual(failed['originState'], 'unavailable')
        self.assertNotIn('longitude', failed['origin'])
        self.query_origin.assert_called_once()
        self.query_origin.return_value = dict(role='You', country='DE', ip='198.51.100.2')
        with patch.object(backend.time, 'time', return_value=131):
            backend.refresh_origin()
            self.assertEqual(backend.with_origin(dict(running=True))['origin']['country'], 'DE')

    def test_parallel_lookup_is_serialized(self):
        with (backend.RUNTIME / 'origin.lock').open('a') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            backend.refresh_origin()
        self.query_origin.assert_not_called()

    def test_runtime_only_and_unchanged_reads_are_stable(self):
        backend.refresh_origin()
        before = backend.with_origin(dict(running=True, revision=42))
        after = backend.with_origin(dict(running=True, revision=42))
        self.assertEqual(before, after)
        self.assertEqual(list(backend.DATA.iterdir()), [])
        self.assertEqual((backend.RUNTIME / 'origin.json').stat().st_mode & 0o777, 0o600)

    def test_refresh_preserves_point_then_updates_changed_connection(self):
        with patch.object(backend.time, 'time', return_value=100):
            backend.refresh_origin()
        def changed_connection():
            during = backend.with_origin(dict(running=True))
            self.assertEqual(during['originState'], 'ready')
            self.assertEqual(during['origin']['country'], 'TH')
            return dict(role='You', country='DE', ip='198.51.100.2')
        self.query_origin.side_effect = changed_connection
        with patch.object(backend.time, 'time', return_value=401):
            backend.refresh_origin()
            self.assertEqual(backend.with_origin(dict(running=True))['origin']['country'], 'DE')


class NamespaceTests(unittest.TestCase):
    def test_namespace_check_fails_closed(self):
        with patch.object(backend.os.path, 'samefile', return_value=True):
            self.assertFalse(backend.host_network())
        with patch.object(backend.os.path, 'samefile', return_value=False):
            self.assertTrue(backend.host_network())
        with patch.object(backend.os.path, 'samefile', side_effect=PermissionError):
            self.assertFalse(backend.host_network())


if __name__ == '__main__':
    unittest.main()
