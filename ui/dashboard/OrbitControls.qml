import ".."
import QtQuick

// Layout only: the lower half remains reserved for the circuit.
Item {
 id:root;objectName:"orbit-controls"
 property var actions:[]
 property var actionModel:({})
 property bool panelActive:false
 property bool reducedMotion:false
 property color ink:ThemeColors.color("uiText")
 property color accent:ThemeColors.color("uiAccent")
 property real controlSize:44
 readonly property real ringRadius:Math.max(0,height/2-controlSize/2)
 property real globeRadius:90
 readonly property real actionRadius:Math.max(globeRadius+38,96)
 signal triggered(string kind)
 function focusFirst(reverse){
  for(var i=0;i<buttons.count;i++){
   var button=buttons.itemAt(reverse?buttons.count-1-i:i)
   if(button.enabled){button.forceActiveFocus(Qt.TabFocusReason);return true}
  }
  return false
 }
 Repeater {
  id:buttons;model:root.actions
  delegate:DashboardAction {
   id:button;required property var modelData;required property int index
   objectName:"orbit-"+modelData;activityObjectName:"orbit-"+modelData+"-active-dot";descriptor:root.actionModel[modelData]
   readonly property real angle:-Math.PI+index*Math.PI/Math.max(1,root.actions.length-1)
   x:root.width/2+Math.cos(angle)*root.actionRadius-width/2
   y:root.height/2+Math.sin(angle)*root.actionRadius-height/2
   width:root.controlSize;height:width
   panelActive:root.panelActive;reducedMotion:root.reducedMotion
   ink:root.ink;accent:root.accent;tooltipBelow:Math.sin(angle)<0
   KeyNavigation.tab:index<root.actions.length-1?buttons.itemAt(index+1):null
   KeyNavigation.backtab:index>0?buttons.itemAt(index-1):null
   onClicked:root.triggered(descriptor.kind)
  }
 }
}
