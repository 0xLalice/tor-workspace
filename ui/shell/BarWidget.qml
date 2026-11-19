import ".."
import QtQuick
import Quickshell.Io

// String URL boundary: the shell can load this entry point without any native module.
Item {
 id: root
 property QtObject bar: null
 property var settings: ({})
 property string moduleName: "tor.workspace"
 property var installation: ({ready:false,issues:["Checking installation…"]})
 property string loadError: ""
 readonly property bool popoutSwitchClosing: screen.item ? screen.item.popoutSwitchClosing : false
 readonly property bool opened: screen.item ? screen.item.opened : false
 readonly property bool dashboardLoaded: screen.status===Loader.Ready && screen.item!==null
 implicitWidth: screen.item ? screen.item.implicitWidth : 24
 implicitHeight: screen.item ? screen.item.implicitHeight : 24
 function open() { if(screen.item)screen.item.open() }
 function close() { if(screen.item)screen.item.close() }
 function toggle() { if(screen.item)screen.item.toggle() }
 function closeForPopoutSwitch() { if(screen.item)screen.item.closeForPopoutSwitch() }
 function checkInstallation() { if(!check.running)check.running=true }
 function startInstallation() { if(screen.item)screen.item.startInstallation() }
 function showScreen() {
  var name="RuntimeWidget.qml"
  var next=Qt.resolvedUrl(name)
  if(screen.source.toString()!==next.toString())screen.setSource(next, {bar:Qt.binding(function(){return root.bar}),settings:Qt.binding(function(){return root.settings}),installationHost:root})
 }
 onInstallationChanged: RenderCapabilities.nativeReady=installation.nativeReady===true
 Loader {
  id: screen
  anchors.fill: parent
  onStatusChanged: if(status===Loader.Error) {
   root.loadError="The panel could not load. Ask your agent to check Qt and rebuild the native modules."
  }
 }
 Process {
  id:check
  command:["bash","-c","if command -v python3 >/dev/null 2>&1; then exec python3 -B \"$1\"; else printf '%s\\n' '{\"ready\":false,\"issues\":[\"Python is missing.\"]}'; fi","tor-install-check",decodeURIComponent(Qt.resolvedUrl("../../install/setup_status.py").toString().replace(/^file:\/\//,""))]
  stdout:StdioCollector {onStreamFinished:{try{root.installation=JSON.parse(text)}catch(e){root.installation={ready:false,issues:["Could not check installation. Ask your agent to inspect it."]}}}}
  onExited: code=>{if(code!==0)root.installation={ready:false,issues:["Installation check failed. Ask your agent to inspect it."]}}
 }
 Timer {interval:15000;repeat:true;running:!root.installation.ready;onTriggered:root.checkInstallation()}
 Component.onCompleted: {RenderCapabilities.nativeReady=installation.nativeReady===true;showScreen();checkInstallation()}
}
