#!/usr/bin/env python3
"""Check resolved QML design colors against every installed Omarchy palette."""
import json,os,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'backend'))
from palette import palette
def write_fixtures():
    entries=[]
    for folder in (Path('/usr/share/omarchy/themes'),Path.home()/'.config/omarchy/themes'):
     for path in sorted(folder.glob('*/colors.toml')):
      value=palette(path.read_text());value.update(themeId=path.parent.name,themeName=path.parent.name)
      entries.append(value)
    if not entries:return []
    (ROOT/'build').mkdir(exist_ok=True)
    (ROOT/'build/palette-fixtures.json').write_text(json.dumps(entries))
    
    return entries


if __name__ == "__main__":
    entries=write_fixtures()
    if not entries:raise SystemExit("No installed palettes found")
    env=dict(os.environ,QML_XHR_ALLOW_FILE_READ='1',QT_QPA_PLATFORM='offscreen',QT_QPA_PLATFORMTHEME='',QT_QUICK_CONTROLS_STYLE='Basic',QSG_RHI_BACKEND='opengl')
    subprocess.run(['/usr/lib/qt6/bin/qmltestrunner','-input',str(ROOT/'tests/qml/tst_design_palettes.qml')],check=True,env=env)
    print(f'Checked {len(entries)} installed palettes: design-dependent tray lighting, Classic encryption contrast/dimmer opacity, Orbit and legacy roles; exact Classic Osaka mappings checked separately')
