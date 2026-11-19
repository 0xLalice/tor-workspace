"""Country routing regressions; no live networking or installed preferences."""
import base64
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'backend'))
import backend
import exit_controller as ec

A, B, C = ('A'*40, 'B'*40, 'C'*40)

class Tor:
    def __init__(self):
        self.events = []
        self.commands = []
        self.built = ''
        self.policy = ''
        self.progress = 100
        self.records = [(A, 'DE'), (B, 'DE'), (C, 'FR')]
    def command(self, cmd):
        self.commands.append(cmd)
        if cmd.startswith('SETCONF ExitNodes='):
            self.policy = cmd.split('ExitNodes=', 1)[1].split()[0].strip(chr(34))
        if cmd == 'GETCONF ExitNodes StrictNodes':
            return 'ExitNodes='+self.policy+'\nStrictNodes=1'
        if cmd.startswith('CLOSECIRCUIT '):
            cid=cmd.split()[1]
            self.built='\n'.join(line for line in self.built.splitlines() if not line.startswith(cid+' '))+'\n'
        if cmd == 'GETINFO ns/all':
            return '\n'.join('r Relay '+base64.b64encode(bytes.fromhex(fp)).decode().rstrip('=')+
                             ' digest 2026-01-01 00:00:00 192.0.2.'+str(i+1)+' 443 0\ns Exit Running Valid\nw Bandwidth=100'
                             for i, (fp, cc) in enumerate(self.records))
        if cmd.startswith('GETINFO ip-to-country/'):
            return '\n'.join(key+'='+self.records[int(key.rsplit('.',1)[1])-1][1].lower() for key in cmd.split()[1:])
        if cmd.startswith('GETINFO md/id/'): return 'p reject 25'
        if cmd.startswith('GETINFO desc/id/'): return 'reject 192.0.2.0/24:*\naccept *:80\naccept *:443\nreject *:*'
        if cmd == 'GETINFO circuit-status': return self.built
        if cmd == 'GETINFO status/bootstrap-phase': return 'PROGRESS=' + str(self.progress)
        if cmd.startswith('GETINFO ns/id/'):
            index=max(i for i,(fp,_) in enumerate(self.records) if fp==cmd.rsplit('/',1)[1])
            return 'r Relay identity descriptor 2026-01-01 00:00:00 192.0.2.'+str(index+1)+' 443 0'
        return 'OK'
    def circuit(self, cid, fp, purpose='GENERAL'):
        return cid+' BUILT $'+A+'~a,$'+B+'~b,$'+fp+'~exit PURPOSE='+purpose+'\n'

class ControllerTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        for key in ('DATA', 'RUNTIME', 'GATEWAY'):
            p = patch.object(backend, key, Path(self.temp.name)/key); p.start(); self.addCleanup(p.stop)
        backend.prepare(); backend.GATEWAY.mkdir(); (backend.GATEWAY/'control').touch()
        self.tor = Tor()
        from country_migration import migrate
        migrate()
        self.gateway = ec.Gateway(self.tor)
    def restore(self, country=''):
        self.gateway.prefs = dict(api=3, country=country)
        self.gateway.restore()
        return self.gateway

    def test_country_selection_and_removal(self):
        g = self.restore()
        g.request('set-country', 'DE')
        self.assertEqual(ec.preferences(), dict(api=3, country='DE'))
        self.assertIn('SETCONF ExitNodes={de} StrictNodes=1', self.tor.commands)
        g.request('set-country', '')
        self.assertIn('SETCONF ExitNodes="" StrictNodes=1', self.tor.commands)
        self.assertFalse(any('HALT' in c or 'CLOSE' in c or 'NEWNYM' in c for c in self.tor.commands))

    def test_country_change_disconnects_old_circuits_and_conflux_legs(self):
        g = self.restore()
        self.tor.built = (self.tor.circuit('1', C, 'CONFLUX_LINKED').strip()+' CONFLUX_ID=pair\n'
                          +self.tor.circuit('2', A, 'CONFLUX_LINKED').strip()+' CONFLUX_ID=pair\n'
                          +self.tor.circuit('3', A)
                          +'4 EXTENDED $'+A+'~a PURPOSE=CONFLUX_UNLINKED\n'
                          +self.tor.circuit('5', C, 'HS_CLIENT_REND'))
        g.request('set-country', 'DE')
        for cid in ('1','2','4'):
            self.assertIn('CLOSECIRCUIT '+cid,self.tor.commands)
        for cid in ('3','5'):
            self.assertNotIn('CLOSECIRCUIT '+cid,self.tor.commands)
        self.assertTrue(ec.ready(g.state,'DE'))
        self.assertEqual(g.state['verifiedCountry'],'DE')

    def test_new_partial_circuits_can_finish_but_late_old_exits_are_closed(self):
        g = self.restore('DE')
        self.tor.built='6 EXTENDED $'+A+'~a PURPOSE=GENERAL\n'
        g.tick()
        self.assertNotIn('CLOSECIRCUIT 6',self.tor.commands)
        self.tor.built=self.tor.circuit('6',C)
        g.tick()
        self.assertIn('CLOSECIRCUIT 6',self.tor.commands)
        self.assertFalse(g.state['policyReady'])

    def test_policy_readback_failure_never_publishes_ready_or_saves_new_country(self):
        g = self.restore()
        original=self.tor.command
        def command(cmd):
            if cmd=='GETCONF ExitNodes StrictNodes' and self.tor.policy=='{de}':
                return 'ExitNodes={fr}\nStrictNodes=1'
            return original(cmd)
        with patch.object(self.tor,'command',side_effect=command):
            with self.assertRaisesRegex(RuntimeError,'did not confirm'):
                g.request('set-country','DE')
        self.assertEqual(ec.preferences()['country'],'')
        self.assertFalse(g.state['policyReady'])

    def test_external_policy_drift_is_repaired_before_readiness(self):
        g = self.restore('DE')
        self.tor.built=self.tor.circuit('7',A)
        g.tick();self.tor.policy='{fr}'
        g.request('launch-ready',None)
        self.assertEqual(self.tor.policy,'{de}')
        self.assertTrue(ec.ready(g.state,'DE'))

    def test_observation_uses_exact_ip_and_is_distinct_from_requested_country(self):
        g=self.restore('DE')
        original=self.tor.command
        with patch.object(self.tor,'command',side_effect=lambda cmd:'ip-to-country/192.42.116.15=nl\nOK' if cmd=='GETINFO ip-to-country/192.42.116.15' else original(cmd)):
            observation=g.request('observe-exit','192.42.116.15')
        self.assertEqual(observation['country'],'NL')
        self.assertEqual(observation['requestedCountry'],'DE')
        with self.assertRaises(ValueError):g.request('observe-exit','127.0.0.1')

    def test_ready_requires_verified_policy_and_matching_country(self):
        state=dict(api=3,running=True,state='ready',exitCountry='DE',appliedCountry='DE',verifiedCountry='DE',policyReady=True)
        self.assertTrue(ec.ready(state,'DE'))
        for change in ({'policyReady':False},{'verifiedCountry':'FR'},{'appliedCountry':'FR'},{'state':'unavailable'}):
            self.assertFalse(ec.ready(dict(state,**change),'DE'))

    def test_unavailable_country_blocks_waiting_launch(self):
        state=dict(api=3,running=True,state='unavailable',exitCountry='AQ',message='No exits available')
        with patch.object(ec,'rpc',return_value=state):
            with self.assertRaisesRegex(RuntimeError,'No exits available'):ec.wait_ready()

    def test_launch_demand_recovers_idle_tor_and_reports_progress(self):
        pending=dict(api=3,running=True,state='starting',exitCountry='DE')
        ready=dict(pending,state='ready',policyReady=True,appliedCountry='DE',verifiedCountry='DE')
        with patch.object(ec,'rpc',side_effect=[pending,ready]), patch('circuit_recovery.recover',return_value=dict(pending,message='Building a Tor circuit…')) as recover, patch.object(ec.time,'sleep'), patch('builtins.print') as progress:
            self.assertEqual(ec.wait_ready(on_progress=progress),ready)
            self.assertEqual([c.args[0] for c in recover.call_args_list], [pending, ready])
            progress.assert_called_once_with('Building a Tor circuit…')

    def test_launch_wait_is_bounded(self):
        pending=dict(api=3,running=True,state='starting',exitCountry='DE')
        with patch.object(ec,'rpc',return_value=pending), patch('circuit_recovery.recover',return_value=pending), patch.object(ec.time,'monotonic',side_effect=[0,0,2,2]), patch.object(ec.time,'sleep'):
            with self.assertRaisesRegex(RuntimeError,'No verified Tor route'):
                ec.wait_ready(timeout=1)

    def test_launch_wait_does_not_start_offline_tor(self):
        with patch.object(ec,'rpc',side_effect=FileNotFoundError()), patch.object(Path,'exists',return_value=False), patch('circuit_recovery.recover') as recover:
            with self.assertRaisesRegex(RuntimeError,'Tor is off'):ec.wait_ready()
            recover.assert_not_called()

    def test_fresh_circuits_does_not_select_exit(self):
        g = self.restore()
        before = list(self.tor.commands)
        g.request('new-circuits', None)
        self.assertEqual(self.tor.commands[len(before):], ['SIGNAL NEWNYM'])
        g.request('new-circuits', None)
        self.assertEqual(self.tor.commands.count('SIGNAL NEWNYM'), 1)

    def test_explicit_refresh_replaces_display_and_then_stays_stable(self):
        g = self.restore()
        self.tor.built = self.tor.circuit('1', A)+self.tor.circuit('2', C)
        g.tick(); self.assertEqual(g.state['circuitId'], '1')
        g.request('new-circuits', None)
        self.assertEqual(g.state['circuitId'], '1')  # No blank intermediate route.
        g.tick(); self.assertEqual(g.state['circuitId'], '2')
        self.assertEqual(len(g.state['route']), 3)
        self.assertFalse(g.replacement_requested)
        g.tick(); self.assertEqual(g.state['circuitId'], '2')
        g.request('new-circuits', None)  # Cooldown must not queue another switch.
        self.assertFalse(g.replacement_requested)
        self.assertFalse(any(c.startswith(('CLOSECIRCUIT', 'EXTENDCIRCUIT', 'ATTACHSTREAM')) for c in self.tor.commands))

    def test_refresh_retains_route_until_eligible_replacement_exists(self):
        g = self.restore('DE')
        self.tor.built = self.tor.circuit('1', A)
        g.tick(); previous = g.state['route']
        g.request('new-circuits', None); g.tick()
        self.assertTrue(g.replacement_requested)
        self.assertEqual(g.state['route'], previous)
        self.tor.built += self.tor.circuit('2', C)  # FR is outside the policy.
        g.tick(); self.assertEqual(g.state['circuitId'], '1')
        self.tor.built += self.tor.circuit('3', B)
        g.tick(); self.assertEqual(g.state['circuitId'], '3')
        self.assertFalse(g.replacement_requested)

    def test_failed_refresh_does_not_schedule_display_change(self):
        g = self.restore()
        with patch.object(self.tor, 'command', side_effect=RuntimeError('rejected')):
            with self.assertRaises(RuntimeError): g.request('new-circuits', None)
        self.assertFalse(g.replacement_requested)

    def test_missing_consensus_record_uses_another_built_circuit(self):
        g = self.restore()
        missing = 'D'*40
        self.tor.built = '1 BUILT $'+missing+'~gone,$'+B+'~b,$'+A+'~exit PURPOSE=GENERAL\n'+self.tor.circuit('2', C)
        command = self.tor.command
        def reply(value):
            if value == 'GETINFO ns/id/'+missing:
                raise backend.ControlReplyError('Unknown relay')
            return command(value)
        with patch.object(self.tor, 'command', side_effect=reply):
            g.tick()
            self.assertEqual(g.state['state'], 'ready')
            self.assertEqual(g.state['circuitId'], '2')
            self.assertEqual(len(g.state['route']), 3)
            g.tick()
            self.assertEqual(g.state['circuitId'], '2')

    def test_unmapped_circuit_waits_and_recovers_without_crashing(self):
        g = self.restore()
        g.request('set-country', 'DE')
        self.tor.built = self.tor.circuit('1', A)
        command = self.tor.command
        def reply(value):
            if value.startswith('GETINFO ns/id/'):
                raise backend.ControlReplyError('Unknown relay')
            return command(value)
        with patch.object(self.tor, 'command', side_effect=reply):
            g.tick();g.tick()
            self.assertEqual(g.state['state'], 'starting')
            self.assertEqual(g.state['route'], [])
            self.assertEqual(g.request('status', None)['exitCountry'], 'DE')
        g.tick()
        self.assertEqual(g.state['state'], 'ready')

    def test_missing_country_record_does_not_publish_partial_route(self):
        g = self.restore()
        self.tor.built = self.tor.circuit('1', A)
        command = self.tor.command
        def reply(value):
            if value.startswith('GETINFO ip-to-country/'):
                raise backend.ControlReplyError('Unknown address')
            return command(value)
        with patch.object(self.tor, 'command', side_effect=reply):
            g.tick()
            self.assertEqual(g.state['route'], [])

    def test_broken_connection_is_not_treated_as_missing_metadata(self):
        g = self.restore()
        self.tor.built = self.tor.circuit('1', A)
        with patch.object(self.tor, 'command', side_effect=ConnectionResetError):
            with self.assertRaises(ConnectionResetError):g.tick()

    def test_unrestricted_cold_start_waits_for_directory_and_circuit(self):
        records = self.tor.records
        self.tor.records = []
        self.tor.progress = 25
        g = self.restore()
        for progress in (25, 100):
            self.tor.progress = progress
            g.tick()
            self.assertEqual(g.state['state'], 'starting')
            self.assertEqual(g.state['progress'], progress)
            self.assertFalse(g.state['serviceReady'])
            self.assertNotIn('country', g.state['message'])

        self.tor.records = records
        g.directory()
        g.tick()
        self.assertEqual(g.state['state'], 'starting')
        self.assertTrue(g.state['serviceReady'])
        self.tor.built = self.tor.circuit('7', C)
        g.tick()
        self.assertTrue(ec.ready(g.state, ''))

    def test_unavailable_country_recovers_from_directory_without_broadening(self):
        records = self.tor.records
        self.tor.records = []
        self.tor.progress = 25
        g = self.restore('AQ')
        g.tick()
        self.assertEqual(g.state['state'], 'starting')
        self.tor.records = records
        g.directory()
        g.tick()
        self.assertEqual(g.state['state'], 'starting')
        self.tor.progress = 100
        g.tick()
        self.assertEqual(g.state['state'], 'unavailable')
        self.tor.records.append((C, 'AQ')); g.directory()
        self.tor.built = self.tor.circuit('7', C); g.tick()
        self.assertEqual(g.state['state'], 'ready')
        self.assertNotIn('SETCONF ExitNodes="" StrictNodes=1', self.tor.commands)

    def test_successful_representative_circuit_stays_until_closed(self):
        g = self.restore()
        self.tor.built = self.tor.circuit('1', A)+self.tor.circuit('2', B, 'CONFLUX_LINKED')
        self.tor.events = ['STREAM 8 SUCCEEDED 2 example.org:443']
        g.tick(); self.assertEqual(g.state['circuitId'], '2')
        revision = g.state['revision']; g.tick(); self.assertEqual(g.state['revision'], revision)
        self.tor.built = self.tor.circuit('1', A); g.tick()
        self.assertEqual(g.state['circuitId'], '1')
        self.tor.built = ''; g.tick(); self.assertEqual(g.state['route'], [])

    def test_spare_circuit_expiry_preserves_service_but_not_route_readiness(self):
        g = self.restore()
        self.tor.built = self.tor.circuit('1', A); g.tick()
        self.assertTrue(ec.available(g.state)); self.assertTrue(ec.ready(g.state, ''))
        self.tor.built = ''
        for _ in range(20):
            g.tick()
            self.assertTrue(ec.available(g.request('status', None)))
            self.assertFalse(ec.ready(g.state, ''))
            self.assertEqual(g.state['route'], [])
        self.assertFalse(any(c.startswith(('EXTENDCIRCUIT', 'SIGNAL')) for c in self.tor.commands))

    def test_availability_requires_bootstrap_and_applicable_country(self):
        g = self.restore(); self.tor.progress = 80; g.tick()
        self.assertFalse(ec.available(g.state))
        self.tor.progress = 100; g.tick(); self.assertTrue(ec.available(g.state))
        g.request('set-country', 'AQ'); self.assertFalse(ec.available(g.state))
        g.request('set-country', 'DE'); self.assertTrue(ec.available(g.state))
        self.assertFalse(ec.available(dict(g.state, appliedCountry='FR')))
        self.assertFalse(ec.available(dict(g.state, state='error')))
        self.assertFalse(ec.available(dict(g.state, running=False)))

    def test_offline_preferences_do_not_start_tor(self):
        (backend.GATEWAY/'control').unlink()
        with patch.object(ec, 'rpc', side_effect=FileNotFoundError), patch.object(backend.subprocess, 'Popen', side_effect=AssertionError('must not start')):
            self.assertFalse(ec.client('set-country', 'DE')['running'])
            self.assertEqual(ec.client('set-country', '')['exitCountry'], '')

    def test_failed_country_change_preserves_preference(self):
        g = self.restore()
        with patch.object(self.tor, 'command', side_effect=RuntimeError('rejected')):
            with self.assertRaises(RuntimeError): g.request('set-country', 'DE')
        self.assertEqual(g.prefs['country'], '')

    def test_concurrent_offline_country_requests_are_atomic(self):
        import concurrent.futures
        (backend.GATEWAY/'control').unlink()
        with patch.object(ec, 'rpc', side_effect=FileNotFoundError):
            with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
                replies = list(pool.map(lambda cc: ec.client('set-country', cc), ['DE','FR','']*5))
        self.assertTrue(all(not r['running'] for r in replies))
        self.assertIn(ec.preferences()['country'], ('DE','FR',''))
        self.assertEqual(set(ec.preferences()), {'api','country'})

    def test_invalid_action_rejected_even_offline(self):
        with self.assertRaises(ValueError): ec.client('unknown')

    def test_rpc_requests_are_serialized_and_api_rejected(self):
        import concurrent.futures
        import multiprocessing
        import socket
        import time
        class Context:
            def __enter__(inner): return self.tor
            def __exit__(inner,*args): pass
        with patch.object(backend,'Controller',return_value=Context()):
            process=multiprocessing.get_context('fork').Process(target=ec.serve)
            process.start()
        try:
            for _ in range(100):
                if (backend.RUNTIME/'controller.sock').exists():break
                time.sleep(.01)
            with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
                replies=list(pool.map(lambda country:ec.rpc('set-country',country),['DE','FR','']*4))
            self.assertTrue(all(r['api']==3 for r in replies))
            self.assertEqual(ec.rpc()['exitCountry'],ec.preferences()['country'])
            self.assertEqual((backend.RUNTIME/'controller.sock').stat().st_mode & 0o777,0o600)
            with socket.socket(socket.AF_UNIX,socket.SOCK_SEQPACKET) as client:
                client.connect(str(backend.RUNTIME/'controller.sock'))
                client.send(b'{"api":1,"action":"status"}')
                self.assertIn('Incompatible',json.loads(client.recv(65536))['error'])
        finally:
            process.terminate();process.join(3)


if __name__=='__main__': unittest.main()
