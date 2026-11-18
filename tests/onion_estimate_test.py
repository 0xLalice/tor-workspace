import concurrent.futures
import importlib.util
from pathlib import Path
import tempfile
import threading
import unittest

spec=importlib.util.spec_from_file_location('onion_estimate',Path(__file__).resolve().parents[1]/'backend/onion_estimate.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
CSV='# Tor Metrics\nfrac,onions,date,extra\n1,657399,2026-09-22,x\n1,123,2026-09-20,x\n1,,2026-09-23,x\n1,NaN,2026-09-24,x\n1,0,2026-09-24,x\n1,5,2999-01-01,x\n'
class EstimateTest(unittest.TestCase):
 def test_latest_and_format(self):
  value=m.parse(CSV)
  self.assertEqual(value['date'],'2026-09-22')
  self.assertEqual(m.display(value)['text'],'Tor Metrics estimates 657,000 .onion addresses for 22 Sep 2026.')
  for n,expected in [('999999','1,000,000'),('12345','12,300'),('12','12')]:
   self.assertIn(' '+expected+' .onion',m.display(dict(value,onions=n))['text'])
  for text in ['date,users\n2026-09-22,1','date,onions\n2026-09-22,NaN','date,onions\ninvalid,100']:
   with self.assertRaises(ValueError):m.parse(text)
 def test_cache_attempts_failure_and_older(self):
  with tempfile.TemporaryDirectory() as d:
   path=Path(d)/'estimate.json';calls=[]
   def fetch():calls.append(1);return CSV
   self.assertIsNone(m.cached(path))
   first=m.refresh(path,fetch,now=100000)
   self.assertEqual(m.refresh(path,fetch,now=100001),first);self.assertEqual(len(calls),1)
   def failure():calls.append(1);raise OSError('offline')
   self.assertEqual(m.refresh(path,failure,now=200000),first)
   self.assertEqual(m.refresh(path,fetch,now=200001),first);self.assertEqual(len(calls),2)
   self.assertEqual(m.refresh(path,lambda:'date,onions\n2026-01-01,100',now=300000),first)
   path.write_text('broken');self.assertIsNone(m.cached(path))
   self.assertEqual(m.refresh(path,fetch,now=400000),first)
 def test_concurrent(self):
  with tempfile.TemporaryDirectory() as d:
   path=Path(d)/'estimate.json';started=threading.Event();release=threading.Event();calls=[]
   def fetch():calls.append(1);started.set();release.wait(5);return CSV
   with concurrent.futures.ThreadPoolExecutor() as pool:
    pending=pool.submit(m.refresh,path,fetch,100000)
    self.assertTrue(started.wait(3))
    self.assertIsNone(m.refresh(path,fetch,100000))
    release.set();self.assertIsNotNone(pending.result())
   self.assertEqual(len(calls),1)
if __name__=='__main__':unittest.main()
