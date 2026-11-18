import sys
from pathlib import Path
import unittest
from unittest.mock import patch,MagicMock
import tempfile
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'backend'))
import lifecycle

class LifecycleTests(unittest.TestCase):
 def test_start_is_explicit_broker_request(self):
  with patch.object(lifecycle.subprocess,'run') as run:
   result=lifecycle.start()
  self.assertEqual(run.call_args.args[0][-1],'start');self.assertTrue(result['running']);self.assertEqual(result['route'],[])
 def test_stop_tor_and_clear_state(self):
  context=MagicMock()
  context.__enter__.side_effect=[context,ConnectionRefusedError()]
  with tempfile.TemporaryDirectory() as folder,patch.object(lifecycle.backend,'RUNTIME',Path(folder)),patch.object(lifecycle.backend,'Controller',return_value=context),patch.object(lifecycle.backend,'prepare'),patch.object(lifecycle.backend,'gateway_generation',return_value='test-generation'),patch.object(lifecycle,'atomic') as store:
   result=lifecycle.stop()
  context.command.assert_called_once_with('SIGNAL HALT')
  self.assertFalse(result['running']);self.assertEqual(result['route'],[]);store.assert_called_once()
 def test_stop_tolerates_shutdown_disconnect_but_waits_for_closed_socket(self):
  for error in (ConnectionResetError(),BrokenPipeError(),RuntimeError('Tor control connection closed')):
   with self.subTest(error=type(error).__name__):
    context=MagicMock();context.__enter__.side_effect=[context,error,ConnectionRefusedError()]
    context.command.side_effect=error
    with tempfile.TemporaryDirectory() as folder,patch.object(lifecycle.backend,'RUNTIME',Path(folder)),patch.object(lifecycle.backend,'Controller',return_value=context),patch.object(lifecycle.backend,'prepare'),patch.object(lifecycle.backend,'gateway_generation',return_value='generation'),patch.object(lifecycle,'atomic') as store,patch.object(lifecycle.time,'sleep'):
     result=lifecycle.stop()
     self.assertEqual((Path(folder)/'stopped-generation').read_text(),'generation')
    self.assertFalse(result['running']);self.assertEqual(context.__enter__.call_count,3);store.assert_called_once()
 def test_repeated_resets_do_not_claim_stopped(self):
  context=MagicMock();context.__enter__.side_effect=ConnectionResetError()
  with tempfile.TemporaryDirectory() as folder,patch.object(lifecycle.backend,'RUNTIME',Path(folder)),patch.object(lifecycle.backend,'Controller',return_value=context),patch.object(lifecycle,'atomic') as store,patch.object(lifecycle.time,'sleep'):
   with self.assertRaisesRegex(RuntimeError,'did not stop'):lifecycle.stop()
  store.assert_not_called()
if __name__=='__main__':unittest.main()
