"""Regression checks for a source plugin installed and updated through Git."""
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


def artifact(target):
    target.mkdir(parents=True)
    for name in [*json.loads((ROOT/'source-hashes.json').read_text()), 'source-hashes.json']:
        dest = target/name
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT/name, dest)
    return target


def git(root, *args):
    return subprocess.check_output(['git','-C',str(root),*args], text=True, stderr=subprocess.STDOUT)


def commit(root, message):
    git(root,'add','.')
    git(root,'-c','user.name=Test','-c','user.email=test@example.invalid','commit','-qm',message)


class PackageTests(unittest.TestCase):
    def test_personal_id_migration_preserves_git_settings_and_backup(self):
        with tempfile.TemporaryDirectory() as temp:
            config = Path(temp)/'config'
            installer = module('id_migration', ROOT/'install/install-user.py')
            old = config/'omarchy/plugins'/installer.LEGACY_ID
            artifact(old); git(old,'init','-b','main'); commit(old,'Initial')
            git(old,'remote','add','origin','https://example.invalid/private.git')
            (config/'hypr').mkdir()
            hypr = config/'hypr/hyprland.lua'
            hypr.write_text('dofile(os.getenv("HOME") .. "/.config/omarchy/plugins/'+installer.LEGACY_ID+'/workspace.lua")\n')
            shell = config/'omarchy/shell.json'
            shell.write_text(json.dumps({'bar':{'layout':{'right':[{'id':installer.LEGACY_ID,'settings':{'custom':True}}]}},'other':42}))
            target = installer.install(old,config,False)
            self.assertEqual(target.name,'tor.workspace')
            self.assertFalse(old.exists())
            self.assertEqual(git(target,'remote','get-url','origin').strip(),'https://example.invalid/private.git')
            self.assertEqual(git(target,'status','--porcelain'),'')
            state = json.loads(shell.read_text())
            self.assertEqual(state['other'],42)
            self.assertEqual(state['bar']['layout']['right'],[{'id':'tor.workspace','settings':{'custom':True}}])
            self.assertNotIn(installer.LEGACY_ID,hypr.read_text())
            self.assertEqual(hypr.read_text().count('integration/workspace.lua'),1)
            self.assertTrue(list((config/'omarchy/tor-workspace-backups').glob('*/omarchy/plugins/'+installer.LEGACY_ID+'/.git')))

    def test_new_git_install_retires_old_local_copy_and_keeps_bar_position(self):
        with tempfile.TemporaryDirectory() as temp:
            config = Path(temp)/'config'
            installer = module('id_local_migration',ROOT/'install/install-user.py')
            target = artifact(config/'omarchy/plugins/tor.workspace')
            git(target,'init','-b','main');commit(target,'New install')
            old = config/'omarchy/plugins'/installer.LEGACY_ID
            old.mkdir();(old/'personal-edit.txt').write_text('Keep this backup')
            shell = config/'omarchy/shell.json'
            shell.write_text(json.dumps({'bar':{'layout':{'left':[{'id':'tor.workspace'}],'right':[{'id':installer.LEGACY_ID}]}}}))
            installer.install(target,config,False)
            self.assertFalse(old.exists())
            self.assertEqual(json.loads(shell.read_text())['bar']['layout'],{'left':[],'right':[{'id':'tor.workspace'}]})
            saved = list((config/'omarchy/tor-workspace-backups').rglob('personal-edit.txt'))
            self.assertEqual(saved[0].read_text(),'Keep this backup')

    def test_in_place_setup_keeps_checkout_placement_and_future_updates(self):
        with tempfile.TemporaryDirectory() as temp:
            base = Path(temp)
            upstream = artifact(base/'upstream')
            git(upstream,'init','-b','main');commit(upstream,'Initial source')
            config = base/'config'
            target = config/'omarchy/plugins/tor.workspace'
            target.parent.mkdir(parents=True)
            subprocess.run(['git','clone','-q',str(upstream),str(target)], check=True)
            (config/'hypr').mkdir()
            (config/'hypr/hyprland.lua').write_text('-- existing config\n')
            shell = config/'omarchy/shell.json'
            shell.write_text(json.dumps({'bar':{'layout':{'right':[{'id':'tor.workspace'}]}},'unrelated':True}))
            installer = module('package_installer',target/'install/install-user.py')
            installer.install(target,config,False)
            installer.install(target,config,False)
            self.assertTrue((target/'.git/config').is_file())
            self.assertEqual(git(target,'status','--porcelain'),'')
            state = json.loads(shell.read_text())
            self.assertTrue(state['unrelated'])
            self.assertEqual(state['bar']['layout'],{'right':[{'id':'tor.workspace'}]})
            self.assertEqual((config/'hypr/hyprland.lua').read_text().count('local tor_workspace'),1)
            # Simulate a new source commit and the same fast-forward Omarchy uses.
            readme=upstream/'README.md';readme.write_text(readme.read_text()+'\nUpdate fixture.\n')
            hashes=json.loads((upstream/'source-hashes.json').read_text())
            hashes['README.md']=hashlib.sha256(readme.read_bytes()).hexdigest()
            (upstream/'source-hashes.json').write_text(json.dumps(hashes,indent=2)+'\n')
            commit(upstream,'Update')
            git(target,'fetch','origin','HEAD');git(target,'merge','--ff-only','FETCH_HEAD')
            self.assertIn('Update fixture.',(target/'README.md').read_text())
            self.assertEqual(git(target,'status','--porcelain'),'')

    def test_git_build_does_not_rewrite_source_inventory(self):
        with tempfile.TemporaryDirectory() as temp:
            source = artifact(Path(temp)/'source')
            git(source,'init','-b','main');commit(source,'Initial')
            builder = module('package_build',source/'tools/build-native.py')
            before = (source/'source-hashes.json').read_bytes()
            def fake_build(destination):
                for name, binary in builder.MODULES.items():
                    (destination/'build/qml'/name).mkdir(parents=True, exist_ok=True)
                    (destination/'build/qml'/name/binary).write_bytes(b'local build')
                    (destination/'build/qml'/name/'build-info.json').write_text('{}')
            with patch.object(builder,'build',side_effect=fake_build):
                builder.build_verified(source)
            self.assertEqual(before,(source/'source-hashes.json').read_bytes())
            self.assertEqual(git(source,'status','--porcelain'),'')
            (source/'manifest.json').write_text('{}')
            with patch.object(builder,'build') as compile_mock:
                with self.assertRaisesRegex(ValueError,'integrity mismatch'):
                    builder.build_verified(source)
                compile_mock.assert_not_called()

    def test_native_source_change_requires_rebuild(self):
        with tempfile.TemporaryDirectory() as temp:
            source = artifact(Path(temp)/'source')
            readiness = module('package_readiness',source/'install/setup_status.py')
            digest = readiness.native_source_hash(source)
            for name,binary in readiness.MODULES.items():
                (source/'build/qml'/name).mkdir(parents=True, exist_ok=True)
                (source/'build/qml'/name/binary).write_bytes(b'local')
                (source/'build/qml'/name/'build-info.json').write_text(json.dumps({'api':1,'qt':'6.11.2','architecture':'x86_64','sources':digest}))
            self.assertEqual(readiness.native_issues(source,'6.11.2','x86_64'),[])
            code=source/'native/circuit/circuit.cpp';code.write_text(code.read_text()+'\n// changed\n')
            self.assertEqual(len(readiness.native_issues(source,'6.11.2','x86_64')),3)

    def test_external_installer_does_not_replace_git_managed_plugin(self):
        with tempfile.TemporaryDirectory() as temp:
            base=Path(temp);source=artifact(base/'source');config=base/'config'
            target=config/'omarchy/plugins/tor.workspace';target.mkdir(parents=True)
            git(target,'init','-b','main')
            installer=module('external_installer',source/'install/install-user.py')
            with self.assertRaisesRegex(ValueError,'Git-managed'):
                installer.install(source,config,False)
            self.assertTrue((target/'.git').is_dir())


if __name__ == '__main__': unittest.main()
