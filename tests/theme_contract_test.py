"""Presentation presets remain data: no per-theme application implementation."""
import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'backend'))
sys.path.insert(0,str(ROOT/'tools'))
import published_theme
from preset_schema import validate
from sync_themes import sync

class ThemeContract(unittest.TestCase):
    def test_additional_catalog_entries_need_only_json(self):
        with tempfile.TemporaryDirectory() as folder:
            assets=Path(folder)/'assets';themes=assets/'themes';themes.mkdir(parents=True)
            names=[]
            for i in range(10):
                preset=copy.deepcopy(published_theme.builtins()[0]);name=f'extra-{i}'
                preset.update(id=name,name=f'Extra {i}')
                preset['interface']['design']=name
                preset['interface']['style'].update(actionLayout='arc' if i%2 else 'flow',padding=16+i)
                names.append(name);(themes/(name+'.json')).write_text(json.dumps(preset))
            (assets/'theme-catalog.json').write_text(json.dumps(names))
            with patch.object(published_theme,'BUILTINS',themes):
                self.assertEqual([theme['id'] for theme in published_theme.builtins()],names)

    def test_style_boundary_and_recovery(self):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'published.json';runtime=published_theme.PublishedTheme(path)
            good=copy.deepcopy(runtime.read()['preset']);good.update(id='new-theme',name='New theme')
            good['interface']['design']='new-theme';good['interface']['style']['actionLayout']='arc'
            path.write_text(json.dumps(good));self.assertEqual(runtime.read()['preset'],good)
            for style in (None,[],{'actionLayout':'unknown'},{'enabled':True},{'title':'New wording'},
                          {'fontFamily':'fixed'},{'build':-1},{'outline':.5},{'padding':True},{'cameraBlend':float('inf')}):
                invalid=copy.deepcopy(good);invalid['interface']['style']=style
                with self.assertRaises(ValueError):validate(invalid)
                path.write_text(json.dumps(invalid));result=runtime.read()
                self.assertTrue(result['error']);self.assertEqual(result['preset'],good)

    def test_generated_bootstrap_matches_authoring_sources(self):
        sync(check=True)

    def test_shared_ui_has_no_theme_identity_branches_or_copy_overrides(self):
        import re
        for path in (ROOT/'ui').rglob('*.qml'):
            text=path.read_text()
            self.assertIsNone(re.search(r'ThemeDesign\.(original|meridian|porcelain|sentence)\b',text),str(path))
            self.assertIsNone(re.search(r'\.design\s*[!=]==?\s*["\'](?:original|meridian|porcelain)',text),str(path))
        self.assertNotIn('var sentences=',(ROOT/'ui/theme/DesignDefinitions.js').read_text())

if __name__=='__main__':unittest.main()
