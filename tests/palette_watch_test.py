"""Real filesystem notifications: truncated writes and atomic theme swaps."""
from pathlib import Path
import json
import os
import select
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
DATA='background="#111111"\nforeground="#eeeeee"\n'

class PaletteWatchTests(unittest.TestCase):
    def test_stabilization_replacement_and_symlink_rearming(self):
        with tempfile.TemporaryDirectory() as tmp:
            state=Path(tmp);current=state/'omarchy/current';current.mkdir(parents=True)
            first=state/'first';first.mkdir();(first/'colors.toml').write_text(DATA)
            (current/'theme').symlink_to(first);(current/'theme.name').write_text('first')
            proc=subprocess.Popen(['python3','-B',str(ROOT/'backend/palette.py'),'--watch'],env=dict(os.environ,XDG_STATE_HOME=tmp),stdout=subprocess.PIPE,stderr=subprocess.PIPE)
            def receive():
                self.assertTrue(select.select([proc.stdout],[],[],3)[0],'No palette notification')
                return json.loads(proc.stdout.readline())
            try:
                initial=receive();self.assertEqual(initial['themeId'],'first')
                (first/'colors.toml').write_text('background="')
                self.assertFalse(select.select([proc.stdout],[],[],.3)[0],'Partial palette was emitted')
                replacement=first/'next';replacement.write_text(DATA.replace('#111111','#222222'));replacement.replace(first/'colors.toml')
                self.assertEqual(receive()['background'],'#222222')
                second=state/'second';second.mkdir();(second/'colors.toml').write_text(DATA.replace('#111111','#333333'))
                link=current/'next';link.symlink_to(second);link.replace(current/'theme')
                (current/'theme.name').write_text('second')
                swapped=receive();self.assertEqual(swapped['background'],'#333333');self.assertEqual(swapped['themeId'],'second')
                (second/'colors.toml').write_text(DATA.replace('#111111','#444444'))
                self.assertEqual(receive()['background'],'#444444')
                self.assertFalse(select.select([proc.stdout],[],[],.3)[0],'Duplicate palette emission')
            finally:
                proc.terminate();proc.wait(timeout=3);proc.stdout.close();proc.stderr.close()
