"""Remove only owned backend files, including bytecode from older installations."""
from pathlib import Path
import tempfile
import unittest
from package_test import ROOT, module

uninstall = module('uninstall', ROOT/'system/uninstall.py')


class UninstallTests(unittest.TestCase):
    def test_owned_bytecode_and_empty_directory_removed(self):
        with tempfile.TemporaryDirectory() as temporary:
            code = Path(temporary)/'backend'
            cache = code/'__pycache__'; cache.mkdir(parents=True)
            (code/'network.py').write_text('old')
            for name in ('network.cpython-313.pyc', 'network.cpython-314.pyc'):
                (cache/name).write_bytes(b'old bytecode')
            uninstall.remove_backend_files(code)
            self.assertFalse(code.exists())

    def test_unknown_files_and_symlink_target_preserved(self):
        with tempfile.TemporaryDirectory() as temporary:
            code = Path(temporary)/'backend'; code.mkdir()
            outside = Path(temporary)/'other'; outside.mkdir()
            saved = outside/'network.cpython-314.pyc'; saved.write_bytes(b'keep')
            (code/'__pycache__').symlink_to(outside, target_is_directory=True)
            (code/'personal').write_text('keep')
            uninstall.remove_backend_files(code)
            self.assertEqual(saved.read_bytes(), b'keep')
            self.assertEqual((code/'personal').read_text(), 'keep')
            self.assertTrue((code/'__pycache__').is_symlink())
