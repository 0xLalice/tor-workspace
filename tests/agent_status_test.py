"""Probe the launch prerequisite without opening terminals or requiring Python in PATH."""
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
    def test_agent_failure_reopens_installation(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);capture=root/'calls'
            for name,body in [('omarchy','if [[ $1 == default ]]; then printf claude; exit 0; fi\nprintf "%s\\n" "$*" >> "$CAPTURE"\nexit "$RESULT"'),('omarchy-shell','printf "%s\\n" "$*" >> "$CAPTURE"')]:
                script=root/name;script.write_text('#!/bin/bash\n'+body+'\n');script.chmod(0o755)
            for result in (0,7,130):
                with self.subTest(result=result):
                    capture.unlink(missing_ok=True)
                    proc=subprocess.run(['/bin/bash',str(ROOT/'install/agent-session.sh'),'test prompt'],env=dict(os.environ,PATH=str(root),CAPTURE=str(capture),RESULT=str(result)))
                    self.assertEqual(proc.returncode,result)
                    calls=capture.read_text().splitlines()
                    self.assertEqual(calls[0],'agent prompt --inline test prompt')
                    self.assertEqual(calls[1:],['tor.workspace installationFailed'] if result else [])

    def test_update_failure_uses_update_dialog(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            capture = root/'calls'
            for name, body in [('omarchy', 'if [[ $1 == default ]]; then printf claude; else exit 7; fi'),
                               ('omarchy-shell', 'printf "%s\\n" "$*" >> "$CAPTURE"')]:
                script = root/name
                script.write_text('#!/bin/bash\n'+body+'\n')
                script.chmod(0o755)
            result = subprocess.run(['/bin/bash', str(ROOT/'install/agent-session.sh'),
                                     'update prompt', 'updateFailed'],
                                    env=dict(os.environ, PATH=str(root), CAPTURE=str(capture)))
            self.assertEqual(result.returncode, 7)
            self.assertEqual(capture.read_text().strip(), 'tor.workspace updateFailed')

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
            self.assertEqual(args[0],'--approve-for-me')
            key,value=args[2].split('=',1)
            self.assertEqual(key,'projects')  # Codex splits dotted CLI keys literally.
            config={key:tomllib.loads('value='+value)['value']}
            self.assertEqual(config,{'projects':{str(project):{'trust_level':'trusted'}}})
            self.assertEqual(args[3:],['--','review only'])
            self.assertFalse(any('bypass' in a for a in args))
    def test_unset_missing_and_executable_agent(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            shell = root/'omarchy'
            shell.write_text('#!/bin/bash\nprintf "%s\\n" "$TEST_AGENT"\n')
            shell.chmod(0o755)
            for agent, executable, expected in (('',False,False), ('codex',False,False), ('codex',True,True), ('bogus',True,False)):
                with self.subTest(agent=agent, executable=executable):
                    binary=root/agent if agent else root/'unused'
                    if executable:
                        binary.write_text('#!/bin/bash\nexit 0\n');binary.chmod(0o755)
                    result=subprocess.check_output(['/bin/bash',str(ROOT/'install/agent-status.sh')],env=dict(os.environ,PATH=str(root),TEST_AGENT=agent),text=True)
                    self.assertEqual(json.loads(result)['available'],expected)
                    if executable: binary.unlink()
