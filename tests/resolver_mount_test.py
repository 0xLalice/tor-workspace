"""Exercise the actual session DNS mount directives without root or live DNS."""
import importlib.util,os,subprocess,tempfile,time,unittest,shutil
from pathlib import Path
spec=importlib.util.spec_from_file_location('installer',Path(__file__).resolve().parents[1]/'system/install.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class ResolverMountTests(unittest.TestCase):
 @unittest.skipUnless(os.environ.get('DBUS_SESSION_BUS_ADDRESS') and shutil.which('systemd-run') and shutil.which('unshare'), 'Requires a user systemd manager')
 def test_host_resolver_replacement_cannot_remove_namespace_override(self):
  if subprocess.run(['unshare','--user','--map-root-user','--mount','true'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL).returncode:
   self.skipTest('Unprivileged mount namespaces unavailable')
  self.exercise_mounts()

 def exercise_mounts(self):
  with tempfile.TemporaryDirectory(prefix='tor-dns-regression-') as tmp:
   root=Path(tmp);uid=os.getuid();config=root/f'etc/netns/omarchy-tor-{uid}';config.mkdir(parents=True)
   config.joinpath('resolv.conf').write_text('nameserver 10.77.0.1\n');config.joinpath('nsswitch.conf').write_text('hosts: files dns\n')
   host=root/'run/systemd/resolve';host.mkdir(parents=True)
   for name in ['stub-resolv.conf','resolv.conf']:host.joinpath(name).write_text('nameserver 127.0.0.53\n')
   root.joinpath('etc/resolv.conf').symlink_to('../run/systemd/resolve/stub-resolv.conf');root.joinpath('etc/nsswitch.conf').write_text('hosts: resolve\n')
   properties=[]
   for line in m.unit_text(uid,os.getgid(),str(Path.home()))[f'omarchy-tor-session-{uid}.service'].splitlines():
    if line.startswith(('TemporaryFileSystem=','BindReadOnlyPaths=')):
     properties+=['-p',line.replace('/etc/',tmp+'/etc/').replace('/run/',tmp+'/run/')]
   code='''from pathlib import Path
import sys,time
p=Path(sys.argv[1]);(p/'ready').touch()
end=time.monotonic()+8
while not (p/'go').exists():
 if time.monotonic()>end:raise RuntimeError('parent timed out')
 time.sleep(.02)
assert (p/'etc/resolv.conf').read_text()=='nameserver 10.77.0.1\\n'
print('PASS: host resolver file replacement does not change terminal DNS')
'''
   p=subprocess.Popen(['systemd-run','--user','--wait','--pipe','--collect','--quiet','-p','PrivateUsers=yes',*properties,'/usr/bin/python3','-c',code,tmp],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
   end=time.monotonic()+8
   while not root.joinpath('ready').exists() and p.poll() is None and time.monotonic()<end:time.sleep(.02)
   for name in ['stub-resolv.conf','resolv.conf']:
    fresh=host/(name+'.new');fresh.write_text('nameserver 192.0.2.53\n');fresh.replace(host/name)
   root.joinpath('go').touch();out,_=p.communicate(timeout=10);self.assertEqual(p.returncode,0,out);self.assertIn('PASS:',out)
