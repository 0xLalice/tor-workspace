"""Account-independent setup and optional agent review in a disposable directory."""
from pathlib import Path
import json
import os
import subprocess
import tempfile
import unittest
import shutil
import tomllib

ROOT = Path(__file__).resolve().parents[1]


class AgentStatusTests(unittest.TestCase):
    def test_codex_trust_is_exact_path_and_invocation_only(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);project=root/'quoted "project" \\ path';install=project/'install';install.mkdir(parents=True)
            shutil.copyfile(ROOT/'install/agent-session.sh',install/'agent-session.sh')
            binary=root/'bin';binary.mkdir();capture=root/'args.json'
            (binary/'omarchy').write_text('#!/bin/bash\nprintf codex\n');(binary/'omarchy').chmod(0o755)
            (binary/'codex').write_text('#!/usr/bin/python3\nimport json,os,sys\nfrom pathlib import Path\nPath(os.environ["CAPTURE"]).write_text(json.dumps(sys.argv[1:]))\n')
            (binary/'codex').chmod(0o755)
            subprocess.run(['/bin/bash',str(install/'agent-session.sh'),'review only'],check=True,
                env=dict(os.environ,PATH=str(binary),CAPTURE=str(capture)))
            args=json.loads(capture.read_text())
            self.assertEqual(args[:2],['--sandbox','read-only'])
            key,value=args[3].split('=',1)
            self.assertEqual(key,'projects')  # Codex splits dotted CLI keys literally.
            config={key:tomllib.loads('value='+value)['value']}
            self.assertEqual(config,{'projects':{str(project):{'trust_level':'trusted'}}})
            self.assertEqual(args[4:],['--','review only'])
            self.assertFalse(any('bypass' in a for a in args))

    def test_scripted_install_update_cancel_and_failed_review(self):
        revision = 'a'*40
        for agent, action, choices, expected in [
            ('', ['install'], 'i\n', ['setup','restart shell']),
            ('codex', ['update', revision], 'i\n', ['--confirmed '+revision]),
            ('codex', ['update', revision], 'r\ni\n', ['review','--confirmed '+revision]),
            ('codex', ['install'], 'r\nq\n', ['review']),
            ('', ['install'], 'q\n', []),
        ]:
            with self.subTest(agent=agent, action=action, choices=choices), tempfile.TemporaryDirectory() as folder:
                root = Path(folder)
                install = root/'install'
                install.mkdir()
                for name in ('agent-session.sh', 'interactive-setup.sh'):
                    shutil.copyfile(ROOT/'install'/name, install/name)
                for name, output in [('setup-session.py', "'setup'"), ('update-session.py', "' '.join(sys.argv[1:])")]:
                    (install/name).write_text("import os,sys\nwith open(os.environ['CAPTURE'],'a') as f: print("+output+", file=f)\n")
                def shell(name, body):
                    path=root/name
                    path.write_text('#!/bin/bash\n'+body+'\n')
                    path.chmod(0o755)
                shell('omarchy','if [[ $1 == default ]]; then echo "$TEST_AGENT"; else echo "$*" >> "$CAPTURE"; fi')
                shell('codex','echo review >> "$CAPTURE"; exit 1')
                calls=root/'calls'
                calls.touch()
                result=subprocess.run(['bash',install/'interactive-setup.sh',*action],input=choices,
                    env=dict(os.environ,PATH=str(root)+':'+os.environ['PATH'],CAPTURE=str(calls),TEST_AGENT=agent),
                    stdout=subprocess.PIPE,text=True)
                self.assertEqual(result.returncode,0)
                self.assertEqual(calls.read_text().splitlines(),expected)
