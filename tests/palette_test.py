import importlib.util
from pathlib import Path
import unittest
import tomllib

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('palette', ROOT/'backend/palette.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class PaletteTest(unittest.TestCase):
    def test_exact_jade(self):
        data=(ROOT/'tests/fixtures/reference/colors.toml').read_text()
        parsed=module.palette(data)
        for key,value in tomllib.loads(data).items(): self.assertEqual(parsed[key],value)

    def test_shipped_themes(self):
        paths=list(Path('/usr/share/omarchy/themes').glob('*/colors.toml'))
        if not paths:self.skipTest("Omarchy themes are not installed")
        modes=set()
        for path in paths:
            with self.subTest(theme=path.parent.name):
                value=module.palette(path.read_text());modes.add(value['mode'])
                for role in ('accent','bright_yellow','bright_foreground','dark_background'):
                    self.assertRegex(value[role],r'^#[0-9a-fA-F]{6}$')
        self.assertEqual(modes,{'dark','light'})

    def test_legacy_light(self):
        value=module.palette('background="#ffffff"\nforeground="#111111"\ncolor4="#123456"\ncolor11="#abcdef"')
        self.assertEqual(value['accent'],'#123456')
        self.assertEqual(value['bright_yellow'],'#abcdef')
        self.assertEqual(value['mode'],'light')

    def test_partial_palette_rejected(self):
        with self.assertRaises(ValueError): module.palette('accent="#123456"')


if __name__=='__main__':unittest.main()
