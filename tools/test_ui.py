#!/usr/bin/env python3
"""Run UI suites in fresh Qt processes to isolate singletons, focus and rendering."""
import argparse
import os
from pathlib import Path
import subprocess
import sys

from check_palettes import write_fixtures

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--platform', default='offscreen', choices=('offscreen', 'xcb', 'wayland'),
                    help='Explicit test display; defaults to headless regardless of desktop environment')
args = parser.parse_args()
write_fixtures()
env = dict(os.environ, QT_QPA_PLATFORM=args.platform, QT_QPA_PLATFORMTHEME='',
           QT_QUICK_CONTROLS_STYLE='Basic')
for key,value in {'QML_XHR_ALLOW_FILE_READ':'1','QT_QUICK_BACKEND':'rhi','QSG_RHI_BACKEND':'opengl',
                  'QT_QUICK_CONTROLS_STYLE':'Basic'}.items():
    env.setdefault(key,value)
failed = []
for suite in sorted((ROOT/'tests/qml').glob('tst_*.qml')):
    result = subprocess.run(['/usr/lib/qt6/bin/qmltestrunner','-input',str(suite)],env=env)
    if result.returncode: failed.append(suite.name)
if failed:
    print('Failed suites: '+', '.join(failed),file=sys.stderr)
sys.exit(bool(failed))
