#!/usr/bin/env python3
"""Protocol regressions: circuit parsing and local directory observations."""
import importlib.util
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import MagicMock, patch

spec = importlib.util.spec_from_file_location('panel_backend', Path(__file__).parents[1] / 'backend/backend.py')
backend = importlib.util.module_from_spec(spec)
spec.loader.exec_module(backend)
sys.path.insert(0, str(Path(__file__).parents[1] / 'backend'))
from local_circuits import parse_built
from exit_controller import built_circuits
from circuit_recovery import pending_general
FINGERPRINTS = ['A' * 40, 'B' * 40, 'C' * 40]
PATH = ','.join('$' + fingerprint + '~Relay' for fingerprint in FINGERPRINTS)


class ScriptedStream:
    def __init__(self, lines):
        self.lines = iter((line + '\r\n').encode() for line in lines)
        self.written = []

    def readline(self, *_):
        return next(self.lines, b'')

    def write(self, value):
        self.written.append(value)


class RouteTests(unittest.TestCase):
    def circuit_reply(self, lines):
        controller = backend.Controller()
        controller.events = []
        controller.stream = ScriptedStream(lines + ['250 OK', '250-version=example', '250 OK'])
        reply = controller.command('GETINFO circuit-status')
        self.assertEqual(controller.command('GETINFO version'), 'version=example\nOK')
        return reply

    def test_single_inline_circuit_matches_multiline_and_all_readers(self):
        row = '33 BUILT ' + PATH + ' PURPOSE=GENERAL'
        inline = self.circuit_reply(['250-circuit-status=' + row])
        multiline = self.circuit_reply(['250+circuit-status=', row, '.'])
        self.assertEqual(inline, multiline)
        self.assertEqual(parse_built(inline), [('33', FINGERPRINTS)])
        self.assertEqual(built_circuits(inline), {'33': FINGERPRINTS})
        relay = MagicMock()
        relay.command.return_value = 'r Relay identity descriptor 2026-09-18 00:00:00 192.0.2.1 443 0'
        self.assertEqual(len(backend.circuit_route(relay, '33', inline)), 3)

    def test_empty_reply_still_means_zero(self):
        reply = self.circuit_reply(['250-circuit-status='])
        self.assertEqual(parse_built(reply), [])
        self.assertEqual(built_circuits(reply), {})
        self.assertFalse(pending_general(reply))

    def test_multiple_circuits_keep_all_numeric_ids(self):
        reply = self.circuit_reply(['250+circuit-status=',
            '33 BUILT ' + PATH + ' PURPOSE=GENERAL',
            '34 BUILT ' + PATH + ' PURPOSE=CONFLUX_LINKED', '.'])
        self.assertEqual([cid for cid, _ in parse_built(reply)], ['33', '34'])
        self.assertEqual(list(built_circuits(reply)), ['33', '34'])

    def test_single_pending_circuit_is_seen_without_counting_it_as_built(self):
        reply = self.circuit_reply(['250-circuit-status=33 EXTENDED ' + PATH + ' PURPOSE=GENERAL'])
        self.assertTrue(pending_general(reply))
        self.assertEqual(parse_built(reply), [])
        self.assertEqual(built_circuits(reply), {})

    def test_events_and_multiline_data_preserve_next_reply(self):
        controller = backend.Controller()
        controller.events = []
        controller.stream = ScriptedStream([
            '650 STREAM 42 NEW 0 check.torproject.org:443 SOCKS_USERNAME="omarchy-tor-panel"',
            '250+circuit-status=',
            '176 BUILT ' + PATH + ' PURPOSE=GENERAL',
            '.',
            '650 STREAM 42 SUCCEEDED 176 1.2.3.4:443',
            '250 OK',
            '250+ns/id/example=',
            '..dot-stuffed',
            '.',
            '250 OK',
        ])
        reply = controller.command('GETINFO circuit-status')
        self.assertIn('176 BUILT ' + PATH, reply)
        self.assertNotIn('STREAM', reply)
        self.assertEqual(len(controller.events), 2)
        self.assertIn('\n.dot-stuffed\n', controller.command('GETINFO ns/id/example'))

    def test_selects_matched_successful_stream_and_preserves_hop_order(self):
        circuit_id = '176'

        class RelayInfo:
            def command(self, request):
                index = FINGERPRINTS.index(request.removeprefix('GETINFO ns/id/'))
                return f'r Relay{index} identity descriptor 2026-09-18 00:00:00 192.0.2.{index + 1} 443 0\nOK'

        circuits = '999 BUILT $' + 'D' * 40 + '~Unrelated PURPOSE=GENERAL\n176 BUILT ' + PATH + ' PURPOSE=GENERAL'
        route = backend.circuit_route(RelayInfo(), circuit_id, circuits)
        self.assertEqual([hop['role'] for hop in route], ['Guard', 'Middle', 'Exit'])
        self.assertEqual([hop['ip'] for hop in route], ['192.0.2.1', '192.0.2.2', '192.0.2.3'])

    def test_never_substitutes_an_unrelated_circuit(self):
        circuits = '999 BUILT ' + PATH + ' PURPOSE=GENERAL'
        self.assertEqual(backend.circuit_route(None, '', circuits), [])
        self.assertEqual(backend.circuit_route(None, '176', circuits), [])


class ExitCountryTests(unittest.TestCase):
    def test_counts_relays_not_ips_and_filters_nonusable_exits(self):
        records = [('a','192.0.2.1','Exit Running Valid'),
                   ('b','192.0.2.1','Exit Running Valid'),
                   ('c','192.0.2.2','Exit Running Valid'),
                   ('d','192.0.2.3','Exit Running Valid BadExit'),
                   ('e','192.0.2.4','Running Valid'),
                   ('f','192.0.2.5','Exit Valid')]
        directory='ns/all=\n'+'\n'.join(
            f'r Relay {identity} digest 2026-09-20 00:00:00 {address} 443 0\ns {flags}'
            for identity,address,flags in records)+'\nOK'
        control=MagicMock()
        control.command.side_effect=[directory,
            'ip-to-country/192.0.2.1=de\nip-to-country/192.0.2.2=is\nOK']
        with patch.object(backend,'Controller') as factory, \
             patch.object(backend,'country_names',return_value={'DE':'Germany','IS':'Iceland','FR':'France'}), \
             patch.object(backend.subprocess,'run',side_effect=AssertionError('No external request')):
            factory.return_value.__enter__.return_value=control
            result=backend.exit_countries()
        self.assertEqual([(r['code'],r['count']) for r in result],[('',3),('DE',2),('IS',1)])
        self.assertEqual(result[1]['name'],'Germany (2 exits)')
        self.assertEqual(result[2]['name'],'Iceland (1 exit)')
        control.command.assert_called_with('GETINFO ip-to-country/192.0.2.1 ip-to-country/192.0.2.2')

    def test_empty_directory_only_offers_automatic(self):
        with patch.object(backend,'Controller') as factory:
            factory.return_value.__enter__.return_value.command.return_value='ns/all=\nOK'
            self.assertEqual(backend.exit_countries(),[{'code':'','name':'Any country (0 exits)','count':0}])

    def test_offline_does_not_invent_country_availability(self):
        with patch.object(backend,'Controller',side_effect=OSError('offline')):
            result=backend.exit_countries()
        self.assertGreater(len(result),1)
        self.assertTrue(all(item['count'] is None for item in result))
        self.assertIsNone(result[0]['count'])
        self.assertIn('unavailable',result[0]['name'])


class OriginTests(unittest.TestCase):
    def test_origin_lookup_is_direct_and_country_uses_explicit_ip(self):
        response = subprocess.CompletedProcess([],0,stdout='{"ip":"198.51.100.1"}')
        with patch.object(backend.subprocess, 'run', return_value=response) as curl, \
             patch.object(backend, 'query_country', return_value='TH') as country:
            result = backend.query_origin()
        command = curl.call_args.args[0]
        self.assertEqual(command[command.index('--noproxy')+1], '*')
        self.assertNotIn('--proxy', command)
        country.assert_called_once_with('198.51.100.1')
        self.assertEqual(result['role'], 'You')
        self.assertEqual(result['country'], 'TH')

    def test_unavailable_origin_stays_unknown(self):
        with patch.object(backend.subprocess, 'run', return_value=subprocess.CompletedProcess([],1)):
            origin = backend.query_origin()
        self.assertEqual(origin['country'], '')
        self.assertEqual(origin['ip'], '')
        value = backend.add_map_points({'origin': origin, 'route': []})
        self.assertNotIn('longitude', value['origin'])


if __name__ == '__main__':
    unittest.main()
