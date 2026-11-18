import ".."
import QtQuick
import QtQuick.Controls

Item {
 id:root;objectName:"performance-monitor"
 property bool monitoring:false
 property bool panelActive:false
 property bool showHud:true
 property var context:({})
 property color ink:ThemeColors.color("uiText")
 property color surface:ThemeColors.color("background")
 readonly property var probe:loader.item
 readonly property var stats:probe?probe.stats:({})
 readonly property bool recording:probe?probe.recording:false
 function snapshot(){return probe?probe.snapshot():({available:false,error:"Enable diagnostics; native frame probe must be built"})}
 function capture(seconds){return probe?probe.startCapture(seconds,context):false}
 function value(key){return stats[key]===undefined||stats[key]===null?"Unavailable":Number(stats[key]).toFixed(1)}
 // Optional loading keeps the normal plugin usable after a Qt ABI upgrade.
 Loader {
  id:loader;active:root.monitoring&&RenderCapabilities.nativeReady;source:Qt.resolvedUrl("PerformanceProbe.qml").toString().replace(/^qs:/,"file:")
  onLoaded:{item.collecting=Qt.binding(()=>root.panelActive);item.hud=Qt.binding(()=>root.showHud)}
 }
 width:Math.min(parent?parent.width:300,330);height:hud.implicitHeight+16
 visible:monitoring&&panelActive&&showHud
 Rectangle {anchors.fill:parent;color:root.surface;opacity:.94;radius:ThemeDesign.radius(5);border.color:Qt.alpha(root.ink,ThemeDesign.borderAlpha(.3))}
 Column {
  id:hud;x:8;y:8;width:parent.width-16;spacing:3
  Text {color:root.ink;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(12);text:loader.status===Loader.Error?"FPS probe unavailable":root.value("fps")+" FPS · submissions / last 1 s"}
  Text {color:root.ink;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(10);text:"5 s · ms  p50 "+root.value("p50Ms")+"  p95 "+root.value("p95Ms")+"  p99 "+root.value("p99Ms")}
  Text {color:root.ink;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(10);text:"Max "+root.value("maxMs")+" ms · late "+(root.stats.lateIntervals||0)+" · "+root.value("refreshHz")+" Hz"}
  Text {color:root.ink;font.family:ThemeDesign.fontFamily;font.pixelSize:ThemeDesign.px(10);text:root.recording?"Recording…":root.probe&&root.probe.lastCapture?"Capture saved · see Options":root.probe&&root.probe.error?root.probe.error:"Window output · not GPU time";width:parent.width;wrapMode:Text.WordWrap}
 }
}
