import array
import importlib.util
import json
import multiprocessing
import os
from pathlib import Path
import pty
import socket
import sys
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('session',ROOT/'system/session.py')
session=importlib.util.module_from_spec(spec);spec.loader.exec_module(session)

class SessionTests(unittest.TestCase):
    def test_session_unit_restricts_network_without_desktop_or_file_isolation(self):
        spec=importlib.util.spec_from_file_location('installer',ROOT/'system/install.py')
        installer=importlib.util.module_from_spec(spec);spec.loader.exec_module(installer)
        unit=installer.unit_text(1000,1000,'/home/example')['omarchy-tor-session-1000.service']
        self.assertIn('NetworkNamespacePath=/run/netns/omarchy-tor-1000',unit)
        self.assertIn('NoNewPrivileges=yes',unit)
        self.assertIn('TemporaryFileSystem=/run/systemd/resolve:ro',unit)
        for target in ('/etc/resolv.conf','/run/systemd/resolve/stub-resolv.conf','/run/systemd/resolve/resolv.conf'):
            self.assertIn('BindReadOnlyPaths=/etc/netns/omarchy-tor-1000/resolv.conf:'+target,unit)
        self.assertIn('CapabilityBoundingSet=\n',unit)
        for restriction in ('PrivateTmp=', 'PrivateIPC=', 'PrivatePIDs=', 'ProtectHome=',
                            'ProtectSystem=', 'SystemCallFilter=', 'RestrictNamespaces='):
            self.assertNotIn(restriction,unit)

    def test_network_socket_cannot_be_passed_as_terminal(self):
        left,right=socket.socketpair()
        try:
            with self.assertRaises(ValueError):
                session.validate({'action':'run'},[left.fileno()],os.getuid())
        finally: left.close();right.close()

    def test_unprivileged_broker_runs_child_on_pty(self):
        client,server=socket.socketpair(socket.AF_UNIX,socket.SOCK_SEQPACKET)
        try: server.getsockopt(socket.SOL_SOCKET,socket.SO_PEERCRED,12)
        except PermissionError:
            client.close();server.close();self.skipTest('Tool sandbox blocks peer-credential inspection; run host integration test')
        master,slave=pty.openpty()
        from contextlib import nullcontext
        with patch.object(session, 'controller_ready', return_value=True), patch.object(session, 'launch_policy', side_effect=nullcontext):
            process=multiprocessing.get_context('fork').Process(target=session.handle,args=(server,));process.start()
        server.close()
        desktop={'DISPLAY':':1','WAYLAND_DISPLAY':'wayland-test',
                 'XDG_RUNTIME_DIR':'/run/user/'+str(os.getuid()),
                 'DBUS_SESSION_BUS_ADDRESS':'unix:path=/test/bus',
                 'SSH_AUTH_SOCK':'/test/ssh-agent','PATH':'/usr/bin'}
        code='import os,socket,json; socket.socket(socket.AF_UNIX).close(); print(json.dumps({"uid":os.getuid(),"env":dict(os.environ)}),flush=True)'
        payload={'action':'run','argv':['/usr/bin/python3','-c',code],
                 'env':desktop,'cwd':'/tmp'}
        client.settimeout(5)
        client.sendmsg([json.dumps(payload).encode()],[(socket.SOL_SOCKET,socket.SCM_RIGHTS,array.array('i',[slave]))])
        os.close(slave)
        response=json.loads(client.recv(65536))
        output=os.read(master,4096).decode()
        process.join(5);client.close();os.close(master)
        self.assertEqual(response,{'ok':True,'exitCode':0})
        result=json.loads(output)
        self.assertEqual(result['uid'],os.getuid())
        for key,value in desktop.items():
            self.assertEqual(result['env'][key],value)

    def test_client_has_no_privilege_escalation_fallback(self):
        source=(ROOT/'system/client.py').read_text()
        self.assertNotIn('pkexec',source)
        self.assertNotIn('sudo',source)
        self.assertNotIn('systemd-run',source)

    def test_final_launch_check_rejects_policy_race_stale_state_and_old_gateway(self):
        import tempfile,time
        sys.path.insert(0,str(ROOT/'backend'))
        import backend
        with tempfile.TemporaryDirectory() as folder, patch.object(backend,'DATA',Path(folder)), patch.object(backend,'RUNTIME',Path(folder)), patch.object(backend,'gateway_generation',return_value='current'):
            Path(folder,'country-policy.json').write_text(json.dumps({'api':3,'country':'JP'}))
            state=dict(api=3,running=True,state='ready',exitCountry='JP',appliedCountry='JP',verifiedCountry='JP',policyReady=True,gatewayGeneration='current',heartbeat=time.time())
            for change in ({'exitCountry':'NL'},{'policyReady':False},{'heartbeat':0},{'gatewayGeneration':'old'}):
                Path(folder,'controller-state.json').write_text(json.dumps(dict(state,**change)))
                with self.assertRaisesRegex(RuntimeError,'policy is not ready'):
                    with session.launch_policy():self.fail('must not launch')
            Path(folder,'controller-state.json').write_text(json.dumps(state))
            with session.launch_policy():pass

    def test_policy_writer_cannot_change_policy_during_spawn(self):
        import tempfile,time,threading
        sys.path.insert(0,str(ROOT/'backend'))
        import backend
        with tempfile.TemporaryDirectory() as folder, patch.object(backend,'DATA',Path(folder)), patch.object(backend,'RUNTIME',Path(folder)), patch.object(backend,'gateway_generation',return_value='current'):
            Path(folder,'country-policy.json').write_text(json.dumps({'api':3,'country':'JP'}))
            Path(folder,'controller-state.json').write_text(json.dumps(dict(api=3,running=True,state='ready',exitCountry='JP',appliedCountry='JP',verifiedCountry='JP',policyReady=True,gatewayGeneration='current',heartbeat=time.time())))
            entered=threading.Event();changed=threading.Event()
            def writer():
                with Path(folder,'policy.lock').open('a') as lock:
                    entered.set();session.fcntl.flock(lock,session.fcntl.LOCK_EX);changed.set()
            with session.launch_policy():
                thread=threading.Thread(target=writer);thread.start()
                self.assertTrue(entered.wait(1));self.assertFalse(changed.wait(.1))
            thread.join(2);self.assertTrue(changed.is_set())

    def test_start_acknowledges_even_when_observer_is_unavailable(self):
        client,server=socket.socketpair(socket.AF_UNIX,socket.SOCK_SEQPACKET)
        client.settimeout(3)
        with patch.object(session, 'controller_ready', side_effect=AssertionError('Start must not wait for the observer')):
            process=multiprocessing.get_context('fork').Process(target=session.handle,args=(server,));process.start()
        server.close()
        try:
            client.send(b'{"action":"start"}')
            self.assertTrue(json.loads(client.recv(65536))['ok'])
        finally:
            client.close();process.join(3)
            if process.is_alive():process.terminate();process.join()

    def test_application_does_not_launch_without_observer(self):
        client,server=socket.socketpair(socket.AF_UNIX,socket.SOCK_SEQPACKET)
        master,slave=pty.openpty();client.settimeout(3)
        with patch.object(session, 'controller_ready', return_value=False),patch.object(session.subprocess,'Popen',side_effect=AssertionError('must not launch')):
            process=multiprocessing.get_context('fork').Process(target=session.handle,args=(server,));process.start()
        server.close()
        try:
            payload={'action':'run','argv':['/usr/bin/true'],'env':{},'cwd':'/tmp'}
            client.sendmsg([json.dumps(payload).encode()],[(socket.SOL_SOCKET,socket.SCM_RIGHTS,array.array('i',[slave]))])
            response=json.loads(client.recv(65536))
            self.assertFalse(response['ok']);self.assertIn('initializing',response['error'])
        finally:
            client.close();os.close(master);os.close(slave);process.join(3)
            if process.is_alive():process.terminate();process.join()

if __name__=='__main__': unittest.main()
