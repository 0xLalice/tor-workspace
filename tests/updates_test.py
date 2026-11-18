"""Exercise real Git histories; no GitHub access or user checkout changes."""
import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import subprocess
import tempfile
import threading
import unittest
from unittest.mock import patch
from package_test import ROOT, module, git, commit

updates = module('updates', ROOT/'backend/updates.py')


class UpdateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.remote = self.base/'origin'; self.remote.mkdir()
        git(self.remote, 'init', '-b', 'main')
        (self.remote/'manifest.json').write_text('{"version":"1.0"}')
        (self.remote/'docs').mkdir()
        (self.remote/'docs/releases.json').write_text(json.dumps([{'version':'1.0','changes':['Initial features.']}]))
        commit(self.remote, 'Initial')
        self.local = self.base/'installed'
        subprocess.run(['git','clone','-q',str(self.remote),str(self.local)], check=True)
        self.cache = self.base/'cache'

    def check(self, force=False):
        return updates.check(self.local, self.cache, force)

    def release(self):
        (self.remote/'manifest.json').write_text('{"version":"1.1"}')
        (self.remote/'docs/releases.json').write_text(json.dumps([
            {'version':'1.1','changes':['New numbered workspace.','<b>Plain text only.</b>'], 'icons':['terminal','unsupported']},
            {'version':'1.0','changes':['Old change should not appear.']}]))
        commit(self.remote, 'Release 1.1')

    def test_available_notes_and_no_checkout_or_fetch_head_mutation(self):
        self.release(); before=git(self.local,'rev-parse','HEAD')
        state=self.check()
        self.assertTrue(state['available']); self.assertTrue(state['canUpdate'])
        self.assertEqual(state['latestVersion'],'1.1')
        self.assertEqual(state['releases'][0]['icons'], ['terminal', ''])
        self.assertEqual(git(self.local,'rev-parse','HEAD'),before)
        self.assertEqual(git(self.local,'status','--porcelain'),'')
        self.assertFalse((self.local/'.git/FETCH_HEAD').exists())

    def test_current_and_ahead_are_not_updates(self):
        self.assertFalse(self.check()['available'])
        (self.local/'extra').write_text('local'); commit(self.local,'Ahead')
        self.assertFalse(self.check()['available'])

    def test_divergence_and_dirty_checkout_preserved(self):
        self.release()
        (self.local/'manifest.json').write_text('local edits')
        # A malformed local manifest cannot safely supply update metadata.
        self.assertFalse(self.check()['canUpdate'])
        (self.local/'manifest.json').write_text('{"version":"1.0","local":true}')
        state=self.check(True)
        self.assertTrue(state['available']); self.assertFalse(state['canUpdate'])
        commit(self.local,'Local fork')
        state=self.check(True)
        self.assertTrue(state['available']); self.assertFalse(state['canUpdate'])
        self.assertIn('local', (self.local/'manifest.json').read_text())

    def test_cache_and_force_refresh(self):
        self.assertFalse(self.check()['available']); self.release()
        self.assertFalse(self.check()['available'])
        self.assertTrue(self.check(True)['available'])
        git(self.local,'merge','--ff-only',updates.REF)
        self.assertFalse(self.check()['available'])

    def test_offline_is_bounded_and_does_not_change_source(self):
        with patch.object(updates,'git',side_effect=subprocess.TimeoutExpired('git',30)):
            self.assertTrue(self.check()['error'])
        self.assertEqual(git(self.local,'status','--porcelain'),'')

    def test_cached_discovery_rechecks_local_edits_without_fetch(self):
        self.release()
        self.assertTrue(self.check()['canUpdate'])
        original = updates.git
        def no_fetch(root, *args):
            self.assertNotEqual(args[0], 'fetch')
            return original(root, *args)
        extra = self.local/'personal-change'
        with patch.object(updates, 'git', side_effect=no_fetch):
            extra.write_text('Keep my changes')
            state = self.check()
            self.assertFalse(state['canUpdate'])
            self.assertTrue(state['error'])
            self.assertEqual(extra.read_text(), 'Keep my changes')
            extra.unlink()
            state = self.check()
            self.assertTrue(state['canUpdate'])
            self.assertFalse(state['error'])

    def test_same_version_uses_commit_summary(self):
        (self.remote/'fix').write_text('fix'); commit(self.remote,'Fix globe layout')
        self.assertEqual(self.check()['releases'][0]['changes'],['Fix globe layout'])

    def test_installed_history_is_available_without_network_or_git(self):
        state=updates.local_status(self.local)
        self.assertFalse(state['checked'])
        self.assertEqual(state['releases'][0],dict(version='1.0',kind='installed',changes=['Initial features.']))
        archive=self.base/'archive';archive.mkdir()
        (archive/'manifest.json').write_text('{"version":"0.1"}')
        (archive/'docs').mkdir()
        (archive/'docs/releases.json').write_text('[{"version":"0.1","changes":["First release."]}]')
        self.assertEqual(updates.check(archive)['releases'][0]['changes'],['First release.'])
        self.assertFalse(updates.check(archive)['managed'])

    def test_remote_release_appears_above_installed_history(self):
        self.release(); state=self.check()
        self.assertEqual([(r['version'],r['kind']) for r in state['releases']],[('1.1','available'),('1.0','installed')])
        self.assertEqual(state['releases'][1]['changes'],['Initial features.'])
        self.assertTrue(state['checked'])

    def test_offline_keeps_installed_notes(self):
        original=updates.git
        def offline(root,*args):
            if args[0]=='fetch': raise subprocess.TimeoutExpired('git',30)
            return original(root,*args)
        with patch.object(updates,'git',side_effect=offline): state=self.check()
        self.assertFalse(state['checked']);self.assertTrue(state['error'])
        self.assertEqual(state['releases'][0]['changes'],['Initial features.'])

    def test_reset_to_public_version_still_detected_by_git(self):
        (self.remote/'manifest.json').write_text('{"version":"0.1"}')
        (self.remote/'docs/releases.json').write_text('[{"version":"0.1","changes":["Public version baseline."]}]')
        commit(self.remote,'Reset public version')
        state=self.check()
        self.assertTrue(state['available']);self.assertTrue(state['canUpdate'])
        self.assertEqual(state['releases'][0]['version'],'0.1')

    def test_known_update_survives_a_failed_recheck(self):
        self.release(); known=self.check()
        original=updates.git
        def offline(root,*args):
            if args[0]=='fetch': raise subprocess.TimeoutExpired('git',30)
            return original(root,*args)
        with patch.object(updates,'git',side_effect=offline): state=self.check(True)
        self.assertTrue(state['available']);self.assertFalse(state['canUpdate'])
        self.assertEqual(state['releases'],known['releases'])
        self.assertTrue(state['error'])

    def test_handoff_rechecks_edits_and_remote_revision(self):
        self.release()
        revision = self.check()['revision']
        self.assertTrue(updates.handoff_status(self.local, revision, self.cache)['canUpdate'])
        personal = self.local/'personal'
        personal.write_text('Keep this')
        self.assertFalse(updates.handoff_status(self.local, revision, self.cache)['canUpdate'])
        self.assertEqual(personal.read_text(), 'Keep this')
        personal.unlink()
        (self.remote/'fix').write_text('remote fix')
        commit(self.remote, 'Remote changed after review')
        state = updates.handoff_status(self.local, revision, self.cache)
        self.assertFalse(state['canUpdate'])
        self.assertIn('changed', state['error'])
        self.assertTrue(updates.handoff_status(self.local, state['revision'], self.cache)['canUpdate'])

    def test_auth_required_never_runs_helpers_or_askpass(self):
        class NeedsAuth(BaseHTTPRequestHandler):
            def do_GET(self):
                self.send_response(401)
                self.send_header('WWW-Authenticate', 'Basic realm="test"')
                self.end_headers()
            def log_message(self, *args): pass

        server = ThreadingHTTPServer(('127.0.0.1', 0), NeedsAuth)
        worker = threading.Thread(target=server.serve_forever, daemon=True)
        worker.start()
        self.addCleanup(server.server_close)
        self.addCleanup(worker.join)
        self.addCleanup(server.shutdown)
        origin = 'http://127.0.0.1:'+str(server.server_port)
        git(self.local, 'remote', 'set-url', 'origin', origin+'/private.git')
        marker = self.base/'prompt-invoked'
        helper = self.base/'prompt'
        helper.write_text('#!/bin/sh\ntouch "'+str(marker)+'"\nexit 1\n')
        helper.chmod(0o700)
        # Both generic and URL-scoped helpers must be disabled, including gh's
        # usual URL-specific configuration. Inherited askpass must not run.
        git(self.local, 'config', 'credential.helper', str(helper))
        git(self.local, 'config', 'credential.'+origin+'.helper', str(helper))
        git(self.local, 'config', 'core.askPass', str(helper))
        with patch.dict(os.environ, GIT_ASKPASS=str(helper), SSH_ASKPASS=str(helper),
                        NO_PROXY='127.0.0.1', no_proxy='127.0.0.1'):
            state = self.check(True)
        self.assertFalse(marker.exists(), 'A password-capable helper was invoked')
        self.assertFalse(state['checked'])
        self.assertFalse(state['canUpdate'])
        self.assertTrue(state['error'])
        self.assertEqual(state['releases'][0]['version'], '1.0')
