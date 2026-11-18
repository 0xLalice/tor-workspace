import base64
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock,patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'backend'))
import relay_info as relay
FP='A'*40
ROUTER='r Example '+base64.b64encode(bytes.fromhex(FP)).decode().rstrip('=')+' digest 2026-09-24 00:00:00 1.2.3.4 9001 0\ns Running Valid Exit\nw Bandwidth=99999'
class RelayInfoTests(unittest.TestCase):
 def setUp(self):
  temporary=tempfile.TemporaryDirectory();self.addCleanup(temporary.cleanup)
  p=patch.object(relay,'CACHE',Path(temporary.name));p.start();self.addCleanup(p.stop)
  p=patch.object(relay.backend,'Controller');self.control=p.start().return_value.__enter__.return_value;self.addCleanup(p.stop)
  self.control.command.side_effect=lambda command:ROUTER if command.startswith('GETINFO ns/id/') else 'bandwidth 1000 2000 500\nplatform Tor 0.4.8.21 on Linux'
 def test_local_identity_and_bandwidth(self):
  value=relay.local(FP.lower());self.assertTrue(value['public']);self.assertEqual(value['local']['advertised_bandwidth'],500)
  self.assertEqual(value['local']['flags'],['Running','Valid','Exit'])
  self.assertTrue(all(call.args[0].startswith('GETINFO ') for call in self.control.command.call_args_list))
 def test_missing_public_relay_never_queries_remote(self):
  self.control.command.return_value='';self.control.command.side_effect=None
  with patch.object(relay.subprocess,'run') as run:
   self.assertTrue(relay.enrich(FP)['unavailable']);run.assert_not_called()
 def test_cache_and_tor_only_fetch(self):
  payload={'relays_published':'2026-09-24 00:00:00','relays':[{'fingerprint':FP,'nickname':'Exact','running':False,'first_seen':'2020-01-01 00:00:00'}]}
  with patch.object(relay.subprocess,'run',return_value=Mock(stdout=json.dumps(payload))) as run:
   first=relay.enrich(FP);self.assertFalse(first['loading']);self.assertEqual(first['remote']['nickname'],'Exact')
   second=relay.enrich(FP);self.assertTrue(second['cached']);self.assertEqual(run.call_count,1)
   command=run.call_args.args[0];self.assertIn('--proxy',command);self.assertIn('--noproxy',command);self.assertIn('--max-time',command)
 def test_failed_refresh_retains_cache_and_cools_down(self):
  relay.save(relay.CACHE/(FP+'.json'),{'data':{'nickname':'Old'},'fetchedAt':1})
  with patch.object(relay.subprocess,'run',side_effect=subprocess.TimeoutExpired('curl',18)) as run:
   first=relay.enrich(FP);self.assertTrue(first['unavailable']);self.assertEqual(first['remote']['nickname'],'Old')
   relay.enrich(FP);self.assertEqual(run.call_count,1)
 def test_mismatched_and_malformed_data(self):
  for payload in ({'relays':[{'fingerprint':'B'*40}]},{'relays':[{'fingerprint':FP,'running':'yes'}]},{'relays':[{'fingerprint':FP,'advertised_bandwidth':-1}]}):
   with self.assertRaises(ValueError):relay.normalize(payload,FP)
 def test_invalid_identity(self):
  for fp in ('../x',None,'A'*39):
   with self.assertRaises(ValueError):relay.identity(fp)
if __name__=='__main__':unittest.main()
