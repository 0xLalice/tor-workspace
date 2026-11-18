"""Resume only opted-in shares, after verified readiness, never after Stop."""
from pathlib import Path
import sys
import tempfile
import threading
import unittest
from unittest.mock import patch,Mock
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'backend'))
import share

class ResumeTests(unittest.TestCase):
 def setUp(self):
  tmp=tempfile.TemporaryDirectory();self.addCleanup(tmp.cleanup);self.root=Path(tmp.name)
  for obj,key,value in [(share,'ROOT',self.root/'shares'),(share.backend,'DATA',self.root/'state'),(share.backend,'RUNTIME',self.root/'runtime')]:
   p=patch.object(obj,key,value);p.start();self.addCleanup(p.stop)
  self.identity='a'*32;self.file=self.root/'file.txt';self.file.write_text('original')
  self.folder=share.directory(self.identity)
  share.write(self.folder/'request.json',dict(file=str(self.file),generation='old',colors={}))
  share.save(self.identity,dict(state='ready',url='old-link',name='file.txt'))
 def test_preference_default_and_persistence(self):
  self.assertFalse(share.resume_enabled());share.set_resume(True);self.assertTrue(share.status()['autoResume'])
  self.assertEqual((share.backend.DATA/'sharing.json').stat().st_mode&0o777,0o600)
  self.assertTrue(share.status()['resumeNeedsRestart'])
  share.save(self.identity,dict(state='ready',url='old-link',resumeCapable=True));self.assertFalse(share.status()['resumeNeedsRestart'])
  share.set_resume(False);self.assertFalse(share.resume_enabled())
  with self.assertRaises(ValueError):share.set_resume('yes')
 def exercise(self,opt_in=True,cancel=False,disable=False,missing=False):
  ending=threading.Event();calls=[];states=[]
  def run(folder,publish,ending):
   calls.append(share.read(folder/'request.json')['generation'])
   publish(dict(state='stopped',url='',reason='tor-stopped'))
   if cancel or len(calls)==2:ending.set()
  original_save=share.save
  def save(identity,value):states.append(value.copy());return original_save(identity,value)
  if missing:self.file.unlink()
  preference=Mock(return_value=opt_in)
  if disable:preference.side_effect=[True,True,False]
  with patch.object(share,'run_worker',side_effect=run),patch.object(share.threading,'Event',return_value=ending),patch.object(ending,'wait',return_value=False),patch.object(share.signal,'signal'),patch.object(share,'resume_enabled',preference),patch.object(share,'available_generation',side_effect=['','old','new']) as ready,patch.object(share,'save',side_effect=save):
   share.worker(self.identity)
  return calls,states,ready
 def test_default_does_not_restart(self):
  calls,states,ready=self.exercise(False);self.assertEqual(calls,['old']);ready.assert_not_called()
 def test_wait_then_resume_with_new_generation_and_no_old_url(self):
  calls,states,ready=self.exercise();self.assertEqual(calls,['old','new'])
  paused=[s for s in states if s['state']=='paused'];self.assertTrue(paused)
  self.assertTrue(all(s['url']=='' for s in paused));self.assertEqual(self.file.read_text(),'original')
 def test_explicit_stop_never_resumes(self):
  calls,states,ready=self.exercise(cancel=True);self.assertEqual(calls,['old']);ready.assert_not_called()
 def test_disabling_while_paused_cancels(self):
  calls,states,ready=self.exercise(disable=True);self.assertEqual(calls,['old']);self.assertEqual(states[-1]['state'],'stopped')
 def test_missing_file_reports_failure(self):
  calls,states,ready=self.exercise(missing=True);self.assertEqual(calls,['old']);self.assertEqual(states[-1]['state'],'error')
 def test_availability_is_passive_and_accepts_idle_but_rejects_stale_service(self):
  import exit_controller,time
  state=dict(api=3,running=True,state='ready',serviceReady=True,policyReady=True,exitCountry='',appliedCountry='',heartbeat=time.time(),gatewayGeneration='new')
  with patch.object(exit_controller,'client',return_value=state) as client,patch.object(share.backend,'gateway_generation',return_value='new') as generation:
   self.assertEqual(share.available_generation(),'new');client.assert_called_with('cached')
   state.update(state='starting',policyReady=False,route=[],circuitId='');self.assertEqual(share.available_generation(),'new')
   state.update(state='ready',heartbeat=0);self.assertEqual(share.available_generation(),'')
   self.assertEqual(generation.call_count,2)

 def test_old_generation_or_explicit_stop_cannot_resume(self):
  import exit_controller,time
  state=dict(api=3,running=True,state='ready',serviceReady=True,policyReady=True,exitCountry='',appliedCountry='',heartbeat=time.time(),gatewayGeneration='old')
  with patch.object(exit_controller,'client',return_value=state),patch.object(share.backend,'gateway_generation',return_value='new'):
   self.assertEqual(share.available_generation(),'')
   state['gatewayGeneration']='new'
   share.backend.RUNTIME.mkdir(parents=True)
   (share.backend.RUNTIME/'stopped-generation').write_text('new')
   self.assertEqual(share.available_generation(),'')

if __name__=='__main__':unittest.main()
