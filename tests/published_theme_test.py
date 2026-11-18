"""Plugin-side JSON contract; the builder is deliberately not imported."""
import json
from pathlib import Path
import sys
import tempfile
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'backend'))
from published_theme import PublishedTheme

class Publication(unittest.TestCase):
    def test_default_and_last_valid_theme_survive_bad_file(self):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'published.json';runtime=PublishedTheme(path)
            original=runtime.read()['preset']
            self.assertEqual(original['name'],'Osaka Classic')
            theme=json.loads(json.dumps(original));theme['settings']['markerSize']=9
            path.write_text(json.dumps(theme))
            self.assertEqual(runtime.read()['preset'],theme)
            for invalid in ('{invalid',json.dumps({'themes':[]}),json.dumps({'themes':[theme,theme]})):
                path.write_text(invalid)
                result=runtime.read()
                self.assertTrue(result['error'])
                self.assertEqual(result['preset'],theme)

    def test_exported_collection_and_activation(self):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'published.json';runtime=PublishedTheme(path)
            first=runtime.read()['preset'];second=dict(first,id='second',name='Second')
            path.write_text(json.dumps({'themes':[first,second],'activeId':'second','activation':'test'}))
            result=runtime.read()
            self.assertEqual([e['id'] for e in result['entries']],['original','meridian','second'])
            self.assertEqual(result['entries'][0],first)
            self.assertEqual(result['entries'][-1],second)
            self.assertEqual(result['activeId'],'second')
            self.assertEqual(result['activation'],'test')

    def test_file_sharing_alignment_contract_and_last_valid(self):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'published.json';runtime=PublishedTheme(path)
            theme=runtime.read()['preset']
            for alignment in ('center','left'):
                theme['interface']['fileSharing']={key:alignment for key in ('titleAlignment','footerAlignment','addAlignment')}
                path.write_text(json.dumps(theme))
                self.assertEqual(runtime.read()['preset']['interface']['fileSharing'],theme['interface']['fileSharing'])
            good=json.loads(json.dumps(theme))
            for invalid in (None, [], {'addAlignment':'right'}, {'layout':'grid'}):
                theme['interface']['fileSharing']=invalid;path.write_text(json.dumps(theme))
                result=runtime.read();self.assertTrue(result['error']);self.assertEqual(result['preset'],good)

    def test_builtins_merge_by_id_without_writing_publication(self):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'published.json';runtime=PublishedTheme(path)
            self.assertEqual([x['id'] for x in runtime.read()['entries']],['original','meridian'])
            self.assertFalse(path.exists())
            saved=dict(runtime.entries[1],name='My Meridian',appearance=0,settings={'zoom':1.3})
            data=json.dumps({'themes':[saved],'activeId':'meridian','activation':'saved'})
            path.write_text(data);value=runtime.read()
            self.assertEqual(value['entries'][1],dict(saved,name='Jade Orbit'))
            self.assertEqual(value['preset'],dict(saved,name='Jade Orbit'))
            self.assertEqual(path.read_text(),data)

    def test_legacy_and_invalid_design(self):
        from preset_schema import validate
        theme=PublishedTheme().entries[0]
        for version in (1,2):
            legacy=dict(theme,version=version,interface={})
            self.assertEqual(validate(legacy),legacy)
        for design in ('original','meridian','porcelain'):
            validate(dict(theme,interface={'design':design}))
        for design in ('../other','',None,False,{},[]):
            with self.assertRaises(ValueError):validate(dict(theme,interface={'design':design}))
        for appearance in (10,11):validate(dict(theme,appearance=appearance))
        for appearance in (12,-1,True):
            with self.assertRaises(ValueError):validate(dict(theme,appearance=appearance))

    def test_legacy_without_id_and_bad_identity(self):
        from preset_schema import validate
        legacy={'version':1,'name':'Legacy theme','appearance':8,'settings':{}}
        self.assertEqual(validate(legacy)['id'],validate(legacy)['id'])
        self.assertTrue(validate(legacy)['id'].startswith('legacy-'))
        for value in (None,False,[],{},''):
            with self.assertRaises(ValueError):validate(dict(legacy,id=value))

    def test_retired_selection_maps_to_orbit_without_changing_file(self):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'published.json'
            retired=json.loads((Path(__file__).resolve().parents[1]/'assets/themes/porcelain.json').read_text())
            for data in (retired, {'themes':[retired], 'activeId':'porcelain', 'activation':'old'}):
                original=json.dumps(data);path.write_text(original)
                result=PublishedTheme(path).read()
                self.assertEqual(result['preset']['id'],'meridian')
                self.assertEqual([p['id'] for p in result['entries']],['original','meridian'])
                self.assertEqual(path.read_text(),original)
