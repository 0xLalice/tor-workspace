import importlib.util
import io
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'backend'))
import terminal_info
import backend
spec = importlib.util.spec_from_file_location('terminal_launch', ROOT/'backend/launch.py')
launch = importlib.util.module_from_spec(spec); spec.loader.exec_module(launch)

class TerminalInfo(unittest.TestCase):
    def setUp(self):
        waiter = patch('exit_controller.wait_ready')
        waiter.start(); self.addCleanup(waiter.stop)

    def test_observed_country_uses_tor_local_database(self):
        with patch.dict(os.environ,TOR_WORKSPACE='test'), patch.object(terminal_info,'inside_tor_terminal',return_value=True), patch.object(terminal_info,'fetch_exit_data',return_value='185.220.101.1\n') as fetch, patch.object(terminal_info,'rpc',return_value={'ip':'185.220.101.1','country':'JP','requestedCountry':'JP'}) as lookup, patch('sys.stdout',new_callable=io.StringIO) as output:
            terminal_info.observe_exit()
            lookup.assert_called_once_with('observe-exit','185.220.101.1',timeout=4)
            fetch.assert_called_once()
            self.assertIn('● Country · Japan\n',output.getvalue())
            self.assertLess(output.getvalue().index('● Exit ·'),output.getvalue().index('Country'))

    def test_mismatch_is_explicit(self):
        with patch.dict(os.environ,TOR_WORKSPACE='test'), patch.object(terminal_info,'inside_tor_terminal',return_value=True), patch.object(terminal_info,'fetch_exit_data',return_value='192.42.116.15'), patch.object(terminal_info,'rpc',return_value={'ip':'192.42.116.15','country':'NL','requestedCountry':'JP'}), patch('sys.stdout',new_callable=io.StringIO) as output:
            terminal_info.observe_exit()
            self.assertIn('MISMATCH: requested JP',output.getvalue())
            self.assertNotIn('JP verified',output.getvalue())

    def test_bad_responses_and_failure_release_the_prompt(self):
        cases=[('not-an-ip',None,'Exit not verified'),
               ('127.0.0.1',None,'Exit not verified'),
               (TimeoutError(),None,'Exit not verified'),
               (KeyboardInterrupt(),None,'Exit lookup skipped'),
               ('185.220.101.1',RuntimeError('lookup'),'Country not verified'),
               ('185.220.101.1',{'ip':'185.220.101.2','country':'US'},'Country not verified'),
               ('185.220.101.1',{'ip':'185.220.101.1','country':'\u001b[2J'},'Country not verified')]
        for ip,reply,message in cases:
            with self.subTest(message=message), patch.dict(os.environ,TOR_WORKSPACE='test'), patch.object(terminal_info,'inside_tor_terminal',return_value=True), patch.object(terminal_info,'fetch_exit_data',side_effect=[ip, ip]), patch.object(terminal_info,'rpc',side_effect=[reply]), patch('sys.stdout',new_callable=io.StringIO) as output:
                terminal_info.observe_exit()
                self.assertIn(message,output.getvalue())
                self.assertNotIn('\033',output.getvalue())

    def test_host_invocation_never_probes(self):
        with patch.dict(os.environ,TOR_WORKSPACE='test'), patch.object(terminal_info,'inside_tor_terminal',return_value=False), patch.object(subprocess,'Popen',side_effect=AssertionError('Host probe')), patch('sys.stdout',new_callable=io.StringIO) as output:
            terminal_info.observe_exit()
            self.assertIn('requires a Tor terminal',output.getvalue())

    def test_slow_curl_is_killed_at_deadline(self):
        import time
        real_popen=subprocess.Popen
        processes=[]
        def slow(*args,**kwargs):
            process=real_popen([sys.executable,'-c','import time; time.sleep(30)'],**kwargs)
            processes.append(process)
            return process
        display=terminal_info.ExitDisplay()
        start=time.monotonic()
        with patch.object(subprocess,'Popen',side_effect=slow):
            with self.assertRaises(TimeoutError):
                terminal_info.fetch_exit_data('https://icanhazip.com',start+.15,display,'Checking…')
        self.assertLess(time.monotonic()-start,1)
        self.assertIsNotNone(processes[0].poll())

    def test_curl_flags_disable_config_proxies_and_bound_response(self):
        import time
        with patch.object(subprocess,'Popen') as factory:
            process=factory.return_value.__enter__.return_value
            process.communicate.return_value=(b'185.220.101.1\n',None)
            process.returncode=0
            self.assertEqual(terminal_info.fetch_exit_data('https://icanhazip.com',time.monotonic()+6,terminal_info.ExitDisplay(),'Checking…'),'185.220.101.1\n')
            argv=factory.call_args.args[0]
            self.assertEqual(argv[:2],['curl','-q'])
            self.assertEqual(argv[argv.index('--noproxy')+1],'*')
            self.assertEqual(argv[argv.index('--max-filesize')+1],'16384')
            self.assertLessEqual(float(argv[argv.index('--max-time')+1]),6)

    def test_ctrl_c_skips_in_a_real_terminal(self):
        import pty,select,signal,time
        with tempfile.TemporaryDirectory() as directory:
            curl=Path(directory)/'curl'
            curl.write_text('#!/usr/bin/python3\nimport time\ntime.sleep(30)\n')
            curl.chmod(0o755)
            pid,master=pty.fork()
            if pid==0:
                try:
                    os.environ.update(TOR_WORKSPACE='test',TERM='xterm-256color',PATH=directory+':'+os.environ['PATH'])
                    terminal_info.inside_tor_terminal=lambda:True
                    terminal_info.observe_exit()
                    print('PROMPT_READY',flush=True)
                    os._exit(0)
                except BaseException:os._exit(1)
            output=b'';sent=False;deadline=time.monotonic()+4
            try:
                while time.monotonic()<deadline:
                    if select.select([master],[],[],.1)[0]:
                        try:data=os.read(master,4096)
                        except OSError:break
                        output+=data
                        if b'Checking exit IP' in output and not sent:
                            os.write(master,b'\x03');sent=True
                        if b'PROMPT_READY' in output:break
                self.assertIn(b'Exit lookup skipped',output)
                self.assertIn(b'PROMPT_READY',output)
                self.assertNotIn(b'Traceback',output)
            finally:
                os.close(master)
                try:os.kill(pid,signal.SIGKILL)
                except ProcessLookupError:pass
                os.waitpid(pid,0)

    def test_fallback_checks_exact_observed_ip(self):
        for failure in (TimeoutError(), terminal_info.ExitLookupError('lookup service rejected the request'), 'invalid', '127.0.0.1'):
            with self.subTest(failure=failure), patch.object(terminal_info, 'inside_tor_terminal', return_value=True), patch.object(terminal_info, 'fetch_exit_data', side_effect=[failure, '{"IP":"185.220.101.1","IsTor":true}']) as fetch, patch.object(terminal_info, 'rpc', return_value={'ip':'185.220.101.1','country':'US','requestedCountry':'US'}) as rpc, patch('sys.stdout',new_callable=io.StringIO) as output:
                terminal_info.observe_exit()
                self.assertEqual(fetch.call_count, 2)
                self.assertEqual(fetch.call_args.args[0], terminal_info.EXIT_SOURCES[1])
                rpc.assert_called_once_with('observe-exit', '185.220.101.1', timeout=4)
                self.assertIn('● Country · United States\n', output.getvalue())

    def test_unconfirmed_or_invalid_fallback_never_verified(self):
        for response in ('{"IP":"185.220.101.1","IsTor":false}', '[]', '{}', 'invalid', '{"IP":"10.0.0.1","IsTor":true}', '{"IP":"\\u001b[2J","IsTor":true}'):
            with self.subTest(response=response), patch.object(terminal_info,'inside_tor_terminal',return_value=True), patch.object(terminal_info,'fetch_exit_data',side_effect=[TimeoutError(), response]), patch.object(terminal_info,'rpc') as rpc, patch('sys.stdout',new_callable=io.StringIO) as output:
                terminal_info.observe_exit()
                rpc.assert_not_called()
                self.assertIn('Exit not verified', output.getvalue())
                self.assertNotIn('\033', output.getvalue())

    def test_namespace_identity_is_required(self):
        with patch.dict(os.environ,TOR_WORKSPACE='test'), patch.object(os.path,'samefile',side_effect=FileNotFoundError()), patch.object(subprocess,'Popen') as spawn, patch('sys.stdout',new_callable=io.StringIO):
            terminal_info.observe_exit();spawn.assert_not_called()
        with patch.dict(os.environ,TOR_WORKSPACE='test'), patch.object(os.path,'samefile',return_value=True):
            self.assertTrue(terminal_info.inside_tor_terminal())

    def test_curl_errors_are_specific_and_do_not_echo_remote_output(self):
        import time
        for code, text in [(6,'DNS'),(28,'timed out'),(60,'certificate'),(22,'rejected')]:
            with self.subTest(code=code), patch.object(subprocess,'Popen') as factory:
                process=factory.return_value.__enter__.return_value
                process.communicate.return_value=(b'\x1b[2J',None);process.returncode=code
                with self.assertRaisesRegex(terminal_info.ExitLookupError,text):
                    terminal_info.fetch_exit_data(terminal_info.EXIT_SOURCES[0],time.monotonic()+1,terminal_info.ExitDisplay(),'Checking')

    def test_readiness_failure_never_enters_shell_and_is_visible(self):
        with patch('exit_controller.wait_ready',side_effect=RuntimeError('No exits available')), patch.object(launch,'terminal_client') as factory, patch('builtins.input'), patch('sys.stdout',new_callable=io.StringIO) as output:
            self.assertEqual(launch.terminal_session(),1)
            factory.return_value.request.assert_not_called()
            self.assertIn('Checking Tor route',output.getvalue())
            self.assertIn('No exits available',output.getvalue())

    def test_cancel_readiness_never_enters_shell(self):
        with patch('exit_controller.wait_ready',side_effect=KeyboardInterrupt), patch.object(launch,'terminal_client') as factory, patch('sys.stdout',new_callable=io.StringIO) as output:
            self.assertEqual(launch.terminal_session(),130)
            factory.return_value.request.assert_not_called()
            self.assertIn('cancelled',output.getvalue())

    def test_snapshot(self):
        text = terminal_info.render(dict(running=True, state='ready', exitCountry='DE'), False)
        self.assertIn('T E R M I N A L', text)
        self.assertIn('Requested country: DE', text)
        self.assertNotIn('locked', text)
        self.assertNotIn('Traffic routed through Tor', text)
        self.assertEqual(terminal_info.status_line(dict(running=True, state='ready')), 'Traffic routed through Tor')

    def test_unavailable_is_not_active(self):
        for value in ({}, dict(running=False, state='ready'), dict(running=True, state='unavailable')):
            self.assertIn('Tor routing unavailable', terminal_info.status_line(value))

    def test_shutdown_reason_bound_to_gateway_generation(self):
        with tempfile.TemporaryDirectory() as folder, patch.object(backend, 'RUNTIME', Path(folder)):
            self.assertIn('connection lost', launch.terminal_end_message('new'))
            (Path(folder)/'stopped-generation').write_text('old')
            self.assertIn('connection lost', launch.terminal_end_message('new'))
            self.assertEqual(launch.terminal_end_message('old'),
                'Tor stopped. This terminal session has ended.')

    def test_normal_nonzero_exit_is_not_a_disconnect(self):
        with patch.object(launch, 'terminal_client') as factory, patch.object(backend, 'gateway_generation', return_value='g'), patch('builtins.input') as wait:
            factory.return_value.request.return_value = 7
            self.assertEqual(launch.terminal_session(), 7)
            wait.assert_not_called()

    def test_started_transport_failure_shows_session_ended(self):
        def disconnect(*args):
            Path(os.environ['TOR_TERMINAL_READY']).touch()
            raise RuntimeError('Tor session disconnected')
        with patch.object(launch, 'terminal_client') as factory, patch.object(backend, 'gateway_generation', return_value='g'), patch.object(launch, 'terminal_end_message', return_value='Tor connection lost. This terminal session has ended.'), patch('builtins.input') as wait, patch('builtins.print') as output:
            factory.return_value.request.side_effect = disconnect
            self.assertEqual(launch.terminal_session(), 1)
            self.assertIn('session has ended', output.call_args.args[0])
            wait.assert_called_once()

    def test_notice_is_local_and_emitted_once(self):
        import json
        with tempfile.TemporaryDirectory() as folder:
            marker = str(Path(folder)/'ready')
            Path(marker+'.notice').write_text(json.dumps(''))
            state = dict(running=True, state='ready', exitCountry='DE')
            with patch.dict(os.environ, {'TOR_TERMINAL_READY':marker}), patch.object(sys, 'argv', ['terminal_info.py','--notice']), patch.object(terminal_info,'local_state',return_value=state), patch('subprocess.run',side_effect=AssertionError('No probe')), patch('socket.socket',side_effect=AssertionError('No socket')), patch('builtins.print') as output:
                terminal_info.main(); terminal_info.main()
                output.assert_called_once_with('Tor country restriction changed · Traffic routed through Tor · Requested country: Germany')
                state['circuitId'] = 'new'
                terminal_info.main(); self.assertEqual(output.call_count, 1)
                state['exitCountry'] = ''
                terminal_info.main(); self.assertEqual(output.call_count, 2)

    def test_prompt_helpers_have_zero_network_calls(self):
        import json, time
        with tempfile.TemporaryDirectory() as folder, patch.object(backend, 'RUNTIME', Path(folder)), patch.object(backend, 'gateway_generation', return_value='g'), patch.object(terminal_info, 'preferences', return_value={'country':''}), patch.dict(os.environ, {'TOR_TERMINAL_READY':str(Path(folder)/'ready')}):
            (Path(folder)/'controller-state.json').write_text(json.dumps(dict(api=3, running=True, state='ready', heartbeat=time.time(), gatewayGeneration='g')))
            with patch('subprocess.Popen', side_effect=AssertionError('No process probes')), patch('socket.socket', side_effect=AssertionError('No socket probes')), patch('builtins.print'):
                for args in (['--accent'], ['--notice']):
                    with patch.object(sys, 'argv', ['terminal_info.py']+args): terminal_info.main()

    def test_local_state_rejects_stale_and_incompatible_snapshots(self):
        import json, time
        with tempfile.TemporaryDirectory() as folder, patch.object(backend, 'RUNTIME', Path(folder)), patch.object(backend, 'gateway_generation', return_value='g'), patch.object(terminal_info, 'preferences', return_value={'country':'DE'}):
            path = Path(folder)/'controller-state.json'
            state = dict(api=3, running=True, state='ready', heartbeat=time.time(), gatewayGeneration='g')
            path.write_text(json.dumps(state)); self.assertTrue(terminal_info.local_state()['running'])
            for changes in ({'api':2}, {'heartbeat':0}, {'gatewayGeneration':'old'}):
                path.write_text(json.dumps(dict(state, **changes)))
                self.assertFalse(terminal_info.local_state()['running'])

    def test_header_uses_live_terminal_palette_without_reading_theme_files(self):
        with patch.object(Path, 'read_text', side_effect=AssertionError('No fixed RGB lookup')):
            self.assertEqual(terminal_info.accent(), '\033[38;5;4m')
            header = terminal_info.render({'exitCountry':'US'})
        self.assertIn('\033[38;5;4m', header)
        self.assertNotIn('\033[38;2;', header)
        self.assertNotIn('\033', terminal_info.render({}, colored=False))

    def test_prompt_keeps_status_and_does_not_accumulate(self):
        # Avoid sourcing the user's bashrc in this deterministic prompt test.
        text = (ROOT/'integration/tor-bashrc').read_text()
        function = text[text.index('_tor_workspace_prompt()'):text.index('PROMPT_COMMAND+=')]
        script = function + '''
_TOR_TERMINAL_HELPER="$1"
PS1=$'directory main\\n› '
false
_tor_workspace_prompt
status=$?
[[ $status == 1 ]] || exit 10
first=$PS1
_tor_workspace_prompt
[[ $PS1 == "$first" ]] || exit 11
[[ $PS1 == *directory* && $PS1 == *main* ]] || exit 12
'''
        subprocess.run(['bash','-c',script,'test',str(ROOT/'backend/terminal_info.py')],check=True)

if __name__ == '__main__': unittest.main()
