"""Real process cancellation must unwind the browser's unpublished staging area."""
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]


class BrowserCancellationTests(unittest.TestCase):
    def test_terminal_close_and_termination_preserve_bundle_and_remove_partial_download(self):
        script = '''
import sys, signal
from pathlib import Path
sys.path.insert(0, sys.argv[1])
import browser_install as browser
browser.BASE = Path(sys.argv[2])
def interrupted_download(url, target, limit):
    target.write_bytes(b'partial download')
    (browser.BASE/'downloading').touch()
    while True: signal.pause()
browser.fetch = interrupted_download
browser.main()
'''
        for number in (signal.SIGHUP, signal.SIGTERM, signal.SIGINT):
            with self.subTest(signal=number), tempfile.TemporaryDirectory() as folder:
                base = Path(folder)
                bundle = base/'tor-browser/Browser/firefox'
                bundle.parent.mkdir(parents=True); bundle.write_bytes(b'verified installed browser')
                process = subprocess.Popen([sys.executable, '-B', '-c', script, str(ROOT/'install'), folder],
                                           stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                try:
                    deadline = time.monotonic()+5
                    while not (base/'downloading').exists():
                        self.assertIsNone(process.poll(), 'Installer exited before cancellation')
                        self.assertLess(time.monotonic(), deadline)
                        time.sleep(.01)
                    process.send_signal(number)
                    process.communicate(timeout=5)
                    self.assertEqual(process.returncode, 128+number)
                    self.assertEqual(bundle.read_bytes(), b'verified installed browser')
                    self.assertFalse(list(base.glob('.browser-stage-*')))
                finally:
                    if process.poll() is None: process.kill()
                    process.communicate()
