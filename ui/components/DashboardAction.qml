import ".."
import QtQuick
import QtQuick.Controls

// Both dashboard layouts instantiate this control; it owns no Tor operation.
Button {
 id:root
 property var descriptor:({kind:"",title:"",detail:"",accessible:"",enabled:false,active:false})
 property string activityObjectName:kind+"-active-dot"
 property bool panelActive:false
 property bool reducedMotion:false
 property bool tooltipBelow:true
 property color ink:ThemeColors.color("uiText")
 property color accent:ThemeColors.color("uiAccent")
 readonly property string kind:descriptor.kind
 readonly property bool serviceActive:!!descriptor.active
 readonly property bool glowing:panelActive&&visible&&enabled&&(hovered||visualFocus)
 readonly property bool pulse:ThemeDesign.definition.hoverPulse&&!reducedMotion
 property real shimmer:0
 enabled:descriptor.enabled
 opacity:enabled?1:.28
 implicitWidth:34;implicitHeight:34;padding:0;hoverEnabled:true;focusPolicy:Qt.StrongFocus
 Accessible.name:descriptor.accessible||descriptor.title
 Accessible.description:descriptor.detail||""
 HoverHandler {cursorShape:root.enabled?Qt.PointingHandCursor:Qt.ArrowCursor}
 background:Item {}
 SequentialAnimation on shimmer {
  running:root.glowing&&root.pulse;loops:Animation.Infinite
  NumberAnimation {from:0;to:1;duration:1100;easing.type:Easing.InOutSine}
  NumberAnimation {from:1;to:0;duration:1100;easing.type:Easing.InOutSine}
 }
 contentItem:Item {
  ActionGlyph {
   anchors.centerIn:parent;width:22;height:22;kind:root.kind;ink:root.ink;accent:root.accent
   glow:root.glowing?(root.pulse?.35+.65*root.shimmer:1):0
   scale:root.down?.94:root.glowing&&root.pulse?1.03+.045*root.shimmer:1
   Behavior on scale {NumberAnimation {duration:root.reducedMotion?0:180;easing.type:Easing.OutCubic}}
  }
 }
 ActivityMarker {
  objectName:root.activityObjectName;visible:root.serviceActive
  anchors.right:parent.right;anchors.top:parent.top;anchors.margins:ThemeDesign.definition.markerInset
  width:ThemeDesign.definition.markerSize;height:width
  color:root.accent;active:root.panelActive;reducedMotion:root.reducedMotion
  variant:ThemeDesign.definition.markerVariant
 }
 TorToolTip {
  objectName:"dashboard-action-tooltip"
  // A mouse click retains focus after a popup closes; only keyboard focus shows help.
  visible:root.hovered||root.visualFocus;below:root.tooltipBelow
  ink:root.ink;accent:root.accent;text:root.descriptor.title||"";detail:root.descriptor.detail||""
 }
}
