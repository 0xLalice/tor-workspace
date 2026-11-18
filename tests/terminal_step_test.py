"""Privileged steps wait for the visible terminal; tests never authenticate."""
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('terminal_step',ROOT/'install/terminal-step.py')
step=importlib.util.module_from_spec(spec);spec.loader.exec_module(step)

class TerminalStepTests(unittest.TestCase):
    def test_fixed_privilege_boundary_and_package_names(self):
        self.assertEqual(step.command('install',[]),['/usr/bin/python3','-B',str(ROOT/'install/setup-session.py')])
        with self.assertRaises(ValueError):step.command('install',['tor'])
        self.assertEqual(step.command('packages',['tor','onionshare']),['omarchy','pkg','add','tor','onionshare'])
        self.assertEqual(step.command('backend',[]),['sudo','/usr/bin/python3','-I',str(ROOT/'system/install.py')])
        for names in ([],['--noconfirm'],['x;id'],['$(id)']):
            with self.assertRaises(ValueError):step.command('packages',names)
        with self.assertRaises(ValueError):step.command('backend',['tor'])

    def test_success_cancellation_and_closed_terminal(self):
        for completed, expected in ((0,0),(130,130),(None,1)):
            with self.subTest(completed=completed),patch.object(step.os,'geteuid',return_value=1000):
                saved=[]
                def run(args,**kwargs):
                    path=Path(args[5]);saved.append(path.parent)
                    self.assertEqual(args[0],'foot')
                    self.assertNotIn('sudo',args[:6])
                    if completed is not None:path.write_text(str(completed))
                    return subprocess.CompletedProcess(args,0)
                with patch.object(step.subprocess,'run',side_effect=run):
                    self.assertEqual(step.run('backend',[]),expected)
                self.assertFalse(saved[0].exists())

    def test_terminal_command_records_failure(self):
        with tempfile.TemporaryDirectory() as folder:
            result=Path(folder)/'status'
            process=subprocess.run(['bash',str(ROOT/'install/terminal-command.sh'),str(result),'bash','-c','exit 130'])
            self.assertEqual(process.returncode,130);self.assertEqual(result.read_text(),'130\n')
