"""Exercise update dispatch against disposable Git checkouts and desktop commands."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from package_test import ROOT, commit, git, module

sys.path.insert(0, str(ROOT/'install'))
worker = module('update_session', ROOT/'install/update-session.py')


class UpdateSessionTests(unittest.TestCase):
    def setUp(self):
        folder = tempfile.TemporaryDirectory()
        self.addCleanup(folder.cleanup)
        base = Path(folder.name)
        self.origin = base/'origin'
        self.origin.mkdir()
        for name in ('docs', 'tools', 'install'):
            (self.origin/name).mkdir()
        (self.origin/'manifest.json').write_text('{"version":"1"}')
        (self.origin/'docs/releases.json').write_text('[]')
        for name in ('tools/check_package.py', 'install/setup_status.py'):
            (self.origin/name).write_text('')
        git(self.origin, 'init', '-b', 'main')
        commit(self.origin, 'Installed')
        self.root = base/'installed'
        subprocess.run(['git', 'clone', '-q', str(self.origin), self.root], check=True)
        self.before = git(self.root, 'rev-parse', 'HEAD').strip()
        (self.origin/'manifest.json').write_text('{"version":"2"}')
        commit(self.origin, 'Incoming')
        self.revision = git(self.origin, 'rev-parse', 'HEAD').strip()
        bin_dir = base/'bin'
        bin_dir.mkdir()
        self.log = base/'calls'
        omarchy = bin_dir/'omarchy'
        omarchy.write_text('#!/bin/sh\necho "$*" >> "$CALLS"\nif [ "$1" = restart ]; then exit "$RESTART_RESULT"; fi\n')
        omarchy.chmod(0o755)
        self.enterContext(patch.dict(os.environ, PATH=str(bin_dir)+':'+os.environ['PATH'],
                                     XDG_CACHE_HOME=str(base/'cache'), CALLS=str(self.log), RESTART_RESULT='0'))
        self.state = dict(ready=True, issues=[], torVersion='0.4.9.14', minimumTorVersion='0.4.9.14',
                          buildRequired=False, missingRuntimePackages=[], missingBuildPackages=['cmake'],
                          backendCompatible=True, backendCurrent=True, enrolled=True, socketReady=True,
                          browserReady=True, workspaceReady=True)
        self.enterContext(patch.object(worker.setup_status, 'status', return_value=self.state))
        self.enterContext(patch.object(worker, 'readiness', return_value=self.state))
        self.enterContext(patch.object(worker.os, 'geteuid', return_value=1000))

    def apply(self):
        worker.run(self.root, self.revision, 'Review this update')

    def test_user_update_selects_exact_commit_and_reloads(self):
        self.apply()
        self.assertEqual(git(self.root, 'rev-parse', 'HEAD').strip(), self.revision)
        self.assertEqual(self.log.read_text().splitlines()[-1], 'restart shell')
        self.assertNotIn('launch tui', self.log.read_text())
        self.assertIsNone(worker.pending_update(self.root))

    def test_backend_update_opens_agent_before_changing_head(self):
        self.state['backendCurrent'] = False
        self.apply()
        self.assertEqual(git(self.root, 'rev-parse', 'HEAD').strip(), self.before)
        self.assertIn('launch tui bash', self.log.read_text())
        self.assertNotIn('restart shell', self.log.read_text())

    def test_only_missing_required_build_tools_need_admin(self):
        self.assertFalse(worker.needs_admin(self.state))
        self.assertTrue(worker.needs_admin(dict(self.state, buildRequired=True)))
        self.assertFalse(worker.needs_admin(dict(self.state, buildRequired=True, missingBuildPackages=[])))
        self.assertTrue(worker.needs_admin(dict(self.state, missingRuntimePackages=['tor'])))
        self.assertTrue(worker.needs_admin(dict(self.state, minimumTorVersion='0.4.9.15')))

    def test_failed_reload_can_resume_without_network(self):
        with patch.dict(os.environ, RESTART_RESULT='1'), self.assertRaises(subprocess.CalledProcessError):
            self.apply()
        self.assertEqual(worker.pending_update(self.root)['revision'], self.revision)
        git(self.root, 'remote', 'remove', 'origin')
        self.apply()
        self.assertIsNone(worker.pending_update(self.root))

    def test_changed_revision_and_local_edits_block_both_routes(self):
        (self.origin/'another').touch()
        commit(self.origin, 'New revision')
        with self.assertRaisesRegex(RuntimeError, 'changed'):
            self.apply()
        (self.root/'personal').write_text('preserve')
        with self.assertRaisesRegex(RuntimeError, 'Local changes'):
            self.apply()
        self.assertFalse(self.log.exists())
        self.assertEqual(git(self.root, 'rev-parse', 'HEAD').strip(), self.before)
