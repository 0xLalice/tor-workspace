from pathlib import Path
import os
import re
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'backend'))
import share_page
from onionshare_cli.common import Common
from flask import Flask, render_template

class SharePageTests(unittest.TestCase):
    def test_installed_version_keeps_template_shape_checks(self):
        # Do not substitute version strings: that never tests the other version's assets.
        with tempfile.TemporaryDirectory() as tmp:
            dest=share_page.prepare_overlay(Common(),Path(tmp)/'overlay')
            self.assertTrue((dest/'templates/send.html').is_file())
    def test_page_escaping_download_and_no_external_assets(self):
        with tempfile.TemporaryDirectory() as tmp:
            dest=share_page.prepare_overlay(Common(),Path(tmp)/'overlay')
            app=Flask(__name__,template_folder=str(dest/'templates'))
            with app.app_context():
                html=render_template('send.html',files=[dict(basename='<script>alert(1)</script>.txt',link='/encoded-file',size_human='12 B')],static_url_path='/assets')
                self.assertIn('&lt;script&gt;',html);self.assertNotIn('<script',html)
                self.assertIn('href="/encoded-file" download',html)
                self.assertNotIn('https://',html);self.assertNotIn('http://',html)
                self.assertIn('/assets/workspace.css',html)
                for code in ('403','404','405','500'):
                    self.assertIn('Unavailable',render_template(code+'.html',static_url_path='/assets'))
            self.assertTrue((dest/'static/workspace.css').is_file())

    def test_chat_template_keeps_upstream_protocol_hooks(self):
        with tempfile.TemporaryDirectory() as tmp:
            dest=share_page.prepare_overlay(Common(),Path(tmp)/'overlay','chat')
            app=Flask(__name__,template_folder=str(dest/'templates'))
            with app.app_context():html=render_template('chat.html',username='<test>',static_url_path='/assets')
            self.assertIn('&lt;test&gt;',html)
            for identity in ('username','username-error','chat','new-message','user-list'):
                self.assertIn('id="'+identity+'"',html)
            self.assertIn('/assets/js/chat.js',html)
            self.assertNotIn('https://',html)
            scripts=re.findall(r'<script src="/assets/([^"]+)"',html)
            self.assertEqual(len(scripts),3)
            for script in scripts:self.assertTrue((dest/'static'/script).is_file(),script)
            self.assertIn('id="chat-loading"',html)

    def test_missing_chat_dependency_rejects_custom_page(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            import shutil
            common=Common()
            for kind in ('templates','static'):shutil.copytree(common.get_resource_path(kind),root/kind)
            for script in (root/'static/js').glob('jquery*.js'):script.unlink()
            with patch.object(common,'get_resource_path',side_effect=lambda kind:str(root/kind)):
                with self.assertRaisesRegex(RuntimeError,'chat scripts'):
                    share_page.prepare_overlay(common,root/'overlay','chat')

    def test_colors_are_validated(self):
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/'colors.json';path.write_text('{"accent":"red;}body{display:none}","background":"#ffffff"}')
            with patch.dict(os.environ,TOR_SHARE_COLORS=str(path)):
                colors=share_page.colors()
            self.assertEqual(colors['accent'],share_page.DEFAULTS['accent']);self.assertEqual(colors['background'],'#ffffff')

    def test_incompatible_version_falls_back(self):
        for version in ('2.6.3', '9.0'):
            with self.subTest(version=version), patch.object(share_page.importlib.metadata,'version',return_value=version),patch('onionshare_cli.main',return_value=0) as main:
                self.assertEqual(share_page.main(),0);main.assert_called_once()

    def test_publication_progress_also_works_without_custom_styling(self):
        import contextlib
        import io
        import onionshare_cli
        for styled in (False,True):
            with self.subTest(styled=styled):
                original=onionshare_cli.Onion
                original_common=onionshare_cli.Common
                def run():
                    onion=object.__new__(onionshare_cli.Onion)
                    return onion.start_onion_service('share',{},1234,True)
                output=io.StringIO()
                with patch.object(share_page,'prepare_overlay',side_effect=None if styled else RuntimeError(),return_value=Path('/unused')),patch.object(original,'start_onion_service',return_value='published') as publish,patch.object(onionshare_cli,'main',side_effect=run),contextlib.redirect_stdout(output):
                    self.assertEqual(share_page.main(),'published')
                publish.assert_called_once_with('share',{},1234,True)
                self.assertIn('WORKSPACE_PUBLISHING',output.getvalue())
                self.assertIs(onionshare_cli.Onion,original)
                self.assertIs(onionshare_cli.Common,original_common)

if __name__=='__main__':unittest.main()
