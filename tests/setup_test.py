import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import subprocess
import io
import os

ROOT=Path(__file__).resolve().parents[1]
def load(name,path):
    spec=importlib.util.spec_from_file_location(name,ROOT/path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
browser=load('browser_install','install/browser_install.py')
installer=load('installer','system/install.py')

class SetupTest(unittest.TestCase):
    def test_root_installer_reports_missing_packages_without_installing(self):
        from types import SimpleNamespace
        with patch.object(installer.os,'geteuid',return_value=0),patch.object(installer.os,'umask'),patch.dict(installer.os.environ,SUDO_UID='1000'),patch.object(installer.pwd,'getpwuid',return_value=SimpleNamespace(pw_dir='/home/test',pw_name='test',pw_gid=1000)),patch('builtins.open',unittest.mock.mock_open()),patch.object(installer.fcntl,'flock'),patch.object(installer.Path,'exists',return_value=False),patch.object(installer.subprocess,'run') as run:
            with self.assertRaisesRegex(SystemExit,'Missing runtime packages:.*omarchy pkg add'):
                installer.main()
            run.assert_not_called()

    def test_install_and_retry_with_private_terminal_umask(self):
        from types import SimpleNamespace
        with tempfile.TemporaryDirectory() as folder:
            base=Path(folder)
            def path(value):
                value=Path(value)
                return base/str(value).lstrip('/') if str(value).startswith(('/usr/', '/etc/', '/run/')) else value
            for name in ('gpg','curl','tor','ip','nft','foot','onionshare-cli'):
                target=path('/usr/bin/'+name);target.parent.mkdir(parents=True,exist_ok=True);target.touch()
            target=path('/usr/share/iso-codes/json/iso_3166-1.json')
            target.parent.mkdir(parents=True);target.touch()
            path('/etc/systemd/system').mkdir(parents=True)
            import builtins
            real_open=builtins.open
            def open_file(name,*args,**kwargs):
                if str(name)=='/run/omarchy-tor-install.lock': name=base/'install.lock'
                return real_open(name,*args,**kwargs)
            original=os.umask(0o077)
            try:
                with patch.object(installer,'Path',side_effect=path),patch.object(installer.os,'geteuid',return_value=0),patch.object(installer.os,'chown'),patch.dict(installer.os.environ,{'SUDO_UID':'1000','PKEXEC_UID':'1000'}),patch.object(installer.pwd,'getpwuid',return_value=SimpleNamespace(pw_dir='/home/test',pw_name='test',pw_gid=1000)),patch('builtins.open',side_effect=open_file),patch.object(installer.fcntl,'flock'),patch.object(installer,'pause_supervisor',return_value=False),patch.object(installer.subprocess,'run'),patch.object(Path,'is_symlink',return_value=False):
                    # Only the ownership check is synthetic; writes and modes are real.
                    original_stat=Path.stat
                    def stat(p,*args,**kwargs):
                        result=original_stat(p,*args,**kwargs)
                        if p==path('/usr/local/lib/omarchy-tor'):
                            fields=list(result);fields[4]=0
                            return os.stat_result(fields)
                        return result
                    with patch.object(Path,'stat',stat):
                        for _ in range(2):
                            os.umask(0o077)
                            installer.main()
                            stamp=path('/usr/local/lib/omarchy-tor/version.json')
                            self.assertEqual(json.loads(stamp.read_text())['api'],3)
                            self.assertEqual(stamp.stat().st_mode & 0o777,0o644)
                            for directory in ('/usr/local/lib/omarchy-tor','/etc/omarchy-tor','/etc/omarchy-tor/users'):
                                self.assertEqual(path(directory).stat().st_mode & 0o777,0o755)
            finally:os.umask(original)
    def test_untrusted_download_locations_rejected(self):
        for url in ('http://dist.torproject.org/a','https://dist.torproject.org.evil/a','file:///etc/passwd'):
            with self.assertRaises(ValueError):browser.fetch(url,Path('/tmp/unused-browser-test'),100)

    def test_interrupted_download_resumes_exact_range(self):
        class Response(io.BytesIO):
            def __init__(self,data,status,headers):
                super().__init__(data);self.status=status;self.headers=headers;self.url='https://dist.torproject.org/test'
        replies=[Response(b'abc',200,{'Content-Length':'6','ETag':'"same"'}),Response(b'def',206,{'Content-Range':'bytes 3-5/6'})]
        with tempfile.TemporaryDirectory() as tmp,patch.object(browser,'urlopen',side_effect=replies) as fetch,patch.object(browser.time,'sleep'):
            target=Path(tmp)/'download';browser.fetch('https://dist.torproject.org/test',target,10)
            self.assertEqual(target.read_bytes(),b'abcdef')
            self.assertEqual(fetch.call_args_list[1].args[0].get_header('Range'),'bytes=3-')
            self.assertEqual(fetch.call_args_list[1].args[0].get_header('If-range'),'"same"')

    def test_signature_failure_preserves_existing_browser(self):
        with tempfile.TemporaryDirectory() as tmp:
            base=Path(tmp);existing=base/'tor-browser/Browser';existing.mkdir(parents=True);(existing/'firefox').write_text('original')
            def fetch(url,target,limit):
                target.write_text(json.dumps({'version':'test','binary':'https://dist.torproject.org/a','sig':'https://dist.torproject.org/a.asc'}) if target.name=='release.json' else 'untrusted')
            with patch.object(browser,'BASE',base),patch.object(browser,'fetch',fetch),patch.object(browser.subprocess,'run',side_effect=subprocess.CalledProcessError(1,'gpg')):
                with self.assertRaises(subprocess.CalledProcessError):browser.install()
            self.assertEqual((existing/'firefox').read_text(),'original')
            self.assertFalse((base/'tor-browser.previous').exists())

    def test_units_drop_privileges_and_bind_gateway(self):
        units=installer.unit_text(1000,1000,'/home/test')
        session=units['omarchy-tor-session-1000.service']
        self.assertIn('User=1000',session)
        self.assertIn('NetworkNamespacePath=/run/netns/omarchy-tor-1000',session)
        self.assertIn('BindsTo=omarchy-tor-native-1000.service',session)
        self.assertIn('NoNewPrivileges=yes',session)

    def test_boot_enables_only_idle_socket_not_tor(self):
        units=installer.unit_text(1000,1000,'/home/test')
        for name, text in units.items():
            if name.endswith('.service'):
                self.assertNotIn('[Install]',text)
                self.assertNotIn('WantedBy=',text)
        socket=units['omarchy-tor-session-1000.socket']
        self.assertNotIn('Requires=',socket)
        self.assertIn('WantedBy=sockets.target',socket)

if __name__=='__main__':unittest.main()

class ControllerUpgrade(unittest.TestCase):
    def test_upgrade_stops_only_supervisor_with_temporary_process_only_kill(self):
        with tempfile.TemporaryDirectory() as folder:
            base=Path(folder)
            (base/'proc').mkdir()
            calls=[]
            def path(value):
                if value=='/proc': return base/'proc'
                if value=='/run/systemd/system': return base/'units'
                raise AssertionError(value)
            def run(args, **kwargs):
                calls.append(args)
                if args[:2]==['systemctl','stop']:
                    self.assertEqual(args[2], 'omarchy-tor-session-1000.service')
                    self.assertIn('KillMode=process', next((base/'units').rglob('*.conf')).read_text())
                return subprocess.CompletedProcess(args,0)
            with patch.object(installer,'Path',side_effect=path), patch.object(installer.subprocess,'run',side_effect=run), patch.object(installer.subprocess,'check_output',return_value='123'):
                self.assertTrue(installer.pause_supervisor(1000))
            self.assertFalse(list((base/'units').rglob('*.conf')))
            self.assertFalse(any('omarchy-tor-native' in ' '.join(c) for c in calls))

    def test_idle_upgrade_does_not_activate_services(self):
        with patch.object(installer.subprocess,'run',return_value=subprocess.CompletedProcess([],3)) as run:
            self.assertFalse(installer.pause_supervisor(1000))
            self.assertEqual(run.call_count,1)
