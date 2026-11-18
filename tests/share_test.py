from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'backend'))
import share

class SharingTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory()
        self.root=Path(self.tmp.name)
        self.original=self.root/'hello ü.txt';self.original.write_text('hello')
        self.override=patch.object(share,'ROOT',self.root/'runtime');self.override.start()
    def tearDown(self):
        self.override.stop();self.tmp.cleanup()
    def test_files_and_urls(self):
        self.assertEqual(share.validate_files([self.original.as_uri(),str(self.original)]),[str(self.original)])
        for value in ([],[str(self.root)],['file://remote/test'],['/missing'],['relative'],[None]):
            with self.assertRaises((ValueError,OSError)):share.validate_files(value)
    def test_unreadable_file_rejected(self):
        self.original.chmod(0)
        try:
            with self.assertRaises(PermissionError):share.validate_files([str(self.original)])
        finally:self.original.chmod(0o600)
    def test_output_never_accepts_non_onion_urls(self):
        value={'state':'starting','url':''}
        for line in ['http://localhost:9999','https://example.org','http://short.onion']:
            self.assertEqual(share.output_state(line,value),value)
        ready=share.output_state('http://'+'a'*56+'.onion',value)
        self.assertEqual(ready['state'],'ready')
        self.assertEqual(share.output_state('Compressing files.',value)['state'],'preparing')

    def test_unavailable_tor_is_rejected(self):
        with patch.object(share.shutil,'which',return_value='/usr/bin/onionshare-cli'),patch.object(share.backend,'Controller'),patch.object(share,'available_generation',return_value=''):
            with self.assertRaisesRegex(RuntimeError,'Tor is not available'):
                share.ensure_tor()

    def test_idle_service_can_publish_without_requesting_an_exit(self):
        import exit_controller, time
        state = dict(api=3, running=True, serviceReady=True, state='starting',
                     exitCountry='DE', appliedCountry='DE', policyReady=False,
                     route=[], circuitId='', heartbeat=time.time(), gatewayGeneration='test')
        with patch.object(exit_controller, 'client', return_value=state), patch.object(share.backend, 'RUNTIME', self.root/'state'), patch.object(share.backend, 'gateway_generation', return_value='test'), patch.object(share.backend, 'Controller') as control, patch.object(share.shutil, 'which', return_value='/usr/bin/onionshare-cli'):
            self.assertEqual(share.ensure_tor(), 'test')
            commands = [c.args[0] for c in control.return_value.__enter__.return_value.command.call_args_list]
            self.assertEqual(commands, ['GETINFO status/bootstrap-phase', 'SIGNAL ACTIVE'])

if __name__=='__main__':unittest.main()
