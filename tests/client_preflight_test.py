import importlib.util
from pathlib import Path
import unittest
from unittest.mock import MagicMock, patch


def load(path):
    spec=importlib.util.spec_from_file_location('tor_client_preflight',path)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    return module


class ClientPreflight(unittest.TestCase):
    def test_off_never_contacts_activation_socket_or_allocates_terminal(self):
        client=load(Path(__file__).resolve().parents[1]/'system/client.py')
        for action in ('run','browser'):
            with self.subTest(action=action):
                probe=MagicMock()
                probe.__enter__.return_value=probe
                probe.connect.side_effect=ConnectionRefusedError('Tor stopped')
                with patch.object(client.socket,'socket',return_value=probe) as factory, patch.object(client.pty,'openpty') as pty:
                    with self.assertRaisesRegex(RuntimeError,'Tor is off'):
                        client.request(action,['/bin/true'])
                    self.assertEqual(factory.call_count,1)
                    self.assertTrue(probe.connect.call_args.args[0].endswith('/control'))
                    pty.assert_not_called()

    def test_explicit_start_still_uses_activation(self):
        client=load(Path(__file__).resolve().parents[1]/'system/client.py')
        connection=MagicMock();connection.recv.return_value=b'{"ok":true}'
        with patch.object(client.socket,'socket',return_value=connection):
            self.assertEqual(client.request('start'),0)
        self.assertTrue(connection.connect.call_args.args[0].endswith('/launch.sock'))

if __name__=='__main__':unittest.main()
