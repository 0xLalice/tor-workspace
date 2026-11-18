"""Paired shortcut allocation, ownership and persistence without a compositor."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('shortcuts',ROOT/'backend/shortcuts.py')
shortcuts=importlib.util.module_from_spec(spec);spec.loader.exec_module(shortcuts)
def binding(key,mask,description='User action',**extra):
    return dict(key=key,modmask=mask,description=description,**extra)
class ShortcutTests(unittest.TestCase):
    def test_default_is_super_u_pair(self):
        self.assertEqual(shortcuts.select({},[]),{'open':'SUPER + U','move':'SUPER + SHIFT + U'})
    def test_either_occupied_half_rejects_whole_pair(self):
        for mask in (64,65):
            self.assertEqual(shortcuts.select({},[binding('U',mask)]),shortcuts.pair('I'))
    def test_no_free_pair_stays_unassigned(self):
        self.assertEqual(shortcuts.select({},[binding(k,64) for k in shortcuts.CANDIDATES]),shortcuts.pair(''))
    def test_previous_defaults_migrate_to_free_pair(self):
        for key in ('O','U'):
            old={'open':'SUPER + ALT + '+key,'move':'SUPER + ALT + SHIFT + '+key}
            self.assertEqual(shortcuts.select(old,[]),shortcuts.pair('U'))
    def test_cleared_pair_remains_cleared(self):
        self.assertEqual(shortcuts.select(shortcuts.pair(''),[]),shortcuts.pair(''))
    def test_custom_pair_is_preserved(self):
        self.assertEqual(shortcuts.select(shortcuts.pair('Z'),[]),shortcuts.pair('Z'))
    def test_owned_handles_only(self):
        with patch.object(shortcuts,'hypr',return_value='ok') as run:
            shortcuts.apply(shortcuts.pair('U'),[])
        lua=run.call_args.args[1]
        self.assertIn('h:remove()',lua);self.assertNotIn('hl.unbind',lua)
        self.assertIn('follow=true',lua)
    def test_conflict_rebind_is_atomic(self):
        with tempfile.TemporaryDirectory() as directory,patch.object(shortcuts,'CONFIG',Path(directory)),patch.object(shortcuts,'bindings',return_value=[binding('I',65)]),patch.object(shortcuts,'apply') as apply:
            shortcuts.save(shortcuts.pair('U'))
            with self.assertRaisesRegex(ValueError,'used by'):shortcuts.execute('set','pair','I')
            self.assertEqual(shortcuts.load(),shortcuts.pair('U'));apply.assert_not_called()
    def test_rebind_both_and_persist_clear(self):
        with tempfile.TemporaryDirectory() as directory,patch.object(shortcuts,'CONFIG',Path(directory)),patch.object(shortcuts,'bindings',return_value=[]),patch.object(shortcuts,'apply'):
            shortcuts.execute('set','pair','z')
            self.assertEqual(shortcuts.load(),shortcuts.pair('Z'))
            shortcuts.execute('set','pair','');shortcuts.execute('sync')
            self.assertEqual(shortcuts.load(),shortcuts.pair(''))
    def test_invalid_key_rejected(self):
        for value in ['SUPER + T','1','U;print(1)','UU']:
            with self.assertRaises(ValueError):shortcuts.pair(value)
    def test_remove_preserves_settings(self):
        with tempfile.TemporaryDirectory() as directory,patch.object(shortcuts,'CONFIG',Path(directory)),patch.object(shortcuts,'bindings',return_value=[]),patch.object(shortcuts,'apply') as apply:
            shortcuts.save(shortcuts.pair('U'));shortcuts.execute('remove')
            apply.assert_called_once_with({},[])
            self.assertEqual(shortcuts.load(),shortcuts.pair('U'))
