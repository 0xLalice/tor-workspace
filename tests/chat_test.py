from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch,Mock
from concurrent.futures import ThreadPoolExecutor
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'backend'))
import chat
import share

class ChatTests(unittest.TestCase):
 def setUp(self):
  tmp=tempfile.TemporaryDirectory();self.addCleanup(tmp.cleanup)
  for target,value in [('ROOT',Path(tmp.name)/'chat')]:
   p=patch.object(chat,target,value);p.start();self.addCleanup(p.stop)
  p=patch.object(chat,'ensure_tor',return_value='generation');self.tor=p.start();self.addCleanup(p.stop)
  p=patch.object(chat.subprocess,'run',return_value=Mock(returncode=0));self.run=p.start();self.addCleanup(p.stop)
 def test_open_status_never_starts_anything(self):
  self.assertEqual(chat.status()['state'],'idle');self.run.assert_not_called();self.tor.assert_not_called()
  with self.assertRaises(RuntimeError):chat.ready_url()
 def test_start_is_single_and_stop_clears_link(self):
  with ThreadPoolExecutor(max_workers=3) as pool:list(pool.map(lambda _:chat.start(),range(3)))
  self.assertEqual(sum(c.args[0][0]=='systemd-run' for c in self.run.call_args_list),1)
  chat.save(dict(state='ready',url='http://'+'a'*56+'.onion'))
  self.assertTrue(chat.ready_url().endswith('.onion'))
  self.assertEqual(chat.stop()['url'],'');self.assertFalse((chat.ROOT/'request.json').exists())
 def test_off_never_launches(self):
  self.tor.side_effect=RuntimeError('Start Tor before sharing.')
  self.assertEqual(chat.start()['state'],'error')
  self.assertIn('Start Tor',chat.status()['message'])
  self.run.assert_not_called()
 def test_stale_worker_and_private_state(self):
  chat.start();chat.save(dict(state='ready',url='http://'+'a'*56+'.onion'))
  self.assertEqual((chat.ROOT/'state.json').stat().st_mode&0o777,0o600)
  with patch.object(chat.time,'time',return_value=9999999999):self.assertEqual(chat.status()['url'],'')
  chat.cleanup();self.assertEqual(chat.status()['state'],'error')
 def test_worker_runs_chat_and_stops_on_gateway_change(self):
  from io import StringIO
  chat.start()
  child=Mock(pid=12345,stdout=StringIO(''),poll=Mock(return_value=None))
  ending=Mock();ending.wait.return_value=False;ending.is_set.return_value=False
  with patch.object(share.subprocess,'Popen',return_value=child) as popen,patch.object(share.threading,'Event',return_value=ending),patch.object(share.threading,'Thread'),patch.object(share.signal,'signal'),patch.object(share.backend,'gateway_generation',return_value='different'),patch.object(share.os,'killpg'):
   share.run_worker(chat.ROOT,chat.save,'chat')
  self.assertIn('--chat',popen.call_args.args[0]);self.assertNotIn('--no-autostop-sharing',popen.call_args.args[0])
  self.assertEqual(chat.status()['state'],'stopped');self.assertEqual(chat.status()['url'],'')
 def test_failed_launch_can_retry(self):
  self.run.side_effect=lambda args,**kwargs:Mock(returncode=1 if args[0]=='systemd-run' else 0)
  self.assertEqual(chat.start()['state'],'error')
  self.run.side_effect=None
  self.assertEqual(chat.start()['state'],'starting')

 def test_worker_timeout_and_failure(self):
  from io import StringIO
  for failed in (False,True):
   with self.subTest(failed=failed):
    chat.start()
    child=Mock(pid=12345,stdout=StringIO(''),poll=Mock(return_value=1 if failed else None))
    ending=Mock();ending.wait.return_value=False;ending.is_set.return_value=False
    with patch.object(share.subprocess,'Popen',return_value=child),patch.object(share.threading,'Event',return_value=ending),patch.object(share.threading,'Thread'),patch.object(share.signal,'signal'),patch.object(share.backend,'gateway_generation',return_value='generation'),patch.object(share.time,'monotonic',side_effect=[0,121]),patch.object(share.os,'killpg'):
     share.run_worker(chat.ROOT,chat.save,'chat')
    self.assertEqual(chat.status()['state'],'error')
    self.assertIn('unexpectedly' if failed else '120 seconds',chat.status()['message'])
    self.assertFalse((chat.ROOT/'work').exists())
    self.assertEqual(chat.start()['state'],'starting')
    chat.stop()
 def test_participant_count_expires_instead_of_claiming_empty(self):
  chat.save(dict(state='ready',url='http://'+'a'*56+'.onion',participants=2,participantsAt=chat.time.time()))
  self.assertEqual(chat.status()['participants'],2)
  with patch.object(chat.time,'time',return_value=chat.time.time()+6):self.assertNotIn('participants',chat.status())
  chat.save(dict(state='stopped',url='',participants=2,participantsAt=chat.time.time()))
  self.assertNotIn('participants',chat.status())

 def test_count_from_worker_contains_no_participant_names(self):
  from io import StringIO
  chat.start();chat.save(dict(state='ready',url='http://'+'a'*56+'.onion'))
  child=Mock(pid=12345,stdout=StringIO(''),poll=Mock(return_value=None))
  ending=Mock();ending.wait.side_effect=[False,True];ending.is_set.return_value=False
  messages=Mock();messages.get_nowait.side_effect=['WORKSPACE_ROOM_COUNT 2',share.queue.Empty]
  with patch.object(share.subprocess,'Popen',return_value=child),patch.object(share.threading,'Event',return_value=ending),patch.object(share.threading,'Thread'),patch.object(share.queue,'Queue',return_value=messages),patch.object(share.signal,'signal'),patch.object(share.backend,'gateway_generation',return_value='generation'),patch.object(share.os,'killpg'):
   share.run_worker(chat.ROOT,chat.save,'chat')
  self.assertEqual(chat.status()['participants'],2)
  self.assertNotIn('users',chat.status())

 def test_stop_failure_allows_explicit_retry(self):
  chat.start()
  with patch.object(chat,'stop_service',side_effect=RuntimeError('Retry Stop room.')):
   self.assertIn('error',chat.stop())
  self.assertEqual(chat.stop()['state'],'stopped')

if __name__=='__main__':unittest.main()
