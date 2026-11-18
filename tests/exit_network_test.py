import sys
from pathlib import Path
import unittest
sys.path.insert(0, str(Path(__file__).parents[1]/'tools'))
import exit_network as network

class PlacementTest(unittest.TestCase):
    def test_sample_identity_count_and_country_containment(self):
        rows=[{'id':f'{code}-{i}','country':code} for code in ['US','DE','NL','FJ','NZ','FR'] for i in range(40)]
        rows.append({'id':'unknown','country':'??'})
        result=network.sample_network(rows,120)
        self.assertEqual(result['count'],120)
        self.assertEqual(result['countries'],6)
        self.assertEqual(result['unplaced'],1)
        self.assertEqual(len(set(p['id'] for p in result['points'])),120)
        geometry=network.geometry_index()
        original={r['id']:r['country'] for r in rows}
        for point in result['points']:
            self.assertEqual(original[point['id']],point['country'])
            self.assertTrue(any(network.in_polygon(point['longitude'],point['latitude'],p) for p in geometry[point['country']]))
        again=network.sample_network(rows,120)
        self.assertEqual(result['points'],again['points'])
    def test_holes_are_not_land(self):
        polygon=[[[0,0],[10,0],[10,10],[0,10],[0,0]],[[3,3],[7,3],[7,7],[3,7],[3,3]]]
        self.assertTrue(network.in_polygon(1,1,polygon))
        self.assertFalse(network.in_polygon(5,5,polygon))
        self.assertFalse(network.in_polygon(-1,1,polygon))
    def test_no_fabricated_sample_on_empty_directory(self):
        with self.assertRaises(ValueError):network.sample_network([])

if __name__=='__main__':unittest.main()
