import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import threading
import time
import unittest
from unittest.mock import patch, MagicMock
spec=importlib.util.spec_from_file_location('speed_compare',Path(__file__).resolve().parents[1]/'backend/speed_compare.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class SpeedTest(unittest.TestCase):
 def test_routes(self):
  direct=m.command('direct','https://test.oca.nflxvideo.net/speedtest');tor=m.command('tor')
  self.assertEqual(direct[-1],'https://test.oca.nflxvideo.net/speedtest');self.assertEqual(tor[-1],'https://speed.cloudflare.com/__down?bytes=10485760');self.assertIn('--max-time',tor);self.assertNotIn('--location',tor)
  self.assertEqual(tor[tor.index('--proxy')+1],'socks5h://localhost'+m.SOCKS)
  self.assertEqual(tor[tor.index('--noproxy')+1],'')
  self.assertEqual(direct[direct.index('--proxy')+1],'')
 def test_unknown_route_rejected(self):
  with self.assertRaises(KeyError):m.command('unknown')
 def test_fast_discovery_and_provider_validation(self):
  for url,valid in [('https://test.oca.nflxvideo.net/speedtest?x=1',True),('https://speed.cloudflare.com/test',False),('http://test.nflxvideo.net/test',False)]:
   process=MagicMock();process.returncode=0;process.poll.return_value=0
   process.communicate.return_value=(json.dumps({'targets':[{'url':url}]}).encode(),b'')
   with patch.object(m.subprocess,'Popen',return_value=process) as popen:
    if valid:self.assertEqual(m.fast_target(threading.Event(),{}),url)
    else:
     with self.assertRaises(RuntimeError):m.fast_target(threading.Event(),{})
    args=popen.call_args.args[0]
    self.assertIn('api.fast.com',args[-1]);self.assertEqual(args[args.index('--proxy')+1],'')
    self.assertIn('--max-filesize',args);self.assertNotIn('--location',args)
 def test_cancel_during_discovery_skips_download(self):
  cancelled=threading.Event()
  def discover(*_):cancelled.set();return None
  with patch.object(m,'fast_target',side_effect=discover),patch.object(m.subprocess,'Popen') as popen:
   self.assertEqual(m.measure('direct',lambda _:None,cancelled)['status'],'cancelled');popen.assert_not_called()
 def test_fast_failure_never_uses_another_provider(self):
  with patch.object(m,'fast_target',side_effect=RuntimeError('Fast.com unavailable')),patch.object(m.subprocess,'Popen') as popen:
   self.assertEqual(m.measure('direct',lambda _:None,threading.Event())['status'],'failed');popen.assert_not_called()
 def test_measurement_and_failures(self):
  meta=dict(http_code=200,size_download=m.SIZE,time_starttransfer=2,time_total=4,content_type='application/octet-stream')
  result=m.result(0,meta,m.SIZE)
  self.assertEqual(result['ttfb'],2000);self.assertAlmostEqual(result['mbps'],m.SIZE*4/1e6)
  for code in (28,22,7):self.assertNotIn('mbps',m.result(code,meta,100))
  self.assertEqual(m.result(28,meta,100)['status'],'timeout')
  self.assertNotIn('mbps',m.result(0,meta,100))
  self.assertNotIn('mbps',m.result(0,dict(meta,content_type='text/html'),m.SIZE))
 def test_stream_and_cancel(self):
  payload="import sys,json;sys.stdout.buffer.write(b'12345678');sys.stdout.flush();sys.stderr.write(json.dumps(dict(http_code=200,size_download=8,time_starttransfer=1,time_total=2)))"
  with patch.object(m,'SIZE',8),patch.object(m,'command',return_value=[sys.executable,'-c',payload]):
   self.assertEqual(m.measure('tor',lambda _:None,threading.Event())['status'],'complete')
  cancelled=threading.Event();cancelled.set()
  with patch.object(m,'command',return_value=[sys.executable,'-c','import time;time.sleep(20)']):
   start=time.monotonic();self.assertEqual(m.measure('tor',lambda _:None,cancelled)['status'],'cancelled')
   self.assertLess(time.monotonic()-start,2)
 def test_sequence_and_cancel_prevents_second_route(self):
  with tempfile.TemporaryDirectory() as d,patch.dict(os.environ,{'XDG_RUNTIME_DIR':d}),patch.object(m,'ready'):
   seen=[];states=[];cancel=threading.Event()
   def measure(route,*_):seen.append(route);return dict(status='complete')
   with patch.object(m,'measure',side_effect=measure):m.run(lambda x:states.append(dict(x)),cancel)
   self.assertEqual(seen,['direct','tor']);self.assertFalse(states[-1]['running'])
   seen.clear()
   def cancelled(route,*_):seen.append(route);cancel.set();return dict(status='cancelled')
   with patch.object(m,'measure',side_effect=cancelled):m.run(lambda _:None,cancel)
   self.assertEqual(seen,['direct'])
 def test_missing_socks_never_falls_back(self):
  with patch.object(m,'SOCKS','/tmp/tor-speed-test-socket-does-not-exist'),patch.dict(os.environ,{'HTTPS_PROXY':'http://127.0.0.1:1','NO_PROXY':'*'}):
   value=m.measure('tor',lambda _:None,threading.Event())
   self.assertEqual(value['status'],'failed');self.assertEqual(value['bytes'],0)
 def test_lock_prevents_overlap(self):
  with tempfile.TemporaryDirectory() as d,patch.dict(os.environ,{'XDG_RUNTIME_DIR':d}),patch.object(m,'ready'):
   directory=Path(d)/'tor-speed-compare';directory.mkdir()
   with (directory/'lock').open('a') as lock:
    m.fcntl.flock(lock,m.fcntl.LOCK_EX)
    with patch.object(m,'measure') as measure:
     states=[];m.run(states.append,threading.Event());measure.assert_not_called()
     self.assertIn('already running',states[-1]['error'])
 def test_offline_no_transfer(self):
  with tempfile.TemporaryDirectory() as d,patch.dict(os.environ,{'XDG_RUNTIME_DIR':d}),patch.object(m,'ready',side_effect=OSError()),patch.object(m,'measure') as measure:
   states=[];m.run(states.append,threading.Event());measure.assert_not_called();self.assertIn('error',states[-1])
 def test_bootstrapped_tor_without_verified_circuit_never_transfers(self):
  backend=MagicMock();backend.host_network.return_value=True
  backend.Controller.return_value.__enter__.return_value.command.return_value='PROGRESS=100'
  controller=MagicMock();controller.wait_ready.side_effect=RuntimeError('Wait for a verified Tor circuit, then retry.')
  with tempfile.TemporaryDirectory() as d,patch.dict(os.environ,{'XDG_RUNTIME_DIR':d}),patch.dict(sys.modules,backend=backend,exit_controller=controller),patch.object(m,'measure') as measure:
   states=[];m.run(states.append,threading.Event());measure.assert_not_called()
   controller.wait_ready.assert_called_once()
   self.assertIn('verified Tor circuit',states[-1]['error']);self.assertFalse(states[-1]['running'])
if __name__=='__main__':unittest.main()
