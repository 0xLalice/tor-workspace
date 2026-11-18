from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'backend'))
import host

SERVICE_ID = 'a'*56

class HostTests(unittest.TestCase):
 def setUp(self):
  tmp=tempfile.TemporaryDirectory();self.addCleanup(tmp.cleanup);self.tmp=Path(tmp.name)
  for attr,value in [('ROOT',self.tmp/'runtime'),('DATA',self.tmp/'data')]:
   p=patch.object(host,attr,value);p.start();self.addCleanup(p.stop)
  self.folder=self.tmp/'site';self.folder.mkdir();(self.folder/'index.html').write_text('hello')
  self.source=dict(mode='folder',folder=str(self.folder))
  for target,kw in [('subprocess.run',dict(return_value=Mock(returncode=0))),('backend.Controller',{}),('backend.gateway_generation',dict(return_value='test')),('require_available_tor',dict(return_value='test')),('shutil.which',dict(return_value='/usr/bin/onionshare-cli'))]:
   p=patch('host.'+target,**kw);m=p.start();self.addCleanup(p.stop)
   if target=='subprocess.run':self.run=m
 def test_status_does_not_launch_or_create_state(self):
  self.assertEqual(host.status()['state'],'stopped');self.run.assert_not_called();self.assertFalse(host.DATA.exists())
 def test_validation(self):
  for source in [dict(mode='app',port=p) for p in [0,65536,'3000',True]]+[dict(mode='no'),dict(mode='folder',folder='')]:
   with self.assertRaises(ValueError):host.validate(source)
  with patch.object(host.socket,'create_connection',side_effect=OSError()):
   with self.assertRaisesRegex(ValueError,'Start your app'):host.validate(dict(mode='app',port=3000))
  with patch.object(host.socket,'create_connection') as connect:
   source=host.validate(dict(mode='app',port=3000,folder='/ignored'))
   self.assertEqual(source['folder'],'');self.assertEqual(connect.call_args.args[0],('127.0.0.1',3000))
 def test_single_worker_and_stop_clears_link(self):
  with ThreadPoolExecutor(max_workers=3) as pool:list(pool.map(lambda _:host.start(self.source),range(3)))
  self.assertEqual(sum(c.args[0][0]=='systemd-run' for c in self.run.call_args_list),1)
  host.save(dict(state='ready',url='http://'+SERVICE_ID+'.onion'))
  self.assertIn(SERVICE_ID,host.ready_url())
  self.assertEqual(host.stop()['url'],'')
  self.assertEqual(host.start(self.source)['url'],'')
 def test_tor_unavailable(self):
  with patch.object(host.backend,'Controller',side_effect=OSError()):
   self.assertIn('Start Tor',host.start(self.source)['error'])
  self.run.assert_not_called()
 def test_unavailable_service_does_not_create_worker(self):
  with patch.object(host,'require_available_tor',side_effect=RuntimeError('Tor is not available. Start Tor and retry.')):
   self.assertIn('Tor is not available',host.start(self.source)['error'])
  self.run.assert_not_called()
  self.assertFalse((host.ROOT/'request.json').exists())
 def test_website_session_uses_children_and_no_saved_key(self):
  session=host.website_session(host.validate(self.source))
  self.assertEqual(session['website']['filenames'],[str(self.folder/'index.html')])
  self.assertTrue(session['general']['public']);self.assertIsNone(session['onion']['private_key'])
 def test_stale_worker_and_cleanup(self):
  host.start(self.source)
  with patch.object(host.time,'time',return_value=9999999999):self.assertEqual(host.status()['state'],'error')
  host.cleanup();self.assertFalse((host.ROOT/'request.json').exists());self.assertTrue((host.DATA/'source.json').exists())
 def test_register_always_requests_a_new_service(self):
  control=Mock();control.command.side_effect=['ServiceID='+SERVICE_ID+'\nOK','ServiceID='+'b'*56+'\nOK','ServiceID=invalid\nOK']
  self.assertEqual(host.register(control,3000),SERVICE_ID)
  self.assertEqual(host.register(control,3000),'b'*56)
  for call in control.command.call_args_list:self.assertEqual(call.args[0],'ADD_ONION NEW:ED25519-V3 Port=80,127.0.0.1:3000')
  with self.assertRaisesRegex(RuntimeError,'valid onion address'):host.register(control,3000)
 def test_publication_correlates_unknown_address_without_other_services(self):
  dirs=set()
  self.assertFalse(host.published(['HS_DESC UPLOAD other NO_AUTH otherdir','HS_DESC UPLOADED UNKNOWN UNKNOWN otherdir'],SERVICE_ID,dirs))
  self.assertFalse(host.published(['HS_DESC UPLOAD '+SERVICE_ID+' NO_AUTH ourdir'],SERVICE_ID,dirs))
  self.assertTrue(host.published(['HS_DESC UPLOADED UNKNOWN UNKNOWN ourdir'],SERVICE_ID,dirs))
 def test_old_address_settings_are_ignored(self):
  host.write(host.DATA/'source.json',dict(self.source,persistent=True))
  host.write(host.DATA/'identity.json',dict(service_id=SERVICE_ID))
  host.write(host.DATA/'links.json',{'old':'unused'})
  self.assertEqual(host.status()['url'],'')
  self.assertNotIn('persistent',host.status()['source'])
  self.assertNotIn('sources',host.status())
  self.assertEqual(host.start(self.source)['state'],'starting')
  self.assertEqual(host.strict_read(host.DATA/'source.json'),host.validate(self.source))
 def test_worker_closes_on_gateway_change_without_saving_identity(self):
  host.write(host.ROOT/'request.json',dict(source=dict(mode='app',port=3000),generation='old'))
  with patch.object(host.socket,'create_connection'),patch.object(host,'register',return_value=SERVICE_ID),patch.object(host.signal,'signal'),patch.object(host.backend,'Controller') as controller:
   host.worker()
  controller.return_value.__exit__.assert_called_once()
  self.assertEqual(host.status()['state'],'stopped');self.assertEqual(host.status()['url'],'')
  self.assertFalse((host.ROOT/'work').exists());self.assertFalse(host.DATA.exists())
 def test_corrupt_source_is_not_replaced(self):
  host.DATA.mkdir();path=host.DATA/'source.json';path.write_text('{')
  self.assertEqual(host.start(self.source)['state'],'error');self.assertEqual(path.read_text(),'{')
  self.run.assert_not_called()
 def test_stop_failure_can_retry(self):
  host.start(self.source)
  with patch.object(host,'stop_service',side_effect=RuntimeError('Retry Stop')):
   self.assertEqual(host.stop()['state'],'stopping');self.assertIn('Retry',host.status()['error'])
  self.assertEqual(host.stop()['state'],'stopped')

class ReachabilityTests(unittest.TestCase):
 def test_pending_failed_and_successful_connections(self):
  probe=host.Reachability()
  failed=Mock(returncode=28);failed.poll.side_effect=[None,28];failed.communicate.return_value=('000',None)
  reached=Mock(returncode=0);reached.poll.return_value=0;reached.communicate.return_value=('405',None)
  with patch.object(host.subprocess,'Popen',side_effect=[failed,reached]) as spawn,patch.object(host.time,'monotonic',return_value=10) as clock:
   self.assertFalse(probe.poll('http://'+SERVICE_ID+'.onion'))
   self.assertFalse(probe.poll('http://'+SERVICE_ID+'.onion'))
   self.assertFalse(probe.poll('http://'+SERVICE_ID+'.onion'))
   self.assertEqual(spawn.call_count,1)
   clock.return_value=12
   self.assertFalse(probe.poll('http://'+SERVICE_ID+'.onion'))
   self.assertTrue(probe.poll('http://'+SERVICE_ID+'.onion'))
   args=spawn.call_args.args[0]
   self.assertIn('--head',args)
   self.assertEqual(args[args.index('--proxy')+1],'socks5h://localhost'+str(host.backend.GATEWAY/'socks'))
   self.assertEqual(args[args.index('--noproxy')+1],'')
   self.assertIsNone(probe.process)
 def test_cancellation_reaps_probe(self):
  probe=host.Reachability();child=Mock();child.poll.return_value=None;probe.process=child
  probe.close()
  child.terminate.assert_called_once();child.wait.assert_called_once_with(timeout=2)
  child.communicate.assert_called_once();self.assertIsNone(probe.process)
 def test_non_http_output_never_confirms_reachability(self):
  for code,output in [(0,'000'),(0,''),(0,'200unexpected'),(7,'200')]:
   probe=host.Reachability();child=Mock(returncode=code);child.poll.return_value=code;child.communicate.return_value=(output,None);probe.process=child
   self.assertFalse(probe.poll('http://'+SERVICE_ID+'.onion'))

if __name__=='__main__':unittest.main()
