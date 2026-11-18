import base64
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'backend'))
import backend
import local_circuits as lc

A,B,C='A'*40,'B'*40,'C'*40

def router(fp,ip):
    return 'r relay '+base64.b64encode(bytes.fromhex(fp)).decode().rstrip('=')+' digest 2026-01-01 00:00:00 '+ip+' 9001 0'

class Control:
    def __init__(self,reply):self.reply=reply;self.commands=[]
    def __enter__(self):return self
    def __exit__(self,*args):pass
    def command(self,cmd):
        self.commands.append(cmd)
        if cmd=='GETINFO circuit-status':return self.reply
        if cmd=='GETINFO ns/all':return router(A,'8.8.8.8')+'\n'+router(B,'1.1.1.1')
        if cmd.startswith('GETINFO ip-to-country/'):
            return 'ip-to-country/8.8.8.8=DE\nip-to-country/1.1.1.1=FR'
        raise AssertionError(cmd)

class LocalCircuitsTest(unittest.TestCase):
    def sample(self,control):
        with tempfile.TemporaryDirectory() as folder,patch.object(backend,'RUNTIME',Path(folder)),patch.object(backend,'DATA',Path(folder)/'data'),patch.object(backend,'Controller',return_value=control),patch.object(backend,'gateway_generation',return_value='generation'):
            return lc.snapshot()

    def test_all_built_purposes_and_short_paths(self):
        reply=f'1 BUILT ${A} PURPOSE=GENERAL\n2 BUILT ${A},${B} PURPOSE=HS_CLIENT_REND\n3 BUILT ${B} PURPOSE=CONFLUX_LINKED\n4 LAUNCHED\n5 CLOSED ${A}\n6 BUILT PURPOSE=GENERAL'
        value=self.sample(Control(reply))
        self.assertEqual(value['count'],4)
        self.assertEqual([v['id'] for v in value['circuits']],['1','2','3','6'])
        self.assertEqual(value['circuits'][-1]['route'],[])

    def test_private_hops_are_gaps_and_commands_are_read_only(self):
        control=Control(f'1 BUILT ${C},${A},${B} PURPOSE=GENERAL')
        value=self.sample(control)
        self.assertEqual(value['circuits'][0]['route'][0],{})
        self.assertNotIn(C,str(value))
        self.assertNotIn('8.8.8.8',str(value))
        self.assertIn('longitude',value['circuits'][0]['route'][1])
        self.assertTrue(all(c.startswith('GETINFO ') for c in control.commands))
        self.assertFalse(any('ns/id' in c for c in control.commands))

    def test_zero_is_not_unavailable(self):
        value=self.sample(Control('circuit-status=\nOK'))
        self.assertTrue(value['available']);self.assertEqual(value['count'],0)
        with patch.object(backend,'gateway_generation',side_effect=FileNotFoundError):
            value=lc.snapshot()
        self.assertFalse(value['available']);self.assertIsNone(value['count'])

    def test_missing_geoip_keeps_count_but_no_coordinates(self):
        control=Control(f'1 BUILT ${A} PURPOSE=GENERAL')
        original=control.command
        control.command=lambda cmd: '' if 'ip-to-country/' in cmd else original(cmd)
        value=self.sample(control)
        self.assertEqual(value['count'],1)
        self.assertNotIn('longitude',value['circuits'][0]['route'][0])

    def test_directory_failure_keeps_count_and_gaps(self):
        control=Control(f'1 BUILT ${A} PURPOSE=GENERAL')
        original=control.command
        def command(cmd):
            if cmd=='GETINFO ns/all':raise RuntimeError('Unavailable')
            return original(cmd)
        control.command=command
        value=self.sample(control)
        self.assertEqual(value['count'],1)
        self.assertEqual(value['circuits'][0]['route'],[{}])

    def test_generation_change_invalidates_snapshot(self):
        with patch.object(backend,'gateway_generation',side_effect=['old','new']),patch.object(backend,'Controller',return_value=Control('')),tempfile.TemporaryDirectory() as folder,patch.object(backend,'RUNTIME',Path(folder)),patch.object(backend,'DATA',Path(folder)/'data'):
            self.assertFalse(lc.snapshot()['available'])

    def test_same_country_relays_have_distinct_stable_in_country_points(self):
        from exit_network import geometry_index,in_polygon
        def placed(order):
            rows=[dict(id=str(i),route=[dict(fingerprint=fp,country='DE')]) for i,fp in enumerate(order)]
            lc.place_relays(rows)
            return [r['route'][0] for r in rows]
        first=placed([A,B,A]);second=placed([B,A])
        self.assertEqual(first[0],first[2])
        self.assertEqual(first[0],second[1])
        self.assertEqual(first[1],second[0])
        self.assertNotEqual((first[0]['longitude'],first[0]['latitude']),(first[1]['longitude'],first[1]['latitude']))
        for hop in first:
            self.assertTrue(any(in_polygon(hop['longitude'],hop['latitude'],p) for p in geometry_index()['DE']))
            self.assertEqual(hop['positionKind'],'illustrative-in-country')
