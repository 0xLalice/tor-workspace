"""Exercise native imports through the live shell's qs: URL scheme."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

class NativeShellTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('quickshell') and os.environ.get('WAYLAND_DISPLAY') and (ROOT/'build/qml/circuit/libtorcircuit.so').exists(), 'Requires Quickshell and locally built modules')
    def test_virtual_urls_load_all_modules_and_share_palette_bindings(self):
        with tempfile.TemporaryDirectory() as folder:
            harness = Path(folder)
            (harness/'shell.qml').write_text('''import QtQuick
import Quickshell
import %s as Tor
ShellRoot {
 Tor.NativeCircuitLoader {id:circuit}
 Tor.ExitLights {id:lights;width:100;height:100;points:[{longitude:0,latitude:0}]}
 Tor.PerformanceMonitor {id:performance;monitoring:true;showHud:false}
 Component.onCompleted: {
  Tor.RenderCapabilities.nativeReady=true
  Tor.ThemeColors.palette={themeId:"flexoki-light"}
  Tor.ThemeDesign.design="meridian"
 }
 Timer {interval:1000;running:true;onTriggered:{
  if(circuit.item && circuit.item.contrastGain===1.8 && circuit.item.strokeScale===1.8 && lights.rendererLoaded && performance.probe) {
   Tor.ThemeColors.palette={themeId:"osaka-jade"};finish.start()
  } else {console.log("NATIVE_FAILED");Qt.quit()}
 }}
 Timer {id:finish;interval:50;onTriggered:{
  console.log(circuit.item.contrastGain===1 && circuit.item.strokeScale===1?"NATIVE_OK":"PALETTE_FAILED");Qt.quit()
 }}
}
''' % json.dumps('qs://'+str(ROOT/'ui')))
            result=subprocess.run(['quickshell','--path',str(harness)],capture_output=True,text=True,timeout=15)
            log=result.stdout+result.stderr
            self.assertEqual(result.returncode,0,log)
            self.assertIn('NATIVE_OK',log)
            for error in ('not found','does not match','ReferenceError','TypeError','Cannot assign'):
                self.assertNotIn(error,log)
