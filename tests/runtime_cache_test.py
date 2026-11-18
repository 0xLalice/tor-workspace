"""Runtime imports must not trigger the shell's recursive plugin watcher."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

PLUGIN = Path(__file__).resolve().parents[1] / 'backend'


class RuntimeCacheTests(unittest.TestCase):
    def test_sharing_entrypoints_leave_plugin_directory_unchanged(self):
        for entry in ('share.py', 'chat.py', 'terminal_info.py'):
            with self.subTest(entry=entry), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                plugin = root / 'backend'
                plugin.mkdir()
                for source in PLUGIN.glob('*.py'):
                    shutil.copy2(source, plugin / source.name)
                before = {p.relative_to(plugin): p.read_bytes() for p in plugin.rglob('*') if p.is_file()}
                env = dict(os.environ, XDG_RUNTIME_DIR=str(root / 'runtime'), XDG_STATE_HOME=str(root / 'state'))
                env.pop('PYTHONDONTWRITEBYTECODE', None)
                env.pop('PYTHONPYCACHEPREFIX', None)
                # Deliberately omit -B: direct invocations must be safe too.
                result = subprocess.run([sys.executable, str(plugin / entry), 'status'],
                                        env=env, capture_output=True, text=True, timeout=10)
                self.assertEqual(result.returncode, 0, result.stderr)
                after = {p.relative_to(plugin): p.read_bytes() for p in plugin.rglob('*') if p.is_file()}
                self.assertEqual(before, after)
                self.assertFalse(list(plugin.rglob('__pycache__')))


if __name__ == '__main__':
    unittest.main()
