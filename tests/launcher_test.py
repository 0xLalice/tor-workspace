"""Launch boundary regressions; no real apps, desktop sockets or root requests."""
import importlib.util
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('launcher', ROOT / 'backend/launch.py')
launcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(launcher)


class ExecIntercept(BaseException):
    pass


class LauncherTests(unittest.TestCase):
    def test_launcher_imports_do_not_trigger_plugin_file_watcher(self):
        import os
        import shutil
        import sys
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            source=Path(tmp)/'backend'
            shutil.copytree(ROOT/'backend',source,ignore=shutil.ignore_patterns('__pycache__','*.pyc'))
            script='import runpy,sys;sys.path.insert(0,sys.argv[1]);runpy.run_path(sys.argv[1]+"/launch.py");import backend,chat,exit_controller,circuit_recovery'
            env={k:v for k,v in os.environ.items() if k!='PYTHONDONTWRITEBYTECODE'}
            subprocess.run([sys.executable,'-c',script,str(source)],env=env,check=True)
            self.assertEqual(list(source.rglob('*.pyc')),[])

    def setUp(self):
        import sys
        sys.path.insert(0,str(ROOT/'backend'))
        self.readiness=patch('exit_controller.wait_ready');self.readiness.start();self.addCleanup(self.readiness.stop)
        self.control=patch('backend.Controller');self.control.start();self.addCleanup(self.control.stop)

    def test_chat_opens_only_room_in_temporary_tor_profile(self):
        import tempfile
        import backend
        import chat
        url='http://'+'a'*56+'.onion'
        with tempfile.TemporaryDirectory() as tmp, patch.object(chat,'ready_url',return_value=url), patch.object(launcher.Path,'is_file',return_value=True), patch.object(backend,'RUNTIME',Path(tmp)), patch.object(backend,'prepare'), patch.object(launcher,'run',return_value=subprocess.CompletedProcess([],0,'[]')), patch.object(launcher.subprocess,'run',return_value=subprocess.CompletedProcess([],0)) as execute:
            self.assertEqual(launcher.main(['chat-browser']),0)
            args=execute.call_args.args[0]
            self.assertEqual(args[:3],['python3',str(launcher.BACKEND),'browser'])
            self.assertEqual(args[-1],url)
            profile=Path(args[args.index('--profile')+1]);self.assertFalse(profile.exists())
            self.assertEqual(execute.call_args.kwargs['env']['TOR_SKIP_LAUNCH'],'1')

    def test_darknet_opens_fixed_ahmia_url_in_tor_only(self):
        import tempfile
        import backend
        with tempfile.TemporaryDirectory() as tmp, patch.object(backend,'RUNTIME',Path(tmp)), patch.object(backend,'prepare'), patch.object(launcher.Path,'is_file',return_value=True), patch.object(launcher.subprocess,'run',return_value=subprocess.CompletedProcess([],0)) as execute:
            self.assertEqual(launcher.main(['darknet-browser']),0)
            args=execute.call_args.args[0]
            self.assertEqual(args[:4],['python3',str(launcher.BACKEND),'browser',str(launcher.BROWSER/'firefox')])
            self.assertEqual(args[-1],'http://juhanurmihxlp77nkq76byazcldy2hlmovfu2epvl5ankdibsot4csyd.onion/')
            self.assertIn('--no-remote',args)
            self.assertEqual(execute.call_args.kwargs['env']['TOR_SOCKS_IPC_PATH'],str(launcher.GATEWAY/'socks'))
            self.assertFalse(Path(args[args.index('--profile')+1]).exists())

    def test_darknet_missing_browser_does_not_fallback(self):
        with patch.object(launcher.Path,'is_file',return_value=False), patch.object(launcher.subprocess,'run') as execute:
            with self.assertRaisesRegex(RuntimeError,'Tor Browser is missing'):
                launcher.main(['darknet-browser'])
            execute.assert_not_called()

    def test_tor_off_refuses_browsers_without_start(self):
        with patch('backend.Controller',side_effect=ConnectionRefusedError()), patch.object(launcher.subprocess,'run') as run:
            for action in ('browser','darknet-browser'):
                with self.assertRaisesRegex(RuntimeError,'Tor is off'):launcher.main([action])
            run.assert_not_called()

    def test_unverified_country_blocks_every_network_launch(self):
        with patch('exit_controller.wait_ready',side_effect=RuntimeError('No exits available')), patch.object(launcher.subprocess,'run') as run, patch.object(launcher,'terminal_session') as shell:
            for action in ('browser','darknet-browser','chat-browser','host-browser'):
                with self.assertRaisesRegex(RuntimeError,'No exits available'):launcher.main([action])
            run.assert_not_called();shell.assert_not_called()

    def test_terminal_launches_only_a_dedicated_tor_session(self):
        with patch('exit_controller.wait_ready',side_effect=AssertionError('Window must open first')), patch('backend.Controller',side_effect=AssertionError('Window must open first')), patch.object(launcher.os, 'execvp', side_effect=ExecIntercept) as execute:
            with self.assertRaises(ExecIntercept): launcher.main(['terminal'])
            args = execute.call_args.args[1]
            self.assertEqual(args[0], 'foot')
            self.assertIn('--app-id=org.omarchy.tor-terminal', args)
            self.assertEqual(args[-1], 'shell-session')
            self.assertNotIn('footclient', args)

    def test_browser_uses_namespace_and_ignores_inherited_tor_override(self):
        with patch.object(launcher, 'run', return_value=subprocess.CompletedProcess([],0,'[]')), \
             patch.object(launcher.Path, 'is_file', return_value=True), \
             patch.object(launcher, 'prepare_profile', return_value=Path('/tmp/test-tor-profile')), \
             patch.dict(launcher.os.environ, {'TOR_TRANSPROXY':'1','TOR_CONTROL_PASSWD':'bad'}), \
             patch.object(launcher.subprocess, 'run', return_value=subprocess.CompletedProcess([],0)) as spawn:
            self.assertEqual(launcher.main(['browser']),0)
        args = spawn.call_args.args[0]
        env = spawn.call_args.kwargs['env']
        self.assertEqual(args[:3], ['python3',str(launcher.BACKEND),'browser'])
        self.assertEqual(args[3], str(launcher.BROWSER/'firefox'))
        self.assertIn('--no-remote', args)
        self.assertEqual(args[-1], 'https://check.torproject.org/')
        self.assertNotIn('TOR_TRANSPROXY',env)
        self.assertNotIn('TOR_CONTROL_PASSWD',env)
        self.assertEqual(env['TOR_SKIP_LAUNCH'],'1')
        self.assertTrue(env['TOR_SOCKS_IPC_PATH'].endswith('/'+str(launcher.os.getuid())+'-io/socks'))
        self.assertTrue(env['TOR_CONTROL_COOKIE_AUTH_FILE'].endswith('/cookie'))

    def test_failed_namespace_launch_never_starts_a_normal_shell(self):
        with patch.object(launcher, 'terminal_client') as factory, \
             patch('backend.gateway_generation', return_value='test'), \
             patch('builtins.input', return_value=''):
            factory.return_value.request.side_effect = RuntimeError('Launch failed')
            self.assertEqual(launcher.main(['shell-session']),1)
        factory.return_value.request.assert_called_once_with('run',['/bin/bash',
            '--rcfile',str(ROOT/'integration/tor-bashrc'),'-i'])



if __name__ == '__main__':
    unittest.main()
