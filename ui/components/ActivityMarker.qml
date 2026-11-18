import ".."
import QtQuick

Item {
 id:root
 property color color:ThemeColors.color("uiAccent")
 // 0: steady, 1: breathing dot, 2: expanding ring.
 property int variant:1
 property bool active:true
 property bool reducedMotion:false
 readonly property bool animating:visible&&active&&!reducedMotion&&variant!==0
 property real phase:0
 width:8;height:8
 onAnimatingChanged:if(!animating)phase=0
 SequentialAnimation on phase {
  running:root.animating;loops:Animation.Infinite
  NumberAnimation {from:0;to:1;duration:1800;easing.type:Easing.InOutSine}
  NumberAnimation {from:1;to:0;duration:1800;easing.type:Easing.InOutSine}
 }
 Rectangle {
  anchors.fill:parent;radius:width/2;color:root.color
  opacity:root.animating&&root.variant===1?.82+.13*root.phase:1
 }
 Rectangle {
  anchors.fill:parent;radius:width/2;color:"transparent"
  border.color:root.color;border.width:1
  visible:root.animating&&root.variant===2
  scale:1+root.phase*.55;opacity:(1-root.phase)*.25
 }
}
