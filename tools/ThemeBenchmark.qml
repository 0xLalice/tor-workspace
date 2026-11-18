import QtQuick
import QtQuick.Window
import "../ui" as Tor
import "../ui/theme/BuiltinThemes.js" as Builtins
import "../ui/theme/SoftIllumination.js" as Soft
Window {
 id:window;width:460;height:690;minimumWidth:460;maximumWidth:460;minimumHeight:690;maximumHeight:690;flags:Qt.Dialog;visible:true;title:"Tor Workspace · native benchmark"
 color:Tor.ThemeColors.color("background")
 property string scenario:"steady"
 property int duration:60
 property bool capturing:false
 property bool changed:false
 property var preset:Builtins.entries[0]
 property int paints:0
 property real clock:0
 property var routeA:[{country:"TH",longitude:101,latitude:15},{country:"DE",longitude:10,latitude:51},{country:"FR",longitude:2,latitude:47},{country:"US",longitude:-77,latitude:39}]
 property var routeB:[{country:"TH",longitude:101,latitude:15},{country:"FI",longitude:25,latitude:62},{country:"NL",longitude:5,latitude:52},{country:"CA",longitude:-73,latitude:46}]
 Component.onCompleted:{
  var args=Qt.application.arguments
  scenario=args[args.indexOf("--scenario")+1]||"steady"
  duration=Number(args[args.indexOf("--seconds")+1])||60
  if(args.indexOf("--preset")>=0){var xhr=new XMLHttpRequest();xhr.open("GET",args[args.indexOf("--preset")+1],false);xhr.send();preset=JSON.parse(xhr.responseText)}
  Tor.RenderCapabilities.nativeReady=true
 }
 Tor.TorDashboard {
  id:panel;anchors.fill:parent;anchors.margins:20;active:true
  appearance:window.preset.appearance;interfaceSettings:window.preset.interface||({})
  effectSettings:Tor.ThemeColors.resolveData(Tor.ThemeDesign.definition.softIllumination?Soft.adopt(window.preset.settings):window.preset.settings)
  torRunning:true;state:"ready";route:window.changed?window.routeB:window.routeA
  presetCamera:window.preset.camera||null
  circuitId:window.changed?"benchmark-b":"benchmark-a"
  exitNetwork:({points:Array.from({length:2000},function(_,i){return {longitude:(i*137.508)%360-180,latitude:Math.asin(2*(i+.5)/2000-1)*180/Math.PI}})})
  diagnosticsEnabled:true;diagnosticsHud:false

 }
 Tor.PerformanceProbe {id:probe;collecting:true;hud:false;onCaptureChanged:if(lastCapture){console.log("BENCHMARK_CAPTURE",lastCapture);console.log("BENCHMARK_WORK",JSON.stringify({paintCalls:panel.globe.transitionState.paintCount-window.paints,animationSeconds:panel.globe.time-window.clock}));Qt.quit()}}
 Timer {interval:5000;running:true;onTriggered:{window.paints=panel.globe.transitionState.paintCount;window.clock=panel.globe.time;if(!panel.globe.nativeCircuitRendering){Qt.exit(3);return}probe.startCapture(window.duration,{theme:window.preset.id,scenario:window.scenario,nativeRenderer:panel.globe.nativeCircuitRendering});window.capturing=true}}
 Timer {interval:5000;repeat:true;running:window.capturing&&window.scenario==="renewal";onTriggered:window.changed=!window.changed}
 Timer {interval:33;repeat:true;running:window.capturing&&window.scenario==="interaction";onTriggered:{panel.globe.longitude+=.6;panel.globe.latitude=20+15*Math.sin(panel.globe.time)}}
 Timer {interval:20000;repeat:true;triggeredOnStart:true;running:window.scenario==="illumination";onTriggered:panel.playExitNetwork()}
 Timer {interval:(window.duration+10)*1000;running:true;onTriggered:{console.warn("Benchmark timed out");Qt.exit(2)}}
}
