import ".."
import QtQuick
import Quickshell.Io
import qs.Ui
import qs.Commons

BarIconButton {
 id:root
 objectName:"tor-workspace-marker"
 property bool reducedMotion:false
 readonly property bool torRunning:serviceRunning
 property bool serviceRunning:false
 tooltipText:torRunning?"Tor workspace · Tor is on":"Tor workspace · Tor is off"
 Accessible.role:Accessible.Button
 Accessible.name:tooltipText
 function refreshStatus(){if(!serviceStatus.running)serviceStatus.running=true}
 // Observe the actual service even with the panel closed. No Tor control
 // connection, circuit demand, application launch or privilege is involved.
 Process {
  id:serviceStatus
  command:["sh","-c","exec systemctl is-active --quiet \"omarchy-tor-native-$(id -u).service\""]
  onExited:(code,status)=>{if(status===0)root.serviceRunning=code===0}
 }
 Timer {interval:3000;repeat:true;running:root.visible;triggeredOnStart:true;onTriggered:root.refreshStatus()}
 iconComponent:Component {
  // The shell measures this canvas before the nested vector has painted.
  // Keep its bounds stable when the service glow starts or stops.
  Rectangle {
   width:root.opticalSize;height:root.opticalSize
   color:"transparent"
   clip:true
   OnionEmblem {
    objectName:"tor-workspace-onion"
    lightRole:"trayLight"
    anchors.centerIn:parent;width:parent.width*.85;height:parent.height
    circuitReady:root.torRunning;active:root.visible;lightStyle:2
    reducedMotion:root.reducedMotion;accent:root.foreground
    idleOpacity:1;idleTint:root.foreground
    opacity:root.torRunning?1:.7
    Behavior on opacity {NumberAnimation {duration:root.reducedMotion?0:350}}
   }
  }
 }
}
