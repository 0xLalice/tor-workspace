"""The only test fixtures for obsolete preference formats live here."""
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch, Mock
sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'backend'))
import backend
import country_migration

class Migration(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(); self.addCleanup(temp.cleanup)
        for key in ('DATA', 'RUNTIME'):
            p = patch.object(backend, key, Path(temp.name)/key); p.start(); self.addCleanup(p.stop)
        backend.prepare()

    def test_old_formats_keep_only_country(self):
        for mode in ('locked', 'automatic'):
            target = backend.DATA/'country-policy.json'; target.unlink(missing_ok=True)
            old = backend.DATA/'exit-policy.json'
            old.write_text(json.dumps(dict(mode=mode, fingerprint='A'*40, country='DE')))
            journal = backend.RUNTIME/'recovery.json'; journal.write_text('{"exhausted":true}')
            control = Mock()
            value = country_migration.migrate(control)
            self.assertEqual(value, {'api':3, 'country':'DE'})
            control.command.assert_called_once_with('SETCONF ExitNodes={de} StrictNodes=1')
            self.assertFalse(old.exists()); self.assertFalse(journal.exists())
            self.assertEqual(json.loads(target.read_text()), value)

    def test_older_country_and_idempotence(self):
        old = backend.DATA/'exit-country.json'; old.write_text('"DE"')
        country_migration.migrate()
        self.assertFalse(old.exists())
        self.assertEqual(country_migration.migrate()['country'], 'DE')

    def test_no_country_removes_fingerprint(self):
        (backend.DATA/'exit-policy.json').write_text('{"fingerprint":"ABC","country":""}')
        control = Mock(); country_migration.migrate(control)
        control.command.assert_called_once_with('SETCONF ExitNodes="" StrictNodes=1')

    def test_control_failure_keeps_legacy_files(self):
        old = backend.DATA/'exit-policy.json'; old.write_text('{"country":"DE"}')
        with self.assertRaises(RuntimeError):
            country_migration.migrate(Mock(command=Mock(side_effect=RuntimeError('rejected'))))
        self.assertTrue(old.exists()); self.assertFalse((backend.DATA/'country-policy.json').exists())

    def test_invalid_country_keeps_legacy_files(self):
        old = backend.DATA/'exit-policy.json'; old.write_text('{"country":"DE\\nHALT"}')
        with self.assertRaises(ValueError): country_migration.migrate()
        self.assertTrue(old.exists())
