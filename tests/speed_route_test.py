from pathlib import Path
import sys
import threading
import unittest
from unittest.mock import MagicMock, patch

PLUGIN = Path(__file__).resolve().parents[1]/'backend'
sys.path.insert(0, str(PLUGIN))
import speed_route as r
import speed_compare as s

class SpeedRouteTest(unittest.TestCase):
 def test_distance_is_return_and_unknown_is_not_zero(self):
  points={'AA':[0,0],'BB':[90,0],'CC':[180,0]}
  self.assertEqual(r.describe(['AA','BB','CC'],points)['roundTripKm'],40000)
  self.assertNotIn('roundTripKm',r.describe(['AA',''],points))
  self.assertTrue(r.describe(['AA','AA'],points)['sameCountry'])
  self.assertNotIn('roundTripKm',r.describe(['AA','AA'],points))
 def test_cloudflare_header_and_local_geography(self):
  points,airports=r.geography()
  self.assertEqual(r.endpoint('HTTP/2 200\r\nCF-RAY: abc-FRA\r\n',airports),'DE')
  self.assertEqual(r.endpoint('cf-ray: abc-ZZZ\r\n',{}),'')
  self.assertEqual(r.endpoint('',airports),'')
  self.assertIn('TH',points)
 def test_only_tagged_stream_and_linked_circuits(self):
  watch=r.CircuitWatch();watch.tag='test-tag';control=MagicMock()
  circuits='7 BUILT $a PURPOSE=CONFLUX_LINKED CONFLUX_ID=ABC\n8 BUILT $b PURPOSE=CONFLUX_LINKED CONFLUX_ID=ABC\n9 BUILT $c PURPOSE=GENERAL\n10 BUILT $d PURPOSE=CONFLUX_LINKED CONFLUX_ID=ABC123'
  def command(q):
   if q=='GETINFO circuit-status':return circuits
   if q=='GETINFO ip-to-country/1.1.1.1':return 'ip-to-country/1.1.1.1=de\nOK'
   if q=='GETINFO ip-to-country/2.2.2.2':return 'ip-to-country/2.2.2.2=nl\nOK'
   self.fail('Unexpected command '+q)
  control.command.side_effect=command
  with patch('backend.circuit_route',side_effect=lambda c,cid,cs:[{'ip':'1.1.1.1' if cid=='7' else '2.2.2.2'}]):
   watch.event('STREAM 12 SUCCEEDED 9 1.2.3.4:443 SOCKS_USERNAME="other"',control)
   self.assertEqual(watch.data,{})
   watch.event('STREAM 13 NEW 0 speed.cloudflare.com:443 SOCKS_USERNAME="test-tag"',control)
   watch.event('STREAM 13 SUCCEEDED 7 1.2.3.4:443',control)
   self.assertEqual(watch.data['relayPaths'],[['DE'],['NL']])
   self.assertEqual(watch.data['circuitIds'],['7','8'])
   self.assertTrue(watch.data['multipath'])
   watch.event('STREAM 13 DETACHED 0 speed.cloudflare.com:443',control)
   self.assertEqual(watch.data,{})
 def test_enrichment_does_not_send_locations_to_server(self):
  watch=MagicMock();watch.tag='tag';watch.data={'circuitId':'7','circuitIds':['7'],'relayPaths':[['DE','NL','US']],'multipath':False}
  def download(route,emit,cancelled,locations,watcher,headers):
   Path(headers).write_text('CF-RAY: abc-FRA\r\n')
   emit({'status':'running','bytes':1})
   return {'status':'complete','mbps':1}
  with patch.object(r,'CircuitWatch',return_value=watch),patch.object(s,'measure_download',side_effect=download):
   updates=[];value=s.measure('tor',updates.append,threading.Event(),{'origin':'TH'})
   self.assertEqual(value['countries'],['TH','DE','NL','US','DE'])
   self.assertGreater(value['roundTripKm'],20000)
   self.assertEqual(updates[0]['countries'],value['countries']);watch.close.assert_called_once()
 def test_totals_include_client_and_server_for_each_conflux_path(self):
  # Identical guard/middle countries do not make the full journey zero.
  watch=MagicMock();watch.data={'circuitId':'7','circuitIds':['7','8'],'relayPaths':[['DE','DE','NL'],['GB','CH','NL']],'multipath':True}
  points={'TH':[0,0],'DE':[10,0],'NL':[20,0],'US':[30,0],'GB':[40,0],'CH':[50,0]}
  def download(route,emit,cancelled,locations,watcher,headers):
   Path(headers).write_text('CF-RAY: abc-AAA\r\n')
   return {'status':'complete','mbps':1}
  with patch.object(r,'CircuitWatch',return_value=watch),patch.object(r,'geography',return_value=(points,{'AAA':'US'})),patch.object(s,'measure_download',side_effect=download):
   value=s.measure('tor',lambda _:None,threading.Event(),{'origin':'TH'})
  self.assertEqual(value['paths'][0]['countries'],['TH','DE','DE','NL','US'])
  self.assertEqual(value['paths'][0]['roundTripKm'],6700)
  self.assertEqual(value['paths'][1]['countries'],['TH','GB','CH','NL','US'])
  self.assertEqual(value['paths'][1]['roundTripKm'],20000)
 def test_unknown_endpoint_omits_distance(self):
  watch=MagicMock();watch.data={'circuitId':'7','circuitIds':['7'],'relayPaths':[['DE']],'multipath':False}
  with patch.object(r,'CircuitWatch',return_value=watch),patch.object(s,'measure_download',return_value={'status':'failed'}):
   value=s.measure('tor',lambda _:None,threading.Event(),{'origin':'TH'})
   self.assertEqual(value['countries'],['TH','DE','?']);self.assertNotIn('roundTripKm',value)
 def test_real_command_preserves_config_disable_and_socks_tag(self):
  # No real network: run cancellation after inspecting the actual command.
  watch=MagicMock();watch.tag='only-this-test'
  cancel=threading.Event();cancel.set();process=MagicMock();process.poll.return_value=0
  with patch.object(s.subprocess,'Popen',return_value=process) as popen,patch.object(s.selectors,'DefaultSelector'):
   s.measure_download('tor',lambda _:None,cancel,{},watch,'/tmp/example-header')
   args=popen.call_args.args[0]
   self.assertEqual(args[1],'-q');self.assertEqual(args[args.index('--proxy-user')+1],'only-this-test:test')
   self.assertEqual(args[-1],s.TOR_URL);self.assertIn('socks5h://localhost'+s.SOCKS,args)


 def test_shared_exit_needs_relay_identity(self):
  watch=r.CircuitWatch();watch.circuit_id='7';control=MagicMock()
  control.command.return_value='7 BUILT $a CONFLUX_ID=ABC\n8 BUILT $b CONFLUX_ID=ABC'
  with patch('backend.circuit_route',side_effect=lambda c,cid,cs:[{'ip':'1.1.1.1','fingerprint':cid}]):
   watch.resolve(control);self.assertFalse(watch.data['sharedExitConfirmed'])
  with patch('backend.circuit_route',return_value=[{'ip':'1.1.1.1','fingerprint':'same-exit'}]):
   watch.resolve(control);self.assertTrue(watch.data['sharedExitConfirmed'])
  with patch('backend.circuit_route',return_value=[{'ip':'1.1.1.1'}]):
   watch.resolve(control);self.assertFalse(watch.data['sharedExitConfirmed'])

if __name__=='__main__':unittest.main()
