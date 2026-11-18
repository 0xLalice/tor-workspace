import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'backend'))
import antipode


def feature(code, point):
    return {'properties': {'code': code, 'label_point': point}}


def fixture():
    return antipode.country_snapshot([{'id':'a','country':'CL'}], [feature('CL',[-71,-35])], {'CL':'Chile'}, 100)


class AntipodeData(unittest.TestCase):
    def test_country_grouping_full_inventory_and_unknowns(self):
        rows=[dict(id=str(i),country='CL') for i in range(8000)]
        rows += [dict(id='0',country='CL'),dict(id='unknown',country=''),dict(id='german',country='DE')]
        data=antipode.country_snapshot(rows,[feature('CL',[-71,-35]),feature('DE',[10,51])],{'CL':'Chile','DE':'Germany'},100)
        self.assertEqual(data['totalExits'],8002)
        self.assertEqual(data['mappedExits'],8001)
        self.assertEqual(data['countries'][0]['exitCount'],8000)
        self.assertEqual(data['countries'][0]['longitude'],-71)
        self.assertNotIn('relays',data)

    def test_missing_and_invalid_country_points(self):
        for point in (None,[0],[0,91],[float('nan'),0],[True,0]):
            with self.assertRaises(ValueError):
                antipode.country_snapshot([{'id':'a','country':'CL'}],[feature('CL',point)],{},100)
        with self.assertRaises(ValueError):antipode.country_snapshot([],[],{},100)

    def test_reuses_illuminate_inventory_without_http_or_random_placement(self):
        with patch.object(antipode.exit_network,'inventory',return_value=[{'id':'a','country':'CL'}]) as inventory, patch.object(antipode.exit_network,'placement',side_effect=AssertionError('Illustrative placement used')), patch('subprocess.run',side_effect=AssertionError('External fetch attempted')):
            data=antipode.fetch()
            inventory.assert_called_once_with()
            self.assertEqual(data['countries'][0]['country'],'CL')
            self.assertEqual(data['countries'][0]['exitCount'],1)

    def test_each_search_reads_current_inventory_and_failure_retains_cache(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(antipode,'CACHE',Path(directory)/'private'), patch.object(antipode,'fetch',return_value=fixture()) as fetch:
            self.assertFalse(antipode.snapshot()['cached'])
            self.assertFalse(antipode.snapshot()['cached'])
            self.assertFalse(antipode.snapshot(True)['cached'])
            self.assertEqual(fetch.call_count,3)
            self.assertEqual(antipode.CACHE.stat().st_mode&0o777,0o700)
            path=antipode.CACHE/'country-snapshot.json'
            self.assertEqual(path.stat().st_mode&0o777,0o600)
            fetch.side_effect=OSError('offline')
            failed=antipode.snapshot(True)
            self.assertTrue(failed['stale']);self.assertEqual(failed['publishedAt'],fixture()['publishedAt'])
            path.unlink();self.assertIn('local Tor exit directory',antipode.snapshot()['error'])

    def test_legacy_relay_cache_is_not_reused(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(antipode,'CACHE',Path(directory)), patch.object(antipode,'fetch',side_effect=OSError('offline')):
            (Path(directory)/'snapshot.json').write_text(json.dumps({'relays':[{'latitude':0,'longitude':0}]}))
            self.assertNotIn('countries',antipode.snapshot())
