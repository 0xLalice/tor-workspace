from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch, Mock
from concurrent.futures import ThreadPoolExecutor
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'backend'))
import share

class ShareListTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.root=Path(self.tmp.name)
        self.files=[]
        for name in ('hello ü.txt','second.txt','third.txt'):
            path=self.root/name;path.write_text(name);self.files.append(str(path))
        for target,value in [('ROOT',self.root/'runtime')]:
            p=patch.object(share,target,value);p.start();self.addCleanup(p.stop)
        p=patch.object(share.backend,'DATA',self.root/'state');p.start();self.addCleanup(p.stop)
        p=patch.object(share,'ensure_tor',return_value='generation');self.tor=p.start();self.addCleanup(p.stop)
        p=patch.object(share.subprocess,'run',return_value=Mock(returncode=0));self.run=p.start();self.addCleanup(p.stop)

    def test_multiple_links_and_independent_stop(self):
        result=share.start(self.files);self.assertEqual(len(result['shares']),3)
        ids=result['selectedIds'];self.assertEqual(len(set(ids)),3)
        for i,s in enumerate(result['shares']):share.save(s['id'],dict(s,state='ready',url='http://'+str(i)+'.onion'))
        self.assertEqual(share.status()['readyCount'],3)
        result=share.stop(ids[1]);self.assertEqual(result['readyCount'],2)
        self.assertEqual({s['id'] for s in result['shares']},{ids[0],ids[2]})
        self.assertTrue(all(Path(f).is_file() for f in self.files))

    def test_duplicates_and_concurrent_adds(self):
        with ThreadPoolExecutor(max_workers=3) as pool:
            results=list(pool.map(lambda _:share.start([self.files[0]]),range(3)))
        self.assertEqual(len(share.status()['shares']),1)
        self.assertEqual(len({r['selectedIds'][0] for r in results}),1)
        self.assertEqual(self.run.call_count,1)

    def test_failed_launch_retry_and_dismiss(self):
        self.run.return_value=Mock(returncode=1)
        result=share.start([self.files[0]]);identity=result['selectedIds'][0]
        self.assertEqual(result['shares'][0]['state'],'error')
        self.run.return_value=Mock(returncode=0)
        result=share.retry(identity);self.assertEqual(result['shares'][0]['state'],'starting')
        with self.assertRaises(ValueError):share.dismiss(identity)
        item=result['shares'][0];share.save(identity,dict(item,state='error'))
        self.assertEqual(share.dismiss(identity)['shares'],[])

    def test_off_does_not_start_worker(self):
        self.tor.side_effect=RuntimeError('Start Tor before sharing.')
        with self.assertRaises(RuntimeError):share.start(self.files)
        self.run.assert_not_called()

    def test_failed_stop_remains_retryable_and_preserves_request(self):
        item=share.start([self.files[0]])['shares'][0]
        with patch.object(share,'stop_unit',side_effect=RuntimeError('Stop failed')):
            result=share.stop(item['id'])
        self.assertTrue(result['shares'][0]['stopFailed'])
        self.assertEqual(result['shares'][0]['state'],'stopping')
        self.assertTrue((share.directory(item['id'])/'request.json').exists())
        self.assertEqual(share.stop(item['id'])['shares'],[])
        self.assertTrue(Path(self.files[0]).exists())

    def test_invalid_ids_never_reach_systemctl(self):
        for value in ('../work','',None,'legacy.service'):
            with self.assertRaises(ValueError):share.stop(value)
        self.run.assert_not_called()

    def test_stale_worker_count_and_private_state(self):
        item=share.start([self.files[0]])['shares'][0]
        share.save(item['id'],dict(item,state='ready',url='http://a.onion'))
        path=share.directory(item['id'])/'state.json'
        self.assertEqual(path.stat().st_mode&0o777,0o600)
        with patch.object(share.time,'time',return_value=9999999999):
            result=share.status();self.assertEqual(result['readyCount'],0);self.assertEqual(result['shares'][0]['url'],'')
        share.cleanup(item['id']);self.assertTrue((share.directory(item['id'])/'request.json').exists())

    def test_gateway_stop_clears_worker_and_preserves_original(self):
        from io import StringIO
        item=share.start([self.files[0]])['shares'][0]
        child=Mock(pid=12345,stdout=StringIO(''),poll=Mock(return_value=None))
        ending=Mock();ending.wait.return_value=False;ending.is_set.return_value=False
        with patch.object(share.subprocess,'Popen',return_value=child), patch.object(share.threading,'Event',return_value=ending), patch.object(share.threading,'Thread'), patch.object(share.signal,'signal'), patch.object(share.backend,'gateway_generation',return_value='different'), patch.object(share.os,'killpg'):
            share.worker(item['id'])
        self.assertEqual(share.status()['readyCount'],0)
        self.assertEqual(share.status()['shares'],[])
        self.assertTrue(Path(self.files[0]).exists())
        share.cleanup(item['id']);self.assertFalse(share.directory(item['id']).exists())
        # A new gateway generation alone must not recreate the worker or link.
        self.run.reset_mock();self.tor.return_value='restarted-generation'
        self.assertEqual(share.status()['shares'],[]);self.run.assert_not_called()
        restarted=share.start([self.files[0]])['shares'][0]
        self.assertNotEqual(restarted['id'],item['id'])
        self.assertEqual(restarted['url'],'')
        self.assertEqual(restarted['state'],'starting')

    def test_worker_startup_timeout(self):
        from io import StringIO
        item=share.start([self.files[0]])['shares'][0]
        child=Mock(pid=12345,stdout=StringIO(''),poll=Mock(return_value=None))
        ending=Mock();ending.wait.return_value=False;ending.is_set.return_value=False
        with patch.object(share.subprocess,'Popen',return_value=child), patch.object(share.threading,'Event',return_value=ending), patch.object(share.threading,'Thread'), patch.object(share.signal,'signal'), patch.object(share.backend,'gateway_generation',return_value='generation'), patch.object(share.os,'killpg'), patch.object(share.time,'monotonic',side_effect=[0,121]):
            share.worker(item['id'])
        result=share.status();self.assertEqual(result['shares'][0]['state'],'error')
        self.assertIn('120 seconds',result['shares'][0]['message'])
        self.assertFalse((share.directory(item['id'])/'work').exists())

    def test_publication_gets_its_own_deadline_and_reports_the_stage(self):
        from io import StringIO
        item=share.start([self.files[0]])['shares'][0]
        child=Mock(pid=12345,stdout=StringIO('WORKSPACE_PUBLISHING\n'),poll=Mock(return_value=None))
        ending=Mock();ending.wait.return_value=False;ending.is_set.return_value=False
        # Read the actual child output synchronously so the clock is deterministic.
        thread=Mock(side_effect=lambda target,**kwargs:Mock(start=target))
        with patch.object(share.subprocess,'Popen',return_value=child),patch.object(share.threading,'Event',return_value=ending),patch.object(share.threading,'Thread',thread),patch.object(share.signal,'signal'),patch.object(share.backend,'gateway_generation',return_value='generation'),patch.object(share.os,'killpg'),patch.object(share.time,'monotonic',side_effect=[0,10,121,309,311]):
            share.worker(item['id'])
        result=share.status()['shares'][0]
        self.assertEqual(ending.wait.call_count,3)
        self.assertEqual(result['state'],'error')
        self.assertIn('Tor could not publish',result['message'])
        self.assertIn('5 minutes',result['message'])
        self.assertEqual(result['url'],'')
        self.assertFalse((share.directory(item['id'])/'work').exists())

if __name__=='__main__':unittest.main()
