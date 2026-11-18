"""Exercise the real popup against both strip-sized and full-screen bar hosts."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from package_test import ROOT

SHELL_ROOT = Path(os.environ.get("OMARCHY_TEST_SHELL_ROOT", "/usr/share/omarchy/shell"))


class PopupGeometryTests(unittest.TestCase):
    @unittest.skipUnless(os.environ.get('WAYLAND_DISPLAY') and shutil.which('quickshell')
                         and (SHELL_ROOT/'Ui').is_dir(),
                         'Requires Omarchy Wayland; uses a transparent, input-free background surface')
    def test_popup_uses_painted_strip_not_host_surface(self):
        with tempfile.TemporaryDirectory() as folder:
            harness = Path(folder)
            for name in ('Ui', 'Commons'):
                (harness/name).symlink_to(SHELL_ROOT/name)
            (harness/'shell.qml').write_text('''import QtQuick
import Quickshell
import Quickshell.Wayland
import %s as TorShell
import %s as Sizing
ShellRoot {
 id: root
 property int step: 0
 property bool failed: false
 property var cases: [
  {position:"top",full:true,modern:true},
  {position:"bottom",full:true,modern:true},
  {position:"left",full:true,modern:true},
  {position:"right",full:true,modern:true},
  {position:"top",full:false,modern:false},
  {position:"bottom",full:false,modern:false},
  {position:"left",full:false,modern:false},
  {position:"right",full:false,modern:false}
 ]
 readonly property var current: cases[Math.min(step,cases.length-1)]
 readonly property bool vertical: current.position==="left"||current.position==="right"
 QtObject {
  id: modernBar
  property string position: root.current.position
  property int barSize: 26
  function barSizeFor(name) {return 40}
 }
 QtObject {
  id: legacyBar
  property string position: root.current.position
  property int barSize: 26
 }
 PanelWindow {
  id: host
  visible: true
  color: "transparent"
  mask: Region {}
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Background
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  screen: Quickshell.screens[0]
  implicitWidth: root.current.full||!root.vertical ? screen.width : 26
  implicitHeight: root.current.full||root.vertical ? screen.height : 26
  Item {id: icon; x:300; y:300; width:26; height:26}
 }
 TorShell.TorPopup {
  id: popup
  anchorItem: icon
  bar: root.current.modern ? modernBar : legacyBar
  open: false
  gap: 12
  margin: 10
  readonly property var fitted: Sizing.fit(screenH,availableCardWidth,availableCardHeight)
  contentWidth: fitted.width
  contentHeight: fitted.height
 }
 function check(actual,expected,label) {
  if(Math.abs(actual-expected)>.01){
   console.log("GEOMETRY_FAILED",step,label,actual,"expected",expected)
   failed=true
  }
 }
 Timer {interval:150;running:true;repeat:true;onTriggered:{
  var thickness=root.current.modern?40:26
  var w=host.screen.width,h=host.screen.height
  check(popup.availableCardWidth,Math.max(120,w-(root.vertical?thickness+22:20)),"available width")
  check(popup.availableCardHeight,Math.max(120,h-(root.vertical?20:thickness+22)),"available height")
  check(popup._barStripSize,thickness+12,"click forwarding strip")
  var expected=Sizing.fit(h,w-(root.vertical?thickness+22:20),h-(root.vertical?20:thickness+22))
  check(popup.contentWidth,expected.width,"card width")
  check(popup.contentHeight,expected.height,"card height")
  var position=root.current.position
  if(position==="top")check(popup.cardOrigin.y,thickness+12,"top origin")
  if(position==="bottom")check(popup.cardOrigin.y,h-thickness-12-popup.contentHeight,"bottom origin")
  if(position==="left")check(popup.cardOrigin.x,thickness+12,"left origin")
  if(position==="right")check(popup.cardOrigin.x,w-thickness-12-popup.contentWidth,"right origin")
  root.step++
  if(root.step===root.cases.length){
   if(!root.failed)console.log("POPUP_GEOMETRY_OK",root.step)
   Qt.quit()
  }
 }}
}
''' % (json.dumps((ROOT/'ui/shell').as_uri()),
       json.dumps((ROOT/'ui/shell/PanelSizing.js').as_uri())))
            result = subprocess.run(['quickshell', '--path', str(harness)],
                                    env=dict(os.environ, QT_QPA_PLATFORM='wayland'),
                                    capture_output=True, text=True, timeout=15)
            log = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, log)
            self.assertIn('POPUP_GEOMETRY_OK 8', log)
            for error in ('GEOMETRY_FAILED', 'ReferenceError', 'TypeError'):
                self.assertNotIn(error, log)
