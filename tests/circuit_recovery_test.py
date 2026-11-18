"""Bounded panel demand; fake control socket, no network or installed state."""
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'backend'))
import backend
import circuit_recovery as recovery


class Tor:
    def __init__(self):
        self.commands = []
        self.progress = 100
        self.pending = ''
        self.dormant = 0
        self.reject = False

    def __enter__(self): return self
    def __exit__(self, *args): pass

    def command(self, command):
        self.commands.append(command)
        if command == 'GETINFO status/bootstrap-phase': return 'PROGRESS=' + str(self.progress)
        if command == 'GETINFO circuit-status': return self.pending
        if command == 'GETINFO dormant': return 'dormant=' + str(self.dormant)
        if command == 'SIGNAL ACTIVE': return 'OK'
        if command == 'EXTENDCIRCUIT 0 purpose=general':
            if self.reject: raise RuntimeError('rejected')
            return 'EXTENDED 42\nOK'
        raise AssertionError(command)


class RecoveryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.tor = Tor()
        for name, value in [('RUNTIME', Path(self.temp.name)), ('Controller', lambda: self.tor)]:
            mock = patch.object(backend, name, value);mock.start();self.addCleanup(mock.stop)
        mock = patch.object(recovery.time, 'monotonic', return_value=100)
        self.clock = mock.start();self.addCleanup(mock.stop)
        self.value = dict(state='starting', running=True, route=[], gatewayGeneration='one', exitCountry='RO')

    def builds(self): return self.tor.commands.count('EXTENDCIRCUIT 0 purpose=general')

    def test_idle_build_uses_tor_path_selection_once(self):
        result = recovery.recover(self.value)
        self.assertEqual(result['state'], 'starting');self.assertEqual(self.builds(), 1)
        before = self.tor.commands[:]
        for _ in range(10): recovery.recover(self.value)
        self.assertEqual(self.tor.commands, before)
        self.assertFalse(any(c.startswith(('SETCONF', 'ATTACHSTREAM', 'CLOSECIRCUIT', 'SIGNAL NEWNYM')) for c in before))
        for name in ('circuit-recovery.json', 'circuit-recovery.lock'):
            self.assertEqual((backend.RUNTIME/name).stat().st_mode & 0o777, 0o600)

    def test_concurrent_panel_reads_launch_one_attempt(self):
        from concurrent.futures import ThreadPoolExecutor
        with ThreadPoolExecutor(max_workers=6) as pool:
            values = list(pool.map(lambda _: recovery.recover(self.value), range(12)))
        self.assertEqual(self.builds(), 1)
        self.assertTrue(all(v['state'] == 'starting' for v in values))

    def test_bootstrap_has_real_progress_without_building(self):
        self.tor.progress = 42
        self.assertEqual(recovery.recover(self.value)['progress'], 42)
        self.assertEqual(self.builds(), 0)
        self.tor.progress = 100;recovery.recover(self.value);self.assertEqual(self.builds(), 1)

    def test_wakes_dormant_tor_before_request(self):
        self.tor.dormant = 1;recovery.recover(self.value)
        self.assertLess(self.tor.commands.index('SIGNAL ACTIVE'), self.tor.commands.index('EXTENDCIRCUIT 0 purpose=general'))

    def test_dormant_wakes_even_before_bootstrap_or_directory_recovers(self):
        self.tor.dormant = 1;self.tor.progress = 45
        result = recovery.recover(dict(self.value, state='unavailable'))
        self.assertEqual(result['state'], 'starting')
        self.assertEqual(result['progress'], 45)
        self.assertLess(self.tor.commands.index('SIGNAL ACTIVE'), self.tor.commands.index('GETINFO status/bootstrap-phase'))
        self.assertEqual(self.builds(), 0)

    def test_activity_does_not_depend_on_dormant_flag_and_is_rate_limited(self):
        self.tor.dormant = 0;self.tor.progress = 0
        for now in range(100, 160, 3):
            self.clock.return_value = now;recovery.recover(self.value)
        self.assertEqual(self.tor.commands.count('SIGNAL ACTIVE'), 1)
        self.clock.return_value = 160;recovery.recover(self.value)
        self.assertEqual(self.tor.commands.count('SIGNAL ACTIVE'), 2)
        self.assertEqual(self.builds(), 0)

    def test_dormant_with_pending_circuit_still_wakes(self):
        self.tor.dormant = 1;self.tor.pending = '9 GUARD_WAIT $ABC PURPOSE=GENERAL'
        recovery.recover(self.value)
        self.assertIn('SIGNAL ACTIVE', self.tor.commands)
        self.assertEqual(self.builds(), 0)
        self.clock.return_value = 146;recovery.recover(self.value)
        self.clock.return_value = 160;recovery.recover(self.value)
        self.assertEqual(self.builds(), 1)

    def test_internal_pending_circuit_does_not_block_exit_demand(self):
        self.tor.pending = '9 EXTENDED $ABC BUILD_FLAGS=IS_INTERNAL,NEED_CAPACITY PURPOSE=GENERAL'
        recovery.recover(self.value);self.assertEqual(self.builds(), 1)

    def test_expired_directory_does_not_block_recovery(self):
        result = recovery.recover(dict(self.value, state='unavailable'))
        self.assertEqual(result['state'], 'starting');self.assertEqual(self.builds(), 1)

    def test_existing_build_is_observed_then_times_out(self):
        self.tor.pending = '9 EXTENDED $ABC PURPOSE=GENERAL'
        recovery.recover(self.value);self.assertEqual(self.builds(), 0)
        self.clock.return_value = 146
        self.assertEqual(recovery.recover(self.value)['state'], 'error')
        self.assertEqual(self.builds(), 0)

    def test_hidden_service_build_does_not_count_as_exit(self):
        self.tor.pending = '9 EXTENDED $ABC PURPOSE=HS_CLIENT_REND'
        recovery.recover(self.value);self.assertEqual(self.builds(), 1)

    def test_bounded_retries_and_manual_retry(self):
        for i in range(3):
            self.clock.return_value = 100 + i*60
            self.assertEqual(recovery.recover(self.value)['state'], 'starting')
            self.clock.return_value += 46
            self.assertEqual(recovery.recover(self.value)['state'], 'error')
        self.clock.return_value = 270
        self.assertEqual(recovery.recover(self.value)['state'], 'error');self.assertEqual(self.builds(), 3)
        recovery.recover(self.value, refresh=True);self.assertEqual(self.builds(), 4)

    def test_reopen_after_idle_recovers_without_restart_or_country_change(self):
        for i in range(3):
            self.clock.return_value = 100 + i*60;recovery.recover(self.value)
            self.clock.return_value += 46;recovery.recover(self.value)
        self.clock.return_value = 10000
        result = recovery.recover(self.value)
        self.assertEqual(result['state'], 'starting');self.assertEqual(self.builds(), 4)
        self.assertEqual(result['gatewayGeneration'], 'one')
        self.assertEqual(result['exitCountry'], 'RO')
        self.assertFalse(any(c.startswith(('SETCONF', 'SIGNAL NEWNYM', 'CLOSECIRCUIT')) for c in self.tor.commands))

    def test_continuously_open_panel_retries_after_bounded_backoff(self):
        for now in range(100, 580, 3):
            self.clock.return_value = now;recovery.recover(self.value)
        self.assertEqual(self.builds(), 3)
        self.clock.return_value = 580
        self.assertEqual(recovery.recover(self.value)['state'], 'starting')
        self.assertEqual(self.builds(), 4)

    def test_rejection_cools_down_and_ready_clears_recovery(self):
        self.tor.reject = True
        self.assertEqual(recovery.recover(self.value)['state'], 'error')
        recovery.recover(self.value);self.assertEqual(self.builds(), 1)
        ready = dict(self.value, state='ready', route=[{}, {}, {}], circuitId='42')
        self.assertEqual(recovery.recover(ready), ready)
        self.assertFalse((backend.RUNTIME/'circuit-recovery.json').exists())

    def test_country_or_gateway_change_starts_fresh_attempt(self):
        recovery.recover(self.value)
        recovery.recover(dict(self.value, exitCountry='DE'));self.assertEqual(self.builds(), 2)
        recovery.recover(dict(self.value, exitCountry='DE', gatewayGeneration='two'));self.assertEqual(self.builds(), 3)

    def test_offline_error_and_ready_do_not_create_demand(self):
        for value in [dict(self.value, running=False, state='offline'), dict(self.value, state='error'), dict(self.value, state='ready', route=[{}, {}, {}])]:
            self.assertEqual(recovery.recover(value), value)
        self.assertEqual(self.tor.commands, [])

    def test_explicit_refresh_keeps_existing_route(self):
        ready = dict(self.value, state='ready', route=[{}, {}, {}], circuitId='10')
        result = recovery.recover(ready, refresh=True)
        self.assertEqual(self.builds(), 1);self.assertEqual(result['route'], ready['route']);self.assertEqual(result['state'], 'ready')

    def test_cached_backend_reads_do_not_prime_and_cooldown_is_respected(self):
        import exit_controller, local_circuits
        with patch.object(backend, 'with_origin', side_effect=lambda v:v), patch.object(local_circuits, 'snapshot', return_value={}), patch.object(exit_controller, 'client', return_value=dict(self.value, nextChangeAt=12)), patch.object(recovery, 'recover', side_effect=lambda v, refresh=False:v) as recover:
            backend.request('cached');recover.assert_not_called()
            for _ in range(30): backend.request('status')
            recover.assert_not_called()
            backend.request('new-circuits');self.assertFalse(recover.call_args.kwargs['refresh'])
        with patch.object(backend, 'with_origin', side_effect=lambda v:v), patch.object(exit_controller, 'client', side_effect=[dict(self.value, nextChangeAt=0), dict(self.value, nextChangeAt=12)]), patch.object(recovery, 'recover', side_effect=lambda v, refresh=False:v) as recover:
            backend.request('new-circuits');self.assertTrue(recover.call_args.kwargs['refresh'])

    def test_completed_then_expired_circuit_is_not_rebuilt_by_status(self):
        import exit_controller, local_circuits
        recovery.recover(self.value)
        ready = dict(self.value, state='ready', circuitId='42', route=[{}, {}, {}])
        with patch.object(backend, 'with_origin', side_effect=lambda v:v), patch.object(local_circuits, 'snapshot', return_value={}), patch.object(exit_controller, 'client', return_value=ready) as client:
            backend.request('status')
            self.assertFalse((backend.RUNTIME/'circuit-recovery.json').exists())
            before = self.tor.commands[:]
            client.return_value = self.value
            for now in range(110, 210, 3):
                self.clock.return_value = now
                backend.request('status')
            self.assertEqual(self.tor.commands, before)
            # Another actual operation can create demand immediately.
            recovery.recover(self.value)
            self.assertEqual(self.builds(), 2)


if __name__ == '__main__': unittest.main()
